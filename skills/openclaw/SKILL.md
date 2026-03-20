---
name: clawteam
description: "多 Agent 集群协调工具 / Multi-agent swarm coordination via ClawTeam CLI。当用户提到以下关键词时激活本技能：CT、团队、集群、swarm、多 agent、clawteam、并行 agent、组团、分工协作、team、spawn agents、parallel agents。快捷命令：用户说「CT + 任务描述」即可一键启动多 agent 协作（例如：CT 构建一个全栈应用）。ClawTeam 基于 git worktree 隔离 + tmux + 文件系统消息传递。OpenClaw 是默认 agent 后端。"
version: v2026.03.20
---

# ClawTeam — 多 Agent 集群协调 / Multi-Agent Swarm Coordination

## 概述 / Overview

ClawTeam 是一款 CLI 工具（`clawteam`），用于将多个 AI Agent 编排为自组织集群。每个 Agent 拥有独立的 git worktree 工作空间、tmux 窗口和消息收件箱。**OpenClaw 是默认 Agent 后端。**

**CLI 命令**: `clawteam`（通过 pip 安装，位于 PATH 中）

---

## ⚡ CT 快捷命令 / CT Quick Commands

**用户只需说 `CT` + 任务描述，即可一键启动多 Agent 协作。**

> CT 是 ClawTeam 的缩写。当你识别到用户消息以 `CT` 开头时，自动执行以下流程：
> 1. 分析任务需求 → 2. 创建团队 → 3. 拆分子任务 → 4. 生成 Agent → 5. 开始监控

### 快捷命令示例 / Examples

| 用户输入 | 自动执行的操作 |
|---------|-------------|
| `CT 构建一个全栈 Web 应用` | 创建 5 人团队（架构师 + 2 后端 + 前端 + 测试），拆分任务并行开发 |
| `CT 用 8 个 agent 优化 train.py` | 启动 8 Agent ML 研究集群，每个 Agent 探索不同方向 |
| `CT 审查这个 PR` | 启动代码审查团队（安全 + 性能 + 逻辑审查员） |
| `CT 分析 AAPL, MSFT, NVDA` | 启动对冲基金团队模板（5 分析师 + 风控 + 投资组合管理） |
| `CT 写一篇关于 LLM 的论文` | 启动研究论文团队模板 |

### CT 命令处理流程 / CT Command Flow

```
用户: "CT 构建一个电商平台"
     │
     ▼
┌─── 分析需求 ───────────────────────────────────────────┐
│ 1. 识别 CT 触发词                                       │
│ 2. 解析任务: 构建电商平台                                 │
│ 3. 规划：需要 API / 前端 / 数据库 / 支付 / 测试 5 个方向    │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌─── 自动执行 ───────────────────────────────────────────┐
│ clawteam team spawn-team ecommerce -d "构建电商平台" -n leader  │
│ clawteam task create ecommerce "设计 API 架构" -o architect     │
│ clawteam task create ecommerce "实现后端" -o backend ...        │
│ clawteam spawn -t ecommerce -n architect --task "..."          │
│ clawteam spawn -t ecommerce -n backend --task "..."            │
│ ... (自动为每个方向生成 Agent)                                   │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌─── 主动监控 & 汇报 ────────────────────────────────────┐
│ 自动启动后台监控循环                                      │
│ 进度 ~50% 时主动向用户汇报                                │
│ 全部完成后立即交付结果                                     │
└────────────────────────────────────────────────────────┘
```

---

## 🚀 快速开始 / Quick Start

### 方式一：模板一键启动（推荐）/ Template Launch

```bash
# 对冲基金团队 / Hedge fund team
clawteam launch hedge-fund --team fund1

# 代码审查团队 / Code review team
clawteam launch code-review --team review1

# 研究论文团队 / Research paper team
clawteam launch research-paper --team paper1
```

### 方式二：手动组建团队 / Manual Setup

```bash
# 1. 创建团队（指定 leader）
clawteam team spawn-team my-team -d "构建一个 Web 应用" -n leader

# 2. 创建任务（支持依赖链）
clawteam task create my-team "设计 API 架构" -o architect
# ↑ 返回任务 ID，例如 abc123

clawteam task create my-team "实现用户认证" -o backend --blocked-by abc123
clawteam task create my-team "构建前端界面" -o frontend --blocked-by abc123
clawteam task create my-team "编写集成测试" -o tester

# 3. 生成 Agent（每个 Agent 获得独立 tmux 窗口 + git worktree）
clawteam spawn -t my-team -n architect --task "设计 Web 应用的 REST API 架构"
clawteam spawn -t my-team -n backend --task "实现 OAuth2 用户认证系统"
clawteam spawn -t my-team -n frontend --task "构建 React 前端仪表板"

# 4. 监控进度
clawteam board show my-team        # 看板视图
clawteam board attach my-team      # tmux 分屏视图（所有 Agent 并排）
clawteam board serve --port 8080   # Web 仪表板
```

---

## 📋 命令参考 / Command Reference

### 团队管理 / Team Management

| 命令 Command | 说明 Description |
|-------------|-----------------|
| `clawteam team spawn-team <名称> -d "<描述>" -n <leader>` | 创建团队 Create team |
| `clawteam team discover` | 列出所有团队 List all teams |
| `clawteam team status <team>` | 查看团队状态和成员 Show members |
| `clawteam team cleanup <team> --force` | 删除团队及所有数据 Delete team |

### 任务管理 / Task Management

| 命令 Command | 说明 Description |
|-------------|-----------------|
| `clawteam task create <team> "<主题>" -o <负责人> [--blocked-by <id>]` | 创建任务 |
| `clawteam task list <team> [--owner <name>] [--status <状态>]` | 列出任务（可过滤） |
| `clawteam task update <team> <id> --status <状态>` | 更新任务状态 |
| `clawteam task get <team> <id>` | 查看单个任务详情 |
| `clawteam task stats <team>` | 查看任务时间统计 |
| `clawteam task wait <team> [--timeout <秒>]` | 阻塞等待所有任务完成 |

**任务状态 Task Statuses**: `pending`（待处理）→ `in_progress`（进行中）→ `completed`（已完成）| `blocked`（被阻塞）

**依赖自动解析**: 当阻塞任务完成时，依赖它的任务自动从 `blocked` 变为 `pending`。

**任务锁定**: 任务进入 `in_progress` 时会被当前 Agent 锁定。其他 Agent 无法认领，除非使用 `--force`。失效锁会自动释放。

### Agent 生成 / Agent Spawning

> [!IMPORTANT]
> **始终使用默认命令 (`openclaw`)** — 不要覆盖为 `claude` 或其他 Agent。默认配置正确处理了权限、prompt 注入和嵌套检测。如果指定 `claude`，Agent 会卡在交互式权限确认提示上。

```bash
# 默认（推荐）：在 tmux 中启动 openclaw tui
clawteam spawn -t <team> -n <名称> --task "<任务描述>"

# 显式指定后端（默认仍使用 openclaw）
clawteam spawn tmux -t <team> -n <名称> --task "<任务>"
clawteam spawn subprocess -t <team> -n <名称> --task "<任务>"

# 带 git worktree 隔离
clawteam spawn -t <team> -n <名称> --task "<任务>" --workspace --repo /path/to/repo
```

每个生成的 Agent 获得：
- 🖥️ 独立 tmux 窗口（通过 `board attach` 查看）
- 🌿 独立 git worktree 分支（`clawteam/{team}/{agent}`）
- 📋 自动注入的协调 prompt（包含 clawteam CLI 使用说明）
- 🔧 环境变量: `CLAWTEAM_AGENT_NAME`, `CLAWTEAM_TEAM_NAME` 等

**生成安全特性**:
- 启动前预验证命令 — 如果 Agent CLI 未安装会给出清晰错误
- 生成失败时自动回滚已注册的团队成员和 worktree
- Claude Code / Codex 的工作区信任提示会在新 worktree 中自动确认

### 消息通信 / Messaging

| 命令 Command | 说明 Description |
|-------------|-----------------|
| `clawteam inbox send <team> <收件人> "<消息>" --from <发件人>` | 点对点消息 |
| `clawteam inbox broadcast <team> "<消息>" --from <发件人>` | 广播给所有成员 |
| `clawteam inbox peek <team> -a <agent>` | 查看消息（不消费） |
| `clawteam inbox receive <team>` | 接收并消费消息 |
| `clawteam inbox log <team>` | 查看消息历史 |

> [!WARNING]
> `inbox receive` 会**消费**消息（删除文件）。如需非破坏性查看请用 `inbox peek`。

### 监控仪表板 / Monitoring

| 命令 Command | 说明 Description |
|-------------|-----------------|
| `clawteam board show <team>` | 看板视图（终端富文本） |
| `clawteam board overview` | 所有团队概览 |
| `clawteam board live <team> [--interval 3]` | 实时自动刷新看板 |
| `clawteam board attach <team>` | tmux 分屏视图 |
| `clawteam board serve --port 8080` | Web 仪表板 |

### 成本追踪 / Cost Tracking

| 命令 Command | 说明 Description |
|-------------|-----------------|
| `clawteam cost report <team> --input-tokens <N> --output-tokens <N> --cost-cents <N>` | 上报用量 |
| `clawteam cost show <team>` | 查看费用汇总 |
| `clawteam cost budget <team> <金额>` | 设置预算上限 |

### 模板 / Templates

| 命令 Command | 说明 Description |
|-------------|-----------------|
| `clawteam template list` | 列出可用模板 |
| `clawteam template show <名称>` | 查看模板详情 |
| `clawteam launch <模板> [--team-name <名称>] [--goal "<目标>"]` | 从模板启动 |

**内置模板 Built-in Templates**: `hedge-fund`（对冲基金）, `code-review`（代码审查）, `research-paper`（研究论文）, `strategy-room`（策略室）

### 配置 / Configuration

```bash
clawteam config show                           # 查看所有设置
clawteam config set transport file             # 设置传输后端
clawteam config set skip_permissions true      # 自动跳过权限提示
clawteam config health                         # 系统健康检查
```

### 其他命令 / Other Commands

| 命令 Command | 说明 Description |
|-------------|-----------------|
| `clawteam lifecycle idle <team> --agent <名称>` | 报告 Agent 空闲 |
| `clawteam session save <team> --session-id <id>` | 保存会话以供恢复 |
| `clawteam plan submit <team> "<计划>" --from <agent>` | 提交计划待审批 |
| `clawteam workspace list <team>` | 列出 git worktree |
| `clawteam workspace merge <team> --agent <名称>` | 合并 Agent 分支 |
| `clawteam workspace checkpoint <team> <agent>` | 自动提交检查点 |

---

## 📊 JSON 输出 / JSON Output

在任何子命令前添加 `--json` 获取机器可读输出：

```bash
clawteam --json task list my-team
clawteam --json team status my-team
clawteam --json board show my-team | jq '.taskSummary'
```

---

## 🔄 标准工作流 / Typical Workflow

1. **用户说** → `CT 构建一个 Web 应用` 或 "创建一个团队来构建 Web 应用"
2. **创建团队** → `clawteam team spawn-team webapp -d "构建 Web 应用" -n leader`
3. **创建任务** → 使用 `clawteam task create` + `--blocked-by` 建立依赖链
4. **生成 Agent** → 使用 `clawteam spawn` 为每个 Worker 生成独立 Agent
5. **立即监控** → 生成后**立即**启动后台监控循环，**不要**等用户主动询问
6. **主动通信** → 使用 `clawteam inbox broadcast` 发送团队级别更新
7. **主动交付** → 所有任务完成后**立即**将最终结果报告给用户
8. **清理收尾** → `clawteam cost show` → `clawteam task stats` → 合并 worktree → `clawteam team cleanup webapp --force`

---

## 🎯 Leader 编排模式 / Leader Orchestration Pattern

当 **你** 作为 Leader Agent 时，按以下模式自主管理集群：

### 阶段 1：分析 & 规划 / Analyze & Plan

```
1. 理解用户目标（如果是 CT 命令，从任务描述中提取）
2. 将任务拆分为独立子任务
3. 识别子任务间的依赖关系（什么必须先完成）
4. 决定需要多少个 Worker Agent
5. 为每个 Agent 编写清晰的任务指令
```

### 阶段 2：初始化 / Setup

```bash
# 创建团队
clawteam team spawn-team <team> -d "<目标描述>" -n leader

# 创建任务（带依赖链）
clawteam task create <team> "设计 API" -o architect
# 保存返回的任务 ID（如 abc123）
clawteam task create <team> "实现后端" -o backend --blocked-by abc123
clawteam task create <team> "构建前端" -o frontend --blocked-by abc123
clawteam task create <team> "集成测试" -o tester --blocked-by <backend-id>,<frontend-id>
```

### 阶段 3：生成 Worker / Spawn Workers

```bash
# 每个 spawn 在独立 tmux 窗口中启动一个 openclaw tui
clawteam spawn -t <team> -n architect --task "设计 <目标> 的 REST API 架构"
clawteam spawn -t <team> -n backend --task "基于 API 架构实现后端服务"
clawteam spawn -t <team> -n frontend --task "构建 React 前端界面"
clawteam spawn -t <team> -n tester --task "编写并运行集成测试"
```

### 阶段 4：监控循环 / Monitor Loop

> [!IMPORTANT]
> **生成 Agent 后立即启动监控** — 不要等用户询问进度。运行后台监控循环以便：
> 1. 在 ~50% 任务完成时**主动推送进度更新**
> 2. 所有任务完成后**立即交付最终结果**

```bash
# 每 30-60 秒轮询任务状态
while true; do
  clawteam --json task list <team> | python3 -c "
import sys, json
tasks = json.load(sys.stdin)
done = sum(1 for t in tasks if t['status'] == 'completed')
total = len(tasks)
blocked = sum(1 for t in tasks if t['status'] == 'blocked')
in_prog = sum(1 for t in tasks if t['status'] == 'in_progress')
print(f'进度: {done}/{total} 完成 | {in_prog} 进行中 | {blocked} 阻塞中')
if done == total: print('✅ 全部完成！'); sys.exit(0)
"
  # 检查 Worker 消息
  clawteam inbox receive <team>
  # 进度过半时主动汇报给用户
  sleep 30
done
```

### 阶段 5：收敛 & 交付 / Converge & Report

> [!IMPORTANT]
> 所有任务完成后**必须立即主动交付结果**，不要等用户询问。 报告中包含最终产出、摘要和费用/时间统计。**必须**合并 worktree 并清理。

```bash
# 全部完成后 — 依次执行以下所有步骤：
clawteam board show <team>           # 最终状态
clawteam cost show <team>            # 总费用 — 写入报告
clawteam task stats <team>           # 时间统计 — 写入报告

# 合并每个 Worker 的分支到 main
for agent in <agent1> <agent2> ...; do
  clawteam workspace merge <team> --agent $agent
done

clawteam team cleanup <team> --force  # 清理 — 最后执行
# 然后：立即向用户发送最终交付物
```

---

## 🧠 Leader 决策规则 / Decision Rules

| 场景 Scenario | 行动 Action |
|--------------|------------|
| 独立任务 Independent tasks | 并行生成 Workers |
| 顺序任务 Sequential tasks | 用 `--blocked-by` 链接，ClawTeam 自动解除阻塞 |
| Worker 求助 Worker asks for help | 检查 inbox，通过 `inbox send` 提供指导 |
| Worker 卡住 Worker stuck | 检查任务状态；`in_progress` 过久则通过 `inbox send` 催促 |
| Worker 完成 Worker done | 通过 inbox 消息验证结果，然后进入下一阶段 |
| 全部完成 All done | 合并 worktree → 主动交付结果 → 清理 |
| 始终 Always | 生成后**立即**启动后台监控，**绝不**等用户询问状态 |

---

## 🔧 故障排除 / Troubleshooting

| 问题 Problem | 解决方案 Solution |
|-------------|-----------------|
| `clawteam: command not found` | 运行 `pip install -e .` 重新安装，或创建符号链接: `ln -sf "$(which clawteam)" ~/bin/clawteam` |
| Agent 卡在权限提示 Stuck on permission prompt | 确保使用默认 `openclaw` 命令，不要指定 `claude`。运行 `clawteam config set skip_permissions true` |
| Agent 无法互相通信 Agents can't communicate | 检查 `~/.clawteam/` 目录权限。所有 Agent 必须运行在同一用户下 |
| tmux 会话找不到 tmux session not found | 运行 `tmux ls` 查看现有会话。重新生成 Agent: `clawteam spawn ...` |
| Git worktree 冲突 Worktree conflict | 运行 `clawteam workspace cleanup <team> <agent>` 清理后重新生成 |
| 任务一直处于 blocked 状态 | 检查 `--blocked-by` 依赖的任务是否已完成。用 `clawteam task list <team>` 排查 |
| 预算超支 Budget exceeded | 用 `clawteam cost show <team>` 检查费用，用 `clawteam cost budget <team> <金额>` 设置上限 |

---

## 📁 数据存储位置 / Data Location

所有状态存储在 `~/.clawteam/`：

```
~/.clawteam/
├── teams/<team>/config.json         # 团队配置
├── tasks/<team>/task-<id>.json      # 任务数据（fcntl 文件锁保证并发安全）
├── plans/<team>/<agent>-<id>.md     # 计划文件（按团队隔离）
├── teams/<team>/inboxes/<agent>/    # Agent 收件箱
│   └── msg-*.json                   # 消息文件
└── costs/<team>/                    # 费用数据
```

可通过环境变量 `CLAWTEAM_DATA_DIR` 自定义数据目录（默认 `~/.clawteam`）。

---

## 📌 注意事项 / Important Notes

- `inbox receive` **消费**消息（删除文件）。非破坏性查看用 `inbox peek`
- 所有文件写入使用原子操作（tmp + rename）防止数据损坏
- 团队状态持久化为 JSON 文件，无需数据库或后台服务
- 跨机器协作可通过 NFS/SSHFS 共享 `~/.clawteam/` 目录，或使用 P2P 传输（ZeroMQ）
- 已生成的 Agent 的身份环境变量由 `clawteam spawn` 自动设置，无需手动配置

---

*版本 Version: v2026.03.20 | 适配 OpenClaw 默认后端 | CT 快捷命令支持*
