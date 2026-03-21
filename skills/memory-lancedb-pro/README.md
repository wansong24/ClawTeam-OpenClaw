# 🧠 Memory-LanceDB-Pro — 本地长期记忆 Skill

[![版本](https://img.shields.io/badge/版本-v2026.03.21-blue)]()
[![License](https://img.shields.io/badge/License-MIT-green)]()
[![OpenClaw](https://img.shields.io/badge/OpenClaw-Skill-orange)]()
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-Optimized-purple)]()

> 基于 [memory-lancedb-pro](https://github.com/CortexReach/memory-lancedb-pro) 的全本地长期记忆解决方案。  
> 使用 [oMLX](https://github.com/jundot/omlx) Apple Silicon 专属推理服务器，零 API 费用，与 OpenClaw 内置记忆完全隔离。

---

## 💡 有了记忆，AI 不再是金鱼

**没有记忆** — 每次对话从零开始：
```
你: "用 Tab 缩进，必须加错误处理"
（下一次会话）
你: "我说过了——Tab 不是空格！" 😤
（再下一次）
你: "……Tab，错误处理，再说一遍。"
```

**有了记忆** — AI 自动记住你的偏好、决策和上下文：
```
你: "用 Tab 缩进，必须加错误处理"
（下一次会话 — Agent 自动回忆你的偏好）
Agent: （默默应用 Tab + 错误处理）✅
你: "上个月我们为什么选 PostgreSQL 而不是 MongoDB？"
Agent: "根据 2 月 12 日的讨论，主要原因是……" ✅
```

---

## ✨ 特性

| 特性 | 说明 |
|------|------|
| 🍎 **Apple Silicon 优化** | oMLX 推理服务器，分层 KV 缓存，连续批处理 |
| 🔒 **与 OpenClaw 隔离** | 独立 `custom:long-term` 作用域 + 独立数据库路径 |
| 🔍 **混合检索 + 本地 Reranking** | 向量(bge-m3) + BM25 + 本地 cross-encoder 重排序 |
| 🧬 **智能提取** | LLM 驱动的 6 类别记忆分类 + 两段去重 |
| ⏰ **生命周期管理** | Weibull 衰减模型，三层分级（Core/Working/Peripheral） |
| 🔄 **自改进治理** | LEARNINGS.md / ERRORS.md 追踪 + 技能提取 |
| 📦 **每日 GitHub 备份** | 自动导出 + 增量提交 + 备份元数据 |
| ⚡ **快捷命令** | `/remember`、`/recall`、`/lesson`、`/self-review` 等一键操作 |
| 🧠 **9 MCP 工具** | 4 核心 + 2 管理 + 3 自改进，完整覆盖 |

---

## 🏗️ 架构

```
┌──────────────────────────────────────────────────────┐
│              memory-lancedb-pro 插件                   │
│    Plugin Registration · Config · Lifecycle Hooks     │
└──────┬──────────┬──────────┬──────────┬───────────────┘
       │          │          │          │
  ┌────▼───┐ ┌────▼───┐ ┌───▼────┐ ┌──▼──────────┐
  │ store  │ │embedder│ │retriever│ │   scopes    │
  │  .ts   │ │  .ts   │ │  .ts   │ │    .ts      │
  └────────┘ └────────┘ └────────┘ └─────────────┘
                │              │
           ┌────▼───┐    ┌─────▼──────────┐
           │migrate │    │noise-filter.ts │
           │  .ts   │    │adaptive-       │
           └────────┘    │retrieval.ts    │
                         └────────────────┘
  ┌─────────────┐  ┌──────────┐  ┌──────────────────┐
  │  tools.ts   │  │  cli.ts  │  │smart-extractor.ts│
  │ (9 MCP 工具) │  │  (CLI)   │  │decay-engine.ts   │
  └─────────────┘  └──────────┘  │tier-manager.ts   │
                                 └──────────────────┘
       ↕                    ↕
  ┌─────────┐         ┌──────────┐
  │  oMLX   │         │ LanceDB  │
  │  :8000  │         │ (本地DB) │
  └─────────┘         └──────────┘
```

---

## 🚀 快速开始

### 前置要求

- macOS + **Apple Silicon**（M1/M2/M3/M4）
- [oMLX](https://github.com/jundot/omlx) 已安装（`http://localhost:8000`）
- Node.js ≥ 22.16
- OpenClaw 已安装

### 一键安装

```bash
# 克隆 skill 到 OpenClaw skills 目录
git clone https://github.com/wansong24/ClawTeam-OpenClaw.git
cd ClawTeam-OpenClaw/skills/memory-lancedb-pro

# 运行安装脚本（自动检测 oMLX/Ollama）
bash scripts/setup.sh
```

安装脚本将自动完成：
1. ✅ 检测 oMLX 服务（优先）或 Ollama（备用）
2. ✅ 检查嵌入模型（bge-m3）和 LLM 模型可用性
3. ✅ 安装 memory-lancedb-pro 插件
4. ✅ 自动合并配置到 openclaw.json（备份原配置）
5. ✅ 安装 Skill 文件到 OpenClaw skills 目录
6. ✅ 创建数据和备份目录

### 配置

安装完成后，验证并重启：

```bash
openclaw config validate
openclaw gateway restart

# 验证插件已加载
openclaw plugins info memory-lancedb-pro
openclaw memory-pro stats
```

---

## 📋 使用方法

### 快捷命令

```
/remember 我偏好使用 TypeScript + React 技术栈
/recall 技术栈偏好
/lesson macOS 上 sed -i 需要加 '' 参数
/memory-stats
/memory-backup
/memory-list preference
/memory-forget <id>
/self-review
```

### CLI 操作

```bash
openclaw memory-pro search "技术栈" --scope custom:long-term
openclaw memory-pro list --scope custom:long-term --category preference
openclaw memory-pro stats --scope custom:long-term
```

---

## 📦 每日 GitHub 备份

```bash
# 初始化备份仓库
bash scripts/backup-to-github.sh --init-repo

# 手动备份
bash scripts/backup-to-github.sh

# 设置每日自动备份（凌晨 2:00）
bash scripts/backup-to-github.sh --install-schedule

# 查看备份状态
bash scripts/backup-to-github.sh --status
```

### 恢复记忆

```bash
openclaw memory-pro import memories-20260321.json --scope custom:long-term
```

---

## 📁 目录结构

```
skills/memory-lancedb-pro/
├── SKILL.md                           # 主 Skill 文件（中文）
├── README.md                          # 本文件
├── references/
│   └── full-reference.md              # 深度技术参考（按需加载）
└── scripts/
    ├── setup.sh                       # 一键安装脚本
    ├── backup-to-github.sh            # GitHub 每日备份脚本
    └── openclaw-config-template.json  # OpenClaw 配置模板
```

### 数据存储

```
~/.openclaw/memory/
├── lancedb-longterm/     # 长期记忆 LanceDB 数据库
├── backups/              # 本地备份文件
│   ├── memories-YYYYMMDD.json
│   └── metadata-YYYYMMDD.json
└── backup-repo/          # GitHub 备份仓库克隆
```

---

## 🔒 与 OpenClaw 内置记忆的隔离

| 维度 | OpenClaw 内置 | 本 Skill |
|------|-------------|---------|
| 作用域 | `global` | `custom:long-term` |
| 数据库 | `~/.openclaw/memory/lancedb` | `~/.openclaw/memory/lancedb-longterm` |
| 自动捕获 | ✅ | ❌（手动触发） |
| 会话记忆 | 根据配置 | ❌ 禁用 |
| Reranking | 需 API | ✅ 本地（oMLX） |

---

## 🔧 故障排除

| 问题 | 解决方案 |
|------|---------|
| oMLX 未运行 | 从菜单栏启动，或 `omlx serve --model-dir ~/models` |
| 嵌入失败 | `curl http://localhost:8000/v1/models` 检查 bge-m3 |
| 记忆未召回 | 确认 `autoRecall: true` 且 scope 正确 |
| 智能提取失败 | 检查 LLM 模型是否已加载 |
| 备份推送失败 | 检查 GitHub SSH key 配置 |
| 需回退到 Ollama | 安装 Ollama 后改 `baseURL` 为 `http://localhost:11434/v1` |

---

## 📄 许可证

MIT

---

*版本: v2026.03.21 | 基于 [memory-lancedb-pro](https://github.com/CortexReach/memory-lancedb-pro) by CortexReach | [oMLX](https://github.com/jundot/omlx) Apple Silicon 优化*
