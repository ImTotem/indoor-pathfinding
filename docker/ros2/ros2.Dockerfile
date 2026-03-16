# ── Stage 1: Rust 빌드 (순수 Ubuntu) ──
FROM ubuntu:22.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    cmake build-essential git curl unzip libclang-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

# protoc
RUN curl -LO https://github.com/protocolbuffers/protobuf/releases/download/v29.5/protoc-29.5-linux-x86_64.zip && \
    unzip protoc-29.5-linux-x86_64.zip -d /usr/local && \
    rm protoc-29.5-linux-x86_64.zip

# Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.93.1
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /workspace
COPY protocols/ ./protocols/
RUN cd protocols/rust && cargo build --release

COPY server/gateway/ ./server/gateway/

# ROS2 없이 빌드 (noop 퍼블리셔 사용)
RUN cd server/gateway && cargo build --release

# ── Stage 2: ROS2 런타임 ──
FROM osrf/ros:humble-desktop-full-jammy

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl unzip libclang-dev \
    ros-humble-rmw-cyclonedds-cpp \
    && rm -rf /var/lib/apt/lists/*

# protoc (r2r 빌드에 필요)
RUN curl -LO https://github.com/protocolbuffers/protobuf/releases/download/v29.5/protoc-29.5-linux-x86_64.zip && \
    unzip protoc-29.5-linux-x86_64.zip -d /usr/local && \
    rm protoc-29.5-linux-x86_64.zip

# Rust (ROS2 feature 빌드용)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.93.1
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /workspace

# Stage 1에서 빌드된 의존성 캐시 복사
COPY --from=builder /workspace/protocols/ ./protocols/
COPY --from=builder /workspace/server/ ./server/
COPY --from=builder /root/.cargo/registry /root/.cargo/registry
COPY --from=builder /workspace/server/gateway/target/ ./server/gateway/target/

# ROS2 feature로 재빌드 (r2r 링크만 추가)
RUN . /opt/ros/humble/setup.sh && \
    cd server/gateway && cargo build --release --features ros2

RUN cp /workspace/server/gateway/target/release/gateway /usr/local/bin/ && \
    rm -rf /workspace/server/gateway/target /root/.cargo/registry

ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

EXPOSE 50051

CMD ["bash", "-c", ". /opt/ros/humble/setup.bash && gateway"]
