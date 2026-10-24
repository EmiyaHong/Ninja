# 挥刀轨迹 Shader 选型与调节手册

更新：2026-10-22。适用项目：Ninja / Godot 4.7.2。

本手册已经核对网站说明、示例代码和当前项目的美术接口；尚未把下列第三方 Shader 导入本项目验证。先挑喜欢的视觉，再做相应适配。

## 1. 挥刀轨迹是不是用 Shader 画的？

本项目的效果由三部分组成：

1. 输入脚本记录刀尖经过的位置，决定真实曲线。
2. Line2D 将这些位置连接成有宽度的带状图形。
3. 贴图和 Shader 决定这条带子内部的颜色、纹理、流动、透明度等效果。

Shader 可以参与绘制，也能自己生成固定刀光形状，但不会自动知道刀尖过去经过哪里。我们的任意曲线依然由采样数据提供。伤害和弹反单独计算，改变刀光宽度不会扩大命中范围。

无需自定义 Shader，也可以用 Line2D 的颜色、渐变和宽度变化做简单刀迹；如果想加流动能量、噪声溶解或特殊边缘，再用 Shader。

参考：[Line2D 官方说明](https://docs.godotengine.org/en/4.7/classes/class_line2d.html)、[CanvasItem Shader 官方说明](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/canvas_item_shader.html)。

## 2. 在哪里挑效果

总入口：[Godot Shaders：2D / Canvas item](https://godotshaders.com/shader-type/canvas_item/)。

挥砍分类：[Slash](https://godotshaders.com/shader-tag/slash/)。分类里同时有 2D 与 3D，选择时看 Canvas item 标记；Spatial 是 3D，不能直接挂到本项目的 Line2D。

### A. Energy Beams：能量、电流、意念感

[预览与代码](https://godotshaders.com/shader/energy-beams/)

作者提供能量束、颜色、外层颜色、粗细、噪声、速度和显隐进度参数。适合作为意念飞刀的能量风格参考。

适配说明：原例挂在 ColorRect，生成能量束；不是现成的任意曲线拖尾。源码含旧版 Godot 的 hint_color 等语法，需要迁移到 Godot 4，并适配轨迹带子的坐标、透明度和淡出。选中这个风格后再做这些改动。

优先关注的实际参数：color、outline_color、thickness、outline_thickness、energy、speed、progress。发光扩散还涉及显示范围与渲染设置，不能只把颜色数值拉高。

### B. Pixel Slash shader：像素斩击

[预览与代码](https://godotshaders.com/shader/pixel-slash-shader/)

支持像素化、边缘参差、颜色和厚度渐变、弧度、抖动消隐。适合像素美术。

适配说明：原版在 Sprite 上生成固定弧形，适合 Boss 单次挥刀或命中特效。若用于玩家任意曲线，需要将像素边缘和配色方法迁移到曲线材质，不能直接把固定弧形当作鼠标路径。

优先关注的实际参数：pixelScale、minRadius、maxRadius、maxAngle、maxRandomness、visibleArc、dither。还需配置 thicknessGradient 与 color 两张渐变纹理。

### C. Circular Crescent Slash 2D Mask：干净月牙刀光

[预览与代码](https://godotshaders.com/shader/circular_cresent_slash_2d_mask/)

用两个圆和角度遮罩形成月牙，结构较简单。可以配合自己画的纹理，再播放刀光显现和消失。

适配说明：原版需要有可见纹理的 Sprite2D，是固定月牙形，适合 Boss 的清楚、简洁斩击；玩家任意曲线仍需另外适配。

优先关注的实际参数：inner_radius、outer_radius、inner_offset、outer_offset、lead_angle、tail_angle。

### D. Procedural Idyllic Slash (2D)：可高度定制的斩击

[预览与代码](https://godotshaders.com/shader/procedural-idyllic-slash-2d/)

作者提供演示工程和详细说明，可调形状、扭曲、颜色及动画，适合挑复杂的魔法刀光风格。

适配说明：原例用于 ColorRect 或方形 Quad；参数超过 100 个，作者明确说明未优化。适合作为效果参考或特定招式表现，不建议新手第一天逐项调完，也不应当作无需适配的 Line2D 拖尾。

### E. Line2D animation：简单流动条纹

[预览与代码](https://godotshaders.com/shader/line2d-animation/)

这是直接面向 Line2D 的流动条纹示例，可以作为学习轨迹材质的简单样例；外观更接近流动标记线，需要进一步美化才像刀光。

作者要求 Texture Mode 为 Tile，而本项目目前由脚本设为 Stretch，需要先改成可选模式并测试。这个 Shader 自己写入颜色，因此不会使用 Line2D 的 Gradient 或纹理颜色。

可先调实际参数 color1、color2、opacity、speed、direction、frequency。页面提到的 amplitude 在当前展示代码中没有影响最终 COLOR，不建议把它作为有效调节项。

上述作者页面均列有许可。实际采用时保留相应来源与许可记录；示例图片、视频里的素材不自动等同于可复用的 Shader 代码。

## 3. 你选中后，要告诉我什么

把页面链接发来，附一句希望保留的特点，例如：

> 喜欢 Energy Beams 的青白配色和柔软边缘，但不要闪电抖动，希望是一条短而细的刀迹。

或者：

> 喜欢 Pixel Slash 的像素边缘，玩家要沿鼠标曲线走，Boss 用月牙斩击。

选择视觉不等于必须照搬全部代码。我们会保留真实曲线和既有战斗规则，适配喜欢的外观，再把常用参数整理出来。

## 4. 当前项目里如何挂材质

以下入口来自当前 scripts/weapon_controller.gd 和 docs/美术资源接入说明.md。

1. 结束正在运行的游戏，保持 Godot 编辑器打开。
2. 在 FileSystem 面板打开 scenes/player_weapon.tscn。Boss 则打开 scenes/boss_weapon.tscn。
3. 选中场景根节点，在 Inspector 找到 Trail appearance only 属性组。
4. 在 Trail Material 新建 ShaderMaterial，或拖入已适配的 .tres 材质。
5. 展开 ShaderMaterial，将 .gdshader 文件赋给 Shader，再展开 Shader Parameters 调整它公开的参数。裸 .gdshader 不能直接赋给 Trail Material。
6. 保存场景和材质，按 F5 运行，再切换自由练刀模式观察圆弧、S 形和折返。

不要只改 Trail 子节点的 Material：启动时根节点的 Trail Material 会覆盖它。将常用材质保存在 assets/materials/ 下，方便下次找到。

玩家与 Boss 如果需要不同效果，应使用不同的 ShaderMaterial 资源；它们可以共用同一个 Shader 文件。修改同一份共享材质参数会影响所有使用它的节点。[ShaderMaterial 官方说明](https://docs.godotengine.org/en/4.7/classes/class_shadermaterial.html)

## 5. 调节时看哪几个参数

| 想改变什么 | 当前入口或所需支持 | 建议操作 |
| --- | --- | --- |
| 轨迹粗细 | 根节点 Trail Width | 先试 3、6、12，比较识别度和遮挡程度 |
| 基础颜色 | 根节点 Trail Color，或材质自己的颜色参数 | 若 Shader 完全重写颜色，应改 Shader Parameters 中的颜色 |
| 透明程度 | Trail Color 的 Alpha，或 Shader 的 opacity | 从半透明开始，避免遮住 Boss 的预警；Shader 需保留对应透明度输入 |
| 纹理质感 | 根节点 Trail Texture，或 Shader 专用纹理参数 | 可用透明背景条带做刀锋、刷痕或能量纹理；具体布局按最终 Shader 约定 |
| 图案流动 | Shader 的 speed 等参数 | 先静止再慢慢增加，不改变真实挥刀速度 |
| 边缘扭动 | Shader 的 noise/distortion/energy 等参数 | 从低值开始，避免视觉刀迹离实际路径太远 |
| 消散效果 | Shader 的 progress/dissolve 等参数及动画驱动 | 由脚本或动画持续更新；参数名字随 Shader 不同 |
| 短拖尾保留多久 | 需要轨迹脚本提供点的时间和寿命 | 当前没有寿命滑块，不能只靠材质增加这个行为 |

这里的通用词不是每个 Shader 都具有的固定字段。完成适配后，以该材质实际公开的参数为准。

当前版本在按住时保留整笔轨迹，松开时清除。若想要“刀尖后方只保留最近约 0.15 秒”的短拖尾，需要后续给显示轨迹加寿命，保留战斗采样的独立性。调低 opacity 只能让整条线变透明，不会自动删除旧路径。

推荐调节顺序：颜色 → 宽度 → 透明度 → 流动速度 → 噪声 → 淡出。每次只改一项，并保存一个满意的材质预设。初次无需编辑 Shader 代码。

## 6. 常见情况

- 参数改了没反应：先确认改的是根节点所用的材质；再确认 Shader 是否使用该参数。当前项目的默认材质为空，只有原始线条，没有 Shader Parameters。
- 效果是一整块方形或月牙，没有沿鼠标走：所选代码生成的是固定区域效果，需要适配曲线坐标，不是鼠标输入出了问题。
- 越拉长轨迹图案越大：当前纹理模式是 Stretch，会把纹理拉伸到整条线。需要稳定重复密度时可改 Tile，但须同时考虑 Shader 的坐标用法与重复设置。
- 辉光边缘被切掉：Shader 的绘制范围受承载它的几何形状限制，需要预留更宽的显示范围或使用合适的辉光方案。
- 调粗刀迹后伤害范围不变：这是预期。Trail Width 只改外观，真实武器尺寸另有参数。

完整素材挂接说明另见 [美术资源接入说明.md](美术资源接入说明.md)。
