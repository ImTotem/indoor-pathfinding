# TODO

## 완료

| 작업 | 상태 |
|---|---|
| proto 정의 — common, mapping, localization, session, service 분리 | 완료 |
| `server/api` — FastAPI 맵 CRUD (dto/repository 패턴) | 완료 |
| Docker 설정 (api + postgres + slam 컨테이너 분리, GPU) | 완료 |
| Flutter ↔ REST API 연동 (맵 생성/목록) | 완료 |
| Flutter UI — 다크모드 색상, 닫기 모달, 이름 검증 | 완료 |
| Flutter 환경 — fvm 전환, Gradle/AGP/Kotlin/NDK 업그레이드 | 완료 |

## 남은 작업

| 우선순위 | 작업 | 상태 |
|---|---|---|
| 1 | `session/request.proto`에 `map_id` 추가 + Map 모델에 `status` 필드 | 미완 |
| 2 | `server/gateway` — gRPC ↔ ROS2 변환 실제 구현 | 스텁 |
| 3 | `server/slam` — MASt3R-SLAM + RoMa 어댑터 구현 | 스텁 |
| 4 | Docker 이미지 실제 빌드 & 테스트 (slam 컨테이너) | 미실행 |
| 5 | Flutter gRPC 연동 — Rust Core 센서 스트리밍 | 미착수 |
