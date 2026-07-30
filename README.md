# macos-to-linux-compat

> MacOS → Linux compatibility helper for AI coding assistants.

[中文文档](./README.zh-CN.md)

## What This Solves

When you use AI coding tools (Claude Code, Cursor, Aider, Continue, etc.) on macOS, three common cross-platform headaches keep coming up:

1. **tar warnings on Linux** — `tar: Ignoring unknown extended header keyword 'LIBARCHIVE.xattr.com.apple.provenance'`
2. **Wrong file ownership** — macOS user uid (501) gets baked into archives; files become "orphaned" after extraction on Linux
3. **Slow builds** — Default Docker / apt / yum / pip / npm sources are hosted overseas; builds from China time out

This skill makes AI assistants automatically apply cross-platform-safe rules when working on macOS:

- Proper `tar` / `zip` / `rsync` / `scp` flags that strip macOS-specific metadata
- `--no-same-owner` advice when extracting on Linux
- China-friendly mirrors for `apt`, `yum`, `dnf`, `apk`, `pip`, `npm`, `go`, `cargo`, `composer`
- Coverage for `Dockerfile`, `docker-compose`, GitHub Actions, GitLab CI, Jenkinsfile

## Features

- ✅ `tar` packing: `--no-acls --no-xattrs --no-fflags --no-mac-metadata`
- ✅ `tar` extraction: `--no-same-owner`
- ✅ `apt` / `yum` / `dnf` / `apk` mirrors: Tsinghua / Aliyun
- ✅ `pip` / `npm` / `go` / `cargo` / `composer` mirrors
- ✅ Docker / CI / CD configuration aware
- ✅ Standalone verification scripts

## Installation

### One-Click Install (recommended)

After cloning the repository, run:

```bash
./install.sh
```

The script auto-detects installed AI tools (Claude Code, Cursor, Aider, Continue) and lets you choose which to install to. Just follow the prompts.

Common commands:

```bash
./install.sh --all                 # Install to all detected tools
./install.sh claude-code           # Install only to Claude Code
./install.sh claude-code cursor    # Install to specific tools
./install.sh --list                # Show detection status
./install.sh --uninstall           # Remove from all tools
./install.sh --help                # Full help
```

Install paths:

- **Claude Code**: `~/.claude/skills/macos-to-linux-compat/SKILL.md`
- **Cursor**: `./AGENTS.md` (or `./CLAUDE.md` if it already exists)
- **Aider**: `./CONVENTIONS.md`
- **Continue**: `~/.continue/config.json` (`customInstructions` merged via `jq`)

### Manual Install

If you prefer manual setup:

**Claude Code:**

```bash
mkdir -p ~/.claude/skills/macos-to-linux-compat
cp SKILL.md ~/.claude/skills/macos-to-linux-compat/SKILL.md
```

Claude Code auto-loads skills from `~/.claude/skills/`.

**Cursor / Aider / Continue / Other:**

Copy the content of `SKILL.md` into your project's:

- `AGENTS.md`, **or**
- `CLAUDE.md`, **or**
- System prompt configuration

## Quick Start

Just work as usual — when AI detects macOS environment and you trigger any cross-platform scenario (tar, Dockerfile, CI config), it will apply the rules automatically.

### Manual verification

```bash
# Verify a tar archive is free of macOS extended attributes
./scripts/verify-archive.sh your-archive.tar.gz

# Verify a config file has all sources replaced
./scripts/verify-sources.sh your-Dockerfile

# Check if you're currently on macOS
./scripts/detect-macos.sh
```

## Project Structure

```
.
├── SKILL.md                # Main rule document (AI reads this)
├── README.md               # English README
├── README.zh-CN.md         # Chinese README
├── install.sh              # One-click installer for AI tools
├── scripts/
│   ├── verify-archive.sh   # Verify tar archive cleanliness
│   ├── verify-sources.sh   # Verify source URLs replaced
│   └── detect-macos.sh     # Detect macOS environment
├── references/
│   ├── archive-cheatsheet.md   # tar/zip/rsync/scp reference
│   ├── sources-mirror.md       # China mirror map
│   └── ownership-handling.md   # Ownership strategy explained
└── examples/
    ├── dockerfile/         # Dockerfile examples
    ├── ci/                 # CI configuration examples
    └── commands/           # Cross-platform command examples
```

## Verification Scripts

| Script | Purpose |
|---|---|
| `scripts/verify-archive.sh` | Check tar archive for macOS extended attributes |
| `scripts/verify-sources.sh` | Check config files for unreplaced default sources |
| `scripts/detect-macos.sh` | Detect if running on macOS |

## Contributing

Issues and PRs welcome for:

- More Linux distribution mirrors
- More CI platforms
- More cross-platform commands (zip variants, git LFS, etc.)
- Bug reports on specific macOS / Linux combinations

## License

MIT — see [LICENSE](./LICENSE)