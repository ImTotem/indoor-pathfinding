/// UniFFI 진입점 — Kotlin/Swift 바인딩으로 노출되는 함수

mod aggregator;
mod engine;
mod grpc_client;
mod types;

use aggregator::SensorMsg;
use engine::RustCoreEngine;
pub use types::*;

uniffi::setup_scaffolding!();

/// 엔진 초기화 (앱 시작 시 1회)
#[uniffi::export]
pub fn init_engine(server_endpoint: String) {
    RustCoreEngine::init(server_endpoint);
}

/// 매핑 세션 시작 — 서버가 session_id 생성
#[uniffi::export]
pub fn start_mapping_session(map_id: String) -> Result<(), RustCoreError> {
    RustCoreEngine::get().start_mapping_session(map_id)
}

/// Localization 세션 시작 — 서버가 session_id 생성
#[uniffi::export]
pub fn start_localization_session(map_id: String) -> Result<(), RustCoreError> {
    RustCoreEngine::get().start_localization_session(map_id)
}

/// 현재 세션 종료 — gRPC 스트림 닫기 + SessionService.Stop
#[uniffi::export]
pub fn stop_session() -> Result<(), RustCoreError> {
    RustCoreEngine::get().stop_session()
}

/// 카메라 프레임 push (Native에서 호출)
#[uniffi::export]
pub fn push_frame(
    timestamp: f64,
    image_data: Vec<u8>,
    fx: f64,
    fy: f64,
    cx: f64,
    cy: f64,
) {
    RustCoreEngine::get().push_sensor(SensorMsg::Frame {
        timestamp,
        image_data,
        fx,
        fy,
        cx,
        cy,
    });
}

/// IMU 데이터 push (Native에서 호출)
#[uniffi::export]
pub fn push_imu(
    timestamp: f64,
    ax: f64,
    ay: f64,
    az: f64,
    gx: f64,
    gy: f64,
    gz: f64,
) {
    RustCoreEngine::get().push_sensor(SensorMsg::Imu {
        timestamp,
        ax,
        ay,
        az,
        gx,
        gy,
        gz,
    });
}

/// 기압계 데이터 push (Native에서 호출)
#[uniffi::export]
pub fn push_barometer(timestamp: f64, pressure: f64) {
    RustCoreEngine::get().push_sensor(SensorMsg::Barometer {
        timestamp,
        pressure,
    });
}

/// 엔진 상태 조회 (Kotlin 폴링용)
#[uniffi::export]
pub fn get_status() -> EngineStatus {
    RustCoreEngine::get().get_status()
}
