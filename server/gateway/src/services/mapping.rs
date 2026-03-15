use std::pin::Pin;

use tokio_stream::Stream;
use tonic::{Request, Response, Status, Streaming};
use tracing::info;

use indoor_pathfinding_protocols::mapping::{MappingPacket, MappingResponse, MappingState};
use indoor_pathfinding_protocols::service::mapping_service_server::MappingService;

#[derive(Default)]
pub struct MappingServiceImpl;

#[tonic::async_trait]
impl MappingService for MappingServiceImpl {
    type StreamMappingStream =
        Pin<Box<dyn Stream<Item = Result<MappingResponse, Status>> + Send + 'static>>;

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
                yield MappingResponse {
                    timestamp: packet.timestamp,
                    pose: None,
                    state: MappingState::Initializing.into(),
                };
            }
        };

        Ok(Response::new(Box::pin(output) as Self::StreamMappingStream))
    }
}
