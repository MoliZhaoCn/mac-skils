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