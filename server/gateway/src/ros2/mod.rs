#[cfg(feature = "ros2")]
mod publisher;

#[cfg(feature = "ros2")]
pub use publisher::Ros2Publisher;

#[cfg(not(feature = "ros2"))]
mod noop;

#[cfg(not(feature = "ros2"))]
pub use noop::Ros2Publisher;
