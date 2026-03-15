use r2r::{sensor_msgs, std_msgs, QosProfile};
use std::sync::{Arc, Mutex};
use tracing::info;

pub struct Ros2Publisher {
    node: Arc<Mutex<r2r::Node>>,
    image_pub: r2r::Publisher<sensor_msgs::msg::CompressedImage>,
    imu_pub: r2r::Publisher<sensor_msgs::msg::Imu>,
    camera_info_pub: r2r::Publisher<sensor_msgs::msg::CameraInfo>,
}

impl Ros2Publisher {
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let ctx = r2r::Context::create()?;
        let mut node = r2r::Node::create(ctx, "gateway", "")?;

        let image_pub = node.create_publisher::<sensor_msgs::msg::CompressedImage>(
            "/slam/image/compressed",
            QosProfile::default(),
        )?;
        let imu_pub = node.create_publisher::<sensor_msgs::msg::Imu>(
            "/slam/imu",
            QosProfile::default(),
        )?;
        let camera_info_pub = node.create_publisher::<sensor_msgs::msg::CameraInfo>(
            "/slam/camera_info",
            QosProfile::default(),
        )?;

        info!("ROS2 퍼블리셔 초기화 완료");

        Ok(Self {
            node: Arc::new(Mutex::new(node)),
            image_pub,
            imu_pub,
            camera_info_pub,
        })
    }

    pub fn publish_image(&self, _session_id: &str, timestamp: f64, data: &[u8]) {
        let secs = timestamp as i32;
        let nanosecs = ((timestamp - secs as f64) * 1e9) as u32;

        let msg = sensor_msgs::msg::CompressedImage {
            header: std_msgs::msg::Header {
                stamp: r2r::builtin_interfaces::msg::Time {
                    sec: secs,
                    nanosec: nanosecs,
                },
                frame_id: "camera".to_string(),
            },
            format: "jpeg".to_string(),
            data: data.to_vec(),
        };

        if let Err(e) = self.image_pub.publish(&msg) {
            tracing::error!("이미지 발행 실패: {e}");
        }
    }

    pub fn publish_imu(
        &self,
        _session_id: &str,
        timestamp: f64,
        accel: [f64; 3],
        gyro: [f64; 3],
    ) {
        let secs = timestamp as i32;
        let nanosecs = ((timestamp - secs as f64) * 1e9) as u32;

        let msg = sensor_msgs::msg::Imu {
            header: std_msgs::msg::Header {
                stamp: r2r::builtin_interfaces::msg::Time {
                    sec: secs,
                    nanosec: nanosecs,
                },
                frame_id: "imu".to_string(),
            },
            linear_acceleration: r2r::geometry_msgs::msg::Vector3 {
                x: accel[0],
                y: accel[1],
                z: accel[2],
            },
            angular_velocity: r2r::geometry_msgs::msg::Vector3 {
                x: gyro[0],
                y: gyro[1],
                z: gyro[2],
            },
            ..Default::default()
        };

        if let Err(e) = self.imu_pub.publish(&msg) {
            tracing::error!("IMU 발행 실패: {e}");
        }
    }

    pub fn publish_camera_info(
        &self,
        _session_id: &str,
        fx: f64,
        fy: f64,
        cx: f64,
        cy: f64,
    ) {
        let msg = sensor_msgs::msg::CameraInfo {
            header: std_msgs::msg::Header {
                frame_id: "camera".to_string(),
                ..Default::default()
            },
            width: 0,
            height: 0,
            k: [fx, 0.0, cx, 0.0, fy, cy, 0.0, 0.0, 1.0],
            ..Default::default()
        };

        if let Err(e) = self.camera_info_pub.publish(&msg) {
            tracing::error!("CameraInfo 발행 실패: {e}");
        }
    }

    pub fn spin_once(&self) {
        if let Ok(mut node) = self.node.lock() {
            node.spin_once(std::time::Duration::from_millis(1));
        }
    }
}
