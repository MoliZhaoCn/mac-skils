# macos-to-linux-compat

> 面向 AI 编码助手的 MacOS → Linux 兼容性助手。

[English](./README.md)

## 解决什么问题

在 MacOS 上使用 AI 编码工具（Claude Code、Cursor、Aider、Continue 等）时，常遇到三个跨平台问题：

1. **Linux 解压 tar 报错** — `tar: 忽略未知的扩展头关键字 'LIBARCHIVE.xattr.com.apple.provenance'`
2. **文件所有权错乱** — MacOS 用户 uid (501) 被硬编码进归档，Linux 解压后文件"无主"
3. **构建慢如蜗牛** — 默认 Docker / apt / yum / pip / npm 源在国外，国内构建动辄超时

本 skill 让 AI 助手在 MacOS 上工作时自动应用跨平台安全的规则：

- `tar` / `zip` / `rsync` / `scp` 使用剥离 macOS 元数据的参数
- Linux 解压时建议加 `--no-same-owner`
- `apt` / `yum` / `dnf` / `apk` / `pip` / `npm` / `go` / `cargo` / `composer` 配置国内源
- 覆盖 `Dockerfile`、`docker-compose`、GitHub Actions、GitLab CI、Jenkinsfile
- Docker Compose：生成时 AI 会先询问持久化方式（bind mount / 命名 volume / 临时卷）和端口暴露方式（127.0.0.1 / 0.0.0.0 / 反向代理），推荐方案作默认

## 功能特性

- ✅ `tar` 打包：自动加 `--no-acls --no-xattrs --no-fflags --no-mac-metadata`
- ✅ `tar` 解压：自动建议加 `--no-same-owner`
- ✅ `apt` / `yum` / `dnf` / `apk` 国内源：清华源 / 阿里源
- ✅ `pip` / `npm` / `go` / `cargo` / `composer` 国内源
- ✅ Docker / CI / CD 配置感知
- ✅ **Docker Compose**：生成前询问持久化和端口方案（提供推荐项作为默认）
- ✅ 附带独立的验证脚本

## 安装

根据你使用的 AI 工具，把 `SKILL.md` 复制到对应位置。

### Claude Code

```bash
mkdir -p ~/.claude/skills/macos-to-linux-compat
cp SKILL.md ~/.claude/skills/macos-to-linux-compat/SKILL.md
```

Claude Code 会自动加载 `~/.claude/skills/` 下的 skill。

### Cursor

把 `SKILL.md` 内容复制到项目的 `AGENTS.md`（或 `CLAUDE.md`）。

### Aider

把 `SKILL.md` 内容复制到项目的 `CONVENTIONS.md`。

### Continue (VS Code)

把 `SKILL.md` 内容（去掉 YAML frontmatter）合并到 `~/.continue/config.json` 的 `customInstructions` 字段：

```bash
# 需要 jq
jq --arg ci "$(awk 'BEGIN{c=0}/^---$/{c++;next}c>=2{print}' SKILL.md)" \
   '.customInstructions = $ci' ~/.continue/config.json > /tmp/config.json \
&& mv /tmp/config.json ~/.continue/config.json
```

## 快速开始

正常使用即可 —— 当 AI 检测到 MacOS 环境且触发跨平台场景（tar、Dockerfile、CI 配置）时，会自动应用规则。

### 手动验证

```bash
# 验证 tar 包不含 macOS 扩展属性
./scripts/verify-archive.sh your-archive.tar.gz

# 验证配置文件的源已替换
./scripts/verify-sources.sh your-Dockerfile

# 检测当前是否在 MacOS
./scripts/detect-macos.sh
```

## 项目结构

```
.
├── SKILL.md                # 主规则文档（AI 读取）
├── README.md               # 英文 README
├── README.zh-CN.md         # 中文 README
├── scripts/
│   ├── verify-archive.sh   # 验证归档干净
│   ├── verify-sources.sh   # 验证源已替换
│   └── detect-macos.sh     # 检测 macOS 环境
├── references/
│   ├── archive-cheatsheet.md   # tar/zip/rsync/scp 速查
│   ├── sources-mirror.md       # 国内源映射表
│   ├── ownership-handling.md   # 所有权策略详解
│   └── docker-compose-cheatsheet.md  # Docker Compose 安全规则速查
└── examples/
    ├── dockerfile/         # Dockerfile 示例
    ├── docker-compose/     # Docker Compose 示例
    ├── ci/                 # CI 配置示例
    └── commands/           # 跨平台命令示例
```

## 验证脚本

| 脚本 | 用途 |
|---|---|
| `scripts/verify-archive.sh` | 检查 tar 包是否含 macOS 扩展属性 |
| `scripts/verify-sources.sh` | 检查配置文件是否有未替换的默认源 |
| `scripts/detect-macos.sh` | 检测当前是否在 macOS |

## 贡献

欢迎提交 Issue 和 PR 补充：

- 更多 Linux 发行版的国内源
- 更多 CI 平台
- 更多跨平台命令（zip 变体、git LFS 等）
- 特定 macOS / Linux 组合的 bug 报告

## 许可证

MIT —— 见 [LICENSE](./LICENSE)
