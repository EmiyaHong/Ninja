# -*- coding: utf-8 -*-
"""Geocat 八视图（AI 图生图版）后处理定型脚本。

输入：geometric/geocat/_gen_tmp/ 里 AI 生成的原始图（RGB、浅色底、右下角有"AI生成"水印）
处理：1) 右下角水印区擦除  2) 边缘洪水填充去背景 → 真透明
      3) 裁内容 bbox → 统一内容高 780px、脚底基线 y=889、水平居中 x=512
输出：geometric/geocat/geocat_stand_<NN>_<direction>.png（1024² RGBA）+ _preview_sheet.png
"""
import os
from collections import deque

import numpy as np
from PIL import Image

BASE = os.path.dirname(os.path.abspath(__file__))
GEOCAT = os.path.join(os.path.dirname(BASE), "geometric", "geocat")
TMP = os.path.join(GEOCAT, "_gen_tmp")

SIZE = 1024
CONTENT_H = 780          # 八张统一内容高度（耳朵尖/尾尖 → 脚底）
BASELINE_Y = 889         # 脚底基线
WM_RECT = (860, 905, SIZE, SIZE)   # "AI生成"水印区（先确认角色不进入）

SOURCES = [
    (1, "front", "参考图中的布偶猫角色_正面视角_脸与胸腹正对镜头_左右严格对_2026-10-22T12-16-44.png"),
    (2, "front_right", "第一张参考图是布偶猫正面_第二张是同一角色右侧面_画前右斜4_2026-10-22T12-25-16.png"),
    (3, "right", "把参考图中的布偶猫角色旋转到正侧面视角_鼻尖朝画面右侧_身体_2026-10-22T12-15-19.png"),
    (4, "back_right", "把参考图中的布偶猫角色旋转到后右斜135__介于正背面与右侧_2026-10-22T12-20-53.png"),
    (5, "back", "把参考图中的布偶猫角色旋转到正背面_角色完全背对镜头_不回头_2026-10-22T12-21-05.png"),
    (6, "back_left", "把参考图中的布偶猫角色旋转到后左斜面_角色背向镜头并向左转1_2026-10-22T12-18-07.png"),
    (7, "left", "把参考图中的布偶猫角色旋转到正侧面_鼻尖朝画面左侧_身体侧对_2026-10-22T12-18-22.png"),
    (8, "front_left", "第一张参考图是布偶猫正面_第二张是同一角色左侧面_画前左斜4_2026-10-22T12-25-31.png"),
]


def border_bg_color(arr):
    """四边像素的中位数 = 背景色。"""
    edge = np.concatenate([arr[0], arr[-1], arr[:, 0], arr[:, -1]])
    return np.median(edge, axis=0)


def flood_bg(arr, tol=34.0):
    """从四边洪水填充背景：与背景色距离 < tol 且连通到边缘的像素 = 背景。"""
    h, w, _ = arr.shape
    bg = border_bg_color(arr)
    dist = np.sqrt(((arr.astype(np.float32) - bg) ** 2).sum(axis=2))
    cand = dist < tol
    mask = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if cand[y, x] and not mask[y, x]:
                mask[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if cand[y, x] and not mask[y, x]:
                mask[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and cand[ny, nx] and not mask[ny, nx]:
                mask[ny, nx] = True
                q.append((ny, nx))
    return mask


def edge_std(arr):
    edge = np.concatenate([arr[0], arr[-1], arr[:, 0], arr[:, -1]]).astype(np.float32)
    return edge.std(axis=0).max()


def process(idx, name, fname):
    img = Image.open(os.path.join(TMP, fname)).convert("RGB")
    arr = np.array(img)

    # 自适应容差：干净纯色底 std<8 → 45；带纹理/噪点底 → 80
    # （角色内部色块被近黑描边封闭，描边与背景色距离远大于 80，洪水进不去）
    tol = 45.0 if edge_std(arr) < 8 else 80.0

    # 1) 水印区先用背景色覆盖（先确认角色不进入该区域）
    bg = border_bg_color(arr).astype(np.uint8)
    x0, y0, x1, y1 = WM_RECT
    dist_bg = np.sqrt(((arr.astype(np.float32) - bg) ** 2).sum(axis=2))
    intruders = int((dist_bg[y0:y1, x0:x1] > 80).sum())
    if intruders > 300:
        print(f"  !! {fname}: 水印区内有 {intruders} 个非背景像素，请人工检查")
    arr[y0:y1, x0:x1] = bg

    # 2) 去背景 → 真透明
    bgmask = flood_bg(arr, tol)
    rgba = np.dstack([arr, np.where(bgmask, 0, 255).astype(np.uint8)])

    # 2b) 去 1px 毛边：与透明区相邻且颜色接近背景的像素也透明
    a = rgba[:, :, 3] > 0
    near_bg = dist_bg < tol + 25
    edge = np.zeros_like(a)
    edge[1:, :] |= ~a[1:, :]
    edge[:-1, :] |= ~a[:-1, :]
    edge[:, 1:] |= ~a[:, 1:]
    edge[:, :-1] |= ~a[:, :-1]
    rgba[:, :, 3][a & edge & near_bg] = 0

    im = Image.fromarray(rgba, "RGBA")
    a2 = np.array(im)[:, :, 3] > 0
    ys, xs = np.where(a2)
    bx0, by0, bx1, by1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1

    # 3) 裁剪 → 统一缩放 → 居中贴回（脚底对齐基线）
    crop = im.crop((bx0, by0, bx1, by1))
    cw, ch = crop.size
    nw, nh = round(cw * CONTENT_H / ch), CONTENT_H
    crop = crop.resize((nw, nh), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(crop, (SIZE // 2 - nw // 2, BASELINE_Y - nh), crop)

    dst = os.path.join(GEOCAT, f"geocat_stand_{idx:02d}_{name}.png")
    out.save(dst)
    print(f"geocat_stand_{idx:02d}_{name}.png  原始bbox=({bx0},{by0},{bx1},{by1})"
          f"  缩放={nw}x{nh}")
    return dst


def make_preview(paths):
    sheet = Image.new("RGB", (4 * SIZE // 2, 2 * SIZE // 2), (238, 234, 224))
    for i, p in enumerate(paths):
        im = Image.open(p).resize((SIZE // 2, SIZE // 2), Image.LANCZOS)
        sheet.paste(im, ((i % 4) * SIZE // 2, (i // 4) * SIZE // 2), im)
    dst = os.path.join(GEOCAT, "_preview_sheet.png")
    sheet.save(dst)
    return dst


def main():
    paths = [process(idx, name, fname) for idx, name, fname in SOURCES]
    print("preview:", make_preview(paths))


if __name__ == "__main__":
    main()
