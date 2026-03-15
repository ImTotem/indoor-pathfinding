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
        // TODO: SessionType에 따라 분기
        //  - MAPPING: MASt3R-SLAM 초기화, rosbag2 녹화 시작
        //  - LOCALIZATION: map_id에 해당하는 맵 파일 로드, RoMa 초기화
        // TODO: 세션 상태를 관리하는 구조체에 등록
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
        // TODO: SLAM 엔진 정리, rosbag2 녹화 중지, 세션 상태 제거
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
        // TODO: 현재 활성 세션 조회, 없으면 Idle 반환
        Ok(Response::new(SessionResponse {
            session_id: String::new(),
            state: SessionState::Idle.into(),
            message: "Idle".into(),
        }))
    }
}
