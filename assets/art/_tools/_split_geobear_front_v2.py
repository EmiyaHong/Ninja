# -*- coding: utf-8 -*-
"""geobear front split v2 — clean-edged game-ready parts.

v1 cut parts from the raster with hand polygons -> jagged seams, speckles.
v2 approach:
  - every part silhouette = fitted primitives (measured from the 6-color master)
    drawn at 4x supersample -> smooth, flush, anti-aliased edges;
  - interior detail = original pixels (face, armor plate, belly, claw roots);
  - hidden joint backing = flat primitive fills (circles/ellipses), no stroke;
  - cleanup rules repaint foreign marks inside each part (no armor in upper arm,
    no belly in legs, no claw-root marks in forearm bottom).

Outputs: geometric/geobear/parts/front/{10 parts, pivots.json,
assembled_preview.png, parts_preview.png, articulation_preview.png, README.md}
"""
import json
import math
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ART, "geometric", "geobear", "geobear_stand_01_front.png")
OUT = os.path.join(ART, "geometric", "geobear", "parts", "front")
os.makedirs(OUT, exist_ok=True)

W = H = 1254
SS = 4                      # supersample factor
STROKE = 13                 # outline width in 1x px
TEAL = (25, 99, 101)
BLACK = (6, 7, 11)
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
    """Pick the connected component whose bbox best matches the expected
    (x0,y0,x1,y1) — robust against neighboring parts touching the hint rect."""
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


# ---------------- geometry fitting ----------------

def hull_points(mask):
    """Boundary points -> convex hull (monotonic chain), 1x coords."""
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
    """Ramer-Douglas-Peucker on a closed polygon."""
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
        # polygon chain from i to j (wrapping)
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
    # anchor at the two farthest points
    cx = sum(p[0] for p in points) / n
    cy = sum(p[1] for p in points) / n
    i0 = max(range(n), key=lambda i: (points[i][0] - cx) ** 2 + (points[i][1] - cy) ** 2)
    j0 = max(range(n), key=lambda i: -((points[i][0] - points[i0][0]) ** 2 + (points[i][1] - points[i0][1]) ** 2))
    rec(i0, j0)
    rec(j0, i0)
    return [p for p, k in zip(points, keep) if k]


def fit_poly(mask, eps=7.0):
    return rdp(hull_points(mask), eps)


def with_ring(mask, ring_px=15):
    return mask | (IS_BLACK & dilate(mask, ring_px))


# measure components (bbox-signature matching, no accidental merging)
head_teal = comp_by_bbox(IS_TEAL, (443, 93, 810, 405))
ear_r = comp_by_bbox(IS_TEAL, (410, 58, 522, 168))    # screen-left ear = char right
ear_l = comp_by_bbox(IS_TEAL, (730, 57, 842, 168))
torso_teal = comp_by_bbox(IS_TEAL, (340, 304, 912, 861))
belly = comp_by_bbox(IS_CREAM, (430, 470, 821, 865))
uarm_r = comp_by_bbox(IS_TEAL, (197, 363, 357, 581))
uarm_l = comp_by_bbox(IS_TEAL, (896, 363, 1056, 581))
farm_r = comp_by_bbox(IS_TEAL, (78, 598, 336, 873))
farm_l = comp_by_bbox(IS_TEAL, (917, 598, 1175, 873))
armor_r = comp_by_bbox(IS_GRAY, (70, 533, 280, 797))
armor_l = comp_by_bbox(IS_GRAY, (972, 533, 1183, 797))
leg_r = comp_by_bbox(IS_TEAL, (376, 839, 555, 1045))
leg_l = comp_by_bbox(IS_TEAL, (697, 840, 876, 1045))
foot_r = comp_by_bbox(IS_TEAL, (260, 1063, 558, 1164))
foot_l = comp_by_bbox(IS_TEAL, (694, 1063, 993, 1164))
claw_r_imgs = [comp_by_bbox(IS_CREAM, (89, 872, 137, 959)),
               comp_by_bbox(IS_CREAM, (156, 875, 210, 967)),
               comp_by_bbox(IS_CREAM, (235, 848, 287, 936))]
claw_l_imgs = [comp_by_bbox(IS_CREAM, (966, 848, 1017, 940)),
               comp_by_bbox(IS_CREAM, (1042, 874, 1097, 960)),
               comp_by_bbox(IS_CREAM, (1115, 872, 1164, 957))]

# fitted primitives
head_bb = ndimage.find_objects(ndimage.label(with_ring(head_teal))[0])
ys, xs = np.where(with_ring(head_teal))
HEAD_E = ((xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2,
          (xs.max() - xs.min()) / 2, (ys.max() - ys.min()) / 2)


def circ(mask):
    ys, xs = np.where(with_ring(mask))
    return ((xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2,
            max(xs.max() - xs.min(), ys.max() - ys.min()) / 2)


EAR_R, EAR_L = circ(ear_r), circ(ear_l)
UARM_R_POLY = fit_poly(with_ring(uarm_r), 6)
UARM_L_POLY = fit_poly(with_ring(uarm_l), 6)
FARM_R_POLY = fit_poly(with_ring(farm_r | armor_r), 8)
FARM_L_POLY = fit_poly(with_ring(farm_l | armor_l), 8)
LEG_R_POLY = fit_poly(with_ring(leg_r), 6)
LEG_L_POLY = fit_poly(with_ring(leg_l), 6)
FOOT_R_POLY = fit_poly(with_ring(foot_r), 6)
FOOT_L_POLY = fit_poly(with_ring(foot_l), 6)
CLAW_R_POLYS = [fit_poly(with_ring(c, 11), 5) for c in claw_r_imgs]
CLAW_L_POLYS = [fit_poly(with_ring(c, 11), 5) for c in claw_l_imgs]
BELLY_POLY = fit_poly(belly, 8)


def torso_silhouette():
    """Row-scan the real torso outline (arms/head excluded), RDP-smoothed."""
    arm_excl = np.zeros((H, W), dtype=bool)
    for m in (with_ring(uarm_r), with_ring(uarm_l),
              with_ring(farm_r | armor_r), with_ring(farm_l | armor_l)):
        arm_excl |= dilate(m, 8)
    head_excl = dilate(head_teal, 20)
    pts_l, pts_r = [], []
    for y in range(290, 886, 3):
        row = OPAQUE[y].copy()
        row[:300] = False
        row[930:] = False
        row &= ~head_excl[y] & ~arm_excl[y]
        xs2 = np.where(row)[0]
        if len(xs2):
            pts_l.append((int(xs2.min()), y))
            pts_r.append((int(xs2.max()), y))
    left = rdp(pts_l, 4)
    right = rdp(pts_r[::-1], 4)[::-1]
    return left + [(627, 878)] + right[::-1]


TORSO_POLY = torso_silhouette()

# ---------------- drawing helpers ----------------

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


def draw_poly_open(img, pts, fill, skip_edge):
    """Fill polygon; stroke every edge except those where skip_edge(a, b) is True
    (used to leave claw roots / palm cut lines unsealed)."""
    d = ImageDraw.Draw(img)
    d.polygon(spts(pts), fill=fill + (255,))
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        if skip_edge(a, b):
            continue
        d.line([a[0] * SS, a[1] * SS, b[0] * SS, b[1] * SS],
               fill=BLACK + (255,), width=STROKE * SS)


def draw_ellipse(img, cx, cy, rx, ry, fill, stroke=True):
    d = ImageDraw.Draw(img)
    box = [(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS]
    d.ellipse(box, fill=fill + (255,))
    if stroke:
        d.ellipse(box, outline=BLACK + (255,), width=STROKE * SS)


def downscale(img):
    return img.resize((W, H), Image.LANCZOS)


def paste_original(dst_part, keep_mask):
    """Paste original RGBA pixels where keep_mask is True into 1x part array."""
    arr = np.array(dst_part)
    src = OA.copy()
    src[~keep_mask] = (0, 0, 0, 0)
    sm = src[:, :, 3] > 0
    arr[sm] = src[sm]
    return Image.fromarray(arr, "RGBA")


def boundary_band(mask, width=16):
    return mask & ~erode(mask, width)


parts = {}

# ---- torso: clean silhouette + original belly + belly outline + own outline ----
tm = Image.new("L", (W, H), 0)
ImageDraw.Draw(tm).polygon(TORSO_POLY + [TORSO_POLY[0]], fill=255)
torso_mask = np.asarray(tm) > 0
c = new_canvas()
draw_poly(c, TORSO_POLY, TEAL)                                  # silhouette
belly_m = np.asarray(Image.new("L", (W, H), 0))                 # placeholder
bm = Image.new("L", (W, H), 0)
ImageDraw.Draw(bm).polygon(BELLY_POLY + [BELLY_POLY[0]], fill=255)
belly_poly_mask = np.asarray(bm) > 0
# interior: original cream belly + its outline, pasted onto 1x result later
part = downscale(c)
keep = (IS_CREAM & belly_poly_mask) | (IS_BLACK & dilate(belly, 14) & torso_mask)
part = paste_original(part, keep)
parts["torso"] = part

# ---- head: fitted circles, interior fully original ----
c = new_canvas()
draw_ellipse(c, *HEAD_E, TEAL)
draw_ellipse(c, EAR_R[0], EAR_R[1], EAR_R[2], EAR_R[2], TEAL)
draw_ellipse(c, EAR_L[0], EAR_L[1], EAR_L[2], EAR_L[2], TEAL)
# neck stump (hidden fill, no stroke)
d4 = ImageDraw.Draw(c)
d4.ellipse([(627 - 88) * SS, (392 - 45) * SS, (627 + 88) * SS, (392 + 45) * SS],
           fill=TEAL + (255,))
part = downscale(c)
head_mask = (np.array(part)[:, :, 3] > 0)
interior = erode(head_mask, 18)          # keep original face/fur inside the edge
part = paste_original(part, interior)
parts["head"] = part

# ---- upper arms: pure redraw (no interior detail) + shoulder ball ----
for name, poly, sh in (("upper_arm_r", UARM_R_POLY, (300, 420)), ("upper_arm_l", UARM_L_POLY, (954, 420))):
    c = new_canvas()
    d4 = ImageDraw.Draw(c)
    d4.ellipse([(sh[0] - 58) * SS, (sh[1] - 55) * SS, (sh[0] + 58) * SS, (sh[1] + 55) * SS],
               fill=TEAL + (255,))                       # shoulder backing (hidden)
    draw_poly(c, poly, TEAL)
    parts[name] = downscale(c)

# ---- forearms: redrawn hexagon (clean stroke only) + original armor plate ----
for name, poly, armor in (("forearm_r", FARM_R_POLY, armor_r), ("forearm_l", FARM_L_POLY, armor_l)):
    c = new_canvas()
    d4 = ImageDraw.Draw(c)
    ex = 270 if name.endswith("_r") else 984
    d4.ellipse([(ex - 50) * SS, (560 - 30) * SS, (ex + 50) * SS, (560 + 30) * SS],
               fill=TEAL + (255,))                       # elbow backing (hidden)
    draw_poly(c, poly, TEAL)
    part = downscale(c)
    pm = Image.new("L", (W, H), 0)
    ImageDraw.Draw(pm).polygon(poly + [poly[0]], fill=255)
    poly_mask = np.asarray(pm) > 0
    # paste ONLY interior content: armor plate + its outline ring.
    # silhouette black comes from the redrawn stroke alone -> flush edges.
    keep = (IS_GRAY & dilate(armor, 2)) | (IS_BLACK & dilate(armor, 9) & ~boundary_band(poly_mask, 10))
    part = paste_original(part, keep)
    parts[name] = part

# ---- claws: palm polygon (= forearm bottom tip, stroked) + 3 triangles ----
def palm_poly(farm_mask):
    """Palm = forearm bottom tip. Rebuilt as a clean trapezoid-ish polygon from the
    hexagon silhouette's real width at the cut line and its bottom vertex,
    avoiding hull bumps from claw-root outline residue."""
    fm = farm_mask.copy()
    fm[:815, :] = False
    ys, xs = np.where(fm)
    y_top = 828
    row = farm_mask[y_top]
    rxs = np.where(row)[0]
    lx, rx = int(rxs.min()) - 4, int(rxs.max()) + 4
    # bottom tip of the region
    tip_y = int(ys.max())
    tip_x = int(xs[ys == ys.max()].mean())
    return [(lx, y_top), (rx, y_top), (int(tip_x + (rx - tip_x) * 0.9), int(tip_y * 0.72 + y_top * 0.28)),
            (tip_x, tip_y), (int(tip_x + (lx - tip_x) * 0.9), int(tip_y * 0.72 + y_top * 0.28))]


for name, polys, fm in (("claw_r", CLAW_R_POLYS, with_ring(farm_r | armor_r)),
                        ("claw_l", CLAW_L_POLYS, with_ring(farm_l | armor_l))):
    palm = palm_poly(fm)
    c = new_canvas()
    # palm = forearm bottom tip; do NOT stroke its top cut edge (no line across the wrist)
    draw_poly_open(c, palm, TEAL, skip_edge=lambda a, b: a[1] < 832 and b[1] < 832)
    for p in polys:
        # claw triangles: stroke the two side edges, leave the root (top edge) open
        draw_poly_open(c, p, CREAM,
                       skip_edge=lambda a, b: a[1] < 875 and b[1] < 875)
    parts[name] = downscale(c)

# ---- legs: pure redraw (leg polygon + foot trapezoid), no pasted outline ----
for name, lp, fp, hx in (("leg_foot_r", LEG_R_POLY, FOOT_R_POLY, 465),
                         ("leg_foot_l", LEG_L_POLY, FOOT_L_POLY, 789)):
    c = new_canvas()
    d4 = ImageDraw.Draw(c)
    d4.ellipse([(hx - 60) * SS, (838 - 24) * SS, (hx + 60) * SS, (838 + 24) * SS],
               fill=TEAL + (255,))                       # hip backing (hidden)
    draw_poly(c, lp, TEAL)
    draw_poly(c, fp, TEAL)
    parts[name] = downscale(c)

for name, img in parts.items():
    img.save(os.path.join(OUT, f"{name}.png"))

# ---------------- pivots.json ----------------
pivots = {
    "canvas": [W, H],
    "coordinate_system": "origin top-left, +X right, +Y down, pixels of the 1254x1254 master canvas",
    "root": {"pos": [627, 1164], "note": "整体定位点：两脚脚底中央的底边中点"},
    "parts": {
        "torso":       {"pivot": [627, 590],  "parent": None,          "note": "躯干中心（腹部色块中心），整棵树的根"},
        "head":        {"pivot": [627, 400],  "parent": "torso",       "note": "颈部连接处"},
        "upper_arm_r": {"pivot": [300, 420],  "parent": "torso",       "note": "肩关节（角色右侧=屏幕左侧）"},
        "upper_arm_l": {"pivot": [954, 420],  "parent": "torso",       "note": "肩关节"},
        "forearm_r":   {"pivot": [270, 585],  "parent": "upper_arm_r", "note": "肘关节"},
        "forearm_l":   {"pivot": [984, 585],  "parent": "upper_arm_l", "note": "肘关节"},
        "claw_r":      {"pivot": [190, 852],  "parent": "forearm_r",   "note": "腕关节"},
        "claw_l":      {"pivot": [1064, 852], "parent": "forearm_l",   "note": "腕关节"},
        "leg_foot_r":  {"pivot": [465, 845],  "parent": "torso",       "note": "髋部连接处"},
        "leg_foot_l":  {"pivot": [789, 845],  "parent": "torso",       "note": "髋部连接处"},
    },
    "draw_order_back_to_front": [
        "torso", "leg_foot_r", "leg_foot_l",
        "forearm_r", "forearm_l",
        "upper_arm_r", "upper_arm_l",
        "claw_r", "claw_l", "head",
    ],
    "mirror_rule": "右侧部件 pivot.x = 1254 - 左侧对应 pivot.x",
}
with open(os.path.join(OUT, "pivots.json"), "w", encoding="utf-8") as f:
    json.dump(pivots, f, ensure_ascii=False, indent=2)

DRAW_ORDER = pivots["draw_order_back_to_front"]


def assemble(transforms=None):
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for name in DRAW_ORDER:
        img = parts[name]
        if transforms and name in transforms:
            img = transforms[name]
        canvas.alpha_composite(img)
    return canvas


assembled = assemble()
preview = Image.new("RGB", (W * 2 + 60, H + 40), (232, 232, 232))
preview.paste(assembled, (20, 20), assembled)
preview.paste(orig, (W + 40, 20), orig)
preview.save(os.path.join(OUT, "assembled_preview.png"))

# alpha-aware diff report
a = np.array(assembled).astype(int)
o = OA.astype(int)
am = (a[:, :, 3] > 0) != (o[:, :, 3] > 0)
both = (a[:, :, 3] > 0) & (o[:, :, 3] > 0)
rgbm = (np.abs(a[:, :, :3] - o[:, :, :3]).sum(axis=2) > 30) & both
print("assembled vs original | alpha-diff:", int(am.sum()), "rgb-diff:", int(rgbm.sum()))

# ---------------- articulation preview ----------------
def rot(img, angle, cx, cy):
    return img.rotate(angle, resample=Image.BICUBIC, center=(cx, cy), fillcolor=(0, 0, 0, 0))


def rot_point(p, angle_deg, c):
    a_ = math.radians(angle_deg)
    dx, dy = p[0] - c[0], p[1] - c[1]
    return (c[0] + dx * math.cos(a_) + dy * math.sin(a_),
            c[1] - dx * math.sin(a_) + dy * math.cos(a_))


S = (300, 420)
E = (270, 585)
WP = (190, 852)
TH_S, TH_E, TH_W = 90.0, -90.0, 45.0
E1 = rot_point(E, TH_S, S)
W1 = rot_point(rot_point(WP, TH_S, S), TH_E, E1)
t_upper = rot(parts["upper_arm_r"], TH_S, *S)
t_fore = rot(rot(parts["forearm_r"], TH_S, *S), TH_E, *E1)
t_claw = rot(rot(rot(parts["claw_r"], TH_S, *S), TH_E, *E1), TH_W, *W1)
posed = assemble({"upper_arm_r": t_upper, "forearm_r": t_fore, "claw_r": t_claw})
art_prev = Image.new("RGB", (W * 2 + 60, H + 40), (232, 232, 232))
art_prev.paste(assembled, (20, 20), assembled)
art_prev.paste(posed, (W + 40, 20), posed)
art_prev.save(os.path.join(OUT, "articulation_preview.png"))

# ---------------- parts preview ----------------
try:
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 26)
except OSError:
    font = ImageFont.load_default()
CELL = 400
names = ["head", "torso", "upper_arm_r", "upper_arm_l", "forearm_r",
         "forearm_l", "claw_r", "claw_l", "leg_foot_r", "leg_foot_l"]
sheet = Image.new("RGB", (CELL * 5, CELL * 2), (245, 245, 245))
d = ImageDraw.Draw(sheet)
for i, name in enumerate(names):
    img = parts[name]
    bb = img.getbbox()
    crop = img.crop(bb)
    scale = min((CELL - 80) / crop.width, (CELL - 110) / crop.height)
    thumb = crop.resize((max(1, round(crop.width * scale)), max(1, round(crop.height * scale))), Image.LANCZOS)
    cx, cy = (i % 5) * CELL, (i // 5) * CELL
    sheet.paste(thumb, (cx + (CELL - thumb.width) // 2, cy + (CELL - 60 - thumb.height) // 2), thumb)
    tw = d.textlength(name, font=font)
    d.text((cx + (CELL - tw) / 2, cy + CELL - 48), name, fill=(20, 20, 20), font=font)
    d.rectangle([cx, cy, cx + CELL - 1, cy + CELL - 1], outline=(200, 200, 200))
sheet.save(os.path.join(OUT, "parts_preview.png"))
print("v2 done")
