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

## 归档与传输规则

### tar 打包（Mac → Linux）

**问题**：MacOS BSD tar 会写入 `LIBARCHIVE.xattr.com.apple.*`、`SCHILY.fflags`、`SCHILY.acl` 等扩展属性，Linux 上 GNU tar 解压时会报"未知扩展头"警告。同时 Mac 用户的 uid (501) 会被硬编码。

**推荐写法**：

```bash
tar --no-acls --no-xattrs --no-fflags --no-mac-metadata \
    -czf archive.tar.gz files/
```

可选加固（强制 uid 0，避免 root 解压时变"无主"）：

```bash
tar --owner=0 --group=0 \
    --no-acls --no-xattrs --no-fflags --no-mac-metadata \
    -czf archive.tar.gz files/
```

### tar 解压（Linux 上）

```bash
tar -xzf archive.tar.gz --no-same-owner
```

### zip 压缩

```bash
zip -r archive.zip files/
```

### rsync 跨平台传输

```bash
rsync -avz --no-perms --no-owner --no-group --no-xattrs \
    -e ssh ./local/ user@linux-host:/remote/
```

### scp 传输

```bash
scp archive.tar.gz user@linux-host:/remote/
```

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

### CI/CD 替换规则

在每个 CI 文件的 `setup-python` / `setup-node` / `setup-go` 步骤之后追加源配置：

```yaml
- name: 配置 pip 国内源
  run: pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

- name: 配置 npm 国内源
  run: npm config set registry https://registry.npmmirror.com
```

## 验证清单

生成产物后执行下列命令验证：

```bash
./scripts/verify-archive.sh archive.tar.gz
./scripts/verify-sources.sh Dockerfile
./scripts/detect-macos.sh
```