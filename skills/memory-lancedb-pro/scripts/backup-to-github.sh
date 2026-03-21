#!/usr/bin/env bash
# ============================================================================
# 🧠 Memory-LanceDB-Pro GitHub 每日备份脚本
# 版本: v2026.03.21
# 说明: 导出记忆、生成元数据、推送到 GitHub
# ============================================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
SCOPE="custom:long-term"
BACKUP_DIR="$HOME/.openclaw/memory/backups"
REPO_DIR="$HOME/.openclaw/memory/backup-repo"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d)
BACKUP_FILE="$BACKUP_DIR/memories-$DATE.json"
METADATA_FILE="$BACKUP_DIR/metadata-$DATE.json"
LAUNCHD_LABEL="com.openclaw.memory-backup"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/$LAUNCHD_LABEL.plist"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================================================
# 显示帮助
# ============================================================================
show_help() {
    echo "用法: bash backup-to-github.sh [选项]"
    echo ""
    echo "选项:"
    echo "  --init-repo          初始化 GitHub 备份仓库"
    echo "  --install-schedule   设置每日自动备份（launchd，凌晨 2:00）"
    echo "  --uninstall-schedule 移除自动备份计划"
    echo "  --status             查看最近备份状态"
    echo "  --help, -h           显示帮助"
    echo ""
    echo "无参数运行时执行一次备份。"
}

# ============================================================================
# 初始化 GitHub 备份仓库
# ============================================================================
init_repo() {
    echo -e "${CYAN}🔧 初始化 GitHub 备份仓库${NC}"
    echo ""

    if [ -d "$REPO_DIR/.git" ]; then
        log_ok "备份仓库已存在: $REPO_DIR"
        return 0
    fi

    echo "请输入 GitHub 备份仓库地址 (例如: git@github.com:username/memory-backup.git):"
    read -r REPO_URL

    if [ -z "$REPO_URL" ]; then
        log_error "仓库地址不能为空"
        exit 1
    fi

    mkdir -p "$REPO_DIR"

    # 尝试克隆，如果仓库为空则初始化
    if git clone "$REPO_URL" "$REPO_DIR" 2>/dev/null; then
        log_ok "仓库已克隆: $REPO_DIR"
    else
        cd "$REPO_DIR"
        git init
        git remote add origin "$REPO_URL"

        # 创建初始 README
        cat > "$REPO_DIR/README.md" << 'README_EOF'
# 🧠 OpenClaw Memory Backup

本仓库自动备份 OpenClaw memory-lancedb-pro 插件的长期记忆数据。

## 备份内容

- `memories-YYYYMMDD.json` — 当日记忆导出
- `metadata-YYYYMMDD.json` — 备份元数据（统计信息）

## 恢复

```bash
openclaw memory-pro import memories-YYYYMMDD.json --scope custom:long-term
```

---

*由 [memory-lancedb-pro Skill](https://github.com/wansong24/ClawTeam-OpenClaw) 自动生成*
README_EOF

        git add .
        git commit -m "🧠 初始化记忆备份仓库"
        git branch -M main
        git push -u origin main 2>/dev/null || log_warn "首次推送失败，请确认仓库已创建"

        log_ok "备份仓库初始化完成: $REPO_DIR"
    fi
}

# ============================================================================
# 执行备份
# ============================================================================
do_backup() {
    echo -e "${CYAN}🧠 Memory-LanceDB-Pro 备份 — $DATE${NC}"
    echo ""

    mkdir -p "$BACKUP_DIR"

    # 1. 导出记忆
    log_info "导出 scope=$SCOPE 的记忆..."

    if command -v openclaw &>/dev/null; then
        openclaw memory-pro export --scope "$SCOPE" --output "$BACKUP_FILE" 2>/dev/null || {
            log_error "记忆导出失败"
            exit 1
        }
    else
        log_error "openclaw 命令未找到"
        exit 1
    fi

    if [ ! -f "$BACKUP_FILE" ]; then
        log_warn "导出文件为空，可能没有记忆数据"
        return 0
    fi

    local file_size
    file_size=$(wc -c < "$BACKUP_FILE" | tr -d ' ')
    log_ok "记忆已导出: $BACKUP_FILE ($file_size bytes)"

    # 2. 生成元数据
    log_info "生成备份元数据..."

    python3 << PYEOF > "$METADATA_FILE"
import json, sys
from datetime import datetime

try:
    with open("$BACKUP_FILE", "r") as f:
        data = json.load(f)

    memories = data if isinstance(data, list) else data.get("memories", data.get("data", []))

    categories = {}
    tiers = {}
    for m in memories:
        cat = m.get("category", "unknown")
        categories[cat] = categories.get(cat, 0) + 1
        tier = m.get("metadata", {}).get("tier", "unknown") if isinstance(m.get("metadata"), dict) else "unknown"
        tiers[tier] = tiers.get(tier, 0) + 1

    metadata = {
        "backup_date": "$DATE",
        "backup_time": datetime.now().isoformat(),
        "scope": "$SCOPE",
        "total_memories": len(memories),
        "categories": categories,
        "tiers": tiers,
        "file_size_bytes": $file_size,
        "version": "v2026.03.21"
    }

    print(json.dumps(metadata, indent=2, ensure_ascii=False))
except Exception as e:
    print(json.dumps({"error": str(e), "backup_date": "$DATE"}))
PYEOF

    log_ok "元数据已生成: $METADATA_FILE"

    # 显示统计
    python3 -c "
import json
with open('$METADATA_FILE') as f:
    m = json.load(f)
print(f'  总记忆数: {m.get(\"total_memories\", \"?\")}')
cats = m.get('categories', {})
for k, v in cats.items():
    print(f'  - {k}: {v}')
" 2>/dev/null || true

    # 3. 推送到 GitHub
    if [ -d "$REPO_DIR/.git" ]; then
        log_info "推送到 GitHub..."

        cp "$BACKUP_FILE" "$REPO_DIR/"
        cp "$METADATA_FILE" "$REPO_DIR/"

        cd "$REPO_DIR"

        # 如果有变更才提交
        if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
            log_ok "记忆无变化，跳过推送"
        else
            git add .
            git commit -m "🧠 记忆备份 $DATE ($(python3 -c "import json; print(json.load(open('$METADATA_FILE')).get('total_memories', '?'))" 2>/dev/null || echo '?') 条记忆)"

            # 推送，失败则 rebase 重试
            if ! git push 2>/dev/null; then
                log_warn "推送失败，尝试 pull --rebase 后重试..."
                git pull --rebase 2>/dev/null && git push 2>/dev/null || {
                    log_error "推送失败，请手动检查 git 状态"
                }
            fi

            log_ok "已推送到 GitHub ✓"
        fi
    else
        log_warn "备份仓库未初始化，仅保留本地备份"
        log_info "运行 --init-repo 初始化 GitHub 备份仓库"
    fi

    # 4. 清理旧备份
    log_info "清理 $RETENTION_DAYS 天前的本地备份..."
    find "$BACKUP_DIR" -name "memories-*.json" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find "$BACKUP_DIR" -name "metadata-*.json" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    log_ok "清理完成"

    echo ""
    echo -e "${GREEN}━━━ 备份完成 ━━━${NC}"
}

# ============================================================================
# 查看备份状态
# ============================================================================
show_status() {
    echo -e "${CYAN}🧠 备份状态${NC}"
    echo ""

    # 最近备份
    local latest
    latest=$(ls -t "$BACKUP_DIR"/memories-*.json 2>/dev/null | head -1)
    if [ -n "$latest" ]; then
        local latest_date
        latest_date=$(basename "$latest" | sed 's/memories-//' | sed 's/.json//')
        local latest_size
        latest_size=$(wc -c < "$latest" | tr -d ' ')
        log_ok "最近备份: $latest_date ($latest_size bytes)"

        # 显示元数据
        local meta="${latest/memories-/metadata-}"
        if [ -f "$meta" ]; then
            python3 -c "
import json
with open('$meta') as f:
    m = json.load(f)
print(f'  记忆总数: {m.get(\"total_memories\", \"?\")}')
cats = m.get('categories', {})
for k, v in cats.items():
    print(f'  - {k}: {v}')
" 2>/dev/null || true
        fi
    else
        log_warn "没有找到备份文件"
    fi

    # 备份数量
    local count
    count=$(ls "$BACKUP_DIR"/memories-*.json 2>/dev/null | wc -l | tr -d ' ')
    log_info "本地备份数量: $count (保留 $RETENTION_DAYS 天)"

    # GitHub 状态
    if [ -d "$REPO_DIR/.git" ]; then
        cd "$REPO_DIR"
        local remote
        remote=$(git remote get-url origin 2>/dev/null || echo "未配置")
        log_ok "GitHub 仓库: $remote"
        local last_push
        last_push=$(git log -1 --format="%ai" 2>/dev/null || echo "未知")
        log_info "最后推送: $last_push"
    else
        log_warn "GitHub 备份仓库未初始化"
    fi

    # launchd 状态
    if [ -f "$LAUNCHD_PLIST" ]; then
        log_ok "自动备份: 已启用 (每日凌晨 2:00)"
    else
        log_warn "自动备份: 未启用"
    fi
}

# ============================================================================
# 安装定时备份（launchd）
# ============================================================================
install_schedule() {
    echo -e "${CYAN}🔧 安装每日自动备份${NC}"
    echo ""

    mkdir -p "$HOME/Library/LaunchAgents"

    cat > "$LAUNCHD_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LAUNCHD_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT_PATH</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$HOME/.openclaw/memory/backups/backup.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.openclaw/memory/backups/backup-error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
    </dict>
</dict>
</plist>
EOF

    launchctl load "$LAUNCHD_PLIST" 2>/dev/null || true
    log_ok "每日自动备份已安装（凌晨 2:00）"
    log_info "查看日志: tail -f $BACKUP_DIR/backup.log"
}

# ============================================================================
# 卸载定时备份
# ============================================================================
uninstall_schedule() {
    if [ -f "$LAUNCHD_PLIST" ]; then
        launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
        rm -f "$LAUNCHD_PLIST"
        log_ok "自动备份已移除"
    else
        log_warn "自动备份未安装"
    fi
}

# ============================================================================
# 主入口
# ============================================================================
main() {
    case "${1:-}" in
        --init-repo)
            init_repo
            ;;
        --install-schedule)
            install_schedule
            ;;
        --uninstall-schedule)
            uninstall_schedule
            ;;
        --status)
            show_status
            ;;
        --help|-h)
            show_help
            ;;
        *)
            do_backup
            ;;
    esac
}

main "$@"
