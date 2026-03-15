use std::pin::Pin;

use tokio_stream::Stream;
use tonic::{Request, Response, Status, Streaming};
use tracing::info;

use indoor_pathfinding_protocols::localization::{
    LocalizationPacket, LocalizationResponse, LocalizationState,
};
use indoor_pathfinding_protocols::service::localization_service_server::LocalizationService;

#[derive(Default)]
pub struct LocalizationServiceImpl;

#[tonic::async_trait]
impl LocalizationService for LocalizationServiceImpl {
    type LocalizeStream =
        Pin<Box<dyn Stream<Item = Result<LocalizationResponse, Status>> + Send + 'static>>;

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
                yield LocalizationResponse {
                    timestamp: packet.timestamp,
                    pose: None,
                    confidence: 0.0,
                    state: LocalizationState::Unspecified.into(),
                };
            }
        };

        Ok(Response::new(Box::pin(output) as Self::LocalizeStream))
    }
}
