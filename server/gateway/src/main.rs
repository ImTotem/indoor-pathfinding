use std::pin::Pin;

use tokio_stream::Stream;
use tonic::{transport::Server, Request, Response, Status, Streaming};
use tracing::info;

use indoor_pathfinding_protocols::sensor::{
    mapping_service_server::{MappingService, MappingServiceServer},
    localization_service_server::{LocalizationService, LocalizationServiceServer},
    LocalizationPacket, LocalizationResult, LocalizationState,
    MappingPacket, MappingResult, MappingState,
};
use indoor_pathfinding_protocols::sync::{
    sync_service_server::{SyncService, SyncServiceServer},
    GetStatusRequest, SessionResponse, SessionState, StartSession, StopSession,
};

// === Mapping Service ===

#[derive(Default)]
pub struct MappingServiceImpl;

#[tonic::async_trait]
impl MappingService for MappingServiceImpl {
    type StreamMappingStream =
        Pin<Box<dyn Stream<Item = Result<MappingResult, Status>> + Send + 'static>>;

    async fn stream_mapping(
        &self,
        request: Request<Streaming<MappingPacket>>,
    ) -> Result<Response<Self::StreamMappingStream>, Status> {
        info!("맵 생성 스트리밍 연결");
        let mut stream = request.into_inner();

        let output = async_stream::try_stream! {
            while let Some(packet) = stream.message().await? {
                info!(session = %packet.session_id, ts = packet.timestamp, "매핑 패킷 수신");

                // TODO: ROS2 토픽으로 발행 → MASt3R-SLAM 처리 → 결과 수신
                yield MappingResult {
                    timestamp: packet.timestamp,
                    position: None,
                    orientation: None,
                    state: MappingState::Initializing.into(),
                };
            }
        };

        Ok(Response::new(Box::pin(output) as Self::StreamMappingStream))
    }
}

// === Localization Service ===

#[derive(Default)]
pub struct LocalizationServiceImpl;

#[tonic::async_trait]
impl LocalizationService for LocalizationServiceImpl {
    type LocalizeStream =
        Pin<Box<dyn Stream<Item = Result<LocalizationResult, Status>> + Send + 'static>>;

    async fn localize(
        &self,
        request: Request<Streaming<LocalizationPacket>>,
    ) -> Result<Response<Self::LocalizeStream>, Status> {
        info!("위치 탐색 스트리밍 연결");
        let mut stream = request.into_inner();

        let output = async_stream::try_stream! {
            while let Some(packet) = stream.message().await? {
                info!(session = %packet.session_id, ts = packet.timestamp, "로컬라이제이션 패킷 수신");

                // TODO: ROS2 토픽으로 발행 → RoMa 처리 → 결과 수신
                yield LocalizationResult {
                    timestamp: packet.timestamp,
                    position: None,
                    orientation: None,
                    confidence: 0.0,
                    state: LocalizationState::Unspecified.into(),
                };
            }
        };

        Ok(Response::new(Box::pin(output) as Self::LocalizeStream))
    }
}

// === Sync Service ===

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
    info!(%addr, "gateway gRPC 서버 시작");

    Server::builder()
        .add_service(MappingServiceServer::new(MappingServiceImpl::default()))
        .add_service(LocalizationServiceServer::new(LocalizationServiceImpl::default()))
        .add_service(SyncServiceServer::new(SyncServiceImpl::default()))
        .serve_with_shutdown(addr, async {
            tokio::signal::ctrl_c().await.ok();
            info!("종료 시그널 수신");
        })
        .await?;

    Ok(())
}
