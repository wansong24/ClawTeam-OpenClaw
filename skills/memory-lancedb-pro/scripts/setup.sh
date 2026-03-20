#!/usr/bin/env bash
# ============================================================================
# 🧠 Memory-LanceDB-Pro 本地部署一键安装脚本
# 版本: v2026.03.20
# 说明: 自动安装 Ollama、拉取本地模型、配置 memory-lancedb-pro 插件
# ============================================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置
EMBEDDING_MODEL="nomic-embed-text"
LLM_MODEL="qwen3:8b"
OLLAMA_URL="http://localhost:11434"
DB_PATH="$HOME/.openclaw/memory/lancedb-longterm"
BACKUP_DIR="$HOME/.openclaw/memory/backups"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_TEMPLATE="$SCRIPT_DIR/openclaw-config-template.json"

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

# ============================================================================
# 步骤 1: 检测并安装 Ollama
# ============================================================================
install_ollama() {
    log_step "步骤 1/5: 检测 Ollama"

    if command -v ollama &>/dev/null; then
        local version
        version=$(ollama --version 2>/dev/null || echo "unknown")
        log_ok "Ollama 已安装 ($version)"
    else
        log_warn "Ollama 未安装，正在安装..."

        if [[ "$(uname)" == "Darwin" ]]; then
            if command -v brew &>/dev/null; then
                log_info "通过 Homebrew 安装 Ollama..."
                brew install ollama
            else
                log_info "通过官方安装脚本安装 Ollama..."
                curl -fsSL https://ollama.ai/install.sh | sh
            fi
        elif [[ "$(uname)" == "Linux" ]]; then
            log_info "通过官方安装脚本安装 Ollama..."
            curl -fsSL https://ollama.ai/install.sh | sh
        else
            log_error "不支持的操作系统: $(uname)"
            exit 1
        fi

        log_ok "Ollama 安装完成"
    fi

    # 确保 Ollama 服务运行中
    if ! curl -s "$OLLAMA_URL/api/version" &>/dev/null; then
        log_info "启动 Ollama 服务..."
        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS: 尝试 brew services 或直接后台启动
            if brew services list 2>/dev/null | grep -q ollama; then
                brew services start ollama
            else
                ollama serve &>/dev/null &
            fi
        else
            ollama serve &>/dev/null &
        fi

        # 等待服务启动
        for i in {1..15}; do
            if curl -s "$OLLAMA_URL/api/version" &>/dev/null; then
                break
            fi
            sleep 1
        done

        if curl -s "$OLLAMA_URL/api/version" &>/dev/null; then
            log_ok "Ollama 服务已启动"
        else
            log_error "Ollama 服务启动失败，请手动运行: ollama serve"
            exit 1
        fi
    else
        log_ok "Ollama 服务运行中"
    fi
}

# ============================================================================
# 步骤 2: 拉取本地模型
# ============================================================================
pull_models() {
    log_step "步骤 2/5: 拉取本地模型"

    # 嵌入模型
    if ollama list 2>/dev/null | grep -q "$EMBEDDING_MODEL"; then
        log_ok "嵌入模型 $EMBEDDING_MODEL 已存在"
    else
        log_info "拉取嵌入模型 $EMBEDDING_MODEL (约 274MB)..."
        ollama pull "$EMBEDDING_MODEL"
        log_ok "嵌入模型拉取完成"
    fi

    # LLM 模型
    if ollama list 2>/dev/null | grep -q "$LLM_MODEL"; then
        log_ok "LLM 模型 $LLM_MODEL 已存在"
    else
        log_info "拉取 LLM 模型 $LLM_MODEL (约 4.9GB，请耐心等待)..."
        ollama pull "$LLM_MODEL"
        log_ok "LLM 模型拉取完成"
    fi

    # 验证嵌入端点
    log_info "验证嵌入端点..."
    local embed_result
    embed_result=$(curl -s "$OLLAMA_URL/v1/embeddings" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$EMBEDDING_MODEL\",\"input\":\"test\"}" 2>/dev/null)

    if echo "$embed_result" | python3 -c "import sys,json; d=json.load(sys.stdin); assert len(d['data'][0]['embedding'])>0" 2>/dev/null; then
        local dims
        dims=$(echo "$embed_result" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data'][0]['embedding']))")
        log_ok "嵌入端点工作正常 (维度: $dims)"
    else
        log_error "嵌入端点验证失败，请检查 Ollama 服务"
        exit 1
    fi
}

# ============================================================================
# 步骤 3: 安装 memory-lancedb-pro 插件
# ============================================================================
install_plugin() {
    log_step "步骤 3/5: 安装 memory-lancedb-pro 插件"

    if command -v openclaw &>/dev/null; then
        # 检查是否已安装
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
    log_step "步骤 4/5: 配置"

    # 创建数据目录
    mkdir -p "$DB_PATH"
    mkdir -p "$BACKUP_DIR"
    log_ok "数据目录已创建: $DB_PATH"
    log_ok "备份目录已创建: $BACKUP_DIR"

    # 检查配置模板
    if [[ -f "$CONFIG_TEMPLATE" ]]; then
        log_ok "配置模板: $CONFIG_TEMPLATE"
        echo ""
        log_info "请将以下配置合并到你的 openclaw.json 中："
        echo ""
        cat "$CONFIG_TEMPLATE"
        echo ""
        log_info "openclaw.json 通常位于: ~/.openclaw/openclaw.json"
        log_info "或运行: openclaw config show 查看当前配置路径"
    else
        log_warn "配置模板文件未找到: $CONFIG_TEMPLATE"
    fi
}

# ============================================================================
# 步骤 5: 验证
# ============================================================================
verify_setup() {
    log_step "步骤 5/5: 验证安装"

    local all_ok=true

    # 检查 Ollama
    if curl -s "$OLLAMA_URL/api/version" &>/dev/null; then
        log_ok "Ollama 服务: 运行中"
    else
        log_error "Ollama 服务: 未响应"
        all_ok=false
    fi

    # 检查模型
    if ollama list 2>/dev/null | grep -q "$EMBEDDING_MODEL"; then
        log_ok "嵌入模型: $EMBEDDING_MODEL ✓"
    else
        log_error "嵌入模型: $EMBEDDING_MODEL 未找到"
        all_ok=false
    fi

    if ollama list 2>/dev/null | grep -q "$LLM_MODEL"; then
        log_ok "LLM 模型: $LLM_MODEL ✓"
    else
        log_error "LLM 模型: $LLM_MODEL 未找到"
        all_ok=false
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

    echo ""
    if $all_ok; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}  ✅ 安装完成！${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "下一步："
        echo "  1. 将配置模板合并到 openclaw.json"
        echo "  2. 运行: openclaw config validate"
        echo "  3. 运行: openclaw gateway restart"
        echo "  4. 测试: openclaw memory-pro stats"
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
    echo ""
    echo -e "${CYAN}🧠 Memory-LanceDB-Pro 本地部署安装脚本 v2026.03.20${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    install_ollama
    pull_models
    install_plugin
    setup_config
    verify_setup
}

main "$@"
