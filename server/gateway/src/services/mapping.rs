use std::pin::Pin;
use std::sync::Arc;

use tokio_stream::Stream;
use tonic::{Request, Response, Status, Streaming};
use tracing::info;

use indoor_pathfinding_protocols::mapping::{MappingPacket, MappingResponse, MappingState};
use indoor_pathfinding_protocols::service::mapping_service_server::MappingService;

use crate::session_manager::{SessionManager, SessionType};

pub struct MappingServiceImpl {
    manager: Arc<SessionManager>,
}

impl MappingServiceImpl {
    pub fn new(manager: Arc<SessionManager>) -> Self {
        Self { manager }
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
        let manager = self.manager.clone();

        let output = async_stream::try_stream! {
            let mut offset = 0.0_f64;
            let mut offset_loaded = false;

            while let Some(packet) = stream.message().await? {
                manager.validate_session(&packet.session_id, SessionType::Mapping).await?;

                // 첫 패킷에서 clock offset 1회 로드
                if !offset_loaded {
                    offset = manager.get_clock_offset(&packet.session_id).await.unwrap_or(0.0);
                    offset_loaded = true;
                    info!(session = %packet.session_id, offset, "Clock offset 적용");
                }

                info!(session = %packet.session_id, ts = packet.timestamp, "매핑 패킷 수신");

                let pub_ = manager.publisher();
                let sid = &packet.session_id;

                pub_.publish_image(sid, packet.timestamp + offset, &packet.image_data);

                for imu in &packet.imu_data {
                    let accel = imu.acceleration.as_ref().map(|v| [v.x, v.y, v.z]).unwrap_or_default();
                    let gyro = imu.angular_velocity.as_ref().map(|v| [v.x, v.y, v.z]).unwrap_or_default();
                    pub_.publish_imu(sid, imu.timestamp + offset, accel, gyro);
                }

                if let Some(intr) = &packet.intrinsics {
                    pub_.publish_camera_info(sid, intr.fx, intr.fy, intr.cx, intr.cy);
                }

                if let Some(baro) = &packet.barometer {
                    pub_.publish_barometer(sid, baro.timestamp + offset, baro.pressure);
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
