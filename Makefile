# Parent Makefile — orchestrates Docker for both PPO and PPO-LSTM from the
# project root (embodied_rl/). Mirrors PPO/Makefile and PPO-LSTM/Makefile,
# but every target that used to run `$(VENV)/bin/python ...` now runs inside
# the matching docker compose service instead.
#
# Anything variant-specific (PPO vs PPO-LSTM) is exposed as a *-ppo / *-lstm
# pair of targets, same split as having two separate Makefiles today. Shared
# infrastructure (build, board, combine, clean) has one target for both.
#
# Requires: docker, docker compose v2. GPU targets additionally require an
# NVIDIA GPU + nvidia-container-toolkit on a Linux host — there is no GPU
# passthrough for Apple Silicon (MPS), so on a Mac only the CPU targets do
# anything useful.

.PHONY: build build-gpu \
        run-ppo run-lstm run-ppo-gpu run-lstm-gpu \
        tune-ppo tune-lstm \
        tune-vector-ppo tune-vector-lstm \
        tune-image-ppo tune-image-lstm \
        tune-all-ppo tune-all-lstm tune-all \
        board report-ppo report-lstm combine compare-all \
        shell-ppo shell-lstm \
        clean clean-docker help

COMPOSE := docker compose -f docker/docker-compose.yml

# ── Per-variant run options (override on the command line) ────────────────
ENV_PPO       ?= ALE/Pong-v5
STEPS_PPO     ?= 1000000
ENV_LSTM      ?= ALE/Pong-v5
STEPS_LSTM    ?= 3000000

# ── Tuning envs — identical lists in both original Makefiles ───────────────
V_ENVS := \
	CartPole-v1 \
	Pendulum-v1 \
	Acrobot-v1 \
	MountainCar-v0 \
	MountainCarContinuous-v0 \
	LunarLander-v3 \
	LunarLanderContinuous-v3 \
	BipedalWalker-v3 \
	BipedalWalkerHardcore-v3 \
	HalfCheetah-v4 \
	Hopper-v4 \
	Walker2d-v4 \
	Ant-v4 \
	Humanoid-v4 \
	HumanoidStandup-v4 \
	Swimmer-v4 \
	Reacher-v4 \
	InvertedPendulum-v4 \
	InvertedDoublePendulum-v4

I_ENVS := \
	ALE/MsPacman-v5 \
	ALE/Pong-v5 \
	ALE/Breakout-v5 \
	ALE/SpaceInvaders-v5 \
	ALE/Asteroids-v5 \
	ALE/Pitfall-v5 \
	ALE/Centipede-v5 \
	ALE/DonkeyKong-v5 \
	CarRacing-v3

TUNE_ENV            ?= CartPole-v1
TUNE_TRIALS_VECTOR   ?= 50
TUNE_STEPS_VECTOR    ?= 50000

# These two differ between variants in the original Makefiles — keep the
# same split here (LSTM tunes image envs longer, with more trials).
TUNE_STEPS_IMAGE_PPO  ?= 200000
TUNE_TRIALS_IMAGE_PPO ?= 20
TUNE_STEPS_IMAGE_LSTM  ?= 300000
TUNE_TRIALS_IMAGE_LSTM ?= 30

# ── Reporting ───────────────────────────────────────────────────────────────
COMBINED_METRICS := combined_metrics
PPO_METRICS      := PPO/metrics
LSTM_METRICS     := PPO-LSTM/metrics/ppo_lstm

help:
	@echo "build / build-gpu           build both variants' images (CPU / CUDA)"
	@echo "run-ppo / run-lstm          train (ENV_PPO/ENV_LSTM, STEPS_PPO/STEPS_LSTM)"
	@echo "run-ppo-gpu / run-lstm-gpu  same, on the CUDA image (Linux+NVIDIA only)"
	@echo "tune-ppo / tune-lstm        single-env Optuna tune (TUNE_ENV)"
	@echo "tune-vector-ppo/-lstm       tune across all vector envs"
	@echo "tune-image-ppo/-lstm        tune across all image/Atari envs"
	@echo "tune-all-ppo/-lstm/-all     everything above"
	@echo "board                       TensorBoard for both variants at :6006"
	@echo "report-ppo / report-lstm    print/save that variant's metrics table"
	@echo "combine / compare-all       merge PPO + PPO-LSTM metrics, then report"
	@echo "shell-ppo / shell-lstm      drop into a bash shell in that image"
	@echo "clean / clean-docker        remove local venvs / docker images+containers"

# ── Build ───────────────────────────────────────────────────────────────────
build:
	$(COMPOSE) build ppo ppo-lstm

build-gpu:
	$(COMPOSE) build ppo-gpu ppo-lstm-gpu

# ── Run (train) ─────────────────────────────────────────────────────────────
# Same --render caveat as the individual Makefiles' `run` target: rendering
# needs a real display and won't work headless in Docker. These targets run
# the equivalent of `compare` (train for N steps, no --render).
run-ppo: build
	$(COMPOSE) run --rm ppo --env $(ENV_PPO) --total-steps $(STEPS_PPO)

run-lstm: build
	$(COMPOSE) run --rm ppo-lstm --env $(ENV_LSTM) --total-steps $(STEPS_LSTM)

run-ppo-gpu: build-gpu
	$(COMPOSE) run --rm ppo-gpu --env $(ENV_PPO) --total-steps $(STEPS_PPO)

run-lstm-gpu: build-gpu
	$(COMPOSE) run --rm ppo-lstm-gpu --env $(ENV_LSTM) --total-steps $(STEPS_LSTM)

# ── Tune ────────────────────────────────────────────────────────────────────
tune-ppo: build
	$(COMPOSE) run --rm ppo --tune --env $(TUNE_ENV) \
		--trials $(TUNE_TRIALS_VECTOR) --total-steps $(TUNE_STEPS_VECTOR)

tune-lstm: build
	$(COMPOSE) run --rm ppo-lstm --tune --env $(TUNE_ENV) \
		--trials $(TUNE_TRIALS_VECTOR) --total-steps $(TUNE_STEPS_VECTOR)

tune-vector-ppo: build
	@for env in $(V_ENVS); do \
		echo "[ppo] Tuning $$env..."; \
		$(COMPOSE) run --rm ppo --tune --env $$env \
			--trials $(TUNE_TRIALS_VECTOR) --total-steps $(TUNE_STEPS_VECTOR) || break; \
	done

tune-vector-lstm: build
	@for env in $(V_ENVS); do \
		echo "[ppo-lstm] Tuning $$env..."; \
		$(COMPOSE) run --rm ppo-lstm --tune --env $$env \
			--trials $(TUNE_TRIALS_VECTOR) --total-steps $(TUNE_STEPS_VECTOR) || break; \
	done

# Note the different steps/trials per variant — matches the two original
# Makefiles, which were not identical here.
tune-image-ppo: build
	@for env in $(I_ENVS); do \
		echo "[ppo] Tuning $$env..."; \
		$(COMPOSE) run --rm ppo --tune --env $$env \
			--trials $(TUNE_TRIALS_IMAGE_PPO) --total-steps $(TUNE_STEPS_IMAGE_PPO) || break; \
	done

tune-image-lstm: build
	@for env in $(I_ENVS); do \
		echo "[ppo-lstm] Tuning $$env..."; \
		$(COMPOSE) run --rm ppo-lstm --tune --env $$env \
			--trials $(TUNE_TRIALS_IMAGE_LSTM) --total-steps $(TUNE_STEPS_IMAGE_LSTM) || break; \
	done

tune-all-ppo: tune-vector-ppo tune-image-ppo
tune-all-lstm: tune-vector-lstm tune-image-lstm
tune-all: tune-all-ppo tune-all-lstm

# ── Monitoring ──────────────────────────────────────────────────────────────
# Combined TensorBoard for both variants (see docker/docker-compose.yml's
# `board` service, which uses --logdir_spec to label the two runs dirs).
board: build
	$(COMPOSE) up board

# ── Reporting ───────────────────────────────────────────────────────────────
# report.py has no third-party dependencies, so this runs on the host with
# whatever `python3` you already have — no need to go through Docker for it.
report-ppo:
	python3 PPO/report.py

report-lstm:
	python3 PPO-LSTM/report.py

combine:
	mkdir -p $(COMBINED_METRICS)
	@if [ -d "$(PPO_METRICS)" ]; then cp -r $(PPO_METRICS)/. $(COMBINED_METRICS)/; fi
	@if [ -d "$(LSTM_METRICS)" ]; then cp -r $(LSTM_METRICS) $(COMBINED_METRICS)/ppo_lstm; fi
	@echo "  Combined metrics -> $(COMBINED_METRICS)"

compare-all: combine
	python3 PPO/report.py --metrics-dir $(COMBINED_METRICS)

# ── Debugging ───────────────────────────────────────────────────────────────
shell-ppo: build
	$(COMPOSE) run --rm --entrypoint bash ppo

shell-lstm: build
	$(COMPOSE) run --rm --entrypoint bash ppo-lstm

# ── Cleanup ─────────────────────────────────────────────────────────────────
# Local venvs (if you still use `make install`/`make run` inside PPO/ or
# PPO-LSTM/ directly) are untouched by Docker and vice versa — clean each
# side separately.
clean-docker:
	$(COMPOSE) down --rmi local -v

clean:
	rm -rf PPO/ppo_env PPO/__pycache__ PPO/runs
	rm -rf PPO-LSTM/ppo_env PPO-LSTM/__pycache__ PPO-LSTM/runs
	rm -rf $(COMBINED_METRICS)