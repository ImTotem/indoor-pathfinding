use std::pin::Pin;
use std::sync::Arc;

use tokio_stream::Stream;
use tonic::{Request, Response, Status, Streaming};
use tracing::info;

use indoor_pathfinding_protocols::mapping::{MappingPacket, MappingResponse, MappingState};
use indoor_pathfinding_protocols::service::mapping_service_server::MappingService;

use crate::ros2::Ros2Publisher;

pub struct MappingServiceImpl {
    publisher: Arc<Ros2Publisher>,
}

impl MappingServiceImpl {
    pub fn new(publisher: Arc<Ros2Publisher>) -> Self {
        Self { publisher }
    }
}

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
        let publisher = self.publisher.clone();

        let output = async_stream::try_stream! {
            while let Some(packet) = stream.message().await? {
                info!(session = %packet.session_id, ts = packet.timestamp, "매핑 패킷 수신");

                // 이미지 발행
                publisher.publish_image(
                    &packet.session_id,
                    packet.timestamp,
                    &packet.image_data,
                );

                // IMU 데이터 발행
                for imu in &packet.imu_data {
                    let accel = imu.acceleration.as_ref().map(|v| [v.x, v.y, v.z]).unwrap_or_default();
                    let gyro = imu.angular_velocity.as_ref().map(|v| [v.x, v.y, v.z]).unwrap_or_default();
                    publisher.publish_imu(&packet.session_id, imu.timestamp, accel, gyro);
                }

                // Intrinsics 발행
                if let Some(intr) = &packet.intrinsics {
                    publisher.publish_camera_info(
                        &packet.session_id,
                        intr.fx, intr.fy, intr.cx, intr.cy,
                    );
                }

                // TODO: MASt3R-SLAM 결과 수신
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
