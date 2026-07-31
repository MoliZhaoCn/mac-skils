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
- Docker Compose: AI prompts before choosing persistence (bind mount / named volume / ephemeral) and port binding (127.0.0.1 / 0.0.0.0 / reverse proxy)

## Features

- ✅ `tar` packing: `--no-acls --no-xattrs --no-fflags --no-mac-metadata`
- ✅ `tar` extraction: `--no-same-owner`
- ✅ `apt` / `yum` / `dnf` / `apk` mirrors: Tsinghua / Aliyun
- ✅ `pip` / `npm` / `go` / `cargo` / `composer` mirrors
- ✅ Docker / CI / CD configuration aware
- ✅ **Docker Compose**: prompts before choosing persistence and port binding (with recommended defaults)
- ✅ Standalone verification scripts

## Installation

Pick the AI tool you use and copy `SKILL.md` to the right place.

### Claude Code

```bash
mkdir -p ~/.claude/skills/macos-to-linux-compat
cp SKILL.md ~/.claude/skills/macos-to-linux-compat/SKILL.md
```

Claude Code auto-loads skills from `~/.claude/skills/`.

### Cursor

Copy `SKILL.md` content into your project's `AGENTS.md` (or `CLAUDE.md`).

### Aider

Copy `SKILL.md` content into your project's `CONVENTIONS.md`.

### Continue (VS Code)

Merge `SKILL.md` content (excluding the YAML frontmatter) into your `~/.continue/config.json` as the `customInstructions` field:

```bash
# Requires jq
jq --arg ci "$(awk 'BEGIN{c=0}/^---$/{c++;next}c>=2{print}' SKILL.md)" \
   '.customInstructions = $ci' ~/.continue/config.json > /tmp/config.json \
&& mv /tmp/config.json ~/.continue/config.json
```

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
├── scripts/
│   ├── verify-archive.sh   # Verify tar archive cleanliness
│   ├── verify-sources.sh   # Verify source URLs replaced
│   └── detect-macos.sh     # Detect macOS environment
├── references/
│   ├── archive-cheatsheet.md   # tar/zip/rsync/scp reference
│   ├── sources-mirror.md       # China mirror map
│   ├── ownership-handling.md   # Ownership strategy explained
│   └── docker-compose-cheatsheet.md  # Docker Compose security rules
└── examples/
    ├── dockerfile/         # Dockerfile examples
    ├── docker-compose/     # Docker Compose examples
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