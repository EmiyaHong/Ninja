# ART 素材索引 · 交接文档

> 面向下一个接手本项目的 AI / 美术。**先读本文件，再动素材。**
> 最后更新：2026-10-22 17:58（目录已按画风重组） ｜ 素材根目录：`res://assets/art/`（`E:\Godot\Ninja\assets\art\`）
> 机器可读版：[`art_manifest.json`](art_manifest.json)（逐文件尺寸、内容包围盒、状态、衍生关系）

**一句话**：这是 Godot 4.7 忍者动作游戏的全部美术素材 —— 卡通厚涂「苍爪熊」和几何扁平「几何熊」各占一个文件夹，加一套 42 件透明 UI 组件，共 **84 张 PNG / 47.8 MB**。

---

## 0. 一分钟上手

| 你想做什么 | 打开这个文件 |
| --- | --- |
| 看 Boss 最终长什么样 | `cartoon/stand/cangzhua_stand_01_front.png`（厚涂）／`geometric/geobear/geobear_stand_01_front.png`（几何） |
| 做 Boss 待机转向 | `cartoon/stand/` 或 `geometric/geobear/` 里的 `_01~08_` 八方向（透明底） |
| 做 Boss 攻击动画 | `cartoon/attack/cangzhua_attack_sweep_sheet.png`（已对齐的 4×2 拼版）＋ 单帧 `..._f01~08.png` |
| 搭游戏 UI | `geometric/ui_kit/components/`（42 个透明 PNG，按功能命名） |
| 看 UI 整体设计语言 | `geometric/ui_kit/boards/geometric_ui_concept_v1.png`（定稿母板，六分区） |
| 拿结构化数据给程序/AI | `art_manifest.json` |

⚠️ 三个最容易踩的坑，先记住：
1. **八视图之间存在 7%~34% 的比例漂移**，脚底基线也不统一，直接切帧会跳。
2. **攻击单帧是紧裁切的、画布尺寸各不相同**，不能直接丢进 AnimatedSprite2D 播放。
3. **不要只移动 PNG 而不管 `.import`** —— 导入缓存靠它，要么连它一起搬，要么删掉重建（本目录刚重建过一遍）。

---

## 1. 项目背景（决定素材该长什么样）

- **游戏**：2D 横版/侧视忍者动作游戏，Godot **4.7 / Forward+**。
- **核心玩法**：意念操控飞刀 ＋ 鼠标划线攻击 ＋ 弹反（parry）。这套 UI 就是为「血条／架势条／易伤／弹反火花／划线方向」服务的。
- **唯一 Boss**：苍爪熊。三头身、双足站立、宽肩厚背圆腹短腿；深青蓝皮毛＋米黄口鼻腹部；前臂三块青灰甲片；每爪三枚象牙色长弯爪（武器本体）；琥珀色小眼、倔强有威慑感。轮廓参考《怪物猎人》青熊兽。
- **两条并存的风格线**（同一设计意图，两种画风，不要混用）：

| 文件夹 | 风格 | 用途 |
| --- | --- | --- |
| `cartoon/` | 厚涂卡通风，有毛边纹理、二档阴影、细描边 | 表现力优先的最终形态 |
| `geometric/` | 纯几何（圆头／梯形躯干／六边形巨前臂／三角爪）、粗近黑描边、平涂无阴影、严格 6 色 | 便于拆件与关节动画；UI Kit 统一在这条风格线上 |

- **接入约定**：见 [`../../docs/art-integration.md`](../../docs/art-integration.md)。角色走 `Actor Visual Scene` 或 `Head/Body Texture`（参考尺寸头 46×46、身体 52×70）；武器贴图需要填**刀尖像素坐标**；美术不得影响命中判定。

---

## 2. 目录结构

```
assets/art/
├─ README.md                          ← 本文件
├─ art_manifest.json                  ← 机器可读清单
│
├─ cartoon/                           ← ① 卡通厚涂风（苍爪熊 cangzhua）
│  ├─ stand/     cangzhua_stand_01..08_*.png        站立八视图（透明）
│  ├─ quad/      cangzhua_quad_01..08_*.png         四足八视图（透明）
│  └─ attack/    cangzhua_attack_sweep_f01..08.png  横扫单帧（透明，紧裁切）
│                cangzhua_attack_sweep_sheet.png    4×2 拼版（浅灰底，已对齐）
│
├─ geometric/                         ← ② 几何扁平风
│  ├─ geobear/   geobear_stand_01..08_*.png         八视图（透明，严格 6 色）
│  │             geometric_bear_front_transparent.png   正面生成母图（仅溯源）
│  │  └─ parts/front/  10 件动画拆件（同画布原位）+ pivots.json + 3 张检查图 + README
│  └─ ui_kit/
│     ├─ boards/ geometric_ui_concept_v1.png        ★ UI 定稿母板（42 拆件唯一来源）
│     │  └─ archive/  7 张历史稿（另一版渲染 + 全部废案）
│     └─ components/  42 个透明 UI 件
│
└─ _tools/                            ← 后处理脚本（配方，不是美术资产）
   ├─ SPLITTING_GUIDE.md              ★ 角色拆件制作手册（拆件前必读）
   ├─ _make_transparent.py
   ├─ _compose_attack_sheet.py
   ├─ _clean_flat.py
   ├─ _slice_components.py
   ├─ _split_geobear_front.py         v1 位图抠图版（废弃，仅对照）
   └─ _split_geobear_front_v2.py      v2 矢量重绘版（现行）
```

`*.import` 是 Godot 自动生成的导入缓存，不算美术资产。

---

## 3. 命名与编号规范

**角色**：`<角色>_<姿态|动作>_<NN>_<朝向>.png`，编号两位补零。

| 编号 | 01 | 02 | 03 | 04 | 05 | 06 | 07 | 08 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 朝向 | 正面 | 前右斜45° | 右侧面 | 后右斜45° | 正背面 | 后左斜45° | 左侧面 | 前左斜45° |

**动作序列**：`<角色>_<动作>_fNN.png` + `<角色>_<动作>_sheet.png`。
**UI 件**：`<类型>_<名称>[_<状态>].png`，类型 ∈ `icon / bar / fx / arrow / btn / panel / plate / slider / toggle / checkbox / tabs / curve`。

**镜像关系是既成事实**（像素级验证过，不是"看起来像"）：

| 文件 | 关系 |
| --- | --- |
| `cangzhua_stand_06` / `07` | = mirror(04) / mirror(03) |
| `cangzhua_quad_06` / `07` | = mirror(04) / mirror(03) |
| `geobear_stand_06` / `07` / `08` | = mirror(04) / mirror(03) / mirror(02) |
| `cangzhua_attack_sweep_f08` | **完全等于** f01（同一待机帧） |

改其中一张时记得同步镜像那张，否则八视图会「一半新一半旧」。

---

## 4. 资产清单

以下路径省略所在文件夹：站立图在 `cartoon/stand/`，四足在 `cartoon/quad/`，攻击在 `cartoon/attack/`，几何熊在 `geometric/geobear/`。

### 4.1 苍爪熊 · 站立八视图（8 张，1024×1536，RGBA）

| 文件 | 内容尺寸 | 脚底 y | 备注 |
| --- | --- | --- | --- |
| `cangzhua_stand_01_front.png` | 980×1185 | 1326 | **主视图**；攻击 f01/f08 的来源 |
| `..._02_front_right.png` | 831×1231 | 1389 | -- |
| `..._03_right.png` | 579×1249 | 1392 | 纯侧面 |
| `..._04_back_right.png` | 784×1228 | 1398 | -- |
| `..._05_back.png` | 935×1222 | 1390 | 正背面 |
| `..._06_back_left.png` | 761×1251 | 1410 | = mirror(04) |
| `..._07_left.png` | 575×1270 | 1415 | = mirror(03) |
| `..._08_front_left.png` | 897×1268 | 1429 | 生成图，非镜像 |

→ 高度差 **7.2%**，脚底差 **103px**。

### 4.2 苍爪熊 · 四足八视图（8 张，1024×1536，RGBA）

| 文件 | 内容尺寸 | 脚底 y | 备注 |
| --- | --- | --- | --- |
| `cangzhua_quad_01_front.png` | 955×1149 | 1349 | 最高的一张 |
| `..._02_front_right.png` | 845×866 | 1252 | 明显偏矮（俯视更重） |
| `..._03_right.png` | 888×858 | 1247 | 同上 |
| `..._04_back_right.png` | 873×1024 | 1291 | -- |
| `..._05_back.png` | 888×1058 | 1299 | -- |
| `..._06_back_left.png` | 873×1024 | 1291 | = mirror(04) |
| `..._07_left.png` | 888×858 | 1247 | = mirror(03) |
| `..._08_front_left.png` | 950×1062 | 1346 | -- |

→ 高度差 **33.9%**，是四套里最需要重做对齐的一组。

### 4.3 苍爪熊 · 右臂横扫攻击（8 帧 + 拼版）

| 帧 | 内容 | 画布 | 说明 |
| --- | --- | --- | --- |
| `f01` | 980×1185 | 980×1185 | 待机（复用 stand_01 裁边） |
| `f02` | 958×1163 | -- | 起手，右臂高举、爪尖朝上 |
| `f03` | 921×1075 | -- | 挥出，扫至头部高度 |
| `f04` | 847×1037 | -- | 横扫中段 |
| `f05` | 847×1035 | -- | 横扫后段（与 f04 极接近，易看成重复帧） |
| `f06` | 847×1034 | -- | 收势，手臂沉到腰线（曾重抽 2 次修左臂） |
| `f07` | 955×1109 | -- | 回位 |
| `f08` | 980×1185 | -- | 循环收尾，= f01 |
| `..._sheet.png` | 8 帧 4×2 排布 | 3072×2048 | 单格 768×1024，统一缩放 0.7347 + 脚底对齐；RGB 浅灰底 |

**单帧全部透明、紧裁切**（bbox 即画布边界），所以帧与帧之间没有共同的坐标参考 —— 这是它现在不能直接播的根因，见 §7 P0-2。

### 4.4 几何熊 · 站立八视图（8 张，RGBA）

| 文件 | 画布 | 内容尺寸 | 备注 |
| --- | --- | --- | --- |
| `geobear_stand_01_front.png` | 1254×1254 | 1149×1141 | 母本，6 色严格量化 |
| `..._02_front_right.png` | 1024×1024 | 432×915 | 实际视角约 60~70°，偏侧 |
| `..._03_right.png` | 1024×1024 | 451×919 | 纯侧面 |
| `..._04_back_right.png` | 1024×1024 | 649×908 | -- |
| `..._05_back.png` | 1024×1024 | 921×912 | 正背面 |
| `..._06_back_left.png` | 1024×1024 | 649×908 | = mirror(04) |
| `..._07_left.png` | 1024×1024 | 451×919 | = mirror(03) |
| `..._08_front_left.png` | 1024×1024 | 432×915 | = mirror(02) |

`geometric_bear_front_transparent.png`（1254×1254）是生成原图，19140 种颜色、内容贴到画布底边，**只作溯源，别直接用**。

### 4.5 色板（可直接当规范）

**几何熊 · 严格 6 色**（`_clean_flat.py` 的映射目标，实测文件里只有这 6 色）：

| 用途 | HEX | RGB |
| --- | --- | --- |
| 描边黑 | `#06070B` | 6,7,11 |
| 主体青蓝 | `#196365` | 25,99,101 |
| 米白腹/口鼻 | `#FCECCB` | 252,236,203 |
| 灰甲片 | `#5C5F66` | 92,95,102 |
| 琥珀眼 | `#F0A628` | 240,166,40 |
| 象牙爪/内耳 | `#FFF9E6` | 255,249,230 |

**苍爪熊**（厚涂，颜色有渐变，取主色）：皮毛 `#2D4A50`、暗部 `#1E3036`、腹部 `#E4D3B5`、甲片 `#536568`。

**UI Kit**：描边近黑 `#050D13`｜面板米白 `#F8EDD1`｜底板灰蓝 `#515C67`｜玩家/弹反青绿 `#67D1CF`（深青 `#3D5755`）｜生命红 `#DB6C60`（浅段 `#DA8679`）｜架势金 `#E8B54D`。
语义固定：青绿=玩家能力与选中，暗红=生命危险，琥珀金=架势/弹反，紫/橙红=破防易伤。

### 4.6 UI Kit 展示板（8 张，1536×1024，RGB）

| 位置 / 文件 | 状态 | 说明 |
| --- | --- | --- |
| `boards/geometric_ui_concept_v1.png` | ★ **定稿母板** | 六分区完整，**无水印**，42 拆件的唯一来源 |
| `boards/archive/Redraw_..._T09-14-36.png` | 定稿另一版 | 布局一致但像素不同（全图级微位移），右下有「AI生成」水印；仅对照 |
| `boards/archive/Redraw_..._T08-09-23.png` | 已被取代 | 首次达标（粗线/锐角/大间距），组件位置与定稿不同，**不可拆件** |
| `boards/archive/Use_the_reference_image_ONLY_f_...png` | 废案 | 几何熊风；圆钮只出 3/6、缺对话面板、残留 MODE/CLOSE 文字 |
| `boards/archive/A_single_..._T07-35-09.png` | 废案 | 粗线方块风；组件齐全但有英文标签与伤害数字 |
| `boards/archive/A_single_..._T07-34-19.png` | 失败版 | 描边达标但组件大量缺失 |
| `boards/archive/A_single_..._T07-20-07.png` | 废案 | Minecraft 极简方块风，含文字 |
| `boards/archive/A_single_..._T06-36-59.png` | 参考 | 首版四分区，**组件覆盖最全**（含物品格、技能树、奖励卡、任务条、胜负横幅），当需求清单看 |

### 4.7 UI 拆件 · 42 个（`geometric/ui_kit/components/`，全部透明）

由 `_tools/_slice_components.py` 按手工矩形框 + 自动收紧 + 边缘洪泛去背 + 1px 柔边生成。

| 类别 | 文件（尺寸） |
| --- | --- |
| 生命/架势 | `icon_heart` 82×74 ｜ `bar_health_player` 341×55 ｜ `icon_skull` 99×92 ｜ `bar_health_boss` 879×66 ｜ `icon_shield` 71×85 ｜ `bar_stance` 1120×54 ｜ `icon_shield_cracked` 85×94 |
| 战斗反馈 | `icon_vulnerable` 103×108 ｜ `bar_countdown` 215×37 ｜ `fx_parry_spark` 131×150 ｜ `fx_hit_burst` 150×142 ｜ `icon_guard_break` 135×156 ｜ `plate_hint_small` 253×89 ｜ `plate_hint_large` 404×97 |
| 方向 | `arrow_red_right/left/down` ｜ `arrow_cyan_left/right/up`（约 130×128） ｜ `icon_mouse` 104×139 ｜ `curve_swipe` 340×85 |
| 按钮 | `btn_wide_normal/hover/pressed/disabled`（207/210/207/188 × 92） ｜ 圆钮 `btn_pause/play/retry/settings/back/close`（约 96×95） |
| 面板 | `panel_menu` 442×145 ｜ `panel_dialog` 263×151 ｜ `panel_results` 702×145 |
| 设置 | `icon_speaker` 59×68 ｜ `slider_volume` 364×71 ｜ `toggle_on/off` 125×71 ｜ `checkbox_on/off` 69~72×70 ｜ `tabs_mode` 384×80 |

尺寸即原始像素（母板 1536×1024 上按 1.4222 倍映射得出），UI 里若要 1080p 设计稿尺寸，约等于除以 1.42。

---

## 5. 图像规格与 Godot 导入

- 角色与 UI 件：**RGBA 8bit，真透明**（alpha 有 0 值；UI 件因做了 1px 柔边，边缘有少量半透明像素）。
- 展示板、拼版：**RGB 无 alpha**（浅灰底 `#D9D6D4`）。
- 全部为 Godot 默认导入参数：无损压缩、`mipmaps=false`、`fix_alpha_border=true`、无 VRAM 压缩。
- 纹理过滤未在 `.import` 里设定，走 CanvasItem 的 `texture_filter`；粗描边素材建议 `Nearest` 或 `Linear`＋整数倍缩放，避免描边发虚。
- 尺寸偏大（角色 1024×1536、Boss 血条 879px 宽），入库前建议按实际显示尺寸下采样。

---

## 6. 生产流水线（4 个脚本，都在 `_tools/`）

| 脚本 | 做什么 | 输入 → 输出 | 现在能直接跑吗 |
| --- | --- | --- | --- |
| `_make_transparent.py` | 白底转透明：边缘洪泛 + 封闭亮腔补洞（`BG_TOL=42`、`BRIGHT=238`） | ImageGen 白底图 → cangzhua 八视图 | ✗ 输入已清理，只做参考 |
| `_compose_attack_sheet.py` | 8 帧拼版：去白底 → 裁边 → 统一缩放 → **脚底基线对齐** → 4×2 浅灰板 | 单帧 → `cartoon/attack/..._sheet.png` | ✗ 需改 `FRAMES`（`_atk_*.png` 已删） |
| `_clean_flat.py` | 平涂矢量风清洗：边缘洪泛 → alpha 腐蚀 1px 去毛边 → **6 色最近色映射** | 生成原图 → geobear 八视图 | ✗ 需改 jobs；**色板可直接复用** |
| `_slice_components.py` | 手工矩形框（1080×720 坐标 ×1.4222）拆母板，自动收紧 + 去背 + 1px 柔边 | `boards/geometric_ui_concept_v1.png` → 42 件 | ○ 改 `SRC`/`OUT` 即可重跑（当前写死剪贴板路径） |
| `_split_geobear_front_v2.py` | 角色动画拆件（矢量重绘轮廓+原图内部细节+关节补画+pivots+验收图） | geobear 正面母图 → `parts/front/` 10 件 | ✅ 可重跑；方法论见 **`SPLITTING_GUIDE.md`** |

脚本用 `__file__` 定位，搬进 `_tools/` 后 `BASE` 指向 `_tools/`；要跑得先把 `BASE` 改回素材目录。

**已验证的生成经验（含踩过的坑，复用价值最高）**：

- ImageGen 传 `background:"transparent"` **不生效**，出来的仍是白底 → 必须后处理去背。
- **并行多张会互相覆盖**（同秒时间戳），所有 2D 图必须串行生成、出图即改名。
- 整图生成序列帧**帧序不可控**（曾把主命中帧画成待机）→ 改用"逐帧生成 + 脚本拼版"。
- 图生图做朝向旋转：`input_fidelity=high/medium` 会把角色死死锚在正面，**低 fidelity + "在转盘上旋转 X 度"** 才转得动；从侧面图反向"转回 45°"比从正面转出更稳。
- 平台会给展示板右下角加「AI生成」水印，prompt 写 no watermark 无效。
- **不要用自适应量化**去修毛边（8 色 median-cut 会把灰甲片和琥珀眼合并掉色）→ 用固定色板最近色映射。
- 被删的生成图可从 `C:\Users\hyc\.workbuddy\blobs\` 按修改时间找回。

---

## 7. 已知问题（按严重度）

**P0-1 · 跨方向比例/基线不统一**
站立八视图内容高 1185~1270px（7.2%），脚底 y 1326~1429；四足套 858~1149px（**33.9%**）；几何熊 908~1141px（25.7%）且 01 画布尺寸与其余七张不同。
→ 修法：统一缩放到同一身高、按脚底对齐到同一基线，再导出定尺图集（512² 或 1024²）。

**P0-2 · 攻击单帧画布各异且紧裁切**
`f01` 980×1185、`f03` 921×1075、`f04~f06` 847×10xx，bbox 等于整张画布，帧间没有共同坐标参考。
→ 修法：重排到统一画布（建议 1024×1024，脚底 y=980，身体中心 x=512），保留每帧相对位移。

**P1-3 · 5 个面板/提示条顶部带进了分区标题线**
`panel_menu` 顶部残留「ANELS」字样；`panel_dialog`、`panel_results`、`plate_hint_large`、`plate_hint_small` 顶部各有一条细横线（母板的分区分隔线）。
→ 修法：重切时这 5 个 RECT 的 `y0` 下移 6~10px，或切完擦掉顶部 2~4 行。

**P1-4 · 水印**：仅 `boards/archive/Redraw_..._T09-14-36.png` 有，母板干净，无需处理。

**P2-5 · 几何熊 02 视角偏侧**：标称前右斜 45°，实际约 60~70°，与 04 区分度不足。

**P2-6 · 分辨率过剩**：角色 1024×1536、拼版 3072×2048，导入为无损无 mipmap，包体与显存都偏大。

**已解决**：原 15 个孤立 `.import` 在本次重排时随目录一起清空，Godot 已按新路径重建 84 个，无孤立项。

---

## 8. 缺口（下一个 AI 最可能被要求做的事）

1. 只有一套「右臂横扫」动作，**行走/受击/死亡/弹反/蓄力全都没有**。
2. **没有飞刀贴图**，而 `docs/art-integration.md` 的武器接口要填「刀尖像素坐标」。
3. ~~Boss 没有部件拆分~~ **已解决（正面）**：`geometric/geobear/parts/front/` 10 件 + pivots.json（2026-10-22，**v2 矢量重绘版**，v1 位图抠图版存档于 `parts/front_v1_draft/` 勿用）；其余七个方向未拆。
4. UI 拆件**没有九宫格边距标注**，血条/面板直接拉伸会把描边拉变形。
5. 没有 `.tres`/`SpriteFrames`/atlas 资源，Godot 里仍需手工建 AnimatedSprite2D。

---

## 9. 给 AI 的操作守则

**可以做**
- 新增素材沿用 §3 命名，两位补零，动作图同时出 `sheet`，并按画风放进 `cartoon/` 或 `geometric/`。
- 改图前先读 `art_manifest.json` 里该文件的 `content` 与 `bbox`，别按画布尺寸估算角色大小。
- 要新动作：先用 `_tools/` 里两个去背配方，再过一遍 §7 P0 的对齐。

**不要做**
- 不要只移动/重命名 PNG 而不管 `.import`（要么连它一起搬，要么删掉让它重建；本目录重建后 uid 已变，因此目前没有任何场景引用这些图）。
- 不要用 `boards/geometric_ui_concept_v1.png` 以外的任何展示板拆件（组件位置都对不上）。
- 不要把 `cartoon` 和 `geometric` 混进同一套动画（画风、描边粗细、阴影逻辑完全不同）。
- 不要靠 alpha 通道推断受击区 —— 判定框由场景里的 `Hurtbox` 决定（见 [`../../docs/art-integration.md`](../../docs/art-integration.md)）。
- 不要用自适应量化修毛边，会丢色。

改完素材记得同步更新本文件 §4 的尺寸表和 `art_manifest.json`。
