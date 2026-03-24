# ── Stage 1: Rust 빌드 (순수 Ubuntu) ──
FROM ubuntu:24.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive

# 카카오 미러 + 병렬 다운로드
RUN echo 'Acquire::Queue-Mode "access";' > /etc/apt/apt.conf.d/99parallel && \
    echo 'Acquire::http::Pipeline-Depth "10";' >> /etc/apt/apt.conf.d/99parallel && \
    sed -i 's|http://archive.ubuntu.com|http://mirror.kakao.com|g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || true && \
    sed -i 's|http://security.ubuntu.com|http://mirror.kakao.com|g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || true && \
    apt-get update && apt-get install -y --no-install-recommends \
    cmake build-essential git curl unzip libclang-dev pkg-config ca-certificates \
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

# ── Stage 2: ROS2 Jazzy 런타임 (Ubuntu 24.04 + Python 3.12) ──
FROM osrf/ros:jazzy-desktop-full

ARG DEBIAN_FRONTEND=noninteractive

# 카카오 미러 + 병렬 다운로드
RUN echo 'Acquire::Queue-Mode "access";' > /etc/apt/apt.conf.d/99parallel && \
    echo 'Acquire::http::Pipeline-Depth "10";' >> /etc/apt/apt.conf.d/99parallel && \
    sed -i 's|http://archive.ubuntu.com|http://mirror.kakao.com|g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || true && \
    sed -i 's|http://security.ubuntu.com|http://mirror.kakao.com|g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || true && \
    apt-get update && apt-get install -y --no-install-recommends \
    curl unzip libclang-dev \
    ros-jazzy-rmw-cyclonedds-cpp \
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

# ROS2 feature로 재빌드 (r2r 추가)
ENV CARGO_NET_RETRY=10
ENV CARGO_HTTP_TIMEOUT=600
RUN . /opt/ros/jazzy/setup.sh && \
    cd server/gateway && cargo build --release --features ros2

RUN cp /workspace/server/gateway/target/release/gateway /usr/local/bin/ && \
    rm -rf /workspace/server/gateway/target /root/.cargo/registry

ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ENV ROS_DISTRO=jazzy

EXPOSE 50051

CMD ["bash", "-c", ". /opt/ros/jazzy/setup.bash && gateway"]
