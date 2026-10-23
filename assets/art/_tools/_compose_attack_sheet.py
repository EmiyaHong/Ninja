# -*- coding: utf-8 -*-
"""Compose the 8-frame attack sheet: de-bg white frames, uniform scale,
align foot baselines, paste onto light-gray 4x2 sheet."""
import os
from collections import deque
from PIL import Image

BASE = os.path.dirname(os.path.abspath(__file__))
BG_TOL = 40
SHEET_BG = (217, 214, 212, 255)
COLS, ROWS = 4, 2
CELL_W, CELL_H = 768, 1024
MARGIN_BOTTOM = 40   # baseline distance from cell bottom
SIDE_MARGIN = 24

FRAMES = [
    "cangzhua_stand_01_front.png",  # F1 idle (already transparent)
    "_atk_f2.png", "_atk_f3.png", "_atk_f4.png",
    "_atk_f5.png", "_atk_f6.png", "_atk_f7.png",
    "cangzhua_stand_01_front.png",  # F8 = F1
]


def is_bg(px, ref, tol):
    return all(abs(px[i] - ref[i]) <= tol for i in range(3))


def remove_white_bg(img):
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    ref = tuple(sum(c[i] for c in corners) // 4 for i in range(3))
    if max(ref) < 235:  # not a white-ish bg, assume already transparent
        return img
    visited = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_bg(px[x, y], ref, BG_TOL):
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_bg(px[x, y], ref, BG_TOL):
                q.append((x, y))
    while q:
        x, y = q.popleft()
        idx = y * w + x
        if visited[idx]:
            continue
        visited[idx] = 1
        p = px[x, y]
        px[x, y] = (p[0], p[1], p[2], 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not visited[ny * w + nx] \
               and is_bg(px[nx, ny], ref, BG_TOL):
                q.append((nx, ny))
    # enclosed bright pockets
    for y in range(h):
        for x in range(w):
            if not visited[y * w + x]:
                r, g, b, a = px[x, y]
                if a == 255 and r >= 240 and g >= 240 and b >= 240:
                    px[x, y] = (r, g, b, 0)
    return img


def content_bbox(img):
    alpha = img.getchannel("A")
    return alpha.getbbox()


# 1) load + de-bg + trim
trimmed = []
for name in FRAMES:
    img = Image.open(os.path.join(BASE, name))
    img = remove_white_bg(img)
    bb = content_bbox(img)
    trimmed.append(img.crop(bb))
    print(name, "bbox", bb, "->", img.crop(bb).size)

# 2) one uniform scale for all frames (fit the largest frame into a cell)
scale = 1e9
for img in trimmed:
    w, h = img.size
    scale = min(scale,
                (CELL_H - MARGIN_BOTTOM - 60) / h,   # 60px headroom at top
                (CELL_W - 2 * SIDE_MARGIN) / w)
print("uniform scale:", round(scale, 4))

# 3) compose
sheet = Image.new("RGBA", (CELL_W * COLS, CELL_H * ROWS), SHEET_BG)
baseline_offset = CELL_H - MARGIN_BOTTOM
for i, img in enumerate(trimmed):
    w, h = img.size
    nw, nh = round(w * scale), round(h * scale)
    rimg = img.resize((nw, nh), Image.LANCZOS)
    r, c = divmod(i, COLS)
    x = c * CELL_W + (CELL_W - nw) // 2
    y = r * CELL_H + baseline_offset - nh
    sheet.alpha_composite(rimg, (x, y))

out = os.path.join(BASE, "cangzhua_attack_sweep_8f.png")
sheet.convert("RGB").save(out)
print("saved", out, sheet.size)
