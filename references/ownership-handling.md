# 所有权处理详解

## 问题描述

MacOS BSD tar 在打包时会调用 `stat(2)`，将文件的 uid 和 gid 写入 pax header：

```
uid = 501      ← MacOS 第一个普通用户的 uid
gid = 20       ← staff 组的 gid
```

跨平台传输时，这些数字在 Linux 上没有对应用户：
- **Linux 普通用户解压**：tar 会 fallback 使用当前用户的 uid/gid，表面正常但实际混乱
- **Linux root 解压**：tar 会忠实用 501:20 创建文件，导致"无主"状态

## 双阶段策略

### 阶段一：打包时剥离（Mac 上）

```bash
tar --no-acls --no-xattrs --no-fflags --no-mac-metadata \
    -czf archive.tar.gz files/
```

剥离后，tar 包内文件的 uid/gid 字段依然存在（默认值），但不再包含 MacOS 特有的扩展属性。

### 阶段二：解压时声明（Linux 上）

```bash
tar -xzf archive.tar.gz --no-same-owner
```

`--no-same-owner` 让当前解压用户自然拥有所有文件，不再尝试恢复归档里的 uid/gid。

## 何时显式指定 owner

仅当满足以下全部条件时：

1. 用户明确告知目标 Linux 用户名
2. 目标环境使用非 root 用户解压
3. 后续不需要调整所有者

```bash
# 打包时强制为某个用户名
tar --owner=appuser --group=appuser \
    --no-acls --no-xattrs --no-fflags --no-mac-metadata \
    -czf archive.tar.gz files/

# Linux 上直接解压（无需 --no-same-owner）
tar -xzf archive.tar.gz
```

## 不要做的事

❌ 不要写死 `--owner=root --group=root`，除非你确定目标用户是 root 且其他人不需修改
❌ 不要假设 Linux 上有 uid=501 的用户
❌ 不要在解压后用 `chown 501:20 file` 试图还原（uid 在 Linux 上无意义）