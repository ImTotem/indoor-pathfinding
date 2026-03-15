use crate::session_manager::SessionType;

pub struct Rosbag2Recorder;

impl Rosbag2Recorder {
    pub fn new() -> Self {
        Self
    }

    pub fn start_recording(&mut self, _session_id: &str, _session_type: SessionType, _output_dir: &str) {}
    pub fn stop_recording(&mut self, _session_id: &str) {}
}
