#!/usr/bin/env bash
set -euo pipefail

force=false
[[ "${1:-}" == "-f" || "${1:-}" == "--force" ]] && force=true

main=$(git worktree list --porcelain | awk 'NR==1{print $2}')

git worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r dir; do
  [[ "$dir" == "$main" ]] && continue
  if $force; then
    echo -e "\033[31m==> removing $dir\033[0m"
    git worktree remove "$dir" --force
  else
    echo -e "\033[33m[dry-run] would remove $dir\033[0m"
  fi
done

if $force; then
  git worktree prune
else
  echo -e "\033[33mdry run. rerun with -f to delete\033[0m"
fi
