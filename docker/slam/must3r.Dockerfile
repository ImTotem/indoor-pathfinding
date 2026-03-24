# ros2.Dockerfile 베이스 (gateway + ROS2 Jazzy 포함, Python 3.12)
FROM indoor-pathfinding-ros2:latest

ARG DEBIAN_FRONTEND=noninteractive

# CUDA 12.8 Toolkit (NVIDIA apt repo)
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget ca-certificates gnupg software-properties-common && \
    wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && rm -f cuda-keyring_1.1-1_all.deb && \
    apt-get update && apt-get install -y --no-install-recommends cuda-toolkit-12-8 && \
    rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/local/cuda-12.8/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cuda-12.8/lib64"

# apt 병렬 다운로드 + 카카오 미러 + 최소 설치
RUN echo 'Acquire::Queue-Mode "access";' > /etc/apt/apt.conf.d/99parallel && \
    echo 'Acquire::http::Pipeline-Depth "10";' >> /etc/apt/apt.conf.d/99parallel && \
    sed -i 's|http://archive.ubuntu.com|http://mirror.kakao.com|g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || true && \
    sed -i 's|http://security.ubuntu.com|http://mirror.kakao.com|g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || true && \
    apt-get update && apt-get install -y --no-install-recommends \
    python3-dev python3-venv python3-pip \
    libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# ── PyTorch + xFormers (cu128, Blackwell sm_120 지원) ──
# BuildKit 캐시: 레이어 무효화되어도 다운로드 캐시 유지
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system --break-system-packages \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128

RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system --break-system-packages \
    xformers --index-url https://download.pytorch.org/whl/cu128

# ── MUSt3R + API 의존성 ──
ENV UV_HTTP_TIMEOUT=600
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system --break-system-packages \
    "must3r@git+https://github.com/naver/must3r.git" \
    "fastapi>=0.115.0" "uvicorn[standard]>=0.34.0"

# ── 모델 가중치 (런타임에 볼륨 마운트) ──
# docker run -v ~/docker-data/slam/must3r/weights:/workspace/weights ...
WORKDIR /workspace/weights

# ── MUSt3R 래퍼 노드 (자주 변경 → 마지막) ──
WORKDIR /workspace
COPY server/slam/must3r/ ./slam/must3r/

ENV XFORMERS_DISABLED=1
ENV MUST3R_CHKPT=/workspace/weights/MUSt3R_512.pth
ENV MAPS_DIR=/workspace/maps
ENV PYTHONPATH=/opt/ros/jazzy/lib/python3.12/dist-packages:/opt/ros/jazzy/local/lib/python3.12/dist-packages

EXPOSE 8000 7860 8080

# gateway + MUSt3R SLAM API 동시 실행
CMD ["bash", "-c", ". /opt/ros/jazzy/setup.bash && gateway & uvicorn slam.must3r.api:app --host 0.0.0.0 --port 8000 && wait"]
