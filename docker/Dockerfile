# syntax=docker/dockerfile:1
#
# Embodied RL training image (PPO / PPO-LSTM).
#
# Build for CPU (default, works on any machine):
#   docker build -t embodied-rl:cpu --build-arg TORCH_VARIANT=cpu .
#
# Build for NVIDIA GPU (Linux host + nvidia-container-toolkit):
#   docker build -t embodied-rl:cuda --build-arg TORCH_VARIANT=cuda .
#
# Note: Apple Silicon (MPS) is NOT available inside Docker — there is no GPU
# passthrough for Metal. On a Mac, this image always runs on CPU, same as any
# other Linux container. Use the CUDA build only when deploying to a Linux
# box with an NVIDIA GPU.

ARG TORCH_VARIANT=cpu
FROM python:3.10-slim AS base

# System deps needed by Box2D (swig), MuJoCo (GL/OSMesa), Atari (ale-py/AutoROM),
# video writing (ffmpeg/opencv), and building wheels in general.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    swig \
    git \
    curl \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    libosmesa6-dev \
    libglfw3 \
    libglew-dev \
    patchelf \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# --- Torch: install the right wheel for the target device -------------------
ARG TORCH_VARIANT
COPY docker/requirements.txt ./requirements.txt

RUN pip install --no-cache-dir --upgrade pip && \
    if [ "$TORCH_VARIANT" = "cuda" ]; then \
        pip install --no-cache-dir torch==2.0.1 --index-url https://download.pytorch.org/whl/cu121; \
    else \
        pip install --no-cache-dir torch==2.0.1 --index-url https://download.pytorch.org/whl/cpu; \
    fi

RUN pip install --no-cache-dir -r requirements.txt

# Atari ROMs require explicit license acceptance (non-interactive here).
RUN AutoROM --accept-license

# --- Project code -------------------------------------------------------------
# Copy in the actual project (rename the "* copy" folders to PPO / PPO-LSTM /
# configs before building, or adjust the paths below to match your layout).
COPY PPO ./PPO
COPY PPO-LSTM ./PPO-LSTM
COPY configs ./configs

# Headless-safe defaults. Atari/MuJoCo rendering (--render) needs a real
# display; this just lets gym import cleanly without one. For an actual
# on-screen render, run the container with X11 forwarding instead of relying
# on Xvfb (see docker-compose.yml comments).
ENV SDL_VIDEODRIVER=dummy \
    PYTHONUNBUFFERED=1

VOLUME ["/app/checkpoints", "/app/runs", "/app/metrics"]

EXPOSE 6006

WORKDIR /app/PPO
ENTRYPOINT ["python", "-u", "main.py"]
CMD ["--env", "CartPole-v1", "--total-steps", "1000000"]