"""Boite a outils des projectiles en pixel art (utilisee par tools/gen_projectiles.py).

Une forme (polygones, ellipses) est remplie puis modelee : lumiere en haut a gauche, quatre tons
(profond, sombre, moyen, clair), bord interieur assombri, contour d'encre colore, reflets.
"""
import math

from PIL import Image, ImageDraw


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def ramp(deep, dark, mid, light):
    return [hexc(deep), hexc(dark), hexc(mid), hexc(light)]


def rot(points, angle, cx, cy):
    c, s = math.cos(angle), math.sin(angle)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in points]


def mask_of(size, polys=(), ellipses=(), lines=()):
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    for p in polys:
        d.polygon([(round(x), round(y)) for x, y in p], fill=255)
    for e in ellipses:
        d.ellipse([round(v) for v in e], fill=255)
    for (a, b, w) in lines:
        d.line([tuple(round(v) for v in a), tuple(round(v) for v in b)], fill=255, width=w)
    return m


def shade(frame, mask, tones, light=(-0.7, -0.7), offset=(0, 0), edge_dark=True):
    """Remplit `mask` dans `frame` avec les quatre tons, modele par la lumiere."""
    w, h = mask.size
    pts = [(x, y) for y in range(h) for x in range(w) if mask.getpixel((x, y)) > 0]
    if not pts:
        return set()
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    ext = max(max(abs(p[0] - cx), abs(p[1] - cy)) for p in pts) or 1.0
    lx, ly = light
    solid = set(pts)
    for x, y in pts:
        s = ((x - cx) * lx + (y - cy) * ly) / ext
        t = 3 if s > 0.42 else (2 if s > -0.15 else (1 if s > -0.62 else 0))
        if edge_dark and t > 1 and any((x + dx, y + dy) not in solid for dx, dy in ((1, 0), (0, 1))):
            t -= 1
        frame.putpixel((x + offset[0], y + offset[1]), tones[t])
    return solid


def ink(frame, color):
    """Contour d'un pixel, de la couleur donnee, autour de tout ce qui est opaque."""
    w, h = frame.size
    solid = {(x, y) for y in range(h) for x in range(w) if frame.getpixel((x, y))[3] > 200}
    for x, y in solid:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if 0 <= n[0] < w and 0 <= n[1] < h and n not in solid and frame.getpixel(n)[3] < 120:
                frame.putpixel(n, color)


def dots(frame, points, color):
    w, h = frame.size
    for x, y in points:
        x, y = round(x), round(y)
        if 0 <= x < w and 0 <= y < h:
            frame.putpixel((x, y), color)


def strip(size, frames, make):
    """Bande de `frames` images ; make(f) renvoie une image size x size."""
    out = Image.new("RGBA", (size * frames, size), (0, 0, 0, 0))
    for f in range(frames):
        out.alpha_composite(make(f), (f * size, 0))
    return out


def blank(size):
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))
