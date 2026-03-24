# TODO

## 완료

| 작업 | 상태 |
|---|---|
| proto 정의 — common, mapping, localization, session, service 분리 | 완료 |
| `session/request.proto`에 `map_id` + `SessionType` 추가 | 완료 |
| `server/api` — FastAPI 맵 CRUD (dto/repository 패턴) | 완료 |
| Docker 설정 (api + postgres + slam 컨테이너 분리, GPU) | 완료 |
| Flutter ↔ REST API 연동 (맵 생성/목록) | 완료 |
| Flutter UI — 다크모드 색상, 닫기 모달, 이름 검증 | 완료 |
| Flutter 환경 — fvm 전환, Gradle/AGP/Kotlin/NDK 업그레이드 | 완료 |
| `server/gateway` — gRPC 수신 → ROS2 토픽 발행 → rosbag2 녹화 | 완료 |
| `server/gateway` — 서버 측 session_id 생성 (s + UUID) | 완료 |
| Rust Core — UniFFI 바인딩, tokio 런타임, gRPC 세션/스트리밍 | 완료 |
| Rust Core — 센서 aggregator (Frame+IMU+Baro → proto 패킷) | 완료 |
| Rust Core — bounded 채널 (128), 큐 드레인, queue_full 상태 | 완료 |
| Android — CameraX 프리뷰 (Flutter Texture), JPEG 인코딩 | 완료 |
| Android — IMU/자이로/기압계 센서 수집 → Rust Core push | 완료 |
| Android — SENSOR_LANDSCAPE (자동회전 무관 OS 회전) | 완료 |
| Android — 왼손/오른손 모드 (UI 좌우 대칭 + 캡처 이미지 180° 보정) | 완료 |
| Flutter — 카메라 화면 (프리뷰, 녹화 시작/일시정지/재개, HUD) | 완료 |
| Flutter — HUD (캡처FPS, 전송FPS, IMU, 자이로, 기압계, 포즈) | 완료 |
| Flutter — 종료 모달, 업로드 모달 (드레인 프로그레스), 큐 대기 모달 | 완료 |
| Flutter — 녹화 카운트다운 모달 (3초, 백그라운드 세션 설정) | 완료 |
| Flutter — MethodChannel/EventChannel 브릿지 (세션, 카메라, 상태) | 완료 |
| Gradle — cargo-ndk 자동 크로스 컴파일 + UniFFI 바인딩 생성 | 완료 |
| PNG → JPEG 전환 (YUV→JPEG 직접 변환, 10배+ 속도 향상) | 완료 |
| RTT 기반 타임스탬프 보정 (5라운드, CLOCK_BOOTTIME → Unix epoch) | 완료 |
| Proto — SyncTime, SetTimeOffset RPC 추가 | 완료 |
| Docker — 멀티스테이지 빌드 (Rust SIGSEGV 회피), Rust 1.93.1 고정 | 완료 |
| 세션 구조 개선 — 스트림 끊김 즉시 정리, 리퍼, CleanupStale RPC | 완료 |
| Proto — CleanupStale RPC, device_orientation 필드 추가 | 완료 |
| 캡처 이미지 회전 보정 — device_orientation 메타데이터 활용 | 완료 |

## 남은 작업

| 우선순위 | 작업 | 상태 |
|---|---|---|
| ~~1~~ | ~~`server/slam` — MUSt3R SLAM 어댑터 구현 (`slam.py` 연동)~~ | 완료 |
| ~~2~~ | ~~Docker slam 컨테이너 빌드 (MUSt3R + CUDA + ROS2 Jazzy)~~ | 완료 |
| ~~3~~ | ~~gateway → SLAM API 세션 시작/종료 HTTP 호출~~ | 완료 |
| 4 | Pathfinding 카메라 화면 — localization 세션 연동 | 미착수 |
| 5 | SLAM 요구 시 서버 측 JPEG→PNG 변환 | 미착수 |
| 6 | MUSt3R 키프레임 수 개선 (현재 113프레임 → 1키프레임) | 조사 필요 |
| 7 | 세션 분리: 프레임 전송 완료 후 앱 종료, SLAM은 백그라운드 계속 처리 | 미착수 |

### SLAM 엔진 선정

- **MUSt3R** (naver/must3r) 채택 — MASt3R 후속, 다층 메모리 메커니즘
- 근거: SLAM 내장 (`slam.py`), 웹캠 실시간 지원, 멀티뷰 강화, 최신 모델
- 라이선스: Non-Commercial (졸업작품 용도 OK)
- DUSt3R → MASt3R → **MUSt3R** 진화 순서
