# -*- coding: utf-8 -*-
"""geobear 右侧面（stand_03_right）拆件 —— v2：原图像素裁切路线。

v1（各部件多边形重绘 + 描边骑缝）实测拼装 alpha 差 1.61%、色差 5.58%，
且外轮廓系统性内缩 2~7px —— 多边形重绘注定有偏差。v2 改成：

  每个部件 = 自己的原图像素（含描边，原样 1:1） + 隐藏区补画（藏在别的件后面）

拼装时一个像素都不重绘，理论拼装误差 = 0。

与 geocat 正面（AI 图）一致的做法，差异在于 geobear 是严格 6 色平涂，
补画用纯色块即可，且**透明区 RGB 是米白 (255,249,230) 不是 0**，
取像素时必须连同 RGB 一起清零（否则 LANCZOS / 合成边缘会泛米白光晕）。

结构实测（侧面）：
  - 头与背部轮廓连续无接缝 → 人工开边切割线 CUT（耳后 → 下巴线左端 → 下巴线下缘）
  - 手臂只有近侧一条：上臂（青蓝胶囊）→ 前臂（灰护甲八边形即前臂本体）
    → 腕掌（青蓝沙漏块）+ 3 根米白三角爪（爪根不封口，与掌连体）
  - 腿柱近乎被爪挡住；髋包补画在腿件上；腿脚一体（踝部双线属原设计）
  - 脚掌右端与躯干底边之间本来开口（无连线），不补

输出：geometric/geobear/parts/right/
"""
import json
import math
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ART, "geometric", "geobear", "geobear_stand_03_right.png")
OUT = os.path.join(ART, "geometric", "geobear", "parts", "right")
os.makedirs(OUT, exist_ok=True)

W = H = 1024
BLACK = (6, 7, 11)
TEAL = (25, 99, 101)
CREAM = (252, 236, 203)
GRAY = (92, 95, 102)

orig = Image.open(SRC).convert("RGBA")
OA = np.array(orig).copy()
RGB = OA[:, :, :3]
OPAQUE = OA[:, :, 3] > 0

# 透明区 RGB 是米白，必须清零，否则补画/缩放边缘会泛白
OA[~OPAQUE] = (0, 0, 0, 0)
RGB = OA[:, :, :3]

YS, XS = np.indices((H, W))


def color_mask(c):
    return np.all(RGB == c, axis=2) & OPAQUE


IS_TEAL = color_mask(TEAL)
IS_BLACK = color_mask(BLACK)
IS_CREAM = color_mask(CREAM)
IS_GRAY = color_mask(GRAY)


def dilate(m, px):
    if px <= 0:
        return m
    return np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(
        ImageFilter.MaxFilter(px * 2 + 1))) > 0


def erode(m, px):
    if px <= 0:
        return m
    return np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(
        ImageFilter.MinFilter(px * 2 + 1))) > 0


def comp_by_bbox(mask, expected, tol=30, min_px=50):
    """按包围盒签名选连通域（手册 §3：不要用相交提示框，会串件）。"""
    lab, n = ndimage.label(mask)
    best, best_d = None, 1e18
    for i in range(1, n + 1):
        ys, xs = np.where(lab == i)
        if len(xs) < min_px:
            continue
        bb = (xs.min(), ys.min(), xs.max(), ys.max())
        d = sum(abs(bb[k] - expected[k]) for k in range(4))
        if d < best_d:
            best, best_d = lab == i, d
    assert best is not None and best_d < tol * 4, f"no comp near {expected} (d={best_d})"
    return best


def polygon_mask(pts):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return np.asarray(m) > 0


def ellipse_mask(cx, cy, rx, ry):
    ex = (XS - cx) / rx
    ey = (YS - cy) / ry
    return ex * ex + ey * ey <= 1


# ============================================================
# 1. 连通域（预期 bbox 来自逐色连通域分析）
# ============================================================
uarm = comp_by_bbox(IS_TEAL, (393, 324, 522, 514))       # 上臂胶囊
armor = comp_by_bbox(IS_GRAY, (365, 505, 549, 697))      # 前臂护甲八边形
palm = comp_by_bbox(IS_TEAL, (375, 681, 569, 770))       # 腕掌青蓝块
palm_bits = IS_TEAL & dilate(palm, 30) & (YS > 770)      # 爪间青蓝小尖
palm_full = palm | palm_bits
leg = comp_by_bbox(IS_TEAL, (426, 812, 554, 868))        # 腿柱
foot = comp_by_bbox(IS_TEAL, (392, 883, 645, 958))       # 脚掌梯形
claws = [comp_by_bbox(IS_CREAM, (389, 772, 429, 838)),
         comp_by_bbox(IS_CREAM, (449, 776, 491, 846)),
         comp_by_bbox(IS_CREAM, (511, 769, 552, 838))]
belly = comp_by_bbox(IS_CREAM, (571, 413, 674, 744))     # 腹部米白块
torso_teal = comp_by_bbox(IS_TEAL, (301, 65, 677, 744))  # 头+躯干连体主域

# ============================================================
# 2. 头/躯干切割线（头背轮廓连续，只能人工开边）
# ============================================================
# 后颈无天然凹口（背线连续），人工开边：耳后 (410,185) 斜下到肩背交点，
# 再并入下巴线。下巴线实测是一条 14px 粗黑线，从 (580,350) 斜到 (656,426)
# 继续下行 —— 它右侧是"颈部前侧 + 胸口"，属躯干，不能划给头。
# 所以切割沿下巴线下缘走（线归头，胸在线的右下）。
NECK_JOIN = (560, 398)
JAW_TOP = (580, 348)
CUT = [(410, 185), (440, 258), (478, 320), (520, 362), NECK_JOIN, JAW_TOP,
       (600, 366), (630, 392), (656, 424)]
# 头部区域：切割线以上的全部内容（含下巴线本体），下界不超过 JAW 线
head_region = np.zeros((H, W), dtype=bool)
for y in range(20, 440):
    head_region[y] = (XS[y] >= 398) & (YS[y] >= 20) & (YS[y] <= 440)
# 用切割线把 (x,y) 空间切成两半：左/上 = 头
_cut_pts = [(398, 20)] + CUT + [(748, 430), (748, 20)]
HEAD_POLY = _cut_pts
HEAD_REGION = polygon_mask(HEAD_POLY) & OPAQUE

# ============================================================
# 3. 各部件"可见区"掩码 —— 严格分层，重叠区只归一个件
# ============================================================
# 绘制顺序（后→前）：torso, leg_foot, upper_arm, forearm, claw, head
# 从上往下扣：head > claw > forearm > upper_arm > leg_foot > torso
# 每一件的掩码 = 自身区域 - 更上层已占区域。这样拼装时同一像素只有一个件
# 提供原图色，不会因为"两个件都带该像素且颜色不同"而被上层色盖出差异。
arm_chain = (uarm | armor | palm_full | claws[0] | claws[1] | claws[2]
             | foot | leg)

ORDER = ["head", "claw", "forearm", "upper_arm", "leg_foot", "torso"]

head_mask = HEAD_REGION

claw_core = palm_full | claws[0] | claws[1] | claws[2]
claw_mask = dilate(claw_core, 9) & OPAQUE & ~head_mask

farm_mask = dilate(armor, 10) & OPAQUE & ~head_mask & ~claw_mask

uarm_mask = dilate(uarm, 10) & OPAQUE & ~head_mask & ~claw_mask & ~farm_mask

legfoot_mask = dilate(leg | foot, 11) & OPAQUE & ~head_mask & ~claw_mask \
    & ~farm_mask & ~uarm_mask

# 躯干：除头/手臂链/爪/腿脚之外的全部原图像素（背、胸、腹、底边）
torso_core = OPAQUE & ~head_mask & ~claw_mask & ~farm_mask \
    & ~uarm_mask & ~legfoot_mask

print("初始 alpha 覆盖检查:")
alloc = (head_mask | claw_mask | farm_mask | uarm_mask | legfoot_mask | torso_core)
missing = OPAQUE & ~alloc
print("  未归属像素", int(missing.sum()))
if missing.any():
    ys, xs = np.where(missing)
    print("  bbox", xs.min(), ys.min(), xs.max(), ys.max())

# 未归属的碎屑：就近并入最近部件（防止丢像素）
if missing.any():
    msks = {"head": head_mask, "claw": claw_mask, "farm": farm_mask,
            "uarm": uarm_mask, "legfoot": legfoot_mask, "torso": torso_core}
    dmap = {k: ndimage.distance_transform_edt(~v) for k, v in msks.items()}
    best = np.argmin(np.stack([dmap[k] for k in ORDER]), axis=0)
    for i, k in enumerate(ORDER):
        add = missing & (best == i)
        if add.any():
            msks[k] |= add
            print(f"  碎屑 {int(add.sum())}px → {k}")
    head_mask = msks["head"]
    claw_mask = msks["claw"]
    farm_mask = msks["farm"]
    uarm_mask = msks["uarm"]
    legfoot_mask = msks["legfoot"]
    torso_core = msks["torso"]

# ============================================================
# 4. 组装部件：原图像素 + 补画垫底
# ============================================================
# 补画的两条铁律（踩过两次坑）：
#   ① 补画只准出现在"原图透明区"或"本件自身可见区以下" —— 绝不能压在别件的
#      原像素上（否则拼装时补画色会盖掉别件的黑描边/填色）。
#      → 实现：补画先裁掉（所有件可见区 - 本件可见区）。
#   ② 补画不得超出角色轮廓（原图不透明区），否则拼装多出不透明像素。
#      → 实现：补画 ∩ OPAQUE。
ALL_VIS = None   # 稍后回填（各件掩码确定后）


def make_part(visible_mask, backings=(), backings_shape=()):
    """visible_mask 的原图像素贴最上层；补画垫在下面（被可见区遮住，只在旋转后露出）。"""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for (cx, cy, rx, ry, color) in backings:
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=color + (255,))
    arr = np.array(img)
    for (shape, color) in backings_shape:
        arr[shape] = color + (255,)
    src = OA.copy()
    src[~visible_mask] = (0, 0, 0, 0)
    sm = src[:, :, 3] > 0
    arr[sm] = src[sm]
    return Image.fromarray(arr, "RGBA")


PARTS_SPEC = {
    # name: (visible_mask, backings, backings_shape)
    # 头：颈桩 —— 从下巴线往下延伸进胸口，转头时露出的是脖子而不是洞。
    "head": (head_mask, [(500, 388, 118, 66, TEAL),
                         (470, 358, 92, 56, TEAL),
                         (556, 376, 92, 46, TEAL)], ()),
    # 躯干：头后（背颈根 + 整个头部下缘）必须够大，抬头 15° 才不露洞
    "torso": (torso_core, [(510, 396, 126, 80, TEAL),      # 头后 / 颈根
                           (560, 388, 100, 52, TEAL),      # 颈前（下巴线下方）
                           (452, 336, 92, 62, TEAL),       # 肩（上臂后面）
                           (452, 508, 84, 52, TEAL),       # 肘（前臂后面）
                           (468, 700, 80, 44, TEAL),       # 腕（爪后面）
                           (470, 800, 110, 90, TEAL)], ()),  # 髋（腿脚后面）
    "upper_arm": (uarm_mask, [(452, 336, 88, 58, TEAL),    # 肩关节包
                              (452, 512, 82, 46, TEAL)], ()),   # 肘（前臂后面）
    "forearm": (farm_mask, [(455, 512, 82, 46, TEAL),      # 肘关节包
                            (468, 694, 78, 40, GRAY)], ()),     # 腕（爪后面）
    "claw": (claw_mask, [(470, 692, 74, 38, GRAY)], ()),
    "leg_foot": (legfoot_mask, [(492, 806, 84, 66, TEAL),
                                (492, 760, 70, 46, TEAL)], ()),
}

# 补画裁剪的唯一不变量：不覆盖任何黑描边像素。
#   理由：拼装时上层件盖住下层件，补画只要落在别件的"填色区"上就被遮住，无影响；
#   但若落在别件的黑线上，就会把线涂成青蓝/灰色 → 拼装出现色差、视觉断线。
#   另外不出角色轮廓（~OPAQUE），否则拼装多出不透明像素。
# 关节补画本来就该伸进相邻部件（那才是"补全被遮挡部分"），所以不做包络限制。
parts = {}
for name, (vis, back, bshape) in PARTS_SPEC.items():
    img = make_part(vis, back, bshape)
    arr = np.array(img)
    painted = (arr[:, :, 3] > 0) & ~vis
    bad = painted & (~OPAQUE | IS_BLACK)
    arr[bad] = (0, 0, 0, 0)
    # 补画被黑描边切断后要能接到本件身上：把与本件可见区同属一个整体的补画块
    # 并入（去掉"浮空孤岛"——孤岛旋转后会成为飞出去的黑疙瘩/色块）
    a = arr[:, :, 3] > 0
    lab, k = ndimage.label(a, structure=np.ones((3, 3)))
    keep = np.zeros(k + 1, dtype=bool)
    for lb in np.unique(lab[vis & a]):
        keep[lb] = True
    # 与本件可见区相距 ≤ 2px 的补画块也保留（被描边隔开但紧贴，属生理连接）
    near = dilate(vis, 2)
    for lb in np.unique(lab[near & a]):
        keep[lb] = True
    drop = a & ~keep[lab]
    arr[drop] = (0, 0, 0, 0)
    parts[name] = Image.fromarray(arr, "RGBA")


for name, img in parts.items():
    img.save(os.path.join(OUT, f"{name}.png"))

# ============================================================
# 5. pivots.json
# ============================================================
fys, fxs = np.where(foot)
root_x = int((fxs.min() + fxs.max()) / 2)
root_y = int(fys.max())
pivots = {
    "canvas": [W, H],
    "coordinate_system": "origin top-left, +X right, +Y down, pixels of the 1024x1024 master canvas",
    "source_view": "geobear_stand_03_right.png（纯侧面，鼻尖朝画面右）",
    "root": {"pos": [root_x, root_y], "note": "整体定位点：脚掌底边中点"},
    "parts": {
        "torso":     {"pivot": [622, 578], "parent": None,        "note": "腹部色块中心，整棵树的根"},
        "head":      {"pivot": [508, 352], "parent": "torso",     "note": "颈部连接处（人工切割线中点）"},
        "upper_arm": {"pivot": [452, 332], "parent": "torso",     "note": "肩关节（上臂顶）"},
        "forearm":   {"pivot": [455, 508], "parent": "upper_arm", "note": "肘关节（上臂底/护甲顶）"},
        "claw":      {"pivot": [470, 690], "parent": "forearm",   "note": "腕关节（掌顶）"},
        "leg_foot":  {"pivot": [492, 812], "parent": "torso",     "note": "髋部（腿柱顶，缺口被爪件遮盖）"},
    },
    "draw_order_back_to_front": [
        "torso", "leg_foot", "upper_arm", "forearm", "claw", "head",
    ],
    "mirror_rule": "左侧面（stand_07）= mirror(本套)，pivot.x' = 1024 - pivot.x",
    "notes": "侧面只见近侧手臂与单腿；头背切割线开边不描线；爪根不封口（手册 §6）。",
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
# 三栏：拼装 / 原图 / 差异热力图
heat = np.zeros((H, W, 3), np.uint8) + 235
_a = np.array(assembled).astype(int)
_o = OA.astype(int)
_am = (_a[:, :, 3] > 0) != (_o[:, :, 3] > 0)
_both = (_a[:, :, 3] > 0) & (_o[:, :, 3] > 0)
_rgbm = (np.abs(_a[:, :, :3] - _o[:, :, :3]).sum(axis=2) > 30) & _both
heat[_am] = [255, 0, 0]        # 红 = alpha 差异（缺块/多块）
heat[_rgbm] = [255, 140, 0]    # 橙 = 颜色差异
preview = Image.new("RGB", (W * 3 + 80, H + 40), (232, 232, 232))
preview.paste(assembled, (20, 20), assembled)
preview.paste(orig, (W + 40, 20), orig)
preview.paste(Image.fromarray(heat), (W * 2 + 60, 20))
preview.save(os.path.join(OUT, "assembled_preview.png"))

# alpha 感知 diff
a = np.array(assembled).astype(int)
o = OA.astype(int)
am = (a[:, :, 3] > 0) != (o[:, :, 3] > 0)
both = (a[:, :, 3] > 0) & (o[:, :, 3] > 0)
rgbm = (np.abs(a[:, :, :3] - o[:, :, :3]).sum(axis=2) > 30) & both
print("assembled vs original | alpha-diff:", int(am.sum()),
      f"({100 * am.sum() / OPAQUE.sum():.3f}%)",
      "rgb-diff:", int(rgbm.sum()), f"({100 * rgbm.sum() / OPAQUE.sum():.3f}%)")

# ============================================================
# 6. 关节活动检查
# ============================================================
try:
    font_small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 18)
except OSError:
    font_small = ImageFont.load_default()
def rot(img, angle, cx, cy):
    return img.rotate(angle, resample=Image.BICUBIC, center=(cx, cy),
                      fillcolor=(0, 0, 0, 0))


def rot_point(p, angle_deg, c_):
    a_ = math.radians(angle_deg)
    dx, dy = p[0] - c_[0], p[1] - c_[1]
    return (c_[0] + dx * math.cos(a_) + dy * math.sin(a_),
            c_[1] - dx * math.sin(a_) + dy * math.cos(a_))


S = (452, 332)          # 肩
E = (455, 508)          # 肘
WP = (470, 690)         # 腕
HP = (492, 812)         # 髋
NK = (508, 352)         # 颈
TH_S, TH_E, TH_W, TH_H, TH_L = 90.0, -90.0, 45.0, 15.0, 30.0


def pose(arm=0.0, elbow=0.0, wrist=0.0, head=0.0, leg=0.0):
    """按关节链摆姿：手臂链自上而下累加旋转。"""
    t = {}
    S1 = S
    E1 = rot_point(E, arm, S1)
    W1 = rot_point(rot_point(WP, arm, S1), elbow, E1)
    if arm:
        t["upper_arm"] = rot(parts["upper_arm"], arm, *S1)
    if arm or elbow:
        t["forearm"] = rot(rot(parts["forearm"], arm, *S1), elbow, *E1)
    if arm or elbow or wrist:
        t["claw"] = rot(rot(rot(parts["claw"], arm, *S1), elbow, *E1), wrist, *W1)
    if head:
        t["head"] = rot(parts["head"], head, *NK)
    if leg:
        t["leg_foot"] = rot(parts["leg_foot"], leg, *HP)
    return assemble(t)


# 四联检查：待机 / 抬臂90 / 抬臂90+弯肘90 / 全链+转腕45+抬头15+抬腿30
POSES = [
    ("idle", pose()),
    ("arm 90", pose(arm=TH_S)),
    ("arm 90 + elbow -90", pose(arm=TH_S, elbow=TH_E)),
    ("all joints", pose(arm=TH_S, elbow=TH_E, wrist=TH_W,
                        head=TH_H, leg=TH_L)),
]
CELLW, CELLH = W // 2, H // 2
art_prev = Image.new("RGB", (CELLW * 4, CELLH + 44), (232, 232, 232))
_d = ImageDraw.Draw(art_prev)
for i, (label, im) in enumerate(POSES):
    th = im.resize((CELLW, CELLH), Image.LANCZOS)
    bg = Image.new("RGB", (CELLW, CELLH), (240, 240, 240))
    bg.paste(th, (0, 0), th)
    art_prev.paste(bg, (i * CELLW, 44))
    _d.text((i * CELLW + 12, 12), label, fill=(20, 20, 20), font=font_small)
    _d.line([(i * CELLW, 0), (i * CELLW, CELLH + 44)], fill=(180, 180, 180))
art_prev.save(os.path.join(OUT, "articulation_preview.png"))

# ============================================================
# 7. 分件展示
# ============================================================
try:
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 26)
except OSError:
    font = ImageFont.load_default()
CELL = 400
names = ["head", "torso", "upper_arm", "forearm", "claw", "leg_foot"]
sheet = Image.new("RGB", (CELL * 3, CELL * 2), (245, 245, 245))
d = ImageDraw.Draw(sheet)
for i, name in enumerate(names):
    img = parts[name]
    crop = img.crop(img.getbbox())
    scale = min((CELL - 80) / crop.width, (CELL - 110) / crop.height)
    thumb = crop.resize((max(1, round(crop.width * scale)),
                         max(1, round(crop.height * scale))), Image.LANCZOS)
    cx, cy = (i % 3) * CELL, (i // 3) * CELL
    sheet.paste(thumb, (cx + (CELL - thumb.width) // 2,
                        cy + (CELL - 60 - thumb.height) // 2), thumb)
    tw = d.textlength(name, font=font)
    d.text((cx + (CELL - tw) / 2, cy + CELL - 48), name, fill=(20, 20, 20), font=font)
    d.rectangle([cx, cy, cx + CELL - 1, cy + CELL - 1], outline=(200, 200, 200))
sheet.save(os.path.join(OUT, "parts_preview.png"))
print("geobear right-side split v2 done ->", OUT)
