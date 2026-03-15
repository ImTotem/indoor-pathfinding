use r2r::sensor_msgs;
use std::collections::HashMap;
use std::sync::Mutex;
use tokio::sync::mpsc;
use tracing::info;

use super::commands::PublishCommand;
use super::messages;
use crate::session_manager::SessionType;

pub struct Ros2Publisher {
    tx: mpsc::UnboundedSender<PublishCommand>,
}

struct SessionPublishers {
    image: r2r::Publisher<sensor_msgs::msg::CompressedImage>,
    camera_info: r2r::Publisher<sensor_msgs::msg::CameraInfo>,
    barometer: r2r::Publisher<sensor_msgs::msg::FluidPressure>,
    imu: Option<r2r::Publisher<sensor_msgs::msg::Imu>>,
}

impl Ros2Publisher {
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let (tx, mut rx) = mpsc::unbounded_channel::<PublishCommand>();

        std::thread::spawn(move || {
            let ctx = r2r::Context::create().expect("ROS2 Context 생성 실패");
            let node = Mutex::new(
                r2r::Node::create(ctx, "gateway", "").expect("ROS2 Node 생성 실패"),
            );
            let mut sessions: HashMap<String, SessionPublishers> = HashMap::new();

            info!("ROS2 퍼블리셔 스레드 시작");

            loop {
                if let Ok(mut n) = node.lock() {
                    n.spin_once(std::time::Duration::from_millis(1));
                }

                while let Ok(cmd) = rx.try_recv() {
                    handle_command(&node, &mut sessions, cmd);
                }
            }
        });

        Ok(Self { tx })
    }

    pub fn create_session_publishers(&self, session_id: &str, prefix: &str, session_type: SessionType) {
        let _ = self.tx.send(PublishCommand::CreateSession {
            session_id: session_id.to_string(),
            prefix: prefix.to_string(),
            session_type,
        });
    }

    pub fn remove_session_publishers(&self, session_id: &str) {
        let _ = self.tx.send(PublishCommand::RemoveSession {
            session_id: session_id.to_string(),
        });
    }

    pub fn publish_image(&self, session_id: &str, timestamp: f64, data: &[u8]) {
        let _ = self.tx.send(PublishCommand::Image {
            session_id: session_id.to_string(),
            timestamp,
            data: data.to_vec(),
        });
    }

    pub fn publish_imu(&self, session_id: &str, timestamp: f64, accel: [f64; 3], gyro: [f64; 3]) {
        let _ = self.tx.send(PublishCommand::Imu {
            session_id: session_id.to_string(),
            timestamp,
            accel,
            gyro,
        });
    }

    pub fn publish_camera_info(&self, session_id: &str, fx: f64, fy: f64, cx: f64, cy: f64) {
        let _ = self.tx.send(PublishCommand::CameraInfo {
            session_id: session_id.to_string(),
            fx,
            fy,
            cx,
            cy,
        });
    }

    pub fn publish_barometer(&self, session_id: &str, timestamp: f64, pressure: f64) {
        let _ = self.tx.send(PublishCommand::Barometer {
            session_id: session_id.to_string(),
            timestamp,
            pressure,
        });
    }
}

fn handle_command(
    node: &Mutex<r2r::Node>,
    sessions: &mut HashMap<String, SessionPublishers>,
    cmd: PublishCommand,
) {
    match cmd {
        PublishCommand::CreateSession {
            session_id,
            prefix,
            session_type,
        } => {
            let mut n = node.lock().unwrap();
            let qos = r2r::QosProfile::default();

            let image = n
                .create_publisher(&format!("{prefix}/image/compressed"), qos.clone())
                .expect("이미지 퍼블리셔 생성 실패");
            let camera_info = n
                .create_publisher(&format!("{prefix}/camera_info"), qos.clone())
                .expect("CameraInfo 퍼블리셔 생성 실패");

            let barometer = n
                .create_publisher(&format!("{prefix}/barometer"), qos.clone())
                .expect("기압계 퍼블리셔 생성 실패");

            let imu = if session_type == SessionType::Mapping {
                Some(
                    n.create_publisher(&format!("{prefix}/imu"), qos)
                        .expect("IMU 퍼블리셔 생성 실패"),
                )
            } else {
                None
            };

            info!(session_id = %session_id, prefix = %prefix, "세션 퍼블리셔 생성");
            sessions.insert(session_id, SessionPublishers { image, camera_info, imu, barometer });
        }
        PublishCommand::RemoveSession { session_id } => {
            sessions.remove(&session_id);
            info!(session_id = %session_id, "세션 퍼블리셔 제거");
        }
        PublishCommand::Image { session_id, timestamp, data } => {
            if let Some(s) = sessions.get(&session_id) {
                let _ = s.image.publish(&messages::compressed_image(timestamp, data));
            }
        }
        PublishCommand::Imu { session_id, timestamp, accel, gyro } => {
            if let Some(s) = sessions.get(&session_id) {
                if let Some(pub_imu) = &s.imu {
                    let _ = pub_imu.publish(&messages::imu(timestamp, accel, gyro));
                }
            }
        }
        PublishCommand::CameraInfo { session_id, fx, fy, cx, cy } => {
            if let Some(s) = sessions.get(&session_id) {
                let _ = s.camera_info.publish(&messages::camera_info(fx, fy, cx, cy));
            }
        }
        PublishCommand::Barometer { session_id, timestamp, pressure } => {
            if let Some(s) = sessions.get(&session_id) {
                let _ = s.barometer.publish(&messages::fluid_pressure(timestamp, pressure));
            }
        }
    }
}
