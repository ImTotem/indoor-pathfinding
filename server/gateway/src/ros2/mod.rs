mod commands;

#[cfg(feature = "ros2")]
mod messages;
#[cfg(feature = "ros2")]
mod publisher;
#[cfg(feature = "ros2")]
mod recorder;

#[cfg(feature = "ros2")]
pub use publisher::Ros2Publisher;
#[cfg(feature = "ros2")]
pub use recorder::Rosbag2Recorder;

#[cfg(not(feature = "ros2"))]
mod noop;
#[cfg(not(feature = "ros2"))]
mod recorder_noop;

#[cfg(not(feature = "ros2"))]
pub use noop::Ros2Publisher;
#[cfg(not(feature = "ros2"))]
pub use recorder_noop::Rosbag2Recorder;
