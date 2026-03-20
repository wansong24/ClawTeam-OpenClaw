#!/usr/bin/env bash
# ============================================================================
# 🧠 Memory-LanceDB-Pro 每日 GitHub 备份脚本
# 版本: v2026.03.20
# 说明: 导出长期记忆并推送到 GitHub 仓库，支持设置定时任务
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
BACKUP_DIR="$HOME/.openclaw/memory/backups"
BACKUP_REPO_DIR="$HOME/.openclaw/memory/backup-repo"
SCOPE="custom:long-term"
MAX_LOCAL_BACKUPS=30  # 保留最近 30 天的本地备份
DATE_TAG=$(date +%Y%m%d)
BACKUP_FILE="memories-${DATE_TAG}.json"
LAUNCHD_LABEL="com.openclaw.memory-backup"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================================================
# 安装定时任务 (macOS launchd)
# ============================================================================
install_schedule() {
    echo -e "\n${CYAN}📅 设置每日自动备份 (macOS launchd)${NC}\n"

    if [[ "$(uname)" != "Darwin" ]]; then
        log_warn "当前系统不是 macOS，请手动设置 cron 定时任务："
        echo "  crontab -e"
        echo "  # 每天凌晨 2 点备份"
        echo "  0 2 * * * $SCRIPT_PATH"
        return
    fi

    # 创建 LaunchAgents 目录
    mkdir -p "$HOME/Library/LaunchAgents"

    # 生成 plist
    cat > "$LAUNCHD_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LAUNCHD_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${SCRIPT_PATH}</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>${BACKUP_DIR}/backup.log</string>
    <key>StandardErrorPath</key>
    <string>${BACKUP_DIR}/backup-error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
    </dict>
</dict>
</plist>
EOF

    # 加载定时任务
    launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
    launchctl load "$LAUNCHD_PLIST"

    log_ok "每日备份定时任务已设置 (每天凌晨 2:00)"
    log_info "plist 文件: $LAUNCHD_PLIST"
    log_info "查看状态: launchctl list | grep $LAUNCHD_LABEL"
    log_info "手动触发: launchctl start $LAUNCHD_LABEL"
    log_info "卸载: launchctl unload $LAUNCHD_PLIST"
}

# ============================================================================
# 初始化 GitHub 备份仓库
# ============================================================================
init_backup_repo() {
    if [[ -d "$BACKUP_REPO_DIR/.git" ]]; then
        return 0
    fi

    echo -e "\n${CYAN}📦 初始化 GitHub 备份仓库${NC}\n"

    read -p "请输入 GitHub 备份仓库 URL (例如 git@github.com:wansong24/openclaw-memory-backup.git): " REPO_URL

    if [[ -z "$REPO_URL" ]]; then
        log_error "仓库 URL 不能为空"
        exit 1
    fi

    mkdir -p "$BACKUP_REPO_DIR"

    # 尝试 clone 或初始化
    if git clone "$REPO_URL" "$BACKUP_REPO_DIR" 2>/dev/null; then
        log_ok "仓库克隆成功"
    else
        log_info "仓库不存在或为空，初始化新仓库..."
        cd "$BACKUP_REPO_DIR"
        git init
        git remote add origin "$REPO_URL"

        # 创建 README
        cat > README.md << 'READMEEOF'
# 🧠 OpenClaw 长期记忆备份

此仓库由 memory-lancedb-pro 自动维护，用于每日备份 OpenClaw 的长期记忆数据。

## 文件说明

- `memories-YYYYMMDD.json` — 每日记忆快照
- `latest.json` — 最新记忆数据（符号链接或副本）

## 恢复记忆

```bash
openclaw memory-pro import memories-YYYYMMDD.json --scope custom:long-term
```

---

*自动生成 — 请勿手动修改*
READMEEOF

        cat > .gitignore << 'GIEOF'
.DS_Store
*.log
GIEOF

        git add -A
        git commit -m "🧠 初始化记忆备份仓库"

        # 尝试推送（如果远程仓库已创建）
        if git push -u origin main 2>/dev/null || git push -u origin master 2>/dev/null; then
            log_ok "初始推送成功"
        else
            log_warn "初始推送跳过 — 请先在 GitHub 上创建仓库: $REPO_URL"
            log_info "创建后运行: cd $BACKUP_REPO_DIR && git push -u origin main"
        fi
    fi
}

# ============================================================================
# 执行备份
# ============================================================================
do_backup() {
    echo -e "\n${CYAN}🧠 Memory-LanceDB-Pro 记忆备份 — $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"

    # 确保备份目录存在
    mkdir -p "$BACKUP_DIR"

    # 步骤 1: 导出记忆
    log_info "导出记忆 (scope: $SCOPE)..."

    local export_path="$BACKUP_DIR/$BACKUP_FILE"

    if command -v openclaw &>/dev/null; then
        if openclaw memory-pro export --scope "$SCOPE" --output "$export_path" 2>/dev/null; then
            local count
            count=$(python3 -c "import json; print(len(json.load(open('$export_path'))))" 2>/dev/null || echo "?")
            log_ok "导出完成: $export_path ($count 条记忆)"
        else
            log_warn "openclaw memory-pro export 失败，尝试直接复制 LanceDB 数据..."
            local db_path="$HOME/.openclaw/memory/lancedb-longterm"
            if [[ -d "$db_path" ]]; then
                cp -r "$db_path" "$BACKUP_DIR/lancedb-snapshot-${DATE_TAG}"
                log_ok "LanceDB 快照已保存"
            else
                log_error "无法导出记忆，数据库路径不存在: $db_path"
                return 1
            fi
        fi
    else
        log_error "openclaw 命令未找到"
        return 1
    fi

    # 步骤 2: 推送到 GitHub
    if [[ -d "$BACKUP_REPO_DIR/.git" ]]; then
        log_info "推送备份到 GitHub..."

        # 复制备份文件到仓库
        cp "$export_path" "$BACKUP_REPO_DIR/" 2>/dev/null || true
        cp "$export_path" "$BACKUP_REPO_DIR/latest.json" 2>/dev/null || true

        cd "$BACKUP_REPO_DIR"

        # 检查是否有变化
        if git diff --quiet && git diff --staged --quiet && [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
            log_info "记忆未发生变化，跳过推送"
        else
            git add -A
            git commit -m "🧠 记忆备份 $(date '+%Y-%m-%d %H:%M')" --quiet
            if git push --quiet 2>/dev/null; then
                log_ok "备份已推送到 GitHub"
            else
                log_warn "推送失败 — 请检查网络连接和仓库权限"
            fi
        fi
    else
        log_warn "GitHub 备份仓库未初始化"
        log_info "运行: $SCRIPT_PATH --init-repo 初始化"
    fi

    # 步骤 3: 清理旧备份
    log_info "清理超过 $MAX_LOCAL_BACKUPS 天的本地备份..."
    local cleaned=0
    while IFS= read -r old_file; do
        rm -f "$old_file"
        cleaned=$((cleaned + 1))
    done < <(find "$BACKUP_DIR" -name "memories-*.json" -mtime +$MAX_LOCAL_BACKUPS 2>/dev/null || true)

    if [[ $cleaned -gt 0 ]]; then
        log_ok "已清理 $cleaned 个旧备份文件"
    fi

    echo ""
    log_ok "备份完成! ✅"
}

# ============================================================================
# 主流程
# ============================================================================
main() {
    case "${1:-}" in
        --install-schedule)
            install_schedule
            ;;
        --init-repo)
            init_backup_repo
            ;;
        --help|-h)
            echo "用法: $(basename "$0") [选项]"
            echo ""
            echo "选项:"
            echo "  (无参数)           执行记忆备份"
            echo "  --install-schedule 设置每日自动备份定时任务"
            echo "  --init-repo        初始化 GitHub 备份仓库"
            echo "  --help             显示此帮助信息"
            ;;
        *)
            # 如果备份仓库未初始化，先初始化
            if [[ ! -d "$BACKUP_REPO_DIR/.git" ]]; then
                init_backup_repo
            fi
            do_backup
            ;;
    esac
}

main "$@"
