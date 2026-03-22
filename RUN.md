# 실행 가이드

## 사전 준비

### 필수 도구
- [mise](https://mise.jdx.dev/) — Rust, Python, Android SDK, protoc 관리
- [fvm](https://fvm.app/) — Flutter 버전 관리 (3.29.3)
- Docker + Docker Compose
- Android 실기기 (USB 디버깅 또는 무선 ADB)
- cargo-ndk (`cargo install cargo-ndk`)

### Rust 타겟
```bash
rustup target add aarch64-linux-android x86_64-linux-android
```

---

## 1. Gateway 서버 실행

### Docker로 실행
```bash
cd ~/git/indoor-pathfinding

# gateway (gRPC + ROS2 + rosbag2)
docker compose -f docker/docker-compose.yml up slam

# API 서버 (맵 CRUD)
docker compose -f docker/docker-compose.yml up api
```

gateway: `100.78.78.37:50051` (gRPC)
API: `100.78.78.37:8000` (REST)

### Gateway 로컬 실행 (ROS2 없이)
```bash
cargo run -p gateway
```

---

## 2. Flutter 앱 실행

### 실기기 연결
```bash
# USB
adb devices

# 무선 (Tailscale)
adb connect <phone-ip>:5555
```

### 실행
```bash
cd ~/git/indoor-pathfinding/client/flutter_app
fvm flutter run
```

### 빌드만 (설치 별도)
```bash
fvm flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

> 첫 빌드 시 Gradle이 자동으로 Rust 크로스 컴파일 + UniFFI 바인딩을 생성합니다 (~1분).

---

## 3. 앱 사용 흐름

1. **홈** → "맵 생성" 카드 선택
2. **맵 정보 입력** → 건물 이름 입력 → "다음 화면으로"
3. **카메라 화면** → 녹화 버튼 (3초 카운트다운 후 녹화 시작)
   - 녹화 중: HUD에 캡처FPS, 전송FPS, IMU, 기압계 실시간 표시
   - 일시정지/재개: 녹화 버튼 토글
   - 왼손/오른손 모드: 자동 감지 (SENSOR_LANDSCAPE)
4. **종료** → X 버튼 → "종료" → 업로드 모달 (큐 드레인 진행률) → 자동으로 홈 이동

---

## 4. 녹화 데이터 확인

### rosbag2 파일 위치
```bash
ls ~/docker-data/slam/rosbag2/
# 또는 Docker 내부
docker exec <container> ls /workspace/rosbag2/
```

### 메시지 수 확인
```bash
sqlite3 ~/docker-data/slam/rosbag2/<session_id>/<session_id>_0.db3 \
  "SELECT t.name, COUNT(*) FROM messages m JOIN topics t ON m.topic_id=t.id GROUP BY t.name;"
```

### 타임스탬프 확인
```bash
sqlite3 <db3파일> \
  "SELECT MIN(timestamp)/1e9, MAX(timestamp)/1e9 FROM messages;"
```
> Unix epoch (~1.77e9) 범위면 RTT 시간 보정 정상.

### 이미지 추출
```bash
python3 scripts/extract_rosbag_images.py ~/docker-data/slam/rosbag2/<session_id>/<session_id>_0.db3
# → extracted/ 폴더에 JPEG 파일 생성
```

### DB Browser에서 이미지 보기 (SQL)
```sql
SELECT
  substr(data, instr(hex(data), 'FFD8FF') / 2 + 1) as clean_image
FROM messages
WHERE topic_id = (SELECT id FROM topics WHERE name LIKE '%image%')
ORDER BY timestamp
LIMIT 1;
```
> 결과 셀 클릭 → 우측 "Image" 탭

---

## 5. Rust 코드 변경 시

### Client (Rust Core) 변경
```bash
cd ~/git/indoor-pathfinding

# 호스트 빌드 + UniFFI 바인딩 생성
cargo build -p indoor-pathfinding-rust-core --release
cargo run --release --bin uniffi-bindgen generate \
  --library target/release/librust_core.so \
  --language kotlin \
  --out-dir client/flutter_app/android/app/src/main/java

# Android 크로스 컴파일
ANDROID_NDK_HOME=~/.local/share/mise/installs/android-sdk/1.0/ndk/27.0.12077973 \
  cargo ndk -o client/flutter_app/android/app/src/main/jniLibs \
  -t arm64-v8a -t x86_64 build --release

# Flutter 재빌드
cd client/flutter_app && fvm flutter build apk --debug
```

### Gateway 변경
```bash
# 로컬 테스트
cargo build -p gateway

# Docker 재빌드
docker compose -f docker/docker-compose.yml build slam
```

### Proto 변경
```bash
# proto 변경 시 protocols 크레이트가 자동 재생성
cargo build  # workspace 전체 빌드
```

---

## 6. 문제 해결

| 증상 | 원인 | 해결 |
|------|------|------|
| `flutter build` Dart SIGSEGV | Flutter 3.41.4 컴파일러 버그 | `fvm use 3.29.3` 사용 |
| `flutter build` JVM SIGSEGV | Gradle JIT 컴파일러 간헐 오류 | `flutter clean && flutter build` 재시도 |
| gateway 패킷 수신 안 됨 | Docker 재빌드 필요 | `docker compose build slam` |
| rosbag2 좀비 프로세스 | 앱 비정상 종료 | 30초 후 리퍼 자동 정리, 또는 앱 재시작 시 CleanupStale |
| 카메라 권한 오류 | 앱 첫 실행 | 설정에서 카메라 권한 허용 |
| adb 연결 안 됨 | 무선 연결 끊김 | `adb connect <ip>:5555` |
