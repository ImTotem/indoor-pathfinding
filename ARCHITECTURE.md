# Indoor Pathfinding 아키텍처

## 전체 구조

```
[클라이언트 - Flutter + Rust Core]
Flutter ──uniffi──→ Rust Core ──gRPC──→ gateway

[서버 - Docker]
gateway (Rust)
  ├── gRPC 서버: Flutter로부터 센서 데이터 수신, 포즈 결과 반환
  ├── ROS2 발행: 센서 데이터를 ROS2 토픽으로 변환/발행
  └── ROS2 구독: SLAM 결과(포즈)를 구독해서 gRPC로 전달

SLAM 어댑터 (C++/Python)
  ├── ROS2 토픽 구독 → SLAM 엔진 API 호출 → 결과를 ROS2 토픽으로 발행
  ├── 구현체: ORB-SLAM3, MASt3R-SLAM 등 교체 가능
  └── 카메라 캘리브레이션: 세션 시작 시 gateway로부터 수신

FastAPI ──→ PostgreSQL (맵 CRUD, REST)
```

## 통신 프로토콜

| 구간 | 프로토콜 | 이유 |
|---|---|---|
| Flutter ↔ Rust Core | uniffi (FFI) | 온디바이스, 지연 최소 |
| Rust Core ↔ gateway | gRPC (protobuf) | 양방향 스트리밍, 바이너리 효율 |
| gateway ↔ SLAM | ROS2 DDS 토픽 | SLAM 엔진 교체 용이, ROS2 생태계 활용 |
| Flutter ↔ FastAPI | REST (JSON) | 맵 CRUD, 성능 무관 |

## ROS2 토픽 설계 (표준 인터페이스)

SLAM 엔진에 독립적인 고정 토픽:

| 방향 | 토픽 | 메시지 타입 | 설명 |
|---|---|---|---|
| gateway → SLAM | `/slam/image` | sensor_msgs/Image | 카메라 프레임 |
| gateway → SLAM | `/slam/imu` | sensor_msgs/Imu | IMU 데이터 |
| gateway → SLAM | `/slam/calibration` | 커스텀 | 카메라 캘리브레이션 (세션 시작 시) |
| SLAM → gateway | `/slam/pose` | geometry_msgs/PoseStamped | 추정 포즈 |
| SLAM → gateway | `/slam/status` | 커스텀 | 트래킹 상태 |
| SLAM → gateway | `/slam/map_points` | sensor_msgs/PointCloud2 | 맵 포인트 |

## DDS 큐 vs rosbag2

- **DDS QoS 큐**: ROS2 미들웨어가 관리하는 버퍼. SLAM 처리가 느릴 때 메시지 손실 방지.
- **rosbag2**: ROS2 토픽을 **파일로 녹화**하는 도구. 실시간 동작과 무관.

### rosbag2 용도
1. **SLAM 알고리즘 튜닝** — 같은 데이터로 파라미터 변경 반복 테스트
2. **버그 재현** — 현장 데이터를 사무실에서 재생
3. **SLAM 엔진 비교** — 동일 데이터로 ORB-SLAM3 vs MASt3R 성능 비교

## 카메라 캘리브레이션

- 기기마다 캘리브레이션이 다르므로 **클라이언트에서 전송**
- gRPC `StartSession` 시 캘리 데이터 포함
- gateway가 ROS2 토픽/파라미터로 SLAM 어댑터에 전달
- SLAM 어댑터는 이 값으로 엔진 초기화

## SLAM 어댑터 구조

SLAM 엔진을 교체 가능하게 설계:

```
server/slam/
├── interface/         # ROS2 표준 토픽 인터페이스 정의
└── adapters/
    ├── orbslam3/      # ORB-SLAM3 구현체
    └── mast3r/        # MASt3R-SLAM 구현체 (추후)
```

각 어댑터는 동일한 ROS2 토픽을 구독/발행하므로 gateway 수정 없이 교체 가능.

## 폴더 구조

```
server/
├── api/       # FastAPI (REST, 맵 CRUD)
├── gateway/   # gRPC ↔ ROS2 변환 (Rust)
├── slam/      # SLAM 어댑터 계층
└── db/        # PostgreSQL 마이그레이션 (alembic)
```
