use std::collections::VecDeque;
use std::sync::Mutex;

use indoor_pathfinding_protocols::mapping::MappingPacket;

/// 센서 데이터 큐
pub struct SensorQueue {
    queue: Mutex<VecDeque<MappingPacket>>,
    capacity: usize,
}

impl SensorQueue {
    pub fn new(capacity: usize) -> Self {
        Self {
            queue: Mutex::new(VecDeque::with_capacity(capacity)),
            capacity,
        }
    }

    /// 센서 패킷을 큐에 추가. 용량 초과 시 가장 오래된 데이터 제거.
    pub fn push(&self, packet: MappingPacket) {
        let mut q = self.queue.lock().unwrap();
        if q.len() >= self.capacity {
            q.pop_front();
        }
        q.push_back(packet);
    }

    /// 큐에서 패킷을 하나 꺼냄
    pub fn pop(&self) -> Option<MappingPacket> {
        self.queue.lock().unwrap().pop_front()
    }

    /// 큐에 남은 패킷 수
    pub fn len(&self) -> usize {
        self.queue.lock().unwrap().len()
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

/// gRPC 클라이언트 — gateway에 센서 데이터를 전송
pub struct GrpcClient {
    _endpoint: String,
}

impl GrpcClient {
    pub fn new(endpoint: String) -> Self {
        Self {
            _endpoint: endpoint,
        }
    }

    /// 서버에 연결 (TODO: 실제 tonic 채널 연결)
    pub async fn connect(&self) -> Result<(), Box<dyn std::error::Error>> {
        // TODO: tonic::transport::Channel::from_shared → connect
        Ok(())
    }

    /// 센서 스트리밍 시작 (TODO: 실제 gRPC 스트리밍)
    pub async fn start_streaming(
        &self,
        _queue: &SensorQueue,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // TODO: MappingService::stream_mapping 양방향 스트리밍
        Ok(())
    }
}
