# ccclean - Claude Code 进程清理工具

---
name: ccclean
description: Claude Code 进程清理工具。清理孤儿进程、释放内存。触发词：ccclean、清理 Claude 进程、清理孤儿进程
---

## 触发词

- `/ccclean`
- `清理 Claude 进程`
- `清理孤儿进程`
- `claude process cleanup`
- `kill orphan processes`

## 命令说明

| 命令 | 说明 |
|------|------|
| `/ccclean` | 快速扫描 - 显示进程摘要 |
| `/ccclean audit` | 深度审计 - 完整分类报告 |
| `/ccclean clean` | 交互式清理（需确认） |
| `/ccclean clean --dry-run` | 预览清理（不执行） |
| `/ccclean clean --safe` | 仅清理真正孤儿（PPID=1） |

## 执行指令

### 核心概念

**孤儿进程识别**：
- TTY=?? （无终端关联）
- PPID=1 （父进程为 init/launchd，真正孤儿）
- 进程年龄 >24 小时

**受保护进程**（永不清理）：
- 有 TTY 关联的进程（ttysXXX）
- 当前 shell 的祖先进程链
- Claude 桌面应用的子进程
- MCP 服务子进程
- 运行时间 <1 小时的新进程

---

## Phase 0: 快速扫描

当用户运行 `/ccclean` 或 `/ccclean scan` 时执行：

```bash
# 获取当前 shell 的 PID 和祖先链
CURRENT_PID=$$
CURRENT_TTY=$(tty 2>/dev/null | sed 's|/dev/||')

# 统计各类进程
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║             ccclean - 进程扫描结果                  ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# 有 TTY 的活跃进程
ACTIVE=$(ps -eo tty,comm | grep -E "ttys.*claude" | wc -l | tr -d ' ')

# 无 TTY 的后台进程
BACKGROUND=$(ps -eo tty,comm | grep -E "^\?\?.*claude" | wc -l | tr -d ' ')

# 真正孤儿 (PPID=1)
ORPHAN=$(ps -eo ppid,comm | awk '$1==1 && /claude/' | wc -l | tr -d ' ')

# 古老进程 (>7天)
OLD_COUNT=$(ps -eo etime,comm | grep claude | awk '{
  split($1, a, /[-:]/)
  if (length(a) == 4) days = a[1]
  else days = 0
  if (days >= 7) count++
} END {print count+0}')

echo "进程统计:"
echo "  ✓ 活跃会话 (有 TTY):      $ACTIVE 个"
echo "  ⚠ 后台进程 (无 TTY):      $BACKGROUND 个"
echo "  ☠ 真正孤儿 (PPID=1):      $ORPHAN 个"
echo "  📦 古老进程 (>7天):       $OLD_COUNT 个"
echo ""
echo "运行 \`/ccclean audit\` 查看详细报告"
echo "运行 \`/ccclean clean\` 开始清理"
```

输出示例：
```
╔════════════════════════════════════════════════════╗
║             ccclean - 进程扫描结果                  ║
╚════════════════════════════════════════════════════╝

进程统计:
  ✓ 活跃会话 (有 TTY):      5 个
  ⚠ 后台进程 (无 TTY):    113 个
  ☠ 真正孤儿 (PPID=1):      2 个
  📦 古老进程 (>7天):      23 个

运行 `/ccclean audit` 查看详细报告
运行 `/ccclean clean` 开始清理
```

---

## Phase 1: 深度审计

当用户运行 `/ccclean audit` 时执行：

```bash
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║           ccclean - 深度审计报告                   ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# 获取所有 claude 相关进程的详细信息
echo "═══════════════════════════════════════════════════════"
echo "【活跃会话】(有 TTY - 受保护)"
echo "═══════════════════════════════════════════════════════"
ps -eo pid,ppid,tty,etime,rss,command | grep -E "ttys.*claude" | grep -v grep | head -20
echo ""

echo "═══════════════════════════════════════════════════════"
echo "【真正孤儿】(PPID=1 - 可安全清理)"
echo "═══════════════════════════════════════════════════════"
ps -eo pid,ppid,tty,etime,rss,command | awk '$2==1 && /claude/' | grep -v grep | head -20
echo ""

echo "═══════════════════════════════════════════════════════"
echo "【后台进程】(无 TTY - 按年龄分组)"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "--- 古老 (>7天) ---"
ps -eo pid,ppid,tty,etime,rss,command | grep -E "^\s*[0-9]+\s+[0-9]+\s+\?\?" | grep claude | grep -v grep | awk '{
  split($4, a, /[-:]/)
  if (length(a) == 4 && a[1] >= 7) print
}' | head -10
echo ""

echo "--- 陈旧 (1-7天) ---"
ps -eo pid,ppid,tty,etime,rss,command | grep -E "^\s*[0-9]+\s+[0-9]+\s+\?\?" | grep claude | grep -v grep | awk '{
  split($4, a, /[-:]/)
  if (length(a) == 4 && a[1] >= 1 && a[1] < 7) print
}' | head -10
echo ""

echo "--- 较新 (<24小时) ---"
ps -eo pid,ppid,tty,etime,rss,command | grep -E "^\s*[0-9]+\s+[0-9]+\s+\?\?" | grep claude | grep -v grep | awk '{
  split($4, a, /[-:]/)
  if (length(a) < 4) print
}' | head -10
echo ""

# 内存统计
echo "═══════════════════════════════════════════════════════"
echo "【内存使用统计】"
echo "═══════════════════════════════════════════════════════"
TOTAL_MEM=$(ps -eo rss,command | grep claude | grep -v grep | awk '{sum+=$1} END {print sum/1024}')
echo "Claude 进程总内存占用: ${TOTAL_MEM:-0} MB"
echo ""
```

---

## Phase 2: 用户确认（关键）

当用户运行 `/ccclean clean` 时，**必须使用 AskUserQuestion 工具** 获取用户确认：

**步骤 1**: 收集待清理进程信息

```bash
# 统计各类可清理进程
ORPHAN_PIDS=$(ps -eo pid,ppid,tty | awk '$2==1 && $3=="??" {print $1}' | grep -f <(ps -eo pid,command | grep claude | awk '{print $1}'))
ORPHAN_COUNT=$(echo "$ORPHAN_PIDS" | grep -c . 2>/dev/null || echo 0)

# 古老进程 (>7天, 无 TTY)
OLD_PIDS=$(ps -eo pid,tty,etime,command | grep -E "\?\?.*claude" | grep -v grep | awk '{
  split($3, a, /[-:]/)
  if (length(a) == 4 && a[1] >= 7) print $1
}')
OLD_COUNT=$(echo "$OLD_PIDS" | grep -c . 2>/dev/null || echo 0)

# 陈旧进程 (1-7天, 无 TTY)
STALE_PIDS=$(ps -eo pid,tty,etime,command | grep -E "\?\?.*claude" | grep -v grep | awk '{
  split($3, a, /[-:]/)
  if (length(a) == 4 && a[1] >= 1 && a[1] < 7) print $1
}')
STALE_COUNT=$(echo "$STALE_PIDS" | grep -c . 2>/dev/null || echo 0)

# 受保护进程统计
ACTIVE_COUNT=$(ps -eo tty,command | grep -E "ttys.*claude" | wc -l | tr -d ' ')
```

**步骤 2**: 使用 AskUserQuestion 工具询问用户

向用户展示以下信息并询问选择：

```
即将清理以下进程：

☠ 真正孤儿 (PPID=1):        X 个
📦 古老进程 (>7天):         Y 个
📦 陈旧进程 (1-7天):        Z 个

受保护（不会清理）:
✓ 活跃终端会话:             A 个
✓ 新进程 (<24h):            B 个

请选择清理范围:
```

**选项**：
1. `仅安全项` - 只清理 PPID=1 的真正孤儿
2. `安全 + 古老` - 清理孤儿和 >7 天的进程
3. `所有陈旧` - 清理孤儿和 >1 天的进程
4. `取消` - 不执行任何清理

---

## Phase 3: 执行清理

根据用户选择执行清理。**必须遵循安全机制**：

### 安全检查函数

```bash
# 检查进程是否可安全终止
is_safe_to_kill() {
  local pid=$1

  # 1. 进程必须存在
  if ! ps -p $pid > /dev/null 2>&1; then
    return 1
  fi

  # 2. 必须无 TTY
  local tty=$(ps -o tty= -p $pid 2>/dev/null | tr -d ' ')
  if [[ "$tty" != "??" ]]; then
    return 1
  fi

  # 3. 不能是当前 shell 的祖先
  local check_pid=$$
  while [[ $check_pid -gt 1 ]]; do
    if [[ "$check_pid" == "$pid" ]]; then
      return 1
    fi
    check_pid=$(ps -o ppid= -p $check_pid 2>/dev/null | tr -d ' ')
  done

  return 0
}
```

### 清理执行

```bash
clean_process() {
  local pid=$1

  # 预清理验证
  if ! is_safe_to_kill $pid; then
    echo "⏭ 跳过 PID $pid (安全检查未通过)"
    return 0
  fi

  # 发送 SIGTERM
  kill -15 $pid 2>/dev/null

  # 等待 2 秒
  sleep 2

  # 检查是否仍在运行
  if ps -p $pid > /dev/null 2>&1; then
    # 发送 SIGKILL
    kill -9 $pid 2>/dev/null
    sleep 1
  fi

  # 确认终止
  if ps -p $pid > /dev/null 2>&1; then
    echo "✗ PID $pid 清理失败"
    return 1
  else
    echo "✓ PID $pid 已清理"
    return 0
  fi
}
```

### 清理报告

```bash
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║             ccclean - 清理完成                     ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "清理结果:"
echo "  ✓ 成功清理:    $SUCCESS_COUNT 个进程"
echo "  ✗ 清理失败:    $FAIL_COUNT 个进程"
echo "  ⏭ 跳过:        $SKIP_COUNT 个进程"
echo ""
echo "释放内存: 约 ${FREED_MEM:-0} MB"
echo ""
```

---

## Dry-Run 模式

当用户运行 `/ccclean clean --dry-run` 时：

1. 执行所有扫描和分析步骤
2. 列出所有将被清理的进程
3. **不执行任何 kill 操作**
4. 输出预览报告

```bash
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║         ccclean - DRY RUN 预览                     ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "⚠ 这是预览模式，不会执行实际清理"
echo ""
echo "将要清理的进程:"
# 列出进程...
echo ""
echo "运行 \`/ccclean clean\` 执行实际清理"
```

---

## Safe 模式

当用户运行 `/ccclean clean --safe` 时：

1. **只清理** PPID=1 的真正孤儿进程
2. 跳过所有其他类型的进程
3. 仍需用户确认

---

## 注意事项

1. **永远不要自动清理进程** - 必须通过 AskUserQuestion 获得用户明确许可
2. **保护活跃会话** - 有 TTY 的进程绝不能被清理
3. **验证两次** - 在 kill 前重新验证进程状态
4. **优雅终止** - 先 SIGTERM，等待后才 SIGKILL
5. **详细日志** - 记录每个操作以便排查问题
