# -*- coding: utf-8 -*-
"""geobear 右侧面（stand_03）拆件 —— 按 SPLITTING_GUIDE v2 路线。

与正面的差异（侧面结构实测）：
  - 头与背部轮廓连续无接缝 → 人工开边切割线 CUT（耳后 (410,185) → 下巴线左端
    (521,360) → (560,395)），切边不描线；头 = 原图像素直接贴（轮廓在原图完整），
    躯干 = 逐行实测轮廓重建（切边走 draw_poly_open 不描）。
  - 手臂只有近侧一条：上臂（青蓝胶囊）→ 前臂（灰八边形护甲即前臂本体）
    → 腕掌（青蓝块）+ 3 根米白三角爪（爪根不封口）。
  - 腿柱几乎被爪挡住：躯干底边 (y≈748) 与腿顶 (y≈812) 之间的缺口由爪部遮盖；
    髋包补画在腿件上。腿脚一体（踝部双线保留，属原设计）。
  - 脚掌与躯干底边右端之间本来就是开口的（无连线），不补。
  - 画布 1024×1024，描边宽 12（正面 13px@1254 的等比）。

输出：geometric/geobear/parts/right/{6 件 PNG, pivots.json,
assembled_preview.png, parts_preview.png, articulation_preview.png, README.md}
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
SS = 4
STROKE = 14            # 实测描边环宽（y500 左缘 14px）
BLACK = (6, 7, 11)
TEAL = (25, 99, 101)
CREAM = (252, 236, 203)
GRAY = (92, 95, 102)

orig = Image.open(SRC).convert("RGBA")
OA = np.array(orig)
RGB = OA[:, :, :3]
OPAQUE = OA[:, :, 3] > 0


def color_mask(c):
    return np.all(RGB == c, axis=2) & OPAQUE


IS_TEAL = color_mask(TEAL)
IS_BLACK = color_mask(BLACK)
IS_CREAM = color_mask(CREAM)
IS_GRAY = color_mask(GRAY)


def dilate(m, px):
    return np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(
        ImageFilter.MaxFilter(px * 2 + 1))) > 0


def erode(m, px):
    return np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(
        ImageFilter.MinFilter(px * 2 + 1))) > 0


_LABEL_CACHE = {}


def comp_by_bbox(mask, expected, tol=30):
    """按包围盒签名选连通域（手册 §3：不要用相交提示框，会串件）。"""
    key = (mask.tobytes(),)
    if key not in _LABEL_CACHE:
        _LABEL_CACHE[key] = ndimage.label(mask)
    lab, n = _LABEL_CACHE[key]
    best, best_d = None, 1e18
    for i in range(1, n + 1):
        ys, xs = np.where(lab == i)
        if len(xs) < 50:
            continue
        bb = (xs.min(), ys.min(), xs.max(), ys.max())
        d = sum(abs(bb[k] - expected[k]) for k in range(4))
        if d < best_d:
            best, best_d = lab == i, d
    assert best is not None and best_d < tol * 4, f"no comp near {expected}"
    return best


def hull_points(mask):
    bnd = mask & ~erode(mask, 1)
    ys, xs = np.where(bnd)
    pts = sorted(set(zip(xs[::3].tolist(), ys[::3].tolist())))

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower = []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    upper = []
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def rdp(points, eps):
    if len(points) < 4:
        return points
    keep = [True] * len(points)

    def perp_dist(p, a, b):
        ax, ay = a
        bx, by = b
        dx, dy = bx - ax, by - ay
        L = math.hypot(dx, dy)
        if L == 0:
            return math.hypot(p[0] - ax, p[1] - ay)
        return abs(dy * p[0] - dx * p[1] + bx * ay - by * ax) / L

    def rec(i, j):
        if (j - i) % len(points) <= 1:
            return
        a, b = points[i], points[j]
        dmax, kmax = -1, -1
        k = (i + 1) % len(points)
        while k != j:
            d = perp_dist(points[k], a, b)
            if d > dmax:
                dmax, kmax = d, k
            k = (k + 1) % len(points)
        if dmax > eps:
            rec(i, kmax)
            rec(kmax, j)
        else:
            k = (i + 1) % len(points)
            while k != j:
                keep[k] = False
                k = (k + 1) % len(points)

    n = len(points)
    cx = sum(p[0] for p in points) / n
    cy = sum(p[1] for p in points) / n
    i0 = max(range(n), key=lambda i: (points[i][0] - cx) ** 2 + (points[i][1] - cy) ** 2)
    j0 = max(range(n), key=lambda i: -((points[i][0] - points[i0][0]) ** 2
                                       + (points[i][1] - points[i0][1]) ** 2))
    rec(i0, j0)
    rec(j0, i0)
    return [p for p, k in zip(points, keep) if k]


def fit_poly(mask, eps=7.0):
    return rdp(hull_points(mask), eps)


def with_ring(mask, ring_px=15):
    return mask | (IS_BLACK & dilate(mask, ring_px))


# ---------------- 连通域（预期 bbox 来自首次连通域分析） ----------------
uarm = comp_by_bbox(IS_TEAL, (393, 324, 522, 514))       # 上臂胶囊
armor = comp_by_bbox(IS_GRAY, (365, 505, 549, 697))      # 前臂护甲八边形
palm = comp_by_bbox(IS_TEAL, (375, 681, 569, 770))       # 腕掌青蓝块
palm_bits = IS_TEAL & dilate(palm, 30) & (np.indices((H, W))[0] > 770)  # 爪间青蓝小尖
palm_full = palm | palm_bits
leg = comp_by_bbox(IS_TEAL, (426, 812, 554, 868))        # 腿柱
foot = comp_by_bbox(IS_TEAL, (392, 883, 645, 958))       # 脚掌梯形
claw_imgs = [comp_by_bbox(IS_CREAM, (389, 772, 429, 838)),
             comp_by_bbox(IS_CREAM, (449, 776, 491, 846)),
             comp_by_bbox(IS_CREAM, (511, 769, 552, 838))]
belly = comp_by_bbox(IS_CREAM, (571, 413, 674, 744))
torso_teal = comp_by_bbox(IS_TEAL, (301, 65, 677, 744))  # 头+躯干连体主域

# ---------------- 头/躯干人工切割线（头背无缝，开边切割） ----------------
# CUT：耳后 → 下巴线左端 → 沿下巴线下缘 tuck 到右侧（下巴线整体归头）
CUT = [(410, 185), (440, 260), (480, 320), (521, 360), (570, 380), (655, 392)]
HEAD_POLY = CUT + [(700, 386), (745, 380), (745, 40), (400, 40)]
hm = Image.new("L", (W, H), 0)
ImageDraw.Draw(hm).polygon(HEAD_POLY, fill=255)
HEAD_REGION = (np.asarray(hm) > 0) & OPAQUE

# ---------------- 躯干逐行轮廓（排除手臂/腕/爪/腿/脚/头，膨胀 8px） ----------------
# 扫描得到的是"描边外缘"，内缩半笔宽 → 多边形边=填色界，描边骑缝与原图齐平
excl = np.zeros((H, W), dtype=bool)
for m in (with_ring(uarm), with_ring(armor), with_ring(palm_full),
          *[with_ring(c) for c in claw_imgs], with_ring(leg), with_ring(foot)):
    excl |= dilate(m, 8)
excl |= dilate(HEAD_REGION, 6)

INSET = 7   # 外缘内缩到"描边中线"（环 14px 全在填色界外侧）
rows_l, rows_r = {}, {}
for y in range(185, 760, 2):
    row = OPAQUE[y].copy()
    row[:280] = False
    row[700:] = False
    row &= ~excl[y]
    xs2 = np.where(row)[0]
    if len(xs2):
        rows_l[y] = int(xs2.min()) + INSET
        rows_r[y] = int(xs2.max()) - INSET


def median_smooth(pts, w=5):
    """按 y 排序的 (x,y) 列，x 做中值平滑去行扫毛刺。"""
    xs = [p[0] for p in pts]
    out = []
    for i, p in enumerate(pts):
        lo, hi = max(0, i - w // 2), min(len(xs), i + w // 2 + 1)
        out.append((int(np.median(xs[lo:hi])), p[1]))
    return out


ys_sorted = sorted(rows_l)
left_pts = rdp(median_smooth([(rows_l[y], y) for y in ys_sorted]), 4)
right_pts = rdp(median_smooth([(rows_r[y], y) for y in ys_sorted if y >= 392]), 4)
# 躯干多边形（顺时针）：左缘 ↓ → 底边 → 右缘 ↑（注意右缘要 bottom→top）
# → 顶 = 切割线+tuck（不描边）
ybot = max(y for y in ys_sorted if y >= 392)
TORSO_POLY = (left_pts + [(right_pts[-1][0], ybot)] + list(reversed(right_pts))
              + list(reversed(CUT)))
N_CUT_EDGES = len(CUT)          # 末尾 CUT 段（含闭合边）不描边


def new_canvas():
    return Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))


def spts(pts):
    return [(x * SS, y * SS) for x, y in pts]


def draw_poly(img, pts, fill, stroke=True):
    d = ImageDraw.Draw(img)
    d.polygon(spts(pts), fill=fill + (255,))
    if stroke:
        d.line(spts(pts) + [spts(pts)[0]], fill=BLACK + (255,),
               width=STROKE * SS, joint="curve")


def draw_poly_open_tail(img, pts, fill, open_tail_edges):
    """填充多边形；最后 open_tail_edges 条边不描（切割线开边）。"""
    d = ImageDraw.Draw(img)
    d.polygon(spts(pts), fill=fill + (255,))
    n = len(pts)
    for i in range(n - open_tail_edges):
        a, b = pts[i], pts[(i + 1) % n]
        d.line([a[0] * SS, a[1] * SS, b[0] * SS, b[1] * SS],
               fill=BLACK + (255,), width=STROKE * SS)


def draw_poly_open(img, pts, fill, skip_edge):
    d = ImageDraw.Draw(img)
    d.polygon(spts(pts), fill=fill + (255,))
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        if skip_edge(a, b):
            continue
        d.line([a[0] * SS, a[1] * SS, b[0] * SS, b[1] * SS],
               fill=BLACK + (255,), width=STROKE * SS)


def downscale(img):
    return img.resize((W, H), Image.LANCZOS)


def paste_original(dst_part, keep_mask):
    arr = np.array(dst_part)
    src = OA.copy()
    src[~keep_mask] = (0, 0, 0, 0)
    sm = src[:, :, 3] > 0
    arr[sm] = src[sm]
    return Image.fromarray(arr, "RGBA")


def ellipse_backing(img, cx, cy, rx, ry, fill):
    ImageDraw.Draw(img).ellipse([(cx - rx) * SS, (cy - ry) * SS,
                                 (cx + rx) * SS, (cy + ry) * SS], fill=fill + (255,))


parts = {}

# ---- 头：原图区域像素（轮廓完整）+ 颈部补画（压在躯干青蓝上，不可见） ----
c = new_canvas()
ellipse_backing(c, 490, 350, 85, 45, TEAL)
part = downscale(c)
part = paste_original(part, HEAD_REGION)
parts["head"] = part

# ---- 躯干：逐行轮廓重建 + 腹块贴原图 + 头后补画 ----
c = new_canvas()
draw_poly_open_tail(c, TORSO_POLY, TEAL, N_CUT_EDGES)
ellipse_backing(c, 520, 395, 90, 50, TEAL)      # 头后补画（抬头时露出）
part = downscale(c)
tm = Image.new("L", (W, H), 0)
ImageDraw.Draw(tm).polygon(TORSO_POLY + [TORSO_POLY[0]], fill=255)
torso_mask = np.asarray(tm) > 0
keep = (IS_CREAM & dilate(belly, 2)) | (IS_BLACK & dilate(belly, 14) & torso_mask)
part = paste_original(part, keep)
parts["torso"] = part

# ---- 上臂：胶囊重绘 + 肩包（探到躯干青蓝上，不可见） ----
UARM_POLY = fit_poly(dilate(uarm, 7), 6)  # 拟合到描边中线，描边骑缝齐平  # 对填色区拟合，描边骑缝=与原图齐平
c = new_canvas()
ellipse_backing(c, 455, 335, 62, 38, TEAL)
draw_poly(c, UARM_POLY, TEAL)
parts["upper_arm"] = downscale(c)

# ---- 前臂：八边形重绘（灰护甲即前臂本体，底色直接用灰，杜绝描边间青蓝细缝） ----
FARM_POLY = fit_poly(dilate(armor, 7), 8)
c = new_canvas()
ellipse_backing(c, 455, 512, 55, 25, TEAL)
draw_poly(c, FARM_POLY, GRAY)
part = downscale(c)
pm = Image.new("L", (W, H), 0)
ImageDraw.Draw(pm).polygon(FARM_POLY + [FARM_POLY[0]], fill=255)
poly_mask = np.asarray(pm) > 0
keep = (IS_GRAY & dilate(armor, 2)) | (IS_BLACK & dilate(armor, 9) & poly_mask)
part = paste_original(part, keep)
parts["forearm"] = part

# ---- 爪：腕掌（沙漏形非凸→逐行扫描轮廓，不用凸包）+ 3 爪（根不封口） ----
_pm = dilate(palm_full, 7)          # 描边中线层
_rows = {}
for _y in range(675, 812):
    _xs = np.where(_pm[_y, 340:610])[0] + 340
    if len(_xs):
        _rows[_y] = (int(_xs.min()), int(_xs.max()))
_pys = sorted(_rows)
PALM_POLY = (rdp(median_smooth([(_rows[y][0], y) for y in _pys]), 4)
             + list(reversed(rdp(median_smooth([(_rows[y][1], y) for y in _pys]), 4))))
CLAW_POLYS = [fit_poly(dilate(cm, 5), 5) for cm in claw_imgs]
c = new_canvas()
ellipse_backing(c, 470, 692, 58, 22, GRAY)      # 腕包（探到护甲灰底上，不可见）
draw_poly(c, PALM_POLY, TEAL)
for p in CLAW_POLYS:
    draw_poly_open(c, p, CREAM, skip_edge=lambda a, b: a[1] < 780 and b[1] < 780)
parts["claw"] = downscale(c)

# ---- 腿脚一体：腿柱 + 脚掌各自描边（踝部双线属原设计）+ 髋包（被爪件盖住） ----
LEG_POLY = fit_poly(dilate(leg, 7), 6)
FOOT_POLY = fit_poly(dilate(foot, 7), 6)
c = new_canvas()
ellipse_backing(c, 490, 812, 62, 32, TEAL)
draw_poly(c, LEG_POLY, TEAL)
draw_poly(c, FOOT_POLY, TEAL)
parts["leg_foot"] = downscale(c)

for name, img in parts.items():
    img.save(os.path.join(OUT, f"{name}.png"))

# ---------------- pivots.json ----------------
foot_xs = [p[0] for p in FOOT_POLY]
foot_ys = [p[1] for p in FOOT_POLY]
root_x = int((min(foot_xs) + max(foot_xs)) / 2)
root_y = int(max(foot_ys))
pivots = {
    "canvas": [W, H],
    "coordinate_system": "origin top-left, +X right, +Y down, pixels of the 1024x1024 master canvas",
    "source_view": "geobear_stand_03_right.png（纯侧面，鼻尖朝画面右）",
    "root": {"pos": [root_x, root_y], "note": "整体定位点：脚掌底边中点"},
    "parts": {
        "torso":     {"pivot": [622, 578], "parent": None,        "note": "腹部色块中心，整棵树的根"},
        "head":      {"pivot": [510, 355], "parent": "torso",     "note": "颈部连接处（人工切割线中点附近）"},
        "upper_arm": {"pivot": [455, 330], "parent": "torso",     "note": "肩关节（上臂顶）"},
        "forearm":   {"pivot": [455, 508], "parent": "upper_arm", "note": "肘关节（上臂底/护甲顶之间）"},
        "claw":      {"pivot": [470, 688], "parent": "forearm",   "note": "腕关节（掌顶）"},
        "leg_foot":  {"pivot": [490, 812], "parent": "torso",     "note": "髋部（腿柱顶，缺口被爪件遮盖）"},
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
preview = Image.new("RGB", (W * 2 + 60, H + 40), (232, 232, 232))
preview.paste(assembled, (20, 20), assembled)
preview.paste(orig, (W + 40, 20), orig)
preview.save(os.path.join(OUT, "assembled_preview.png"))

# alpha 感知 diff（手册 §8：原图透明像素 RGB 非零，直接比 RGB 会误报）
a = np.array(assembled).astype(int)
o = OA.astype(int)
am = (a[:, :, 3] > 0) != (o[:, :, 3] > 0)
both = (a[:, :, 3] > 0) & (o[:, :, 3] > 0)
rgbm = (np.abs(a[:, :, :3] - o[:, :, :3]).sum(axis=2) > 30) & both
print("assembled vs original | alpha-diff px:", int(am.sum()),
      f"({100 * am.sum() / OPAQUE.sum():.2f}%)", " rgb-diff px:", int(rgbm.sum()))

# ---------------- 关节活动检查：抬臂 90° + 弯肘 90° + 转腕 45° + 抬头 15° ----------------
def rot(img, angle, cx, cy):
    return img.rotate(angle, resample=Image.BICUBIC, center=(cx, cy), fillcolor=(0, 0, 0, 0))


def rot_point(p, angle_deg, c_):
    a_ = math.radians(angle_deg)
    dx, dy = p[0] - c_[0], p[1] - c_[1]
    return (c_[0] + dx * math.cos(a_) + dy * math.sin(a_),
            c_[1] - dx * math.sin(a_) + dy * math.cos(a_))


S = (455, 330)
E = (455, 508)
WP = (470, 688)
TH_S, TH_E, TH_W, TH_H = 90.0, -90.0, 45.0, 15.0
E1 = rot_point(E, TH_S, S)
W1 = rot_point(rot_point(WP, TH_S, S), TH_E, E1)
posed = assemble({
    "upper_arm": rot(parts["upper_arm"], TH_S, *S),
    "forearm": rot(rot(parts["forearm"], TH_S, *S), TH_E, *E1),
    "claw": rot(rot(rot(parts["claw"], TH_S, *S), TH_E, *E1), TH_W, *W1),
    "head": rot(parts["head"], TH_H, *pivots["parts"]["head"]["pivot"]),
})
art_prev = Image.new("RGB", (W * 2 + 60, H + 40), (232, 232, 232))
art_prev.paste(assembled, (20, 20), assembled)
art_prev.paste(posed, (W + 40, 20), posed)
art_prev.save(os.path.join(OUT, "articulation_preview.png"))

# ---------------- 分件展示 ----------------
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
print("geobear right-side split done ->", OUT)
