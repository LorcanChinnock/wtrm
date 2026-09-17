#!/usr/bin/env bash
set -euo pipefail

for arg in "$@"; do
  if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
    cat <<'EOF'
wtrm - delete git worktrees for the current repo (keeps the main one)

Usage:
  wtrm            dry run: list worktrees that would be removed
  wtrm -d         delete them, skipping any with uncommitted changes
  wtrm -f         delete them, forcing through uncommitted changes too
  wtrm -p         pick which worktrees to delete (needs fzf), safely
  wtrm -p -f      pick which worktrees to delete, forcing through changes
EOF
    exit 0
  fi
done

git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository" >&2; exit 1; }

force=false
delete=false
pick=false
for arg in "$@"; do
  case "$arg" in
    -f|--force) force=true ;;
    -d|--delete) delete=true ;;
    -p|--pick) pick=true ;;
    *) echo "wtrm: unknown option: $arg" >&2; exit 1 ;;
  esac
done

porcelain=$(git worktree list --porcelain)
main=$(awk 'NR==1{print $2}' <<< "$porcelain")
targets=()
while IFS= read -r dir; do
  targets+=("$dir")
done < <(awk -v main="$main" '/^worktree /{ if ($2 != main) print $2 }' <<< "$porcelain")

if (( ${#targets[@]} == 0 )); then
  echo "nothing to remove"
  exit 0
fi

if $pick; then
  command -v fzf >/dev/null 2>&1 || { echo "wtrm: --pick requires fzf (brew install fzf)" >&2; exit 1; }
  picked=()
  while IFS= read -r dir; do
    picked+=("$dir")
  done < <(printf '%s\n' "${targets[@]}" | fzf --multi --height=40% --header='tab: select, enter: confirm, esc: cancel')
  if (( ${#picked[@]} == 0 )); then
    echo "nothing selected"
    exit 0
  fi
  targets=("${picked[@]}")
fi

total=${#targets[@]}

if ! $force && ! $delete && ! $pick; then
  n=0
  for dir in "${targets[@]}"; do
    n=$((n + 1))
    printf "\033[33m[%d/%d] would remove %s\033[0m\n" "$n" "$total" "$dir"
  done
  echo "dry run — rerun with -d (safe) or -f (force) to delete $total worktree(s)"
  exit 0
fi

jobs=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)
tmp=$(mktemp)

if $force; then
  # shellcheck disable=SC2016
  printf '%s\n' "${targets[@]}" | xargs -P "$jobs" -I{} bash -c '
    if git worktree remove "$1" --force; then
      printf "\033[31m✓ removed [%s]\033[0m\n" "$1"
    else
      printf "\033[33m✗ failed [%s]\033[0m\n" "$1"
    fi
  ' _ {} | tee "$tmp" || true
else
  # shellcheck disable=SC2016
  printf '%s\n' "${targets[@]}" | xargs -P "$jobs" -I{} bash -c '
    if git worktree remove "$1" 2>/dev/null; then
      printf "\033[31m✓ removed [%s]\033[0m\n" "$1"
    else
      printf "\033[33m⚠ skipped, uncommitted changes [%s]\033[0m\n" "$1"
    fi
  ' _ {} | tee "$tmp" || true
fi

removed=$(grep -c '✓' "$tmp" || true)
skipped=$(grep -c '⚠\|✗' "$tmp" || true)
rm -f "$tmp"

git worktree prune

if (( skipped > 0 )); then
  echo "removed $removed, skipped $skipped (of $total)"
else
  echo "removed $removed worktree(s)"
fi
