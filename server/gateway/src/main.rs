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

    Ok(())
}
