use std::pin::Pin;
use std::sync::Arc;

use tokio_stream::Stream;
use tonic::{Request, Response, Status, Streaming};
use tracing::info;

use indoor_pathfinding_protocols::localization::{
    LocalizationPacket, LocalizationResponse, LocalizationState,
};
use indoor_pathfinding_protocols::service::localization_service_server::LocalizationService;

use crate::session_manager::{SessionManager, SessionType};

pub struct LocalizationServiceImpl {
    manager: Arc<SessionManager>,
}

impl LocalizationServiceImpl {
    pub fn new(manager: Arc<SessionManager>) -> Self {
        Self { manager }
    }
}

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
        let manager = self.manager.clone();

        let output = async_stream::try_stream! {
            while let Some(packet) = stream.message().await? {
                manager.validate_session(&packet.session_id, SessionType::Localization).await?;
                info!(session = %packet.session_id, ts = packet.timestamp, "로컬라이제이션 패킷 수신");

                let pub_ = manager.publisher();
                let sid = &packet.session_id;

                pub_.publish_image(sid, packet.timestamp, &packet.query_image);

                if let Some(intr) = &packet.intrinsics {
                    pub_.publish_camera_info(sid, intr.fx, intr.fy, intr.cx, intr.cy);
                }

                if let Some(baro) = &packet.barometer {
                    pub_.publish_barometer(sid, baro.timestamp, baro.pressure);
                }

                // TODO: RoMa 결과 수신
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
