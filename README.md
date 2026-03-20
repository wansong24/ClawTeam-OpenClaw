# ClawTeam-OpenClaw — 多 Agent 集群协调平台

<p align="center">
  <strong>🤖 你设定目标，Agent 集群自动完成剩下的一切</strong>
</p>

<p align="center">
  <a href="README_EN.md">English</a> | <strong>中文</strong>
</p>

---

## 📖 简介

**ClawTeam-OpenClaw** 是 [HKUDS/ClawTeam](https://github.com/HKUDS/ClawTeam) 的深度 OpenClaw 适配分支，专为多 Agent 集群协调而设计。本项目将 [OpenClaw](https://openclaw.ai) 设为默认 Agent 后端，实现了：

- 🔀 **Agent 自组织** — Leader 自动创建和管理 Worker Agent
- 🌿 **Git Worktree 隔离** — 每个 Agent 在独立分支工作，零合并冲突
- 📬 **文件系统消息传递** — Agent 间通过收件箱通信，无需额外服务
- 📊 **实时监控看板** — 终端 / Web 仪表板追踪团队进度
- 🔗 **任务依赖链** — 自动阻塞/解除阻塞，确保正确执行顺序

### ⚡ CT 快捷命令

本 fork 独创 **CT 快捷命令**，用户只需说：

```
CT 构建一个全栈 Web 应用
```

OpenClaw 即自动完成：团队创建 → 任务拆分 → Agent 生成 → 并行协作 → 主动交付结果。

---

## 🚀 安装

### 前提条件

| 依赖 | 要求 | 安装命令 |
|------|------|---------|
| Python | 3.10+ | `brew install python@3.12` |
| tmux | 任意版本 | `brew install tmux` |
| OpenClaw | 最新版 | `pip install openclaw` |
| Git | 任意版本 | 系统自带 |

### 安装步骤

```bash
# 1. 克隆仓库（不要用 pip install clawteam，那是上游版本）
git clone https://github.com/win4r/ClawTeam-OpenClaw.git
cd ClawTeam-OpenClaw
pip install -e .

# 2. 创建 ~/bin/clawteam 符号链接（确保生成的 Agent 能找到命令）
mkdir -p ~/bin
ln -sf "$(which clawteam)" ~/bin/clawteam
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc

# 3. 安装 OpenClaw Skill（教 OpenClaw 如何使用 ClawTeam）
mkdir -p ~/.openclaw/workspace/skills/clawteam
cp skills/openclaw/SKILL.md ~/.openclaw/workspace/skills/clawteam/SKILL.md

# 4. 验证安装
clawteam --version
clawteam config health
```

### 一键安装脚本

```bash
git clone https://github.com/win4r/ClawTeam-OpenClaw.git
cd ClawTeam-OpenClaw
bash scripts/install-openclaw.sh
```

---

## 📋 使用方法

### 方式一：CT 快捷命令（推荐）

安装 Skill 后，直接在 OpenClaw 中使用 CT 命令：

| 命令 | 效果 |
|------|------|
| `CT 构建一个全栈 Web 应用` | 创建 5 人团队并行开发 |
| `CT 用 8 个 agent 优化 train.py` | 启动 ML 研究集群 |
| `CT 审查这个 PR` | 启动代码审查团队 |
| `CT 分析 AAPL, MSFT, NVDA` | 启动对冲基金分析团队 |

### 方式二：模板一键启动

```bash
clawteam launch hedge-fund --team fund1 --goal "分析 2026 Q2 科技股"
clawteam launch code-review --team review1
clawteam launch research-paper --team paper1
```

### 方式三：手动组建

```bash
# 创建团队
clawteam team spawn-team dev-team -d "构建电商平台" -n leader

# 创建带依赖的任务
clawteam task create dev-team "设计 API 架构" -o architect
clawteam task create dev-team "实现后端" -o backend --blocked-by <api-task-id>
clawteam task create dev-team "构建前端" -o frontend --blocked-by <api-task-id>

# 生成 Agent
clawteam spawn -t dev-team -n architect --task "设计 RESTful API 架构"
clawteam spawn -t dev-team -n backend --task "实现用户认证和支付系统"
clawteam spawn -t dev-team -n frontend --task "构建 React 前端界面"

# 监控
clawteam board attach dev-team   # tmux 分屏视图
clawteam board serve --port 8080 # Web 仪表板
```

---

## 🏗️ 架构

```
用户: "CT 优化这个 LLM"
     │
     ▼
┌──────────────┐    clawteam spawn    ┌──────────────┐
│  Leader      │ ────────────────────► │  Worker      │
│  (OpenClaw)  │ ──┐                  │  git worktree│
│              │   │                  │  tmux window │
│  spawn       │   ├────────────────► ├──────────────┤
│  task create │   │                  │  Worker      │
│  inbox send  │   │                  │  git worktree│
│  board show  │   └────────────────► │  tmux window │
└──────────────┘                      └──────────────┘
                        │
                        ▼
              ┌─────────────────────┐
              │   ~/.clawteam/      │
              │   ├── teams/    (谁) │
              │   ├── tasks/    (做什么) │
              │   ├── inboxes/  (怎么沟通) │
              │   └── costs/    (花了多少) │
              └─────────────────────┘
```

**核心设计**：
- 所有状态存储为 `~/.clawteam/` 下的 JSON 文件，无需数据库
- 原子写入（tmp + rename）+ `fcntl` 文件锁确保并发安全
- 支持 P2P 传输（ZeroMQ），适用于跨机器协作

---

## 🎭 使用场景

### 1. 自主 ML 研究 — 8 Agent × 8 GPU

基于 [@karpathy/autoresearch](https://github.com/karpathy/autoresearch)，一条 prompt 启动 8 个研究 Agent：

```
CT 用 8 个 GPU 优化 train.py，阅读 program.md 获取指令
```

### 2. 敏捷软件工程

```
CT 构建一个带认证、数据库和 React 前端的全栈 Todo 应用
```

自动生成 5 Agent（架构师 + 2 后端 + 前端 + 测试），依赖链自动管理。

### 3. 对冲基金分析

```bash
clawteam launch hedge-fund --team fund1 --goal "分析 AAPL, MSFT, NVDA 2026 Q2 走势"
```

5 分析 Agent + 风险管理 + 投资组合决策。

---

## 📖 常用命令速查

| 类别 | 命令 | 说明 |
|------|------|------|
| 团队 | `clawteam team spawn-team <名> -d "<描述>" -n <leader>` | 创建团队 |
| 团队 | `clawteam team discover` | 列出所有团队 |
| 任务 | `clawteam task create <team> "<主题>" -o <负责人>` | 创建任务 |
| 任务 | `clawteam task list <team>` | 列出任务 |
| 任务 | `clawteam task update <team> <id> --status completed` | 完成任务 |
| 生成 | `clawteam spawn -t <team> -n <名> --task "<描述>"` | 生成 Agent |
| 消息 | `clawteam inbox send <team> <收件人> "<消息>"` | 发送消息 |
| 消息 | `clawteam inbox broadcast <team> "<消息>"` | 广播消息 |
| 监控 | `clawteam board show <team>` | 看板视图 |
| 监控 | `clawteam board attach <team>` | tmux 分屏 |
| 费用 | `clawteam cost show <team>` | 查看费用 |
| 模板 | `clawteam launch <模板> --team <名>` | 从模板启动 |
| 清理 | `clawteam team cleanup <team> --force` | 删除团队 |

---

## 🔧 常见问题

| 问题 | 解决方案 |
|------|---------|
| `clawteam: command not found` | `pip install -e .` 并创建符号链接: `ln -sf "$(which clawteam)" ~/bin/clawteam` |
| Agent 卡在权限提示 | 使用默认 `openclaw` 命令，运行 `clawteam config set skip_permissions true` |
| Agent 无法互相通信 | 检查 `~/.clawteam/` 目录权限，确保同一用户运行 |
| tmux 会话找不到 | `tmux ls` 查看现有会话，必要时重新生成 Agent |

---

## 📜 许可证

MIT — 自由使用、修改和分发。

---

## 🙏 致谢

- [HKUDS/ClawTeam](https://github.com/HKUDS/ClawTeam) — 上游项目
- [@karpathy/autoresearch](https://github.com/karpathy/autoresearch) — 自主 ML 研究框架
- [OpenClaw](https://openclaw.ai) — 默认 Agent 后端
- [ai-hedge-fund](https://github.com/virattt/ai-hedge-fund) — 对冲基金模板灵感

---

*版本: v2026.03.20 | [English](README_EN.md)*
