# claude-code-cleanup

[English](#english) | [中文](#中文)

---

## English

### Problem

Claude Code, Codex CLI, and OpenCode have a known memory leak issue. When you close a session, orphan processes may continue running in the background, consuming memory (60-170MB each). This can accumulate to 30GB+ over time.

**Related discussions:**
- Claude Code: [#4953](https://github.com/anthropics/claude-code/issues/4953), [#11377](https://github.com/anthropics/claude-code/issues/11377), [#18859](https://github.com/anthropics/claude-code/issues/18859), [#19433](https://github.com/anthropics/claude-code/issues/19433), [#20369](https://github.com/anthropics/claude-code/issues/20369)
- Codex CLI: [#7932](https://github.com/openai/codex/issues/7932), [#9345](https://github.com/openai/codex/issues/9345)

### Solution

This repository provides two tools to clean up orphan processes:

1. **`ccclean.sh`** - Standalone bash script with interactive UI
2. **`skill/SKILL.md`** - Claude Code agent skill for `/ccclean` command

### Features (v6)

- **Multi-tool support**: Claude Code, Codex CLI, OpenCode
- **MCP ecosystem cleanup**: Detect and clean orphan Playwright Chrome instances and MCP Node server processes (`npm exec @playwright/mcp`, `node playwright-mcp`, etc.)
- **Smart Chrome protection**: Shared MCP Chrome instance stays alive if any Claude Code session is still active
- **System health scan**: Report high-CPU (>50%) non-system processes running >10 minutes (report only, no auto-kill)
- **Orphan zsh detection**: Detects orphan zsh spawned by `tail` and `shell-snapshot`
- **Process type labels**: Shows `[claude]`, `[codex]`, `[opencode]`, `[tail]`, `[zsh]`, `[mcp-chrome]`, `[mcp-node]` for each process
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

- **Precise matching**: Only kills processes related to Claude/Codex/OpenCode and their MCP ecosystem
- **MCP Chrome shared instance protection**: Won't kill Chrome if any active session is connected
- **PID reuse protection**: Verifies process start time + args + PPID before killing
- **Runtime protection**: Skips processes running less than 5 minutes (configurable)
- **Double confirmation**: Requires user confirmation before cleanup
- **Graceful termination**: SIGTERM first, then SIGKILL
- **System health scan**: Reports anomalous high-CPU processes without auto-killing

### License

MIT

---

## 中文

### 问题

Claude Code、Codex CLI 和 OpenCode 存在已知的内存泄漏问题。当你关闭会话时，孤儿进程可能继续在后台运行，每个占用 60-170MB 内存。长期累积可能达到 30GB+。

**相关讨论：**
- Claude Code: [#4953](https://github.com/anthropics/claude-code/issues/4953), [#11377](https://github.com/anthropics/claude-code/issues/11377), [#18859](https://github.com/anthropics/claude-code/issues/18859), [#19433](https://github.com/anthropics/claude-code/issues/19433), [#20369](https://github.com/anthropics/claude-code/issues/20369)
- Codex CLI: [#7932](https://github.com/openai/codex/issues/7932), [#9345](https://github.com/openai/codex/issues/9345)

### 解决方案

本仓库提供两种工具来清理孤儿进程：

1. **`ccclean.sh`** - 独立的 bash 脚本，带交互式界面
2. **`skill/SKILL.md`** - Claude Code agent skill，支持 `/ccclean` 命令

### 功能特性 (v6)

- **多工具支持**：Claude Code、Codex CLI、OpenCode
- **MCP 生态清理**：检测并清理孤儿 Playwright Chrome 实例和 MCP Node 服务进程（`npm exec @playwright/mcp`、`node playwright-mcp` 等）
- **智能 Chrome 保护**：共享的 MCP Chrome 实例在有任何活跃 Claude Code 会话时不会被清理
- **系统健康扫描**：报告 CPU > 50% 且运行超过 10 分钟的非系统进程（仅报告，不自动清理）
- **孤儿 zsh 检测**：检测由 `tail` 和 `shell-snapshot` 产生的孤儿 zsh 进程
- **进程类型标识**：显示 `[claude]`、`[codex]`、`[opencode]`、`[tail]`、`[zsh]`、`[mcp-chrome]`、`[mcp-node]` 标签
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

- **精确匹配**：只清理 Claude/Codex/OpenCode 及其 MCP 生态相关进程
- **MCP Chrome 共享实例保护**：有活跃会话连接时不会清理 Chrome
- **PID 复用保护**：清理前验证进程启动时间 + 参数 + PPID
- **运行时长保护**：跳过运行少于 5 分钟的进程（可配置）
- **双重确认**：清理前需要用户确认
- **优雅终止**：先发送 SIGTERM，再发送 SIGKILL
- **系统健康扫描**：报告异常高 CPU 进程，不自动清理

### 许可证

MIT
