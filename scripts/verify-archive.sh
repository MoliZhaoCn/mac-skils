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