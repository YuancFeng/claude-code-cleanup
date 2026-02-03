# claude-code-cleanup

[English](#english) | [中文](#中文)

---

## English

### Problem

Claude Code, Codex CLI, and OpenCode have a known memory leak issue. When you close a session, orphan processes may continue running in the background, consuming memory (60-170MB each). This can accumulate to 30GB+ over time.

**Related GitHub Issues:**
- Claude Code: #19433, #20369, #11377, #4953, #18859
- Codex CLI: #7932, #9345

### Solution

This repository provides two tools to clean up orphan processes:

1. **`ccclean.sh`** - Standalone bash script with interactive UI
2. **`skill/SKILL.md`** - Claude Code agent skill for `/ccclean` command

### Features (v5)

- **Multi-tool support**: Claude Code, Codex CLI, OpenCode
- **Orphan zsh detection**: Detects orphan zsh spawned by `tail` and `shell-snapshot`
- **Process type labels**: Shows `[CLAUDE]`, `[CODEX]`, `[OPENCODE]`, `[tail]`, `[zsh]` for each process
- **File cleanup**: Optional `--files` flag to clean up expired shell-snapshots and empty temp directories
- **POSIX compatible**: Works with macOS default bash 3.2

### Quick Start

#### Option 1: Bash Script

```bash
# Download
curl -O https://raw.githubusercontent.com/YuancFeng/claude-code-cleanup/main/ccclean.sh
chmod +x ccclean.sh

# Run (process cleanup only)
./ccclean.sh

# Run with file cleanup
./ccclean.sh --files
```

#### Option 2: Shell Alias

Add to `~/.zshrc` or `~/.bashrc`:

```bash
alias ccclean='curl -sL https://raw.githubusercontent.com/YuancFeng/claude-code-cleanup/main/ccclean.sh | bash'
```

#### Option 3: Claude Code Skill

Copy `skill/SKILL.md` to your Claude Code skills directory, then use `/ccclean` command.

### Command Line Options

| Option | Description |
|--------|-------------|
| (none) | Interactive process cleanup only |
| `--files` | Also clean up expired shell-snapshots (7+ days) and empty temp directories |

### Safety Features

- **Precise matching**: Only kills processes related to Claude/Codex/OpenCode
- **PID reuse protection**: Verifies process start time + args + PPID before killing
- **Runtime protection**: Skips processes running less than 5 minutes (configurable)
- **Double confirmation**: Requires user confirmation before cleanup
- **Graceful termination**: SIGTERM first, then SIGKILL

### License

MIT

---

## 中文

### 问题

Claude Code、Codex CLI 和 OpenCode 存在已知的内存泄漏问题。当你关闭会话时，孤儿进程可能继续在后台运行，每个占用 60-170MB 内存。长期累积可能达到 30GB+。

**相关 GitHub Issues:**
- Claude Code: #19433, #20369, #11377, #4953, #18859
- Codex CLI: #7932, #9345

### 解决方案

本仓库提供两种工具来清理孤儿进程：

1. **`ccclean.sh`** - 独立的 bash 脚本，带交互式界面
2. **`skill/SKILL.md`** - Claude Code agent skill，支持 `/ccclean` 命令

### 功能特性 (v5)

- **多工具支持**：Claude Code、Codex CLI、OpenCode
- **孤儿 zsh 检测**：检测由 `tail` 和 `shell-snapshot` 产生的孤儿 zsh 进程
- **进程类型标识**：显示 `[CLAUDE]`、`[CODEX]`、`[OPENCODE]`、`[tail]`、`[zsh]` 标签
- **文件清理**：可选 `--files` 参数清理过期的 shell-snapshots 和空临时目录
- **POSIX 兼容**：支持 macOS 默认 bash 3.2

### 快速开始

#### 方案 1：Bash 脚本

```bash
# 下载
curl -O https://raw.githubusercontent.com/YuancFeng/claude-code-cleanup/main/ccclean.sh
chmod +x ccclean.sh

# 运行（仅清理进程）
./ccclean.sh

# 运行并清理文件
./ccclean.sh --files
```

#### 方案 2：Shell 别名

添加到 `~/.zshrc` 或 `~/.bashrc`：

```bash
alias ccclean='curl -sL https://raw.githubusercontent.com/YuancFeng/claude-code-cleanup/main/ccclean.sh | bash'
```

#### 方案 3：Claude Code Skill

将 `skill/SKILL.md` 复制到你的 Claude Code skills 目录，然后使用 `/ccclean` 命令。

### 命令行参数

| 参数 | 说明 |
|------|------|
| (无) | 仅交互式清理进程 |
| `--files` | 同时清理过期的 shell-snapshots（7天以上）和空临时目录 |

### 安全特性

- **精确匹配**：只清理 Claude/Codex/OpenCode 相关进程
- **PID 复用保护**：清理前验证进程启动时间 + 参数 + PPID
- **运行时长保护**：跳过运行少于 5 分钟的进程（可配置）
- **双重确认**：清理前需要用户确认
- **优雅终止**：先发送 SIGTERM，再发送 SIGKILL

### 许可证

MIT
