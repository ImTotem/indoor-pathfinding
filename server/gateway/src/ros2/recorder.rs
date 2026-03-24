use std::collections::HashMap;
use std::process::{Child, Command};
use tracing::{info, error};

use crate::session_manager::SessionType;

pub struct Rosbag2Recorder {
    processes: HashMap<String, Child>,
}

impl Rosbag2Recorder {
    pub fn new() -> Self {
        Self {
            processes: HashMap::new(),
        }
    }

    pub fn start_recording(
        &mut self,
        session_id: &str,
        session_type: SessionType,
        output_dir: &str,
    ) {
        let prefix = match session_type {
            SessionType::Mapping => format!("/slam/mapping/{session_id}"),
            SessionType::Localization => format!("/slam/localization/{session_id}"),
        };

        let mut topics = vec![
            format!("{prefix}/image/compressed"),
            format!("{prefix}/camera_info"),
            format!("{prefix}/barometer"),
        ];

        if session_type == SessionType::Mapping {
            topics.push(format!("{prefix}/imu"));
        }

        let output_path = format!("{output_dir}/{session_id}");

        let result = Command::new("bash")
            .args([
                "-c",
                &format!(
                    "source /opt/ros/$ROS_DISTRO/setup.bash && ros2 bag record -o {} {}",
                    output_path,
                    topics.join(" ")
                ),
            ])
            .spawn();

        match result {
            Ok(child) => {
                info!(session_id = %session_id, output = %output_path, "rosbag2 녹화 시작");
                self.processes.insert(session_id.to_string(), child);
            }
            Err(e) => {
                error!(session_id = %session_id, "rosbag2 녹화 시작 실패: {e}");
            }
        }
    }

    pub fn stop_recording(&mut self, session_id: &str) {
        if let Some(mut child) = self.processes.remove(session_id) {
            // SIGINT로 정상 종료
            unsafe {
                libc::kill(child.id() as i32, libc::SIGINT);
            }
            let _ = child.wait();
            info!(session_id = %session_id, "rosbag2 녹화 중지");
        }
    }
}

impl Drop for Rosbag2Recorder {
    fn drop(&mut self) {
        for (session_id, mut child) in self.processes.drain() {
            unsafe {
                libc::kill(child.id() as i32, libc::SIGINT);
            }
            let _ = child.wait();
            info!(session_id = %session_id, "rosbag2 녹화 정리");
        }
    }
}
