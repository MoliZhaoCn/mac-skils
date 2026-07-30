#!/usr/bin/env bash
# install.sh - 一键安装 macos-to-linux-compat skill 到 AI 工具
#
# 用法:
#   ./install.sh                       交互式选择目标工具
#   ./install.sh --all                 安装到所有检测到的工具
#   ./install.sh claude-code cursor    安装到指定工具
#   ./install.sh --uninstall [target]  卸载（target 可省略，默认所有）
#   ./install.sh --list                列出所有支持的目标
#   ./install.sh --help                显示帮助
#
# 支持的工具:
#   claude-code   Claude Code (复制 SKILL.md 到 ~/.claude/skills/)
#   cursor        Cursor IDE (追加到 ./AGENTS.md 或 ./CLAUDE.md)
#   aider         Aider CLI (追加到 ./CONVENTIONS.md)
#   continue      Continue (VS Code) (合并到 ~/.continue/config.json)

set -e

# ============ 路径常量 ============

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_FILE="$SCRIPT_DIR/SKILL.md"
SKILL_NAME="macos-to-linux-compat"
MARKER_START="<!-- macos-to-linux-compat:start -->"
MARKER_END="<!-- macos-to-linux-compat:end -->"

# ============ 颜色（如果终端支持）============
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

# ============ 检测函数 ============

# 每个工具的检测返回 0（已安装）或 1（未安装）
detect_claude_code() {
    # Claude Code 检测：~/.claude/ 目录存在，或 claude 命令可用
    [ -d "$HOME/.claude" ] && return 0
    command -v claude >/dev/null 2>&1 && return 0
    return 1
}

detect_cursor() {
    # Cursor 检测：~/.cursor/ 或 cursor 命令
    [ -d "$HOME/.cursor" ] && return 0
    [ -d "$HOME/.config/Cursor" ] && return 0
    command -v cursor >/dev/null 2>&1 && return 0
    return 1
}

detect_aider() {
    # Aider 检测：aider 命令
    command -v aider >/dev/null 2>&1 && return 0
    return 1
}

detect_continue() {
    # Continue 检测：~/.continue/ 目录
    [ -d "$HOME/.continue" ] && return 0
    return 1
}

# 工具名映射：外部名 (命令行/显示) -> 内部函数名
# 因为 bash 函数名不允许连字符
TOOL_FN_NAME() {
    case "$1" in
        claude-code) echo "claude_code" ;;
        cursor)      echo "cursor" ;;
        aider)       echo "aider" ;;
        continue)    echo "continue" ;;
        *)           echo "$1" ;;
    esac
}

# 列出所有支持的工具名（按固定顺序）
ALL_TOOLS=(claude-code cursor aider continue)

# ============ 安装函数 ============

# Claude Code: 复制 SKILL.md 到 skills 目录
install_claude_code() {
    local target_dir="$HOME/.claude/skills/$SKILL_NAME"
    local target_file="$target_dir/SKILL.md"

    mkdir -p "$target_dir"

    if [ -f "$target_file" ]; then
        # 已存在：询问是否覆盖
        echo -e "${YELLOW}⚠️  目标文件已存在: $target_file${NC}"
        echo -n "覆盖? [y/N] "
        read -r ans
        if [[ ! "$ans" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}跳过 Claude Code${NC}"
            return 0
        fi
    fi

    cp "$SKILL_FILE" "$target_file"
    echo -e "${GREEN}✅ Claude Code: $target_file${NC}"
}

# Cursor: 追加 SKILL 内容到 ./AGENTS.md（如果存在）或 ./CLAUDE.md
install_cursor() {
    local target=""
    if [ -f "./AGENTS.md" ]; then
        target="./AGENTS.md"
    elif [ -f "./CLAUDE.md" ]; then
        target="./CLAUDE.md"
    else
        target="./AGENTS.md"  # 默认创建 AGENTS.md
    fi

    append_to_file "$target" "Cursor"
}

# Aider: 追加 SKILL 内容到 ./CONVENTIONS.md
install_aider() {
    append_to_file "./CONVENTIONS.md" "Aider"
}

# Continue: 合并 customInstructions 到 ~/.continue/config.json
install_continue() {
    local config_file="$HOME/.continue/config.json"
    mkdir -p "$(dirname "$config_file")"

    # 读取 SKILL.md 内容（去掉 frontmatter，因为 Continue 不需要）
    local skill_content
    skill_content=$(awk '/^---$/{c++; next} c>=2{print}' "$SKILL_FILE")

    if [ -f "$config_file" ]; then
        # 已存在：合并 customInstructions
        if command -v jq >/dev/null 2>&1; then
            local new_content
            new_content=$(jq --arg ci "$skill_content" '.customInstructions = ($ci)' "$config_file")
            echo "$new_content" > "$config_file"
            echo -e "${GREEN}✅ Continue: 已更新 $config_file 的 customInstructions${NC}"
        else
            echo -e "${YELLOW}⚠️  需要 jq 来合并 JSON。请安装 jq 后重试，或手动编辑 $config_file${NC}"
            return 1
        fi
    else
        # 不存在：创建新文件
        cat > "$config_file" <<EOF
{
  "customInstructions": $(printf '%s' "$skill_content" | jq -Rs .)
}
EOF
        echo -e "${GREEN}✅ Continue: 已创建 $config_file${NC}"
    fi
}

# 通用：追加到文件（带标记，用于 Cursor/Aider）
# 用法: append_to_file <path> <tool-name>
append_to_file() {
    local target="$1"
    local tool_name="$2"

    # 如果文件已包含 marker，认为已经安装过
    if [ -f "$target" ] && grep -q "$MARKER_START" "$target" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  $tool_name: $target 已包含此 skill${NC}"
        echo -n "替换已存在的内容? [y/N] "
        read -r ans
        if [[ ! "$ans" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}跳过 $tool_name${NC}"
            return 0
        fi
        # 删除旧内容（marker 之间的）
        sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$target"
        rm -f "$target.bak"
    fi

    # 追加新内容（带 marker）
    {
        echo ""
        echo "$MARKER_START"
        cat "$SKILL_FILE"
        echo "$MARKER_END"
    } >> "$target"

    echo -e "${GREEN}✅ $tool_name: 已追加到 $target${NC}"
}

# ============ 卸载函数 ============

uninstall_claude_code() {
    local target_dir="$HOME/.claude/skills/$SKILL_NAME"
    if [ -d "$target_dir" ]; then
        rm -rf "$target_dir"
        echo -e "${GREEN}✅ Claude Code: 已删除 $target_dir${NC}"
    else
        echo -e "${BLUE}ℹ️  Claude Code 未安装${NC}"
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
        echo -e "${BLUE}ℹ️  Continue 未安装${NC}"
        return 0
    fi

    if command -v jq >/dev/null 2>&1; then
        local updated
        updated=$(jq 'del(.customInstructions)' "$config_file")
        echo "$updated" > "$config_file"
        echo -e "${GREEN}✅ Continue: 已从 $config_file 移除 customInstructions${NC}"
    else
        echo -e "${YELLOW}⚠️  需要 jq 来编辑 JSON。请手动从 $config_file 移除 customInstructions${NC}"
    fi
}

# 通用：删除文件中的 marker 段
remove_markers() {
    local target="$1"
    local tool_name="$2"

    if [ ! -f "$target" ]; then
        return 0
    fi

    if ! grep -q "$MARKER_START" "$target" 2>/dev/null; then
        echo -e "${BLUE}ℹ️  $tool_name: $target 未包含此 skill${NC}"
        return 0
    fi

    sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$target"
    rm -f "$target.bak"

    # 如果文件变成空白，删除
    if [ ! -s "$target" ]; then
        rm -f "$target"
        echo -e "${GREEN}✅ $tool_name: 已删除空文件 $target${NC}"
    else
        echo -e "${GREEN}✅ $tool_name: 已从 $target 移除 skill 段${NC}"
    fi
}

# ============ 辅助函数 ============

# 交互式多选 TUI（类似 gum choose / whiptail，但不依赖外部工具）
#
# 用法:
#   multi_select "<prompt>" "<option1>" "<option2>" ...
#
# 行为:
#   - 上下箭头（或 k/j）切换当前项
#   - 空格选中/取消当前项
#   - a 切换全选/全不选
#   - q 取消（清空选择）
#   - Enter 确认
#
# 副作用:
#   - 设置全局数组 RESULT（选中项的列表）
multi_select() {
    local prompt="$1"
    shift
    local -a options=("$@")
    local total=${#options[@]}
    local current=0
    local -a selected
    local i

    # 初始化全部未选
    for ((i=0; i<total; i++)); do
        selected[$i]=0
    done

    # 保存终端状态
    local saved_stty=""
    if [ -t 0 ]; then
        saved_stty=$(stty -g 2>/dev/null || echo "")
    fi

    # 隐藏光标
    if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
        tput civis 2>/dev/null || printf '\033[?25l'
    else
        printf '\033[?25l'
    fi

    # trap 恢复终端
    __ms_cleanup() {
        if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
            tput cnorm 2>/dev/null || printf '\033[?25h'
        else
            printf '\033[?25h'
        fi
        if [ -n "$saved_stty" ]; then
            stty "$saved_stty" 2>/dev/null || true
        fi
        # 清屏 + 移到顶部（避免半截 TUI 残留）
        printf '\033[2J\033[H'
        trap - EXIT INT TERM
    }
    trap '__ms_cleanup' EXIT INT TERM

    # 渲染函数
    __ms_render() {
        # 移到屏幕顶部
        printf '\033[H'

        # 标题
        printf '\033[1m%s\033[0m\n' "$prompt"
        printf '\n'

        for ((i=0; i<total; i++)); do
            local mark
            if [ "${selected[$i]}" = "1" ]; then
                mark=$'[\033[32m✓\033[0m]'
            else
                mark="[ ]"
            fi

            if [ "$i" = "$current" ]; then
                # 当前项：反色 + 加粗
                printf '\033[7;1m > %s %s \033[0m\n' "$mark" "${options[$i]}"
            else
                printf '   %s %s\n' "$mark" "${options[$i]}"
            fi
        done

        printf '\n'
        printf '\033[2m  ↑/↓ 移动   SPACE 选中/取消   A 全选   Q 取消   Enter 确认\033[0m'
    }

    # 清屏
    printf '\033[2J'

    # 主循环
    # 注意：任何按键都不会意外退出循环，只有 Enter 才确认。
    # ESC、未识别键、功能键等都安全忽略。
    # read 失败（EOF/Ctrl-D）= 用户取消，退出循环（清空选择）。
    while true; do
        __ms_render

        # 读取按键
        local key
        if ! IFS= read -r -s -n1 key 2>/dev/null; then
            # EOF / Ctrl-D：视为用户取消
            selected=()
            for ((i=0; i<total; i++)); do selected[$i]=0; done
            break
        fi

        case "$key" in
            $'\x1b')
                # ESC 序列（方向键 / 其他）
                local seq=""
                # 尝试读取后续字节
                if IFS= read -r -s -n1 -t 0.01 seq 2>/dev/null; then
                    if [ "$seq" = "[" ] || [ "$seq" = "O" ]; then
                        local final=""
                        IFS= read -r -s -n1 -t 0.01 final 2>/dev/null || true
                        seq="$seq$final"
                    fi
                    case "$seq" in
                        '[A'|'[D'|'OA'|'OD')  # 上/左
                            ((current--))
                            [ $current -lt 0 ] && current=$((total-1))
                            ;;
                        '[B'|'[C'|'OB'|'OC')  # 下/右
                            ((current++))
                            [ $current -ge $total ] && current=0
                            ;;
                        *)
                            # 其他 ESC 序列（Home/End/PageUp/PageDown/F1-F12 等）
                            # 忽略
                            :
                            ;;
                    esac
                fi
                # 单独的 ESC = 忽略（不再清空退出），让用户继续编辑
                ;;
            ' ')
                # 空格：切换当前项
                if [ "${selected[$current]}" = "1" ]; then
                    selected[$current]=0
                else
                    selected[$current]=1
                fi
                ;;
            'a'|'A')
                # a: 全选 / 全不选（toggle）
                local all_sel=1
                for ((i=0; i<total; i++)); do
                    [ "${selected[$i]}" = "0" ] && all_sel=0
                done
                for ((i=0; i<total; i++)); do
                    if [ $all_sel = 1 ]; then
                        selected[$i]=0
                    else
                        selected[$i]=1
                    fi
                done
                ;;
            'q'|'Q')
                # q: 清空所有选择但不退出循环，让用户可以重新选
                selected=()
                for ((i=0; i<total; i++)); do selected[$i]=0; done
                ;;
            'k'|'K')
                # vim 风格上
                ((current--))
                [ $current -lt 0 ] && current=$((total-1))
                ;;
            'j'|'J')
                # vim 风格下
                ((current++))
                [ $current -ge $total ] && current=0
                ;;
            ''|$'\n'|$'\r')
                # Enter: 确认，退出循环
                break
                ;;
            *)
                # 未识别的按键：忽略，不退出
                :
                ;;
        esac
    done

    __ms_cleanup

    # 输出 RESULT 数组
    RESULT=()
    for ((i=0; i<total; i++)); do
        [ "${selected[$i]}" = "1" ] && RESULT+=("${options[$i]}")
    done
}

# 显示某工具的安装路径（用于 select_targets 输出）
show_install_path() {
    local tool="$1"
    case "$tool" in
        claude-code)
            printf '  \033[32m✓\033[0m %-12s \033[36m→\033[0m %s\n' \
                "$tool" "$HOME/.claude/skills/$SKILL_NAME/SKILL.md"
            ;;
        cursor)
            local target="./AGENTS.md"
            if [ -f "./CLAUDE.md" ] && [ ! -f "./AGENTS.md" ]; then
                target="./CLAUDE.md"
            fi
            local note="(将创建)"
            [ -f "$target" ] && note="(已存在，将追加)"
            printf '  \033[32m✓\033[0m %-12s \033[36m→\033[0m %s %s\n' \
                "$tool" "$target" "$note"
            ;;
        aider)
            printf '  \033[32m✓\033[0m %-12s \033[36m→\033[0m %s %s\n' \
                "$tool" "./CONVENTIONS.md" "$( [ -f ./CONVENTIONS.md ] && echo '(已存在，将追加)' || echo '(将创建)' )"
            ;;
        continue)
            printf '  \033[32m✓\033[0m %-12s \033[36m→\033[0m %s\n' \
                "$tool" "$HOME/.continue/config.json"
            ;;
        *)
            printf '  \033[32m✓\033[0m %s\n' "$tool"
            ;;
    esac
}

# 检测所有工具并输出列表
list_tools() {
    echo "支持的目标："
    echo ""
    for tool in "${ALL_TOOLS[@]}"; do
        local fn="detect_$(TOOL_FN_NAME "$tool")"
        if $fn; then
            echo -e "  ${GREEN}✓${NC} $tool  ${CYAN}(已检测到)${NC}"
        else
            echo -e "  ${RED}✗${NC} $tool  ${BLUE}(未检测到)${NC}"
        fi
    done
    echo ""
    echo "检测方式："
    echo "  claude-code: ~/.claude/ 目录或 claude 命令"
    echo "  cursor:      ~/.cursor/ 目录或 cursor 命令"
    echo "  aider:       aider 命令"
    echo "  continue:    ~/.continue/ 目录"
}

# 交互式选择目标
select_targets() {
    # 检测已安装的工具
    local -a detected=()
    for tool in "${ALL_TOOLS[@]}"; do
        local fn="detect_$(TOOL_FN_NAME "$tool")"
        if $fn; then
            detected+=("$tool")
        fi
    done

    if [ ${#detected[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠️  未检测到任何已安装的 AI 工具${NC}"
        echo ""
        echo "可用工具：${ALL_TOOLS[*]}"
        echo ""
        echo "可以直接用命令行指定：./install.sh claude-code cursor ..."
        exit 1
    fi

    echo -e "${BOLD}${CYAN}macos-to-linux-compat 安装工具${NC}"
    echo ""

    # 用 multi-select TUI 让用户选择
    multi_select "选择要安装到的 AI 工具：" "${detected[@]}"
    SELECTED=("${RESULT[@]}")

    if [ ${#SELECTED[@]} -eq 0 ]; then
        echo -e "${YELLOW}未选择任何工具，退出${NC}"
        exit 0
    fi

    # 展示每个工具的安装路径
    echo ""
    echo -e "${BOLD}将安装到以下位置：${NC}"
    for tool in "${SELECTED[@]}"; do
        show_install_path "$tool"
    done
    echo ""

    # 让用户最后确认
    echo -n "确认安装到以上位置? [Y/n] "
    read -r ans
    if [[ "$ans" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}已取消${NC}"
        exit 0
    fi
}

# 执行安装
do_install() {
    if [ ${#SELECTED[@]} -eq 0 ]; then
        echo -e "${YELLOW}未选择任何工具${NC}"
        exit 0
    fi

    echo ""
    echo -e "${BOLD}开始安装到: ${SELECTED[*]}${NC}"
    echo ""

    local errors=0
    for tool in "${SELECTED[@]}"; do
        local fn="install_$(TOOL_FN_NAME "$tool")"
        if type "$fn" >/dev/null 2>&1; then
            if ! "$fn"; then
                errors=$((errors+1))
            fi
        else
            echo -e "${RED}❌ 未知工具: $tool${NC}"
            errors=$((errors+1))
        fi
    done

    echo ""
    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}${BOLD}🎉 安装完成！${NC}"
    else
        echo -e "${YELLOW}⚠️  安装完成，但有 $errors 个错误${NC}"
    fi
}

# 执行卸载
do_uninstall() {
    local targets=("$@")
    if [ ${#targets[@]} -eq 0 ]; then
        # 尝试所有
        targets=("${ALL_TOOLS[@]}")
    fi

    echo ""
    echo -e "${BOLD}开始卸载: ${targets[*]}${NC}"
    echo ""

    for tool in "${targets[@]}"; do
        local fn="uninstall_$(TOOL_FN_NAME "$tool")"
        if type "$fn" >/dev/null 2>&1; then
            "$fn"
        else
            echo -e "${RED}❌ 未知工具: $tool${NC}"
        fi
    done

    echo ""
    echo -e "${GREEN}${BOLD}✅ 卸载完成${NC}"
}

# 打印帮助
print_help() {
    cat <<EOF
${BOLD}macos-to-linux-compat 安装工具${NC}

${BOLD}用法:${NC}
  ./install.sh                       交互式选择目标工具
  ./install.sh --all                 安装到所有检测到的工具
  ./install.sh claude-code cursor    安装到指定工具（空格分隔）
  ./install.sh --uninstall [target]  卸载（target 可省略，默认所有）
  ./install.sh --list                列出所有支持的目标及检测状态
  ./install.sh --help                显示此帮助

${BOLD}支持的工具:${NC}
  claude-code   Claude Code
                → 复制到 ~/.claude/skills/macos-to-linux-compat/SKILL.md

  cursor        Cursor IDE
                → 追加到 ./AGENTS.md 或 ./CLAUDE.md

  aider         Aider CLI
                → 追加到 ./CONVENTIONS.md

  continue      Continue (VS Code)
                → 合并到 ~/.continue/config.json (customInstructions)

${BOLD}示例:${NC}
  ./install.sh --all                  # 安装到所有检测到的工具
  ./install.sh claude-code            # 仅安装到 Claude Code
  ./install.sh claude-code cursor     # 安装到 Claude Code 和 Cursor
  ./install.sh --uninstall claude-code  # 卸载 Claude Code 安装
  ./install.sh --uninstall            # 卸载所有

${BOLD}要求:${NC}
  - bash 4+
  - SKILL.md 必须存在于脚本同目录
  - Continue 安装需要 jq（https://stedolan.github.io/jq/）
EOF
}

# ============ 主流程 ============

main() {
    # 检查 SKILL.md 存在
    if [ ! -f "$SKILL_FILE" ]; then
        echo -e "${RED}❌ 找不到 SKILL.md: $SKILL_FILE${NC}" >&2
        exit 1
    fi

    SELECTED=()

    # 解析参数
    case "${1:-}" in
        --help|-h|"")
            if [ -z "${1:-}" ]; then
                echo -e "${BOLD}${CYAN}macos-to-linux-compat 安装工具${NC}${NC}"
                echo ""
                select_targets
                do_install
            else
                print_help
            fi
            ;;
        --list|-l)
            list_tools
            ;;
        --all|-a)
            echo -e "${BOLD}${CYAN}macos-to-linux-compat 安装工具${NC}${NC}"
            echo ""
            SELECTED=()
            for tool in "${ALL_TOOLS[@]}"; do
                local fn="detect_$(TOOL_FN_NAME "$tool")"
                if $fn; then
                    SELECTED+=("$tool")
                    echo -e "${GREEN}✓${NC} 检测到: $tool"
                fi
            done
            echo ""
            if [ ${#SELECTED[@]} -eq 0 ]; then
                echo -e "${YELLOW}未检测到任何工具${NC}"
                exit 1
            fi
            do_install
            ;;
        --uninstall|-u)
            shift
            do_uninstall "$@"
            ;;
        *)
            # 工具名列表
            SELECTED=("$@")
            do_install
            ;;
    esac
}

main "$@"