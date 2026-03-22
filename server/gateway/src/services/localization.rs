use std::pin::Pin;
use std::sync::Arc;

use tokio::sync::mpsc;
use tokio_stream::Stream;
use tonic::{Request, Response, Status, Streaming};
use tracing::{info, warn};

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

        let (tx, rx) = mpsc::channel::<Result<LocalizationResponse, Status>>(32);

        tokio::spawn(async move {
            let mut session_id: Option<String> = None;
            let mut offset = 0.0_f64;
            let mut offset_loaded = false;

            let result: Result<(), Status> = async {
                while let Some(packet) = stream.message().await? {
                    manager
                        .validate_session(&packet.session_id, SessionType::Localization)
                        .await?;

                    if session_id.is_none() {
                        session_id = Some(packet.session_id.clone());
                    }

                    if !offset_loaded {
                        offset = manager
                            .get_clock_offset(&packet.session_id)
                            .await
                            .unwrap_or(0.0);
                        offset_loaded = true;
                        info!(session = %packet.session_id, offset, "Clock offset 적용");
                    }

                    let pub_ = manager.publisher();
                    let sid = &packet.session_id;

                    pub_.publish_image(sid, packet.timestamp + offset, &packet.query_image);

                    if let Some(intr) = &packet.intrinsics {
                        pub_.publish_camera_info(sid, intr.fx, intr.fy, intr.cx, intr.cy);
                    }

                    if let Some(baro) = &packet.barometer {
                        pub_.publish_barometer(sid, baro.timestamp + offset, baro.pressure);
                    }

                    let response = LocalizationResponse {
                        timestamp: packet.timestamp,
                        pose: None,
                        confidence: 0.0,
                        state: LocalizationState::Unspecified.into(),
                    };

                    if tx.send(Ok(response)).await.is_err() {
                        break;
                    }
                }
                Ok(())
            }
            .await;

            if let Some(sid) = &session_id {
                match result {
                    Ok(()) => info!(session_id = %sid, "로컬라이제이션 스트림 종료"),
                    Err(ref e) => {
                        warn!(session_id = %sid, error = %e, "로컬라이제이션 스트림 에러 종료")
                    }
                }
                let _ = manager.stop_session(sid).await;
            }
        });

        let output = tokio_stream::wrappers::ReceiverStream::new(rx);
        Ok(Response::new(Box::pin(output) as Self::LocalizeStream))
    }
}
