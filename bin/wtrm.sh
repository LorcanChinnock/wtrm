#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
wtrm - delete all git worktrees for the current repo (keeps the main one)

Usage:
  wtrm          dry run: list worktrees that would be removed
  wtrm -f       remove them (in parallel), then prune
EOF
  exit 0
fi

git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository" >&2; exit 1; }

force=false
[[ "${1:-}" == "-f" || "${1:-}" == "--force" ]] && force=true

porcelain=$(git worktree list --porcelain)
main=$(awk 'NR==1{print $2}' <<< "$porcelain")
targets=()
while IFS= read -r dir; do
  targets+=("$dir")
done < <(awk -v main="$main" '/^worktree /{ if ($2 != main) print $2 }' <<< "$porcelain")
total=${#targets[@]}

if (( total == 0 )); then
  echo "nothing to remove"
  exit 0
fi

if ! $force; then
  n=0
  for dir in "${targets[@]}"; do
    n=$((n + 1))
    printf "\033[33m[%d/%d] would remove %s\033[0m\n" "$n" "$total" "$dir"
  done
  echo "dry run — rerun with -f to delete $total worktree(s)"
  exit 0
fi

jobs=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)
# shellcheck disable=SC2016 -- expands inside the child bash -c, not here
printf '%s\n' "${targets[@]}" | xargs -P "$jobs" -I{} bash -c '
  git worktree remove "$1" --force && printf "\033[31m✓ [%s]\033[0m\n" "$1"
' _ {}

git worktree prune
echo "removed $total worktree(s)"
