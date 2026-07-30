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
