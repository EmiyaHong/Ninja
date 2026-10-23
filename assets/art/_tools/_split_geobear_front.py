# -*- coding: utf-8 -*-
"""Split geobear_stand_01_front.png into 10 articulated parts (front view).
- Same 1254x1254 canvas, parts stay at original positions.
- Hidden joint areas filled flat (teal), exposed outlines stay with their parts.
- Overlapping outlines are all the same near-black, so coincident seams are invisible.
Outputs: parts/front/*.png + pivots.json + assembled/articulation/parts previews + README.
"""
import json
import math
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # assets/art
SRC = os.path.join(ART, "geometric", "geobear", "geobear_stand_01_front.png")
OUT = os.path.join(ART, "geometric", "geobear", "parts", "front")
os.makedirs(OUT, exist_ok=True)

W = H = 1254
TEAL = (25, 99, 101, 255)

orig = Image.open(SRC).convert("RGBA")
orig_arr = np.array(orig)


def mask_image():
    return Image.new("L", (W, H), 0)


def region_mask(shapes, subtract=None):
    """shapes: list of ('poly', pts) / ('ellipse', cx, cy, rx, ry) / ('rect', x0,y0,x1,y1)."""
    m = mask_image()
    d = ImageDraw.Draw(m)
    for kind, *a in shapes:
        if kind == "poly":
            d.polygon(a[0], fill=255)
        elif kind == "ellipse":
            cx, cy, rx, ry = a
            d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
        elif kind == "rect":
            d.rectangle(a[0], fill=255)
    if subtract is not None:
        m = Image.fromarray(np.asarray(m) & ~np.asarray(subtract))
    return m


HEAD_SHAPES = [
    ("ellipse", 627, 240, 212, 212),
    ("ellipse", 466, 112, 78, 78),
    ("ellipse", 786, 112, 78, 78),
]
head_mask = region_mask(HEAD_SHAPES)

TORSO_POLY = [(325, 315), (350, 298), (905, 298), (930, 315),
              (918, 865), (880, 880), (700, 880), (627, 922),
              (555, 880), (375, 880), (332, 865)]


def measure_torso_poly():
    """Measure the real torso silhouette row by row from the original image.
    Central band x300-930, head circle excluded, arm/forearm/claw regions excluded
    (they intrude past x300). Legs stay (hidden fills under the leg parts)."""
    opaque = orig_arr[:, :, 3] > 0
    head_excl = np.asarray(head_mask) > 0
    arm_excl = np.zeros((H, W), dtype=bool)
    for n in ("upper_arm_r", "upper_arm_l", "forearm_r", "forearm_l", "claw_r", "claw_l"):
        arm_excl |= np.asarray(regions[n]) > 0
    # dilate exclusion by 8px to swallow outline spillover past the region edges
    arm_excl = np.asarray(
        Image.fromarray((arm_excl * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(17))) > 0
    ys = list(range(292, 896))
    left_pts, right_pts = [], []
    for y in ys:
        row = opaque[y].copy()
        row[:300] = False
        row[930:] = False
        row &= ~head_excl[y]
        row &= ~arm_excl[y]
        xs = np.where(row)[0]
        if len(xs) == 0:
            continue
        left_pts.append((int(xs.min()), y))
        right_pts.append((int(xs.max()), y))
    # decimate to one point every ~25px vertically
    lp = left_pts[::25] + [left_pts[-1]]
    rp = right_pts[::25] + [right_pts[-1]]
    poly = lp + [(627, 880)] + rp[::-1]
    return poly

# part region masks (original pixels)
regions = {
    "head": head_mask,
    "upper_arm_r": region_mask([("rect", (180, 348, 372, 604))]),
    "upper_arm_l": region_mask([("rect", (882, 348, 1074, 604))]),
    "forearm_r": region_mask(
        [("poly", [(50, 530), (285, 520), (345, 600), (342, 878), (290, 890), (68, 890), (50, 600)])],
        subtract=region_mask([("rect", (180, 348, 376, 606))])),
    "forearm_l": region_mask(
        [("poly", [(1204, 530), (969, 520), (909, 600), (912, 878), (964, 890), (1186, 890), (1204, 600)])],
        subtract=region_mask([("rect", (878, 348, 1074, 606))])),
    "claw_r": region_mask([("rect", (72, 832, 310, 1000))]),
    "claw_l": region_mask([("rect", (944, 832, 1182, 1000))]),
    "leg_foot_r": region_mask([("rect", (238, 815, 585, 1188))]),
    "leg_foot_l": region_mask([("rect", (669, 815, 1016, 1188))]),
}

# --- elbow zones: color-aware split so the gray armor never leaks into the upper arm ---
# teal -> upper arm, gray -> forearm, black -> nearest of the two
from scipy import ndimage as _ndi

for ua, fa, (x0, y0, x1, y1) in (("upper_arm_r", "forearm_r", (170, 490, 390, 615)),
                                 ("upper_arm_l", "forearm_l", (864, 490, 1084, 615))):
    zone = np.zeros((H, W), dtype=bool)
    zone[y0:y1, x0:x1] = True
    rgb = orig_arr[:, :, :3]
    is_teal = np.all(rgb == (25, 99, 101), axis=2) & zone
    is_gray = np.all(rgb == (92, 95, 102), axis=2) & zone
    seeds = is_teal | is_gray
    _, idx = _ndi.distance_transform_edt(~seeds, return_indices=True)
    # label map: 0=none, 1=teal(upper arm), 2=gray(forearm) — then majority-smooth
    # so the black outline between them is split in one clean sweep, not speckled
    label = np.zeros((H, W), dtype=np.uint8)
    label[zone & (orig_arr[:, :, 3] > 0)] = 1
    label[is_gray] = 2
    lab_s = np.zeros_like(label)
    ys0, ys1 = max(0, y0 - 12), min(H, y1 + 12)
    xs0, xs1 = max(0, x0 - 12), min(W, x1 + 12)
    lab_s[ys0:ys1, xs0:xs1] = _ndi.median_filter(label[ys0:ys1, xs0:xs1], size=13)
    ua_m = np.asarray(regions[ua]) > 0
    fa_m = np.asarray(regions[fa]) > 0
    zm = zone & (orig_arr[:, :, 3] > 0)
    owns_gray = zm & (lab_s == 2)
    owns_teal = zm & (lab_s != 2)
    ua_m = (ua_m & ~zone) | owns_teal
    fa_m = (fa_m & ~zone) | owns_gray
    regions[ua] = Image.fromarray((ua_m * 255).astype(np.uint8))
    regions[fa] = Image.fromarray((fa_m * 255).astype(np.uint8))

# --- torso is rebuilt as a clean procedural surface ---
# teal silhouette + cream belly + own outlines only (no arm/leg/head marks baked in)
BLACK = (6, 7, 11)
CREAM = (252, 236, 203)
TORSO_POLY = measure_torso_poly()
torso_poly_mask = np.asarray(region_mask([("poly", TORSO_POLY)])) > 0
is_black = np.all(orig_arr[:, :, :3] == BLACK, axis=2) & (orig_arr[:, :, 3] > 0)
is_cream = np.all(orig_arr[:, :, :3] == CREAM, axis=2) & (orig_arr[:, :, 3] > 0)
torso_surface = np.zeros((H, W, 4), dtype=np.uint8)
torso_surface[torso_poly_mask] = TEAL
belly = is_cream & torso_poly_mask
torso_surface[belly] = orig_arr[belly]
belly_zone = np.asarray(Image.fromarray((belly * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(31))) > 0
torso_outline = is_black & torso_poly_mask & ~np.asarray(
    Image.fromarray((torso_poly_mask * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(45))) > 0
torso_surface[torso_outline] = (6, 7, 11, 255)
torso_surface[is_black & belly_zone & torso_poly_mask] = (6, 7, 11, 255)
# neck fill under the chin: flat teal, no outline
neck = np.asarray(region_mask([("ellipse", 627, 385, 165, 70)])) > 0
torso_surface[neck & torso_poly_mask] = TEAL

# --- legs must not steal belly cream or claw tips: drop torso-poly and claw-zone
# pixels, but keep the leg's own top outline ---
for leg, claw, (x0, y0, x1, y1) in (("leg_foot_r", "claw_r", (370, 825, 560, 870)),
                                    ("leg_foot_l", "claw_l", (694, 825, 884, 870))):
    lm = np.asarray(regions[leg]) > 0
    lm &= ~torso_poly_mask                      # belly corner stays with torso
    lm &= ~(np.asarray(regions[claw]) > 0)      # claw tips stay with the claw part
    hip_zone = np.zeros((H, W), dtype=bool)
    hip_zone[y0:y1, x0:x1] = True
    hip_zone &= ~(np.asarray(regions[claw]) > 0)
    lm |= is_black & hip_zone                   # but keep the leg's own top outline
    regions[leg] = Image.fromarray((lm * 255).astype(np.uint8))

# hard overwrites (erase other parts' marks from this part): name -> list of shapes
overwrites = {
    "forearm_r": [("rect", (80, 832, 300, 868))],        # erase claw-root outlines
    "forearm_l": [("rect", (954, 832, 1174, 868))],
}

# hidden extension fills (transparent-only): name -> list of shapes
extensions = {
    "head": [("ellipse", 627, 392, 88, 45)],             # neck stump
    "upper_arm_r": [("ellipse", 300, 425, 58, 58)],      # shoulder ball
    "upper_arm_l": [("ellipse", 954, 425, 58, 58)],
    "forearm_r": [("ellipse", 270, 558, 55, 40)],        # elbow backing, rounded (no square shards when rotated)
    "forearm_l": [("ellipse", 984, 558, 55, 40)],
    "claw_r": [("ellipse", 190, 852, 95, 30)],           # wrist backing, rounded
    "claw_l": [("ellipse", 1064, 852, 95, 30)],
    # legs need no extension: the rebuilt torso surface is complete underneath
}

part_arrays = {}
for name, reg in regions.items():
    canvas = np.zeros((H, W, 4), dtype=np.uint8)
    rm = np.asarray(reg) > 0
    canvas[rm] = orig_arr[rm]
    # hard overwrite zones -> flat teal
    for sh in overwrites.get(name, []):
        om = np.asarray(region_mask([sh])) > 0
        canvas[om] = TEAL
    # hidden extension: fill only where still transparent
    for sh in extensions.get(name, []):
        em = np.asarray(region_mask([sh])) > 0
        fill = em & (canvas[:, :, 3] == 0)
        canvas[fill] = TEAL
    part_arrays[name] = canvas
part_arrays["torso"] = torso_surface

# sanity + fallback: every original opaque pixel must be claimed by >=1 region;
# seam stragglers go to the spatially nearest region (all outlines are the same black,
# so nearest-fill assignment is safe).
claimed = torso_poly_mask.copy()
for reg in regions.values():
    claimed |= np.asarray(reg) > 0
lost = (orig_arr[:, :, 3] > 0) & ~claimed
print("unclaimed original px before fallback:", int(lost.sum()))
if lost.sum() > 0:
    from scipy import ndimage
    _, nearest_idx = ndimage.distance_transform_edt(~claimed, return_indices=True)
    # build a label map: for each claimed pixel, which part owns it (first match wins)
    owner = np.full((H, W), "", dtype=object)
    owner[torso_poly_mask] = "torso"
    for name, reg in regions.items():
        m = (np.asarray(reg) > 0) & (owner == "")
        owner[m] = name
    ly, lx = np.where(lost)
    for y, x in zip(ly, lx):
        part_arrays[owner[nearest_idx[0, y, x], nearest_idx[1, y, x]]][y, x] = orig_arr[y, x]
    print("fallback assigned:", int(lost.sum()))

parts = {}
for name, arr in part_arrays.items():
    parts[name] = Image.fromarray(arr, "RGBA")
    parts[name].save(os.path.join(OUT, f"{name}.png"))
    ys, xs = np.where(arr[:, :, 3] > 0)
    print(f"{name}: bbox x{xs.min()}-{xs.max()} y{ys.min()}-{ys.max()} px={len(xs)}")

# ---------- pivots.json ----------
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

# ---------- assembled preview ----------
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

# diff metric (assembled vs original)
asm_arr = np.array(assembled)
diff = np.abs(asm_arr.astype(int) - orig_arr.astype(int))
vis = (orig_arr[:, :, 3] > 0)
diff_alpha = np.abs(diff[:, :, 3]) > 0
both_opaque = vis & (asm_arr[:, :, 3] > 0)
rgb_diff = (np.abs(diff[:, :, :3]).sum(axis=2) > 30) & both_opaque
print(f"assembled vs original: alpha-diff px={int(diff_alpha.sum())}, rgb-diff px={int(rgb_diff.sum())}")

# dump unclaimed-pixels map for debugging
lost_img = np.zeros((H, W, 4), dtype=np.uint8)
lost_img[lost] = (255, 0, 0, 255)
Image.fromarray(lost_img, "RGBA").save(os.path.join(OUT, "_debug_lost.png"))

# ---------- articulation preview (FK chain on character-right arm = screen-left) ----------
def rot(img, angle, cx, cy):
    return img.rotate(angle, resample=Image.BICUBIC, center=(cx, cy), fillcolor=(0, 0, 0, 0))

def rot_point(p, angle_deg, c):
    a = math.radians(angle_deg)  # PIL rotate = counter-clockwise in screen coords (y down)
    dx, dy = p[0] - c[0], p[1] - c[1]
    # PIL's rotate(angle) rotates the IMAGE counter-clockwise around center in image coords
    x = dx * math.cos(a) + dy * math.sin(a)
    y = -dx * math.sin(a) + dy * math.cos(a)
    return (c[0] + x, c[1] + y)

S = tuple(pivots["parts"]["upper_arm_r"]["pivot"])
E = tuple(pivots["parts"]["forearm_r"]["pivot"])
Wr = tuple(pivots["parts"]["claw_r"]["pivot"])
TH_S, TH_E, TH_W = 90.0, -90.0, 45.0   # 抬臂90 / 弯肘90 / 转腕45

E1 = rot_point(E, TH_S, S)
W1 = rot_point(rot_point(Wr, TH_S, S), TH_E, E1)
W2 = rot_point(W1, TH_W, W1)  # not needed for transform, only for reference

t_upper = rot(parts["upper_arm_r"], TH_S, *S)
t_fore = rot(rot(parts["forearm_r"], TH_S, *S), TH_E, *E1)
t_claw = rot(rot(rot(parts["claw_r"], TH_S, *S), TH_E, *E1), TH_W, *W1)

posed = assemble({"upper_arm_r": t_upper, "forearm_r": t_fore, "claw_r": t_claw})

art_prev = Image.new("RGB", (W * 2 + 60, H + 40), (232, 232, 232))
art_prev.paste(assembled, (20, 20), assembled)
art_prev.paste(posed, (W + 40, 20), posed)
art_prev.save(os.path.join(OUT, "articulation_preview.png"))
print("articulation: elbow ->", E1, "wrist ->", W1)

# ---------- parts preview (5x2 labeled grid) ----------
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
    px = cx + (CELL - thumb.width) // 2
    py = cy + (CELL - 60 - thumb.height) // 2
    sheet.paste(thumb, (px, py), thumb)
    label = name
    tw = d.textlength(label, font=font)
    d.text((cx + (CELL - tw) / 2, cy + CELL - 48), label, fill=(20, 20, 20), font=font)
    d.rectangle([cx, cy, cx + CELL - 1, cy + CELL - 1], outline=(200, 200, 200))
sheet.save(os.path.join(OUT, "parts_preview.png"))
print("previews saved")
