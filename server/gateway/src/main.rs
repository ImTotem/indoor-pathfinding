use std::pin::Pin;

use tokio_stream::Stream;
use tonic::{transport::Server, Request, Response, Status, Streaming};
use tracing::info;

use indoor_pathfinding_protocols::sensor::{
    sensor_service_server::{SensorService, SensorServiceServer},
    PoseResult, SensorPacket,
};
use indoor_pathfinding_protocols::sync::{
    sync_service_server::{SyncService, SyncServiceServer},
    GetStatusRequest, SessionResponse, SessionState, StartSession, StopSession,
};

#[derive(Default)]
pub struct SensorServiceImpl;

#[tonic::async_trait]
impl SensorService for SensorServiceImpl {
    type StreamSensorStream =
        Pin<Box<dyn Stream<Item = Result<PoseResult, Status>> + Send + 'static>>;

    async fn stream_sensor(
        &self,
        request: Request<Streaming<SensorPacket>>,
    ) -> Result<Response<Self::StreamSensorStream>, Status> {
        info!("센서 스트리밍 연결 수립");
        let mut stream = request.into_inner();

        let output = async_stream::try_stream! {
            while let Some(packet) = stream.message().await? {
                // TODO: ROS2 토픽으로 센서 데이터 발행
                // TODO: rosbag2에 기록
                info!(timestamp = packet.timestamp, "센서 패킷 수신");

                // TODO: ORB-SLAM3로부터 실제 포즈 결과 수신
                yield PoseResult {
                    timestamp: packet.timestamp,
                    position: None,
                    orientation: None,
                    state: 3, // INITIALIZING
                };
            }
        };

        Ok(Response::new(Box::pin(output) as Self::StreamSensorStream))
    }
}

#[derive(Default)]
pub struct SyncServiceImpl;

#[tonic::async_trait]
impl SyncService for SyncServiceImpl {
    async fn start(
        &self,
        request: Request<StartSession>,
    ) -> Result<Response<SessionResponse>, Status> {
        let req = request.into_inner();
        info!(session_id = %req.session_id, "세션 시작 요청");
        // TODO: ROS2 노드 초기화, ORB-SLAM3 프로세스 시작
        Ok(Response::new(SessionResponse {
            session_id: req.session_id,
            state: SessionState::Active.into(),
            message: "Session started".into(),
        }))
    }

    async fn stop(
        &self,
        request: Request<StopSession>,
    ) -> Result<Response<SessionResponse>, Status> {
        let req = request.into_inner();
        info!(session_id = %req.session_id, "세션 중지 요청");
        // TODO: 녹화 중지, ROS2 정리
        Ok(Response::new(SessionResponse {
            session_id: req.session_id,
            state: SessionState::Idle.into(),
            message: "Session stopped".into(),
        }))
    }

    async fn get_status(
        &self,
        _request: Request<GetStatusRequest>,
    ) -> Result<Response<SessionResponse>, Status> {
        // TODO: 실제 상태 조회
        Ok(Response::new(SessionResponse {
            session_id: String::new(),
            state: SessionState::Idle.into(),
            message: "Idle".into(),
        }))
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt::init();

    let addr = "[::1]:50051".parse()?;
    info!(%addr, "bridge_node gRPC 서버 시작");

    Server::builder()
        .add_service(SensorServiceServer::new(SensorServiceImpl::default()))
        .add_service(SyncServiceServer::new(SyncServiceImpl::default()))
        .serve_with_shutdown(addr, async {
            tokio::signal::ctrl_c().await.ok();
            info!("종료 시그널 수신");
        })
        .await?;

    Ok(())
}
