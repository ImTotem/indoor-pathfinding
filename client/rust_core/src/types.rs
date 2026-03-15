/// UniFFI Record/Enum 타입 — Kotlin/Swift 바인딩으로 노출

#[derive(uniffi::Enum, Clone, Debug, PartialEq)]
pub enum SessionState {
    Idle,
    Mapping,
    Localizing,
    Error,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct PoseResult {
    pub x: f64,
    pub y: f64,
    pub z: f64,
    pub qx: f64,
    pub qy: f64,
    pub qz: f64,
    pub qw: f64,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct EngineStatus {
    pub state: SessionState,
    pub pose: Option<PoseResult>,
    pub frame_count: u64,
    pub total_pushed: u64,
    pub queue_full: bool,
    pub error_message: Option<String>,
}

#[derive(uniffi::Error, Debug, thiserror::Error)]
pub enum RustCoreError {
    #[error("Not connected to server")]
    NotConnected,
    #[error("Session already active")]
    SessionAlreadyActive,
    #[error("No active session")]
    NoActiveSession,
    #[error("gRPC error: {reason}")]
    GrpcError { reason: String },
    #[error("Internal error: {reason}")]
    InternalError { reason: String },
}

impl EngineStatus {
    pub fn idle() -> Self {
        Self {
            state: SessionState::Idle,
            pose: None,
            frame_count: 0,
            total_pushed: 0,
            queue_full: false,
            error_message: None,
        }
    }
}
