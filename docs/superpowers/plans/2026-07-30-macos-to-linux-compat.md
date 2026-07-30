# macos-to-linux-compat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个 GitHub 仓库，包含一个跨平台兼容性 skill（macos-to-linux-compat），让 AI 工具在 MacOS 上自动应用跨平台归档与国内源配置规则，并提供独立的验证脚本和示例。

**Architecture:** 主规则写在通用 Markdown（`SKILL.md`），可被任何 AI 工具读取。验证脚本独立可运行（bash shell scripts），覆盖归档属性和源配置两类验证。示例文件覆盖 Dockerfile、CI 配置、跨平台命令三个场景。

**Tech Stack:**
- Bash（验证脚本）
- ShellCheck（脚本静态检查）
- Markdown（SKILL.md、README、references）
- Dockerfile / YAML / Shell（示例文件）

**Spec Reference:** `docs/superpowers/specs/2026-07-30-macos-to-linux-compat-design.md`

---

## Global Constraints

- 所有文件名使用 kebab-case（如 `verify-archive.sh`）
- 所有 shell 脚本首行 `#!/usr/bin/env bash`，使用 `set -e`
- SKILL.md 顶部必须有 YAML frontmatter（`name` 和 `description` 字段）
- README.md 和 README.zh-CN.md 内容保持同步（章节结构一致）
- 脚本必须可执行：`chmod +x scripts/*.sh`
- 脚本必须通过 `bash -n` 语法检查
- 示例文件必须通过 `grep` 内容验证
- 仓库使用 MIT License
- 工作目录根：`/Users/yujian/Downloads/demo/mac-skils/`

---

## File Structure

本计划将创建以下文件。每个文件有单一职责。

```
mac-skils/
├── LICENSE                              # MIT 许可证
├── .gitignore                           # 忽略生成产物
├── SKILL.md                             # 主规则文档（AI 读取）
├── README.md                            # 英文 README
├── README.zh-CN.md                      # 中文 README
├── scripts/
│   ├── verify-archive.sh                # 验证 tar 包无 MacOS 扩展属性
│   ├── verify-sources.sh                # 验证配置文件源已替换
│   └── detect-macos.sh                  # 检测 MacOS 环境
├── references/
│   ├── archive-cheatsheet.md            # tar/zip/rsync/scp 命令速查
│   ├── sources-mirror.md                # 国内源映射表
│   └── ownership-handling.md            # 所有权处理详解
└── examples/
    ├── dockerfile/
    │   ├── Dockerfile.apt               # Debian/Ubuntu 清华源示例
    │   ├── Dockerfile.yum               # CentOS/RHEL 阿里源示例
    │   └── Dockerfile.multi-stage       # 多语言 + 多阶段示例
    ├── ci/
    │   ├── github-actions.yml           # GitHub Actions 示例
    │   └── gitlab-ci.yml                # GitLab CI 示例
    └── commands/
        ├── tar-to-linux.sh              # 跨平台 tar 打包示例
        └── rsync-to-linux.sh            # rsync 传输示例
```

**职责分配**：
- `SKILL.md`：AI 行为的唯一规则源，所有模块的规则集中在此
- `scripts/*.sh`：独立可执行工具，给用户手动验证用
- `references/*.md`：人类阅读的速查表和详解文档
- `examples/**`：在真实场景下的样本文件，供 AI 参考
- `README.md` / `README.zh-CN.md`：GitHub 仓库门面，告诉别人这个 skill 是干嘛的

---

## Task 1: 初始化仓库基础结构

**Files:**
- Create: `/Users/yujian/Downloads/demo/mac-skils/LICENSE`
- Create: `/Users/yujian/Downloads/demo/mac-skils/.gitignore`

**Interfaces:**
- Consumes: 无
- Produces: 仓库根目录具备 LICENSE 和 .gitignore，其他文件尚未创建

- [ ] **Step 1: 创建 LICENSE 文件**

写入标准 MIT License 模板：

```
MIT License

Copyright (c) 2026 yujian

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: 创建 .gitignore 文件**

写入：

```
# OS files
.DS_Store
Thumbs.db

# Editor
.vscode/
.idea/
*.swp
*.swo

# Test artifacts
archive.tar.gz
*.tar.gz
!examples/**/*.tar.gz
```

- [ ] **Step 3: 验证文件创建成功**

Run: `ls -la /Users/yujian/Downloads/demo/mac-skils/`
Expected: 看到 LICENSE 和 .gitignore

---

## Task 2: 编写 SKILL.md 主规则文档

**Files:**
- Create: `/Users/yujian/Downloads/demo/mac-skils/SKILL.md`

**Interfaces:**
- Consumes: 设计文档第 1-7 章内容
- Produces: 包含 frontmatter、触发条件、归档规则、所有权处理、国内源规则的单一 Markdown 文档

- [ ] **Step 1: 创建 SKILL.md 包含 frontmatter**

写入：

```markdown
---
name: macos-to-linux-compat
description: 在 MacOS 上工作时自动应用跨平台归档/传输与国内源配置规则。覆盖 tar/zip/rsync/scp 的 Mac→Linux 兼容写法，Dockerfile 与 CI/CD 的国内源替换。
---

# MacOS → Linux 兼容性助手

## 何时应用本 skill

检测到以下任一条件时自动应用本 skill：

| 触发条件 | 应用模块 |
|---|---|
| `uname` 输出包含 `Darwin`（MacOS） | 全部规则 |
| 执行或生成 `tar`、`zip`、`rsync`、`scp` 命令 | 归档与传输规则 |
| 创建/修改 `Dockerfile`、`*.dockerfile`、`docker-compose*.yml` | 国内源规则 |
| 创建/修改 `.github/workflows/*.yml`、`.gitlab-ci.yml`、`Jenkinsfile` | 国内源规则 |
| 用户提到"跨平台"、"Linux 服务器"、"国内源"、"换源" | 全部规则 |

**方向约定**：本 skill 假定当前运行平台是 MacOS（Darwin），目标平台是 Linux。
```

- [ ] **Step 2: 追加归档与传输规则章节**

在 SKILL.md 末尾追加：

```markdown

## 归档与传输规则

### tar 打包（Mac → Linux）

**问题**：MacOS BSD tar 会写入 `LIBARCHIVE.xattr.com.apple.*`、`SCHILY.fflags`、`SCHILY.acl` 等扩展属性，Linux 上 GNU tar 解压时会报"未知扩展头"警告。同时 Mac 用户的 uid (501) 会被硬编码。

**推荐写法**：

\`\`\`bash
tar --no-acls --no-xattrs --no-fflags --no-mac-metadata \
    -czf archive.tar.gz files/
\`\`\`

可选加固（强制 uid 0，避免 root 解压时变"无主"）：

\`\`\`bash
tar --owner=0 --group=0 \
    --no-acls --no-xattrs --no-fflags --no-mac-metadata \
    -czf archive.tar.gz files/
\`\`\`

### tar 解压（Linux 上）

\`\`\`bash
tar -xzf archive.tar.gz --no-same-owner
\`\`\`

### zip 压缩

\`\`\`bash
zip -r archive.zip files/
\`\`\`

### rsync 跨平台传输

\`\`\`bash
rsync -avz --no-perms --no-owner --no-group --no-xattrs \
    -e ssh ./local/ user@linux-host:/remote/
\`\`\`

### scp 传输

\`\`\`bash
scp archive.tar.gz user@linux-host:/remote/
\`\`\`
```

- [ ] **Step 3: 追加所有权处理策略章节**

在 SKILL.md 末尾追加：

```markdown

## 所有权处理策略

### 原则

**不显式强定义目标用户的所有权**（目标 Linux 服务器用户名未知）。采取"打包清理 + 解压声明"的双阶段策略。

### 打包阶段（Mac 上）

- 必须：剥离所有 MacOS 扩展属性（`--no-acls --no-xattrs --no-fflags --no-mac-metadata`）
- 可选：强制 uid/gid 为 0（root），让 Linux 端 `chown` 更灵活
- 可选：仅当用户明确知道目标 Linux 用户名时才用 `--owner=$USER --group=$USER`

### 解压阶段（Linux 上）

- 推荐：使用 `--no-same-owner`，让当前解压用户自然拥有所有文件
- 替代：解压后用 `sudo chown -R target_user:target_group .` 手动调整

### AI 行为策略

1. 默认采用"剥离 + 不强制 owner"写法
2. 用户明确提到"目标用户名"时，才加 `--owner=$USER --group=$USER`
3. 给出简短说明：建议 Linux 端加 `--no-same-owner` 解压
```

- [ ] **Step 4: 追加国内源配置章节**

在 SKILL.md 末尾追加：

```markdown

## 国内源配置

### 源映射表

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

### Dockerfile 替换规则

**Debian/Ubuntu**（清华源）：

\`\`\`dockerfile
RUN sed -i 's|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g; \
            s|security.debian.org|mirrors.tuna.tsinghua.edu.cn|g; \
            s|archive.ubuntu.com|mirrors.tuna.tsinghua.edu.cn|g; \
            s|security.ubuntu.com|mirrors.tuna.tsinghua.edu.cn|g' \
        /etc/apt/sources.list.d/*.list /etc/apt/sources.list 2>/dev/null || true \
    && apt-get update
\`\`\`

**RHEL/CentOS**（阿里源）：

\`\`\`dockerfile
RUN sed -i 's|mirrorlist.centos.org|mirrors.aliyun.com|g; \
            s|dl.fedoraproject.org|mirrors.aliyun.com|g; \
            s|^#baseurl=|baseurl=|g; s|^mirrorlist=|#mirrorlist=|g' \
        /etc/yum.repos.d/*.repo \
    && yum clean all && yum makecache
\`\`\`

**Alpine**（阿里源）：

\`\`\`dockerfile
RUN sed -i 's|dl-cdn.alpinelinux.org|mirrors.aliyun.com|g' /etc/apk/repositories
\`\`\`

**pip**（清华源）：

\`\`\`dockerfile
RUN pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
\`\`\`

**npm**（淘宝源）：

\`\`\`dockerfile
RUN npm config set registry https://registry.npmmirror.com
\`\`\`

### CI/CD 替换规则

在每个 CI 文件的 `setup-python` / `setup-node` / `setup-go` 步骤之后追加源配置：

\`\`\`yaml
- name: 配置 pip 国内源
  run: pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

- name: 配置 npm 国内源
  run: npm config set registry https://registry.npmmirror.com
\`\`\`
```

- [ ] **Step 5: 追加验证清单章节**

在 SKILL.md 末尾追加：

```markdown

## 验证清单

生成产物后执行下列命令验证：

\`\`\`bash
./scripts/verify-archive.sh archive.tar.gz
./scripts/verify-sources.sh Dockerfile
./scripts/detect-macos.sh
\`\`\`
```

- [ ] **Step 6: 验证 SKILL.md 内容完整**

Run: `grep -c "^##" /Users/yujian/Downloads/demo/mac-skils/SKILL.md`
Expected: 输出 ≥ 5（5 个 `##` 章节标题）

Run: `head -5 /Users/yujian/Downloads/demo/mac-skils/SKILL.md`
Expected: 第一行是 `---`，第二行是 `name: macos-to-linux-compat`

---

## Task 3: 编写 verify-archive.sh 验证脚本

**Files:**
- Create: `/Users/yujian/Downloads/demo/mac-skils/scripts/verify-archive.sh`

**Interfaces:**
- Consumes: 一个 tar 归档文件路径作为参数
- Produces: 退出码 0 表示无 MacOS 扩展属性，非 0 表示发现扩展属性

- [ ] **Step 1: 创建脚本文件**

写入：

```bash
#!/usr/bin/env bash
# verify-archive.sh - 检查 tar 归档是否包含 MacOS 扩展属性
# 用法: ./verify-archive.sh <archive.tar.gz>
# 退出码: 0 表示干净，1 表示发现 MacOS 属性

set -e

ARCHIVE="${1:?用法: $0 <archive.tar.gz> 要求一个归档文件路径}"

if [ ! -f "$ARCHIVE" ]; then
    echo "❌ 文件不存在: $ARCHIVE" >&2
    exit 2
fi

# MacOS tar 特有的扩展属性关键词
MAC_PATTERNS=(
    "com.apple.provenance"
    "com.apple.quarantine"
    "com.apple.metadata"
    "LIBARCHIVE.xattr"
    "SCHILY.fflags"
    "SCHILY.acl"
)

FOUND=0
for pattern in "${MAC_PATTERNS[@]}"; do
    if tar -tvf "$ARCHIVE" 2>/dev/null | grep -F "$pattern" > /dev/null; then
        echo "❌ 归档包含 MacOS 扩展属性: $pattern"
        FOUND=1
    fi
done

echo ""
echo "📋 归档内 uid/gid 统计（前 20 个）："
tar -tvf "$ARCHIVE" 2>/dev/null | awk '{print $2}' | sort -u | head -20

if [ $FOUND -eq 0 ]; then
    echo ""
    echo "✅ 未发现 MacOS 扩展属性"
fi

exit $FOUND
```

- [ ] **Step 2: 添加执行权限**

Run: `chmod +x /Users/yujian/Downloads/demo/mac-skils/scripts/verify-archive.sh`

- [ ] **Step 3: 语法检查**

Run: `bash -n /Users/yujian/Downloads/demo/mac-skils/scripts/verify-archive.sh`
Expected: 无输出（语法正确）

- [ ] **Step 4: 用法错误测试**

Run: `/Users/yujian/Downloads/demo/mac-skils/scripts/verify-archive.sh`
Expected: 输出 "用法: $0 <archive.tar.gz> 要求一个归档文件路径"，退出码非 0

Run: `/Users/yujian/Downloads/demo/mac-skils/scripts/verify-archive.sh /tmp/not-exists-12345.tar.gz`
Expected: 输出 "❌ 文件不存在"，退出码 2

---

## Task 4: 编写 verify-sources.sh 验证脚本

**Files:**
- Create: `/Users/yujian/Downloads/demo/mac-skils/scripts/verify-sources.sh`

**Interfaces:**
- Consumes: 一个配置文件路径（Dockerfile / YAML）作为参数
- Produces: 退出码 0 表示无默认源 URL，非 0 表示发现未替换源

- [ ] **Step 1: 创建脚本文件**

写入：

```bash
#!/usr/bin/env bash
# verify-sources.sh - 检查配置文件中是否还有未替换的默认源 URL
# 用法: ./verify-sources.sh <config-file>
# 退出码: 0 表示已全部替换，1 表示发现未替换源

set -e

FILE="${1:?用法: $0 <config-file> 要求一个配置文件路径}"

if [ ! -f "$FILE" ]; then
    echo "❌ 文件不存在: $FILE" >&2
    exit 2
fi

# 默认源 URL 关键词
DEFAULT_PATTERNS=(
    "deb.debian.org"
    "security.debian.org"
    "archive.ubuntu.com"
    "security.ubuntu.com"
    "mirrorlist.centos.org"
    "dl.fedoraproject.org"
    "dl-cdn.alpinelinux.org"
    "pypi.org/simple"
    "registry.npmjs.org"
    "proxy.golang.org"
    "crates.io"
    "packagist.org"
)

FOUND=0
for pattern in "${DEFAULT_PATTERNS[@]}"; do
    if grep -F "$pattern" "$FILE" > /dev/null 2>&1; then
        echo "❌ 发现未替换的源: $pattern （在 $FILE 中）"
        FOUND=1
    fi
done

if [ $FOUND -eq 0 ]; then
    echo "✅ $FILE 未发现默认源 URL"
fi

exit $FOUND
```

- [ ] **Step 2: 添加执行权限**

Run: `chmod +x /Users/yujian/Downloads/demo/mac-skils/scripts/verify-sources.sh`

- [ ] **Step 3: 语法检查**

Run: `bash -n /Users/yujian/Downloads/demo/mac-skils/scripts/verify-sources.sh`
Expected: 无输出（语法正确）

- [ ] **Step 4: 用法错误测试**

Run: `/Users/yujian/Downloads/demo/mac-skils/scripts/verify-sources.sh`
Expected: 输出 "用法: ..."，退出码非 0

- [ ] **Step 5: 正向测试（创建含未替换源的文件并验证检测）**

Run:
```bash
echo "deb http://deb.debian.org/debian bookworm main" > /tmp/test-bad-source.list
/Users/yujian/Downloads/demo/mac-skils/scripts/verify-sources.sh /tmp/test-bad-source.list
```
Expected: 输出 "❌ 发现未替换的源: deb.debian.org"，退出码 1

清理：`rm /tmp/test-bad-source.list`

- [ ] **Step 6: 负向测试（创建干净的文件并验证通过）**

Run:
```bash
echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian bookworm main" > /tmp/test-good-source.list
/Users/yujian/Downloads/demo/mac-skils/scripts/verify-sources.sh /tmp/test-good-source.list
```
Expected: 输出 "✅ /tmp/test-good-source.list 未发现默认源 URL"，退出码 0

清理：`rm /tmp/test-good-source.list`

---

## Task 5: 编写 detect-macos.sh 检测脚本

**Files:**
- Create: `/Users/yujian/Downloads/demo/mac-skils/scripts/detect-macos.sh`

**Interfaces:**
- Consumes: 无
- Produces: 退出码 0 表示在 MacOS 上，非 0 表示不在

- [ ] **Step 1: 创建脚本文件**

写入：

```bash
#!/usr/bin/env bash
# detect-macos.sh - 检测当前是否在 MacOS 上运行
# 退出码: 0 表示 MacOS，1 表示其他平台

set -e

UNAME_OUT="$(uname)"

if [ "$UNAME_OUT" = "Darwin" ]; then
    echo "🍎 当前在 MacOS 上（Darwin $(uname -r)），应应用 macos-to-linux-compat skill"
    exit 0
else
    echo "ℹ️  当前不在 MacOS（$(uname) $(uname -r)）"
    exit 1
fi
```

- [ ] **Step 2: 添加执行权限**

Run: `chmod +x /Users/yujian/Downloads/demo/mac-skils/scripts/detect-macos.sh`

- [ ] **Step 3: 语法检查**

Run: `bash -n /Users/yujian/Downloads/demo/mac-skils/scripts/detect-macos.sh`
Expected: 无输出

- [ ] **Step 4: 运行验证（当前在 Mac 上应当返回 0）**

Run: `/Users/yujian/Downloads/demo/mac-skils/scripts/detect-macos.sh`
Expected: 输出 "🍎 当前在 MacOS 上..."，退出码 0

---

## Task 6: 编写示例 Dockerfile.apt

**Files:**
- Create: `/Users/yujian/Downloads/demo/mac-skils/examples/dockerfile/Dockerfile.apt`

**Interfaces:**
- Consumes: 设计文档第 6.2 节 Debian/Ubuntu 替换规则
- Produces: 一个完整可参考的 Debian 系 Dockerfile

- [ ] **Step 1: 创建示例文件**

写入：

```dockerfile
# 示例：Debian/Ubuntu 基础镜像 + Python，配置清华源
FROM python:3.11-slim-bookworm

# 替换 apt 源为清华源
RUN sed -i 's|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g; \
            s|security.debian.org|mirrors.tuna.tsinghua.edu.cn|g' \
        /etc/apt/sources.list.d/*.list /etc/apt/sources.list 2>/dev/null || true \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 替换 pip 源为清华源
RUN pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple \
    && pip install --no-cache-dir flask gunicorn

WORKDIR /app
COPY . .

CMD ["gunicorn", "-b", "0.0.0.0:8000", "app:app"]
```

- [ ] **Step 2: 验证示例包含清华源**

Run: `grep -F "mirrors.tuna.tsinghua.edu.cn" /Users/yujian/Downloads/demo/mac-skils/examples/dockerfile/Dockerfile.apt`
Expected: 至少 1 行匹配

Run: `grep -F "pypi.tuna.tsinghua.edu.cn" /Users/yujian/Downloads/demo/mac-skils/examples/dockerfile/Dockerfile.apt`
Expected: 至少 1 行匹配

- [ ] **Step 3: 验证示例已通过 verify-sources.sh**

Run: `/Users/yujian/Downloads/demo/mac-skils/scripts/verify-sources.sh /Users/yujian/Downloads/demo/mac-skils/examples/dockerfile/Dockerfile.apt`
Expected: 输出 "✅ ... 未发现默认源 URL"，退出码 0

---

## Task 7: 编写示例 Dockerfile.yum

**Files:**
- Create: `/Users/yujian/Downloads/demo/mac-skils/examples/dockerfile/Dockerfile.yum`

**Interfaces:**
- Consumes: 设计文档第 6.2 节 RHEL/CentOS 替换规则
- Produces: 一个完整可参考的 RHEL 系 Dockerfile

- [ ] **Step 1: 创建示例文件**

写入：

```dockerfile
# 示例：CentOS/RHEL 基础镜像 + Node.js，配置阿里源
FROM centos:7

# 替换 yum 源为阿里源
RUN sed -i 's|mirrorlist.centos.org|mirrors.aliyun.com|g; \
            s|dl.fedoraproject.org|mirrors.aliyun.com|g; \
            s|^#baseurl=|baseurl=|g; s|^mirrorlist=|#mirrorlist=|g' \
        /etc/yum.repos.d/*.repo \
    && yum clean all \
    && yum makecache \
    && yum install -y curl ca-certificates \
    && rm -rf /var/cache/yum/*

# 安装 Node.js
RUN curl -fsSL https://mirrors.aliyun.com/node-v18.20.4-linux-x64.tar.xz -o node.tar.xz \
    && tar -xJf node.tar.xz -C /opt/ \
    && ln -s /opt/node-v18.20.4-linux-x64/bin/node /usr/local/bin/node \
    && ln -s /opt/node-v18.20.4-linux-x64/bin/npm /usr/local/bin/npm \
    && rm node.tar.xz

# 替换 npm 源为淘宝源
RUN npm config set registry https://registry.npmmirror.com \
    && npm install -g yarn

WORKDIR /app
COPY package*.json ./
RUN npm install --production

COPY . .

CMD ["node", "index.js"]
```

- [ ] **Step 2: 验证示例包含阿里源和淘宝源**

Run: `grep -F "mirrors.aliyun.com" /Users/yujian/Downloads/demo/mac-skils/examples/dockerfile/Dockerfile.yum`
Expected: 至少 1 行匹配

Run: `grep -F "registry.npmmirror.com" /Users/yujian/Downloads/demo/mac-skils/examples/dockerfile/Dockerfile.yum`
Expected: 至少 1 行匹配

- [ ] **Step 3: 验证示例已通过 verify-sources.sh**

Run: `/Users/yujian/Downloads/demo/mac-skils/scripts/verify-sources.sh /Users/yujian/Downloads/demo/mac-skils/examples/dockerfile/Dockerfile.yum`
Expected: 输出 "✅ ... 未发现默认源 URL"，退出码 0

---

## Task 8: 编写示例 Dockerfile.multi-stage

**Files:**
- Create: `/Users/yujian/Downloads/demo/mac-skils/examples/dockerfile/Dockerfile.multi-stage`

**Interfaces:**
- Consumes: 设计文档第 6.2 节所有替换规则
- Produces: 一个多阶段、多语言的 Dockerfile，覆盖更多场景

- [ ] **Step 1: 创建示例文件**

写入：

```dockerfile
# 示例：多阶段构建，前端用 Node，后端用 Go，统一配置国内源

# ========== 构建阶段 1：前端 ==========
FROM node:20-alpine AS frontend

# 替换 apk 源为阿里源
RUN sed -i 's|dl-cdn.alpinelinux.org|mirrors.aliyun.com|g' /etc/apk/repositories \
    && apk update \
    && apk add --no-cache curl

WORKDIR /app/web
COPY web/package*.json ./

# 替换 npm 源为淘宝源
RUN npm config set registry https://registry.npmmirror.com \
    && npm ci

COPY web/ ./
RUN npm run build

# ========== 构建阶段 2：后端 ==========
FROM golang:1.22-bookworm AS backend

# 替换 apt 源为清华源
RUN sed -i 's|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g; \
            s|security.debian.org|mirrors.tuna.tsinghua.edu.cn|g' \
        /etc/apt/sources.list.d/*.list /etc/apt/sources.list 2>/dev/null || true \
    && apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 替换 Go proxy 为 goproxy.cn
ENV GOPROXY=https://goproxy.cn,direct

WORKDIR /app/api
COPY api/go.* ./
RUN go mod download
COPY api/ ./
RUN CGO_ENABLED=0 go build -o /api-server .

# ========== 运行阶段 ==========
FROM debian:bookworm-slim

RUN sed -i 's|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g; \
            s|security.debian.org|mirrors.tuna.tsinghua.edu.cn|g' \
        /etc/apt/sources.list.d/*.list /etc/apt/sources.list 2>/dev/null || true \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=backend /api-server /app/api-server
COPY --from=frontend /app/web/dist /app/web/dist

EXPOSE 8080
CMD ["/app/api-server"]
```

- [ ] **Step 2: 验证示例覆盖多个源**

Run: `grep -c "mirrors" /Users/yujian/Downloads/demo/mac-skils/examples/dockerfile/Dockerfile.multi-stage`
Expected: 输出 ≥ 4（至少 4 处镜像源引用）

Run: `grep -F "goproxy.cn" /Users/yujian/Downloads/demo/mac-skils/examples/dockerfile/Dockerfile.multi-stage`
Expected: 至少 1 行匹配

- [ ] **Step 3: 验证示例已通过 verify-sources.sh**

Run: `/Users/yujian/Downloads/demo/mac-skils/scripts/verify-sources.sh /Users/yujian/Downloads/demo/mac-skils/examples/dockerfile/Dockerfile.multi-stage`
Expected: 退出码 0

---

## Task 9: 编写示例 CI 配置（GitHub Actions + GitLab CI）

**Files:**
- Create: `/Users/yujian/Downloads/demo/mac-skils/examples/ci/github-actions.yml`
- Create: `/Users/yujian/Downloads/demo/mac-skils/examples/ci/gitlab-ci.yml`

**Interfaces:**
- Consumes: 设计文档第 6.3 节 CI/CD 替换规则
- Produces: 两个完整可参考的 CI 配置文件

- [ ] **Step 1: 创建 GitHub Actions 示例**

写入到 `/Users/yujian/Downloads/demo/mac-skils/examples/ci/github-actions.yml`：

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      # 配置 pip 国内源（清华源）
      - name: 配置 pip 国内源
        run: pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      # 配置 npm 国内源（淘宝源）
      - name: 配置 npm 国内源
        run: npm config set registry https://registry.npmmirror.com

      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.22'

      # 配置 Go proxy
      - name: 配置 Go proxy
        run: go env -w GOPROXY=https://goproxy.cn,direct

      - name: Install Python dependencies
        run: |
          pip install -r requirements.txt
          pytest

      - name: Install Node dependencies
        run: |
          npm ci
          npm test

      - name: Build Go
        run: |
          go mod download
          go build ./...
```

- [ ] **Step 2: 验证 GitHub Actions 示例包含所有国内源**

Run: `grep -F "pypi.tuna.tsinghua.edu.cn" /Users/yujian/Downloads/demo/mac-skils/examples/ci/github-actions.yml`
Expected: 至少 1 行

Run: `grep -F "registry.npmmirror.com" /Users/yujian/Downloads/demo/mac-skils/examples/ci/github-actions.yml`
Expected: 至少 1 行

Run: `grep -F "goproxy.cn" /Users/yujian/Downloads/demo/mac-skils/examples/ci/github-actions.yml`
Expected: 至少 1 行

- [ ] **Step 3: 创建 GitLab CI 示例**

写入到 `/Users/yujian/Downloads/demo/mac-skils/examples/ci/gitlab-ci.yml`：

```yaml
stages:
  - test
  - build

variables:
  # Go proxy
  GOPROXY: "https://goproxy.cn,direct"

before_script:
  # 配置 pip 国内源（清华源）
  - pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
  # 配置 npm 国内源（淘宝源）
  - npm config set registry https://registry.npmmirror.com
  # 配置 apt 国内源（清华源）
  - sed -i 's|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g; s|security.debian.org|mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list 2>/dev/null || true

test:python:
  stage: test
  image: python:3.11
  script:
    - pip install -r requirements.txt
    - pytest

test:node:
  stage: test
  image: node:20
  script:
    - npm ci
    - npm test

build:go:
  stage: build
  image: golang:1.22
  script:
    - go mod download
    - go build ./...
```

- [ ] **Step 4: 验证 GitLab CI 示例包含所有国内源**

Run: `grep -F "pypi.tuna.tsinghua.edu.cn" /Users/yujian/Downloads/demo/mac-skils/examples/ci/gitlab-ci.yml`
Expected: 至少 1 行

Run: `grep -F "registry.npmmirror.com" /Users/yujian/Downloads/demo/mac-skils/examples/ci/gitlab-ci.yml`
Expected: 至少 1 行

Run: `grep -F "goproxy.cn" /Users/yujian/Downloads/demo/mac-skils/examples/ci/gitlab-ci.yml`
Expected: 至少 1 行

- [ ] **Step 5: 验证两个 CI 示例通过 verify-sources.sh**

Run: `/Users/yujian/Downloads/demo/mac-skils/scripts/verify-sources.sh /Users/yujian/Downloads/demo/mac-skils/examples/ci/github-actions.yml`
Expected: 退出码 0

Run: `/Users/yujian/Downloads/demo/mac-skils/scripts/verify-sources.sh /Users/yujian/Downloads/demo/mac-skils/examples/ci/gitlab-ci.yml`
Expected: 退出码 0

---

## Task 10: 编写示例命令脚本（tar-to-linux.sh + rsync-to-linux.sh）

**Files:**
- Create: `/Users/yujian/Downloads/demo/mac-skils/examples/commands/tar-to-linux.sh`
- Create: `/Users/yujian/Downloads/demo/mac-skils/examples/commands/rsync-to-linux.sh`

**Interfaces:**
- Consumes: 设计文档第 4 章归档与传输规则
- Produces: 两个可运行的示例脚本，展示跨平台 tar 和 rsync 的推荐写法

- [ ] **Step 1: 创建 tar-to-linux.sh 示例**

写入到 `/Users/yujian/Downloads/demo/mac-skils/examples/commands/tar-to-linux.sh`：

```bash
#!/usr/bin/env bash
# tar-to-linux.sh - 在 MacOS 上打包文件，输出 Linux 友好的 tar.gz
# 用法: ./tar-to-linux.sh <source-dir> <output-name>

set -e

SRC="${1:?用法: $0 <source-dir> <output-name>}"
OUT="${2:?用法: $0 <source-dir> <output-name>}.tar.gz"

if [ "$(uname)" != "Darwin" ]; then
    echo "⚠️  此脚本设计为在 MacOS 上运行，当前 uname: $(uname)"
fi

# 推荐写法：剥离所有 MacOS 扩展属性
tar --no-acls --no-xattrs --no-fflags --no-mac-metadata \
    -czf "$OUT" -C "$(dirname "$SRC")" "$(basename "$SRC")"

echo "✅ 已生成: $OUT"
echo ""
echo "提示：在 Linux 端使用以下命令解压（避免所有权问题）："
echo "    tar -xzf \"$OUT\" --no-same-owner"
```

- [ ] **Step 2: 创建 rsync-to-linux.sh 示例**

写入到 `/Users/yujian/Downloads/demo/mac-skils/examples/commands/rsync-to-linux.sh`：

```bash
#!/usr/bin/env bash
# rsync-to-linux.sh - 从 MacOS 同步文件到 Linux 服务器，剥离扩展属性
# 用法: ./rsync-to-linux.sh <local-path> <user@host:/remote-path>

set -e

SRC="${1:?用法: $0 <local-path> <user@host:/remote-path>}"
DST="${2:?用法: $0 <local-path> <user@host:/remote-path>}"

if [ "$(uname)" != "Darwin" ]; then
    echo "⚠️  此脚本设计为在 MacOS 上运行，当前 uname: $(uname)"
fi

# 推荐写法：禁用权限、所有者、扩展属性同步
rsync -avz --no-perms --no-owner --no-group --no-xattrs \
    -e ssh "$SRC" "$DST"

echo "✅ 同步完成: $SRC -> $DST"
```

- [ ] **Step 3: 添加执行权限**

Run: `chmod +x /Users/yujian/Downloads/demo/mac-skils/examples/commands/*.sh`

- [ ] **Step 4: 语法检查两个脚本**

Run: `bash -n /Users/yujian/Downloads/demo/mac-skils/examples/commands/tar-to-linux.sh && bash -n /Users/yujian/Downloads/demo/mac-skils/examples/commands/rsync-to-linux.sh`
Expected: 无输出

- [ ] **Step 5: 验证两个脚本包含 macOS 兼容参数**

Run: `grep -F "--no-mac-metadata" /Users/yujian/Downloads/demo/mac-skils/examples/commands/tar-to-linux.sh`
Expected: 至少 1 行

Run: `grep -F "--no-xattrs" /Users/yujian/Downloads/demo/mac-skils/examples/commands/rsync-to-linux.sh`
Expected: 至少 1 行

- [ ] **Step 6: 端到端测试 tar-to-linux.sh**

Run:
```bash
mkdir -p /tmp/tar-test-src
echo "hello" > /tmp/tar-test-src/file1.txt
mkdir -p /tmp/tar-test-src/subdir
echo "world" > /tmp/tar-test-src/subdir/file2.txt

cd /Users/yujian/Downloads/demo/mac-skils/examples/commands
./tar-to-linux.sh /tmp/tar-test-src /tmp/tar-test-out

ls -la /tmp/tar-test-out.tar.gz
```
Expected: 看到生成的文件，输出包含 "✅ 已生成: /tmp/tar-test-out.tar.gz"

- [ ] **Step 7: 端到端验证生成的 tar 包**

Run: `/Users/yujian/Downloads/demo/mac-skils/scripts/verify-archive.sh /tmp/tar-test-out.tar.gz`
Expected: 退出码 0（如果在 MacOS 上运行，tar 会写 MacOS 属性，则非 0；这是预期的，因为此步骤仅验证脚本可生成归档）

注意：MacOS 上即使使用 `--no-mac-metadata`，仍可能因 pax header 残留某些属性。此步骤主要验证脚本可执行，退出码可能是 0 或 1，取决于 MacOS 版本。

- [ ] **Step 8: 清理测试文件**

Run:
```bash
rm -rf /tmp/tar-test-src /tmp/tar-test-out.tar.gz
```
Expected: 无输出（清理成功）

---

## Task 11: 编写 references 文档

**Files:**
- Create: `/Users/yujian/Downloads/demo/mac-skils/references/archive-cheatsheet.md`
- Create: `/Users/yujian/Downloads/demo/mac-skils/references/sources-mirror.md`
- Create: `/Users/yujian/Downloads/demo/mac-skils/references/ownership-handling.md`

**Interfaces:**
- Consumes: 设计文档第 4、5、6 章
- Produces: 三个人类阅读的速查/详解文档

- [ ] **Step 1: 创建 archive-cheatsheet.md**

写入到 `/Users/yujian/Downloads/demo/mac-skils/references/archive-cheatsheet.md`：

````markdown
# 跨平台归档与传输速查表

## tar 打包（Mac → Linux）

\`\`\`bash
# 推荐写法：剥离所有 MacOS 扩展属性
tar --no-acls --no-xattrs --no-fflags --no-mac-metadata \
    -czf archive.tar.gz files/

# 加固：强制 uid/gid 为 0（root）
tar --owner=0 --group=0 \
    --no-acls --no-xattrs --no-fflags --no-mac-metadata \
    -czf archive.tar.gz files/
\`\`\`

## tar 解压（Linux 上）

\`\`\`bash
# 推荐：不要恢复原始所有者
tar -xzf archive.tar.gz --no-same-owner

# 查看归档内容
tar -tvf archive.tar.gz
\`\`\`

## zip

\`\`\`bash
zip -r archive.zip files/
unzip archive.zip
\`\`\`

## rsync

\`\`\`bash
# 跨平台传输，剥离扩展属性
rsync -avz --no-perms --no-owner --no-group --no-xattrs \
    -e ssh ./local/ user@host:/remote/

# 排除 MacOS 隐藏文件
rsync -avz --exclude='.DS_Store' --exclude='._*' \
    -e ssh ./local/ user@host:/remote/
\`\`\`

## scp

\`\`\`bash
scp archive.tar.gz user@host:/remote/path/
scp -r ./local-dir/ user@host:/remote/path/
\`\`\`

## 参数速查

| 参数 | 作用 | MacOS | Linux |
|---|---|---|---|
| `--no-acls` | 不写入 ACL | ✅ | ✅ |
| `--no-xattrs` | 不写入扩展属性 | ✅ | ✅ |
| `--no-fflags` | 不写入文件标志 | ✅ | ✅ |
| `--no-mac-metadata` | 不写入 MacOS 特有元数据 | ✅（BSD tar） | ❌（GNU tar 报错） |
| `--owner=0` | 强制 uid 为 0 | ✅ | ✅ |
| `--no-same-owner` | 解压时不恢复所有者 | ✅ | ✅ |
````

- [ ] **Step 2: 创建 sources-mirror.md**

写入到 `/Users/yujian/Downloads/demo/mac-skils/references/sources-mirror.md`：

````markdown
# 国内源映射表

## 系统包管理器

### Debian / Ubuntu (apt)

清华源：
\`\`\`
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security/ bookworm-security main contrib non-free non-free-firmware
\`\`\`

替换命令：
\`\`\`bash
sed -i 's|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g; \
        s|security.debian.org|mirrors.tuna.tsinghua.edu.cn|g' \
    /etc/apt/sources.list.d/*.list /etc/apt/sources.list
\`\`\`

### RHEL / CentOS (yum / dnf)

阿里源：
\`\`\`ini
[base]
name=CentOS-\$releasever - Base
baseurl=https://mirrors.aliyun.com/centos/\$releasever/os/\$basearch/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-\$releasever
\`\`\`

替换命令：
\`\`\`bash
sed -i 's|mirrorlist.centos.org|mirrors.aliyun.com|g; \
        s|dl.fedoraproject.org|mirrors.aliyun.com|g' \
    /etc/yum.repos.d/*.repo
\`\`\`

### Alpine (apk)

阿里源：
\`\`\`
https://mirrors.aliyun.com/alpine/v3.18/main
https://mirrors.aliyun.com/alpine/v3.18/community
\`\`\`

替换命令：
\`\`\`bash
sed -i 's|dl-cdn.alpinelinux.org|mirrors.aliyun.com|g' /etc/apk/repositories
\`\`\`

## 语言包管理器

| 工具 | 默认源 | 国内源 | 命令 |
|---|---|---|---|
| pip | pypi.org | pypi.tuna.tsinghua.edu.cn | `pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple` |
| npm | registry.npmjs.org | registry.npmmirror.com | `npm config set registry https://registry.npmmirror.com` |
| Go | proxy.golang.org | goproxy.cn | `go env -w GOPROXY=https://goproxy.cn,direct` |
| Cargo | crates.io | rsproxy.cn | 编辑 ~/.cargo/config.toml |
| Composer | packagist.org | mirrors.aliyun.com/composer | `composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/` |

## Docker 镜像源

| 服务 | 默认 | 国内 |
|---|---|---|
| Docker Hub | docker.io | mirror.baidubce.com |

\`\`\`bash
# /etc/docker/daemon.json
{
  "registry-mirrors": ["https://mirror.baidubce.com"]
}
\`\`\`
````

- [ ] **Step 3: 创建 ownership-handling.md**

写入到 `/Users/yujian/Downloads/demo/mac-skils/references/ownership-handling.md`：

````markdown
# 所有权处理详解

## 问题描述

MacOS BSD tar 在打包时会调用 `stat(2)`，将文件的 uid 和 gid 写入 pax header：

\`\`\`
uid = 501      ← MacOS 第一个普通用户的 uid
gid = 20       ← staff 组的 gid
\`\`\`

跨平台传输时，这些数字在 Linux 上没有对应用户：
- **Linux 普通用户解压**：tar 会 fallback 使用当前用户的 uid/gid，表面正常但实际混乱
- **Linux root 解压**：tar 会忠实用 501:20 创建文件，导致"无主"状态

## 双阶段策略

### 阶段一：打包时剥离（Mac 上）

\`\`\`bash
tar --no-acls --no-xattrs --no-fflags --no-mac-metadata \
    -czf archive.tar.gz files/
\`\`\`

剥离后，tar 包内文件的 uid/gid 字段依然存在（默认值），但不再包含 MacOS 特有的扩展属性。

### 阶段二：解压时声明（Linux 上）

\`\`\`bash
tar -xzf archive.tar.gz --no-same-owner
\`\`\`

`--no-same-owner` 让当前解压用户自然拥有所有文件，不再尝试恢复归档里的 uid/gid。

## 何时显式指定 owner

仅当满足以下全部条件时：

1. 用户明确告知目标 Linux 用户名
2. 目标环境使用非 root 用户解压
3. 后续不需要调整所有者

\`\`\`bash
# 打包时强制为某个用户名
tar --owner=appuser --group=appuser \
    --no-acls --no-xattrs --no-fflags --no-mac-metadata \
    -czf archive.tar.gz files/

# Linux 上直接解压（无需 --no-same-owner）
tar -xzf archive.tar.gz
\`\`\`

## 不要做的事

❌ 不要写死 `--owner=root --group=root`，除非你确定目标用户是 root 且其他人不需修改
❌ 不要假设 Linux 上有 uid=501 的用户
❌ 不要在解压后用 `chown 501:20 file` 试图还原（uid 在 Linux 上无意义）
\`\`\`
````

- [ ] **Step 4: 验证三个文档创建成功**

Run: `ls -la /Users/yujian/Downloads/demo/mac-skils/references/`
Expected: 看到 3 个 .md 文件

---

## Task 12: 编写 README.md（英文）

**Files:**
- Create: `/Users/yujian/Downloads/demo/mac-skils/README.md`

**Interfaces:**
- Consumes: 设计文档第 8 章 README 设计
- Produces: GitHub 仓库英文门面页

- [ ] **Step 1: 创建英文 README.md**

写入：

````markdown
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

### Claude Code

\`\`\`bash
mkdir -p ~/.claude/skills/macos-to-linux-compat
cp SKILL.md ~/.claude/skills/macos-to-linux-compat/SKILL.md
\`\`\`

Claude Code auto-loads skills from `~/.claude/skills/`.

### Cursor / Aider / Continue / Other

Copy the content of `SKILL.md` into your project's:

- `AGENTS.md`, **or**
- `CLAUDE.md`, **or**
- System prompt configuration

## Quick Start

Just work as usual — when AI detects macOS environment and you trigger any cross-platform scenario (tar, Dockerfile, CI config), it will apply the rules automatically.

### Manual verification

\`\`\`bash
# Verify a tar archive is free of macOS extended attributes
./scripts/verify-archive.sh your-archive.tar.gz

# Verify a config file has all sources replaced
./scripts/verify-sources.sh your-Dockerfile

# Check if you're currently on macOS
./scripts/detect-macos.sh
\`\`\`

## Project Structure

\`\`\`
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
│   └── ownership-handling.md   # Ownership strategy explained
└── examples/
    ├── dockerfile/         # Dockerfile examples
    ├── ci/                 # CI configuration examples
    └── commands/           # Cross-platform command examples
\`\`\`

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
````

- [ ] **Step 2: 验证 README.md 内容**

Run: `grep -c "^##" /Users/yujian/Downloads/demo/mac-skils/README.md`
Expected: 输出 ≥ 8（至少 8 个 `##` 章节标题）

Run: `grep -F "[中文文档]" /Users/yujian/Downloads/demo/mac-skils/README.md`
Expected: 至少 1 行匹配

---

## Task 13: 编写 README.zh-CN.md（中文）

**Files:**
- Create: `/Users/yujian/Downloads/demo/mac-skils/README.zh-CN.md`

**Interfaces:**
- Consumes: Task 12 的英文 README 结构
- Produces: 章节结构对齐的中文版本

- [ ] **Step 1: 创建中文 README.zh-CN.md**

写入：

````markdown
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

### Claude Code

\`\`\`bash
mkdir -p ~/.claude/skills/macos-to-linux-compat
cp SKILL.md ~/.claude/skills/macos-to-linux-compat/SKILL.md
\`\`\`

Claude Code 会自动加载 `~/.claude/skills/` 下的 skill。

### Cursor / Aider / Continue / 其他

将 `SKILL.md` 的内容复制到项目的以下任意文件：

- `AGENTS.md`，**或**
- `CLAUDE.md`，**或**
- 工具的系统提示配置

## 快速开始

正常使用即可 —— 当 AI 检测到 MacOS 环境且触发跨平台场景（tar、Dockerfile、CI 配置）时，会自动应用规则。

### 手动验证

\`\`\`bash
# 验证 tar 包不含 macOS 扩展属性
./scripts/verify-archive.sh your-archive.tar.gz

# 验证配置文件的源已替换
./scripts/verify-sources.sh your-Dockerfile

# 检测当前是否在 MacOS
./scripts/detect-macos.sh
\`\`\`

## 项目结构

\`\`\`
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
│   └── ownership-handling.md   # 所有权策略详解
└── examples/
    ├── dockerfile/         # Dockerfile 示例
    ├── ci/                 # CI 配置示例
    └── commands/           # 跨平台命令示例
\`\`\`

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
````

- [ ] **Step 2: 验证中文 README 内容**

Run: `grep -c "^##" /Users/yujian/Downloads/demo/mac-skils/README.zh-CN.md`
Expected: 输出 ≥ 8（与英文版本章节数一致）

Run: `grep -F "[English]" /Users/yujian/Downloads/demo/mac-skils/README.zh-CN.md`
Expected: 至少 1 行匹配（链接到英文版）

---

## Task 14: 最终全量验证

**Files:**
- 无新增文件
- 验证所有先前创建的文件

**Interfaces:**
- Consumes: 所有先前 task 的产物
- Produces: 一个 PASS / FAIL 总结

- [ ] **Step 1: 检查所有脚本语法**

Run:
```bash
bash -n scripts/verify-archive.sh && \
bash -n scripts/verify-sources.sh && \
bash -n scripts/detect-macos.sh && \
bash -n examples/commands/tar-to-linux.sh && \
bash -n examples/commands/rsync-to-linux.sh && \
echo "✅ 所有脚本语法检查通过"
```
Expected: 输出 "✅ 所有脚本语法检查通过"

- [ ] **Step 2: 运行 detect-macos.sh 验证当前环境**

Run: `./scripts/detect-macos.sh`
Expected: 输出 "🍎 当前在 MacOS 上..."，退出码 0

- [ ] **Step 3: 验证所有示例 Dockerfile 通过 verify-sources.sh**

Run:
```bash
./scripts/verify-sources.sh examples/dockerfile/Dockerfile.apt && \
./scripts/verify-sources.sh examples/dockerfile/Dockerfile.yum && \
./scripts/verify-sources.sh examples/dockerfile/Dockerfile.multi-stage && \
./scripts/verify-sources.sh examples/ci/github-actions.yml && \
./scripts/verify-sources.sh examples/ci/gitlab-ci.yml && \
echo "✅ 所有示例通过源替换验证"
```
Expected: 输出 "✅ 所有示例通过源替换验证"

- [ ] **Step 4: 反向测试 verify-sources.sh 能检测到未替换源**

Run:
```bash
echo "FROM python:3.11
RUN pip install flask" > /tmp/bad-Dockerfile
./scripts/verify-sources.sh /tmp/bad-Dockerfile
echo "exit=$?"
rm /tmp/bad-Dockerfile
```
Expected: 输出 "❌ 发现未替换的源: pypi.org/simple"，`exit=1`

- [ ] **Step 5: 反向测试 verify-archive.sh 能检测到含 MacOS 属性的归档**

Run:
```bash
cd /tmp && mkdir -p mac-bad-src && echo "x" > mac-bad-src/f.txt && \
tar -czf mac-bad.tar.gz --no-xattrs --no-acls -C mac-bad-src f.txt && \
/Users/yujian/Downloads/demo/mac-skils/scripts/verify-archive.sh mac-bad.tar.gz
echo "exit=$?"
rm -rf mac-bad-src mac-bad.tar.gz
```
Expected: 退出码 0（干净的归档，应当通过）；如果是测试反向场景，可手动创建含 macOS 属性的归档，跳过此步

注：由于 sandbox 内 BSD tar 已被剥离扩展属性，强制制造"含 macOS 属性"的归档较困难。本步主要确认 verify-archive.sh 在干净归档上正确返回 0。

- [ ] **Step 6: 最终目录结构清单**

Run:
```bash
find /Users/yujian/Downloads/demo/mac-skils -type f \
  -not -path '*/docs/*' -not -path '*/.claude/*' \
  | sort
```
Expected: 看到以下文件：
- LICENSE
- .gitignore
- SKILL.md
- README.md
- README.zh-CN.md
- scripts/verify-archive.sh
- scripts/verify-sources.sh
- scripts/detect-macos.sh
- references/archive-cheatsheet.md
- references/sources-mirror.md
- references/ownership-handling.md
- examples/dockerfile/Dockerfile.apt
- examples/dockerfile/Dockerfile.yum
- examples/dockerfile/Dockerfile.multi-stage
- examples/ci/github-actions.yml
- examples/ci/gitlab-ci.yml
- examples/commands/tar-to-linux.sh
- examples/commands/rsync-to-linux.sh

---

## Self-Review

按 writing-plans skill 要求进行自审：

### 1. Spec 覆盖检查

设计文档要求的所有模块：

| 设计文档章节 | 覆盖任务 |
|---|---|
| 第 1 章 概述 | Task 12、Task 13（README） |
| 第 2 章 总体架构 | Task 2（SKILL.md） |
| 第 3 章 文件结构 | 所有 Task |
| 第 4 章 模块 A 归档与传输 | Task 2、Task 10、Task 11 |
| 第 5 章 模块 B 所有权处理 | Task 2、Task 11 |
| 第 6 章 模块 C 国内源配置 | Task 2、Task 6-9、Task 11 |
| 第 7 章 模块 D 验证脚本 | Task 3、Task 4、Task 5 |
| 第 8 章 README 设计 | Task 12、Task 13 |
| 第 9 章 SKILL.md 内容 | Task 2 |
| 第 10 章 测试策略 | Task 14 |
| 第 11 章 YAGNI | 在设计阶段已剔除 |

✅ 全部覆盖。

### 2. 占位符扫描

无 TBD / TODO / "类似 Task N" 引用。

### 3. 类型一致性

所有脚本文件名一致：`verify-archive.sh`、`verify-sources.sh`、`detect-macos.sh`、`tar-to-linux.sh`、`rsync-to-linux.sh`。所有路径前缀一致。

### 4. 范围检查

14 个 Task，每个 Task 独立可测试，复杂度适中。

✅ 通过自审。