mod ros2;
mod services;

use std::sync::Arc;
use tonic::transport::Server;
use tracing::info;

use indoor_pathfinding_protocols::service::{
    localization_service_server::LocalizationServiceServer,
    mapping_service_server::MappingServiceServer,
    session_service_server::SessionServiceServer,
};

use ros2::Ros2Publisher;
use services::localization::LocalizationServiceImpl;
use services::mapping::MappingServiceImpl;
use services::session::SessionServiceImpl;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt::init();

    let publisher = Arc::new(Ros2Publisher::new()?);

    // ROS2 spin을 백그라운드에서 실행
    let spin_publisher = publisher.clone();
    tokio::spawn(async move {
        loop {
            spin_publisher.spin_once();
            tokio::time::sleep(std::time::Duration::from_millis(1)).await;
        }
    });

    let addr = "[::]:50051".parse()?;
    info!(%addr, "gateway gRPC 서버 시작");

    Server::builder()
        .add_service(MappingServiceServer::new(MappingServiceImpl::new(
            publisher.clone(),
        )))
        .add_service(LocalizationServiceServer::new(
            LocalizationServiceImpl::default(),
        ))
        .add_service(SessionServiceServer::new(SessionServiceImpl::default()))
        .serve_with_shutdown(addr, async {
            tokio::signal::ctrl_c().await.ok();
            info!("종료 시그널 수신");
        })
        .await?;

    Ok(())
}
