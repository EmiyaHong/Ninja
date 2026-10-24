# Ninja 项目协作约定

## 设计讨论日志

用户于 2026-10-22 明确要求：在“战斗逻辑”聊天中讨论的每个问题、思路和拆解，应保存到 Godot 项目，供日后回顾；项目计划作为面试 Demo。

- 日志入口：`docs/design-journal.md`。继续该聊天、接手其战斗设计工作时，先阅读日志近期条目，并在本轮结束前记录新增的实质问题、用户反馈、方案、取舍、决定与验证状态。
- 记录可回顾的设计依据与结论，不记录内部思维链，不必复制所有聊天原文。重要用户要求可短引述。没有新设计内容的工具轮询不单独记条目。
- 清楚区分：现有实现 / 讨论提案 / 已授权实验 / 已实现待试玩 / 用户确认。建议与自动测试通过不能写成用户已确认或手感已验证。
- 追加记录，保留被修正的历史结论及修正原因；必要时更新首页状态索引。日期使用 Asia/Taipei。
- 设计日志不替代执行方案及实现交接。实际代码与验证记录分别链接 `docs/implementation-status.md` 和相关测试/试玩文档；避免两名执行者同时编辑同一文件。
- 面试材料应能追溯“问题 → 假设 → 实验 → 证据 → 取舍”，如实区分用户提出的问题、设计讨论、Sol 辅助实现及真人试玩反馈，不编造指标和成果。

## 本轮职责与范围

- 用户偏好：设计聊天讨论，Sol 执行实现；沿用已有合适执行聊天，不擅自扩大实现范围。
- 保留用户当前参数、美术、刀光和其他未提交修改。弹反方向规则已由用户于 2026-10-24（D018）确认为 **B 严格反向**；木桩 A/B 对照与 5 号方向手势（`directional_combat.gd`）代码均保留，不得擅自删除。

## 多 Agent 与 GitHub 团队协作强制规范（Codex 与 Antigravity 必须共同遵守）

- **对等双执行者**：Codex 与 Antigravity 是对等执行者，任一方额度用尽由另一方接手。
- **开工前必读**：任何 Agent 接手任务前，必须先读 [`README.md`](README.md)、[`docs/agent-collaboration.md`](docs/agent-collaboration.md)（§7 任务登记板与 §8 最新交接摘要）、[`docs/design-journal.md`](docs/design-journal.md) 近期条目及 [`docs/implementation-status.md`](docs/implementation-status.md) 末尾，并执行 `git status` / `git log -5`。
- **收工前必写（硬性要求，服务人类协作者与对端 Agent）**：每次完成任务或额度即将耗尽前，必须同步更新以下文档，清楚回答**「这次干了什么、当前进行到哪里、下一步要干什么」**：
  1. [`docs/implementation-status.md`](docs/implementation-status.md)：追加本次改动文件、核心逻辑、自动化测试结果与未验证项。
  2. [`docs/design-journal.md`](docs/design-journal.md)：若有新设计讨论/决策/取舍，追加 `Dxxx` 条目并更新顶部状态索引。
  3. [`docs/agent-collaboration.md`](docs/agent-collaboration.md)：更新 §7 任务登记板（释放文件占用）及 §8 最新交接摘要。
  4. [`README.md`](README.md)：若里程碑、玩法规则或操作方式发生变化，同步更新首页进度表与下一步清单。
- **Git 提交规范**：验证通过并更新上述文档后，使用中文提交信息执行本地 `git commit`；若已配置 GitHub 远程且用户授权推送，执行 `git push`。

