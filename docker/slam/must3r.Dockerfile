# ── Layer 1: 시스템 + Python + uv (거의 안 바뀜) ──
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3.11 python3.11-dev python3.11-venv \
    git cmake build-essential curl \
    libgl1-mesa-glx libglib2.0-0 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# ── Layer 2: PyTorch + xFormers (거의 안 바뀜) ──
# cu128 — RTX 5060 Ti (sm_120 Blackwell) 지원
RUN uv pip install --system --no-cache \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128

RUN uv pip install --system --no-cache \
    xformers --index-url https://download.pytorch.org/whl/cu128

# ── Layer 3: MUSt3R + 의존성 ──
RUN uv pip install --system --no-cache \
    "must3r@git+https://github.com/naver/must3r.git" \
    "gradio>=5.0.0"

# ── Layer 4: 모델 가중치 (~1.5GB, 변경 없음 → 캐시) ──
WORKDIR /workspace/weights
RUN curl -LO https://download.europe.naverlabs.com/ComputerVision/MUSt3R/MUSt3R_512.pth && \
    curl -LO https://download.europe.naverlabs.com/ComputerVision/MUSt3R/MUSt3R_512_retrieval_trainingfree.pth && \
    curl -LO https://download.europe.naverlabs.com/ComputerVision/MUSt3R/MUSt3R_512_retrieval_codebook.pkl

WORKDIR /workspace

# Gradio UI + viser 3D 뷰어
EXPOSE 7860 8080

CMD ["bash"]
