# claude-code-cleanup

[English](#english) | [中文](#中文)

---

## English

### Problem

Claude Code and Codex CLI have a known memory leak issue. When you close a session, orphan processes may continue running in the background, consuming memory (60-170MB each). This can accumulate to 30GB+ over time.

**Related GitHub Issues:**
- Claude Code: #19433, #20369, #11377, #4953, #18859
- Codex CLI: #7932, #9345

### Solution

This repository provides two tools to clean up orphan Claude processes:

1. **`ccclean.sh`** - Standalone bash script with interactive UI
2. **`skill/SKILL.md`** - Claude Code agent skill for `/ccclean` command

### Quick Start

#### Option 1: Bash Script

```bash
# Download
curl -O https://raw.githubusercontent.com/YuancFeng/claude-code-cleanup/main/ccclean.sh
chmod +x ccclean.sh

# Run
./ccclean.sh
```

#### Option 2: Shell Alias

Add to `~/.zshrc` or `~/.bashrc`:

```bash
alias claude-cleanup='ps aux | grep "[c]laude" | awk "\$7 == \"??\" {print \$2}" | xargs kill -9 2>/dev/null && echo "✅ Cleaned"'
```

#### Option 3: Claude Code Skill

Copy `skill/SKILL.md` to your Claude Code skills directory, then use `/ccclean` command.

### Safety Features

- **Precise matching**: Only kills processes named exactly `claude`
- **PID reuse protection**: Verifies process start time before killing
- **Runtime protection**: Skips processes running less than 5 minutes
- **Double confirmation**: Requires user confirmation before cleanup
- **Graceful termination**: SIGTERM first, then SIGKILL

### License

MIT

---

## 中文

### 问题

Claude Code 和 Codex CLI 存在已知的内存泄漏问题。当你关闭会话时，孤儿进程可能继续在后台运行，每个占用 60-170MB 内存。长期累积可能达到 30GB+。

**相关 GitHub Issues:**
- Claude Code: #19433, #20369, #11377, #4953, #18859
- Codex CLI: #7932, #9345

### 解决方案

本仓库提供两种工具来清理孤儿 Claude 进程：

1. **`ccclean.sh`** - 独立的 bash 脚本，带交互式界面
2. **`skill/SKILL.md`** - Claude Code agent skill，支持 `/ccclean` 命令

### 快速开始

#### 方案 1：Bash 脚本

```bash
# 下载
curl -O https://raw.githubusercontent.com/YuancFeng/claude-code-cleanup/main/ccclean.sh
chmod +x ccclean.sh

# 运行
./ccclean.sh
```

#### 方案 2：Shell 别名

添加到 `~/.zshrc` 或 `~/.bashrc`：

```bash
alias claude-cleanup='ps aux | grep "[c]laude" | awk "\$7 == \"??\" {print \$2}" | xargs kill -9 2>/dev/null && echo "✅ 已清理"'
```

#### 方案 3：Claude Code Skill

将 `skill/SKILL.md` 复制到你的 Claude Code skills 目录，然后使用 `/ccclean` 命令。

### 安全特性

- **精确匹配**：只清理进程名完全为 `claude` 的进程
- **PID 复用保护**：清理前验证进程启动时间
- **运行时长保护**：跳过运行少于 5 分钟的进程
- **双重确认**：清理前需要用户确认
- **优雅终止**：先发送 SIGTERM，再发送 SIGKILL

### 许可证

MIT
