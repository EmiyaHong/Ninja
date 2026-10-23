# -*- coding: utf-8 -*-
"""Remove near-white background from generated bear views (border flood fill +
enclosed bright-pocket removal), then save with clean names as RGBA."""
import os
from collections import deque
from PIL import Image

BASE = os.path.dirname(os.path.abspath(__file__))

JOBS = {
    "Draw_the_EXACT_SAME_character__2026-10-22T06-14-12.png": "cangzhua_2_front_right.png",
    "Draw_the_EXACT_SAME_character__2026-10-22T06-08-34.png": "cangzhua_3_right.png",
    "Draw_the_EXACT_SAME_character__2026-10-22T06-12-50.png": "cangzhua_4_back_right.png",
    "Draw_the_EXACT_SAME_character__2026-10-22T06-11-13.png": "cangzhua_5_back.png",
    "Draw_the_EXACT_SAME_character__2026-10-22T06-11-17_mirrored.png": "cangzhua_6_back_left.png",
    "Draw_the_EXACT_SAME_character__2026-10-22T06-11-16.png": "cangzhua_7_left.png",
    "Draw_the_EXACT_SAME_character__2026-10-22T06-15-10.png": "cangzhua_8_front_left.png",
    "Draw_the_EXACT_SAME_character__2026-10-22T06-11-10.png": "cangzhua_quadruped_front.png",
}

BG_TOL = 42          # flood-fill tolerance vs border color
BRIGHT = 238         # enclosed near-white pocket threshold


def is_bg(px, ref, tol):
    return all(abs(px[i] - ref[i]) <= tol for i in range(3))


def process(src, dst):
    img = Image.open(os.path.join(BASE, src)).convert("RGBA")
    w, h = img.size
    px = img.load()
    # reference bg color = median-ish of the 4 corners (they are all ~white)
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    ref = tuple(sum(c[i] for c in corners) // 4 for i in range(3))

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
        px[x, y] = (px[x, y][0], px[x, y][1], px[x, y][2], 0)
        for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
            if 0 <= nx < w and 0 <= ny < h and not visited[ny * w + nx] \
               and is_bg(px[nx, ny], ref, BG_TOL):
                q.append((nx, ny))

    # enclosed bright pockets (gaps between arms and torso etc.)
    for y in range(h):
        for x in range(w):
            if not visited[y * w + x]:
                r, g, b, a = px[x, y]
                if a == 255 and r >= BRIGHT and g >= BRIGHT and b >= BRIGHT:
                    px[x, y] = (r, g, b, 0)

    img.save(os.path.join(BASE, dst))
    print("done:", dst)


for s, d in JOBS.items():
    process(s, d)
print("ALL OK")
