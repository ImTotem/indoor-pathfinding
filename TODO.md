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
| Flutter — MethodChannel/EventChannel 브릿지 (세션, 카메라, 상태) | 완료 |
| Gradle — cargo-ndk 자동 크로스 컴파일 + UniFFI 바인딩 생성 | 완료 |
| PNG → JPEG 전환 (YUV→JPEG 직접 변환, 10배+ 속도 향상) | 완료 |

## 남은 작업

| 우선순위 | 작업 | 상태 |
|---|---|---|
| 1 | `server/slam` — MASt3R-SLAM + RoMa 어댑터 구현 | 미착수 |
| 2 | Docker slam 컨테이너 빌드 & 테스트 | 미실행 |
| 3 | gateway — SLAM 결과 수신 → gRPC 응답 (Pose) 반환 | 스텁 |
| 4 | Pathfinding 카메라 화면 — localization 세션 연동 | 미착수 |
| 5 | 캡처 이미지 회전 보정 — 센서 방향 메타데이터 활용 | 개선 필요 |
| 6 | PNG 인코딩 최적화 — 서버 측 JPEG→PNG 변환 (SLAM 요구 시) | 미착수 |
