#!/usr/bin/env python3
"""rosbag2에서 CompressedImage 이미지를 추출 (db3 + mcap 지원)"""
import sqlite3
import sys
import struct
from pathlib import Path


def extract_image_from_cdr(data: bytes) -> tuple[str, bytes]:
    """CDR 직렬화된 CompressedImage에서 format과 image bytes 추출"""
    offset = 4  # CDR header (4 bytes)

    # Header.stamp (sec: i32 + nanosec: u32 = 8 bytes)
    offset += 8

    # Header.frame_id (string: u32 length + data + padding)
    str_len = struct.unpack_from("<I", data, offset)[0]
    offset += 4 + str_len
    # align to 4 bytes
    offset = (offset + 3) & ~3

    # format (string: u32 length + data)
    fmt_len = struct.unpack_from("<I", data, offset)[0]
    offset += 4
    fmt = data[offset : offset + fmt_len - 1].decode()  # -1 for null terminator
    offset += fmt_len
    offset = (offset + 3) & ~3

    # data (bytes: u32 length + data)
    img_len = struct.unpack_from("<I", data, offset)[0]
    offset += 4
    img_data = data[offset : offset + img_len]

    return fmt, img_data


def extract_from_db3(db3_path: Path, out_dir: Path):
    """sqlite3 db3 파일에서 추출"""
    conn = sqlite3.connect(str(db3_path))

    topics = conn.execute(
        "SELECT id, name, type FROM topics WHERE type LIKE '%CompressedImage%'"
    ).fetchall()

    if not topics:
        print("CompressedImage 토픽을 찾을 수 없습니다.")
        conn.close()
        return

    for topic_id, topic_name, topic_type in topics:
        print(f"토픽: {topic_name} (id={topic_id})")

        messages = conn.execute(
            "SELECT timestamp, data FROM messages WHERE topic_id = ? ORDER BY timestamp",
            (topic_id,),
        ).fetchall()

        print(f"  메시지 수: {len(messages)}")

        for i, (ts, data) in enumerate(messages):
            try:
                fmt, img_bytes = extract_image_from_cdr(data)
                ext = fmt if fmt in ("jpeg", "png") else "bin"
                filename = out_dir / f"frame_{i:05d}_{ts}.{ext}"
                filename.write_bytes(img_bytes)
                if i == 0:
                    print(f"  포맷: {fmt}, 크기: {len(img_bytes)} bytes")
            except Exception as e:
                print(f"  [{i}] 추출 실패: {e}")

    conn.close()


def extract_from_mcap(bag_dir: Path, out_dir: Path):
    """mcap rosbag2 디렉터리에서 추출"""
    mcap_files = list(bag_dir.glob("*.mcap"))
    if not mcap_files:
        print(f"mcap 파일을 찾을 수 없습니다: {bag_dir}")
        return

    for mcap_file in mcap_files:
        print(f"파일: {mcap_file.name}")

        try:
            from mcap.reader import make_reader
        except ImportError:
            print("mcap 패키지가 필요합니다: pip install mcap mcap-ros2-interfaces")
            return

        i = 0
        with open(mcap_file, "rb") as f:
            reader = make_reader(f)
            for schema, channel, message in reader.iter_messages():
                if "CompressedImage" not in schema.name:
                    continue
                try:
                    fmt, img_bytes = extract_image_from_cdr(message.data)
                    ext = fmt if fmt in ("jpeg", "png") else "bin"
                    filename = out_dir / f"frame_{i:05d}_{message.publish_time}.{ext}"
                    filename.write_bytes(img_bytes)
                    if i == 0:
                        print(f"  포맷: {fmt}, 크기: {len(img_bytes)} bytes")
                    i += 1
                except Exception as e:
                    print(f"  [{i}] 추출 실패: {e}")

        print(f"  메시지 수: {i}")


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <db3_file_or_bag_dir> [output_dir]")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    out_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else input_path.parent / "extracted"
    out_dir.mkdir(parents=True, exist_ok=True)

    if input_path.suffix == ".db3":
        extract_from_db3(input_path, out_dir)
    elif input_path.suffix == ".mcap":
        extract_from_mcap(input_path.parent, out_dir)
    elif input_path.is_dir():
        # 디렉터리면 mcap 또는 db3 자동 감지
        mcap_files = list(input_path.glob("*.mcap"))
        db3_files = list(input_path.glob("*.db3"))
        if mcap_files:
            extract_from_mcap(input_path, out_dir)
        elif db3_files:
            for db3 in db3_files:
                extract_from_db3(db3, out_dir)
        else:
            print(f"db3 또는 mcap 파일을 찾을 수 없습니다: {input_path}")
    else:
        print(f"지원하지 않는 형식: {input_path}")

    print(f"\n추출 완료 → {out_dir}")


if __name__ == "__main__":
    main()
