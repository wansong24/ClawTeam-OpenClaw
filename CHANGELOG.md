# 变更日志 / Changelog

所有重要变更将记录在此文件中。版本号使用日期格式。

---

## [v2026.03.20] - 2026-03-20

### ✨ 新增 (Added)

- **CT 快捷命令系统**: 用户只需说 `CT + 任务描述` 即可一键启动多 Agent 协作
  - 在 SKILL.md 的 `description` 中注册 `CT` 作为触发词
  - 新增「CT 快捷命令」专门章节，包含 5 个常用示例
  - 新增 CT 命令处理流程图

- **中文文档支持**:
  - 新增 `README_CN.md` 中文主文档
  - SKILL.md 全面双语化（中文主 / 英文辅）

- **故障排除指南**: SKILL.md 新增 7 类常见问题及解决方案表格

- **版本管理**: 新增 `CHANGELOG.md`，版本号使用日期格式

### 🔄 改进 (Changed)

- **SKILL.md 完全重写**:
  - 所有章节标题和关键说明提供中英双语
  - 命令参考表格增加中文描述列
  - Leader 编排模式增强：更详细的 5 阶段说明
  - 监控脚本增加中文状态输出和阻塞统计
  - 决策规则从列表改为结构化表格
  - 添加 emoji 图标提升可读性

- **数据存储位置说明**: 新增目录结构树状图和 `CLAWTEAM_DATA_DIR` 环境变量说明

### 📋 文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `skills/openclaw/SKILL.md` | 重写 | 双语 + CT 快捷命令 + 故障排除 |
| `README_CN.md` | 新增 | 中文主文档 |
| `CHANGELOG.md` | 新增 | 变更日志 |

---

## [上游版本] - 基于 HKUDS/ClawTeam

原始 ClawTeam 项目的 OpenClaw 适配 fork。详见 [上游仓库](https://github.com/HKUDS/ClawTeam)。
