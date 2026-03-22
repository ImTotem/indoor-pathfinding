use std::sync::Arc;
use tonic::{Request, Response, Status};
use tracing::info;
use uuid::Uuid;

use indoor_pathfinding_protocols::service::session_service_server::SessionService;
use indoor_pathfinding_protocols::session::{
    CleanupStaleRequest, GetStatusRequest, SessionResponse, SessionState, SetTimeOffsetRequest,
    StartSessionPacket, StopSessionPacket, SyncTimeRequest, SyncTimeResponse,
};

use crate::session_manager::{SessionManager, SessionType};

pub struct SessionServiceImpl {
    manager: Arc<SessionManager>,
}

impl SessionServiceImpl {
    pub fn new(manager: Arc<SessionManager>) -> Self {
        Self { manager }
    }
}

fn generate_session_id() -> String {
    format!("s{}", Uuid::new_v4().simple())
}

#[tonic::async_trait]
impl SessionService for SessionServiceImpl {
    async fn start(
        &self,
        request: Request<StartSessionPacket>,
    ) -> Result<Response<SessionResponse>, Status> {
        let req = request.into_inner();
        let session_id = generate_session_id();
        info!(session_id = %session_id, map_id = %req.map_id, r#type = req.r#type, "세션 시작 요청");

        let session_type = match req.r#type {
            0 => SessionType::Mapping,
            1 => SessionType::Localization,
            _ => return Err(Status::invalid_argument("알 수 없는 세션 타입")),
        };

        self.manager
            .start_session(session_id.clone(), req.map_id, session_type)
            .await
            .map_err(|e| Status::already_exists(e))?;

        Ok(Response::new(SessionResponse {
            session_id,
            state: SessionState::Active.into(),
            message: "Session started".into(),
        }))
    }

    async fn stop(
        &self,
        request: Request<StopSessionPacket>,
    ) -> Result<Response<SessionResponse>, Status> {
        let req = request.into_inner();
        info!(session_id = %req.session_id, "세션 중지 요청");

        match self.manager.stop_session(&req.session_id).await {
            Ok(_) => Ok(Response::new(SessionResponse {
                session_id: req.session_id,
                state: SessionState::Idle.into(),
                message: "Session stopped".into(),
            })),
            Err(_) => {
                // 이미 정리됨 (리퍼 or 스트림 종료) → 멱등 성공
                info!(session_id = %req.session_id, "세션 이미 정리됨");
                Ok(Response::new(SessionResponse {
                    session_id: req.session_id,
                    state: SessionState::Idle.into(),
                    message: "Session already stopped".into(),
                }))
            }
        }
    }

    async fn get_status(
        &self,
        _request: Request<GetStatusRequest>,
    ) -> Result<Response<SessionResponse>, Status> {
        if let Some(session) = self.manager.get_active_session().await {
            Ok(Response::new(SessionResponse {
                session_id: session.session_id,
                state: SessionState::Active.into(),
                message: format!("Active: {:?}", session.session_type),
            }))
        } else {
            Ok(Response::new(SessionResponse {
                session_id: String::new(),
                state: SessionState::Idle.into(),
                message: "Idle".into(),
            }))
        }
    }

    async fn sync_time(
        &self,
        request: Request<SyncTimeRequest>,
    ) -> Result<Response<SyncTimeResponse>, Status> {
        let req = request.into_inner();
        self.manager
            .get_session(&req.session_id)
            .await
            .ok_or_else(|| Status::not_found("세션을 찾을 수 없습니다"))?;

        let server_timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs_f64();

        Ok(Response::new(SyncTimeResponse { server_timestamp }))
    }

    async fn set_time_offset(
        &self,
        request: Request<SetTimeOffsetRequest>,
    ) -> Result<Response<SessionResponse>, Status> {
        let req = request.into_inner();
        self.manager
            .set_clock_offset(&req.session_id, req.offset_sec)
            .await
            .map_err(|e| Status::not_found(e))?;

        info!(session_id = %req.session_id, offset = req.offset_sec, "Clock offset 설정");

        Ok(Response::new(SessionResponse {
            session_id: req.session_id,
            state: SessionState::Active.into(),
            message: format!("Clock offset: {:.6}s", req.offset_sec),
        }))
    }

    async fn cleanup_stale(
        &self,
        _request: Request<CleanupStaleRequest>,
    ) -> Result<Response<SessionResponse>, Status> {
        info!("스테일 세션 정리 요청");
        let cleaned = self.manager.cleanup_all_sessions().await;
        let message = if cleaned.is_empty() {
            "No stale sessions".to_string()
        } else {
            format!("Cleaned {} session(s)", cleaned.len())
        };

        Ok(Response::new(SessionResponse {
            session_id: String::new(),
            state: SessionState::Idle.into(),
            message,
        }))
    }
}
