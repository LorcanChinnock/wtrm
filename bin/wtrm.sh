#!/usr/bin/env bash
set -euo pipefail

for arg in "$@"; do
  if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
    cat <<'EOF'
wtrm - delete git worktrees for the current repo (keeps the main one)

Usage:
  wtrm            interactive: pick which to delete (needs a terminal)
                  non-interactive: dry run, lists what would be removed
  wtrm -f         force through uncommitted changes for whatever's deleted
  wtrm -d         skip the picker, delete everything, skipping dirty ones
  wtrm -d -f      skip the picker, delete everything, forcing dirty ones too
EOF
    exit 0
  fi
done

git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository" >&2; exit 1; }

force=false
skip_picker=false
for arg in "$@"; do
  case "$arg" in
    -f|--force) force=true ;;
    -d|--delete) skip_picker=true ;;
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

draw_picker() {
  printf '\033[2Kspace: toggle  a: all  n: none  enter: confirm  q: cancel\n' >&2
  local i mark ptr
  for ((i = 0; i < n; i++)); do
    mark=' '
    [[ ${checked[i]} -eq 1 ]] && mark='x'
    ptr='  '
    [[ $i -eq $cursor ]] && ptr='> '
    printf '\033[2K%s[%s] %s\n' "$ptr" "$mark" "${targets[i]}" >&2
  done
}

if [[ -t 0 && -t 1 ]] && ! $skip_picker; then
  n=${#targets[@]}
  checked=()
  for ((i = 0; i < n; i++)); do checked[i]=1; done
  cursor=0

  stty_orig=$(stty -g)
  stty -echo -icanon min 1 time 0
  trap 'stty "$stty_orig"; printf "\033[?25h" >&2' EXIT
  printf '\033[?25l' >&2
  draw_picker

  cancelled=false
  while true; do
    IFS= read -rsn1 key
    if [[ $key == $'\x1b' ]]; then
      rest=""
      read -rsn2 -t 0.05 rest || true
      key+="$rest"
    fi
    case "$key" in
      $'\x1b[A') (( cursor > 0 )) && ((cursor--)) || true ;;
      $'\x1b[B') (( cursor < n - 1 )) && ((cursor++)) || true ;;
      ' ') (( checked[cursor] == 1 )) && checked[cursor]=0 || checked[cursor]=1 ;;
      a) for ((i = 0; i < n; i++)); do checked[i]=1; done ;;
      n) for ((i = 0; i < n; i++)); do checked[i]=0; done ;;
      q) cancelled=true; break ;;
      ''|$'\n'|$'\r') break ;;
    esac
    printf '\033[%dA' "$((n + 1))" >&2
    draw_picker
  done

  stty "$stty_orig"
  printf '\033[?25h' >&2
  trap - EXIT

  if $cancelled; then
    echo "cancelled"
    exit 0
  fi

  picked=()
  for ((i = 0; i < n; i++)); do
    (( checked[i] == 1 )) && picked+=("${targets[i]}")
  done
  if (( ${#picked[@]} == 0 )); then
    echo "nothing selected"
    exit 0
  fi
  targets=("${picked[@]}")
elif ! $force && ! $skip_picker; then
  n=0
  for dir in "${targets[@]}"; do
    n=$((n + 1))
    printf "\033[33m[%d/%d] would remove %s\033[0m\n" "$n" "${#targets[@]}" "$dir"
  done
  echo "dry run — rerun with -d (safe) or -f (force) to delete ${#targets[@]} worktree(s)"
  exit 0
fi

total=${#targets[@]}
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
