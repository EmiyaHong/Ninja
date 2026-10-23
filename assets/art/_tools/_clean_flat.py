# -*- coding: utf-8 -*-
"""Flatten generated flat-vector art to a canonical palette and de-bg.
Steps: border flood de-bg -> 1px alpha erosion (kill fringe) -> nearest-palette remap.
Palette sampled from the user's confirmed front artwork."""
import os
from collections import deque
import numpy as np
from PIL import Image, ImageFilter

BASE = os.path.dirname(os.path.abspath(__file__))

PALETTE = np.array([
    (6, 7, 11),        # near-black outline
    (25, 99, 101),     # teal body
    (252, 236, 203),   # cream belly/muzzle
    (92, 95, 102),     # gray armor
    (240, 166, 40),    # amber eyes
    (255, 249, 230),   # ivory claws / inner ear
], dtype=np.float32)

BG_TOL = 42


def is_bg(px, ref, tol):
    return all(abs(px[i] - ref[i]) <= tol for i in range(3))


def flood_mask(img):
    """Return bytearray mask: 1 = background (border-connected near-bg)."""
    w, h = img.size
    px = img.load()
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    ref = tuple(sum(c[i] for c in corners) // 4 for i in range(3))
    mask = bytearray(w * h)
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
        if mask[idx]:
            continue
        mask[idx] = 1
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not mask[ny * w + nx] \
               and is_bg(px[nx, ny], ref, BG_TOL):
                q.append((nx, ny))
    return mask


def clean(src, dst):
    img = Image.open(src).convert("RGB")
    w, h = img.size
    mask = flood_mask(img)

    alpha = Image.frombytes("L", (w, h), bytes(bytearray(0 if m else 255 for m in mask)))
    alpha = alpha.filter(ImageFilter.MinFilter(3))  # erode 1px fringe

    arr = np.asarray(img).astype(np.float32)
    a = np.asarray(alpha)
    flat = arr.reshape(-1, 3)
    d = ((flat[:, None, :] - PALETTE[None, :, :]) ** 2).sum(axis=2)
    nearest = PALETTE[d.argmin(axis=1)].astype(np.uint8).reshape(h, w, 3)

    out = np.dstack([nearest, a])
    Image.fromarray(out, "RGBA").save(dst)
    print("done:", dst)


if __name__ == "__main__":
    jobs = {
        "_geo_02_front_right.png": "geobear_stand_02_front_right.png",
        "_geo_03_right.png": "geobear_stand_03_right.png",
        "_geo_04_back_right.png": "geobear_stand_04_back_right.png",
        "_geo_05_back.png": "geobear_stand_05_back.png",
    }
    for s, d in jobs.items():
        clean(os.path.join(BASE, s), os.path.join(BASE, d))

    # front base from the user's confirmed artwork
    clean(r"C:\Users\hyc\.workbuddy\clipboard-images\clipboard-2026-10-22T09-24-31-024Z-b147456a.jpg",
          os.path.join(BASE, "geobear_stand_01_front.png"))

    # mirrors from cleaned versions
    for src, dst in [("geobear_stand_02_front_right.png", "geobear_stand_08_front_left.png"),
                     ("geobear_stand_03_right.png", "geobear_stand_07_left.png"),
                     ("geobear_stand_04_back_right.png", "geobear_stand_06_back_left.png")]:
        Image.open(os.path.join(BASE, src)).transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(BASE, dst))
        print("mirrored:", dst)
    print("ALL OK")
