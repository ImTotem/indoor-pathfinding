#!/usr/bin/env python3
"""rosbag2 db3 파일에서 CompressedImage 메시지의 이미지를 추출"""
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


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <db3_file> [output_dir]")
        sys.exit(1)

    db3_path = Path(sys.argv[1])
    out_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else db3_path.parent / "extracted"
    out_dir.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(str(db3_path))

    # 토픽 이름 확인
    topics = conn.execute(
        "SELECT id, name, type FROM topics WHERE type LIKE '%CompressedImage%'"
    ).fetchall()

    if not topics:
        print("CompressedImage 토픽을 찾을 수 없습니다.")
        topics_all = conn.execute("SELECT id, name, type FROM topics").fetchall()
        print("사용 가능한 토픽:")
        for t in topics_all:
            print(f"  [{t[0]}] {t[1]} ({t[2]})")
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
    print(f"\n추출 완료 → {out_dir}")


if __name__ == "__main__":
    main()
