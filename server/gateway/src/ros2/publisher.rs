use r2r::{sensor_msgs, std_msgs, QosProfile};
use tokio::sync::mpsc;
use tracing::info;

enum PublishCommand {
    Image {
        timestamp: f64,
        data: Vec<u8>,
    },
    Imu {
        timestamp: f64,
        accel: [f64; 3],
        gyro: [f64; 3],
    },
    CameraInfo {
        fx: f64,
        fy: f64,
        cx: f64,
        cy: f64,
    },
    Barometer {
        timestamp: f64,
        pressure: f64,
    },
}

pub struct Ros2Publisher {
    tx: mpsc::UnboundedSender<PublishCommand>,
}

impl Ros2Publisher {
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let (tx, mut rx) = mpsc::unbounded_channel::<PublishCommand>();

        std::thread::spawn(move || {
            let ctx = r2r::Context::create().expect("ROS2 Context 생성 실패");
            let mut node = r2r::Node::create(ctx, "gateway", "").expect("ROS2 Node 생성 실패");

            let image_pub = node
                .create_publisher::<sensor_msgs::msg::CompressedImage>(
                    "/slam/image/compressed",
                    QosProfile::default(),
                )
                .expect("이미지 퍼블리셔 생성 실패");

            let imu_pub = node
                .create_publisher::<sensor_msgs::msg::Imu>(
                    "/slam/imu",
                    QosProfile::default()
                )
                .expect("IMU 퍼블리셔 생성 실패");

            let camera_info_pub = node
                .create_publisher::<sensor_msgs::msg::CameraInfo>(
                    "/slam/camera_info",
                    QosProfile::default(),
                )
                .expect("CameraInfo 퍼블리셔 생성 실패");

            let barometer_pub = node
                .create_publisher::<sensor_msgs::msg::FluidPressure>(
                    "/slam/barometer",
                    QosProfile::default(),
                )
                .expect("기압계 퍼블리셔 생성 실패");

            info!("ROS2 퍼블리셔 초기화 완료");

            loop {
                node.spin_once(std::time::Duration::from_millis(1));

                while let Ok(cmd) = rx.try_recv() {
                    match cmd {
                        PublishCommand::Image { timestamp, data } => {
                            let (sec, nanosec) = to_stamp(timestamp);
                            let msg = sensor_msgs::msg::CompressedImage {
                                header: make_header(sec, nanosec, "camera"),
                                format: "png".to_string(),
                                data,
                            };
                            if let Err(e) = image_pub.publish(&msg) {
                                tracing::error!("이미지 발행 실패: {e}");
                            }
                        }
                        PublishCommand::Imu {
                            timestamp,
                            accel,
                            gyro,
                        } => {
                            let (sec, nanosec) = to_stamp(timestamp);
                            let msg = sensor_msgs::msg::Imu {
                                header: make_header(sec, nanosec, "imu"),
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
                            if let Err(e) = imu_pub.publish(&msg) {
                                tracing::error!("IMU 발행 실패: {e}");
                            }
                        }
                        PublishCommand::CameraInfo { fx, fy, cx, cy } => {
                            let msg = sensor_msgs::msg::CameraInfo {
                                header: make_header(0, 0, "camera"),
                                width: 0,
                                height: 0,
                                k: vec![fx, 0.0, cx, 0.0, fy, cy, 0.0, 0.0, 1.0],
                                ..Default::default()
                            };
                            if let Err(e) = camera_info_pub.publish(&msg) {
                                tracing::error!("CameraInfo 발행 실패: {e}");
                            }
                        }
                        PublishCommand::Barometer {
                            timestamp,
                            pressure,
                        } => {
                            let (sec, nanosec) = to_stamp(timestamp);
                            let msg = sensor_msgs::msg::FluidPressure {
                                header: make_header(sec, nanosec, "barometer"),
                                fluid_pressure: pressure,
                                variance: 0.0,
                            };
                            if let Err(e) = barometer_pub.publish(&msg) {
                                tracing::error!("기압계 발행 실패: {e}");
                            }
                        }
                    }
                }
            }
        });

        Ok(Self { tx })
    }

    pub fn publish_image(&self, _session_id: &str, timestamp: f64, data: &[u8]) {
        let _ = self.tx.send(PublishCommand::Image {
            timestamp,
            data: data.to_vec(),
        });
    }

    pub fn publish_imu(&self, _session_id: &str, timestamp: f64, accel: [f64; 3], gyro: [f64; 3]) {
        let _ = self.tx.send(PublishCommand::Imu {
            timestamp,
            accel,
            gyro,
        });
    }

    pub fn publish_camera_info(&self, _session_id: &str, fx: f64, fy: f64, cx: f64, cy: f64) {
        let _ = self.tx.send(PublishCommand::CameraInfo { fx, fy, cx, cy });
    }

    pub fn publish_barometer(&self, _session_id: &str, timestamp: f64, pressure: f64) {
        let _ = self.tx.send(PublishCommand::Barometer {
            timestamp,
            pressure,
        });
    }

    pub fn spin_once(&self) {
        // ROS2 spin은 별도 스레드에서 처리
    }
}

fn to_stamp(timestamp: f64) -> (i32, u32) {
    let sec = timestamp as i32;
    let nanosec = ((timestamp - sec as f64) * 1e9) as u32;
    (sec, nanosec)
}

fn make_header(sec: i32, nanosec: u32, frame_id: &str) -> std_msgs::msg::Header {
    std_msgs::msg::Header {
        stamp: r2r::builtin_interfaces::msg::Time { sec, nanosec },
        frame_id: frame_id.to_string(),
    }
}
