use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::{Mutex, RwLock};
use tracing::{error, info, warn};

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
    pub created_at: Instant,
}

pub struct SessionManager {
    sessions: RwLock<HashMap<String, Session>>,
    publisher: Arc<Ros2Publisher>,
    recorder: Mutex<Rosbag2Recorder>,
    slam_client: reqwest::Client,
    slam_api_url: String,
}

impl SessionManager {
    pub fn new(publisher: Arc<Ros2Publisher>) -> Self {
        let slam_api_url =
            std::env::var("SLAM_API_URL").unwrap_or_else(|_| "http://localhost:8000".to_string());
        Self {
            sessions: RwLock::new(HashMap::new()),
            publisher,
            recorder: Mutex::new(Rosbag2Recorder::new()),
            slam_client: reqwest::Client::new(),
            slam_api_url,
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

        self.publisher
            .create_session_publishers(&session_id, &prefix, session_type);

        self.recorder
            .lock()
            .await
            .start_recording(&session_id, session_type, ROSBAG2_OUTPUT_DIR);

        // SLAM API에 세션 시작 알림 (실패해도 녹화는 계속)
        if session_type == SessionType::Mapping {
            self.notify_slam_start(&session_id, &map_id).await;
        }

        let session = Session {
            session_id: session_id.clone(),
            map_id,
            session_type,
            clock_offset_sec: None,
            created_at: Instant::now(),
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

        // SLAM API에 세션 종료 알림 (결과 저장 트리거)
        if session.session_type == SessionType::Mapping {
            self.notify_slam_stop(session_id).await;
        }

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

    pub async fn cleanup_all_sessions(&self) -> Vec<String> {
        let ids: Vec<String> = self.sessions.read().await.keys().cloned().collect();
        let mut cleaned = Vec::new();
        for id in ids {
            if self.stop_session(&id).await.is_ok() {
                cleaned.push(id);
            }
        }
        cleaned
    }

    pub async fn reap_inactive_sessions(&self, timeout: Duration) -> Vec<String> {
        let now = Instant::now();
        let stale: Vec<String> = {
            let sessions = self.sessions.read().await;
            if sessions.is_empty() {
                return Vec::new();
            }
            sessions
                .values()
                .filter(|s| now.duration_since(s.created_at) > timeout)
                .map(|s| s.session_id.clone())
                .collect()
        };
        let mut cleaned = Vec::new();
        for id in stale {
            if self.stop_session(&id).await.is_ok() {
                warn!(session_id = %id, "리퍼에 의해 세션 정리됨");
                cleaned.push(id);
            }
        }
        cleaned
    }

    pub fn spawn_reaper(self: &Arc<Self>) -> tokio::task::JoinHandle<()> {
        let manager = Arc::clone(self);
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(30));
            loop {
                interval.tick().await;
                manager
                    .reap_inactive_sessions(Duration::from_secs(120))
                    .await;
            }
        })
    }

    // ── SLAM API 호출 (graceful — 실패해도 녹화 계속) ──

    async fn notify_slam_start(&self, session_id: &str, map_id: &str) {
        let url = format!("{}/sessions", self.slam_api_url);
        match self
            .slam_client
            .post(&url)
            .json(&serde_json::json!({
                "session_id": session_id,
                "map_id": map_id,
            }))
            .send()
            .await
        {
            Ok(resp) if resp.status().is_success() => {
                info!(session_id = %session_id, "SLAM 세션 시작 알림 성공");
            }
            Ok(resp) => {
                warn!(session_id = %session_id, status = %resp.status(), "SLAM 세션 시작 알림 실패");
            }
            Err(e) => {
                error!(session_id = %session_id, "SLAM API 연결 실패 (녹화는 계속): {}", e);
            }
        }
    }

    async fn notify_slam_stop(&self, session_id: &str) {
        let url = format!("{}/sessions/{}", self.slam_api_url, session_id);
        match self.slam_client.delete(&url).send().await {
            Ok(resp) if resp.status().is_success() => {
                info!(session_id = %session_id, "SLAM 세션 종료 알림 성공");
            }
            Ok(resp) => {
                warn!(session_id = %session_id, status = %resp.status(), "SLAM 세션 종료 알림 실패");
            }
            Err(e) => {
                error!(session_id = %session_id, "SLAM API 연결 실패: {}", e);
            }
        }
    }
}
