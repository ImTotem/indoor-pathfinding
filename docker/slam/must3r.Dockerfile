# ── Layer 1: 시스템 + Python (거의 안 바뀜) ──
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3.11 python3.11-dev python3.11-venv python3-pip \
    git cmake build-essential \
    libgl1-mesa-glx libglib2.0-0 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel

# ── Layer 2: PyTorch + xFormers (~3GB, 거의 안 바뀜) ──
RUN python3 -m pip install --no-cache-dir \
    torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 \
    --index-url https://download.pytorch.org/whl/cu126

RUN python3 -m pip install --no-cache-dir \
    xformers==0.0.30 --index-url https://download.pytorch.org/whl/cu126

# ── Layer 3: MUSt3R 의존성 (변경 적음) ──
RUN python3 -m pip install --no-cache-dir \
    cython pyaml scikit-learn open3d viser>=1.0.0 opencv-python-headless pillow

# ── Layer 4: MUSt3R 설치 ──
RUN python3 -m pip install --no-cache-dir \
    must3r@git+https://github.com/naver/must3r.git

WORKDIR /workspace

# viser 웹 GUI 포트
EXPOSE 8012

# 기본: bash (테스트/데모 자유롭게)
CMD ["bash"]
