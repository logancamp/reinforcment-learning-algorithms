# Reinforcement Learning Algorithms

From-scratch PyTorch implementations of PPO and PPO-LSTM, tuned and tested
across ~25 Gymnasium environments (classic control, Box2D, MuJoCo, Atari).

Each variant lives in its own folder (`PPO/`, `PPO-LSTM/`) with its own
Makefile. Optuna handles per-environment hyperparameter tuning, TensorBoard
and JSON metrics track training, and `report.py` compares results across
environments and variants. A Dockerized setup wraps both for reproducible
runs.

## Quick start

Native (per variant):

```bash
cd PPO            # or PPO-LSTM
make install
make run
```

Docker (both variants, from the project root):

```bash
make build
make run-ppo ENV_PPO=LunarLander-v3
make board          # TensorBoard, localhost:6006
```

See `docker/` for the Dockerfile/compose setup, and `configs/` for tuned
hyperparameters and scores per environment.
