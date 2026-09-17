# wtrm

Delete git worktrees for the current repo, keeping the main one.

Run it in a terminal and it shows an interactive picker — everything's
pre-selected, space to toggle, enter to confirm, q to cancel. No terminal
(scripts, CI)? It falls back to a dry-run listing unless you pass `-d`/`-f`.

## Usage

```bash
npx wtrm          # interactive picker; non-interactive: dry run
npx wtrm -f       # force through uncommitted changes for whatever's deleted
npx wtrm -d       # skip the picker, delete everything, skipping dirty ones
npx wtrm -d -f    # skip the picker, delete everything, forcing dirty ones too
```

Or install globally:

```bash
npm install -g wtrm
wtrm
```

## Platforms

macOS, Linux, and Windows. On Windows this runs through Git Bash — already on
your PATH if Git is installed, which `wtrm` requires anyway.
