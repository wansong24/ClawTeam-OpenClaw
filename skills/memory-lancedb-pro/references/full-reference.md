# 📚 Memory-LanceDB-Pro 深度技术参考

本文档为深度技术参考，由 SKILL.md 按需加载。包含完整配置项、数据库 schema、检索公式、衰减模型、oMLX 集成细节等。

---

## 🔌 oMLX API 参考

oMLX 是专为 Apple Silicon 优化的本地推理服务器，提供 OpenAI 兼容 API。

### 端点

| 端点 | 用途 |
|------|------|
| `POST /v1/embeddings` | 嵌入向量生成（bge-m3） |
| `POST /v1/chat/completions` | LLM 智能提取（Qwen3 等） |
| `POST /v1/rerank` | 本地 cross-encoder 重排序 |
| `GET /v1/models` | 列出已加载模型 |
| `GET /admin` | Web 管理仪表板 |

### 默认配置

- **端口**: `8000`（可通过 `OMLX_PORT` 环境变量修改）
- **基地址**: `http://localhost:8000/v1`
- **认证**: 默认无需 API Key（占位用 `omlx`）
- **模型目录**: `~/models/`（通过 `--model-dir` 指定）
- **设置存储**: `~/.omlx/settings.json`

### Ollama 备用方案

如 oMLX 不可用，可回退到 Ollama：
- **端口**: `11434`
- **基地址**: `http://localhost:11434/v1`
- **嵌入模型**: `nomic-embed-text`（768维）
- **无 reranking**: 需设 `rerank: "none"`

---

## 🧠 LanceDB 数据库 Schema

### memories 表

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | UUID 唯一标识 |
| `text` | string | 记忆内容文本 |
| `vector` | float[] | 嵌入向量（bge-m3: 1024维 / nomic: 768维） |
| `category` | string | 存储类别: preference/fact/decision/entity/reflection/other |
| `scope` | string | 作用域: `custom:long-term` |
| `importance` | float | 重要性 0.0-1.0 |
| `timestamp` | string | ISO 8601 创建时间 |
| `metadata` | JSON | 扩展元数据 |

### metadata 字段（v1.1.0）

| key | 说明 |
|-----|------|
| `l0_abstract` | L0 一句话摘要（索引层） |
| `l1_overview` | L1 结构化概要（中间层） |
| `l2_content` | L2 完整叙述（详细层） |
| `memory_category` | 语义分类: profile/preferences/entities/events/cases/patterns |
| `tier` | 生命周期层级: core/working/peripheral |
| `access_count` | 被召回次数 |
| `confidence` | 提取置信度 0.0-1.0 |
| `last_accessed_at` | 最后被召回时间 |

---

## 🔍 混合检索完整管线

```
Query
  │
  ├─→ embedQuery(bge-m3) → Vector ANN Search (cosine) ─┐
  │                                                      ├─→ Hybrid Fusion
  └─→ BM25 Full-Text Search ────────────────────────────┘
                                                          │
                                                    Reranking (oMLX /v1/rerank)
                                                          │
                                                    Lifecycle Decay Boost
                                                          │
                                                    Length Normalization
                                                          │
                                                    Hard Min Score Filter
                                                          │
                                                    MMR Diversity
                                                          │
                                                        Results
```

### 融合公式

```
hybridScore = vectorScore_base + (bm25Hit ? bm25Weight × bm25Score : 0)
```

- `vectorWeight`: 0.7（默认）
- `bm25Weight`: 0.3（默认）

### Reranking 公式（启用时）

```
finalScore = 0.6 × crossEncoderScore + 0.4 × hybridScore
```

oMLX 本地 reranker 调用 `/v1/rerank`，兼容 Jina rerank API 格式。

### BM25 关键词保护

BM25 score ≥ 0.75 的结果绕过语义过滤，保护 API key、工单号等精确匹配内容。

---

## 📉 Weibull 衰减模型

### 衰减公式

```
recency = exp(-λ × daysSince^β)

其中:
  λ = ln(2) / halfLifeDays
  β = tier-specific shape parameter
  daysSince = (now - lastAccessedAt) / (24 × 60 × 60 × 1000)
```

### 三层参数

| 参数 | Core | Working | Peripheral |
|------|------|---------|------------|
| β (shape) | 0.8 | 1.0 | 1.3 |
| 衰减速度 | 最慢 | 标准 | 最快 |
| 最低分 floor | 0.9 | 0.7 | 0.5 |

### 综合评分

```
compositeScore = recency × 0.4 + frequency × 0.3 + intrinsic × 0.3

其中:
  frequency = min(1.0, access_count / frequencyNorm)
  intrinsic = importance × confidence
```

### 层级晋升/降级

- **→ Core**: access_count ≥ coreAccessThreshold（默认 10）且 compositeScore 高
- **→ Peripheral**: 距上次访问 ≥ peripheralAgeDays（默认 60天）且 compositeScore 低
- **→ Working**: 其他情况

### 访问强化（间隔重复）

```
effectiveHalfLife = baseHalfLife × (1 + reinforcementFactor × log2(1 + access_count))
上限: effectiveHalfLife ≤ baseHalfLife × maxHalfLifeMultiplier
```

---

## 🧬 智能提取 6 类别映射

| 语义类别 | 存储 category | 合并策略 |
|---------|--------------|---------|
| profile | fact | 始终合并（MERGE） |
| preferences | preference | 相似则合并 |
| entities | entity | 相似则合并 |
| events | decision | 仅追加（CREATE） |
| cases | fact | 仅追加（CREATE） |
| patterns | other | 相似则合并 |

### 两段去重

1. **向量预过滤**: 余弦相似度 ≥ 0.7 → 候选重复
2. **LLM 语义决策**: CREATE / MERGE / SKIP / SUPPORT / CONTEXTUALIZE / CONTRADICT

### L0/L1/L2 分层存储

- **L0**: 一句话摘要（≤ 100 字符），用于快速索引
- **L1**: 结构化概要，包含关键要素
- **L2**: 完整叙述内容

---

## 🔧 完整配置参考

### embedding（嵌入配置）

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `provider` | `openai-compatible` | 嵌入提供者 |
| `model` | `bge-m3` | 嵌入模型名 |
| `baseURL` | `http://localhost:8000/v1` | oMLX API 地址 |
| `apiKey` | `omlx` | API Key（oMLX 默认不需要） |
| `dimensions` | `1024` | 向量维度 |
| `taskQuery` | — | Jina 查询任务类型 |
| `taskPassage` | — | Jina 文档任务类型 |
| `normalized` | — | 是否归一化 |

### retrieval（检索配置）

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `mode` | `hybrid` | 检索模式: hybrid/vector/bm25 |
| `vectorWeight` | `0.7` | 向量权重 |
| `bm25Weight` | `0.3` | BM25 权重 |
| `minScore` | `0.3` | 软最低分 |
| `hardMinScore` | `0.35` | 硬最低分 |
| `rerank` | `cross-encoder` | 重排序: cross-encoder/none |
| `rerankProvider` | `jina` | Reranker 提供者（oMLX 兼容 Jina 格式） |
| `rerankEndpoint` | `http://localhost:8000/v1/rerank` | Reranker 端点 |
| `rerankApiKey` | `omlx` | Reranker API Key |
| `candidatePoolSize` | `12` | 重排序候选池大小 |
| `filterNoise` | `true` | 噪声过滤 |
| `lengthNormAnchor` | `500` | 长度归一化锚点 |
| `recencyHalfLifeDays` | `14` | 近期性半衰期 |
| `recencyWeight` | `0.1` | 近期性权重 |
| `timeDecayHalfLifeDays` | `60` | 时间衰减半衰期 |
| `reinforcementFactor` | `0.5` | 访问强化因子（0 禁用） |
| `maxHalfLifeMultiplier` | `3` | 最大半衰期倍数 |

### decay（衰减引擎）

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `recencyHalfLifeDays` | `30` | 基础半衰期（天） |
| `frequencyWeight` | `0.3` | 频率权重 |
| `intrinsicWeight` | `0.3` | 内在价值权重 |
| `betaCore` | `0.8` | Core 层 β 参数 |
| `betaWorking` | `1.0` | Working 层 β 参数 |
| `betaPeripheral` | `1.3` | Peripheral 层 β 参数 |

### tier（层级管理）

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `coreAccessThreshold` | `10` | 晋升 Core 所需访问次数 |
| `peripheralAgeDays` | `60` | 降级 Peripheral 的天数 |

### llm（智能提取 LLM）

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `model` | `Qwen3-8B-MLX` | LLM 模型名 |
| `baseURL` | `http://localhost:8000/v1` | oMLX API 地址 |
| `apiKey` | `omlx` | API Key |
| `auth` | `api-key` | 认证方式: api-key/oauth |
| `timeoutMs` | `30000` | 超时毫秒 |

---

## 🛠️ 9 MCP 工具完整参考

### 核心工具（自动注册）

#### memory_store
```json
{
  "content": "记忆内容（< 500 字符）",
  "category": "preference|fact|decision|entity|reflection|other",
  "scope": "custom:long-term",
  "importance": 0.85
}
```

#### memory_recall
```json
{
  "query": "搜索关键词或语义描述",
  "scope": "custom:long-term",
  "limit": 5
}
```

#### memory_forget
```json
{ "id": "记忆 UUID" }
```

#### memory_update
```json
{
  "id": "记忆 UUID",
  "content": "更新后的内容"
}
```

### 管理工具（需 `enableManagementTools: true`）

#### memory_stats
返回记忆库统计：总数、各类别分布、各层级分布、存储大小。

#### memory_list
```json
{
  "scope": "custom:long-term",
  "category": "preference",
  "limit": 20
}
```

### 自改进工具

#### self_improvement_log
```json
{
  "type": "lesson|error",
  "content": "学习或错误描述",
  "tags": ["tag1", "tag2"]
}
```
写入 LEARNINGS.md（LRN-YYYYMMDD-XXX）或 ERRORS.md（ERR-YYYYMMDD-XXX）。

#### self_improvement_extract_skill
从一个 learning 条目中提取可复用的 skill 脚手架。

#### self_improvement_review
审查所有 pending 状态的条目，输出需要关注的学习和错误。

### 条目生命周期

```
pending → resolved → promoted_to_skill
```

---

## 🔇 噪声过滤规则

### 5 类噪声（自动跳过存储）

1. **Agent 拒绝**: "I can't", "I'm unable to", "作为 AI"
2. **元问题**: "你能做什么", "你是什么模型"
3. **问候语**: "你好", "hello", "hi"
4. **确认**: "好的", "ok", "明白"
5. **纯 emoji**: 😀 👍 ✅

### 自适应检索

| 条件 | 行为 |
|------|------|
| 问候/确认/emoji/斜杠命令 | 跳过检索 |
| 包含 "remember"/"previously"/"last time" | 强制检索 |
| 英文 < 15 字符 | 跳过检索 |
| 中文 < 6 字符 | 跳过检索 |

---

## 💻 CLI 命令完整参考

```bash
openclaw memory-pro list [--scope custom:long-term] [--category fact] [--limit 20] [--json]
openclaw memory-pro search "query" [--scope custom:long-term] [--limit 10] [--json]
openclaw memory-pro stats [--scope custom:long-term] [--json]
openclaw memory-pro delete <id>
openclaw memory-pro delete-bulk --scope custom:long-term [--before 2026-01-01] [--dry-run]
openclaw memory-pro export [--scope custom:long-term] [--output memories.json]
openclaw memory-pro import memories.json [--scope custom:long-term] [--dry-run]
openclaw memory-pro reembed --source-db /path/to/old-db [--batch-size 32] [--skip-existing]
openclaw memory-pro upgrade [--dry-run] [--batch-size 10] [--no-llm] [--limit N]
openclaw memory-pro migrate check|run|verify [--source /path]
```

---

*版本: v2026.03.21 | memory-lancedb-pro v1.1.0-beta.8*
