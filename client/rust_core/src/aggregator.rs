/// 센서 데이터 수집 → proto 패킷 조립

use indoor_pathfinding_protocols::common::{BarometerData, Intrinsics, Vector3};
use indoor_pathfinding_protocols::localization::LocalizationPacket;
use indoor_pathfinding_protocols::mapping::{ImuData, MappingPacket};

/// Native에서 전달되는 센서 메시지
pub enum SensorMsg {
    Frame {
        timestamp: f64,
        image_data: Vec<u8>,
        fx: f64,
        fy: f64,
        cx: f64,
        cy: f64,
    },
    Imu {
        timestamp: f64,
        ax: f64,
        ay: f64,
        az: f64,
        gx: f64,
        gy: f64,
        gz: f64,
    },
    Barometer {
        timestamp: f64,
        pressure: f64,
    },
}

pub struct Aggregator {
    session_id: String,
    imu_buffer: Vec<ImuData>,
    latest_baro: Option<BarometerData>,
}

impl Aggregator {
    pub fn new(session_id: String) -> Self {
        Self {
            session_id,
            imu_buffer: Vec::new(),
            latest_baro: None,
        }
    }

    /// 센서 메시지 처리 → 프레임 도착 시 MappingPacket 반환
    pub fn process_mapping(&mut self, msg: SensorMsg) -> Option<MappingPacket> {
        match msg {
            SensorMsg::Imu {
                timestamp,
                ax,
                ay,
                az,
                gx,
                gy,
                gz,
            } => {
                self.imu_buffer.push(ImuData {
                    timestamp,
                    acceleration: Some(Vector3 {
                        x: ax,
                        y: ay,
                        z: az,
                    }),
                    angular_velocity: Some(Vector3 {
                        x: gx,
                        y: gy,
                        z: gz,
                    }),
                });
                None
            }
            SensorMsg::Barometer {
                timestamp,
                pressure,
            } => {
                self.latest_baro = Some(BarometerData {
                    timestamp,
                    pressure,
                });
                None
            }
            SensorMsg::Frame {
                timestamp,
                image_data,
                fx,
                fy,
                cx,
                cy,
            } => {
                let packet = MappingPacket {
                    session_id: self.session_id.clone(),
                    timestamp,
                    image_data,
                    imu_data: std::mem::take(&mut self.imu_buffer),
                    intrinsics: Some(Intrinsics { fx, fy, cx, cy }),
                    barometer: self.latest_baro.clone(),
                };
                Some(packet)
            }
        }
    }

    /// 센서 메시지 처리 → 프레임 도착 시 LocalizationPacket 반환
    pub fn process_localization(&mut self, msg: SensorMsg) -> Option<LocalizationPacket> {
        match msg {
            SensorMsg::Imu { .. } => None, // localization에서는 IMU 미사용
            SensorMsg::Barometer {
                timestamp,
                pressure,
            } => {
                self.latest_baro = Some(BarometerData {
                    timestamp,
                    pressure,
                });
                None
            }
            SensorMsg::Frame {
                timestamp,
                image_data,
                fx,
                fy,
                cx,
                cy,
            } => {
                let packet = LocalizationPacket {
                    session_id: self.session_id.clone(),
                    timestamp,
                    query_image: image_data,
                    intrinsics: Some(Intrinsics { fx, fy, cx, cy }),
                    barometer: self.latest_baro.clone(),
                    hint: None,
                };
                Some(packet)
            }
        }
    }
}
