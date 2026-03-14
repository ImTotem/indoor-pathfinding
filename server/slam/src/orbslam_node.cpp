#include <rclcpp/rclcpp.hpp>
#include <sensor_msgs/msg/image.hpp>
#include <sensor_msgs/msg/imu.hpp>
#include <geometry_msgs/msg/pose_stamped.hpp>

class OrbSlamNode : public rclcpp::Node {
public:
  OrbSlamNode() : Node("orbslam_node") {
    // 파라미터 선언
    this->declare_parameter("vocabulary_path", "");
    this->declare_parameter("settings_path", "");

    // 카메라 이미지 구독
    image_sub_ = this->create_subscription<sensor_msgs::msg::Image>(
      "/camera/image_raw", 10,
      [this](const sensor_msgs::msg::Image::SharedPtr msg) {
        on_image(msg);
      });

    // IMU 데이터 구독
    imu_sub_ = this->create_subscription<sensor_msgs::msg::Imu>(
      "/imu/data", 100,
      [this](const sensor_msgs::msg::Imu::SharedPtr msg) {
        on_imu(msg);
      });

    // 포즈 결과 발행
    pose_pub_ = this->create_publisher<geometry_msgs::msg::PoseStamped>(
      "/orbslam/pose", 10);

    RCLCPP_INFO(this->get_logger(), "ORB-SLAM3 노드 초기화 완료");
    // TODO: ORB-SLAM3 시스템 초기화
  }

private:
  void on_image(const sensor_msgs::msg::Image::SharedPtr /*msg*/) {
    // TODO: ORB-SLAM3에 이미지 전달 → 포즈 추정 → pose_pub_ 발행
  }

  void on_imu(const sensor_msgs::msg::Imu::SharedPtr /*msg*/) {
    // TODO: ORB-SLAM3에 IMU 데이터 전달 (VIO 모드)
  }

  rclcpp::Subscription<sensor_msgs::msg::Image>::SharedPtr image_sub_;
  rclcpp::Subscription<sensor_msgs::msg::Imu>::SharedPtr imu_sub_;
  rclcpp::Publisher<geometry_msgs::msg::PoseStamped>::SharedPtr pose_pub_;
};

int main(int argc, char **argv) {
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<OrbSlamNode>());
  rclcpp::shutdown();
  return 0;
}
