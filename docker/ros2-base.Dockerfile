FROM osrf/ros:humble-desktop-full-jammy AS base

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    cmake \
    build-essential \
    git \
    curl \
    protobuf-compiler \
    ros-humble-rmw-cyclonedds-cpp \
    && rm -rf /var/lib/apt/lists/*

# Rust (gateway 빌드용)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# --- gateway 빌드 (코드 변경 시 여기부터 재빌드) ---

WORKDIR /workspace

COPY protocols/ ./protocols/
RUN cd protocols/rust && cargo build --release

COPY server/gateway/ ./server/gateway/
RUN cd server/gateway && cargo build --release

RUN cp /workspace/server/gateway/target/release/gateway /usr/local/bin/ && \
    rm -rf /workspace/server/gateway/target

EXPOSE 50051
