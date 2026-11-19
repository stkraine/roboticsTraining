# Isaac Lab research (as of 2026-11-18)

Method: GitHub release pages plus a shallow clone of tag `v3.0.0` (inspected, not modified). The docs site was returning 503 or redirects, so doc claims are taken from `docs/source/*.rst` in the tag. Items marked UNVERIFIED were not confirmed.

## 1. Versions and install

Latest stable: **v3.0.0** (released 20 Oct 2026). Source: https://github.com/isaac-sim/IsaacLab/releases/tag/v3.0.0

| Isaac Lab | Isaac Sim | Notes |
|---|---|---|
| v3.0.0 (GA) | 6.2 (`isaacsim[all,extscache]==6.2.0.0`, `pyproject.toml` ~L180) | Python 3.12 only (`requires-python = ">=3.12,<3.13"`), PyTorch 2.11 + CUDA 13.0, Warp 1.17, Newton 1.6.1, RSL-RL 5.5.1 |
| v3.0.0-EA / beta2.x / beta | 6.1 / 6.0.1 / 6.0 | pre-releases |
| v2.3.x | 5.1 | Isaac Lab 2.x line; Isaac Sim 5.1 and older are stated as unsupported by 3.0 |

- Isaac Sim is now **optional** in 3.0. Newton physics (MuJoCo-Warp) runs kit-less with no Isaac Sim. PhysX needs either `--extra ovphysx` or `--extra isaacsim`.
- Do not upgrade a 2.x environment in place. Create a fresh Python 3.12 env.
- Requirements: Ubuntu 22.04+ x86_64 (also aarch64/DGX Spark, Windows 11), NVIDIA GPU with compute capability 7.5+ (Turing or newer), a driver new enough for CUDA 13 (`docs/source/isaaclab/installation.rst` L95-135). GLIBC 2.35+ is needed for the Isaac Sim pip packages.

Install methods (`docs/source/isaaclab/installation.rst`):
1. **uv from a source checkout (recommended).** `git clone --branch v3.0.0 --depth 1 https://github.com/isaac-sim/IsaacLab.git`, then `uv run isaaclab train ...`. uv resolves the env on each call. Add `--extra isaacsim` for full PhysX/RTX.
2. **pip/uv wheel.** `uv venv --python 3.12 --seed env_isaaclab`, then `uv pip install isaaclab==3.0.0` (L676) plus the CUDA 13.0 torch build. Extras: `isaaclab[isaacsim]`, `[all]`, and others.
3. **Docker.** `docker/container.py` wraps docker compose. Dockerfiles: `Dockerfile.base`, `.kitless`, `.ros2`, `.curobo`. Also a cluster/HPC interface.

## 2. External project pattern

Use the built-in template generator rather than forking. Source: `docs/source/developer-tools/template_generator.rst`, https://isaac-sim.github.io/IsaacLab/main/source/developer-tools/template_generator.html (UNVERIFIED that the URL path is exact).

- Run `uv run isaaclab --new` (or `-n`) from the checkout or from a uv project with the isaaclab wheel installed.
- Choose **External (recommended)**. This produces a standalone, installable uv project with a `src` layout, task registration, per-library agent configs, `tests/test_registration.py`, and pytest markers (`unit`, `integration`, `smoke`, `kitless`).
- Content options: Cartpole (runnable), Stubbed (`NotImplementedError` and `MISSING`), Blank.
- Workflow options: manager-based single-agent, direct single-agent, direct multi-agent.
- Dependency link: pins to the installed isaaclab version from a wheel. From a source checkout it records relative editable paths in `[tool.uv.sources]`, so regenerate or fix them if directories move.
- Internal option (writes into `source/isaaclab_tasks`) is only for contributing upstream.
- External tasks are discovered by the CLI (`load_external_tasks()` in `isaaclab_rl/entrypoints/dispatch.py`).

## 3. Built-in lift/pick tasks and config layout

**Task IDs and locations changed in 3.0. The 2.x ID `Isaac-Lift-Cube-Franka-v0` is not the primary ID anymore.**

- `Isaac-Lift-Franka`: `source/isaaclab_tasks/isaaclab_tasks/core/lift/config/franka/__init__.py`.
  - Entry point `isaaclab.envs:ManagerBasedRLEnv`; env cfg `franka_env_cfg:FrankaLiftEnvCfg`; only `rsl_rl_ppo_cfg:FrankaPPORunnerCfg` is registered (`default_agent: rsl_rl`).
  - Base cfg `core/lift/lift_env_cfg.py`, with `mdp/` and an ADR curriculum. Defaults to 4096 envs with 3 m spacing.
  - Physics selected by `preset(...)` variants, so `physics=newton_mjwarp`, `physics=isaacsim_physx` and so on are Hydra-style overrides.
  - Other core variants: `Isaac-Lift-Soft-Franka`, `-Cloth-`, `-Cable-`, `-Camera`, `Isaac-Lift-KukaAllegro`, `Isaac-Reach-Franka`, `Isaac-Reach-Franka-OSC`.
- Legacy cube-lift: `IsaacContrib-Lift-Cube-Franka` (also `-IK-Abs`, `-IK-Rel`) under `isaaclab_tasks/contrib/lift/`. It still registers configs for rsl_rl, skrl, rl_games and sb3. Also in contrib: `stack`, `pick_place` (GR1/G1 humanoids), `cabinet`, `place`, `reorient`.
- Layout (manager-based): `*_env_cfg.py` composes `SceneCfg`, `ObservationsCfg`, `ActionsCfg`, `RewardsCfg`, `TerminationsCfg`, `EventCfg` and `CurriculumCfg` as `@configclass`es, plus `mdp/` for custom term functions. Robot-specific subclasses live in `config/<robot>/`, with `agents/` holding RL hyperparameters and `gym.register` in `__init__.py`. Direct workflow is one env class that implements `_get_observations` and `_get_rewards` itself (`docs/source/how-to/create_direct_rl_env.rst`).
- Whether the core Franka lift cfg's "lift cube" matches "pick up a box" exactly: the cube is a rigid object and the reward is to lift and track a goal pose. A box likely needs only a spawn-shape/size change. UNVERIFIED in sim.

## 4. RL libraries and commands

Backends in `isaaclab_rl/entrypoints/backends/`: **rsl_rl** (default), **skrl**, **rl_games**, **sb3**, plus torchrl and rlinf (new). Multi-GPU (`train_multigpu`) supports rsl_rl, rl_games and skrl (torch). It does not support SB3.

```
uv run isaaclab train --rl_library rsl_rl --task Isaac-Lift-Franka physics=newton_mjwarp
uv run --extra isaacsim isaaclab train --rl_library rsl_rl --task Isaac-Lift-Franka physics=isaacsim_physx
uv run isaaclab play  --rl_library rsl_rl --task Isaac-Lift-Franka --viz newton_gl   # --checkpoint to select
```
Per-library extras: `--extra skrl`, `--extra rl-games`, `--extra sb3` (extras names: UNVERIFIED for sb3). The legacy `scripts/reinforcement_learning/train.py` and `play.py` are thin wrappers around the same entrypoint. Common flags: `--num_envs --seed --max_iterations --video --video_length --video_interval --agent --distributed`.

## 5. Headless, logs, tests

- **Headless is the default**: no visualizer is requested unless `--viz <kind>` is passed (`newton_gl`, `kit`, `viser`, `rerun`, ...). `--viz none` is also parsed. There is no `--headless` flag in the unified CLI (checked by grep only). `AppLauncher` is largely replaced by `launch_simulation`. `--cpu` was removed; use `--device cpu`.
- **Logs and checkpoints** are relative to the CWD: `logs/<library>/<experiment_name>/<timestamp_run_name>/` (e.g. `logs/rsl_rl/...`, `logs/rl_games/<config>`). rsl_rl checkpoints match `model_*.pt`. Each run also gets a run manifest file. TensorBoard can be pointed at `logs/`. Videos are enabled by `--video`.
- **Tests**: Isaac Lab itself uses `uv run python -m pytest source/isaaclab/test/...` (`docs/source/refs/contributing.rst` ~L758). Generated external projects use `uv run pytest tests` and ship a registration test. Repo tests under `source/isaaclab_tasks/test` are not installed, so vendor your own harness.

## 3.0 migration gotchas

Quaternion order is now (x, y, z, w). `.data.*` returns `ProxyArray` (use `.torch`). The SB3 default action bounds are now [-1, 1]. Observation noise callbacks no longer copy data. Most 2.x tutorials and blog posts are stale.

## Recommendation

Install v3.0.0 via uv from a source checkout, which stays unmodified. Generate an **External, Stubbed or Cartpole, manager-based single-agent, rsl_rl PPO** project with `uv run isaaclab --new` in the user's own repo. Copy `core/lift` (`lift_env_cfg.py`, `franka_env_cfg.py`, `mdp`) as the starting point and register it under your own task ID. Swap the cube for a box, then train with rsl_rl. Start with `physics=newton_mjwarp` for kit-less iteration and verify on `isaacsim_physx` (PhysX) before trusting contact-heavy grasping.

## Open questions

- Is an Isaac Sim 6.2-capable GPU/driver (CUDA 13 driver, Turing+) available on the target machine? Is an Ubuntu 22.04+ host assumed?
- Newton versus PhysX grasp fidelity for Franka lift. The docs mention a "transfer policies between physx and newton" how-to (`docs/source/how-to/transfer_policies_between_physx_and_newton.rst`), which I did not read.
- Whether to use Isaac Sim at all (kit-less) or need RTX cameras and sim-to-real, which would make `--extra isaacsim` necessary.
- Exact docs URLs were not verified live (503s). The authoritative text is in the cloned v3.0.0 tree.
