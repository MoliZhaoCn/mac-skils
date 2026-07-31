#!/usr/bin/env bash
# install.sh - macos-to-linux-compat 一键安装脚本
#
# 设计原则:
#   - 没有 TUI，避免方向键/空格/ESC 解析的所有坑
#   - 纯文字交互：检测 → 编号列表 → 用户输入编号
#   - 直接命令行参数可完全跳过交互
#
# 用法:
#   ./install.sh                    默认: add (无参数 = add)
#   ./install.sh add                添加 skill
#   ./install.sh add all            添加所有检测到的工具
#   ./install.sh add <tool>...      添加指定工具
#   ./install.sh remove             移除 skill
#   ./install.sh remove <tool>...   移除指定工具
#   ./install.sh list               列出工具及检测状态
#   ./install.sh help               帮助
#
# 支持的工具: claude-code, cursor, aider, continue

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# SKILL.md 路径：优先用环境变量（npx 模式），否则用脚本同目录（独立运行模式）
SKILL_FILE="${SKILL_FILE:-$SCRIPT_DIR/SKILL.md}"
SKILL_NAME="macos-to-linux-compat"
MARKER_START="<!-- macos-to-linux-compat:start -->"
MARKER_END="<!-- macos-to-linux-compat:end -->"

ALL_TOOLS=(claude-code cursor aider continue)

# 颜色（ANSI-C quoting 让 \033 成为真正的 ESC）
if [ -t 1 ]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    CYAN=$'\033[0;36m'
    BOLD=$'\033[1m'
    NC=$'\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' BOLD='' NC=''
fi

# ============ 输出辅助 ============

info() { printf "${CYAN}i${NC} %s\n" "$*"; }
ok()   { printf "${GREEN}+${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}!${NC} %s\n" "$*"; }
err()  { printf "${RED}x${NC} %s\n" "$*" >&2; }

die() {
    err "$@"
    exit 1
}

# ============ 检测 ============

detect_tool() {
    case "$1" in
        claude-code) [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1 ;;
        cursor)      [ -d "$HOME/.cursor" ] || [ -d "$HOME/.config/Cursor" ] || command -v cursor >/dev/null 2>&1 ;;
        aider)       command -v aider >/dev/null 2>&1 ;;
        continue)    [ -d "$HOME/.continue" ] ;;
        *) return 1 ;;
    esac
}

# 检测所有已安装的工具，输出到 stdout
detect_all() {
    local tool
    for tool in "${ALL_TOOLS[@]}"; do
        if detect_tool "$tool"; then
            printf '%s\n' "$tool"
        fi
    done
}

# ============ 安装/卸载目标 ============

target_path() {
    case "$1" in
        claude-code) printf '%s/.claude/skills/%s/SKILL.md' "$HOME" "$SKILL_NAME" ;;
        cursor)      printf './AGENTS.md' ;;
        aider)       printf './CONVENTIONS.md' ;;
        continue)    printf '%s/.continue/config.json' "$HOME" ;;
        *)           return 1 ;;
    esac
}

# ============ 安装函数 ============

install_claude_code() {
    local target="$HOME/.claude/skills/$SKILL_NAME/SKILL.md"
    mkdir -p "$(dirname "$target")"

    if [ -f "$target" ]; then
        warn "已存在: $target"
        confirm "覆盖" "N" || { info "跳过 Claude Code"; return 0; }
    fi

    cp "$SKILL_FILE" "$target"
    ok "Claude Code -> $target"
}

install_cursor() {
    local target="./AGENTS.md"
    [ -f "./CLAUDE.md" ] && [ ! -f "./AGENTS.md" ] && target="./CLAUDE.md"

    if [ -f "$target" ] && grep -q "$MARKER_START" "$target" 2>/dev/null; then
        warn "$target 已包含此 skill"
        confirm "替换已存在的内容" "N" || { info "跳过 Cursor"; return 0; }
        sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$target"
        rm -f "$target.bak"
    fi

    {
        printf "\n%s\n" "$MARKER_START"
        cat "$SKILL_FILE"
        printf "\n%s\n" "$MARKER_END"
    } >> "$target"

    ok "Cursor -> $target"
}

install_aider() {
    local target="./CONVENTIONS.md"

    if [ -f "$target" ] && grep -q "$MARKER_START" "$target" 2>/dev/null; then
        warn "$target 已包含此 skill"
        confirm "替换已存在的内容" "N" || { info "跳过 Aider"; return 0; }
        sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$target"
        rm -f "$target.bak"
    fi

    {
        printf "\n%s\n" "$MARKER_START"
        cat "$SKILL_FILE"
        printf "\n%s\n" "$MARKER_END"
    } >> "$target"

    ok "Aider -> $target"
}

install_continue() {
    local config_file="$HOME/.continue/config.json"

    if ! command -v jq >/dev/null 2>&1; then
        err "需要 jq: brew install jq"
        return 1
    fi

    mkdir -p "$(dirname "$config_file")"

    # 读取 SKILL.md 内容（去掉 frontmatter）
    local skill_content
    skill_content=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$SKILL_FILE")

    if [ -f "$config_file" ]; then
        local new_content
        new_content=$(jq --arg ci "$skill_content" '.customInstructions = $ci' "$config_file")
        printf '%s\n' "$new_content" > "$config_file"
        ok "Continue -> 已更新 $config_file"
    else
        local json_content
        json_content=$(printf '%s' "$skill_content" | jq -Rs .)
        cat > "$config_file" <<EOF
{
  "customInstructions": $json_content
}
EOF
        ok "Continue -> 已创建 $config_file"
    fi
}

install_tool() {
    case "$1" in
        claude-code) install_claude_code ;;
        cursor)      install_cursor ;;
        aider)       install_aider ;;
        continue)    install_continue ;;
        *)           err "未知工具: $1"; return 1 ;;
    esac
}

# ============ 卸载函数 ============

uninstall_claude_code() {
    local target="$HOME/.claude/skills/$SKILL_NAME"
    if [ -d "$target" ]; then
        rm -rf "$target"
        ok "已删除 $target"
    else
        info "Claude Code 未安装"
    fi
}

uninstall_cursor() {
    remove_markers "./AGENTS.md" "Cursor"
    remove_markers "./CLAUDE.md" "Cursor"
}

uninstall_aider() {
    remove_markers "./CONVENTIONS.md" "Aider"
}

uninstall_continue() {
    local config_file="$HOME/.continue/config.json"
    if [ ! -f "$config_file" ]; then
        info "Continue 未安装"
        return 0
    fi
    if ! command -v jq >/dev/null 2>&1; then
        err "需要 jq"
        return 1
    fi
    local updated
    updated=$(jq 'del(.customInstructions)' "$config_file")
    printf '%s\n' "$updated" > "$config_file"
    ok "已从 $config_file 移除 customInstructions"
}

remove_markers() {
    local target="$1"
    local name="$2"

    if [ ! -f "$target" ]; then
        return 0
    fi

    if ! grep -q "$MARKER_START" "$target" 2>/dev/null; then
        info "$name: $target 未包含此 skill"
        return 0
    fi

    sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$target"
    rm -f "$target.bak"

    # 删完 marker 后如果文件只剩空白，删整个文件
    if [ ! -s "$target" ] || ! grep -q '[^[:space:]]' "$target" 2>/dev/null; then
        rm -f "$target"
        ok "已删除空文件 $target"
    else
        ok "已从 $target 移除 $name 段"
    fi
}

uninstall_tool() {
    case "$1" in
        claude-code) uninstall_claude_code ;;
        cursor)      uninstall_cursor ;;
        aider)       uninstall_aider ;;
        continue)    uninstall_continue ;;
        *)           err "未知工具: $1"; return 1 ;;
    esac
}

# ============ 通用辅助 ============

# confirm "问题" "默认Y/N" -> 退出码 0=确认 1=取消
confirm() {
    local prompt="$1"
    local default="$2"
    local suffix="[y/N]"
    [ "$default" = "Y" ] && suffix="[Y/n]"

    local ans
    printf "%s %s " "$prompt" "$suffix"
    if ! read -r ans; then
        ans="$default"
    fi

    if [ "$default" = "Y" ]; then
        [[ ! "$ans" =~ ^[Nn]$ ]]
    else
        [[ "$ans" =~ ^[Yy]$ ]]
    fi
}

# 列出已检测到的工具，返回赋值给数组
# 用法: list_installed arr_name
list_installed() {
    local -n outvar="$1"
    outvar=()
    while IFS= read -r line; do
        outvar+=("$line")
    done < <(detect_all)
}

# 选择工具（纯文字，无 TUI）
# 列出已安装工具，让用户输入编号（逗号分隔）
# 输入空 = 全选；输入 q = 取消
# 用法: select_tools "提示语" 数组名
#       返回值 0=确认 1=取消；选中结果放在 SELECTED（全局）
select_tools() {
    local prompt="$1"
    local -n tools="$2"

    if [ "${#tools[@]}" -eq 0 ]; then
        SELECTED=()
        return 1
    fi

    printf "\n%s\n" "$prompt"
    printf "\n"
    local i
    for ((i=0; i<${#tools[@]}; i++)); do
        printf "  %d) %s\n" "$((i+1))" "${tools[$i]}"
    done
    printf "\n"
    printf "输入编号（多个用逗号分隔），回车 = 全部，q = 取消: "

    local input
    if ! read -r input; then
        input=""
    fi

    # 空输入 = 全选
    if [ -z "$input" ]; then
        SELECTED=("${tools[@]}")
        return 0
    fi

    # q = 取消
    case "$input" in
        q|Q) SELECTED=(); return 1 ;;
    esac

    # 解析逗号分隔的编号
    SELECTED=()
    IFS=',' read -ra nums <<< "$input"
    for n in "${nums[@]}"; do
        # 去掉空白
        n="${n// /}"
        # 验证是数字
        if [[ "$n" =~ ^[0-9]+$ ]]; then
            local idx=$((n - 1))
            if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#tools[@]}" ]; then
                SELECTED+=("${tools[$idx]}")
            else
                warn "跳过无效编号: $n"
            fi
        else
            warn "跳过非数字: $n"
        fi
    done

    if [ "${#SELECTED[@]}" -eq 0 ]; then
        return 1
    fi
    return 0
}

# ============ 子命令 ============

cmd_add() {
    if [ ! -f "$SKILL_FILE" ]; then
        die "找不到 SKILL.md: $SKILL_FILE"
    fi

    # 参数模式
    if [ "$#" -gt 0 ]; then
        if [ "$1" = "all" ]; then
            shift
            local tool
            for tool in $(detect_all); do
                install_tool "$tool"
            done
            local -a detected=()
            list_installed detected
            if [ "${#detected[@]}" -eq 0 ]; then
                warn "未检测到任何已安装的 AI 工具"
                info "可手动指定: $0 add <tool>"
                return 1
            fi
            return 0
        fi

        local tool errors=0
        for tool in "$@"; do
            if ! install_tool "$tool"; then
                errors=$((errors+1))
            fi
        done
        return $errors
    fi

    # 交互模式
    local -a detected=()
    list_installed detected

    if [ "${#detected[@]}" -eq 0 ]; then
        warn "未检测到任何已安装的 AI 工具"
        info "可手动指定: $0 add <tool>（如 claude-code、cursor、aider、continue）"
        return 1
    fi

    echo
    echo "macos-to-linux-compat 安装工具"
    echo "============================"
    echo
    info "检测到 ${#detected[@]} 个 AI 工具"

    if ! select_tools "选择要安装的工具:" detected; then
        info "已取消"
        return 0
    fi

    echo
    echo "将安装到:"
    local tool
    for tool in "${SELECTED[@]}"; do
        printf "  - %s -> %s\n" "$tool" "$(target_path "$tool")"
    done
    echo

    if ! confirm "确认安装" "Y"; then
        info "已取消"
        return 0
    fi

    local errors=0
    for tool in "${SELECTED[@]}"; do
        if ! install_tool "$tool"; then
            errors=$((errors+1))
        fi
    done

    echo
    if [ "$errors" -eq 0 ]; then
        ok "安装完成"
    else
        warn "$errors 个工具安装失败"
    fi
    return 0
}

cmd_remove() {
    if [ "$#" -gt 0 ]; then
        local tool errors=0
        for tool in "$@"; do
            if ! uninstall_tool "$tool"; then
                errors=$((errors+1))
            fi
        done
        return $errors
    fi

    # 交互模式
    local -a detected=()
    list_installed detected

    if [ "${#detected[@]}" -eq 0 ]; then
        info "未检测到任何 AI 工具（无可卸载）"
        return 0
    fi

    echo
    echo "macos-to-linux-compat 卸载工具"
    echo "==========================="
    echo

    if ! select_tools "选择要卸载的工具:" detected; then
        info "已取消"
        return 0
    fi

    echo
    if ! confirm "确认卸载" "N"; then
        info "已取消"
        return 0
    fi

    local errors=0
    local tool
    for tool in "${SELECTED[@]}"; do
        if ! uninstall_tool "$tool"; then
            errors=$((errors+1))
        fi
    done

    echo
    if [ "$errors" -eq 0 ]; then
        ok "卸载完成"
    else
        warn "$errors 个工具卸载失败"
    fi
    return 0
}

cmd_list() {
    echo
    echo "macos-to-linux-compat - AI 工具检测"
    echo "================================="
    echo
    local tool
    for tool in "${ALL_TOOLS[@]}"; do
        if detect_tool "$tool"; then
            printf "  %s%-12s%s  已检测到\n" "$GREEN" "$tool" "$NC"
        else
            printf "  %s%-12s%s  未检测到\n" "$NC" "$tool" "$NC"
        fi
    done
    echo
    info "检测方式:"
    echo "  claude-code: ~/.claude/ 目录或 claude 命令"
    echo "  cursor:      ~/.cursor/ 目录或 cursor 命令"
    echo "  aider:       aider 命令"
    echo "  continue:    ~/.continue/ 目录"
}

cmd_help() {
    local cmd_name="macos-to-linux-compat"

    # 如果通过 npx 调用，显示 npx 用法
    if [ -n "${npm_lifecycle_event:-}" ] || [ "$0" = "$cmd_name" ]; then
        cmd_name="npx $cmd_name"
    else
        cmd_name="$0"
    fi

    cat <<EOF
${BOLD}macos-to-linux-compat 安装工具${NC}

${BOLD}用法:${NC}
  ${cmd_name}                  默认: add (添加 skill)
  ${cmd_name} add              添加 skill
  ${cmd_name} add all          添加所有检测到的工具
  ${cmd_name} add <tool>...    添加指定工具
  ${cmd_name} remove           移除 skill
  ${cmd_name} remove <tool>... 移除指定工具
  ${cmd_name} list             列出工具及检测状态
  ${cmd_name} help             显示此帮助

${BOLD}支持的工具:${NC}
  claude-code   Claude Code
                -> ~/.claude/skills/macos-to-linux-compat/SKILL.md

  cursor        Cursor IDE
                -> ./AGENTS.md (或 ./CLAUDE.md)

  aider         Aider CLI
                -> ./CONVENTIONS.md

  continue      Continue (VS Code)
                -> ~/.continue/config.json

${BOLD}示例:${NC}
  ${cmd_name}                       # 交互式添加
  ${cmd_name} add claude-code       # 仅安装到 Claude Code
  ${cmd_name} add all               # 安装到所有检测到的工具
  ${cmd_name} remove aider          # 卸载 Aider

${BOLD}交互模式:${NC}
  工具列表以编号显示。输入编号（多个用逗号分隔）：
    1,3     -> 选中第 1 和第 3 个
  回车 = 全部选中
  q   = 取消
EOF
}

# ============ 主入口 ============

main() {
    local cmd="${1:-}"
    shift 2>/dev/null || true

    case "$cmd" in
        "")
            cmd_add
            ;;
        add|install|i)
            cmd_add "$@"
            ;;
        remove|uninstall|rm|r)
            cmd_remove "$@"
            ;;
        list|ls|l)
            cmd_list
            ;;
        help|-h|--help)
            cmd_help
            ;;
        -*)
            err "未知选项: $cmd"
            info "试试: $0 help"
            exit 1
            ;;
        *)
            cmd_add "$cmd" "$@"
            ;;
    esac
}

main "$@"