# 🧠 Memory-LanceDB-Pro 深度技术参考

> 本文档按需加载，包含完整的技术细节。日常使用请参考 SKILL.md。

---

## 数据库 Schema

LanceDB 表名: `memories`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 唯一标识符 (UUID) |
| `text` | string | 记忆内容文本 |
| `vector` | float[] | 嵌入向量 (nomic-embed-text: 768 维) |
| `category` | string | 存储类别: preference / fact / decision / entity / reflection / other |
| `scope` | string | 作用域: `custom:long-term` |
| `importance` | float | 重要性 0.0-1.0 |
| `timestamp` | string | ISO 8601 创建时间 |
| `metadata` | object | 扩展元数据 |

### metadata 常用键 (v1.1.0)

| 键 | 说明 |
|----|------|
| `l0_abstract` | L0 层：一句话索引摘要 |
| `l1_overview` | L1 层：结构化概要 |
| `l2_content` | L2 层：完整叙述内容 |
| `memory_category` | 语义类别: profile / preferences / entities / events / cases / patterns |
| `tier` | 生命周期层级: core / working / peripheral |
| `access_count` | 被召回次数 |
| `confidence` | LLM 提取置信度 0.0-1.0 |
| `last_accessed_at` | 最后被召回的时间 |

---

## 混合检索管线完整公式

### 1. 向量搜索
```
vectorScore = cosine_similarity(query_vector, memory_vector)
```

### 2. BM25 全文搜索
```
bm25Score = LanceDB FTS index score (已归一化)
```

### 3. 混合融合
```
fusedScore = vectorScore  （基础分）
if bm25Hit:
    fusedScore += bm25Weight × bm25Score  （BM25 加权提升）

默认: vectorWeight=0.7, bm25Weight=0.3
```

> 注意: 不是标准 RRF，而是以向量分为基础、BM25 命中给予加权提升。

### 4. 生命周期衰减加权
```
decayBoost = recency × 0.4 + frequency × 0.3 + intrinsic × 0.3

recency = exp(-lambda × (daysSince / halfLife)^beta)
  - Core:       beta=0.8, halfLife=30d, floor=0.9
  - Working:    beta=1.0, halfLife=30d, floor=0.7
  - Peripheral: beta=1.3, halfLife=30d, floor=0.5

frequency = log(1 + accessCount) × reinforcementFactor
  - reinforcementFactor 默认 0.5
  - maxHalfLifeMultiplier 默认 3（限制最大有效半衰期）

intrinsic = importance × confidence
```

### 5. 长度归一化
```
lengthNorm = 1 + log(anchor / max(textLength, 1))
  - anchor 默认 500 字符
```

### 6. 过滤
```
if finalScore < hardMinScore (0.30): 丢弃
if finalScore < minScore (0.25): 丢弃（软阈值）

BM25 保护: bm25Score ≥ 0.75 的条目绕过语义过滤（保护 API key、票号等精确匹配）
```

---

## Weibull 衰减模型详细参数

### 三层分级规则

| 参数 | Core | Working | Peripheral |
|------|------|---------|------------|
| beta (β) | 0.8 | 1.0 | 1.3 |
| 衰减速度 | 最慢 | 标准 | 最快 |
| 最低分 (floor) | 0.9 | 0.7 | 0.5 |

### 晋升/降级规则

| 转换 | 条件 |
|------|------|
| Working → Core | accessCount ≥ coreAccessThreshold (默认 10) |
| Peripheral → Working | 被召回时自动提升 |
| Working → Peripheral | age > peripheralAgeDays (默认 60) 且 compositeScore 低 |
| Core → Working | 极少发生，仅当 compositeScore 持续极低 |

### 访问强化
```
effectiveHalfLife = baseHalfLife × (1 + reinforcementFactor × log(1 + accessCount))
有效半衰期上限 = baseHalfLife × maxHalfLifeMultiplier

每次召回有去抖动计时器，避免短时间重复计数。
```

---

## 智能提取（Smart Extraction）

### 6 类别映射

| 语义类别 | 存储 category | 说明 |
|---------|--------------|------|
| Profile | fact | 用户身份/背景信息 |
| Preferences | preference | 偏好设置和习惯 |
| Entities | entity | 人物/项目/工具 |
| Events | decision | 关键事件和决策 |
| Cases | fact | 案例和经验 |
| Patterns | other | 行为模式和规律 |

### L0/L1/L2 分层存储

| 层级 | 内容 | 用途 |
|------|------|------|
| L0 | 一句话摘要 | 快速索引和预览 |
| L1 | 结构化概要 | 中等详细程度的回忆 |
| L2 | 完整叙述 | 需要完整上下文时使用 |

### 两段去重流程
```
阶段 1: 向量相似度预过滤
  - 新记忆与已有记忆计算余弦相似度
  - 相似度 ≥ 0.7 → 进入 LLM 决策

阶段 2: LLM 语义决策
  - CREATE: 创建新记忆
  - MERGE: 合并到已有记忆
  - SKIP: 跳过（已存在或无价值）
  - SUPPORT / CONTEXTUALIZE / CONTRADICT: 高级操作

类别特殊规则:
  - profile → 总是 MERGE（保持最新用户画像）
  - events / cases → 总是 CREATE（每个事件唯一）
```

---

## 噪声过滤 & 自适应检索

### 过滤的内容类型
- Agent 拒绝回复（"I cannot..."）
- 元问题（"你能做什么？"）
- 简单问候（"你好"、"hi"）
- 表情符号和短确认
- Slash 命令

### 自适应触发规则

| 条件 | 操作 |
|------|------|
| 输入 < 15 字符 (CJK: 6 字符) | 跳过检索 |
| 输入是问候/确认/表情 | 跳过检索 |
| 包含 "remember" / "记住" / "上次" / "之前" | 强制检索 |
| Slash 命令 (/help, /new 等) | 跳过检索 |
| 正常输入 | 正常检索 |

---

## 完整配置参考

```json
{
  "embedding": {
    "provider": "openai-compatible",
    "model": "nomic-embed-text",
    "baseURL": "http://localhost:11434/v1",
    "apiKey": "ollama",
    "dimensions": 768,
    "taskQuery": "retrieval.query",
    "taskPassage": "retrieval.passage",
    "normalized": true
  },
  "dbPath": "~/.openclaw/memory/lancedb-longterm",
  "autoCapture": false,
  "autoRecall": true,
  "captureAssistant": false,
  "smartExtraction": true,
  "extractMinMessages": 2,
  "extractMaxChars": 8000,
  "retrieval": {
    "mode": "hybrid",
    "vectorWeight": 0.7,
    "bm25Weight": 0.3,
    "minScore": 0.25,
    "hardMinScore": 0.30,
    "rerank": "none",
    "candidatePoolSize": 20,
    "recencyHalfLifeDays": 14,
    "recencyWeight": 0.1,
    "filterNoise": true,
    "lengthNormAnchor": 500,
    "timeDecayHalfLifeDays": 60,
    "reinforcementFactor": 0.5,
    "maxHalfLifeMultiplier": 3
  },
  "scopes": {
    "default": "custom:long-term",
    "definitions": {
      "custom:long-term": {
        "description": "长期记忆存储 — 与 OpenClaw 内置记忆隔离"
      }
    }
  },
  "sessionMemory": {
    "enabled": false,
    "messageCount": 15
  },
  "enableManagementTools": true,
  "llm": {
    "model": "qwen3:8b",
    "baseURL": "http://localhost:11434/v1",
    "apiKey": "ollama",
    "timeoutMs": 60000
  },
  "decay": {
    "recencyHalfLifeDays": 30,
    "frequencyWeight": 0.3,
    "intrinsicWeight": 0.3,
    "betaCore": 0.8,
    "betaWorking": 1.0,
    "betaPeripheral": 1.3
  },
  "tier": {
    "coreAccessThreshold": 10,
    "peripheralAgeDays": 60
  }
}
```

---

## CLI 命令完整参考

```bash
# 列出记忆
openclaw memory-pro list [--scope custom:long-term] [--category fact] [--limit 20] [--json]

# 搜索记忆
openclaw memory-pro search "关键词" [--scope custom:long-term] [--limit 10] [--json]

# 查看统计
openclaw memory-pro stats [--scope custom:long-term] [--json]

# 删除单条记忆
openclaw memory-pro delete <id>

# 批量删除
openclaw memory-pro delete-bulk --scope custom:long-term [--before 2025-01-01] [--dry-run]

# 导出记忆
openclaw memory-pro export [--scope custom:long-term] [--output memories.json]

# 导入记忆
openclaw memory-pro import memories.json [--scope custom:long-term] [--dry-run]

# 重新嵌入（更换模型后）
openclaw memory-pro reembed --source-db /path/to/old-db [--batch-size 32] [--skip-existing]

# 升级（从旧版本）
openclaw memory-pro upgrade [--dry-run] [--batch-size 10] [--no-llm]

# 迁移检查
openclaw memory-pro migrate check|run|verify [--source /path]
```

---

## Ollama 本地部署详细指南

### 推荐模型

| 用途 | 模型 | 大小 | 说明 |
|------|------|------|------|
| 嵌入 | `nomic-embed-text` | 274MB | 768 维向量，效果优秀 |
| 智能提取 LLM | `qwen3:8b` | 4.9GB | JSON 输出可靠，中文能力强 |

### Ollama 健康检查

```bash
# 检查 Ollama 服务
curl -s http://localhost:11434/api/version

# 检查模型列表
curl -s http://localhost:11434/api/tags | python3 -m json.tool

# 测试嵌入
curl -s http://localhost:11434/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model":"nomic-embed-text","input":"测试嵌入"}' | python3 -c "
import sys, json
r = json.load(sys.stdin)
v = r['data'][0]['embedding']
print(f'维度: {len(v)}, 前3个值: {v[:3]}')
"

# 测试 LLM
curl -s http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3:8b","messages":[{"role":"user","content":"用JSON格式回复: {\"test\": true}"}]}'
```

### 远程 Ollama 配置

如果 Ollama 运行在另一台机器上：
```json
{
  "embedding": {
    "baseURL": "http://<远程IP>:11434/v1"
  },
  "llm": {
    "baseURL": "http://<远程IP>:11434/v1"
  }
}
```

---

*版本: v2026.03.20 | 深度技术参考文档*
