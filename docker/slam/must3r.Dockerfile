# ── Layer 1: 시스템 + Python + uv (거의 안 바뀜) ──
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive

# ROS2 Humble 리포지토리 추가
RUN apt-get update && apt-get install -y curl gnupg2 lsb-release && \
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
      -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
      http://packages.ros.org/ros2/ubuntu jammy main" \
      > /etc/apt/sources.list.d/ros2.list

RUN apt-get update && apt-get install -y \
    python3.11 python3.11-dev python3.11-venv \
    git cmake build-essential \
    libgl1-mesa-glx libglib2.0-0 \
    ros-humble-rclpy ros-humble-sensor-msgs ros-humble-std-msgs \
    ros-humble-rmw-cyclonedds-cpp \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"
ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# ── Layer 2: PyTorch + xFormers (거의 안 바뀜) ──
RUN uv pip install --system --no-cache \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128

RUN uv pip install --system --no-cache \
    xformers --index-url https://download.pytorch.org/whl/cu128

# ── Layer 3: MUSt3R + API 의존성 ──
RUN uv pip install --system --no-cache \
    "must3r@git+https://github.com/naver/must3r.git" \
    "fastapi>=0.115.0" "uvicorn[standard]>=0.34.0"

# ── Layer 4: 모델 가중치 (~1.5GB, 변경 없음 → 캐시) ──
WORKDIR /workspace/weights
RUN curl -LO https://download.europe.naverlabs.com/ComputerVision/MUSt3R/MUSt3R_512.pth && \
    curl -LO https://download.europe.naverlabs.com/ComputerVision/MUSt3R/MUSt3R_512_retrieval_trainingfree.pth && \
    curl -LO https://download.europe.naverlabs.com/ComputerVision/MUSt3R/MUSt3R_512_retrieval_codebook.pkl

# ── Layer 5: 래퍼 노드 코드 (자주 변경 → 마지막) ──
WORKDIR /workspace
COPY server/slam/must3r/ ./slam/must3r/

ENV XFORMERS_DISABLED=1
ENV MUST3R_CHKPT=/workspace/weights/MUSt3R_512.pth
ENV MAPS_DIR=/workspace/maps
ENV PYTHONPATH=/opt/ros/humble/lib/python3.10/dist-packages:/opt/ros/humble/local/lib/python3.10/dist-packages

# 내부 HTTP API (8000) + Gradio (7860) + viser (8080)
EXPOSE 8000 7860 8080

# ROS2 환경 로드 + FastAPI 서버 시작 (ROS2 노드 내장)
CMD ["bash", "-c", ". /opt/ros/humble/setup.bash && uvicorn slam.must3r.api:app --host 0.0.0.0 --port 8000"]
