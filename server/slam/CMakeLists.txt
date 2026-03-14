cmake_minimum_required(VERSION 3.8)
project(orbslam_ros2)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# ROS2 dependencies
find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(sensor_msgs REQUIRED)
find_package(geometry_msgs REQUIRED)
find_package(cv_bridge REQUIRED)
find_package(image_transport REQUIRED)

# ORB-SLAM3
# TODO: find_package(ORB_SLAM3 REQUIRED) — 시스템에 설치된 ORB-SLAM3 경로 설정 필요

add_executable(orbslam_node src/orbslam_node.cpp)
ament_target_dependencies(orbslam_node
  rclcpp
  sensor_msgs
  geometry_msgs
  cv_bridge
  image_transport
)

install(TARGETS orbslam_node
  DESTINATION lib/${PROJECT_NAME}
)

install(DIRECTORY launch config
  DESTINATION share/${PROJECT_NAME}
)

ament_package()
