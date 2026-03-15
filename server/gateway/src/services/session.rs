use std::sync::Arc;
use tonic::{Request, Response, Status};
use tracing::info;
use uuid::Uuid;

use indoor_pathfinding_protocols::service::session_service_server::SessionService;
use indoor_pathfinding_protocols::session::{
    GetStatusRequest, SessionResponse, SessionState, StartSessionPacket, StopSessionPacket,
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

/// session_id 생성: "s" + 하이픈 없는 UUID (ROS2 토픽 이름 규칙 충족)
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

        self.manager
            .stop_session(&req.session_id)
            .await
            .map_err(|e| Status::not_found(e))?;

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
}
