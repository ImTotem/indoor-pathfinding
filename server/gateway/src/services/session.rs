use tonic::{Request, Response, Status};
use tracing::info;

use indoor_pathfinding_protocols::service::session_service_server::SessionService;
use indoor_pathfinding_protocols::session::{
    GetStatusRequest, SessionResponse, SessionState, StartSessionPacket, StopSessionPacket,
};

#[derive(Default)]
pub struct SessionServiceImpl;

#[tonic::async_trait]
impl SessionService for SessionServiceImpl {
    async fn start(
        &self,
        request: Request<StartSessionPacket>,
    ) -> Result<Response<SessionResponse>, Status> {
        let req = request.into_inner();
        info!(session_id = %req.session_id, map_id = %req.map_id, r#type = req.r#type, "세션 시작 요청");
        Ok(Response::new(SessionResponse {
            session_id: req.session_id,
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
