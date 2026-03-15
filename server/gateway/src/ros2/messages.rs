use r2r::{builtin_interfaces, geometry_msgs, sensor_msgs, std_msgs};

pub fn stamp(timestamp: f64) -> builtin_interfaces::msg::Time {
    let sec = timestamp as i32;
    let nanosec = ((timestamp - sec as f64) * 1e9) as u32;
    builtin_interfaces::msg::Time { sec, nanosec }
}

pub fn header(timestamp: f64, frame_id: &str) -> std_msgs::msg::Header {
    std_msgs::msg::Header {
        stamp: stamp(timestamp),
        frame_id: frame_id.to_string(),
    }
}

pub fn compressed_image(timestamp: f64, data: Vec<u8>) -> sensor_msgs::msg::CompressedImage {
    sensor_msgs::msg::CompressedImage {
        header: header(timestamp, "camera"),
        format: "jpeg".to_string(),
        data,
    }
}

pub fn imu(timestamp: f64, accel: [f64; 3], gyro: [f64; 3]) -> sensor_msgs::msg::Imu {
    sensor_msgs::msg::Imu {
        header: header(timestamp, "imu"),
        linear_acceleration: geometry_msgs::msg::Vector3 {
            x: accel[0],
            y: accel[1],
            z: accel[2],
        },
        angular_velocity: geometry_msgs::msg::Vector3 {
            x: gyro[0],
            y: gyro[1],
            z: gyro[2],
        },
        ..Default::default()
    }
}

pub fn camera_info(fx: f64, fy: f64, cx: f64, cy: f64) -> sensor_msgs::msg::CameraInfo {
    sensor_msgs::msg::CameraInfo {
        header: header(0.0, "camera"),
        k: vec![fx, 0.0, cx, 0.0, fy, cy, 0.0, 0.0, 1.0],
        ..Default::default()
    }
}

pub fn fluid_pressure(timestamp: f64, pressure: f64) -> sensor_msgs::msg::FluidPressure {
    sensor_msgs::msg::FluidPressure {
        header: header(timestamp, "barometer"),
        fluid_pressure: pressure,
        variance: 0.0,
    }
}
