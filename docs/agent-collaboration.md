# Ninja 多 Agent 协作手册（DOX）

建立：2026-10-24（Asia/Taipei） · 维护者：Antigravity（协调/文档角色，见 §3）
本文是各 AI agent 接手项目时的入口。冲突时以 `AGENTS.md`（用户规则）为准。

## 1. 项目是什么

- **类型**：Godot 4.7（GDScript，Forward Plus，Windows）2D 单人 Boss 战 Demo，用于**面试作品集**（目标岗位：游戏策划/战斗策划）。
- **核心玩法**：刀/鼠标手势挥砍、弹反（Parry）、Boss 破绽与胜负。重点展示“手感调参—实验—证据—取舍”的设计过程，而非内容量。
- **主场景**：`res://scenes/battle.tscn`；Boss 为几何熊（GeoBear，双爪扫击/下砸）；另有木桩训练、手势实验室（`gesture_lab`）、弹反 A/B 实验室（`parry_ab_lab`）。
- **弹反规则**：用户于 2026-10-24（D018）已确认最终采用 **B 严格反向**（逆着来刀方向划动）；4 号木桩 A/B 对照与 5 号方向手势（`directional_combat.gd`）代码均完整保留，供面试展示实验对比与后续收敛战斗风格。
- **空间移动与飞剑范围（D016–D018）**：1 号模式（曲线挥刀 · 战斗）已加入 WASD 八向移动、3×3 网格地图、跟随相机、飞剑圆内最大攻击范围（260px）、几何熊双爪弹反距离限制、Boss 待机追击 AI 与玩家受击框/走位闪避。
- **状态**：已有 git 基线 `baseline-2026-10-23`；最新自动化检查共 **316 项通过，0 失败**；真人试玩手感尚未最终确认（自动测试通过 ≠ 手感已验证）。

### 目录速览

| 路径 | 内容 |
|---|---|
| `scripts/` | 战斗逻辑：`battle_controller`、`boss_controller`、`weapon_controller`、`directional_combat`、`gesture_input`、`parry_trainer`、`combat_tuning`、`blade_trail`、`geobear_visual` 等 |
| `scenes/` | 场景（battle、boss_view、player_view、training_dummy、各实验室） |
| `data/` | 调参资源，如 `combat_tuning.tres` |
| `tests/` | Godot 内测试：`combat_tests`、`parry_ab_tests`、`geobear_tests`、`directional_combat_tests`、`interaction_tests`、`blade_trail_tests` |
| `docs/` | 设计与交接文档（见 §5） |
| `addons/godot_mcp_toolkit/` + `.mcp-tools/` | Godot MCP 插件与 Node 桥接（见 §6） |

## 2. 协作原则

1. 用户偏好：**设计聊天讨论，Sol 执行实现**；沿用已有合适的执行 agent，不擅自扩大范围。
2. 保留用户未提交的修改（参数、美术、刀光等）。动手前先 `git status`，不得 reset/checkout/clean 他人改动。
3. 同一文件同一时间只允许一个 agent 编辑；开工前在 §7 登记，完成后释放。
4. 状态必须分清：现有实现 / 讨论提案 / 已授权实验 / 已实现待试玩 / 用户确认。不编造指标和手感结论。
5. 设计类结论追加到 `docs/design-journal.md`（保留被修正的历史并写明原因，不记录内部思维链）；实现与验证记录写入 `docs/implementation-status.md` 并链接测试。
6. 提交信息使用中文，沿用现有风格；非用户要求不 push、不改 `.git` 配置。
7. 不改 `project.godot` 的 autoload/插件配置，除非任务明确要求。

## 3. 角色分工

**核心模式（用户 2026-10-24 确认）：Codex 与 Antigravity 是对等的“双执行者”，做同样的活，互为备份。** 任一方额度用尽，另一方无缝接手。因此每次工作结束必须写交接记录，这是接力的唯一依据。

| 角色 | 职责 |
|---|---|
| **用户** | 产品负责人与设计决策者；真人试玩、手感反馈、最终取舍 |
| **Codex** | 执行者：实现代码/场景/测试、跑验证、更新文档；额度可用时优先工作 |
| **Antigravity（Claude Opus 5.5，本 agent）** | 与 Codex 相同的执行者；Codex 无额度时接手，也可并行。偏长的代码审阅、重构、长文档与调研 |
| **Sol / “设计聊天”** | 历史文档中出现的名称（Sol 为执行者，设计聊天负责讨论与 `design-journal.md`）。其工作现由 Codex/Antigravity 承担，沿用同一套规则 |

默认两边都做同样的事、不预设分区；用户若另行指定按擅长领域拆分，以 §7 登记板为准。无论谁做，都遵守 §2，不擅自扩大范围。

### 接力规则

1. 接手前：读 §7 最近条目、`design-journal.md` 近期条目、`implementation-status.md` 末段，并 `git status` / `git log -5`。
2. 工作中：占用文件先在 §7 登记；额度随时可能耗尽，所以每完成一个独立小步骤就更新一次，不要攒到最后。
3. 工作后（或预感额度将尽时）：必须写交接记录。

### 交接格式（任何 agent 完成任务时写入 §7 或实现状态文档）

- 做了什么 / 改了哪些文件
- 验证方式与结果（测试名、通过数、截图路径；未验证项明说）
- 未解决问题与建议下一步
- 需要用户决定的事项

## 4. 验证约定

- 测试均为 Godot 内场景/脚本，用无头或编辑器运行。已知基线（2026-10-23）：战斗 101、A/B 41、GeoBear 89 项检查，0 失败。
- Godot 可执行文件：`E:\Godot\Godot_v4.7.2-stable_win64_console.exe`（控制台版，适合命令行；同目录另有非 console 版）。
- 运行示例（2026-10-24 已验证，输出 `COMBAT_TESTS: 101 checks, 0 failures`）：
  `E:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path E:\Godot\Ninja res://tests/combat_tests.tscn --quit-after 600`
- 其他测试场景同理替换：`parry_ab_tests.tscn`、`geobear_tests.tscn`、`directional_combat_tests.tscn`。沙箱内启动时 MCP 运行时端口注册的 `write_atomic`/日志写入警告可忽略。
- 手势/键盘输入已知有 OS 层差异（IME、焦点、D3D12）；需真人试玩确认，不能只凭自动注入测试宣告修复。
- 日志与截图放 `docs/screenshots/`，临时日志放 `tests/*.log`，不要提交无关产物。

## 5. 文档索引

- `AGENTS.md`：用户规则（最高优先级）
- `docs/design-journal.md`：设计讨论日志（先读近期条目）
- `docs/implementation-status.md`：实现与验证记录
- `docs/demo-roadmap.md`：Demo 路线与阶段清单
- `docs/combat-demo-plan.md`：战斗 Demo 方案
- `docs/parry-ab-playtest.md`、`docs/directional-gesture-playtest.md`：试玩/实验记录
- `docs/git-baseline.md`：基线记录；`docs/art-integration.md` 等：美术接入与提示词

## 6. Godot MCP

- 插件：`addons/godot_mcp_toolkit`（v1.0.4，已在 `project.godot` 启用，autoload `MCPRuntimeServer`）。
- 桥接：`.mcp-tools/bridge/node_modules/@npgamedev/godot-mcp-server`，需 Node 22+（本机使用 `C:\Users\hyc\AppData\Local\pi-node\current\node.exe`）。
- 配置：
  - 项目级 `.mcp.json`（Codex/Claude 等读取）
  - Antigravity：`C:\Users\hyc\.gemini\antigravity\mcp_config.json`，指向同一桥接与项目路径（2026-10-24 添加，需重启 Antigravity 后生效）
- 使用前提：Godot 编辑器已打开本项目并启用插件；多个 agent 同时连接同一编辑器时，避免同时改场景/脚本。
- 编辑器里正在打开的场景若被外部改动，需刷新后再编辑，避免覆盖。

## 7. 当前任务登记板

| 日期 | Agent | 任务 | 占用文件 | 状态 |
|---|---|---|---|---|
| 2026-10-24 | Antigravity | 建立本手册、配置 Godot MCP、补 Godot 路径、确立双执行者规则 | `docs/agent-collaboration.md`、`AGENTS.md` | 完成；验证：combat_tests 101/0；无待办，等用户指派 |
| 2026-10-24 | Antigravity 主聊天（验收）+ 执行子 agent | D016：1 号模式角色移动、飞剑圆内范围、网格地图扩大 | `scripts/battle_controller.gd`、`scripts/gesture_input.gd`、`tests/movement_tests.*`、`tests/combat_tests.gd`、`tests/interaction_tests.gd`、`docs/implementation-status.md`、`docs/design-journal.md` | 完成（已实现待试玩）；验证：movement 39/0、combat 101/0、parry_ab 41/0、geobear 89/0、directional 34/0（共 304 项 0 失败）；已释放全部文件占用 |
| 2026-10-24 | Antigravity | D017：1 号模式飞剑圈严格最大攻击判定范围 + 受击框/进圈高亮可视化 | `scripts/blade_hit_test.gd`、`scripts/battle_controller.gd`、`tests/movement_tests.gd`、`docs/design-journal.md`、`docs/implementation-status.md` | 完成（已实现待试玩）；验证：movement 42/0、combat 101/0；已释放全部文件占用 |
| 2026-10-24 | Antigravity | D018：弹反距离限制（双爪判定框进飞剑圈 + 挥刀触爪）、Boss 追击 AI、玩家受击框与爪击碰撞、确认 B 严格反向、设计思维导图 | `scripts/battle_controller.gd`、`scripts/boss_controller.gd`、`tests/movement_tests.gd`、`docs/design-journal.md`、`docs/implementation-status.md` | 完成（已实现待试玩）；验证：movement 51/0、combat 101/0、parry_ab 41/0、geobear 89/0、directional 34/0（共 316 项 0 失败）；已释放全部文件占用 |

## 8. 致 Codex 的最新交接摘要（2026-10-24，Codex 无额度期间 Antigravity 完成项）

Codex 接手时请直接阅读本节，并对照 `docs/design-journal.md`（D016–D018）与 `docs/implementation-status.md`（末尾 D016–D018 章节）：

1. **我们在你无额度期间做了什么（D016 → D018）**：
   - **D016（1 号模式角色移动 + 飞剑圆 + 3×3 网格地图）**：
     - 在 `scripts/battle_controller.gd` 仅针对 `mode == 0`（按键 1「曲线挥刀 · 战斗」）加入 WASD/方向键八向移动（`move_speed = 320.0`）、地图扩大为 `Rect2(-1152, -768, 3456, 2304)` 网格、跟随 `Camera2D`（开局取景 `(576, 384)` 不变），并将血条/架势条/受击光环移到 `CanvasLayer` 下的 `HudOverlay` 固定在屏幕。
     - 在 `scripts/gesture_input.gd` 将手势采样保留为屏幕坐标（避免走路/镜头滚动污染手势方向与速度），而可见刀尖与扫掠线段转为相机世界坐标并经 `clamp_tip` 限制在玩家周围 `sword_radius = 260.0` 圆内。
   - **D017（飞剑圆作为严格最大可攻击判定范围 + 射程可视化）**：
     - 在 `scripts/blade_hit_test.gd` 新增 `rect_overlaps_circle()` 与 `swept_hits_in_circle()`：要求 Boss 受击框先与飞剑圆相交，且将刀尖与向后 110px 的刀根全部夹取在飞剑圆内再做扫掠碰撞（防止刀尖贴圈边时刀身伸出圈外蹭伤 Boss）。
     - 在 1 号模式地面画出飞剑范围圆与 Boss 受击框，进圈时同步变亮提示“在射程内”。
   - **D018（弹反双爪距离限制 + Boss 追击 AI + 玩家受击框 + B 严格反向定案 + 思维导图）**：
     - **弹反距离限制**：实时读取几何熊左右爪关节生成两个 `124×124` 的爪子判定框（`boss_claw_hurtboxes()`）；1 号模式下只有当 Boss 挥击爪的判定框进入玩家 `sword_radius` 圆内，且窗口内划出 **B 严格反向** 手势才能弹反（禁止远处隔空弹反）。
     - **Boss 追击 AI**：Boss 在 `idle` 阶段以 `boss_move_speed = 150.0` 追向玩家上方对峙点 `player_view.position + Vector2(0, -230)`；玩家跑远超出交战距离时 `boss.can_start_attack = false`，追近后再蓄力出招。
     - **玩家受击框与走位闪避**：新增 `player_hurtbox()`（`64×96`）与 `_boss_attack_hits_player()`，Boss 落爪时刻若玩家已走位跑出 `boss_attack_reach_box()` 则无伤闪避。
     - **用户设计拍板**：正式选定 **B 严格反向**（`training_rule` 默认值已改为 `1`）；5 号方向手势（`directional_combat.gd`）的设计目的明确为“限制玩家不能永远在远处安全打击”，代码完整保留供后续收敛统一战斗风格；已在 `docs/design-journal.md` D018 绘制 Mermaid 思维导图。
2. **新增与修改的测试（全部 0 失败，共 316 项）**：
   - 新增 `tests/movement_tests.gd` + `tests/movement_tests.tscn`：**51 checks, 0 failures**
   - `tests/combat_tests.tscn`：**101 checks, 0 failures**（仅将第 90 行远点刀尖坐标断言改为 `battle.clamp_tip(Vector2(730, 280))`）
   - `tests/parry_ab_tests.tscn`：**41 checks, 0 failures**
   - `tests/geobear_tests.tscn`：**89 checks, 0 failures**
   - `tests/directional_combat_tests.tscn`：**34 checks, 0 failures**
3. **当前未提交改动与建议下一步**：
   - 未执行 `git commit`（保留用户对提交节奏的控制；用户原有的 `data/combat_tuning.tres` 调试参数、美术、刀光均完好未动）。
   - 下一步待用户在编辑器内按 `F5` 真人试玩 1 号模式（WASD 移动 + 熊追人 + 双爪进圈弹反/走位闪避），根据手感反馈调整移速/半径，或推进 `docs/demo-roadmap.md` 阶段 2（Boss 连段招式表编排）。

