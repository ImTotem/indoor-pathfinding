/// tonic gRPC 클라이언트 — gateway 서버와 통신

use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;
use tonic::transport::Channel;
use tracing::info;

use indoor_pathfinding_protocols::localization::{LocalizationPacket, LocalizationResponse};
use indoor_pathfinding_protocols::mapping::{MappingPacket, MappingResponse};
use indoor_pathfinding_protocols::service::{
    localization_service_client::LocalizationServiceClient,
    mapping_service_client::MappingServiceClient,
    session_service_client::SessionServiceClient,
};
use indoor_pathfinding_protocols::session::{StartSessionPacket, StopSessionPacket};

use crate::types::RustCoreError;

pub struct GatewayClient {
    channel: Channel,
}

/// 세션 타입 (gRPC proto enum 매핑)
pub enum SessionKind {
    Mapping,
    Localization,
}

impl GatewayClient {
    pub async fn connect(endpoint: &str) -> Result<Self, RustCoreError> {
        info!("Connecting to gateway: {}", endpoint);
        let channel = Channel::from_shared(endpoint.to_string())
            .map_err(|e| RustCoreError::GrpcError {
                reason: e.to_string(),
            })?
            .connect()
            .await
            .map_err(|e| RustCoreError::GrpcError {
                reason: format!("Failed to connect: {}", e),
            })?;
        info!("Connected to gateway");
        Ok(Self { channel })
    }

    /// SessionService.Start 호출 → 서버가 생성한 session_id 반환
    pub async fn start_session(
        &self,
        map_id: &str,
        kind: SessionKind,
    ) -> Result<String, RustCoreError> {
        let mut client = SessionServiceClient::new(self.channel.clone());
        let request = StartSessionPacket {
            session_id: String::new(),
            map_id: map_id.to_string(),
            r#type: match kind {
                SessionKind::Mapping => 0,
                SessionKind::Localization => 1,
            },
        };
        let response = client
            .start(request)
            .await
            .map_err(|e| RustCoreError::GrpcError {
                reason: e.to_string(),
            })?;
        let session_id = response.into_inner().session_id;
        info!("Session started: {}", session_id);
        Ok(session_id)
    }

    /// SessionService.Stop 호출
    pub async fn stop_session(&self, session_id: &str) -> Result<(), RustCoreError> {
        let mut client = SessionServiceClient::new(self.channel.clone());
        let request = StopSessionPacket {
            session_id: session_id.to_string(),
        };
        client
            .stop(request)
            .await
            .map_err(|e| RustCoreError::GrpcError {
                reason: e.to_string(),
            })?;
        info!("Session stopped: {}", session_id);
        Ok(())
    }

    /// MappingService.StreamMapping 양방향 스트림 오픈
    pub async fn open_mapping_stream(
        &self,
    ) -> Result<
        (
            mpsc::Sender<MappingPacket>,
            tonic::Streaming<MappingResponse>,
        ),
        RustCoreError,
    > {
        let mut client = MappingServiceClient::new(self.channel.clone());
        let (tx, rx) = mpsc::channel(128);
        let stream = ReceiverStream::new(rx);
        let response = client
            .stream_mapping(stream)
            .await
            .map_err(|e| RustCoreError::GrpcError {
                reason: e.to_string(),
            })?;
        Ok((tx, response.into_inner()))
    }

    /// LocalizationService.Localize 양방향 스트림 오픈
    pub async fn open_localization_stream(
        &self,
    ) -> Result<
        (
            mpsc::Sender<LocalizationPacket>,
            tonic::Streaming<LocalizationResponse>,
        ),
        RustCoreError,
    > {
        let mut client = LocalizationServiceClient::new(self.channel.clone());
        let (tx, rx) = mpsc::channel(128);
        let stream = ReceiverStream::new(rx);
        let response = client
            .localize(stream)
            .await
            .map_err(|e| RustCoreError::GrpcError {
                reason: e.to_string(),
            })?;
        Ok((tx, response.into_inner()))
    }
}
