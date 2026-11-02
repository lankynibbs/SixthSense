"""Rear Heat HUD radar disc texture: neutral dark see-through disc, white rim (v1.5.1: tinted by radar_color), rings at 1/3 and 2/3,
crosshair. Drawn at 4x and scaled down for smooth edges. Writes assets/radar_disc.png (512x512 RGBA)."""
import math, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

SIZE = 512
GREEN = (255, 255, 255)   # v1.5.1: white lines, tinted in game by radar_color (green 90,255,140 by default)

def disc(size=SIZE):
    B = size * 4; c = B / 2; r = c - 24
    yy, xx = np.mgrid[0:B, 0:B].astype(np.float32)
    d = np.hypot(xx - c + 0.5, yy - c + 0.5) / r
    f = np.clip(d, 0, 1) ** 1.6
    a = np.zeros((B, B, 4), np.float32)
    a[..., 0] = 26 - 16 * f; a[..., 1] = 26 - 16 * f; a[..., 2] = 26 - 16 * f   # (neutral: x tint green ~ the old 6,26,12)
    a[..., 3] = np.where(d <= 1, 150 + 40 * f, 0)
    img = Image.fromarray(a.clip(0, 255).astype(np.uint8), 'RGBA')
    def line(fn, alpha, w, glow=0, glow_a=0):
        for width, al, blur in ((glow, glow_a, glow * 0.6), (w, alpha, 0)):
            if width <= 0: continue
            m = Image.new('L', (B, B), 0); fn(ImageDraw.Draw(m), max(1, round(width)))
            if blur: m = m.filter(ImageFilter.GaussianBlur(blur))
            g = Image.new('RGBA', (B, B), GREEN + (0,)); g.putalpha(m.point(lambda p: round(p * al / 255)))
            img.alpha_composite(g)
    line(lambda dr, w: dr.line((c, c - r, c, c + r), fill=255, width=w), 90, 6)
    line(lambda dr, w: dr.line((c - r, c, c + r, c), fill=255, width=w), 90, 6)
    for fr in (1 / 3, 2 / 3):
        rr = r * fr
        line(lambda dr, w, rr=rr: dr.ellipse((c - rr, c - rr, c + rr, c + rr), outline=255, width=w), 130, 8, 28, 50)
    line(lambda dr, w: dr.ellipse((c - r, c - r, c + r, c + r), outline=255, width=w), 245, 18, 60, 140)
    return img.resize((size, size), Image.LANCZOS)

if __name__ == '__main__':
    out = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / 'assets/radar_disc.png')
    disc().save(out); print('wrote', out)
