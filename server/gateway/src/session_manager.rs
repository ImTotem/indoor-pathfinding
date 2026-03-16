use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{Mutex, RwLock};
use tracing::info;

use crate::ros2::{Ros2Publisher, Rosbag2Recorder};

const ROSBAG2_OUTPUT_DIR: &str = "/workspace/rosbag2";

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum SessionType {
    Mapping,
    Localization,
}

#[derive(Debug, Clone)]
pub struct Session {
    pub session_id: String,
    pub map_id: String,
    pub session_type: SessionType,
    pub clock_offset_sec: Option<f64>,
}

pub struct SessionManager {
    sessions: RwLock<HashMap<String, Session>>,
    publisher: Arc<Ros2Publisher>,
    recorder: Mutex<Rosbag2Recorder>,
}

impl SessionManager {
    pub fn new(publisher: Arc<Ros2Publisher>) -> Self {
        Self {
            sessions: RwLock::new(HashMap::new()),
            publisher,
            recorder: Mutex::new(Rosbag2Recorder::new()),
        }
    }

    pub async fn start_session(
        &self,
        session_id: String,
        map_id: String,
        session_type: SessionType,
    ) -> Result<(), String> {
        let mut sessions = self.sessions.write().await;

        if sessions.contains_key(&session_id) {
            return Err(format!("세션이 이미 존재합니다: {session_id}"));
        }

        let prefix = match session_type {
            SessionType::Mapping => format!("/slam/mapping/{session_id}"),
            SessionType::Localization => format!("/slam/localization/{session_id}"),
        };

        self.publisher.create_session_publishers(&session_id, &prefix, session_type);

        self.recorder
            .lock()
            .await
            .start_recording(&session_id, session_type, ROSBAG2_OUTPUT_DIR);

        let session = Session {
            session_id: session_id.clone(),
            map_id,
            session_type,
            clock_offset_sec: None,
        };

        info!(session_id = %session_id, ?session_type, "세션 등록");
        sessions.insert(session_id, session);

        Ok(())
    }

    pub async fn stop_session(&self, session_id: &str) -> Result<Session, String> {
        let mut sessions = self.sessions.write().await;

        let session = sessions
            .remove(session_id)
            .ok_or_else(|| format!("세션을 찾을 수 없습니다: {session_id}"))?;

        self.publisher.remove_session_publishers(session_id);
        self.recorder.lock().await.stop_recording(session_id);

        info!(session_id = %session_id, "세션 제거");
        Ok(session)
    }

    pub async fn get_session(&self, session_id: &str) -> Option<Session> {
        self.sessions.read().await.get(session_id).cloned()
    }

    pub async fn validate_session(
        &self,
        session_id: &str,
        expected_type: SessionType,
    ) -> Result<Session, tonic::Status> {
        let session = self.get_session(session_id).await.ok_or_else(|| {
            tonic::Status::not_found(format!("세션을 찾을 수 없습니다: {session_id}"))
        })?;

        if session.session_type != expected_type {
            return Err(tonic::Status::invalid_argument(format!(
                "{expected_type:?} 세션이 아닙니다"
            )));
        }

        Ok(session)
    }

    pub async fn get_active_session(&self) -> Option<Session> {
        self.sessions.read().await.values().next().cloned()
    }

    pub async fn set_clock_offset(&self, session_id: &str, offset: f64) -> Result<(), String> {
        let mut sessions = self.sessions.write().await;
        let session = sessions
            .get_mut(session_id)
            .ok_or_else(|| format!("세션을 찾을 수 없습니다: {session_id}"))?;
        session.clock_offset_sec = Some(offset);
        Ok(())
    }

    pub async fn get_clock_offset(&self, session_id: &str) -> Option<f64> {
        self.sessions
            .read()
            .await
            .get(session_id)
            .and_then(|s| s.clock_offset_sec)
    }

    pub fn publisher(&self) -> &Ros2Publisher {
        &self.publisher
    }
}
