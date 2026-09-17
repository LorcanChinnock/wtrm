# wtrm

Delete git worktrees for the current repo

<img width="510" height="271" alt="image" src="https://github.com/user-attachments/assets/d59618bc-dae0-4333-9408-adc5d3e66f9b" />


## Usage

```bash
npx @ljchinnock/wtrm          # interactive picker; non-interactive: dry run
npx @ljchinnock/wtrm -f       # force through uncommitted changes for whatever's deleted
npx @ljchinnock/wtrm -d       # skip the picker, delete everything, skipping dirty ones
npx @ljchinnock/wtrm -d -f    # skip the picker, delete everything, forcing dirty ones too
```

Or install globally - the command itself is still just `wtrm`:

```bash
npm install -g @ljchinnock/wtrm
wtrm
```

## Platforms

macOS, Linux, and Windows. On Windows this runs through Git Bash
