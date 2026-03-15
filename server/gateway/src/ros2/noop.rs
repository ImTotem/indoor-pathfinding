use tracing::warn;

/// ROS2 미설치 환경용 no-op 퍼블리셔
pub struct Ros2Publisher;

impl Ros2Publisher {
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        warn!("ROS2 기능이 비활성화되어 있습니다. --features ros2 로 빌드하세요.");
        Ok(Self)
    }

    pub fn publish_image(&self, _session_id: &str, _timestamp: f64, _data: &[u8]) {}

    pub fn publish_imu(
        &self,
        _session_id: &str,
        _timestamp: f64,
        _accel: [f64; 3],
        _gyro: [f64; 3],
    ) {}

    pub fn publish_camera_info(
        &self,
        _session_id: &str,
        _fx: f64,
        _fy: f64,
        _cx: f64,
        _cy: f64,
    ) {}

    pub fn publish_barometer(&self, _session_id: &str, _timestamp: f64, _pressure: f64) {}

    pub fn spin_once(&self) {}
}
