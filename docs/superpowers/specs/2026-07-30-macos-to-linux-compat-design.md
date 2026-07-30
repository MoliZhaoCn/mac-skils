# macos-to-linux-compat Skill 设计文档

**日期**：2026-07-30
**状态**：设计中，待用户审阅
**作者**：与用户协作完成

---

## 1. 概述

### 1.1 目的

在 MacOS 环境下使用 AI 工具（Claude Code / Cursor / Aider / Continue 等）时，自动应用跨平台兼容性规则，避免常见的 Mac → Linux 兼容性问题：

1. **tar 归档警告**：MacOS BSD tar 写入的 `LIBARCHIVE.xattr.com.apple.provenance` 等扩展属性在 Linux 上解压时报"未知扩展头"警告
2. **文件所有权混乱**：MacOS 用户的 uid（典型 501）被硬编码进 tar 包，Linux 上解压后文件"无主"或归属错乱
3. **Dockerfile / CI 拉源慢**：默认 Docker 镜像源和包管理器源在国外，国内构建动辄超时

### 1.2 范围

**包含**：
- tar / zip / rsync / scp 的 Mac → Linux 兼容写法
- Dockerfile / docker-compose / GitHub Actions / GitLab CI / Jenkinsfile 的源替换规则
- apt / yum / dnf / apk / pip / npm / go / cargo / composer 的国内源映射
- 独立的验证脚本

**不包含**（YAGNI）：
- 完整的 Docker 镜像构建工具
- GUI 工具
- 云平台特定镜像源（AWS China、Azure China 等）
- 除中英外的其他语言版本

---

## 2. 总体架构

### 2.1 Skill 形态

通用纯 Markdown 文档（`SKILL.md`），兼容任何能读取系统提示或自定义规则的 AI 工具。

### 2.2 加载方式

- **Claude Code**：放置在 `~/.claude/skills/macos-to-linux-compat/SKILL.md` 自动加载
- **Cursor / Aider / Continue**：将 `SKILL.md` 内容粘贴到项目的 `AGENTS.md` / `CLAUDE.md` 或系统提示中

### 2.3 触发逻辑

AI 检测到以下条件时自动应用本 skill：

| 条件 | 应用模块 |
|---|---|
| `uname` 输出包含 `Darwin`（MacOS） | 全部规则 |
| 执行或生成 `tar` / `zip` / `rsync` / `scp` 命令 | 归档与传输规则 |
| 创建/修改 `Dockerfile`、`*.dockerfile`、`docker-compose*.yml` | 国内源规则 |
| 创建/修改 `.github/workflows/*.yml`、`.gitlab-ci.yml`、`Jenkinsfile` | 国内源规则 |
| 用户提到"跨平台"、"Linux 服务器"、"国内源"、"换源" | 全部规则 |

**歧义澄清**：本 skill 假定当前运行平台是 MacOS（Darwin），目标平台是 Linux。如果用户在 Linux 上工作但要打包文件传输到 Mac，不在本 skill 范围内。

---

## 3. 文件结构

```
mac-skils/
├── SKILL.md                          # 主规则文档（AI 必须读取）
├── README.md                         # 英文 README（GitHub 默认）
├── README.zh-CN.md                   # 中文 README
├── docs/
│   └── superpowers/
│       └── specs/
│           └── 2026-07-30-macos-to-linux-compat-design.md
├── scripts/
│   ├── verify-archive.sh             # 验证 tar 包无 MacOS 扩展属性
│   ├── verify-sources.sh             # 验证配置文件源已替换
│   └── detect-macos.sh               # 检测当前是否在 MacOS 上
├── references/
│   ├── archive-cheatsheet.md         # tar/zip/rsync/scp 命令速查
│   ├── sources-mirror.md             # 国内源映射表
│   └── ownership-handling.md         # 所有权处理策略详解
└── examples/
    ├── dockerfile/
    │   ├── Dockerfile.apt            # Debian/Ubuntu 清华源示例
    │   ├── Dockerfile.yum            # CentOS/RHEL 阿里源示例
    │   └── Dockerfile.multi-stage    # 多阶段构建示例
    ├── ci/
    │   ├── github-actions.yml        # GitHub Actions 示例
    │   └── gitlab-ci.yml             # GitLab CI 示例
    └── commands/
        ├── tar-to-linux.sh           # 跨平台 tar 打包示例
        └── rsync-to-linux.sh         # rsync 传输示例
```

---

## 4. 模块 A：跨平台归档与传输规则

### 4.1 tar 打包（Mac → Linux）

**问题根因**：MacOS BSD tar 调用 `stat(2)` 获取文件元数据，将 `uid=501`、`gid=20`、`SCHILY.fflags`、`SCHILY.acl`、`LIBARCHIVE.xattr.com.apple.*` 等写入 pax header。Linux 上 GNU tar 默认尝试恢复这些元数据，导致解压警告或所有权错乱。

**推荐写法**：

```bash
tar --no-acls --no-xattrs --no-fflags --no-mac-metadata \
    -czf archive.tar.gz files/
```

**参数含义**：
- `--no-acls`：不写入 ACL
- `--no-xattrs`：不写入扩展属性
- `--no-fflags`：不写入文件标志
- `--no-mac-metadata`：不写入 MacOS 特有元数据（BSD tar 特有参数）

**可选加固**：

```bash
# 强制为 root uid (0)，避免被 root 解压时变成"无主"
tar --owner=0 --group=0 \
    --no-acls --no-xattrs --no-fflags --no-mac-metadata \
    -czf archive.tar.gz files/
```

### 4.2 tar 解压（Linux 上）

**推荐写法**：

```bash
tar -xzf archive.tar.gz --no-same-owner
```

`--no-same-owner` 让当前解压用户自然拥有所有文件，避免恢复 MacOS 写入的 uid (501)。

### 4.3 zip 压缩

```bash
zip -r archive.zip files/   # 默认就不存扩展名 fork，行为较干净
```

zip 在跨平台场景下问题较少，但仍建议使用 tar.gz。

### 4.4 rsync 跨平台传输

```bash
rsync -avz --no-perms --no-owner --no-group --no-xattrs \
    -e ssh ./local/ user@linux-host:/remote/
```

### 4.5 scp 传输

```bash
scp archive.tar.gz user@linux-host:/remote/   # 简单传输，scp 不携带元数据
```

---

## 5. 模块 B：所有权处理策略

### 5.1 设计原则

**不显式强定义目标用户的所有权**，因为目标 Linux 服务器的用户名未知。采取"打包清理 + 解压声明"的双阶段策略。

### 5.2 打包阶段（Mac 上）

- **必须**：剥离所有 MacOS 扩展属性（`--no-acls --no-xattrs --no-fflags --no-mac-metadata`）
- **可选**：强制 uid/gid 为 0（root），让 Linux 端 `chown` 更灵活
- **可选**：仅当用户明确知道目标 Linux 用户名时才用 `--owner=$USER --group=$USER`

### 5.3 解压阶段（Linux 上）

- **推荐**：使用 `--no-same-owner`，让当前解压用户自然拥有所有文件
- **替代**：解压后用 `sudo chown -R target_user:target_group .` 手动调整

### 5.4 AI 行为策略

AI 在生成跨平台 tar 命令时应该：
1. 默认采用"剥离 + 不强制 owner"写法（即第 4.1 节的推荐写法）
2. 如果用户明确提到"目标用户名"或"部署到 xxx 用户"，则加上 `--owner=$USER --group=$USER`
3. 给出简短说明：建议 Linux 端加 `--no-same-owner` 解压

---

## 6. 模块 C：国内源配置

### 6.1 源映射表

| 场景 | 默认源 | 国内源 |
|---|---|---|
| Debian/Ubuntu (apt) | deb.debian.org, archive.ubuntu.com | mirrors.tuna.tsinghua.edu.cn |
| RHEL/CentOS (yum/dnf) | mirrorlist.centos.org, dl.fedoraproject.org | mirrors.aliyun.com |
| Alpine (apk) | dl-cdn.alpinelinux.org | mirrors.aliyun.com |
| Python (pip) | pypi.org | pypi.tuna.tsinghua.edu.cn |
| Node (npm) | registry.npmjs.org | registry.npmmirror.com |
| Go (go mod) | proxy.golang.org | goproxy.cn |
| Rust (cargo) | crates.io | rsproxy.cn |
| PHP (composer) | packagist.org | mirrors.aliyun.com/composer |

### 6.2 Dockerfile 替换规则

**Debian/Ubuntu**（清华源）：
```dockerfile
RUN sed -i 's|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g; \
            s|security.debian.org|mirrors.tuna.tsinghua.edu.cn|g; \
            s|archive.ubuntu.com|mirrors.tuna.tsinghua.edu.cn|g; \
            s|security.ubuntu.com|mirrors.tuna.tsinghua.edu.cn|g' \
        /etc/apt/sources.list.d/*.list /etc/apt/sources.list 2>/dev/null || true \
    && apt-get update
```

**RHEL/CentOS**（阿里源）：
```dockerfile
RUN sed -i 's|mirrorlist.centos.org|mirrors.aliyun.com|g; \
            s|dl.fedoraproject.org|mirrors.aliyun.com|g; \
            s|^#baseurl=|baseurl=|g; s|^mirrorlist=|#mirrorlist=|g' \
        /etc/yum.repos.d/*.repo \
    && yum clean all && yum makecache
```

**Alpine**（阿里源）：
```dockerfile
RUN sed -i 's|dl-cdn.alpinelinux.org|mirrors.aliyun.com|g' /etc/apk/repositories
```

**pip**（清华源）：
```dockerfile
RUN pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
```

**npm**（淘宝源）：
```dockerfile
RUN npm config set registry https://registry.npmmirror.com
```

### 6.3 CI/CD 替换规则

**GitHub Actions**：
```yaml
- name: 配置 pip 国内源
  run: pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
```

AI 应在每个 CI 文件的 `setup-python` / `setup-node` / `setup-go` 等步骤之后自动追加源配置步骤。

### 6.4 触发条件

AI 在以下场景自动应用源替换：
- 创建或修改 `Dockerfile`、`*.dockerfile`、`docker-compose*.yml`
- 创建或修改 `.github/workflows/*.yml`、`.gitlab-ci.yml`、`.circleci/config.yml`、`Jenkinsfile`
- 创建或修改 `Vagrantfile`、Packer 模板
- 用户明确提到"配置国内源"、"换源"、"加速"

---

## 7. 模块 D：验证脚本

### 7.1 verify-archive.sh

检查 tar 包是否包含 MacOS 扩展属性。

```bash
#!/usr/bin/env bash
# 用法：./verify-archive.sh <archive.tar.gz>
set -e
ARCHIVE="${1:?用法: $0 <archive.tar.gz>}"

MAC_PATTERNS=(
    "com.apple.provenance"
    "com.apple.quarantine"
    "com.apple.metadata"
    "LIBARCHIVE.xattr"
    "SCHILY.fflags"
    "SCHILY.acl"
)

FOUND=0
for p in "${MAC_PATTERNS[@]}"; do
    if tar -tvf "$ARCHIVE" 2>/dev/null | grep -F "$p" >/dev/null; then
        echo "❌ 归档包含 MacOS 扩展属性: $p"
        FOUND=1
    fi
done

echo ""
echo "📋 归档内 uid/gid 统计："
tar -tvf "$ARCHIVE" 2>/dev/null | awk '{print $2}' | sort -u | head -20

if [ $FOUND -eq 0 ]; then
    echo ""
    echo "✅ 未发现 MacOS 扩展属性"
fi
exit $FOUND
```

### 7.2 verify-sources.sh

检查配置文件是否还有未替换的默认源。

```bash
#!/usr/bin/env bash
# 用法：./verify-sources.sh <Dockerfile 或 CI 配置文件>
set -e
FILE="${1:?用法: $0 <config-file>}"
PATTERNS=(
    "deb.debian.org"
    "archive.ubuntu.com"
    "mirrorlist.centos.org"
    "dl.fedoraproject.org"
    "pypi.org/simple"
    "registry.npmjs.org"
)

FOUND=0
for p in "${PATTERNS[@]}"; do
    if grep -F "$p" "$FILE" >/dev/null 2>&1; then
        echo "❌ 发现未替换的源: $p （在 $FILE 中）"
        FOUND=1
    fi
done

if [ $FOUND -eq 0 ]; then
    echo "✅ $FILE 未发现默认源 URL"
fi
exit $FOUND
```

### 7.3 detect-macos.sh

```bash
#!/usr/bin/env bash
if [ "$(uname)" = "Darwin" ]; then
    echo "🍎 当前在 MacOS 上，应应用 macos-to-linux-compat skill"
    exit 0
else
    echo "ℹ️  当前不在 MacOS ($(uname))"
    exit 1
fi
```

---

## 8. README.md 设计

### 8.1 双文件方案

- `README.md`：英文版本，GitHub 默认显示，顶部链接中文版本
- `README.zh-CN.md`：中文版本

### 8.2 章节大纲

1. 项目标题 + 一句话描述
2. 解决什么问题（3 个核心痛点）
3. 功能特性清单
4. 如何使用（不同 AI 工具的加载方式）
5. 手动使用验证脚本
6. 目录结构
7. 验证脚本说明
8. 贡献指南
9. License（MIT）

---

## 9. SKILL.md 核心内容大纲

```markdown
---
name: macos-to-linux-compat
description: 在 MacOS 上工作时自动应用跨平台归档/传输与国内源配置规则。覆盖 tar/zip/rsync/scp 的 Mac→Linux 兼容写法，Dockerfile 与 CI/CD 的国内源替换。
---

# MacOS → Linux 兼容性助手

## 何时应用

检测到以下任一条件时应用：
- uname 输出包含 Darwin
- 涉及 tar/zip/rsync/scp 命令
- 涉及 Dockerfile / CI 配置文件
- 用户明确提到跨平台、国内源

## 归档与传输规则

### tar 打包
（粘贴 4.1 内容）

### tar 解压
（粘贴 4.2 内容）

### zip / rsync / scp
（粘贴 4.3 - 4.5 内容）

## 所有权处理

（粘贴第 5 章内容）

## 国内源配置

### 源映射表
（粘贴 6.1）

### Dockerfile 替换
（粘贴 6.2）

### CI/CD 替换
（粘贴 6.3）

## 验证清单

执行下列命令验证：
\`\`\`bash
./scripts/verify-archive.sh archive.tar.gz
./scripts/verify-sources.sh Dockerfile
\`\`\`
```

---

## 10. 测试策略

### 10.1 脚本可执行性测试

```bash
bash -n scripts/verify-archive.sh
bash -n scripts/verify-sources.sh
bash -n scripts/detect-macos.sh
```

### 10.2 示例内容测试

```bash
grep -F "mirrors.tuna.tsinghua.edu.cn" examples/dockerfile/Dockerfile.apt
grep -F "--no-mac-metadata" examples/commands/tar-to-linux.sh
grep -F "registry.npmmirror.com" examples/dockerfile/Dockerfile.multi-stage
```

### 10.3 端到端测试

```bash
cd examples/commands
./tar-to-linux.sh                    # 生成测试 tar 包
../../scripts/verify-archive.sh archive.tar.gz   # 必须返回 0
```

### 10.4 AI 应用测试（手动）

在 Claude Code 中加载 SKILL.md 后，验证 AI 行为：
- 自动在 Dockerfile 中加 sed 替换源
- 自动在 tar 命令中加 `--no-mac-metadata`
- 自动在 GitHub Actions 配置中加 pip 国内源

---

## 11. 范围确认（YAGNI 检查）

明确不在本次实现中包含：

- ❌ 完整的 Docker 镜像构建工具
- ❌ 多语言版本（除中英外）
- ❌ GUI 工具
- ❌ 云平台特定的镜像源（AWS China、Azure China 等）
- ❌ 其他跨平台场景（PowerShell on macOS、WSL 等）

---

## 12. 后续可扩展点

明确不在本次实现中，但留作未来扩展：

- 加入 Vagrant / Packer 模板的源替换规则
- 加入 Helm chart 的镜像源替换规则
- 加入 K8s deployment 的 image 替换规则
- 加入 ssh config 的 known_hosts 自动化管理
- 加入 git config 的换行符自动转换（autocrlf）

---

**确认事项清单**：

- [ ] 用户已确认总体架构
- [ ] 用户已确认归档规则
- [ ] 用户已确认所有权处理策略
- [ ] 用户已确认国内源配置（清华 / 阿里分配）
- [ ] 用户已确认 CI/CD 覆盖范围
- [ ] 用户已确认验证脚本设计
- [ ] 用户已确认 README 双语方案
- [ ] 用户已确认测试策略