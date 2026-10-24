# 几何风基础 UI 设计稿

本稿由内置 imagegen 生成，是组件视觉参考，尚未拆分为透明素材或接入 Godot。

图片：assets/art/ui_kit/geometric_ui_concept_v1.png

## 基础需求

- 玩家血条、Boss 血条：当前血量、损失残留、数值文字位置。
- Boss 架势条：从满到空，盾形标识，清空后破防。
- 易伤提示：紫色裂盾、剩余时间条、倍率文字位置。
- 方向提示：Boss 右、左、下；对应玩家左、右、上。以屏幕方向为准。
- 战斗反馈：弹反、受击、破防图标，通用文字底板。
- 按钮：普通、悬停、按下、禁用。
- 功能图标：暂停、继续、重试、设置、返回、关闭。
- 面板：暂停菜单、教学、胜负结算。
- 设置控件：滑条、开关、复选框、三项模式标签。

未来需要时再补充技能冷却、装备栏、物品提示、存档列表和键位重设；本次没有要求制作这些扩展。

## 使用说明

文字、血量、倍率由 Godot 实时绘制。血条的外框、底槽和填充需独立制作；填充变化不能缩放外框。按钮和面板需适配拉伸，边框厚度保持一致。当前图有少量明暗修饰，正式素材可统一为纯色色块。图内英文栏目名是设计稿标注，不属于游戏组件。方向箭头以图标表达，不依赖颜色；敌人和玩家提示应明确标注来源。

## 实际生成提示词

```text
Use case: ui-mockup. Generate a single polished GAME UI COMPONENT DESIGN SHEET for a beginner's 2D mouse-gesture melee combat game. Use the attached geometric bear ONLY as a style and palette reference, do not draw the bear or any character. Flat geometric shapes, circles, rectangles with modest clipped corners, hexagons, triangles; extremely consistent bold near-black outlines, simple solid fills, easy to reproduce in Godot. Dark teal #285C60, warm ivory #F5E8C8, slate gray #626873, near-black #12171D, restrained coral red #D76861 for health and danger, amber #E5AD3D for posture, pale cyan #85D9D0 for parry, violet #9B7BC0 for vulnerability. No gradients, texture, faux 3D, bevels, metallic ornament or glow. Crisp readable large shapes.

Landscape component atlas on warm off-white background, generous spacing, clean alignment, six organized horizontal bands. Small English category labels OUTSIDE components only; no tiny explanatory text. All requested elements must be fully visible, no overlaps, plenty of padding. This is a coherent professional design specification sheet, not a screenshot or gameplay scene.

Band 1 label HEALTH / POSTURE: two red horizontal health bars, one compact player bar with simple heart icon and one long boss bar. One long amber posture bar with hexagonal shield icon. Each bar has bold outlined frame, slate dark empty track and a partially filled flat color region; a small pale red trailing loss segment on health. Put a SMALL empty cracked-shield posture variant at end. Distinct sizes, identical design system.
Band 2 label COMBAT: purple vulnerability badge with cracked shield and slim countdown bar beneath; three standalone feedback tokens (cyan parry spark, coral damage burst, amber broken shield), two empty small message backplates. Clear silhouette differences not just color.
Band 3 label DIRECTIONS: six square icon tiles in TWO clearly grouped triplets: coral enemy arrows RIGHT, LEFT, DOWN; cyan response arrows LEFT, RIGHT, UP in matching positions. All arrows straight and highly legible, no circular arrows in this row. At right a simple mouse silhouette with highlighted left button and one smooth gesture curve with start dot and arrowhead.
Band 4 label BUTTON STATES: four identical wide rectangular blank text buttons side by side: DEFAULT dark teal, HOVER lighter teal plus ivory inset border, PRESSED darker teal and visibly lowered inset face, DISABLED slate gray. Below or adjacent six circular icon buttons: pause (two bars), play (triangle), retry (circular arrow), settings (simple gear), back (left arrow), close (X).
Band 5 label PANELS: three empty reusable panel sizes side by side: medium menu panel with empty title tab and small close X in corner; smaller tutorial speech panel; wide result panel with empty banner title space. Ivory inner fills, teal title tabs, thick black borders. Do NOT put mini UI components inside these panels; leave them empty for runtime text.
Band 6 label SETTINGS: one horizontal volume slider with circular thumb, toggle switch ON and OFF, checkbox unchecked and checked, a three-tab selector with first tab selected. Align neatly.

The art should look like the UI belongs in the same world as the reference bear. Keep all borders approximately the same visual thickness. Prioritize completeness, spacing and readability over decoration. No watermark, no characters, no scenery.
```

