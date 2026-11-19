# roboticsTraining

Robotics training project. Stack, simulator, and layout are still being decided — update this file as they are.

## Project goals
- Create a simulation environment for robotics training
- Train robots to do one task, such as pick up a box

## Layout
- `.claude/agents/` — subagent definitions (researcher, implementer, reviewer)
- `scripts/` — helper scripts (e.g. `new-worktree.sh`)
- `docs/` — notes and research summaries written by agents (create as needed)

## Commands
- TODO: install / build / test / lint commands. Agents must use these to verify work.

## Conventions
- Small, focused commits on a feature branch; never commit directly to `main`.
- Do not commit large artifacts (checkpoints, datasets, logs). Add them to `.gitignore`.
- Keep experiments reproducible: record seeds, configs, and versions.

## Multi-agent workflow
- Each parallel agent works in its own git worktree/branch (`scripts/new-worktree.sh <name>`).
- Agents touch only files in their assigned scope; if a change is needed outside it, report back instead.
- Roles:
  - **researcher** — read-only investigation; writes findings to `docs/` only.
  - **implementer** — writes code and tests in its own worktree.
  - **reviewer** — read-only review of a diff; runs tests, reports issues.
- Every agent's final report should state: what changed, how it was verified, and open questions.
