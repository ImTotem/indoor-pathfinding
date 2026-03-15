use crate::session_manager::SessionType;

pub enum PublishCommand {
    CreateSession {
        session_id: String,
        prefix: String,
        session_type: SessionType,
    },
    RemoveSession {
        session_id: String,
    },
    Image {
        session_id: String,
        timestamp: f64,
        data: Vec<u8>,
    },
    Imu {
        session_id: String,
        timestamp: f64,
        accel: [f64; 3],
        gyro: [f64; 3],
    },
    CameraInfo {
        session_id: String,
        fx: f64,
        fy: f64,
        cx: f64,
        cy: f64,
    },
    Barometer {
        session_id: String,
        timestamp: f64,
        pressure: f64,
    },
}
