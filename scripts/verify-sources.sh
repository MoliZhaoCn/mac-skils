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