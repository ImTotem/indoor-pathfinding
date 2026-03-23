# ── Stage 1: Gateway Rust 빌드 (순수 Ubuntu, 캐시 최대화) ──
FROM ubuntu:22.04 AS gateway-builder

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    cmake build-essential git curl unzip libclang-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LO https://github.com/protocolbuffers/protobuf/releases/download/v29.5/protoc-29.5-linux-x86_64.zip && \
    unzip protoc-29.5-linux-x86_64.zip -d /usr/local && \
    rm protoc-29.5-linux-x86_64.zip

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.93.1
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /workspace
COPY protocols/ ./protocols/
RUN cd protocols/rust && cargo build --release

COPY server/gateway/ ./server/gateway/
RUN cd server/gateway && cargo build --release

# ── Stage 2: CUDA + ROS2 + MUSt3R + Gateway 통합 ──
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive

# ROS2 Humble 리포지토리
RUN apt-get update && apt-get install -y curl gnupg2 lsb-release && \
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
      -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
      http://packages.ros.org/ros2/ubuntu jammy main" \
      > /etc/apt/sources.list.d/ros2.list

# 시스템 패키지 + ROS2
RUN apt-get update && apt-get install -y \
    python3.11 python3.11-dev python3.11-venv \
    git cmake build-essential unzip \
    libgl1-mesa-glx libglib2.0-0 libclang-dev \
    ros-humble-rclpy ros-humble-sensor-msgs ros-humble-std-msgs \
    ros-humble-rmw-cyclonedds-cpp \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && rm -rf /var/lib/apt/lists/*

# uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# protoc (gateway ROS2 feature 빌드용)
RUN curl -LO https://github.com/protocolbuffers/protobuf/releases/download/v29.5/protoc-29.5-linux-x86_64.zip && \
    unzip protoc-29.5-linux-x86_64.zip -d /usr/local && \
    rm protoc-29.5-linux-x86_64.zip

# Rust (gateway ROS2 feature 빌드용)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.93.1
ENV PATH="/root/.cargo/bin:${PATH}"

# ── PyTorch + xFormers ──
RUN uv pip install --system --no-cache \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128

RUN uv pip install --system --no-cache \
    xformers --index-url https://download.pytorch.org/whl/cu128

# ── MUSt3R + API 의존성 ──
RUN uv pip install --system --no-cache \
    "must3r@git+https://github.com/naver/must3r.git" \
    "fastapi>=0.115.0" "uvicorn[standard]>=0.34.0"

# ── 모델 가중치 ──
WORKDIR /workspace/weights
RUN curl -LO https://download.europe.naverlabs.com/ComputerVision/MUSt3R/MUSt3R_512.pth && \
    curl -LO https://download.europe.naverlabs.com/ComputerVision/MUSt3R/MUSt3R_512_retrieval_trainingfree.pth && \
    curl -LO https://download.europe.naverlabs.com/ComputerVision/MUSt3R/MUSt3R_512_retrieval_codebook.pkl

# ── Gateway 빌드 (ROS2 feature) ──
WORKDIR /workspace
COPY --from=gateway-builder /workspace/protocols/ ./protocols/
COPY --from=gateway-builder /workspace/server/gateway/ ./server/gateway/
COPY --from=gateway-builder /root/.cargo/registry /root/.cargo/registry
COPY --from=gateway-builder /workspace/server/gateway/target/ ./server/gateway/target/

ENV CARGO_NET_RETRY=10
ENV CARGO_HTTP_TIMEOUT=600
RUN . /opt/ros/humble/setup.sh && \
    cd server/gateway && cargo build --release --features ros2

RUN cp /workspace/server/gateway/target/release/gateway /usr/local/bin/ && \
    rm -rf /workspace/server/gateway/target /root/.cargo/registry

# ── MUSt3R 래퍼 노드 (자주 변경 → 마지막) ──
COPY server/slam/must3r/ ./slam/must3r/

ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ENV XFORMERS_DISABLED=1
ENV MUST3R_CHKPT=/workspace/weights/MUSt3R_512.pth
ENV MAPS_DIR=/workspace/maps
ENV PYTHONPATH=/opt/ros/humble/lib/python3.10/dist-packages:/opt/ros/humble/local/lib/python3.10/dist-packages

# gateway(50051) + SLAM API(8000) + Gradio(7860) + viser(8080)
EXPOSE 50051 8000 7860 8080

# gateway + MUSt3R SLAM API 동시 실행
CMD ["bash", "-c", ". /opt/ros/humble/setup.bash && gateway & uvicorn slam.must3r.api:app --host 0.0.0.0 --port 8000 && wait"]
