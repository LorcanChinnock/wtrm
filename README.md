# wtrm

Delete all git worktrees for the current repo, keeping the main one.

Dry-run by default — nothing gets deleted unless you pass `-f`/`--force`.

## Usage

```bash
npx wtrm          # dry run: lists worktrees that would be removed
npx wtrm -f       # actually removes them, then prunes
```

Or install globally:

```bash
npm install -g wtrm
wtrm -f
```

## Platforms

macOS, Linux, and Windows. On Windows this runs through Git Bash — already on
your PATH if Git is installed, which `wtrm` requires anyway.
