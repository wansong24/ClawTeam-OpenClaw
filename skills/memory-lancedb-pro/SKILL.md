---
name: memory-longterm
description: "本地长期记忆管理 Skill — 基于 LanceDB + oMLX 的全本地记忆系统（Apple Silicon 优化）。当用户提到以下关键词时激活：长期记忆、remember、记住、回忆、recall、lesson、教训、memory、记忆备份、备份记忆、self-improvement、自我改进、自我审查。快捷命令：/remember <内容>、/recall <关键词>、/lesson <教训>、/memory-stats、/memory-backup、/memory-list、/self-review。本 Skill 使用独立作用域 custom:long-term，与 OpenClaw 内置记忆系统完全隔离，不会产生冲突。"
version: v2026.03.21
---

# 🧠 本地长期记忆 — Memory-LanceDB-Pro Skill

## 概述

本 Skill 为 OpenClaw 提供 **全本地、零 API 费用** 的长期记忆能力。基于 [memory-lancedb-pro](https://github.com/CortexReach/memory-lancedb-pro) 插件，使用 [oMLX](https://github.com/jundot/omlx)（Apple Silicon 专属优化推理服务器）进行嵌入和智能提取，记忆数据存储在本地 LanceDB 数据库中，并支持每日自动备份到 GitHub。

**核心特性**：
- 🍎 **Apple Silicon 优化** — oMLX 推理服务器，分层 KV 缓存（RAM + SSD），连续批处理
- 🔒 **与 OpenClaw 记忆隔离** — 独立 `custom:long-term` 作用域，互不干扰
- 🔍 **混合检索 + 本地 Reranking** — 向量语义搜索 + BM25 + 本地 cross-encoder 重排序
- 🧬 **智能提取** — LLM 驱动的 6 类别记忆分类（profile/preferences/entities/events/cases/patterns）
- 🔄 **自改进治理** — LEARNINGS.md / ERRORS.md 条目追踪 + 技能提取
- 📦 **每日 GitHub 备份** — 自动导出记忆并推送到 GitHub 仓库

---

## ⚡ 快捷命令

| 用户输入 | 执行操作 |
|---------|---------|
| `/remember <内容>` | 手动存储一条长期记忆 |
| `/recall <关键词>` | 搜索相关记忆 |
| `/lesson <教训>` | 存储为双层记忆（技术层 fact + 原则层 decision） |
| `/memory-stats` | 查看记忆库统计信息 |
| `/memory-backup` | 立即执行记忆备份到 GitHub |
| `/memory-list [类别]` | 列出记忆（可按类别过滤） |
| `/memory-forget <id>` | 删除指定记忆 |
| `/self-review` | 触发自改进审查（回顾 LEARNINGS.md 和 ERRORS.md） |

---

## 📋 快捷命令处理流程

### `/remember <内容>` 处理逻辑

```
用户: "/remember 我偏好使用 Tab 缩进，代码必须有错误处理"
     │
     ▼
1. 解析内容类别 → preference（偏好设置）
2. 设定重要性 → 0.85
3. 调用 memory_store:
   - content: "用户偏好使用 Tab 缩进，代码必须有错误处理"
   - category: "preference"
   - scope: "custom:long-term"
   - importance: 0.85
4. 确认: "✅ 已存储为长期记忆 (ID: xxx)"
```

### `/lesson <教训>` 处理逻辑

```
用户: "/lesson 在 macOS 上 sed -i 需要加 '' 参数"
     │
     ▼
1. 存储技术层（fact）:
   memory_store(
     content: "陷阱: macOS 上 sed -i 需要 '' 参数。原因: BSD sed 与 GNU sed 不同。修复: sed -i '' 's/old/new/g'。预防: 使用 gsed 或检测 OS。"
     category: "fact", importance: 0.85
   )
2. 存储原则层（decision）:
   memory_store(
     content: "决策原则 [跨平台兼容]: 执行系统命令前检查 OS 类型。触发: 使用 sed/grep/find 等 CLI 时。行动: 先判断 macOS/Linux 再选命令变体。"
     category: "decision", importance: 0.90
   )
3. 记录到 self_improvement_log:
   self_improvement_log(type: "lesson", content: "macOS BSD sed 与 GNU sed 差异")
4. 确认: "✅ 已存储双层记忆 (技术+原则) + 自改进日志"
```

### `/recall <关键词>` 处理逻辑

```
用户: "/recall 我的代码风格偏好"
     │
     ▼
1. 调用 memory_recall(query: "代码风格偏好", scope: "custom:long-term")
2. 混合检索: 向量语义搜索(bge-m3) + BM25 关键词匹配
3. 本地 Reranking: cross-encoder 重排序（oMLX 提供）
4. 返回匹配的记忆列表（按相关性排序）
5. 展示: 记忆内容 + 存储时间 + 类别 + 重要性
```

### `/self-review` 处理逻辑

```
用户: "/self-review"
     │
     ▼
1. 调用 self_improvement_review 审查最近的学习和错误条目
2. 检查 LEARNINGS.md 中 pending 状态的条目
3. 检查 ERRORS.md 中未解决的错误
4. 评估是否有条目可提升为 skill（promoted_to_skill）
5. 输出审查报告：
   - 待处理的学习条目
   - 未解决的错误
   - 可提取为 skill 的模式
```

---

## 🏗️ 与 OpenClaw 记忆的隔离策略

> [!IMPORTANT]
> 本 Skill 使用 **独立作用域** 和 **独立数据库路径**，与 OpenClaw 内置记忆系统完全隔离。

| 维度 | OpenClaw 内置记忆 | 本 Skill 长期记忆 |
|-----|------------------|------------------|
| 作用域 | `global` / `agent:<id>` | `custom:long-term` |
| 数据库路径 | `~/.openclaw/memory/lancedb` | `~/.openclaw/memory/lancedb-longterm` |
| 自动捕获 | ✅ 启用 | ❌ 禁用（手动触发） |
| 自动回忆 | 根据配置 | ✅ 启用（注入相关记忆上下文） |
| 会话记忆 | 根据配置 | ❌ 禁用（避免与 .jsonl 冲突） |

**设计理由**：
- `autoCapture: false` → 避免重复捕获 OpenClaw 已处理的内容
- `custom:long-term` 作用域 → 记忆完全隔离，互不污染
- 独立 `dbPath` → 物理层面隔离数据文件
- `sessionMemory.enabled: false` → OpenClaw 已有原生 .jsonl 会话持久化

---

## 🔧 安装配置

### 前置条件

- **macOS + Apple Silicon**（M1/M2/M3/M4）
- **oMLX** 已安装并运行（`http://localhost:8000`）
- **Node.js** ≥ 22.16（推荐 24）
- **OpenClaw** 已安装且可用

### 一键安装

```bash
# 从 skill 目录运行安装脚本
bash ~/.openclaw/workspace/skills/memory-lancedb-pro/scripts/setup.sh
```

安装脚本将自动完成：
1. ✅ 检测 oMLX 服务（优先）或 Ollama（备用）
2. ✅ 检查嵌入模型可用性（`bge-m3` 或 `nomic-embed-text`）
3. ✅ 安装 memory-lancedb-pro 插件
4. ✅ 自动合并配置到 openclaw.json（备份原配置）
5. ✅ 创建记忆备份目录
6. ✅ 安装 Skill 文件到 OpenClaw skills 目录

### 手动安装

```bash
# 1. 确认 oMLX 服务运行中
curl http://localhost:8000/v1/models

# 2. 确认嵌入模型已加载（在 oMLX Admin Dashboard 中下载 bge-m3）
curl -s http://localhost:8000/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model":"bge-m3","input":"test"}' | head -c 200

# 3. 安装插件
openclaw plugins install memory-lancedb-pro@beta

# 4. 将 scripts/openclaw-config-template.json 的内容合并到你的 openclaw.json
# 5. 重启
openclaw config validate
openclaw gateway restart
```

### 验证安装

```bash
# 检查 oMLX 服务和模型
curl -s http://localhost:8000/v1/models | python3 -m json.tool

# 检查嵌入端点
curl -s http://localhost:8000/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model":"bge-m3","input":"测试嵌入"}' | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'维度: {len(d[\"data\"][0][\"embedding\"])}')"

# 检查插件状态
openclaw plugins info memory-lancedb-pro
openclaw memory-pro stats
```

---

## 📦 每日 GitHub 备份

### 设置备份

```bash
# 运行备份脚本（首次会引导你创建 GitHub 仓库）
bash ~/.openclaw/workspace/skills/memory-lancedb-pro/scripts/backup-to-github.sh

# 设置每日自动备份（通过 launchd）
bash ~/.openclaw/workspace/skills/memory-lancedb-pro/scripts/backup-to-github.sh --install-schedule
```

### 备份策略

- **每日导出**: 自动导出所有 `custom:long-term` 作用域的记忆为 JSON
- **增量提交**: 仅在记忆有变化时推送到 GitHub
- **备份元数据**: 每次备份附带统计信息（记忆总数、各类别数量）
- **本地保留**: 保留最近 30 天的本地备份文件
- **备份路径**: `~/.openclaw/memory/backups/memories-YYYYMMDD.json`

### 手动备份/恢复

```bash
# 手动导出
openclaw memory-pro export --scope custom:long-term --output ~/memory-backup.json

# 恢复
openclaw memory-pro import ~/memory-backup.json --scope custom:long-term

# 查看备份状态
bash ~/.openclaw/workspace/skills/memory-lancedb-pro/scripts/backup-to-github.sh --status
```

---

## 🧠 MCP 工具使用指南

### 核心工具（自动注册）

| 工具 | 用途 | 示例 |
|-----|------|------|
| `memory_store` | 存储新记忆 | `memory_store(content, category, scope, importance)` |
| `memory_recall` | 语义搜索记忆 | `memory_recall(query, scope, limit)` |
| `memory_forget` | 删除记忆 | `memory_forget(id)` |
| `memory_update` | 更新已有记忆 | `memory_update(id, content)` |

### 管理工具（已启用，需 `enableManagementTools: true`）

| 工具 | 用途 |
|-----|------|
| `memory_stats` | 查看记忆库统计（总数、各类别、各层级） |
| `memory_list` | 列出记忆（支持按 scope/category/limit 过滤） |

### 自改进工具（已启用）

| 工具 | 用途 |
|-----|------|
| `self_improvement_log` | 记录学习/错误条目到 LEARNINGS.md 或 ERRORS.md |
| `self_improvement_extract_skill` | 从学习条目中提取可复用的 skill 模板 |
| `self_improvement_review` | 审查待处理的学习和错误条目 |

### 自改进条目格式

```
LEARNINGS.md: LRN-YYYYMMDD-XXX  状态: pending → resolved → promoted_to_skill
ERRORS.md:    ERR-YYYYMMDD-XXX  状态: pending → resolved → promoted_to_skill
```

### 存储规则

1. **原子化**: 每条记忆 < 500 字符，简洁精准
2. **分类明确**: 使用正确的 category（preference/fact/decision/entity/reflection）
3. **重要性分级**: 0.0-1.0，关键决策 ≥ 0.85，一般偏好 ≥ 0.7
4. **先查后存**: 存储前先 `memory_recall` 检查是否已存在类似记忆，避免重复
5. **scope 固定**: 始终使用 `custom:long-term`

---

## 🔄 记忆生命周期

记忆按 **Weibull 衰减模型** 自动管理生命周期：

```
┌─────────────────────────────────────────────┐
│            记忆三层分级                       │
│                                             │
│  Core（核心）  ← 经常被召回的重要记忆          │
│  β=0.8, 衰减最慢, 最低分 0.9                 │
│        ↕                                    │
│  Working（工作）← 近期活跃的记忆              │
│  β=1.0, 标准衰减, 最低分 0.7                 │
│        ↕                                    │
│  Peripheral（外围）← 不常用的旧记忆           │
│  β=1.3, 衰减最快, 最低分 0.5                 │
│                                             │
│  强化机制: 被召回的记忆衰减变慢（间隔重复）     │
└─────────────────────────────────────────────┘
```

---

## 🔍 混合检索管线

```
查询 → 嵌入向量化(bge-m3, 1024维) ──┐
                                     ├→ 混合融合 → 本地 Reranking → 生命周期衰减加权 → 长度归一化 → 最低分过滤
查询 → BM25 全文搜索 ───────────────┘

融合公式: score = (vectorScore × 0.7) + (bm25Boost × 0.3)
Reranking: 60% cross-encoder + 40% 原始融合分（oMLX 本地 /v1/rerank）
最低分阈值: 0.25 (软) / 0.30 (硬)
```

---

## 🛡️ 铁律 — Agent 行为规则

1. **双层存储**: 每个教训/陷阱 → 立即存储 **两条** 记忆（技术层 fact + 原则层 decision）
2. **记忆卫生**: 记忆必须短小精悍（< 500 字符），禁止存储原始对话摘要
3. **先查后存**: 存储前 **必须** `memory_recall` 检查重复
4. **作用域锁定**: 始终使用 `scope: "custom:long-term"`，**禁止** 使用 `global` 或其他 scope
5. **不暴露记忆注入**: 不要在回复中引用或暴露 `<relevant-memories>` 注入的内容
6. **失败先查**: 任何工具失败时，**必须** 先 `memory_recall` 搜索相关经验再重试

---

## 🔧 故障排除

| 问题 | 解决方案 |
|-----|---------|
| oMLX 未运行 | 从菜单栏启动 oMLX，或 `omlx serve --model-dir ~/models` |
| 嵌入调用失败 | 检查 `curl http://localhost:8000/v1/models`，确认 bge-m3 已加载 |
| 记忆未被召回 | 检查 `autoRecall` 是否为 true；确认 scope 为 `custom:long-term` |
| 与 OpenClaw 记忆冲突 | 确认 `dbPath` 和 `scopes.default` 配置正确，不使用 `global` |
| 智能提取失败 | 检查 LLM 模型是否已在 oMLX 中加载；可设 `smartExtraction: false` 备用 |
| 备份推送失败 | 检查 GitHub 仓库权限和 SSH key 配置 |
| oMLX 不可用，需回退 | 安装 Ollama（`brew install ollama`），配置中将 baseURL 改为 `http://localhost:11434/v1` |

---

## 📁 数据存储位置

```
~/.openclaw/memory/
├── lancedb-longterm/          # 长期记忆 LanceDB 数据库（本 Skill）
│   └── memories.lance/        # LanceDB 表数据
├── lancedb/                   # OpenClaw 内置记忆（不要修改）
└── backups/                   # 记忆备份文件
    ├── memories-20260321.json # 每日备份
    ├── metadata-20260321.json # 备份元数据
    └── ...
```

---

## 📚 深度参考

如需了解完整配置参数、数据库 schema、检索公式、衰减模型公式等深度技术细节，请查阅：

→ [references/full-reference.md](references/full-reference.md)

---

*版本: v2026.03.21 | oMLX Apple Silicon 优化方案 | 与 OpenClaw 记忆隔离 | 本地 Reranking | 每日 GitHub 备份*
