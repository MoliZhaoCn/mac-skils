#!/usr/bin/env bash
# install.sh - macos-to-linux-compat 一键安装脚本
#
# 用法（仿 npx skills add 风格）:
#   ./install.sh                    # 交互式选择并安装（默认 add）
#   ./install.sh add                # 同上
#   ./install.sh add all            # 安装所有检测到的工具
#   ./install.sh add <tool>...      # 安装指定的工具
#   ./install.sh remove             # 交互式选择要卸载的工具
#   ./install.sh remove <tool>...   # 卸载指定的工具
#   ./install.sh list               # 列出已检测到的工具
#   ./install.sh help               # 显示帮助
#
# 支持的工具: claude-code, cursor, aider, continue

# 不使用 set -e，避免与 read 失败、空数组 splice 等场景冲突
# 我们自己处理错误

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_FILE="$SCRIPT_DIR/SKILL.md"
SKILL_NAME="macos-to-linux-compat"
MARKER_START="<!-- macos-to-linux-compat:start -->"
MARKER_END="<!-- macos-to-linux-compat:end -->"

# 工具定义：[name, display, install_path_template, detect_fn]
# detect_fn: 返回 0 表示已检测到，1 表示未检测到
ALL_TOOLS=(
    "claude-code"
    "cursor"
    "aider"
    "continue"
)

# 颜色（注意：必须用 $'\033...' 形式，bash 单引号不会处理 \ 转义）
if [ -t 1 ]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'
    CYAN=$'\033[0;36m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    NC=$'\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' NC=''
fi

# ============ 颜色输出函数 ============

info() { printf "${CYAN}ℹ${NC}  %s\n" "$*"; }
ok()   { printf "${GREEN}✓${NC}  %s\n" "$*"; }
warn() { printf "${YELLOW}⚠${NC}  %s\n" "$*"; }
err()  { printf "${RED}✗${NC}  %s\n" "$*" >&2; }
bold() { printf "${BOLD}%s${NC}\n" "$*"; }

# ============ 检测函数 ============

detect_tool() {
    case "$1" in
        claude-code)
            [ -d "$HOME/.claude" ] && return 0
            command -v claude >/dev/null 2>&1 && return 0
            return 1
            ;;
        cursor)
            [ -d "$HOME/.cursor" ] && return 0
            [ -d "$HOME/.config/Cursor" ] && return 0
            command -v cursor >/dev/null 2>&1 && return 0
            return 1
            ;;
        aider)
            command -v aider >/dev/null 2>&1 && return 0
            return 1
            ;;
        continue)
            [ -d "$HOME/.continue" ] && return 0
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

# 工具名转函数后缀（连字符转下划线）
tool_fn() {
    echo "$1" | tr '-' '_'
}

# ============ 安装路径 ============

target_path() {
    case "$1" in
        claude-code) echo "$HOME/.claude/skills/$SKILL_NAME/SKILL.md" ;;
        cursor)
            if [ -f "./AGENTS.md" ] && [ ! -f "./CLAUDE.md" ]; then
                echo "./AGENTS.md"
            else
                echo "./AGENTS.md"  # 默认 AGENTS.md
            fi
            ;;
        aider)    echo "./CONVENTIONS.md" ;;
        continue) echo "$HOME/.continue/config.json" ;;
        *)        echo "" ;;
    esac
}

# ============ 安装函数 ============

install_tool() {
    local tool="$1"
    case "$tool" in
        claude-code) install_claude_code ;;
        cursor)      install_cursor ;;
        aider)       install_aider ;;
        continue)    install_continue ;;
        *)           err "未知工具: $tool"; return 1 ;;
    esac
}

install_claude_code() {
    local target_dir="$HOME/.claude/skills/$SKILL_NAME"
    local target_file="$target_dir/SKILL.md"

    mkdir -p "$target_dir"

    if [ -f "$target_file" ]; then
        warn "目标文件已存在: $target_file"
        if ! confirm "覆盖?" "N"; then
            info "跳过 Claude Code"
            return 0
        fi
    fi

    cp "$SKILL_FILE" "$target_file"
    ok "Claude Code → $target_file"
}

install_cursor() {
    local target="./AGENTS.md"
    [ -f "./CLAUDE.md" ] && [ ! -f "./AGENTS.md" ] && target="./CLAUDE.md"

    if [ -f "$target" ] && grep -q "$MARKER_START" "$target" 2>/dev/null; then
        warn "$target 已包含此 skill"
        if confirm "替换已存在的内容?" "N"; then
            sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$target"
            rm -f "$target.bak"
        else
            info "跳过 Cursor"
            return 0
        fi
    fi

    {
        printf "\n%s\n" "$MARKER_START"
        cat "$SKILL_FILE"
        printf "\n%s\n" "$MARKER_END"
    } >> "$target"

    ok "Cursor → $target"
}

install_aider() {
    local target="./CONVENTIONS.md"

    if [ -f "$target" ] && grep -q "$MARKER_START" "$target" 2>/dev/null; then
        warn "$target 已包含此 skill"
        if confirm "替换已存在的内容?" "N"; then
            sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$target"
            rm -f "$target.bak"
        else
            info "跳过 Aider"
            return 0
        fi
    fi

    {
        printf "\n%s\n" "$MARKER_START"
        cat "$SKILL_FILE"
        printf "\n%s\n" "$MARKER_END"
    } >> "$target"

    ok "Aider → $target"
}

install_continue() {
    local config_file="$HOME/.continue/config.json"
    mkdir -p "$(dirname "$config_file")"

    # 读取 SKILL.md 内容（去掉 frontmatter）
    local skill_content
    skill_content=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$SKILL_FILE")

    if ! command -v jq >/dev/null 2>&1; then
        err "需要 jq 来合并 JSON。请安装 jq 后重试：brew install jq"
        return 1
    fi

    if [ -f "$config_file" ]; then
        local new_content
        new_content=$(jq --arg ci "$skill_content" '.customInstructions = ($ci)' "$config_file")
        printf '%s\n' "$new_content" > "$config_file"
        ok "Continue → 已更新 $config_file"
    else
        local json_content
        json_content=$(printf '%s' "$skill_content" | jq -Rs .)
        cat > "$config_file" <<EOF
{
  "customInstructions": $json_content
}
EOF
        ok "Continue → 已创建 $config_file"
    fi
}

# ============ 卸载函数 ============

uninstall_tool() {
    local tool="$1"
    case "$tool" in
        claude-code) uninstall_claude_code ;;
        cursor)      uninstall_cursor ;;
        aider)       uninstall_aider ;;
        continue)    uninstall_continue ;;
        *)           err "未知工具: $tool"; return 1 ;;
    esac
}

uninstall_claude_code() {
    local target_dir="$HOME/.claude/skills/$SKILL_NAME"
    if [ -d "$target_dir" ]; then
        rm -rf "$target_dir"
        ok "已删除 $target_dir"
    else
        info "Claude Code 未安装"
    fi
}

uninstall_cursor() {
    remove_marker_from "./AGENTS.md" "Cursor"
    remove_marker_from "./CLAUDE.md" "Cursor"
}

uninstall_aider() {
    remove_marker_from "./CONVENTIONS.md" "Aider"
}

uninstall_continue() {
    local config_file="$HOME/.continue/config.json"
    if [ ! -f "$config_file" ]; then
        info "Continue 未安装"
        return 0
    fi
    if ! command -v jq >/dev/null 2>&1; then
        err "需要 jq 来编辑 JSON"
        return 1
    fi
    local updated
    updated=$(jq 'del(.customInstructions)' "$config_file")
    printf '%s\n' "$updated" > "$config_file"
    ok "已从 $config_file 移除 customInstructions"
}

remove_marker_from() {
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
    if [ ! -s "$target" ]; then
        rm -f "$target"
        ok "已删除空文件 $target"
    else
        ok "已从 $target 移除 $name 段"
    fi
}

# ============ 通用辅助 ============

# confirm "question" "default_Y_or_N"
# 返回值 0=yes, 1=no
confirm() {
    local prompt="$1"
    local default="$2"
    local suffix="[y/N]"
    [ "$default" = "Y" ] && suffix="[Y/n]"

    local ans
    printf "${YELLOW}%s${NC} %s " "$prompt" "$suffix"
    if read -r ans; then
        :
    else
        ans="$default"  # EOF 用默认
    fi

    if [ "$default" = "Y" ]; then
        if [[ "$ans" =~ ^[Nn]$ ]]; then return 1; fi
    else
        if [[ ! "$ans" =~ ^[Yy]$ ]]; then return 1; fi
    fi
    return 0
}

# 检测已安装的工具列表（输出到 stdout）
detect_installed() {
    local tool
    for tool in "${ALL_TOOLS[@]}"; do
        if detect_tool "$tool"; then
            printf '%s\n' "$tool"
        fi
    done
}

# ============ TUI 多选 ============
# 参考 npx skills add 的 checkbox 体验
#
# 用法: tui_checkbox "标题" 选项1 选项2 ...
# 读全局变量 SELECTED (数组)
# 键位: ↑/↓ 移动高亮
#       Space 切换当前项
#       a 切换全选
#       Enter 确认
#       Ctrl-C 退出

tui_checkbox() {
    local title="$1"
    shift
    local -a options=("$@")
    local total=${#options[@]}
    local current=0
    local -a selected
    local i
    for ((i=0; i<total; i++)); do
        selected[$i]=0
    done

    # 隐藏光标
    printf '\033[?25l'
    # 退出时清理（INT/TERM 必须显式 exit，否则 bash 默认不退出，read 会卡住）
    trap 'printf "\033[?25h\n"' EXIT
    trap 'printf "\033[?25h\n"; exit 130' INT
    trap 'printf "\033[?25h\n"; exit 143' TERM

    render() {
        printf '\033[H\033[2J'
        printf '\033[1m%s\033[0m\n' "$title"
        printf '\n'
        local i
        for ((i=0; i<total; i++)); do
            local mark
            if [ "${selected[$i]}" = "1" ]; then
                mark="${GREEN}●${NC}"
            else
                mark="${DIM}○${NC}"
            fi
            if [ "$i" = "$current" ]; then
                # 当前项：反色高亮
                printf '\033[7m > %s %d) %s\033[0m\n' "$mark" "$((i+1))" "${options[$i]}"
            else
                printf '   %s %d) %s\n' "$mark" "$((i+1))" "${options[$i]}"
            fi
        done
        printf '\n'
        printf '\033[2m↑/↓ 移动 · Space 切换 · a 全选 · Enter 确认\033[0m'
    }

    printf '\033[2J'
    render

    while true; do
        local key
        if ! IFS= read -r -s -n1 key 2>/dev/null; then
            # EOF：确认
            break
        fi

        # ESC 序列（方向键）
        if [ "$key" = $'\x1b' ]; then
            local seq=""
            if IFS= read -r -s -n1 -t 0.3 seq 2>/dev/null; then
                if [ "$seq" = "[" ] || [ "$seq" = "O" ]; then
                    local final=""
                    IFS= read -r -s -n1 -t 0.3 final 2>/dev/null || true
                    seq="$seq$final"
                fi
                case "$seq" in
                    '[A'|'OA'|'[D'|'OD')  # 上 / 左
                        current=$((current - 1))
                        if [ "$current" -lt 0 ]; then
                            current=$((total - 1))
                        fi
                        render
                        ;;
                    '[B'|'OB'|'[C'|'OC')  # 下 / 右
                        current=$((current + 1))
                        if [ "$current" -ge "$total" ]; then
                            current=0
                        fi
                        render
                        ;;
                esac
            fi
            continue
        fi

        case "$key" in
            ''|$'\n'|$'\r')
                # Enter
                break
                ;;
            ' ')
                # 空格：切换当前项
                if [ "${selected[$current]}" = "1" ]; then
                    selected[$current]=0
                else
                    selected[$current]=1
                fi
                render
                ;;
            'a'|'A')
                # 全选 toggle
                local all_sel=1
                local j
                for ((j=0; j<total; j++)); do
                    if [ "${selected[$j]}" = "0" ]; then
                        all_sel=0
                    fi
                done
                for ((j=0; j<total; j++)); do
                    if [ "$all_sel" = "1" ]; then
                        selected[$j]=0
                    else
                        selected[$j]=1
                    fi
                done
                render
                ;;
        esac
    done

    # 恢复光标
    printf '\033[?25h\n'
    trap - EXIT INT TERM

    # 输出结果
    SELECTED=()
    for ((i=0; i<total; i++)); do
        if [ "${selected[$i]}" = "1" ]; then
            SELECTED+=("${options[$i]}")
        fi
    done
}

# ============ 子命令实现 ============

cmd_add() {
    # 1. 参数解析
    if [ "$1" = "all" ]; then
        # 安装所有检测到的
        local tool
        for tool in $(detect_installed); do
            install_tool "$tool"
        done
        return 0
    fi

    if [ "$#" -gt 0 ]; then
        # 指定工具
        local tool errors=0
        for tool in "$@"; do
            if ! install_tool "$tool"; then
                errors=$((errors+1))
            fi
        done
        return $errors
    fi

    # 交互模式
    local -a installed
    while IFS= read -r line; do
        installed+=("$line")
    done < <(detect_installed)

    if [ "${#installed[@]}" -eq 0 ]; then
        err "未检测到任何已安装的 AI 工具"
        printf "\n"
        printf "可用工具：\n"
        for tool in "${ALL_TOOLS[@]}"; do
            printf "  - %s\n" "$tool"
        done
        printf "\n你可以直接指定：./install.sh add <tool1> [<tool2> ...]\n"
        return 1
    fi

    printf '\n'
    bold "macos-to-linux-compat 安装工具"
    printf '\n'
    info "已检测到 ${#installed[@]} 个 AI 工具"
    printf '\n'

    tui_checkbox "选择要安装到的工具：" "${installed[@]}"

    if [ "${#SELECTED[@]}" -eq 0 ]; then
        warn "未选择任何工具"
        return 0
    fi

    # 展示安装路径
    printf '\n'
    bold "将安装到以下位置："
    local tool
    for tool in "${SELECTED[@]}"; do
        printf "  ${GREEN}●${NC} %-12s ${CYAN}→${NC} %s\n" "$tool" "$(target_path "$tool")"
    done
    printf '\n'

    if ! confirm "确认安装?" "Y"; then
        warn "已取消"
        return 0
    fi

    # 执行安装
    local errors=0
    for tool in "${SELECTED[@]}"; do
        if ! install_tool "$tool"; then
            errors=$((errors+1))
        fi
    done

    printf '\n'
    if [ "$errors" -eq 0 ]; then
        ok "全部安装完成！"
    else
        warn "安装完成，但有 $errors 个错误"
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
    local -a installed
    while IFS= read -r line; do
        installed+=("$line")
    done < <(detect_installed)

    if [ "${#installed[@]}" -eq 0 ]; then
        info "没有已安装的工具需要卸载"
        return 0
    fi

    printf '\n'
    bold "macos-to-linux-compat 卸载工具"
    printf '\n'

    tui_checkbox "选择要卸载的工具：" "${installed[@]}"

    if [ "${#SELECTED[@]}" -eq 0 ]; then
        warn "未选择任何工具"
        return 0
    fi

    if ! confirm "确认卸载以上工具?" "N"; then
        warn "已取消"
        return 0
    fi

    local errors=0
    local tool
    for tool in "${SELECTED[@]}"; do
        if ! uninstall_tool "$tool"; then
            errors=$((errors+1))
        fi
    done

    printf '\n'
    if [ "$errors" -eq 0 ]; then
        ok "全部卸载完成"
    else
        warn "卸载完成，但有 $errors 个错误"
    fi
    return 0
}

cmd_list() {
    printf '\n'
    bold "macos-to-linux-compat 支持的 AI 工具"
    printf '\n'
    local tool
    for tool in "${ALL_TOOLS[@]}"; do
        if detect_tool "$tool"; then
            printf "  ${GREEN}●${NC} %-12s ${CYAN}已检测到${NC}\n" "$tool"
        else
            printf "  ${DIM}○${NC} %-12s ${DIM}未检测到${NC}\n" "$tool"
        fi
    done
    printf '\n'
    info "检测方式:"
    printf "  claude-code: ~/.claude/ 目录或 claude 命令\n"
    printf "  cursor:      ~/.cursor/ 目录或 cursor 命令\n"
    printf "  aider:       aider 命令\n"
    printf "  continue:    ~/.continue/ 目录\n"
}

cmd_help() {
    cat <<EOF
${BOLD}macos-to-linux-compat 安装工具${NC}

${BOLD}用法:${NC}
  ./install.sh                    交互式选择并安装（默认 add）
  ./install.sh add                同上
  ./install.sh add all            安装所有检测到的工具
  ./install.sh add <tool>...      安装指定的工具
  ./install.sh remove             交互式选择要卸载的工具
  ./install.sh remove <tool>...   卸载指定的工具
  ./install.sh list               列出工具及检测状态
  ./install.sh help               显示此帮助

${BOLD}支持的工具:${NC}
  claude-code   Claude Code
                ${DIM}→${NC} 复制到 ~/.claude/skills/macos-to-linux-compat/SKILL.md

  cursor        Cursor IDE
                ${DIM}→${NC} 追加到 ./AGENTS.md (或 ./CLAUDE.md)

  aider         Aider CLI
                ${DIM}→${NC} 追加到 ./CONVENTIONS.md

  continue      Continue (VS Code)
                ${DIM}→${NC} 合并到 ~/.continue/config.json

${BOLD}示例:${NC}
  ./install.sh                    # 交互式
  ./install.sh add claude-code    # 仅安装到 Claude Code
  ./install.sh add all            # 全部安装
  ./install.sh remove aider       # 卸载 Aider
  ./install.sh list               # 列出工具

${BOLD}说明:${NC}
  - Continue 安装需要 jq（https://stedolan.github.io/jq/）
  - SKILL.md 必须与 install.sh 在同一目录
EOF
}

# ============ 主入口 ============

main() {
    if [ ! -f "$SKILL_FILE" ]; then
        err "找不到 SKILL.md: $SKILL_FILE"
        exit 1
    fi

    local cmd="${1:-}"
    shift 2>/dev/null || true

    case "$cmd" in
        "")
            # 默认行为：add
            cmd_add
            ;;
        add|install)
            cmd_add "$@"
            ;;
        remove|uninstall|rm)
            cmd_remove "$@"
            ;;
        list|ls)
            cmd_list
            ;;
        help|-h|--help)
            cmd_help
            ;;
        -*)
            err "未知选项: $cmd"
            printf "试试 ./install.sh help\n"
            exit 1
            ;;
        *)
            # 不带子命令：当作 add
            cmd_add "$cmd" "$@"
            ;;
    esac
}

main "$@"