from launch import LaunchDescription
from launch_ros.actions import Node


def generate_launch_description():
    return LaunchDescription([
        Node(
            package="orbslam_ros2",
            executable="orbslam_node",
            name="orbslam_node",
            output="screen",
            parameters=[{
                "vocabulary_path": "/opt/ORB_SLAM3/Vocabulary/ORBvoc.txt",
                "settings_path": "",  # TODO: 카메라별 설정 파일 경로
            }],
        ),
    ])
