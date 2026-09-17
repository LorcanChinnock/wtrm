# wtrm

Delete git worktrees for the current repo, keeping the main one.

Dry-run by default — nothing gets deleted unless you pass `-d` or `-f`.

## Usage

```bash
npx wtrm          # dry run: lists worktrees that would be removed
npx wtrm -d       # deletes them, skipping any with uncommitted changes
npx wtrm -f       # deletes them, forcing through uncommitted changes too
npx wtrm -p       # pick which worktrees to delete (needs fzf), safely
npx wtrm -p -f    # pick which worktrees to delete, forcing through changes
```

Or install globally:

```bash
npm install -g wtrm
wtrm -d
```

## Platforms

macOS, Linux, and Windows. On Windows this runs through Git Bash — already on
your PATH if Git is installed, which `wtrm` requires anyway.
