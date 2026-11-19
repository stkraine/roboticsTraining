# Isaac Sim research (as of 2026-11-18)

Latest stable: **Isaac Sim 6.2.0** (GitHub release v6.2.0, 2026-10-14; v7.0.0a1 is a pre-release, ignore).
Sources: https://github.com/isaac-sim/IsaacSim/releases , https://docs.isaacsim.omniverse.nvidia.com/latest/overview/release_notes.html

## 1. System requirements
Source: https://docs.isaacsim.omniverse.nvidia.com/latest/installation/requirements.html
- OS: Ubuntu 22.04 or 24.04 x86_64 (22.04 deprecated, to be removed). Pip wheels need glibc >= 2.35.
- GPU: needs RT cores (A100/H100 unsupported). Min GeForce RTX 4080 (16 GB VRAM); good RTX 5080; ideal RTX PRO 6000 Blackwell (48 GB).
- Driver (Linux): 595.58.03 listed for all tiers.
- RAM 32 GB min (64 GB recommended); 50 GB SSD min.
- Local machine observed: Ubuntu 22.04 (glibc 2.35), RTX 3090 24 GB, driver 595.99.02, system python 3.10.
  The 3090 is below the documented minimum GPU (4080) but has RT cores and enough VRAM; expect it to work but unsupported/slower. Verify with the compatibility check.

## 2. Install options
- **pip (recommended for a repo)**: Python **3.12 required**. Source: https://docs.isaacsim.omniverse.nvidia.com/latest/installation/install_python.html
  ```
  python3.12 -m venv env_isaacsim && source env_isaacsim/bin/activate
  pip install --upgrade pip
  pip install torch==2.11.0 --index-url https://download.pytorch.org/whl/cu128   # cu130 also offered
  pip install "isaacsim[all,extscache]==6.2.0.0" --extra-index-url https://pypi.nvidia.com
  ```
  Run scripts with plain `python script.py`; no python.sh. Bundles: all, extscache, compatibility-check, ros2.
  Ubuntu 22.04 ships Python 3.10, so need deadsnakes or conda/uv for 3.12. Conda variant (`python=3.12`) needs libstdc++ CXXABI_1.3.15.
- **Binary zip** (`isaac-sim-standalone-6.2.0-linux-x86_64.zip`): unzip, `./post_install.sh`, `./isaac-sim.sh`; scripts via `./python.sh` (bundled Python). Source: https://docs.isaacsim.omniverse.nvidia.com/latest/installation/install_workstation.html , https://docs.isaacsim.omniverse.nvidia.com/latest/python_scripting/manual_standalone_python.html
  Large, lives outside the repo; fine for GUI work, worse for reproducibility.
- **Docker/NGC**: `nvcr.io/nvidia/isaac-sim:6.2.0`, needs `ACCEPT_EULA=Y`, `--gpus all`, NVIDIA Container Toolkit, `--network=host` for WebRTC streaming, cache volume mounts (UID 1234). Entry `./runheadless.sh -v`. Source: https://docs.isaacsim.omniverse.nvidia.com/latest/installation/install_container.html
  Good for servers/CI; GUI only via WebRTC streaming.
- Build from source (Apache-2.0 repo, GCC 11 on 24.04): not needed. https://github.com/isaac-sim/IsaacSim

## 3. Headless vs GUI, launching
- Standalone Python script creates `SimulationApp` **first**; all omni/isaacsim.* imports come after it.
  ```python
  from isaacsim import SimulationApp
  simulation_app = SimulationApp({"headless": True})   # False for GUI
  # ... isaacsim.* / omni.* / pxr imports here ...
  simulation_app.update()   # one frame
  simulation_app.close()
  ```
  (Docs also show `import isaacsim; from isaacsim.simulation_app import SimulationApp` for pip.)
- Pip: `isaacsim` command launches the full app; `isaacsim isaacsim.exp.full.streaming --no-window` = headless WebRTC streaming.
- Official examples add `--headless` argparse flag and enable `omni.kit.livestream.app` for headless streaming (v6.2.0 `franka_pick_place_fsm.py`).
- Binary: `./python.sh script.py` (sets ISAAC_PATH, LD_LIBRARY_PATH, bundled ROS2 libs; `--no-ros-env` disables).
- Extensions not all enabled in standalone mode; use `enable_extension(...)`.
- Env gotcha: `SimulationApp` pulls its own Python deps; mixing with other heavy packages in the same venv can conflict, keep the venv dedicated.

## 4. Scene: Franka + box, programmatically
Source (official v6.2.0 example, new "experimental" core API; the old `isaacsim.core.api` World/`add_frankas` examples are under `deprecated/`):
https://github.com/isaac-sim/IsaacSim/blob/v6.2.0/source/standalone_examples/api/isaacsim.core.experimental.api/control_frankas.py
Pattern:
```python
from isaacsim.storage.native import get_assets_root_path
import isaacsim.core.experimental.utils.stage as stage_utils
import isaacsim.core.experimental.utils.app as app_utils
from isaacsim.core.experimental.objects import GroundPlane, DistantLight
from isaacsim.core.experimental.prims import Articulation

root = get_assets_root_path()          # None if assets unreachable -> check and exit
stage_utils.create_new_stage()
GroundPlane("/World/GroundPlane", positions=[0,0,0]); DistantLight("/World/DistantLight")
stage_utils.add_reference_to_stage(
    usd_path=root + "/Isaac/Robots_Multiphysics/FrankaRobotics/FrankaPanda/franka/franka.usda",
    path="/World/Franka", variants=[("Gripper","alternatefinger"),("Mesh","quality")])
franka = Articulation("/World/Franka")
app_utils.play(); simulation_app.update()
franka.set_dof_position_targets([...9 values...])
```
- Box/rigid body: the same package has `isaacsim.core.experimental.objects` shapes (`shapes/cube.py`) and `isaacsim.core.experimental.prims.RigidPrim` (rigid_prim.py, with set_masses/set_velocities). I did not read their exact signatures; check the source or fall back to raw `pxr` (`UsdGeom.Cube` + `UsdPhysics.RigidBodyAPI`/`CollisionAPI`/`MassAPI`), which is stable USD. Stacking/pick-place examples with cubes: `standalone_examples/tutorials/state_machine/franka_pick_place_fsm.py`, `.../api/isaacsim.robot_motion.examples/manipulation/pick_place.py`.
- Assets: default root is the NVIDIA cloud catalog (6.2 versioned; needs Internet); `get_assets_root_path()` resolves it. Nucleus is optional (Omniverse Launcher/Nucleus Workstation retired 2025-10-01; local override via `persistent/isaac/asset_root/default`, `omniverse://<host>/NVIDIA/Assets/Isaac/6.2`). Offline use: download asset packs (see "Accessing assets" doc). Franka asset path changed across versions (older: `/Isaac/Robots/FrankaRobotics/FrankaPanda/franka.usd`), so pin version and verify path.
  Sources: https://docs.isaacsim.omniverse.nvidia.com/latest/installation/install_faq.html
- Alternative: author your own scene as a `.usda` in the repo and reference it, keeping robots as references to NVIDIA assets.

## 5. Pitfalls
- EULA: pip needs `OMNI_KIT_ACCEPT_EULA=YES` (env or `os.environ` before import; otherwise interactive prompt blocks); Docker needs `ACCEPT_EULA=Y`.
- First launch: shader cache warmup is slow (GUI 5-10 min to load; first headless run also slow). Cache at `~/.cache/ov/Kit`; `warmup.sh` exists (binary/Docker). `clear_caches.sh` for conflicts (e.g. source vs pip). Persist caches in Docker.
- Version pinning: pin `isaacsim[...]==6.2.0.0` and torch 2.11.0; APIs moved (Cortex removed in 6.x; core.api -> core.experimental; asset catalog versioned per release). Tutorials online for 4.x/5.x often break.
- Licensing: Isaac Sim source is Apache-2.0, but binaries/pip/container are under the NVIDIA Omniverse License Agreement (accept EULA); NVIDIA assets have their own terms. Don't commit downloaded assets/binaries.
- Imports before `SimulationApp` fail; don't call `close()` in notebooks.
- Driver: pin to >= 595.58.03; docker streaming may lag behind newest drivers.
- Docker requires `--network=host` for streaming; bridge ports don't work.

## Recommendation
Pip install in a Python 3.12 venv (pinned `isaacsim[all,extscache]==6.2.0.0`, torch 2.11.0) with `OMNI_KIT_ACCEPT_EULA=YES`, scripts as plain `python` using `SimulationApp({"headless": args.headless})`. Provide a Dockerfile/compose as optional secondary path. Suggested layout: `pyproject`/`requirements.txt` (pinned), `scripts/setup_env.sh`, `scripts/check_env.sh` (nvidia-smi, glibc, python3.12, compatibility-check), `src/<pkg>/scene.py` (scene builder), `scripts/run_*.py`, `assets/` for custom USD only, `docs/`.

## Open questions
- RTX 3090 vs documented 4080 minimum: run `isaacsim isaacsim.exp.compatibility_check` to confirm.
- Python 3.12 provisioning on Ubuntu 22.04 (uv vs conda vs deadsnakes)?
- Exact RigidPrim/Cube signatures in the experimental API (not read); raw pxr fallback is safe.
- Offline asset pack workflow and exact Franka path in 6.2 catalog (verify with `get_assets_root_path()` at runtime).
- GUI needed locally or WebRTC streaming enough?
