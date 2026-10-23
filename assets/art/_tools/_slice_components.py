# Slice UI kit board into individual transparent-background components.
# Rects are estimated on the 1080x720 display, scaled to actual size, then auto-trimmed.
import os
import numpy as np
from PIL import Image
from scipy import ndimage

SRC = r"C:\Users\hyc\.workbuddy\clipboard-images\clipboard-2026-10-22T09-23-51-816Z-c9b9dcda.jpg"
OUT = r"E:\Godot\Ninja\assets\art\ui_kit\components"
os.makedirs(OUT, exist_ok=True)

# name: (x0, y0, x1, y1) in 1080x720 display coordinates
RECTS = [
    # HEALTH / POSTURE
    ("icon_heart",           (36, 38, 94, 90)),
    ("bar_health_player",    (98, 42, 338, 84)),
    ("icon_skull",           (368, 26, 438, 90)),
    ("bar_health_boss",      (436, 34, 1054, 82)),
    ("icon_shield",          (94, 84, 144, 144)),
    ("bar_stance",           (150, 94, 940, 132)),
    ("icon_shield_cracked",  (950, 78, 1010, 146)),
    # COMBAT
    ("icon_vulnerable",      (92, 174, 164, 250)),
    ("bar_countdown",        (52, 250, 204, 276)),
    ("fx_parry_spark",       (222, 166, 314, 272)),
    ("fx_hit_burst",         (332, 172, 438, 272)),
    ("icon_guard_break",     (462, 164, 558, 276)),
    ("plate_hint_small",     (586, 190, 764, 254)),
    ("plate_hint_large",     (776, 188, 1060, 256)),
    # DIRECTIONS
    ("arrow_red_right",      (38, 306, 128, 396)),
    ("arrow_red_left",       (136, 306, 230, 396)),
    ("arrow_red_down",       (236, 306, 330, 396)),
    ("arrow_cyan_left",      (376, 306, 470, 396)),
    ("arrow_cyan_right",     (476, 306, 570, 396)),
    ("arrow_cyan_up",        (576, 306, 670, 396)),
    ("icon_mouse",           (714, 300, 790, 400)),
    ("curve_swipe",          (822, 310, 1064, 396)),
    # BUTTON STATES
    ("btn_wide_normal",      (22, 428, 168, 494)),
    ("btn_wide_hover",       (176, 428, 324, 494)),
    ("btn_wide_pressed",     (332, 428, 478, 494)),
    ("btn_wide_disabled",    (484, 428, 616, 494)),
    ("btn_pause",            (646, 428, 714, 496)),
    ("btn_play",             (714, 428, 782, 496)),
    ("btn_retry",            (784, 428, 852, 496)),
    ("btn_settings",         (854, 428, 922, 496)),
    ("btn_back",             (924, 428, 992, 496)),
    ("btn_close",            (993, 428, 1061, 496)),
    # PANELS
    ("panel_menu",           (38, 518, 350, 620)),
    ("panel_dialog",         (370, 518, 556, 626)),
    ("panel_results",        (566, 518, 1068, 620)),
    # SETTINGS
    ("icon_speaker",         (24, 648, 66, 696)),
    ("slider_volume",        (66, 648, 324, 698)),
    ("toggle_on",            (360, 646, 450, 696)),
    ("toggle_off",           (474, 646, 562, 696)),
    ("checkbox_off",         (612, 644, 664, 694)),
    ("checkbox_on",          (684, 644, 736, 694)),
    ("tabs_mode",            (790, 640, 1064, 700)),
]

img = Image.open(SRC).convert("RGB")
W, H = img.size
sx, sy = W / 1080.0, H / 720.0
arr = np.asarray(img).astype(np.int16)

border = np.concatenate([
    arr[0:5].reshape(-1, 3), arr[-5:].reshape(-1, 3),
    arr[:, 0:5].reshape(-1, 3), arr[:, -5:].reshape(-1, 3),
])
BG = np.median(border, axis=0)

def process(name, rect):
    x0, y0, x1, y1 = rect
    X0, Y0 = max(0, int(x0 * sx)), max(0, int(y0 * sy))
    X1, Y1 = min(W, int(x1 * sx)), min(H, int(y1 * sy))
    crop = arr[Y0:Y1, X0:X1]
    diff = np.abs(crop - BG).sum(axis=2)
    fg = diff > 40
    if fg.sum() < 100:
        print(f"!! {name}: almost no content, skipped")
        return
    # trim to content bbox
    ys, xs = np.where(fg)
    pad = 6
    ty0, ty1 = max(0, ys.min() - pad), min(crop.shape[0], ys.max() + pad + 1)
    tx0, tx1 = max(0, xs.min() - pad), min(crop.shape[1], xs.max() + pad + 1)
    crop = crop[ty0:ty1, tx0:tx1]
    diff = np.abs(crop - BG).sum(axis=2)
    bg_like = diff < 35
    lab, _ = ndimage.label(bg_like)
    edge_labels = set(np.unique(np.concatenate([
        lab[0, :], lab[-1, :], lab[:, 0], lab[:, -1]]))) - {0}
    outside = np.isin(lab, list(edge_labels))
    alpha = np.where(outside, 0, 255).astype(np.float32)
    # 1px soft edge
    a_img = Image.fromarray(alpha.astype(np.uint8))
    a_img = a_img.filter(__import__("PIL.ImageFilter", fromlist=["GaussianBlur"]).GaussianBlur(0.8))
    alpha = np.asarray(a_img)
    rgba = np.dstack([crop.clip(0, 255).astype(np.uint8), alpha])
    Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, name + ".png"))
    print(f"ok  {name}.png  {rgba.shape[1]}x{rgba.shape[0]}")

for name, rect in RECTS:
    process(name, rect)
print("done ->", OUT)
