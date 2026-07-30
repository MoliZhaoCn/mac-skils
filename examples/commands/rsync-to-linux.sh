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
