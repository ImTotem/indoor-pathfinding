/// RustCoreEngine — tokio 런타임, 세션 관리, gRPC 오케스트레이션

use std::sync::{Arc, OnceLock};

use parking_lot::Mutex;
use tokio::runtime::Runtime;
use tokio::sync::mpsc;
use tracing::{error, info};

use std::time::Instant;

use crate::aggregator::{Aggregator, SensorMsg};
use crate::grpc_client::{GatewayClient, SessionKind};
use crate::types::*;

static ENGINE: OnceLock<RustCoreEngine> = OnceLock::new();

pub struct RustCoreEngine {
    runtime: Runtime,
    server_endpoint: String,
    status: Arc<Mutex<EngineStatus>>,
    session: Mutex<Option<ActiveSession>>,
}

struct ActiveSession {
    sensor_tx: mpsc::Sender<SensorMsg>,
    shutdown_tx: mpsc::Sender<()>,
}

impl RustCoreEngine {
    /// 엔진 초기화 (앱 시작 시 1회)
    pub fn init(server_endpoint: String) {
        ENGINE.get_or_init(|| {
            let runtime = Runtime::new().expect("Failed to create tokio runtime");
            info!("RustCoreEngine initialized: {}", server_endpoint);
            RustCoreEngine {
                runtime,
                server_endpoint,
                status: Arc::new(Mutex::new(EngineStatus::idle())),
                session: Mutex::new(None),
            }
        });
    }

    pub fn get() -> &'static RustCoreEngine {
        ENGINE
            .get()
            .expect("Engine not initialized. Call init_engine() first.")
    }

    /// 매핑 세션 시작
    pub fn start_mapping_session(
        &self,
        map_id: String,
    ) -> Result<(), RustCoreError> {
        {
            let status = self.status.lock();
            if status.state != SessionState::Idle {
                return Err(RustCoreError::SessionAlreadyActive);
            }
        }

        let (sensor_tx, sensor_rx) = mpsc::channel(2048);
        let (shutdown_tx, shutdown_rx) = mpsc::channel(1);

        // 상태 업데이트
        {
            let mut s = self.status.lock();
            s.state = SessionState::Mapping;
            s.frame_count = 0;
            s.total_pushed = 0;
            s.queue_full = false;
            s.pose = None;
            s.error_message = None;
        }

        *self.session.lock() = Some(ActiveSession {
            sensor_tx,
            shutdown_tx,
        });

        let status = self.status.clone();
        let endpoint = self.server_endpoint.clone();

        self.runtime.spawn(async move {
            if let Err(e) = run_mapping_session(
                endpoint,
                map_id,
                sensor_rx,
                shutdown_rx,
                status.clone(),
            )
            .await
            {
                error!("Mapping session error: {}", e);
                let mut s = status.lock();
                s.state = SessionState::Error;
                s.error_message = Some(e.to_string());
            }
        });

        Ok(())
    }

    /// Localization 세션 시작
    pub fn start_localization_session(
        &self,
        map_id: String,
    ) -> Result<(), RustCoreError> {
        {
            let status = self.status.lock();
            if status.state != SessionState::Idle {
                return Err(RustCoreError::SessionAlreadyActive);
            }
        }

        let (sensor_tx, sensor_rx) = mpsc::channel(2048);
        let (shutdown_tx, shutdown_rx) = mpsc::channel(1);

        {
            let mut s = self.status.lock();
            s.state = SessionState::Localizing;
            s.frame_count = 0;
            s.total_pushed = 0;
            s.queue_full = false;
            s.pose = None;
            s.error_message = None;
        }

        *self.session.lock() = Some(ActiveSession {
            sensor_tx,
            shutdown_tx,
        });

        let status = self.status.clone();
        let endpoint = self.server_endpoint.clone();

        self.runtime.spawn(async move {
            if let Err(e) = run_localization_session(
                endpoint,
                map_id,
                sensor_rx,
                shutdown_rx,
                status.clone(),
            )
            .await
            {
                error!("Localization session error: {}", e);
                let mut s = status.lock();
                s.state = SessionState::Error;
                s.error_message = Some(e.to_string());
            }
        });

        Ok(())
    }

    /// 현재 세션 종료
    pub fn stop_session(&self) -> Result<(), RustCoreError> {
        let mut session = self.session.lock();
        if let Some(s) = session.take() {
            let _ = s.shutdown_tx.try_send(());
            Ok(())
        } else {
            Err(RustCoreError::NoActiveSession)
        }
    }

    /// Native에서 센서 데이터 push
    pub fn push_sensor(&self, msg: SensorMsg) {
        let is_frame = matches!(msg, SensorMsg::Frame { .. });
        let session = self.session.lock();
        if let Some(s) = session.as_ref() {
            match s.sensor_tx.try_send(msg) {
                Ok(()) => {
                    let mut st = self.status.lock();
                    if is_frame {
                        st.total_pushed += 1;
                    }
                    st.queue_full = false;
                }
                Err(mpsc::error::TrySendError::Full(_)) => {
                    self.status.lock().queue_full = true;
                }
                Err(mpsc::error::TrySendError::Closed(_)) => {}
            }
        }
    }

    /// 엔진 상태 조회 (Kotlin 폴링용)
    pub fn get_status(&self) -> EngineStatus {
        self.status.lock().clone()
    }
}

/// 매핑 세션 백그라운드 태스크
async fn run_mapping_session(
    endpoint: String,
    map_id: String,
    mut sensor_rx: mpsc::Receiver<SensorMsg>,
    mut shutdown_rx: mpsc::Receiver<()>,
    status: Arc<Mutex<EngineStatus>>,
) -> Result<(), RustCoreError> {
    let client = GatewayClient::connect(&endpoint).await?;

    let session_id = client
        .start_session(&map_id, SessionKind::Mapping)
        .await?;

    // RTT 기반 타임스탬프 동기화 (실패해도 세션 계속)
    if let Err(e) = perform_time_sync(&client, &session_id).await {
        error!("Time sync failed (using raw timestamps): {}", e);
    }

    let (stream_tx, mut response_stream) = client.open_mapping_stream().await?;

    let mut aggregator = Aggregator::new(session_id.clone());

    // 서버 응답 핸들러
    let status_for_responses = status.clone();
    tokio::spawn(async move {
        while let Ok(Some(response)) = response_stream.message().await {
            if let Some(pose) = response.pose {
                let mut s = status_for_responses.lock();
                let pos = pose.position.unwrap_or_default();
                let ori = pose.orientation.unwrap_or_default();
                s.pose = Some(PoseResult {
                    x: pos.x,
                    y: pos.y,
                    z: pos.z,
                    qx: ori.x,
                    qy: ori.y,
                    qz: ori.z,
                    qw: ori.w,
                });
            }
        }
    });

    // 센서 데이터 → 패킷 전송 루프
    loop {
        tokio::select! {
            Some(msg) = sensor_rx.recv() => {
                if let Some(packet) = aggregator.process_mapping(msg) {
                    if stream_tx.send(packet).await.is_err() {
                        info!("Mapping stream closed");
                        break;
                    }
                    status.lock().frame_count += 1;
                }
            }
            _ = shutdown_rx.recv() => {
                info!("Mapping session shutdown requested");
                break;
            }
        }
    }

    // 큐에 남은 데이터 모두 전송
    while let Ok(msg) = sensor_rx.try_recv() {
        if let Some(packet) = aggregator.process_mapping(msg) {
            if stream_tx.send(packet).await.is_err() {
                break;
            }
            status.lock().frame_count += 1;
        }
    }
    info!("Flushed remaining sensor data");

    // 스트림 종료 → 세션 정리
    drop(stream_tx);
    client.stop_session(&session_id).await?;

    {
        let mut s = status.lock();
        s.state = SessionState::Idle;
    }
    info!("Mapping session completed: {}", session_id);

    Ok(())
}

/// Localization 세션 백그라운드 태스크
async fn run_localization_session(
    endpoint: String,
    map_id: String,
    mut sensor_rx: mpsc::Receiver<SensorMsg>,
    mut shutdown_rx: mpsc::Receiver<()>,
    status: Arc<Mutex<EngineStatus>>,
) -> Result<(), RustCoreError> {
    let client = GatewayClient::connect(&endpoint).await?;

    let session_id = client
        .start_session(&map_id, SessionKind::Localization)
        .await?;

    if let Err(e) = perform_time_sync(&client, &session_id).await {
        error!("Time sync failed (using raw timestamps): {}", e);
    }

    let (stream_tx, mut response_stream) = client.open_localization_stream().await?;

    let mut aggregator = Aggregator::new(session_id.clone());

    // 서버 응답 핸들러
    let status_for_responses = status.clone();
    tokio::spawn(async move {
        while let Ok(Some(response)) = response_stream.message().await {
            if let Some(pose) = response.pose {
                let mut s = status_for_responses.lock();
                let pos = pose.position.unwrap_or_default();
                let ori = pose.orientation.unwrap_or_default();
                s.pose = Some(PoseResult {
                    x: pos.x,
                    y: pos.y,
                    z: pos.z,
                    qx: ori.x,
                    qy: ori.y,
                    qz: ori.z,
                    qw: ori.w,
                });
            }
        }
    });

    loop {
        tokio::select! {
            Some(msg) = sensor_rx.recv() => {
                if let Some(packet) = aggregator.process_localization(msg) {
                    if stream_tx.send(packet).await.is_err() {
                        info!("Localization stream closed");
                        break;
                    }
                    status.lock().frame_count += 1;
                }
            }
            _ = shutdown_rx.recv() => {
                info!("Localization session shutdown requested");
                break;
            }
        }
    }

    // 큐에 남은 데이터 모두 전송
    while let Ok(msg) = sensor_rx.try_recv() {
        if let Some(packet) = aggregator.process_localization(msg) {
            if stream_tx.send(packet).await.is_err() {
                break;
            }
            status.lock().frame_count += 1;
        }
    }
    info!("Flushed remaining sensor data");

    drop(stream_tx);
    client.stop_session(&session_id).await?;

    {
        let mut s = status.lock();
        s.state = SessionState::Idle;
    }
    info!("Localization session completed: {}", session_id);

    Ok(())
}

// ── RTT 기반 타임스탬프 동기화 ──

const SYNC_ROUNDS: usize = 5;

/// CLOCK_BOOTTIME 현재 시간 (초) — Android 센서와 동일 클럭
fn boottime_seconds() -> f64 {
    let mut ts = libc::timespec {
        tv_sec: 0,
        tv_nsec: 0,
    };
    unsafe { libc::clock_gettime(libc::CLOCK_BOOTTIME, &mut ts) };
    ts.tv_sec as f64 + ts.tv_nsec as f64 / 1_000_000_000.0
}

/// 5라운드 RTT 측정 → 최소 RTT 샘플의 offset 채택 → 서버에 전달
async fn perform_time_sync(
    client: &GatewayClient,
    session_id: &str,
) -> Result<(), RustCoreError> {
    let mut best_offset = 0.0_f64;
    let mut min_rtt = f64::MAX;

    for i in 0..SYNC_ROUNDS {
        let t1 = Instant::now();
        let t1_boottime = boottime_seconds();
        let server_time = client.sync_time(session_id, t1_boottime).await?;
        let rtt = t1.elapsed().as_secs_f64();
        let offset = server_time - t1_boottime - rtt / 2.0;

        info!(
            round = i,
            rtt_ms = format!("{:.2}", rtt * 1000.0),
            offset_s = format!("{:.6}", offset),
            "Time sync"
        );

        if rtt < min_rtt {
            min_rtt = rtt;
            best_offset = offset;
        }
    }

    info!(
        offset_s = format!("{:.6}", best_offset),
        min_rtt_ms = format!("{:.2}", min_rtt * 1000.0),
        "Time sync 완료"
    );

    client.set_time_offset(session_id, best_offset).await?;
    Ok(())
}
