mod ros2;
mod services;
mod session_manager;

use std::sync::Arc;
use tonic::transport::Server;
use tracing::info;

use indoor_pathfinding_protocols::service::{
    localization_service_server::LocalizationServiceServer,
    mapping_service_server::MappingServiceServer, session_service_server::SessionServiceServer,
};

use ros2::Ros2Publisher;
use services::localization::LocalizationServiceImpl;
use services::mapping::MappingServiceImpl;
use services::session::SessionServiceImpl;
use session_manager::SessionManager;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt::init();

    let publisher = Arc::new(Ros2Publisher::new()?);
    let manager = Arc::new(SessionManager::new(publisher));

    // 백그라운드 리퍼 (30초 간격, 120초 무활동 세션 정리)
    let _reaper = manager.spawn_reaper();

    let addr = "[::]:50051".parse()?;
    info!(%addr, "gateway gRPC 서버 시작");

    Server::builder()
        .add_service(MappingServiceServer::new(MappingServiceImpl::new(
            manager.clone(),
        )))
        .add_service(LocalizationServiceServer::new(
            LocalizationServiceImpl::new(manager.clone()),
        ))
        .add_service(SessionServiceServer::new(SessionServiceImpl::new(
            manager.clone(),
        )))
        .serve_with_shutdown(addr, async {
            tokio::signal::ctrl_c().await.ok();
            info!("종료 시그널 수신");
        })
        .await?;

    // 서버 종료 → 남은 세션 전부 정리 (rosbag2 SIGINT)
    info!("서버 종료 중, 남은 세션 정리");
    manager.cleanup_all_sessions().await;

    Ok(())
}
