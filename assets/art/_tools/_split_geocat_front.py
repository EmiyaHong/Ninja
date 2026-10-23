# -*- coding: utf-8 -*-
"""geocat front split — 剪纸式动画拆件（正面母图 -> 7 件）。

与 geobear v2 的差异：geocat 正面母图是 AI 生成图（非严格平涂量化色），
所以本脚本不重绘轮廓，而是：
  - 可见区域 = 原图像素按区域掩码精确切分（保留原描边与原配色）；
  - 隐藏连接区 = 纯色补画（奶油/米白椭圆包，无描边，拼装后被邻近部件遮盖）；
  - 切割线走在"被遮盖区"或"无线区"（腿根藏在躯干底边线之后、
    头颈中央走在白色口鼻-胸腹连续区、尾根藏在躯干后面），
    拼装后不产生双重黑边。

拆分清单（7 件；四足猫没有手臂/护甲/爪子，对应熊的上臂/前臂/掌就是四条腿）：
  head / torso / tail / leg_fr / leg_fl / leg_br / leg_bl
  （f=前 b=后，r/l 按角色自身；正面图角色右侧=屏幕左侧）

输出：geometric/geocat/parts/front/{7 件 PNG, pivots.json,
assembled_preview.png, parts_preview.png, articulation_preview.png, README.md}
"""
import json
import math
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ART, "geometric", "geocat", "geocat_stand_01_front.png")
OUT = os.path.join(ART, "geometric", "geocat", "parts", "front")
os.makedirs(OUT, exist_ok=True)

W = H = 1024
CREAM = (232, 214, 190, 255)     # 身体奶油（补画用）
WHITE = (250, 244, 230, 255)     # 胸腹米白（颈桩补画用）

orig = Image.open(SRC).convert("RGBA")
OA = np.array(orig)
OPAQUE = OA[:, :, 3] > 0
DARK = (OA[:, :, :3].astype(int).sum(axis=2) < 120) & OPAQUE   # 近黑描边


def poly_mask(pts):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return np.asarray(m) > 0


# ---------------------------------------------------------------- 区域划分
# 尾巴可见区多边形：左缘贴实测分隔线（头腮锯齿与尾左线之间 x≈650；
# 下段躯干右缘线 x 665→704）——分隔线归尾巴/躯干各自保留，不切穿描边
TAIL_POLY = poly_mask([
    (722, 148), (765, 136), (812, 155), (848, 215), (856, 280), (856, 345),
    (850, 410), (836, 465), (820, 515), (788, 562), (743, 602), (716, 642),
    (712, 700), (702, 714),          # 右缘 + 底尖
    (694, 680), (688, 640), (678, 600), (668, 570), (660, 542),   # 左缘下段（线归躯干）
    (653, 505), (650, 460), (652, 420), (650, 380), (650, 330),   # 左缘交错带（线归尾）
    (653, 280), (668, 230), (692, 185),
])

# 头身接缝：arc_y(x) —— 中心白色区平切 y=562，两侧沿黑色弧线
def head_seam_y(x):
    if x < 175:
        return 470
    if x < 263:                      # 左弧
        return 470 + (x - 175) * (558 - 470) / (263 - 175)
    if x < 620:
        return 562                   # 中央白色区（无线，开边切割）
    if x < 665:                      # 右弧
        return 562 - (x - 620) * (562 - 475) / (665 - 620)
    return 475


xs_grid = np.arange(W)[None, :].repeat(H, axis=0)
ys_grid = np.arange(H)[:, None].repeat(W, axis=1)
seam = np.vectorize(head_seam_y)(xs_grid)

head_mask = OPAQUE & (ys_grid < seam) & ~TAIL_POLY

# 腿根分隔线：每列 y∈[700,820] 内第一个黑描边像素 = 躯干底边/腿顶线
def leg_sep_y(x):
    col = DARK[700:820, x]
    idx = np.where(col)[0]
    return 700 + int(idx[0]) if len(idx) else 775


LEG_RANGES = {           # x 范围（屏幕坐标），r/l 为角色自身左右
    "leg_br": (208, 374),   # 屏幕左外 = 角色右后腿
    "leg_fr": (388, 462),   # 屏幕中左（深色远侧）= 角色右前腿
    "leg_fl": (462, 560),   # 屏幕中右 = 角色左前腿
    "leg_bl": (560, 700),   # 屏幕右外 = 角色左后腿
}
leg_masks = {}
for name, (x0, x1) in LEG_RANGES.items():
    m = np.zeros((H, W), dtype=bool)
    for x in range(x0, x1):
        # 腿顶直接含原始分隔线像素（随腿走），不再程序化重描 → 中性位像素级还原；
        # 但不超过 y=766——腿缝间的 V 形斜线（y<766 部分）留在躯干上
        y0 = max(leg_sep_y(x) - 2, 766)
        m[y0:890, x] = OPAQUE[y0:890, x]
    leg_masks[name] = m
legs_all = leg_masks["leg_br"] | leg_masks["leg_fr"] | leg_masks["leg_fl"] | leg_masks["leg_bl"]

# 躯干让出腿列 y∈[766,806] 的全部像素（连黑线一起归腿携带，避免 AA 双层叠加）；
# 腿缝间的 V 形斜线（y<766）保留在躯干上——腿转动时腿缝的线不动
torso_mask = OPAQUE & ~head_mask & ~TAIL_POLY & ~legs_all
for x0, x1 in LEG_RANGES.values():
    torso_mask[766:806, x0:x1] = False
tail_mask = OPAQUE & TAIL_POLY & ~head_mask

def largest_component(mask):
    """只保留最大连通体，去掉区域边界带进来的碎屑（耳朵尖/邻件描边残点）。"""
    from collections import deque
    seen = np.zeros_like(mask)
    best, best_n = None, 0
    ys, xs = np.where(mask)
    for y0, x0 in zip(ys, xs):
        if seen[y0, x0]:
            continue
        q = deque([(y0, x0)])
        seen[y0, x0] = True
        cells = [(y0, x0)]
        while q:
            cy, cx = q.popleft()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < H and 0 <= nx < W and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
                    cells.append((ny, nx))
        if len(cells) > best_n:
            best, best_n = cells, len(cells)
    out = np.zeros_like(mask)
    for cy, cx in best:
        out[cy, cx] = True
    return out


# ---------------------------------------------------------------- 部件组装
def make_part(visible_mask, backings=(), backings_shape=(), backings_copy=()):
    """可见区原图像素 + 隐藏补画包（画在原图像素下面）。
    backings: (cx,cy,rx,ry,color) 纯色椭圆；
    backings_shape: (mask,color) 任意纯色形状；
    backings_copy: (cx,cy,rx,ry,color) 椭圆，只拷贝原图不透明像素
                   （不做纯色垫底——垫底会探进腿间透明缝）；中性位零色差。"""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for (cx, cy, rx, ry, color) in backings:
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=color)
    arr = np.array(img)
    for (shape, color) in backings_shape:
        arr[shape] = color
    for (cx, cy, rx, ry, color) in backings_copy:
        ex = (xs_grid - cx) / rx
        ey = (ys_grid - cy) / ry
        em = (ex * ex + ey * ey <= 1) & OPAQUE
        arr[em] = OA[em]
    src = OA.copy()
    src[~visible_mask] = (0, 0, 0, 0)
    sm = src[:, :, 3] > 0
    arr[sm] = src[sm]
    return Image.fromarray(arr, "RGBA")


# ---- 孤儿像素救援：主连通过滤会丢掉"插在别家区域里的碎片"（尾左线像素、
# 腿顶 AA 细条），按最近部件（20px 内）收回，保证拼装 = 原图逐像素不缺
from scipy import ndimage as _ndi
PART_ORDER = ["head", "torso", "tail", "leg_fr", "leg_fl", "leg_br", "leg_bl"]


def rescue_orphans(masks):
    owned = np.zeros((H, W), dtype=bool)
    for m in masks.values():
        owned |= m
    orphans = OPAQUE & ~owned
    if not orphans.any():
        return masks
    dists = np.stack([_ndi.distance_transform_edt(~m) for m in
                      (masks[n] for n in PART_ORDER)])
    owner = dists.argmin(axis=0)
    for i, name in enumerate(PART_ORDER):
        take = orphans & (owner == i) & (dists[i] < 20)
        if take.any():
            masks[name] = masks[name] | take
            print(f"  救援 {int(take.sum())}px -> {name}")
    return masks


# 头的颈桩改用原图胸部白色像素（椭圆纯白色与胸腹微渐变有色差）
CHEST_CHUNK = OPAQUE & (ys_grid >= 562) & (ys_grid < 618) \
    & (np.abs(xs_grid - 512) < 95) & (OA[:, :, :3].sum(axis=2) > 700)
head_mask2 = head_mask | CHEST_CHUNK
torso_mask &= ~CHEST_CHUNK          # 颈桩像素归头，躯干避让（底下有补画兜底）

# 颈/胸补画形状 = 原图真实胸腹白色区域外扩 6px（不是椭圆，避免白色侵入奶油身体）
from PIL import ImageFilter
_chest = OPAQUE & (OA[:, :, :3].sum(axis=2) > 700) \
    & (xs_grid > 380) & (xs_grid < 650) & (ys_grid > 530) & (ys_grid < 730)
CHEST_SHAPE = np.asarray(Image.fromarray((_chest * 255).astype(np.uint8)).filter(
    ImageFilter.MaxFilter(13))) > 0

# ---- 可见掩码定稿：主连通过滤 → 孤儿救援 → 才生成部件
visible = {"head": head_mask2, "torso": torso_mask, "tail": tail_mask,
           **leg_masks}
visible = {n: largest_component(m) for n, m in visible.items()}
visible = rescue_orphans(visible)

parts = {}
# 头：可见区(含颈部白色原图像素) + 颈胸兜底（拷贝原图像素，中性位零色差）
parts["head"] = make_part(visible["head"], backings_copy=[(512, 585, 100, 45, WHITE)])

# 躯干：可见区 + 头顶后补（藏在头后，x≤600 防探进头尾间隙）+ 颈胸白兜底 +
# 每条腿后面的底边延伸条（含底边描边；腿抬起后身体底边仍完整；
# 延伸条宽度 = 该腿 y=830 处的实际轮廓列，不会探进腿缝——腿缝原图是透明的）
torso_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
arr = np.array(torso_img)
_ex = (xs_grid - 450) / 160.0
_ey = (ys_grid - 505) / 72.0
arr[(_ex * _ex + _ey * _ey <= 1) & (xs_grid <= 600)] = CREAM   # 头后补画
arr[CHEST_SHAPE] = WHITE                                        # 颈胸白兜底
torso_img = Image.fromarray(arr, "RGBA")
d = ImageDraw.Draw(torso_img)
for name, (x0, x1) in LEG_RANGES.items():
    cols = np.where(visible[name][800, x0:x1])[0] + x0          # 腿实际轮廓列（y=800 处）
    sx0, sx1 = int(cols.min()) + 2, int(cols.max()) - 2
    d.rectangle([sx0, 726, sx1, 800], fill=CREAM)               # 腿后底边延伸条
    d.line([(sx0, 800), (sx1, 800)], fill=(6, 7, 9, 255), width=11)
arr = np.array(torso_img)
src = OA.copy()
src[~visible["torso"]] = (0, 0, 0, 0)
sm = src[:, :, 3] > 0
arr[sm] = src[sm]
parts["torso"] = Image.fromarray(arr, "RGBA")

# 尾巴：可见区 + 尾根包（藏在躯干右后，不超出躯干右缘线）
parts["tail"] = make_part(visible["tail"], backings=[(662, 682, 38, 32, CREAM)])

# 腿（画在躯干之前=>腿在最前）：髋包拷贝原图像素（中性位零色差）+
# 原图可见像素（腿顶已含原始分隔线，随腿走；转动后躯干有延伸底边兜底）
HIP = {"leg_br": (290, 758), "leg_fr": (428, 762),
       "leg_fl": (505, 762), "leg_bl": (632, 758)}
for name in ("leg_fr", "leg_fl", "leg_br", "leg_bl"):
    hx, hy = HIP[name]
    parts[name] = make_part(visible[name], backings_copy=[(hx, hy, 46, 32, CREAM)])

for name, img in parts.items():
    img.save(os.path.join(OUT, f"{name}.png"))

# ---------------------------------------------------------------- pivots.json
pivots = {
    "canvas": [W, H],
    "coordinate_system": "origin top-left, +X right, +Y down, pixels of the 1024x1024 master canvas",
    "root": {"pos": [453, 889], "note": "整体定位点：四脚脚底中央的底边中点"},
    "parts": {
        "torso":  {"pivot": [458, 630], "parent": None,    "note": "躯干中心，整棵树的根"},
        "head":   {"pivot": [512, 540], "parent": "torso", "note": "颈部连接处"},
        "tail":   {"pivot": [670, 685], "parent": "torso", "note": "尾根（藏在躯干右后）"},
        "leg_fr": {"pivot": [428, 762], "parent": "torso", "note": "右前腿肩关节（角色右=屏幕左，深色的远侧腿）"},
        "leg_fl": {"pivot": [505, 762], "parent": "torso", "note": "左前腿肩关节"},
        "leg_br": {"pivot": [290, 758], "parent": "torso", "note": "右后腿髋部（屏幕左外侧）"},
        "leg_bl": {"pivot": [632, 758], "parent": "torso", "note": "左后腿髋部（屏幕右外侧）"},
    },
    "draw_order_back_to_front": [
        "tail", "torso", "leg_fr", "leg_fl", "leg_br", "leg_bl", "head",
    ],
    "notes": "四足猫：熊方案的上臂/前臂/手掌对应四条腿（腿脚暂不细分）。leg_fr 是原图中颜色偏深的远侧前腿。",
}
with open(os.path.join(OUT, "pivots.json"), "w", encoding="utf-8") as f:
    json.dump(pivots, f, ensure_ascii=False, indent=2)

DRAW_ORDER = pivots["draw_order_back_to_front"]


def assemble(transforms=None):
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for name in DRAW_ORDER:
        img = parts[name] if not transforms or name not in transforms else transforms[name]
        canvas.alpha_composite(img)
    return canvas


assembled = assemble()
preview = Image.new("RGB", (W * 2 + 60, H + 40), (232, 232, 232))
preview.paste(assembled, (20, 20), assembled)
preview.paste(orig, (W + 40, 20), orig)
preview.save(os.path.join(OUT, "assembled_preview.png"))

a = np.array(assembled).astype(int)
o = OA.astype(int)
am = (a[:, :, 3] > 0) != (o[:, :, 3] > 0)
both = (a[:, :, 3] > 0) & (o[:, :, 3] > 0)
rgbm = (np.abs(a[:, :, :3] - o[:, :, :3]).sum(axis=2) > 30) & both
print("assembled vs original | alpha-diff px:", int(am.sum()), " rgb-diff px:", int(rgbm.sum()))

# ---------------------------------------------------------------- 关节检查图
def rot(img, angle, cx, cy):
    return img.rotate(angle, resample=Image.BICUBIC, center=(cx, cy), fillcolor=(0, 0, 0, 0))


posed = assemble({
    "head": rot(parts["head"], 18, *pivots["parts"]["head"]["pivot"]),
    "tail": rot(parts["tail"], -25, *pivots["parts"]["tail"]["pivot"]),
    "leg_fl": rot(parts["leg_fl"], -50, *pivots["parts"]["leg_fl"]["pivot"]),
    "leg_bl": rot(parts["leg_bl"], 20, *pivots["parts"]["leg_bl"]["pivot"]),
})
art_prev = Image.new("RGB", (W * 2 + 60, H + 40), (232, 232, 232))
art_prev.paste(assembled, (20, 20), assembled)
art_prev.paste(posed, (W + 40, 20), posed)
art_prev.save(os.path.join(OUT, "articulation_preview.png"))

# ---------------------------------------------------------------- 部件展示图
try:
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 26)
except OSError:
    font = ImageFont.load_default()
CELL = 400
names = ["head", "torso", "tail", "leg_fr", "leg_fl", "leg_br", "leg_bl"]
sheet = Image.new("RGB", (CELL * 4, CELL * 2), (245, 245, 245))
d = ImageDraw.Draw(sheet)
for i, name in enumerate(names):
    img = parts[name]
    crop = img.crop(img.getbbox())
    scale = min((CELL - 80) / crop.width, (CELL - 110) / crop.height)
    thumb = crop.resize((max(1, round(crop.width * scale)),
                         max(1, round(crop.height * scale))), Image.LANCZOS)
    cx, cy = (i % 4) * CELL, (i // 4) * CELL
    sheet.paste(thumb, (cx + (CELL - thumb.width) // 2,
                        cy + (CELL - 60 - thumb.height) // 2), thumb)
    tw = d.textlength(name, font=font)
    d.text((cx + (CELL - tw) / 2, cy + CELL - 48), name, fill=(20, 20, 20), font=font)
    d.rectangle([cx, cy, cx + CELL - 1, cy + CELL - 1], outline=(200, 200, 200))
sheet.save(os.path.join(OUT, "parts_preview.png"))
print("geocat split done ->", OUT)
