# ros2.Dockerfile 베이스 (gateway + ROS2 포함)
FROM indoor-pathfinding-ros2:latest

ARG DEBIAN_FRONTEND=noninteractive

# CUDA 12.8 Toolkit
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget ca-certificates gnupg software-properties-common && \
    wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && rm -f cuda-keyring_1.1-1_all.deb && \
    apt-get update && apt-get install -y --no-install-recommends cuda-toolkit-12-8 && \
    rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/local/cuda-12.8/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cuda-12.8/lib64:${LD_LIBRARY_PATH}"

# Python 3.11 (MUSt3R 요구)
RUN apt-get update && apt-get install -y \
    python3.11 python3.11-dev python3.11-venv \
    libgl1-mesa-glx libglib2.0-0 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && rm -rf /var/lib/apt/lists/*

# uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# ── PyTorch + xFormers (cu128, Blackwell sm_120 지원) ──
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

# ── MUSt3R 래퍼 노드 (자주 변경 → 마지막) ──
WORKDIR /workspace
COPY server/slam/must3r/ ./slam/must3r/

ENV XFORMERS_DISABLED=1
ENV MUST3R_CHKPT=/workspace/weights/MUSt3R_512.pth
ENV MAPS_DIR=/workspace/maps
ENV PYTHONPATH=/opt/ros/humble/lib/python3.10/dist-packages:/opt/ros/humble/local/lib/python3.10/dist-packages

EXPOSE 8000 7860 8080

# gateway(베이스 이미지 CMD) + MUSt3R SLAM API 동시 실행
CMD ["bash", "-c", ". /opt/ros/humble/setup.bash && gateway & uvicorn slam.must3r.api:app --host 0.0.0.0 --port 8000 && wait"]
