#!/usr/bin/env bash
# ============================================================================
# 🧠 Memory-LanceDB-Pro 本地部署一键安装脚本
# 版本: v2026.03.21
# 说明: 检测 oMLX/Ollama、配置 memory-lancedb-pro 插件、安装 Skill
# ============================================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 配置
OMLX_URL="http://localhost:8000"
OLLAMA_URL="http://localhost:11434"
OMLX_EMBEDDING_MODEL="bge-m3"
OLLAMA_EMBEDDING_MODEL="nomic-embed-text"
DB_PATH="$HOME/.openclaw/memory/lancedb-longterm"
BACKUP_DIR="$HOME/.openclaw/memory/backups"
SKILL_INSTALL_DIR="$HOME/.openclaw/workspace/skills/memory-lancedb-pro"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_TEMPLATE="$SCRIPT_DIR/openclaw-config-template.json"
OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"

# 检测到的后端
BACKEND=""         # omlx 或 ollama
BACKEND_URL=""
EMBEDDING_MODEL=""
EMBEDDING_DIMS=""
LLM_MODEL=""

CHECK_ONLY=false

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

# ============================================================================
# 解析参数
# ============================================================================
parse_args() {
    for arg in "$@"; do
        case $arg in
            --check-only)
                CHECK_ONLY=true
                ;;
            --help|-h)
                echo "用法: bash setup.sh [选项]"
                echo ""
                echo "选项:"
                echo "  --check-only    仅检测环境状态，不做安装"
                echo "  --help, -h      显示帮助"
                exit 0
                ;;
        esac
    done
}

# ============================================================================
# 步骤 1: 检测推理后端（oMLX 优先，Ollama 备用）
# ============================================================================
detect_backend() {
    log_step "步骤 1/6: 检测推理后端"

    # 优先检测 oMLX
    if curl -s "$OMLX_URL/v1/models" &>/dev/null; then
        BACKEND="omlx"
        BACKEND_URL="$OMLX_URL/v1"
        log_ok "检测到 oMLX 服务 ($OMLX_URL) — Apple Silicon 优化 🍎"

        # 获取 oMLX 模型列表
        local models
        models=$(curl -s "$OMLX_URL/v1/models" 2>/dev/null)
        log_info "oMLX 已加载模型:"
        echo "$models" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    for m in d.get('data', []):
        print(f'  - {m[\"id\"]}')
except:
    print('  (无法解析模型列表)')
" 2>/dev/null || echo "  (无法解析模型列表)"

        # 检测嵌入模型
        if echo "$models" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ids = [m['id'].lower() for m in d.get('data', [])]
sys.exit(0 if any('bge' in i or 'embed' in i for i in ids) else 1)
" 2>/dev/null; then
            EMBEDDING_MODEL="$OMLX_EMBEDDING_MODEL"
            EMBEDDING_DIMS="1024"
            log_ok "检测到嵌入模型: $EMBEDDING_MODEL (${EMBEDDING_DIMS}维)"
        else
            log_warn "未检测到嵌入模型。请在 oMLX Admin Dashboard 中下载 bge-m3"
            log_info "访问 $OMLX_URL/admin → Model Downloader → 搜索 bge-m3"
            EMBEDDING_MODEL="$OMLX_EMBEDDING_MODEL"
            EMBEDDING_DIMS="1024"
        fi

        # 检测 LLM 模型
        LLM_MODEL=$(echo "$models" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for m in d.get('data', []):
    mid = m['id'].lower()
    if 'embed' not in mid and 'bge' not in mid and 'rerank' not in mid:
        print(m['id'])
        sys.exit(0)
print('Qwen3-8B-MLX')
" 2>/dev/null || echo "Qwen3-8B-MLX")
        log_ok "LLM 模型: $LLM_MODEL"

        return 0
    fi

    # 回退检测 Ollama
    if curl -s "$OLLAMA_URL/api/version" &>/dev/null; then
        BACKEND="ollama"
        BACKEND_URL="$OLLAMA_URL/v1"
        EMBEDDING_MODEL="$OLLAMA_EMBEDDING_MODEL"
        EMBEDDING_DIMS="768"
        log_warn "oMLX 未运行，检测到 Ollama ($OLLAMA_URL) — 使用备用方案"

        # 检测 Ollama 模型
        if ollama list 2>/dev/null | grep -q "$OLLAMA_EMBEDDING_MODEL"; then
            log_ok "嵌入模型: $EMBEDDING_MODEL (${EMBEDDING_DIMS}维)"
        else
            log_info "拉取嵌入模型 $OLLAMA_EMBEDDING_MODEL (约 274MB)..."
            if ! $CHECK_ONLY; then
                ollama pull "$OLLAMA_EMBEDDING_MODEL"
            fi
        fi

        # 检测 LLM
        LLM_MODEL=$(ollama list 2>/dev/null | grep -v embed | grep -v NAME | awk '{print $1}' | head -1)
        if [ -z "$LLM_MODEL" ]; then
            LLM_MODEL="qwen3:8b"
            log_info "拉取 LLM 模型 $LLM_MODEL (约 4.9GB)..."
            if ! $CHECK_ONLY; then
                ollama pull "$LLM_MODEL"
            fi
        fi
        log_ok "LLM 模型: $LLM_MODEL"

        return 0
    fi

    log_error "未检测到 oMLX 或 Ollama 服务！"
    echo ""
    echo "请先启动推理后端："
    echo "  oMLX: 从菜单栏启动，或 omlx serve --model-dir ~/models"
    echo "  Ollama: brew install ollama && ollama serve"
    exit 1
}

# ============================================================================
# 步骤 2: 验证嵌入端点
# ============================================================================
verify_embedding() {
    log_step "步骤 2/6: 验证嵌入端点"

    local embed_result
    embed_result=$(curl -s "$BACKEND_URL/embeddings" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$EMBEDDING_MODEL\",\"input\":\"测试嵌入\"}" 2>/dev/null)

    if echo "$embed_result" | python3 -c "import sys,json; d=json.load(sys.stdin); assert len(d['data'][0]['embedding'])>0" 2>/dev/null; then
        local dims
        dims=$(echo "$embed_result" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data'][0]['embedding']))")
        EMBEDDING_DIMS="$dims"
        log_ok "嵌入端点工作正常 (维度: $dims)"
    else
        log_warn "嵌入端点验证失败，模型可能尚未加载"
        if [ "$BACKEND" = "omlx" ]; then
            log_info "请在 oMLX Admin ($OMLX_URL/admin) 中加载嵌入模型"
        fi
    fi
}

# ============================================================================
# 步骤 3: 安装 memory-lancedb-pro 插件
# ============================================================================
install_plugin() {
    log_step "步骤 3/6: 安装 memory-lancedb-pro 插件"

    if $CHECK_ONLY; then
        if command -v openclaw &>/dev/null && openclaw plugins info memory-lancedb-pro &>/dev/null 2>&1; then
            log_ok "memory-lancedb-pro 插件已安装"
        else
            log_warn "memory-lancedb-pro 插件未安装"
        fi
        return 0
    fi

    if command -v openclaw &>/dev/null; then
        if openclaw plugins info memory-lancedb-pro &>/dev/null 2>&1; then
            log_ok "memory-lancedb-pro 插件已安装"
        else
            log_info "安装 memory-lancedb-pro@beta..."
            openclaw plugins install memory-lancedb-pro@beta || {
                log_warn "openclaw plugins install 失败，尝试 npm 安装..."
                npm i -g memory-lancedb-pro@beta
            }
            log_ok "插件安装完成"
        fi
    else
        log_warn "openclaw 命令未找到，请确保 OpenClaw 已正确安装"
        log_info "尝试通过 npm 安装插件..."
        npm i -g memory-lancedb-pro@beta || {
            log_error "插件安装失败"
            exit 1
        }
        log_ok "插件通过 npm 安装完成"
    fi
}

# ============================================================================
# 步骤 4: 配置
# ============================================================================
setup_config() {
    log_step "步骤 4/6: 配置"

    # 创建数据目录
    mkdir -p "$DB_PATH"
    mkdir -p "$BACKUP_DIR"
    log_ok "数据目录: $DB_PATH"
    log_ok "备份目录: $BACKUP_DIR"

    if $CHECK_ONLY; then
        log_info "检查模式，跳过配置修改"
        return 0
    fi

    # 根据检测到的后端生成配置
    local rerank_config
    if [ "$BACKEND" = "omlx" ]; then
        rerank_config='"rerank": "cross-encoder", "rerankProvider": "jina", "rerankEndpoint": "http://localhost:8000/v1/rerank", "rerankApiKey": "omlx", "candidatePoolSize": 12'
    else
        rerank_config='"rerank": "none"'
    fi

    # 尝试自动合并到 openclaw.json
    if [ -f "$OPENCLAW_CONFIG" ]; then
        log_info "检测到 openclaw.json: $OPENCLAW_CONFIG"

        # 备份原配置
        local backup_file="${OPENCLAW_CONFIG}.backup.$(date +%Y%m%d%H%M%S)"
        cp "$OPENCLAW_CONFIG" "$backup_file"
        log_ok "原配置已备份: $backup_file"

        # 使用 python3 合并配置
        python3 << PYEOF
import json, sys

try:
    with open("$OPENCLAW_CONFIG", "r") as f:
        config = json.load(f)
except:
    config = {}

# 确保 plugins 结构存在
config.setdefault("plugins", {})
config["plugins"].setdefault("slots", {})
config["plugins"]["slots"]["memory"] = "memory-lancedb-pro"

config["plugins"].setdefault("entries", {})
config["plugins"]["entries"]["memory-lancedb-pro"] = {
    "enabled": True,
    "config": {
        "embedding": {
            "provider": "openai-compatible",
            "model": "$EMBEDDING_MODEL",
            "baseURL": "$BACKEND_URL",
            "apiKey": "$BACKEND",
            "dimensions": int("$EMBEDDING_DIMS")
        },
        "dbPath": "~/.openclaw/memory/lancedb-longterm",
        "autoCapture": False,
        "autoRecall": True,
        "smartExtraction": True,
        "extractMinMessages": 2,
        "extractMaxChars": 8000,
        "retrieval": {
            "mode": "hybrid",
            "vectorWeight": 0.7,
            "bm25Weight": 0.3,
            "minScore": 0.25,
            "hardMinScore": 0.30,
            "filterNoise": True,
            $([ "$BACKEND" = "omlx" ] && echo '"rerank": "cross-encoder", "rerankProvider": "jina", "rerankEndpoint": "http://localhost:8000/v1/rerank", "rerankApiKey": "omlx", "candidatePoolSize": 12,' || echo '"rerank": "none",')
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
        "sessionMemory": {"enabled": False},
        "llm": {
            "model": "$LLM_MODEL",
            "baseURL": "$BACKEND_URL",
            "apiKey": "$BACKEND"
        },
        "enableManagementTools": True
    }
}

with open("$OPENCLAW_CONFIG", "w") as f:
    json.dump(config, f, indent=2, ensure_ascii=False)

print("配置已合并")
PYEOF

        if [ $? -eq 0 ]; then
            log_ok "配置已自动合并到 $OPENCLAW_CONFIG"
        else
            log_warn "自动合并失败，请手动合并配置模板"
            log_info "配置模板: $CONFIG_TEMPLATE"
        fi
    else
        log_warn "未找到 openclaw.json: $OPENCLAW_CONFIG"
        log_info "请将以下配置模板合并到你的 openclaw.json 中："
        echo ""
        cat "$CONFIG_TEMPLATE"
        echo ""
    fi
}

# ============================================================================
# 步骤 5: 安装 Skill 文件
# ============================================================================
install_skill() {
    log_step "步骤 5/6: 安装 Skill 文件"

    if $CHECK_ONLY; then
        if [ -f "$SKILL_INSTALL_DIR/SKILL.md" ]; then
            log_ok "Skill 文件已安装: $SKILL_INSTALL_DIR"
        else
            log_warn "Skill 文件未安装"
        fi
        return 0
    fi

    mkdir -p "$SKILL_INSTALL_DIR"
    mkdir -p "$SKILL_INSTALL_DIR/references"

    # 复制 Skill 文件
    cp "$SKILL_DIR/SKILL.md" "$SKILL_INSTALL_DIR/SKILL.md"
    cp "$SKILL_DIR/references/full-reference.md" "$SKILL_INSTALL_DIR/references/full-reference.md"

    log_ok "Skill 文件已安装到: $SKILL_INSTALL_DIR"
}

# ============================================================================
# 步骤 6: 验证
# ============================================================================
verify_setup() {
    log_step "步骤 6/6: 验证安装"

    local all_ok=true

    # 检查推理后端
    if [ "$BACKEND" = "omlx" ]; then
        if curl -s "$OMLX_URL/v1/models" &>/dev/null; then
            log_ok "oMLX 服务: 运行中 🍎"
        else
            log_error "oMLX 服务: 未响应"
            all_ok=false
        fi
    elif [ "$BACKEND" = "ollama" ]; then
        if curl -s "$OLLAMA_URL/api/version" &>/dev/null; then
            log_ok "Ollama 服务: 运行中"
        else
            log_error "Ollama 服务: 未响应"
            all_ok=false
        fi
    fi

    # 检查目录
    if [[ -d "$DB_PATH" ]]; then
        log_ok "数据目录: $DB_PATH ✓"
    else
        log_error "数据目录不存在: $DB_PATH"
        all_ok=false
    fi

    if [[ -d "$BACKUP_DIR" ]]; then
        log_ok "备份目录: $BACKUP_DIR ✓"
    else
        log_error "备份目录不存在: $BACKUP_DIR"
        all_ok=false
    fi

    # 检查 Skill 文件
    if [[ -f "$SKILL_INSTALL_DIR/SKILL.md" ]]; then
        log_ok "Skill 文件: 已安装 ✓"
    else
        log_warn "Skill 文件: 未安装"
    fi

    echo ""
    if $all_ok; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}  ✅ 安装完成！${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${PURPLE}推理后端: $BACKEND${NC}"
        echo -e "${PURPLE}嵌入模型: $EMBEDDING_MODEL (${EMBEDDING_DIMS}维)${NC}"
        echo -e "${PURPLE}LLM 模型: $LLM_MODEL${NC}"
        if [ "$BACKEND" = "omlx" ]; then
            echo -e "${PURPLE}Reranking: ✅ 本地 cross-encoder${NC}"
        else
            echo -e "${PURPLE}Reranking: ❌ 未启用（Ollama 不支持）${NC}"
        fi
        echo ""
        echo "下一步："
        echo "  1. 运行: openclaw config validate"
        echo "  2. 运行: openclaw gateway restart"
        echo "  3. 测试: openclaw memory-pro stats"
        echo ""
        echo "设置每日 GitHub 备份："
        echo "  bash $SCRIPT_DIR/backup-to-github.sh --install-schedule"
    else
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}  ⚠️ 部分步骤失败，请检查上方错误信息${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
}

# ============================================================================
# 主流程
# ============================================================================
main() {
    parse_args "$@"

    echo ""
    echo -e "${CYAN}🧠 Memory-LanceDB-Pro 本地部署安装脚本 v2026.03.21${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if $CHECK_ONLY; then
        echo -e "${YELLOW}  [检查模式] 仅检测环境，不做安装${NC}"
    fi
    echo ""

    detect_backend
    verify_embedding
    install_plugin
    setup_config
    install_skill
    verify_setup
}

main "$@"
