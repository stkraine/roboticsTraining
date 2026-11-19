#!/usr/bin/env bash
# Create a sibling git worktree + branch for a parallel agent.
# Usage: scripts/new-worktree.sh <name> [base-branch]
set -euo pipefail

name="${1:?usage: new-worktree.sh <name> [base-branch]}"
base="${2:-main}"
root="$(git rev-parse --show-toplevel)"
dest="$(dirname "$root")/$(basename "$root")-$name"

git -C "$root" worktree add "$dest" -b "$name" "$base"
echo "Worktree ready: $dest (branch: $name)"
echo "Start an agent with: cd \"$dest\" && claude"
