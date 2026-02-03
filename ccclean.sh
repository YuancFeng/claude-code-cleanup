#!/usr/bin/env bash
# ccclean - Claude/Codex/OpenCode 孤儿进程清理工具 (安全增强版 v5)
# 用法: ccclean [--files]
#
# 安全特性：
# - 精确匹配：只清理相关进程（claude/codex/opencode/tail/shell-snapshot zsh）
# - PID 复用保护：kill 前验证 lstart + args + PPID
# - 运行时长保护：默认不清理运行少于 5 分钟的进程
# - POSIX 兼容：支持 macOS 默认 bash 3.2
# - 双重确认：选择后再次确认
#
# 选项：
#   --files  同时清理过期的 shell-snapshots 和空临时目录

set -e

# ============================================
# 配置项
# ============================================
# 最小运行时长（秒），运行时间少于此值的进程将被保护
MIN_RUNTIME_SECONDS=300  # 5分钟

# 分隔符（使用 ASCII Unit Separator，避免命令行参数冲突）
SEP=$'\x1f'

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# ============================================
# 辅助函数
# ============================================

# 将字符串转为小写（兼容 bash 3.2）
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# 将 etime 格式转换为秒
# 格式: [[DD-]HH:]MM:SS 或 MM:SS
etime_to_seconds() {
    local etime="$1"
    local days=0 hours=0 mins=0 secs=0

    # 去除前导空格
    etime=$(echo "$etime" | tr -d ' ')

    if [[ "$etime" =~ ^([0-9]+)-([0-9]+):([0-9]+):([0-9]+)$ ]]; then
        # DD-HH:MM:SS
        days=$((10#${BASH_REMATCH[1]}))
        hours=$((10#${BASH_REMATCH[2]}))
        mins=$((10#${BASH_REMATCH[3]}))
        secs=$((10#${BASH_REMATCH[4]}))
    elif [[ "$etime" =~ ^([0-9]+):([0-9]+):([0-9]+)$ ]]; then
        # HH:MM:SS
        hours=$((10#${BASH_REMATCH[1]}))
        mins=$((10#${BASH_REMATCH[2]}))
        secs=$((10#${BASH_REMATCH[3]}))
    elif [[ "$etime" =~ ^([0-9]+):([0-9]+)$ ]]; then
        # MM:SS
        mins=$((10#${BASH_REMATCH[1]}))
        secs=$((10#${BASH_REMATCH[2]}))
    else
        echo "0"
        return
    fi

    echo $((days * 86400 + hours * 3600 + mins * 60 + secs))
}

# 检查进程是否是 Claude 可执行文件（精确匹配）
is_claude_executable() {
    local pid="$1"

    # 获取进程名（不含路径，不含参数）
    local comm
    comm=$(ps -o comm= -p "$pid" 2>/dev/null | tr -d ' ')

    if [ -z "$comm" ]; then
        return 1
    fi

    # 转为小写
    local comm_lower
    comm_lower=$(to_lower "$comm")

    # 精确匹配：进程名必须完全是 "claude"（不是 claude-flow、claude-dev 等）
    if [ "$comm_lower" = "claude" ]; then
        return 0
    fi

    # 获取完整命令行的第一个参数（可执行文件路径）
    local executable
    executable=$(ps -o args= -p "$pid" 2>/dev/null | awk '{print $1}')

    if [ -z "$executable" ]; then
        return 1
    fi

    # 精确匹配：可执行文件路径必须以 /claude 结尾（不是 /claude-flow）
    # 或者是已知的 Claude 安装路径
    case "$executable" in
        */claude)
            return 0
            ;;
        "$HOME/.local/bin/claude")
            return 0
            ;;
        "$HOME/.local/share/claude/"*)
            return 0
            ;;
    esac

    return 1
}

# 检查进程是否是 Codex 可执行文件（精确匹配）
is_codex_executable() {
    local pid="$1"

    # 获取进程名（不含路径，不含参数）
    local comm
    comm=$(ps -o comm= -p "$pid" 2>/dev/null | tr -d ' ')

    if [ -z "$comm" ]; then
        return 1
    fi

    # 转为小写
    local comm_lower
    comm_lower=$(to_lower "$comm")

    # 精确匹配：进程名必须完全是 "codex"
    if [ "$comm_lower" = "codex" ]; then
        return 0
    fi

    # 获取完整命令行的第一个参数（可执行文件路径）
    local executable
    executable=$(ps -o args= -p "$pid" 2>/dev/null | awk '{print $1}')

    if [ -z "$executable" ]; then
        return 1
    fi

    # 精确匹配：可执行文件路径必须以 /codex 结尾
    # 或者是已知的 Codex 安装路径
    case "$executable" in
        */codex)
            return 0
            ;;
        "$HOME/.local/bin/codex")
            return 0
            ;;
        "/opt/homebrew/bin/codex")
            return 0
            ;;
        "/usr/local/bin/codex")
            return 0
            ;;
        "$HOME/.local/share/codex/"*)
            return 0
            ;;
    esac

    return 1
}

# 检查进程是否是 OpenCode 可执行文件（精确匹配）
is_opencode_executable() {
    local pid="$1"

    # 获取进程名（不含路径，不含参数）
    local comm
    comm=$(ps -o comm= -p "$pid" 2>/dev/null | tr -d ' ')

    if [ -z "$comm" ]; then
        return 1
    fi

    # 转为小写
    local comm_lower
    comm_lower=$(to_lower "$comm")

    # 精确匹配：进程名必须完全是 "opencode"
    if [ "$comm_lower" = "opencode" ]; then
        return 0
    fi

    # 获取完整命令行的第一个参数（可执行文件路径）
    local executable
    executable=$(ps -o args= -p "$pid" 2>/dev/null | awk '{print $1}')

    if [ -z "$executable" ]; then
        return 1
    fi

    # 精确匹配：可执行文件路径必须以 /opencode 结尾
    # 或者是已知的 OpenCode 安装路径
    case "$executable" in
        */opencode)
            return 0
            ;;
        "$HOME/.local/bin/opencode")
            return 0
            ;;
        "/opt/homebrew/bin/opencode")
            return 0
            ;;
        "/usr/local/bin/opencode")
            return 0
            ;;
        "$HOME/.local/share/opencode/"*)
            return 0
            ;;
    esac

    return 1
}

# 检测 Claude 相关的 tail 进程
is_claude_tail_process() {
    local pid="$1"
    local args=$(ps -o args= -p "$pid" 2>/dev/null)

    # 匹配: tail -f /private/tmp/claude/...
    if [[ "$args" =~ ^tail[[:space:]]+-[fF][[:space:]]+/private/tmp/claude/ ]]; then
        return 0
    fi
    return 1
}

# 检测执行 shell-snapshot 的 zsh 进程
is_shell_snapshot_zsh() {
    local pid="$1"

    local comm
    comm=$(ps -o comm= -p "$pid" 2>/dev/null | tr -d ' ')

    if [ -z "$comm" ]; then
        return 1
    fi

    # 仅允许 zsh 变体，避免误判其他进程
    if [[ ! "$comm" =~ ^-?(/bin/)?zsh$ ]]; then
        return 1
    fi

    local args
    args=$(ps -o args= -p "$pid" 2>/dev/null)

    # 匹配: /bin/zsh ... shell-snapshots/snapshot-zsh-...
    if [[ "$args" =~ shell-snapshots/snapshot-zsh- ]]; then
        return 0
    fi
    return 1
}

# 检查是否是相关进程（Claude/Codex/OpenCode 统一入口）
is_claude_related_process() {
    local pid="$1"
    local proc_type=""

    # 1. Claude 主进程
    if is_claude_executable "$pid"; then
        echo "claude"
        return 0
    fi

    # 2. Codex 主进程
    if is_codex_executable "$pid"; then
        echo "codex"
        return 0
    fi

    # 3. OpenCode 主进程
    if is_opencode_executable "$pid"; then
        echo "opencode"
        return 0
    fi

    # 4. tail -f /private/tmp/claude/...
    if is_claude_tail_process "$pid"; then
        echo "tail"
        return 0
    fi

    # 5. 执行 shell-snapshot 的 zsh
    if is_shell_snapshot_zsh "$pid"; then
        echo "zsh"
        return 0
    fi

    return 1
}

# 获取进程启动时间戳（用于 PID 复用验证）
get_process_lstart() {
    local pid="$1"
    ps -o lstart= -p "$pid" 2>/dev/null | tr -s ' '
}

# 获取进程的 PPID
get_ppid() {
    local pid="$1"
    ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' '
}

# 检查进程是否有终端号（有 TTY 的进程必须保护）
has_active_tty() {
    local pid="$1"
    local tty
    tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')

    if [ -z "$tty" ] || [ "$tty" = "??" ] || [ "$tty" = "?" ] || [ "$tty" = "-" ]; then
        return 1
    fi

    return 0
}

# 检查 PPID 是否是孤儿状态（PPID=1 或 PPID 是孤儿 zsh）
is_orphan_state() {
    local pid="$1"
    local ppid
    ppid=$(get_ppid "$pid")

    if [ -z "$ppid" ]; then
        return 1  # 进程不存在
    fi

    # PPID=1 直接是孤儿
    if [ "$ppid" = "1" ]; then
        return 0
    fi

    # 检查 PPID 是否是孤儿 zsh（其 PPID=1 且进程名匹配 zsh 变体）
    # 匹配: -zsh, -/bin/zsh, zsh, /bin/zsh
    local parent_ppid parent_comm
    parent_ppid=$(get_ppid "$ppid")
    parent_comm=$(ps -o comm= -p "$ppid" 2>/dev/null | tr -d ' ')

    if [ "$parent_ppid" = "1" ] && [[ "$parent_comm" =~ ^-?(/bin/)?zsh$ ]]; then
        return 0
    fi

    return 1
}

# 解析参数
CLEAN_FILES=false
for arg in "$@"; do
    case "$arg" in
        --files)
            CLEAN_FILES=true
            ;;
    esac
done

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║   Claude/Codex/OpenCode 孤儿进程清理工具 (v5)  ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# 第一步：保护带终端号的会话（绝对不能动）
# ============================================
echo -e "${GREEN}✓ 带终端号的相关进程将被保护${NC}"
echo -e "${BLUE}ℹ 运行时间 < ${MIN_RUNTIME_SECONDS}秒 的进程也将被保护${NC}"

# ============================================
# 第二步：识别孤儿相关进程（精确匹配）
# ============================================

# 临时文件存储候选进程
CANDIDATES_FILE=$(mktemp)
trap "rm -f $CANDIDATES_FILE" EXIT
protected_tty_count=0

# 找到所有孤儿 zsh（PPID=1 的 zsh）
# 匹配: -zsh, -/bin/zsh, zsh, /bin/zsh
# 使用 tr 确保列表是空格分隔的，避免 IFS 问题
ORPHAN_ZSH_LIST=$(ps -eo pid,ppid,comm | awk '$2==1 && $3~/^-?(\/?bin\/)?zsh$/ {print $1}' | tr '\n' ' ')

# 收集候选清理的相关进程
for zsh_pid in $ORPHAN_ZSH_LIST; do
    for child_pid in $(pgrep -P $zsh_pid 2>/dev/null || true); do
        # 精确检查：必须是相关进程
        # 使用 || true 避免 set -e 导致脚本退出
        proc_type=$(is_claude_related_process "$child_pid" 2>/dev/null || true)
        if [ -z "$proc_type" ]; then
            continue
        fi

        # 有终端号的进程必须保护
        if has_active_tty "$child_pid"; then
            protected_tty_count=$((protected_tty_count + 1))
            continue
        fi

        # 获取运行时间并检查阈值
        runtime=$(ps -o etime= -p $child_pid 2>/dev/null | tr -d ' ')
        runtime_secs=$(etime_to_seconds "$runtime")

        if [ "$runtime_secs" -lt "$MIN_RUNTIME_SECONDS" ]; then
            continue
        fi

        # 获取进程详细信息
        mem_kb=$(ps -o rss= -p $child_pid 2>/dev/null | tr -d ' ')
        proc_cmd=$(ps -o args= -p $child_pid 2>/dev/null)
        lstart=$(get_process_lstart $child_pid)
        ppid=$(get_ppid $child_pid)

        # 使用安全分隔符存储（新增 proc_type）
        echo "${child_pid}${SEP}${zsh_pid}${SEP}${mem_kb}${SEP}${runtime}${SEP}${proc_cmd}${SEP}${lstart}${SEP}${ppid}${SEP}${proc_type}" >> "$CANDIDATES_FILE"
    done
done

# 也检查直接孤儿的相关进程（PPID=1）
for pid in $(ps -eo pid,ppid,comm | awk '$2==1 {print $1}'); do
    # 精确检查：必须是相关进程
    # 使用 || true 避免 set -e 导致脚本退出
    proc_type=$(is_claude_related_process "$pid" 2>/dev/null || true)
    if [ -z "$proc_type" ]; then
        continue
    fi

    # 有终端号的进程必须保护
    if has_active_tty "$pid"; then
        protected_tty_count=$((protected_tty_count + 1))
        continue
    fi

    runtime=$(ps -o etime= -p $pid 2>/dev/null | tr -d ' ')
    runtime_secs=$(etime_to_seconds "$runtime")

    if [ "$runtime_secs" -lt "$MIN_RUNTIME_SECONDS" ]; then
        continue
    fi

    mem_kb=$(ps -o rss= -p $pid 2>/dev/null | tr -d ' ')
    proc_cmd=$(ps -o args= -p $pid 2>/dev/null)
    lstart=$(get_process_lstart $pid)
    ppid=$(get_ppid $pid)

    echo "${pid}${SEP}1${SEP}${mem_kb}${SEP}${runtime}${SEP}${proc_cmd}${SEP}${lstart}${SEP}${ppid}${SEP}${proc_type}" >> "$CANDIDATES_FILE"
done

# 去重
sort -u "$CANDIDATES_FILE" -o "$CANDIDATES_FILE"

if [ "$protected_tty_count" -gt 0 ]; then
    echo -e "${BLUE}ℹ 已保护 ${protected_tty_count} 个带终端号的相关进程${NC}"
fi

# 检查是否有候选进程
if [ ! -s "$CANDIDATES_FILE" ]; then
    echo -e "${GREEN}✅ 没有发现孤儿相关进程，系统很健康！${NC}"
    exit 0
fi

# ============================================
# 第三步：显示候选进程列表
# ============================================
echo ""
echo -e "${YELLOW}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════════════${NC}"
printf "${BOLD}%-4s %-8s %-10s %-14s %-10s %-50s${NC}\n" "编号" "PID" "内存" "运行时间" "类型" "进程命令"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════════════════════════════════${NC}"

declare -a PIDS
declare -a MEMS
declare -a LSTARTS
declare -a CMDS
declare -a PPIDS
declare -a TYPES
idx=0
total_mem=0

while IFS="$SEP" read -r pid parent_pid mem_kb runtime proc_cmd lstart ppid proc_type; do
    idx=$((idx + 1))
    mem_mb=$((mem_kb / 1024))
    total_mem=$((total_mem + mem_mb))

    PIDS[$idx]=$pid
    MEMS[$idx]=$mem_mb
    LSTARTS[$idx]="$lstart"
    CMDS[$idx]="$proc_cmd"
    PPIDS[$idx]="$ppid"
    TYPES[$idx]="$proc_type"

    # 截断过长的命令
    display_cmd="$proc_cmd"
    if [ ${#display_cmd} -gt 48 ]; then
        display_cmd="${display_cmd:0:45}..."
    fi

    # 类型标识带颜色
    case "$proc_type" in
        claude)   type_display="${CYAN}[claude]${NC}" ;;
        codex)    type_display="${GREEN}[codex]${NC}" ;;
        opencode) type_display="${MAGENTA}[opencode]${NC}" ;;
        tail)     type_display="${YELLOW}[tail]${NC}" ;;
        zsh)      type_display="${BLUE}[zsh]${NC}" ;;
        *)        type_display="[???]" ;;
    esac

    printf "%-4s %-8s %-10s %-14s %-10b %-50s\n" \
        "[$idx]" \
        "$pid" \
        "${mem_mb} MB" \
        "$runtime" \
        "$type_display" \
        "$display_cmd"
done < "$CANDIDATES_FILE"

echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}📊 汇总: ${idx} 个孤儿进程，共占用 ${RED}${total_mem} MB${NC} 内存"
echo ""

# ============================================
# 第四步：交互选择
# ============================================
echo -e "${BOLD}请选择要清理的进程:${NC}"
echo -e "  ${CYAN}a${NC} = 清理全部"
echo -e "  ${CYAN}1,2,3${NC} = 清理指定编号（逗号分隔）"
echo -e "  ${CYAN}1-10${NC} = 清理范围（如 1-10 清理编号1到10）"
echo -e "  ${CYAN}q${NC} = 退出"
echo ""
read -p "请输入选择: " choice

if [ "$choice" = "q" ] || [ -z "$choice" ]; then
    echo -e "${YELLOW}已取消${NC}"
    exit 0
fi

# 解析选择
selected=""
if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
    selected=$(seq 1 $idx)
elif echo "$choice" | grep -qE '^[0-9]+-[0-9]+$'; then
    start=$(echo "$choice" | cut -d'-' -f1)
    end=$(echo "$choice" | cut -d'-' -f2)
    selected=$(seq $start $end)
else
    selected=$(echo "$choice" | tr ',' ' ')
fi

# ============================================
# 第五步：二次确认
# ============================================
confirm_count=0
confirm_mem=0
confirm_pids=""

for sel in $selected; do
    if [ -n "${PIDS[$sel]}" ]; then
        confirm_count=$((confirm_count + 1))
        confirm_mem=$((confirm_mem + ${MEMS[$sel]}))
        confirm_pids="$confirm_pids ${PIDS[$sel]}"
    fi
done

echo ""
echo -e "${YELLOW}${BOLD}⚠️  即将清理 ${confirm_count} 个进程，释放约 ${confirm_mem} MB 内存${NC}"
echo -e "${YELLOW}   PID 列表:${confirm_pids}${NC}"
echo ""
read -p "确认清理? (y/n): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo -e "${YELLOW}已取消${NC}"
    exit 0
fi

# ============================================
# 第六步：执行清理（带完整安全验证）
# ============================================
cleaned_count=0
cleaned_mem=0
skipped_count=0

for sel in $selected; do
    if [ -z "${PIDS[$sel]}" ]; then
        echo -e "${RED}⚠ 无效编号: $sel${NC}"
        continue
    fi

    pid=${PIDS[$sel]}
    mem=${MEMS[$sel]}
    original_lstart="${LSTARTS[$sel]}"
    original_cmd="${CMDS[$sel]}"
    original_ppid="${PPIDS[$sel]}"

    echo -ne "清理 PID $pid (${mem}MB)... "

    # ============================================
    # 完整安全验证
    # ============================================

    # 1. 检查进程是否还存在
    current_lstart=$(get_process_lstart $pid)
    if [ -z "$current_lstart" ]; then
        echo -e "${YELLOW}已退出${NC}"
        continue
    fi

    # 2. 验证启动时间（防止 PID 复用）
    if [ "$current_lstart" != "$original_lstart" ]; then
        echo -e "${RED}⚠ PID 已被复用，跳过${NC}"
        skipped_count=$((skipped_count + 1))
        continue
    fi

    # 3. 验证命令行
    current_cmd=$(ps -o args= -p $pid 2>/dev/null)
    if [ "$current_cmd" != "$original_cmd" ]; then
        echo -e "${RED}⚠ 进程已变更，跳过${NC}"
        skipped_count=$((skipped_count + 1))
        continue
    fi

    # 4. 再次确认是 Claude/Codex/OpenCode 相关进程
    current_type=$(is_claude_related_process "$pid" 2>/dev/null || true)
    if [ -z "$current_type" ]; then
        echo -e "${RED}⚠ 非相关进程，跳过${NC}"
        skipped_count=$((skipped_count + 1))
        continue
    fi

    # 5. 确认仍无终端号（防止误杀活跃会话）
    if has_active_tty "$pid"; then
        echo -e "${RED}⚠ 仍有终端号，跳过${NC}"
        skipped_count=$((skipped_count + 1))
        continue
    fi

    # 6. 验证仍处于孤儿状态（新增）
    if ! is_orphan_state "$pid"; then
        echo -e "${RED}⚠ 已被重新接管，跳过${NC}"
        skipped_count=$((skipped_count + 1))
        continue
    fi

    # 安全清理
    kill -TERM $pid 2>/dev/null || true
    sleep 0.3

    if ps -p $pid > /dev/null 2>&1; then
        kill -KILL $pid 2>/dev/null || true
    fi

    cleaned_count=$((cleaned_count + 1))
    cleaned_mem=$((cleaned_mem + mem))

    echo -e "${GREEN}✓${NC}"
done

# ============================================
# 第七步：清理结果
# ============================================
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ 清理完成！${NC}"
echo -e "   清理进程: ${cleaned_count} 个"
echo -e "   释放内存: ${GREEN}${cleaned_mem} MB${NC}"
if [ $skipped_count -gt 0 ]; then
    echo -e "   ${YELLOW}跳过进程: ${skipped_count} 个（安全检查未通过）${NC}"
fi
echo -e "${GREEN}${BOLD}════════════════════════════════════════${NC}"

# 显示当前状态
echo ""
echo -e "${BLUE}当前状态:${NC}"
remaining_total=0
remaining_mem_kb=0
remaining_claude=0
remaining_codex=0
remaining_opencode=0
remaining_tail=0
remaining_zsh=0

while read -r pid; do
    proc_type=$(is_claude_related_process "$pid" 2>/dev/null || true)
    if [ -z "$proc_type" ]; then
        continue
    fi

    remaining_total=$((remaining_total + 1))
    case "$proc_type" in
        claude)   remaining_claude=$((remaining_claude + 1)) ;;
        codex)    remaining_codex=$((remaining_codex + 1)) ;;
        opencode) remaining_opencode=$((remaining_opencode + 1)) ;;
        tail)     remaining_tail=$((remaining_tail + 1)) ;;
        zsh)      remaining_zsh=$((remaining_zsh + 1)) ;;
    esac

    mem_kb=$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -n "$mem_kb" ]; then
        remaining_mem_kb=$((remaining_mem_kb + mem_kb))
    fi
done < <(ps -eo pid=)

remaining_mem=$((remaining_mem_kb / 1024))

echo -e "  剩余相关进程: ${remaining_total} 个"
echo -e "  其中: claude ${remaining_claude}, codex ${remaining_codex}, opencode ${remaining_opencode}, tail ${remaining_tail}, zsh ${remaining_zsh}"
echo -e "  剩余内存占用: ${remaining_mem} MB"

# ============================================
# 可选：清理过期文件
# ============================================
if [ "$CLEAN_FILES" = true ]; then
    echo ""
    echo -e "${CYAN}${BOLD}🗂️  清理过期文件...${NC}"

    # 清理 7 天以上的 shell-snapshots
    if [ -d "$HOME/.claude/shell-snapshots" ]; then
        old_snapshots=$(find "$HOME/.claude/shell-snapshots/" -name "snapshot-*.sh" -mtime +7 2>/dev/null | wc -l | tr -d ' ')
        if [ "$old_snapshots" -gt 0 ]; then
            find "$HOME/.claude/shell-snapshots/" -name "snapshot-*.sh" -mtime +7 -delete 2>/dev/null
            echo -e "  ${GREEN}✓${NC} 清理了 ${old_snapshots} 个过期 shell-snapshots"
        else
            echo -e "  ${BLUE}ℹ${NC} 没有过期的 shell-snapshots"
        fi
    fi

    # 清理空临时目录
    if [ -d "/private/tmp/claude" ]; then
        empty_dirs=$(find /private/tmp/claude/ -type d -empty 2>/dev/null | wc -l | tr -d ' ')
        if [ "$empty_dirs" -gt 0 ]; then
            find /private/tmp/claude/ -type d -empty -delete 2>/dev/null
            echo -e "  ${GREEN}✓${NC} 清理了 ${empty_dirs} 个空临时目录"
        else
            echo -e "  ${BLUE}ℹ${NC} 没有空临时目录"
        fi
    fi
fi
