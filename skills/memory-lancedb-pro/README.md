# 🧠 Memory-LanceDB-Pro — 本地长期记忆 Skill

[![版本](https://img.shields.io/badge/版本-v2026.03.20-blue)]()
[![License](https://img.shields.io/badge/License-MIT-green)]()
[![OpenClaw](https://img.shields.io/badge/OpenClaw-Skill-orange)]()

> 基于 [memory-lancedb-pro](https://github.com/CortexReach/memory-lancedb-pro) 的全本地长期记忆解决方案。  
> 使用 Ollama 本地模型，零 API 费用，与 OpenClaw 内置记忆完全隔离。

---

## ✨ 特性

| 特性 | 说明 |
|------|------|
| 🏠 **全本地运行** | Ollama 嵌入（nomic-embed-text）+ LLM（qwen3:8b），零 API 费用 |
| 🔒 **与 OpenClaw 隔离** | 独立 `custom:long-term` 作用域 + 独立数据库路径 |
| 🔍 **混合检索** | 向量语义搜索 + BM25 关键词搜索，双引擎精准召回 |
| 🧬 **智能提取** | LLM 驱动的 6 类别记忆分类 + 两段去重 |
| ⏰ **生命周期管理** | Weibull 衰减模型，三层分级（Core/Working/Peripheral） |
| 📦 **每日 GitHub 备份** | 自动导出记忆并推送到 GitHub，增量提交 |
| ⚡ **快捷命令** | `/remember`、`/recall`、`/lesson`、`/memory-stats` 一键操作 |

---

## 🚀 快速开始

### 前置要求

- macOS / Linux
- Node.js ≥ 22.16
- OpenClaw 已安装
- Mac 内存 ≥ 16GB

### 一键安装

```bash
# 克隆 skill 到 OpenClaw skills 目录
git clone https://github.com/wansong24/ClawTeam-OpenClaw.git
cd ClawTeam-OpenClaw/skills/memory-lancedb-pro

# 运行安装脚本
bash scripts/setup.sh
```

安装脚本将自动完成：
1. ✅ 检测并安装 Ollama
2. ✅ 拉取嵌入模型 `nomic-embed-text`（274MB）
3. ✅ 拉取 LLM 模型 `qwen3:8b`（4.9GB）
4. ✅ 安装 memory-lancedb-pro 插件
5. ✅ 创建数据和备份目录

### 配置

安装完成后，将 `scripts/openclaw-config-template.json` 的内容合并到你的 `openclaw.json`：

```bash
# 查看配置模板
cat scripts/openclaw-config-template.json

# 验证并重启
openclaw config validate
openclaw gateway restart
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
```

### 手动存储/检索

```bash
# CLI 方式
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
```

### 恢复记忆

```bash
openclaw memory-pro import memories-20260320.json --scope custom:long-term
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
│   └── memories-YYYYMMDD.json
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

---

## 🔧 故障排除

| 问题 | 解决方案 |
|------|---------|
| Ollama 未运行 | `ollama serve &` |
| 嵌入失败 | `curl http://localhost:11434/v1/models` 检查模型 |
| 记忆未召回 | 确认 `autoRecall: true` 且 scope 正确 |
| 智能提取失败 | 检查 qwen3:8b 是否可用 |
| 备份推送失败 | 检查 GitHub SSH key 配置 |

---

## 📄 许可证

MIT

---

*版本: v2026.03.20 | 基于 [memory-lancedb-pro](https://github.com/CortexReach/memory-lancedb-pro) by CortexReach*
