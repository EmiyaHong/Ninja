# 美术与刀迹 Shader 接入

玩家仍使用几何占位；Boss现使用几何熊正面v2.1十件关节场景。接口已经接线并在Godot运行验证。美术不负责输入、伤害或弹反。

## 几何熊当前接入（2026-10-22）

- 正面固定站位；素材总README中的横版/侧视说明不适用于当前游戏。八方向站立图保留供未来转向，本轮没有把它们当攻击动画帧。
- 正式素材只读使用 `assets/art/geometric/geobear/parts/front/` v2.1十件，保留手掌顶部与爪根不封黑线的设计。没有修改PNG、pivots.json或旧稿。
- `scenes/boss_view.tscn` 的 Actor Visual Scene 指向 `scenes/geobear_visual.tscn`，Actor Scale=1。实际十件和关节在该可复用场景内，行为在 `scripts/geobear_visual.gd`。若只想替换头/身体贴图，先清空 Actor Visual Scene；整体视觉场景优先于单张贴图。
- 母图所有部件1254×1254同画布原位。Rig以0.22缩放；原始脚底根点(627,1164)作为局部原点，GeoBear在Boss站位下偏移(0,164)。Boss逻辑站位仍为(576,286)，显示脚底约在(576,450)，不影响固定站位接口。
- 每个关节的局部位置=`自身母图pivot - 父关节母图pivot`；torso用`(627,590)-(627,1164)`。每个Sprite2D `centered=false`，偏移=`-自身母图pivot`。不裁图、不猜测贴图中心。
- 肩→肘→腕继承旋转，Sprite按JSON绘制顺序单独设置z序；没有骨骼/IK。`UpperArmR`是角色右臂、屏幕左边，不能与屏幕左右混淆。
- 右爪执行屏幕左→右；左爪执行右→左；双爪同步下劈。每条爪链的`Claw/StrikeTip`是实际爪尖VFX挂点，位于腕部局部(0,126)，随整条手臂运动。爪没有挂到远处的飞行武器节点。
- Boss的旧悬空BossWeapon节点不再实例化。`scenes/boss_weapon.tscn`仅保留为旧占位资源；玩家飞刀、材质与轨迹场景保持原样。
- 动作由现有Boss/trainer的阶段、deadline与时钟逐帧驱动：蓄力→最后不超过0.16秒快速挥击→原命中时刻→收招；挥击段位于当前弹反窗口内。弹反立即改为回震，破防使用低头垂臂和紫色提示。视觉没有独立伤害计时器、爪碰撞或额外伤害回调。
- `Boss Hurtbox Local`有意调整为`(-70,-100,140,214)`，覆盖新熊头部和躯干，不包含远处活动手臂/爪；不从alpha自动生成。旋转关节或替换视觉不会自动修改该矩形。

已通过89项几何熊检查，以及101项战斗、41项A/B回归；实际运行截图见 `docs/screenshots/geobear-*.png`。当前动作是正面剪纸关节插值，极端姿态有描边叠压、轻微脚部摇摆，尚不是完整角色动画。VFX仅作显示，双爪仍只有一次Boss伤害结算，弹反仍不要求鼠标碰到爪。

## 文件与入口

把角色、武器贴图和自己的视觉场景放到 `assets/art/`，材质/Shader/刀迹纹理放到 `assets/materials/`。在 FileSystem 面板双击下列场景，选中根节点，在 Inspector 调整导出属性，保存后 F5 运行：

| 场景 | 可配置项目 |
| --- | --- |
| `scenes/player_view.tscn` | 玩家头、身体、整套视觉、可选肩部挂点 |
| `scenes/boss_view.tscn` | Boss整体视觉场景，默认接入十件几何熊 |
| `scenes/player_weapon.tscn` | 飞刀贴图/视觉场景、贴图刀尖、刀迹材质/纹理/宽度/颜色 |
| `scenes/geobear_visual.tscn` | Boss肩、肘、腕、爪尖与十件贴图，当前实际使用 |
| `scenes/boss_weapon.tscn` | 旧悬空武器占位资源，当前不实例化 |

战斗和所有训练模式共享这些场景。保留根节点的脚本；把自己的美术场景赋给下述视觉属性。不要用纯美术根节点取代控制脚本。

## 角色、头身体与可选手臂

- `Head Texture` / `Body Texture`：分别指定贴图。贴图按原像素尺寸、居中绘制，默认头中心 `(0,-45)`、身体中心 `(0,18)`；参考尺寸为头 `46×46`、身体 `52×70`。
- `Head Offset` / `Body Offset`：调整贴图中心。角色根节点的 `(0,0)` 仍是固定站位，不随贴图尺寸改变。
- `Actor Visual Scene`：也可以指定一个 `Node2D` 美术场景，整体挂在 `VisualRoot` 下，优先于两张贴图。美术场景根原点对齐上述角色根原点；默认占位头顶 y=-68、脚底 y=53。`Actor Scale` 只缩放显示，不会改变受击区。
- 玩家与 Boss 均有 `LeftShoulder`、`RightShoulder` 两个可选 `Marker2D`（以屏幕左右命名）。需要手臂时，将手臂视觉场景作为相应 Marker 的子节点，手臂原点放在肩部。位置通过根节点 `Left/Right Shoulder Position` 调整；Boss 的位置与挂点子树一起按 Actor Scale 放大。
- 挂点可以为空、隐藏或删除。`VisualRoot` 的内容由视觉属性生成，不要在其下直接保存手臂。没有骨骼或 IK。

玩家武器是独立的飞刀节点，没有挂在手臂下，也不读取肩/手/握柄。松开左键回到独立悬浮位置；没有手臂也能使用全部玩法。

## 武器：刀尖基准不会随贴图漂移

武器节点结构：

```text
PlayerWeapon（玩家；Boss现由关节爪替代）
  Trail                  独立 Line2D，位于游戏视口坐标
  BladePivot             位置=实际刀尖；局部 +X 指向刀尖朝向
    Tip                  Marker2D，固定局部 (0,0)
    Visual               仅美术缩放
```

简单贴图用 `Blade Texture`。`Texture Tip` 填写**源图片左上角为原点的刀尖像素坐标**；例如 110×10 横向刀图、刀尖在最右端中线，填 `(110,5)`。系统以 Sprite2D 非居中方式放图，并偏移 `-Texture Tip`，使这个像素对齐 `Tip`。贴图默认刀身从刀尖沿局部 **-X** 延伸，源图片刀尖应朝右。

`Visual Scale` 仅缩放刀尖下面的美术，刀尖自身不动。复杂武器赋给 `Blade Visual Scene`（优先于贴图）：该 `Node2D` 场景的原点必须就是刀尖 `(0,0)`，刀身沿 -X 延伸。保留 `Tip` 在 BladePivot 原点，不把它移进可缩放的 Visual。

`Blade Length` / `Blade Width` 是明确的**玩法刀刃尺寸**（默认 110/10）。换贴图、贴图偏移、材质、Visual Scale 不会自动改变它们。若以后决定更换实际武器尺寸，应单独有意调整这两个值；只换外观无需调整。

Boss 的受击区在主场景根节点 `Boss Hurtbox Local`，当前相对Boss站位为`(-70,-100,140,214)`，覆盖几何熊头部和躯干的简单矩形。该区域不从贴图透明像素、缩放或Shader推导。木桩模式会画出它。

## 刀迹材质与 Shader

选择武器场景根节点的 `Trail appearance only` 属性组：

1. `Trail Material` 新建或拖入 **ShaderMaterial**，在其中的 Shader 属性指定自己的 **canvas_item Shader**。也可指定其他兼容 2D Material。不要把裸 Shader 直接拖进 Material 字段。
2. `Trail Texture` 指定可选纹理，当前以 `Line2D.LINE_TEXTURE_STRETCH` 沿整条路径铺设。
3. `Trail Width` 为显示宽度（逻辑像素），`Trail Color` 为线条颜色。材质为空时照常显示原来的半透明青色轨迹；纹理为空也可见。

这些导出值会在启动时实际赋给 `Trail` 节点。应修改根节点的导出值；直接修改子节点材质会在启动时被根配置覆盖。运行态脚本若改了这些资源，调用武器的 `apply_appearance()` 即可更新。

Shader 只能改变呈现。线宽、纹理、顶点扭曲、颜色和透明度不会放大受击范围，不会改变鼠标采样、局部方向或弹反时间窗口。不要让显示效果反过来读写战斗数据。

## 已验证与恢复

`tests/combat_tests.tscn` 用内存中的 GradientTexture2D、临时粉色 ShaderMaterial、原生三角形 PackedScene 验证上述接口：Line2D 确实变成粗粉色刀迹，头/身体/刀刃确实换成纹理，整套视觉场景确实实例化，刀尖 Marker 与实际刀尖仍重合。把可选肩部挂点全部移除后，飞刀与伤害仍正常。将刀迹加粗到100像素也不会扩大命中区。

测试后全部恢复占位资源，没有将临时材质写入正式场景。实际预览截图在 `docs/screenshots/art-interface-preview.png`；当前正常外观见 `dummy-vulnerable.png`。用户自己的修改若要恢复，只需清空上述纹理/视觉场景/材质属性，并将刀迹宽度设3、颜色恢复半透明青色。
# 编辑器预览补充（2026-10-22）

打开 `scenes/battle.tscn` 的 2D 视图即可看到几何熊、玩家占位外形及待机刀示意。左侧选择 PlayerBody / BossBody 可调整位置；运行时复用这些节点。几何熊在 `boss_view.tscn` 的 VisualRoot/GeoBear 下，部件是实际 Sprite2D。EditorPreview 只在编辑器显示，血条和战斗 HUD 在 F5 后出现。预览截图：`docs/screenshots/editor-stage-preview.png`。

