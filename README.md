# embodied_rl
Embodied RL agent designed for generalizable game playing

# Docker setup for embodied_rl

## Where these files go

Put the `docker/` folder at the root of your project, alongside `PPO`, `PPO-LSTM`,
and `configs` (rename the `* copy` folders you have now — the Dockerfile expects
`PPO`, `PPO-LSTM`, `configs`):

```
embodied_rl/
├── docker/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── requirements.txt
│   └── .dockerignore
├── PPO/
├── PPO-LSTM/
└── configs/
```

## Build & run

```bash
cd embodied_rl
docker compose -f docker/docker-compose.yml build ppo
docker compose -f docker/docker-compose.yml run --rm ppo --env LunarLander-v3 --total-steps 500000
docker compose -f docker/docker-compose.yml up board   # http://localhost:6006
```

Checkpoints, TensorBoard runs, and metrics are written to `../checkpoints`,
`../runs`, `../metrics` on your host (bind-mounted), so nothing is lost when
the container exits.

## GPU

The `ppo-gpu` service builds a CUDA-enabled image and requests an NVIDIA GPU
via `nvidia-container-toolkit`. It only works on a Linux host with an NVIDIA
card. Apple Silicon (MPS) has no Docker equivalent — on a Mac this whole setup
runs CPU-only, same as native `mps` unavailable-fallback in `ppo.py`.

## What Docker does NOT replace here

- `--render` / `make test`: these open a real window (pygame/SDL) and, on
  your Mac, an actual Terminal + Safari via `osascript`. None of that works
  in a headless Linux container. Use TensorBoard (`make board` / the `board`
  service) to monitor runs instead of on-screen rendering when training in
  Docker.
- `make tune` / `tune-all`: works fine in the container, just run it as the
  command instead of `main.py --env ...`.

## Rebuilding after code changes

The `PPO`/`PPO-LSTM`/`configs` folders are copied into the image at build
time, so re-run `docker compose build` after editing Python files. If you'd
rather iterate without rebuilding, add a bind mount instead of `COPY` (e.g.
`- ../PPO:/app/PPO` in `docker-compose.yml`).