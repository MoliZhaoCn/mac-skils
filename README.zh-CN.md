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

## 功能特性

- ✅ `tar` 打包：自动加 `--no-acls --no-xattrs --no-fflags --no-mac-metadata`
- ✅ `tar` 解压：自动建议加 `--no-same-owner`
- ✅ `apt` / `yum` / `dnf` / `apk` 国内源：清华源 / 阿里源
- ✅ `pip` / `npm` / `go` / `cargo` / `composer` 国内源
- ✅ Docker / CI / CD 配置感知
- ✅ 附带独立的验证脚本

## 安装

### 一键安装（推荐）

克隆仓库后，执行：

```bash
./install.sh
```

脚本会自动检测已安装的 AI 工具（Claude Code、Cursor、Aider、Continue），让你选择要安装到哪些工具，按提示操作即可。

常用命令：

```bash
./install.sh --all                 # 安装到所有检测到的工具
./install.sh claude-code           # 仅安装到 Claude Code
./install.sh claude-code cursor    # 安装到指定工具
./install.sh --list                # 查看检测状态
./install.sh --uninstall           # 从所有工具卸载
./install.sh --help                # 查看完整帮助
```

安装路径：

- **Claude Code**：`~/.claude/skills/macos-to-linux-compat/SKILL.md`
- **Cursor**：`./AGENTS.md`（如已存在则用 `./CLAUDE.md`）
- **Aider**：`./CONVENTIONS.md`
- **Continue**：`~/.continue/config.json`（合并到 `customInstructions`，需 `jq`）

### 手动安装

如果想手动设置：

**Claude Code：**

```bash
mkdir -p ~/.claude/skills/macos-to-linux-compat
cp SKILL.md ~/.claude/skills/macos-to-linux-compat/SKILL.md
```

Claude Code 会自动加载 `~/.claude/skills/` 下的 skill。

**Cursor / Aider / Continue / 其他：**

将 `SKILL.md` 的内容复制到项目的以下任意文件：

- `AGENTS.md`，**或**
- `CLAUDE.md`，**或**
- 工具的系统提示配置

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
├── install.sh              # 一键安装脚本
├── scripts/
│   ├── verify-archive.sh   # 验证归档干净
│   ├── verify-sources.sh   # 验证源已替换
│   └── detect-macos.sh     # 检测 macOS 环境
├── references/
│   ├── archive-cheatsheet.md   # tar/zip/rsync/scp 速查
│   ├── sources-mirror.md       # 国内源映射表
│   └── ownership-handling.md   # 所有权策略详解
└── examples/
    ├── dockerfile/         # Dockerfile 示例
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
