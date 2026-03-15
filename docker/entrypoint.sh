#!/bin/bash
set -e

source /opt/ros/humble/setup.bash
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# rosbag2 녹화 시작 (백그라운드)
mkdir -p /workspace/rosbag2
ros2 bag record -o /workspace/rosbag2/session \
    /slam/image/compressed \
    /slam/imu \
    /slam/camera_info \
    &

# gateway 실행
exec gateway
