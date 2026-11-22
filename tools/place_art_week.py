"""Decors redessines de mardi a dimanche (meme direction que le lundi de tools/place_art.py :
volume, lumiere en haut a gauche, tons en aplats nets, contour d'encre colore).

Lance par tools/place_art.py (et donc par tools/gen_places.py) via WEEK.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))

from PIL import Image  # noqa: E402

from gen_pixel_art import TILE, save  # noqa: E402
from gen_places import tiles  # noqa: E402
from mob_art import canvas, mask_wh  # noqa: E402
from mob_art_week import ell, fade, line, part, poly, rect  # noqa: E402
from place_art import _value, band, dither, put, stamp, tdist, tile, tnoise  # noqa: E402
from proj_art import dots, hexc, ink, ramp, shade  # noqa: E402


# --- Outils communs --------------------------------------------------------------------------

def each(img, fn):
    """Remplit chaque pixel de la tuile avec fn(x, y) (None : laisse le pixel)."""
    for y in range(img.height):
        for x in range(img.width):
            c = fn(x, y)
            if c is not None:
                img.putpixel((x, y), c)
    return img


def rowrand(y, seed):
    return random.Random(seed * 977 + y).random()


def bevel(lx, ly, w, h):
    """Arete d'une plaque en relief : 'seam' (joint), 'hi' (bord eclaire), 'lo' (bord a l'ombre)."""
    if lx == 0 or ly == 0:
        return "seam"
    if lx == 1 or ly == 1:
        return "hi"
    if lx == w - 1 or ly == h - 1:
        return "lo"
    return None


def voronoi(x, y, cells):
    """Plus proche et second plus proche germe, sur la tuile qui boucle (paves, rochers)."""
    best = [(9e9, -1), (9e9, -1)]
    for i, (cx, cy) in enumerate(cells):
        dx, dy = tdist(x, y, cx, cy)
        d = math.hypot(dx, dy)
        if d < best[0][0]:
            best = [(d, i), best[0]]
        elif d < best[1][0]:
            best[1] = (d, i)
    return best[0][0], best[1][0], best[0][1]


def seeds(n, seed, margin=0):
    rng = random.Random(seed)
    cells = []
    side = math.ceil(math.sqrt(n))
    step = TILE / side
    for j in range(side):
        for i in range(side):
            if len(cells) < n:
                cells.append(((i + 0.5) * step + rng.uniform(-step * 0.3, step * 0.3),
                              (j + 0.5) * step + rng.uniform(-step * 0.3, step * 0.3)))
    return cells


def stones(x, y, cells, tones, joint, light_shift=1.2, flat=0.0):
    """Pave / caillou modele : bombe au centre, eclaire en haut a gauche, joint sombre."""
    d1, d2, i = voronoi(x, y, cells)
    edge = d2 - d1
    if edge < 1.1:
        return joint, i, edge
    _, _, j = voronoi(x - light_shift, y - light_shift, cells)
    lit = j == i  # le voisin en haut a gauche est dans le meme pave
    h = min(1.0, edge / 6.0)
    v = 0.25 + 0.45 * h + (0.18 if lit else -0.22) * (1 - h) + flat
    return band(tones, v, x, y, soft=0.12), i, edge


def gear_at(dx, dy, r, teeth, phase=0.0):
    """Partie d'un rouage au point (dx, dy) du centre : None, 'tooth', 'rim', 'face', 'spoke_hole', 'hub'."""
    d = math.hypot(dx, dy)
    a = (math.atan2(dy, dx) / math.tau + phase) % 1
    if d > r:
        return None
    if d > r * 0.8:
        return "tooth" if (a * teeth) % 1 < 0.5 else None
    if d > r * 0.66:
        return "rim"
    if d < r * 0.16:
        return "hole"
    if d < r * 0.3:
        return "hub"
    if r * 0.4 < d < r * 0.58 and (a * 4) % 1 < 0.16:
        return "spoke_hole"  # quatre jours d'allegement
    return "face"


def modeled(tones, dx, dy, r, x, y, base=0.5, soft=0.12):
    """Ton d'un volume rond eclaire en haut a gauche."""
    v = base - 0.38 * (dx + dy) / (r * 1.4)
    return band(tones, v, x, y, soft=soft)


def bubble(w, h, rim_tones, fill_hex, inside=None):
    """Bulle translucide : bord irise opaque, interieur voile, reflet en haut a gauche."""
    img = canvas(w, h)
    cx, cy = (w - 1) / 2, (h - 1) / 2
    r = min(w, h) / 2 - 0.4
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - cx, y - cy)
            if d <= r:
                if d > r - 1.2:
                    k = int((math.atan2(y - cy, x - cx) + math.pi) / math.tau * len(rim_tones)) % len(rim_tones)
                    img.putpixel((x, y), hexc(rim_tones[k], 230))
                else:
                    img.putpixel((x, y), hexc(fill_hex, 70))
    if inside:
        inside(img)
    dots(img, [(round(cx - r * 0.5), round(cy - r * 0.6)), (round(cx - r * 0.65), round(cy - r * 0.4)),
               (round(cx - r * 0.35), round(cy - r * 0.68))], hexc("ffffff"))
    return img


def darken_down(img, amount=0.3):
    """Assombrit vers le bas (le pied d'un mur)."""
    for y in range(img.height):
        k = 1 - amount * y / img.height
        for x in range(img.width):
            r, g, b, a = img.getpixel((x, y))
            img.putpixel((x, y), (int(r * k), int(g * k), int(b * k), a))
    return img


def sheet_sprite(w, h, corners, paper, lines_hex, outline):
    """Une feuille de papier (polygone) avec ses lignes d'ecriture."""
    img = canvas(w, h)
    part(img, poly(w, h, corners), paper, outline)
    return img


# --- Mardi : les Engrenages (paradoxal) ------------------------------------------------------

BRASS = ramp("5e3e18", "8a6028", "b08040", "d0a458")
BRASS_HI, BRASS_SEAM = hexc("f4d890"), hexc("3e2810")


def engrave(img, pts, deep=hexc("6a461a"), lip=hexc("ecc884")):
    """Trait grave dans le laiton : creux sombre, levre claire en bas a droite."""
    for x, y in pts:
        put(img, x + 1, y + 1, lip)
    for x, y in pts:
        put(img, x, y, deep)


def brass_floor(variant):
    """Plaques de laiton brosse boulonnees ; variantes : un cadran grave, un rouage grave, une grille."""
    img = tile()

    def px(x, y):
        e = bevel(x, y, TILE, TILE)
        if e == "seam":
            return BRASS_SEAM
        if e == "hi":
            return BRASS[3]
        if e == "lo":
            return BRASS[0]
        brushed = (rowrand(y, 3) - 0.5) * 0.08 + _value(x, y * 7, 9, 5) * 0.06
        v = 0.5 + brushed + tnoise(x, y, 7) * 0.3 - 0.1 * (x + y) / 98
        return band(BRASS[1:4], v, x, y, soft=0.1)
    each(img, px)
    for rx, ry in ((4, 4), (44, 4), (4, 44), (44, 44)):  # rivets
        put(img, rx, ry, BRASS_HI)
        put(img, rx + 1, ry, BRASS[2])
        put(img, rx + 1, ry + 1, hexc("4a3010"))
        put(img, rx, ry + 1, BRASS[2])
    if variant == 1:  # cadran grave
        ring = {(25 + round(12 * math.cos(a / 72 * math.tau)), 25 + round(12 * math.sin(a / 72 * math.tau))) for a in range(72)}
        ticks = {(25 + round(r * math.cos(a / 12 * math.tau)), 25 + round(r * math.sin(a / 12 * math.tau)))
                 for a in range(12) for r in ((9, 10) if a % 3 else (8, 9, 10))}
        hands = {(25, 25 - i) for i in range(7)} | {(25 + i, 25) for i in range(5)}
        engrave(img, list(ring | ticks | hands))
    elif variant == 2:  # rouage grave
        pts = set()
        for a in range(120):
            t = a / 120
            r = 11 if (t * 10) % 1 < 0.5 else 8.5
            pts.add((25 + round(r * math.cos(t * math.tau)), 25 + round(r * math.sin(t * math.tau))))
        for k in range(10):  # flancs des dents
            t = k / 10
            for r in (9, 10):
                for dt in (0, 0.05):
                    pts.add((25 + round(r * math.cos((t + dt) * math.tau)), 25 + round(r * math.sin((t + dt) * math.tau))))
        pts |= {(25 + round(3 * math.cos(a / 16 * math.tau)), 25 + round(3 * math.sin(a / 16 * math.tau))) for a in range(16)}
        engrave(img, list(pts))
    elif variant == 3:  # grille d'aeration
        for i in range(5):
            y = 17 + i * 3
            for x in range(17, 34):
                put(img, x, y, hexc("2a1a0a"))
                put(img, x, y + 1, BRASS[3])
    return img


def gear_pit_top():
    """Le vide autour : une fosse sombre ou tournent de grands rouages dans l'ombre."""
    img = tile()
    deep = [hexc("150f0a"), hexc("1b140d"), hexc("221911")]
    gear_t = [hexc("2c2116"), hexc("35281a"), hexc("3f3020")]
    each(img, lambda x, y: band(deep, 0.5 + tnoise(x, y, 61) * 0.6, x, y, soft=0.5))
    for cx, cy, r, teeth in ((14, 16, 15, 10), (40, 40, 11, 8)):
        for y in range(TILE):
            for x in range(TILE):
                dx, dy = tdist(x, y, cx, cy)
                dx *= 1 if (x - cx) % TILE < TILE / 2 else -1
                dy *= 1 if (y - cy) % TILE < TILE / 2 else -1
                g = gear_at(dx, dy, r, teeth)
                if g in ("tooth", "rim", "face", "hub"):
                    img.putpixel((x, y), modeled(gear_t, dx, dy, r, x, y, soft=0.3))
    return img


GEARS = [ramp("6a4418", "a87430", "d8a24a", "f4d07a"), ramp("5e3c18", "946426", "c48c3c", "e6bc68"),
         ramp("6a3c1c", "a4602c", "d08a44", "eeb470")]


def gears_face():
    """Rouages imbriques en relief sur un fond de machine sombre, plus sombre vers le pied."""
    img = Image.new("RGBA", (TILE, TILE), hexc("2e2014"))
    each(img, lambda x, y: band([hexc("281b10"), hexc("2e2014"), hexc("36261a")], 0.5 + tnoise(x, y, 71) * 0.5, x, y, soft=0.4))
    for (cx, cy, r, teeth, phase), tones in zip(((13, 17, 13, 10, 0.0), (37, 30, 14, 11, 0.05), (5, 45, 8, 7, 0.1)), GEARS):
        for y in range(TILE):
            for x in range(TILE):
                dx = (x - cx + TILE / 2) % TILE - TILE / 2
                dy = y - cy
                g = gear_at(dx, dy, r, teeth, phase)
                if g is None or g == "spoke_hole":
                    continue
                if g == "hole":
                    c = hexc("1a1008")
                elif g == "hub":
                    c = modeled(tones, dx, dy, r * 0.3, x, y, base=0.65)
                elif g == "rim":
                    c = modeled(tones, dx, dy, r, x, y, base=0.45)
                else:
                    c = modeled(tones, dx, dy, r, x, y, base=0.62)
                img.putpixel((x, y), c)
                for nx, ny in ((x - 1, y), (x, y - 1)):  # contour d'encre sur les bords vides
                    if 0 <= ny < TILE:
                        ndx = (nx - cx + TILE / 2) % TILE - TILE / 2
                        if gear_at(ndx, ny - cy, r, teeth, phase) is None:
                            img.putpixel((x, y), tones[0])
    for x in range(TILE):
        img.putpixel((x, 0), BRASS[3])
        img.putpixel((x, 1), BRASS[1])
    return darken_down(img)


def mardi_star():
    """Etoile doree (soigne) : une etoile de bonne note, deux rubans rouges."""
    w, h = 20, 22
    img = canvas(w, h)
    part(img, poly(w, h, [(5, 13), (8, 14), (6, 21), (4, 19), (2, 20)]), ramp("7a1e28", "b8323c", "e0545a", "f48a8a"), "4a1018")
    part(img, poly(w, h, [(14, 13), (11, 14), (13, 21), (15, 19), (17, 20)]), ramp("7a1e28", "b8323c", "e0545a", "f48a8a"), "4a1018")
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        r = 8.6 if k % 2 == 0 else 4.0
        pts.append((9.5 + math.cos(a) * r, 9 + math.sin(a) * r))
    part(img, poly(w, h, pts), ramp("b0701c", "e8a828", "ffd450", "fff2b0"), "6a3a08")
    dots(img, [(7, 8), (12, 8)], hexc("6a3a08"))
    dots(img, [(8, 11), (9, 12), (10, 12), (11, 11)], hexc("8a4a10"))
    dots(img, [(8, 3), (7, 5)], hexc("ffffff"))
    return img


def compass():
    """La boussole (guide) : boitier de laiton, cadran creme, aiguille rouge et bleue."""
    w, h = 18, 20
    img = canvas(w, h)
    part(img, ell(w, h, (6, 0, 11, 4)), BRASS, "3e2810")
    clear_ring(img, 8.5, 2, 1.2)
    part(img, ell(w, h, (1, 3, 16, 18)), BRASS, "3e2810")
    shade(img, ell(w, h, (3, 5, 14, 16)), ramp("c8bca0", "e2d8c0", "f2ecdc", "fffaf0"), edge_dark=False)
    for a in range(8):
        t = a / 8 * math.tau
        dots(img, [(8.5 + 4.6 * math.cos(t), 10.5 + 4.6 * math.sin(t))], hexc("a08a60"))
    line(img, [(9, 6), (8, 10)], hexc("d83c3c"))
    line(img, [(9, 7), (9, 10)], hexc("f06a5a"))
    line(img, [(8, 11), (8, 15)], hexc("3c5aa8"))
    dots(img, [(8, 10), (9, 11)], hexc("2a1e10"))
    dots(img, [(4, 6), (3, 8)], hexc("fff2c0"))
    return img


def clear_ring(img, cx, cy, r):
    for y in range(img.height):
        for x in range(img.width):
            if math.hypot(x - cx, y - cy) <= r:
                img.putpixel((x, y), (0, 0, 0, 0))


def hourglass():
    """Le sablier retourne (pause) : montants de bois, deux bulbes de verre, sable dore qui coule."""
    w, h = 16, 22
    img = canvas(w, h)
    wood = ramp("4a2a14", "7a4824", "a46a36", "c88e52")
    glass = canvas(w, h)
    shade(glass, poly(w, h, [(3, 3), (12, 3), (12, 5), (8, 10), (7, 10), (3, 5)]), ramp("7a9ab8", "a8c4dc", "cce0f0", "f0f8ff"))
    shade(glass, poly(w, h, [(7, 11), (8, 11), (12, 16), (12, 18), (3, 18), (3, 16)]), ramp("7a9ab8", "a8c4dc", "cce0f0", "f0f8ff"))
    fade(glass, 0.6)
    img.alpha_composite(glass)
    sand = ramp("a8702a", "d89a3c", "f0c060", "fce08e")
    shade(img, poly(w, h, [(5, 6), (10, 6), (8, 9), (7, 9)]), sand)
    shade(img, poly(w, h, [(7, 15), (8, 15), (11, 17), (11, 18), (4, 18), (4, 17)]), sand)
    dots(img, [(7, 11), (7, 12), (8, 13), (7, 14)], hexc("f0c060"))
    part(img, poly(w, h, [(1, 1), (14, 1), (14, 3), (1, 3)]), wood, "2a160a")
    part(img, poly(w, h, [(1, 18), (14, 18), (14, 20), (1, 20)]), wood, "2a160a")
    for x in (2, 13):
        line(img, [(x, 3), (x, 18)], wood[2])
    dots(img, [(4, 4), (4, 15)], hexc("ffffff"))
    return img


def stress_bubble():
    """Bulle de stress : bulle rosee, un gribouillis rouge qui tourne dedans."""
    def scribble(img):
        pts = [(6, 10), (8, 6), (11, 8), (8, 12), (6, 8), (10, 6), (12, 10), (9, 11)]
        line(img, pts, hexc("d83a3a", 200))
    return bubble(18, 18, ["ffb4a0", "ff8c8c", "ffd0b0"], "ffc0b0", scribble)


def clock_hand():
    """Une grande aiguille d'horloge plantee dans le sol, sur son socle de laiton."""
    w, h = 14, 26
    img = canvas(w, h)
    blued = ramp("1a2a5a", "2e4a8e", "4a6ec0", "86a6e8")
    part(img, poly(w, h, [(6, 6), (8, 6), (8, 20), (6, 20)]), blued, "0c1430")
    part(img, poly(w, h, [(7, 0), (11, 4), (7, 8), (3, 4)]), blued, "0c1430")
    clear_ring(img, 7, 4, 1.0)
    part(img, ell(w, h, (4, 11, 10, 17)), blued, "0c1430")
    clear_ring(img, 7, 14, 1.3)
    part(img, poly(w, h, [(2, 20), (11, 20), (13, 25), (0, 25)]), BRASS, "3e2810")
    dots(img, [(5, 3), (6, 9), (5, 12)], hexc("c8dcff"))
    dots(img, [(3, 21), (2, 23)], BRASS_HI)
    return img


def sheets():
    """Feuilles volantes (copies, convocations) qui flottent en desordre."""
    w, h = 22, 18
    img = canvas(w, h)
    paper = ramp("a8a294", "d2ccbc", "ece6d6", "fffcf2")
    part(img, poly(w, h, [(1, 4), (10, 2), (12, 13), (3, 15)]), paper, "6a6458")
    part(img, poly(w, h, [(9, 6), (19, 4), (21, 15), (11, 17)]), paper, "6a6458")
    for i in range(4):
        line(img, [(3 + i * 0.3, 6 + i * 2), (9 + i * 0.3, 5 + i * 2)], hexc("8a98c0"))
        line(img, [(12, 8 + i * 2), (18, 7 + i * 2)], hexc("8a98c0"))
    dots(img, [(17, 13), (18, 12), (16, 12)], hexc("d83a3a"))  # une note en rouge
    dots(img, [(2, 5), (10, 7)], hexc("ffffff"))
    return img


def gear_sprite():
    """Un rouage tombe, debout sur la tranche (se pousse)."""
    w = h = 22
    img = canvas(w, h)
    tones = GEARS[0]
    cx = cy = 10.5
    for y in range(h):
        for x in range(w):
            g = gear_at(x - cx, y - cy, 10, 9, 0.02)
            if g in (None, "spoke_hole", "hole"):
                continue
            base = {"tooth": 0.45, "rim": 0.45, "face": 0.62, "hub": 0.7}[g]
            img.putpixel((x, y), modeled(tones, x - cx, y - cy, 10, x, y, base=base))
    ink(img, hexc("3a2208"))
    dots(img, [(5, 6), (6, 5)], hexc("fff0b0"))
    return img


# --- Mardi : la Salle des pendules (profond) -------------------------------------------------

WOOD_DARK = [ramp("221412", "301c18", "3e2620", "4c3028"), ramp("2a1814", "38201c", "462a24", "56342c"),
             ramp("1e1210", "2a1a16", "38221e", "462c26")]


def parquet_floor(variant):
    """Parquet sombre cire : lames decalees, veinage, bord eclaire ; variantes : noeuds, papiers
    froisses, reflet de cire."""
    img = tile()

    def px(x, y):
        row, ly = y // 10, y % 10
        off = (row * 31) % TILE
        tones = WOOD_DARK[row % 3]
        lx = (x + off) % TILE
        if ly == 0 or lx == 0:
            return hexc("120a0a")
        if ly == 1:
            return tones[3]
        if ly == 9:
            return tones[0]
        grain = math.sin((y * 1.9 + _value(x, y, 81 + row, 2) * 6)) * 0.12
        v = 0.5 + grain + tnoise(x, y, 83) * 0.25
        return band(tones[:3], v, x, y, soft=0.15)
    each(img, px)
    if variant == 1:  # noeuds du bois
        for kx, ky in ((14, 15), (38, 34)):
            for y in range(ky - 2, ky + 3):
                for x in range(kx - 3, kx + 4):
                    d = math.hypot((x - kx) / 1.6, y - ky)
                    if d < 2.2:
                        put(img, x, y, hexc("1a0e0c") if d < 1 or 1.7 < d else hexc("3e2620"))
    elif variant == 2:  # papiers froisses
        paper = ramp("8a8478", "b4ae9e", "d6d0c0", "f2eee2")
        for sx, sy in ((9, 28), (33, 11)):
            ball = canvas(10, 8)
            shade(ball, ell(10, 8, (1, 1, 8, 6), (0, 3, 4, 7)), paper)
            line(ball, [(2, 3), (4, 4), (6, 3)], paper[0])
            dots(ball, [(5, 5), (7, 4)], paper[1])
            ink(ball, hexc("2a2220"))
            stamp(img, ball, sx, sy)
    elif variant == 3:  # reflet de cire : la fenetre se reflete en traits clairs
        for i, (y, x0, x1) in enumerate(((24, 10, 34), (26, 14, 30), (34, 16, 40), (36, 20, 36))):
            for x in range(x0, x1):
                r, g, b, a = img.getpixel((x, y))
                k = 30 if i % 2 == 0 else 18
                img.putpixel((x, y), (min(255, r + k), min(255, g + k - 8), min(255, b + k - 10), a))
    return img


def tick_wall_top():
    """L'ombre autour : noir rougeatre, bruit de fond doux."""
    img = tile()
    tones = [hexc("0e0809"), hexc("140b0c"), hexc("1a0f10"), hexc("221315")]
    return each(img, lambda x, y: band(tones, 0.45 + tnoise(x, y, 91) * 0.5, x, y, soft=0.5))


def panel_face():
    """Boiseries a panneaux en relief, bandeau bordeaux et filet dore, plinthe."""
    img = tile()
    wood = WOOD_DARK[1]

    def px(x, y):
        lx = x % 25
        if y < 4:
            return hexc("e0b05a") if y == 3 else (hexc("6a1a26") if y else hexc("3a0c14"))
        if y >= 45:
            return wood[0] if y > 45 else wood[3]
        if 3 <= lx <= 21 and 9 <= y <= 40:  # panneau en relief
            if lx == 3 or y == 9:
                return wood[3]
            if lx == 21 or y == 40:
                return hexc("120a0a")
            if lx == 4 or y == 10:
                return wood[2]
            v = 0.45 + math.sin(y * 0.9 + _value(x, y, 95, 2) * 4) * 0.12
            return band(wood[:3], v, x, y, soft=0.2)
        return band(wood[:3], 0.55 + tnoise(x, y, 97) * 0.3, x, y, soft=0.2)
    each(img, px)
    return darken_down(img, 0.32)


def desk_lamp():
    """La lampe de bureau (s'allume) : bras de laiton articule, abat-jour vert, lueur chaude."""
    w, h = 18, 21
    img = canvas(w, h)
    part(img, ell(w, h, (2, 16, 13, 20)), ramp("1e2a24", "2e4236", "40584a", "587060"), "0e1410")
    line(img, [(7, 17), (4, 10), (10, 4)], BRASS[1], 2)
    line(img, [(7, 16), (4, 10)], BRASS[3])
    dots(img, [(4, 10)], BRASS_HI)
    part(img, poly(w, h, [(8, 1), (13, 0), (17, 7), (15, 9), (10, 8)]), ramp("1a4a34", "2a6e4c", "3e9468", "64bc8c"), "0c2418")
    dots(img, [(11, 8), (12, 9), (13, 9), (14, 9)], hexc("ffe08a"))
    dots(img, [(12, 10), (13, 10)], hexc("fff6c8"))
    dots(img, [(10, 2), (9, 3)], hexc("bef0d0"))
    return img


def ringing_alarm():
    """Le reveil qui sonne (lance un combat) : cloches qui tremblent, sourcils fronces."""
    w, h = 22, 20
    img = canvas(w, h)
    teal = ramp("1e5a5a", "2e8a86", "4ab8ae", "86e0d4")
    for cx in (6, 15):
        part(img, ell(w, h, (cx - 3, 1, cx + 3, 7)), teal, "0e2a2a")
    line(img, [(10, 1), (11, 3)], hexc("2a3a3a"))
    part(img, ell(w, h, (3, 4, 18, 18)), teal, "0e2a2a")
    shade(img, ell(w, h, (6, 7, 15, 16)), ramp("c8d4d4", "e4eeee", "f4fafa", "ffffff"), edge_dark=False)
    dots(img, [(7, 9), (8, 10), (13, 9), (12, 10)], hexc("1a2a2a"))  # sourcils fronces
    dots(img, [(8, 11), (12, 11)], hexc("1a2a2a"))
    line(img, [(9, 14), (12, 14)], hexc("a03030"))
    dots(img, [(5, 18), (16, 18)], hexc("0e2a2a"))
    for x, y in ((0, 3), (1, 1), (20, 3), (21, 5), (0, 9), (21, 10)):  # ca tremble
        dots(img, [(x, y)], hexc("a8fff0"))
    dots(img, [(5, 6), (4, 8)], hexc("e8fffa"))
    return img


def locked_drawer():
    """Le tiroir verrouille (contient un objet) : petit chiffonnier, serrure qui luit."""
    w, h = 20, 18
    img = canvas(w, h)
    wood = ramp("2a1418", "4a2430", "6a3a48", "8e5a68")
    part(img, poly(w, h, [(1, 2), (18, 2), (18, 16), (1, 16)]), wood, "140a0c")
    for y in (7, 11):
        line(img, [(2, y), (17, y)], wood[0])
    line(img, [(2, 8), (17, 8)], wood[3])
    line(img, [(2, 12), (17, 12)], wood[3])
    dots(img, [(9, 4), (10, 4), (9, 5), (10, 5)], hexc("e8d2ff"))  # serrure qui luit
    dots(img, [(9, 5)], hexc("8a6ab8"))
    dots(img, [(9, 9), (10, 9), (9, 13), (10, 13)], BRASS[2])
    dots(img, [(2, 17), (17, 17)], hexc("140a0c"))
    dots(img, [(2, 3), (3, 3)], hexc("b880a0"))
    return img


def pendulum():
    """Un balancier de pendule qui flotte, oscillant tout seul."""
    w, h = 14, 24
    img = canvas(w, h)
    line(img, [(7, 0), (7, 15)], BRASS[1])
    line(img, [(6, 0), (6, 14)], BRASS[3])
    part(img, ell(w, h, (1, 12, 12, 23)), BRASS, "3e2810")
    shade(img, ell(w, h, (4, 15, 9, 20)), ramp("c08a3a", "e8b85a", "fcdc8a", "fff6d0"), edge_dark=False)
    dots(img, [(3, 14), (4, 13)], BRASS_HI)
    return img


def paper_pile():
    """Une pile de papiers et de dossiers en vrac."""
    w, h = 22, 16
    img = canvas(w, h)
    for i, (y, dx, tones) in enumerate(((10, 0, ramp("6a3a2a", "8e5438", "b0704a", "d0946a")),
                                        (7, 2, ramp("a8a294", "d2ccbc", "ece6d6", "fffcf2")),
                                        (4, -1, ramp("3a4a6a", "506490", "6a80b0", "94a8d0")),
                                        (1, 1, ramp("a8a294", "d2ccbc", "ece6d6", "fffcf2")))):
        part(img, poly(w, h, [(2 + dx, y + 1), (19 + dx, y), (20 + dx, y + 4), (3 + dx, y + 5)]), tones, "2a2220")
    line(img, [(6, 3), (15, 2)], hexc("8a98c0"))
    dots(img, [(4, 2), (5, 2)], hexc("ffffff"))
    return img


def grandfather_clock():
    """La comtoise : grande horloge de bois, cadran creme, balancier dore derriere la vitre."""
    w, h = 16, 30
    img = canvas(w, h)
    wood = ramp("2a1410", "46241c", "643628", "864a36")
    part(img, poly(w, h, [(3, 13), (12, 13), (12, 26), (3, 26)]), wood, "120808")
    part(img, poly(w, h, [(1, 26), (14, 26), (14, 29), (1, 29)]), wood, "120808")
    part(img, ell(w, h, (1, 0, 14, 14)), wood, "120808")
    shade(img, ell(w, h, (3, 2, 12, 11)), ramp("c8bca0", "e2d8c0", "f2ecdc", "fffaf0"), edge_dark=False)
    line(img, [(7, 7), (7, 3)], hexc("2a1e18"))
    line(img, [(7, 7), (10, 7)], hexc("2a1e18"))
    shade(img, poly(w, h, [(5, 15), (10, 15), (10, 24), (5, 24)]), ramp("1a0e0a", "24140e", "2e1a12", "3a2216"), edge_dark=False)
    line(img, [(7, 15), (7, 20)], BRASS[2])
    shade(img, ell(w, h, (5, 19, 9, 23)), BRASS)
    dots(img, [(3, 3), (4, 2), (4, 14)], hexc("a8704a"))
    return img


def mardi():
    tiles("mardi", "paradoxal", [brass_floor(v) for v in range(4)], gear_pit_top(), gears_face())
    tiles("mardi", "profond", [parquet_floor(v) for v in range(4)], tick_wall_top(), panel_face())
    for name, make in {"etoile": mardi_star, "lune": compass, "horloge": hourglass, "bulle": stress_bubble,
                       "aiguille": clock_hand, "feuilles": sheets, "rouage": gear_sprite}.items():
        save(make(), "decor", "mardi", "paradoxal", f"{name}.png")
    for name, make in {"bougie": desk_lamp, "champignon": ringing_alarm, "cristal": locked_drawer,
                       "balancier": pendulum, "papiers": paper_pile, "comtoise": grandfather_clock}.items():
        save(make(), "decor", "mardi", "profond", f"{name}.png")


# --- Mercredi : le Palais des reflets (paradoxal) --------------------------------------------

SILVER = ramp("6e82aa", "8ea2c8", "b2c4e2", "dce8f8")
PEARL = ramp("a080b0", "bc9ec8", "d8bee0", "f2e0f4")


def mirror_floor(variant):
    """Dalles-miroirs en damier argent et nacre, biseau eclaire, reflet en diagonale ; variantes :
    une silhouette qui se reflete, des eclats irises, une fissure."""
    img = tile()

    def px(x, y):
        lx, ly = x % 25, y % 25
        tones = SILVER if ((x // 25) + (y // 25)) % 2 == 0 else PEARL
        e = bevel(lx, ly, 25, 25)
        if e == "seam":
            return hexc("4a4a6e")
        if e == "hi":
            return tones[3]
        if e == "lo":
            return tones[0]
        sheen = max(0.0, 1 - abs(((lx + ly) % 25) - 8) / 3.5)
        v = 0.4 + 0.08 * tnoise(x, y, 101) + 0.55 * sheen
        return band(tones[1:4], v, x, y, soft=0.08)
    each(img, px)
    if variant == 1:  # une silhouette se reflete, a peine (on dirait quelqu'un sous le verre)
        for y in range(TILE):
            for x in range(TILE):
                head = math.hypot(x - 37, y - 29) < 3
                body = abs(x - 37) < 4 - (y - 33) * 0.1 and 33 <= y <= 44
                if head or body:
                    r, g, b, a = img.getpixel((x, y))
                    img.putpixel((x, y), (r - 30, g - 34, b - 16, a))
    elif variant == 2:  # eclats irises
        for (sx, sy), hue in zip(((10, 12), (33, 36), (38, 14)), ("ffb8e8", "a8e8ff", "fff0a8")):
            dots(img, [(sx, sy), (sx + 1, sy), (sx, sy + 1), (sx + 2, sy - 1)], hexc(hue))
            dots(img, [(sx + 1, sy + 1)], hexc("ffffff"))
    elif variant == 3:  # fissure en etoile
        crack = [(30, 18), (28, 20), (27, 22), (25, 23), (23, 26), (21, 27), (19, 30), (27, 22), (29, 24), (30, 27),
                 (28, 20), (31, 20), (34, 19), (30, 18), (31, 15), (33, 13)]
        for x, y in crack:
            put(img, x + 1, y, hexc("ffffff"))
        for x, y in crack:
            put(img, x, y, hexc("52507a"))
    return img


def mirror_wall_top():
    """Le vide autour : un bleu de nuit qui reflete, des eclats de miroir qui scintillent."""
    img = tile()
    tones = [hexc("12142c"), hexc("171a36"), hexc("1d2140"), hexc("24284a")]
    each(img, lambda x, y: band(tones, 0.5 + tnoise(x, y, 111) * 0.5 + 0.2 * math.sin((x + y) * 0.18), x, y, soft=0.5))
    for sx, sy, big in ((9, 11, True), (36, 31, True), (24, 44, False), (44, 6, False), (15, 34, False)):
        put(img, sx, sy, hexc("e8f0ff"))
        if big:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                put(img, sx + dx, sy + dy, hexc("8a94c8"))
            put(img, sx + 2, sy, hexc("4a5288"))
            put(img, sx - 2, sy, hexc("4a5288"))
    return img


def glass_face():
    """Parois de verre : panneaux bleutes encadres d'argent, reflets obliques."""
    img = tile()
    glass = ramp("2e3a6a", "3e4e86", "5468a4", "7a8ec4")

    def px(x, y):
        lx = x % 25
        if y < 3 or y > 46 or lx < 2:
            if y == 0 or lx == 0:
                return SILVER[3]
            if y == 49:
                return hexc("2a2a44")
            return SILVER[1]
        if lx == 2 or y == 3:
            return hexc("1e2448")
        v = 0.55 - 0.3 * (y / TILE)
        stripe = (lx * 2 - y) % 40
        if stripe < 3 or 8 <= stripe < 9:
            v += 0.45
        return band(glass, v, x, y, soft=0.25)
    each(img, px)
    for cx in (0, 25):
        for cy in (1, 48):
            put(img, cx + 1, cy, hexc("ffffff"))
    return darken_down(img, 0.2)


def twin_star():
    """Reflet d'etoile (soigne) : une etoile, et son double a l'envers, plus pale, en dessous."""
    w, h = 18, 26
    img = canvas(w, h)
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        r = 7.5 if k % 2 == 0 else 3.6
        pts.append((8.5 + math.cos(a) * r, 8 + math.sin(a) * r))
    part(img, poly(w, h, pts), ramp("a07ab0", "d0a8e0", "f0d8ff", "ffffff"), "5a3a7a")
    dots(img, [(6, 8), (11, 8)], hexc("5a3a7a"))
    dots(img, [(8, 10), (9, 10)], hexc("8a5aa0"))
    double = img.transpose(Image.FLIP_TOP_BOTTOM)
    fade(double, 0.45)
    img.alpha_composite(double, (0, 9))
    line(img, [(1, 17), (16, 17)], hexc("c8d0f0", 160))
    dots(img, [(7, 2), (6, 4)], hexc("ffffff"))
    return img


def yarn_ball():
    """Le fil d'Ariane (guide) : une pelote de laine rouge dont le fil part au loin."""
    w, h = 20, 16
    img = canvas(w, h)
    red = ramp("7a1424", "b02434", "d8444a", "f47a74")
    part(img, ell(w, h, (1, 2, 13, 14)), red, "4a0a14")
    for k in range(4):
        line(img, [(3 + k * 2, 3 + k), (11 - k, 13 - k * 0.5)], red[1])
    line(img, [(3, 8), (11, 5)], red[3])
    line(img, [(12, 12), (15, 14), (18, 13), (19, 15)], red[2])
    dots(img, [(4, 4), (5, 3)], hexc("ffc0b8"))
    return img


def frozen_coin():
    """La piece figee (pause) : une piece suspendue en plein vol, son ombre arretee au sol."""
    w, h = 16, 22
    img = canvas(w, h)
    part(img, ell(w, h, (3, 1, 12, 14)), ramp("a06a14", "d89a28", "f8c850", "fff0a0"), "5a3a08")
    shade(img, ell(w, h, (5, 3, 10, 12)), ramp("b07a1e", "e0a830", "f8c850", "fff0a0"), light=(0.6, 0.6), edge_dark=False)
    dots(img, [(7, 6), (8, 6), (7, 7), (7, 8), (8, 9), (7, 10)], hexc("a06a14"))
    for y in (3, 7, 11):
        dots(img, [(1, y), (14, y + 1)], hexc("d8e0ff"))
    shade(img, ell(w, h, (3, 18, 12, 21)), ramp("2a2a44", "3a3a58", "4a4a6a", "5a5a7a"), edge_dark=False)
    dots(img, [(5, 3), (4, 5)], hexc("ffffff"))
    return img


def question_bubble():
    """Bulle de doute : un point d'interrogation flotte dedans."""
    def mark(img):
        dots(img, [(7, 5), (8, 4), (9, 4), (10, 4), (11, 5), (11, 6), (10, 7), (9, 8), (9, 9), (9, 12)], hexc("6a5aa8", 220))
    return bubble(18, 18, ["c8d0ff", "e0c8ff", "c8f0ff"], "dcdcff", mark)


def mirror_frame():
    """Un grand cadre dore et ouvrage ; dans le miroir, rien ne se reflete."""
    w, h = 20, 26
    img = canvas(w, h)
    gold = ramp("7a5010", "b88424", "e8b84a", "fff0a0")
    part(img, mask_wh(w, h, polys=[[(1, 3), (18, 3), (18, 24), (1, 24)]], ellipses=[(5, 0, 14, 6)]), gold, "4a2e08")
    shade(img, poly(w, h, [(4, 6), (15, 6), (15, 21), (4, 21)]), ramp("4a5288", "6a74aa", "98a2cc", "c8d0ee"), light=(-0.8, -0.3))
    line(img, [(6, 8), (9, 8)], hexc("e8f0ff"))
    line(img, [(6, 9), (6, 12)], hexc("e8f0ff"))
    dots(img, [(9, 2), (10, 2), (2, 13), (17, 13), (9, 23)], hexc("fff4c0"))
    dots(img, [(3, 4), (2, 6)], hexc("ffffff"))
    return img


def marble_bust():
    """Un buste de marbre sur sa colonne, les yeux vides."""
    w, h = 16, 28
    img = canvas(w, h)
    marble = ramp("8a8aa0", "b4b4c8", "d8d8e6", "f6f6ff")
    part(img, poly(w, h, [(4, 15), (11, 15), (11, 25), (4, 25)]), marble, "4a4a60")
    part(img, poly(w, h, [(2, 24), (13, 24), (14, 27), (1, 27)]), marble, "4a4a60")
    part(img, poly(w, h, [(1, 14), (14, 14), (12, 10), (3, 10)]), marble, "4a4a60")
    part(img, ell(w, h, (4, 0, 11, 9)), marble, "4a4a60")
    dots(img, [(6, 4), (9, 4)], marble[0])
    for y in range(17, 24, 2):
        dots(img, [(6, y), (9, y)], marble[1])
    dots(img, [(5, 1), (4, 3)], hexc("ffffff"))
    return img


def stairs_nowhere():
    """Un petit escalier qui monte... et s'arrete dans le vide."""
    w, h = 22, 20
    img = canvas(w, h)
    stone = ramp("6a6488", "8e88ae", "b4aed0", "dcd6f0")
    for i in range(4):
        x0, y0 = 1 + i * 5, 15 - i * 4
        part(img, poly(w, h, [(x0, y0), (21, y0), (21, y0 + 4), (x0, y0 + 4)]), stone, "3a3458")
        line(img, [(x0, y0), (20, y0)], stone[3])
    dots(img, [(18, 1), (19, 0), (20, 1)], hexc("c8d0ff"))
    return img


# --- Mercredi : le Carrefour brumeux (profond) -----------------------------------------------

COBBLE = [ramp("2a3430", "3a4640", "4c5a52", "62726a"), ramp("2e3434", "3e4644", "505a56", "66706a"),
          ramp("28302e", "36403c", "46524c", "5a6862")]
COBBLE_CELLS = seeds(16, 121)


SETT_ROWS = [(0, [0, 12, 23, 37]), (10, [6, 19, 31, 42]), (20, [3, 14, 27, 38]), (30, [9, 21, 33, 45]),
             (40, [1, 15, 26, 39])]


def sett(x, y):
    """Pave d'une rangee : (indice, position locale u, v dans 0..1, largeur, hauteur) ou None (joint)."""
    row = (y // 10) % 5
    y0, cuts = SETT_ROWS[row]
    ly = y - y0
    for k, c in enumerate(cuts):
        n = cuts[(k + 1) % len(cuts)] + (TILE if k == len(cuts) - 1 else 0)
        lx = (x - c) % TILE
        if lx < n - c:
            w = n - c
            u, v = (lx - (w - 1) / 2) / ((w - 2) / 2), (ly - 4.5) / 4.0
            if abs(u) ** 4 + abs(v) ** 4 > 1:
                return None
            return row * 4 + k, u, v
    return None


def cobble_floor(variant):
    """Vieux paves gris-vert bombes, en rangees decalees, joints sombres ; variantes : mousse,
    flaque, pave fendu."""
    img = tile()
    moss = [hexc("223a22"), hexc("2e4e2a"), hexc("3e6634")]

    def px(x, y):
        s = sett(x, y)
        if s is None:
            if variant == 1 and tnoise(x, y, 125, 2.0) > 0.05:
                return band(moss, 0.5 + tnoise(x, y, 127, 2.0), x, y, 0.5)
            return hexc("141a18")
        i, u, v = s
        tones = COBBLE[(i * 7) % 3]
        k = abs(u) ** 4 + abs(v) ** 4
        light = 0.62 - 0.32 * (u * 0.6 + v) - 0.25 * k + random.Random(i).uniform(-0.08, 0.08)
        return band(tones, light, x, y, soft=0.15)
    each(img, px)
    if variant == 2:  # flaque qui reflete le ciel gris
        for y in range(TILE):
            for x in range(TILE):
                dx, dy = tdist(x, y, 26, 30)
                k = 1 - math.hypot(dx / 11, dy / 5.5) + tnoise(x, y, 129, 2.0) * 0.25
                if k > 0:
                    img.putpixel((x, y), band([hexc("1e2a30"), hexc("2a3a44"), hexc("3e5260")], 0.3 + k * 0.9 - (y - 30) * 0.03, x, y, 0.3))
                    if 0.05 < k < 0.14 and y < 30:
                        img.putpixel((x, y), hexc("8aa0ac"))
    elif variant == 3:  # un pave fendu
        crack = [(14, 9), (15, 11), (14, 13), (16, 15), (17, 17), (16, 18)]
        for x, y in crack:
            put(img, x + 1, y, COBBLE[0][3])
            put(img, x, y, hexc("121816"))
    return img


def fog_wall_top():
    """Le brouillard autour du carrefour : nappes gris-vert tramees."""
    img = tile()
    tones = [hexc("121816"), hexc("181f1d"), hexc("1f2826"), hexc("283230"), hexc("323e3a")]
    return each(img, lambda x, y: band(tones, 0.4 + tnoise(x, y, 131) * 0.55 + tnoise(x, y, 133, 2.0) * 0.2, x, y, soft=0.5))


LEAVES = [hexc("12241a"), hexc("1a3424"), hexc("24462e"), hexc("30583a"), hexc("42704a")]
LEAF_CELLS = seeds(36, 141)


def hedge_face():
    """Haie taillee : touffes de feuilles modelees, dessus plat eclaire, pied dans l'ombre."""
    img = tile()

    def px(x, y):
        d1, d2, i = voronoi(x, (y * 1.3) % TILE, LEAF_CELLS)
        _, _, j = voronoi(x - 1.5, (y * 1.3 - 2) % TILE, LEAF_CELLS)
        v = 0.55 - d1 / 9 + (0.22 if j == i else -0.15) - 0.35 * (y / TILE)
        if d2 - d1 < 0.8:
            v -= 0.25
        if y < 3:
            v = 0.95 if y == 0 else 0.75
        return band(LEAVES, v, x, y, soft=0.25)
    return each(img, px)


def street_lamp():
    """Le lampadaire allume (s'allume) : un reverbere de fonte, sa lanterne chaude dans la brume."""
    w, h = 14, 30
    img = canvas(w, h)
    iron = ramp("1a2220", "2a3632", "3e4c46", "56665e")
    part(img, poly(w, h, [(6, 9), (8, 9), (8, 26), (6, 26)]), iron, "0a0e0c")
    part(img, poly(w, h, [(3, 26), (11, 26), (12, 29), (2, 29)]), iron, "0a0e0c")
    part(img, poly(w, h, [(3, 1), (11, 1), (12, 3), (2, 3)]), iron, "0a0e0c")
    part(img, poly(w, h, [(3, 3), (11, 3), (10, 9), (4, 9)]), ramp("c88a3a", "f0b858", "ffe08e", "fff8d8"), "4a3414")
    line(img, [(7, 3), (7, 8)], hexc("8a6a3a"))
    dots(img, [(5, 4), (5, 5)], hexc("ffffff"))
    return img


def fallen_mask():
    """Le masque pose au sol (lance un combat) : un masque blanc, fendu, qui regarde le ciel."""
    w, h = 22, 14
    img = canvas(w, h)
    porcelain = ramp("8a8e9a", "b8bcc6", "dcdfe6", "fafbff")
    for x0 in (0, 18):  # rubans
        line(img, [(x0 + 1, 7), (x0 + (3 if x0 else -1), 11), (x0 + (2 if x0 else 0), 13)], hexc("8a2a3a"))
    part(img, ell(w, h, (2, 1, 19, 13)), porcelain, "3a3e4a")
    for ex in (6, 13):
        shade(img, ell(w, h, (ex, 4, ex + 3, 7)), ramp("0e1014", "16181e", "1e2028", "282a34"), edge_dark=False)
    line(img, [(8, 10), (11, 11), (14, 10)], hexc("3a3e4a"))
    line(img, [(12, 1), (11, 3), (12, 5)], hexc("5a5e6a"))
    dots(img, [(5, 3), (4, 5)], hexc("ffffff"))
    dots(img, [(4, 9), (17, 9)], hexc("e0a8b0"))
    return img


def suitcase():
    """La valise abandonnee (contient un objet) : cuir fauve, sangles, coins de laiton."""
    w, h = 22, 18
    img = canvas(w, h)
    leather = ramp("4a2a14", "7a4622", "a46634", "c8884e")
    line(img, [(8, 4), (8, 1), (13, 1), (13, 4)], hexc("2a1608"), 2)
    part(img, poly(w, h, [(1, 4), (20, 4), (20, 16), (1, 16)]), leather, "241206")
    for x in (6, 15):
        line(img, [(x, 5), (x, 15)], hexc("5a3418"))
        dots(img, [(x, 9), (x, 10)], BRASS[2])
    for x, y in ((2, 5), (19, 5), (2, 15), (19, 15)):
        dots(img, [(x, y)], BRASS[3])
    dots(img, [(3, 6), (4, 6)], hexc("e8b480"))
    return img


def signpost():
    """Le panneau du carrefour : un poteau, trois fleches qui se contredisent."""
    w, h = 22, 28
    img = canvas(w, h)
    wood = ramp("3a2a1e", "5a4230", "7a5c44", "9a7a5e")
    part(img, poly(w, h, [(10, 2), (12, 2), (12, 27), (10, 27)]), wood, "1a120c")
    for y, left, tones in ((4, False, ramp("4a4a3e", "6e6e5a", "94947a", "bab8a0")),
                           (11, True, ramp("3e4a44", "5a6e64", "7a948a", "a0b8ae")),
                           (18, False, ramp("4a3e3e", "6e5a5a", "947a7a", "b8a0a0"))):
        pts = [(2, y), (16, y), (20, y + 2.5), (16, y + 5), (2, y + 5)] if not left else \
              [(20, y), (6, y), (2, y + 2.5), (6, y + 5), (20, y + 5)]
        part(img, poly(w, h, pts), tones, "1a1a16")
        line(img, [(5 if not left else 8, y + 2.5), (14 if not left else 17, y + 2.5)], tones[0])
    dots(img, [(3, 5), (11, 3)], hexc("e8e4d0"))
    return img


def park_bench():
    """Un banc de square : lattes de bois, pieds de fonte."""
    w, h = 26, 16
    img = canvas(w, h)
    wood = ramp("4a3420", "6e4e30", "906a44", "b48a5e")
    iron = ramp("161c1a", "222a28", "323c38", "46524c")
    for x0 in (3, 20):
        part(img, poly(w, h, [(x0, 2), (x0 + 2, 2), (x0 + 2, 15), (x0, 15)]), iron, "0a0e0c")
    for y in (2, 5):
        part(img, poly(w, h, [(1, y), (24, y), (24, y + 1), (1, y + 1)]), wood, "241a10")
    part(img, poly(w, h, [(1, 9), (24, 9), (25, 11), (0, 11)]), wood, "241a10")
    dots(img, [(2, 2), (3, 9)], hexc("e0c098"))
    return img


def mercredi():
    tiles("mercredi", "paradoxal", [mirror_floor(v) for v in range(4)], mirror_wall_top(), glass_face())
    tiles("mercredi", "profond", [cobble_floor(v) for v in range(4)], fog_wall_top(), hedge_face())
    for name, make in {"etoile": twin_star, "lune": yarn_ball, "horloge": frozen_coin, "bulle": question_bubble,
                       "cadre": mirror_frame, "statue": marble_bust, "escalier": stairs_nowhere}.items():
        save(make(), "decor", "mercredi", "paradoxal", f"{name}.png")
    for name, make in {"bougie": street_lamp, "champignon": fallen_mask, "cristal": suitcase,
                       "panneau": signpost, "banc": park_bench}.items():
        save(make(), "decor", "mercredi", "profond", f"{name}.png")


# --- Jeudi : l'Usine a attendre (paradoxal) --------------------------------------------------

CONCRETE = [hexc("5e6068"), hexc("6c6e76"), hexc("7a7c84"), hexc("888a92")]


def concrete_floor(variant):
    """Dalle de beton lisse, granulats, joint de dilatation ; variantes : bande de file d'attente
    jaune et noire, fleche peinte usee, ticket tombe."""
    img = tile()

    def px(x, y):
        e = bevel(x, y, TILE, TILE)
        if e == "seam":
            return hexc("3a3c44")
        if e == "hi":
            return CONCRETE[3]
        if e == "lo":
            return CONCRETE[0]
        v = 0.5 + tnoise(x, y, 151) * 0.4
        c = band(CONCRETE[1:], v, x, y, soft=0.15)
        h = random.Random(x * 53 + y * 7).random()
        if h < 0.025:
            c = CONCRETE[0]  # granulats
        elif h > 0.985:
            c = hexc("9a9ca4")
        return c
    each(img, px)
    if variant == 1:  # bande de file d'attente (traverse la dalle d'un bord a l'autre)
        for y in range(21, 29):
            for x in range(TILE):
                if y in (21, 28):
                    img.putpixel((x, y), hexc("3a3a2a"))
                else:
                    yellow = ((x + y) // 4) % 2 == 0
                    worn = dither(x, y) < 0.12 + 0.2 * max(0.0, tnoise(x, y, 153, 2.0))
                    c = hexc("e8c030") if yellow else hexc("26262a")
                    if worn:
                        c = CONCRETE[2]
                    img.putpixel((x, y), c)
    elif variant == 2:  # fleche peinte, usee
        arrow = poly(TILE, TILE, [(12, 22), (28, 22), (28, 15), (39, 25), (28, 35), (28, 28), (12, 28)])
        for y in range(TILE):
            for x in range(TILE):
                if arrow.getpixel((x, y)) and dither(x, y) > 0.18 + 0.3 * max(0.0, tnoise(x, y, 155, 2.0)):
                    img.putpixel((x, y), hexc("e8e4d8"))
    elif variant == 3:  # ticket tombe
        t = canvas(12, 8)
        part(t, poly(12, 8, [(1, 2), (10, 0), (11, 5), (2, 7)]), ramp("a89a78", "d8cca8", "f0e6c8", "fffae8"), "4a4438")
        dots(t, [(4, 3), (5, 3), (7, 3), (7, 4), (4, 5)], hexc("c04040"))
        stamp(img, t, 30, 30)
    return img


def tread_top():
    """Le vide autour : tole striee sombre (losanges en relief)."""
    img = tile()

    def px(x, y):
        c = band([hexc("1a1c22"), hexc("20232a"), hexc("272a32")], 0.5 + tnoise(x, y, 161) * 0.5, x, y, soft=0.4)
        lx, ly = x % 10, y % 10
        if (y // 5) % 2:
            lx = (x + 5) % 10
        ly = y % 5
        if (lx, ly) in ((1, 3), (2, 2), (3, 1)):
            c = hexc("3a3e48")
        elif (lx, ly) in ((2, 3), (3, 2), (4, 1)):
            c = hexc("101216")
        return c
    return each(img, px)


def shutter_face():
    """Guichet ferme : rideau de fer baisse, bandeau orange, cadenas au pied."""
    img = tile()
    steel = [hexc("4a4e58"), hexc("5c606a"), hexc("6e727c"), hexc("848892")]

    def px(x, y):
        if y < 8:  # bandeau orange
            if y == 0:
                return hexc("ffd08a")
            if y == 7:
                return hexc("5a2a0a")
            return band([hexc("c05a18"), hexc("e07a26"), hexc("f09a3a")], 0.75 - y / 9, x, y, 0.2)
        if y == 8:
            return hexc("1a1c22")
        ly = (y - 9) % 5
        if ly == 0:
            return steel[3]
        if ly == 4:
            return hexc("2a2c34")
        return band(steel, 0.6 - ly * 0.12 + tnoise(x, y, 163) * 0.15, x, y, 0.15)
    each(img, px)
    for x in range(TILE):  # rail au pied
        img.putpixel((x, 46), hexc("2a2c34"))
        img.putpixel((x, 47), steel[2])
        img.putpixel((x, 48), steel[1])
        img.putpixel((x, 49), hexc("1a1c22"))
    lock = canvas(7, 9)
    line(lock, [(1, 3), (1, 1), (2, 0), (4, 0), (5, 1), (5, 3)], hexc("9a9ca8"))
    part(lock, poly(7, 9, [(0, 3), (6, 3), (6, 8), (0, 8)]), ramp("6a4a10", "a8781e", "d8a838", "f8d870"), "2a1a04")
    dots(lock, [(3, 5), (3, 6)], hexc("2a1a04"))
    stamp(img, lock, 22, 37)
    for x in range(1, TILE, 2):  # pointilles de la bande
        img.putpixel((x, 3), hexc("ffe0a8"))
    return darken_down(img, 0.25)


def golden_ticket():
    """Ticket gagnant (soigne) : ticket dore, bords dentes, une etoile au milieu."""
    w, h = 22, 14
    img = canvas(w, h)
    gold = ramp("a0701c", "d8a430", "f8d058", "fff4b0")
    mask = poly(w, h, [(1, 2), (20, 2), (20, 12), (1, 12)])
    for y in (4, 7, 10):  # encoches
        for x in (1, 20):
            mask.putpixel((x, y), 0)
    part(img, mask, gold, "5a3a08")
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        r = 4 if k % 2 == 0 else 1.8
        pts.append((10.5 + math.cos(a) * r, 7.2 + math.sin(a) * r))
    shade(img, poly(w, h, pts), ramp("c04a20", "e06a28", "ff9a40", "ffd080"))
    for y in range(3, 12, 2):
        dots(img, [(5, y), (16, y)], hexc("b8862a"))
    dots(img, [(3, 3), (4, 3)], hexc("ffffff"))
    for x, y in ((0, 0), (21, 1), (19, 13)):
        dots(img, [(x, y)], hexc("fff4b0"))
    return img


def exit_sign():
    """Le panneau SORTIE (guide) : caisson vert lumineux, petit bonhomme qui court, fleche."""
    w, h = 22, 22
    img = canvas(w, h)
    part(img, poly(w, h, [(10, 13), (11, 13), (11, 21), (10, 21)]), ramp("2a2c34", "44464e", "5e6068", "7a7c84"), "16181c")
    part(img, poly(w, h, [(1, 1), (20, 1), (20, 13), (1, 13)]), ramp("0e6a3a", "16934e", "28c06a", "7aeaa8"), "06301a")
    white = hexc("f4fff8")
    dots(img, [(6, 3), (5, 5), (6, 5), (7, 5), (6, 6), (5, 7), (7, 7), (4, 9), (8, 8), (4, 6), (8, 6)], white)  # bonhomme
    line(img, [(11, 7), (17, 7)], white)
    dots(img, [(16, 5), (17, 6), (16, 9), (17, 8)], white)
    dots(img, [(2, 2), (3, 2)], hexc("c8ffe0"))
    return img


def red_light():
    """Le feu rouge (pause) : boitier noir, le rouge allume, l'orange et le vert eteints."""
    w, h = 12, 28
    img = canvas(w, h)
    part(img, poly(w, h, [(5, 19), (6, 19), (6, 27), (5, 27)]), ramp("2a2c34", "44464e", "5e6068", "7a7c84"), "16181c")
    part(img, poly(w, h, [(1, 1), (10, 1), (10, 20), (1, 20)]), ramp("16181c", "24262c", "34363e", "484a52"), "08080a")
    for i, (lit, off) in enumerate((("ff6050", "4a1a18"), (None, "4a3814"), (None, "143a20"))):
        box = (3, 3 + i * 6, 8, 8 + i * 6)
        if lit:
            shade(img, ell(w, h, box), ramp("b81e1e", "e83a32", "ff7a60", "ffd0c0"))
        else:
            shade(img, ell(w, h, box), [hexc(off)] * 3 + [hexc(off)], edge_dark=False)
    dots(img, [(4, 4)], hexc("ffffff"))
    for x, y in ((0, 5), (11, 5), (0, 8), (11, 8)):
        dots(img, [(x, y)], hexc("ff8a70", 160))
    return img


def anger_bubble():
    """Bulle de colere : bulle rouge, une veine en croix qui pulse dedans."""
    def vein(img):
        for x, y in ((7, 6), (8, 7), (10, 7), (11, 6), (7, 11), (8, 10), (10, 10), (11, 11)):
            dots(img, [(x, y)], hexc("c81e2a", 230))
        dots(img, [(9, 8), (9, 9), (8, 8), (10, 9)], hexc("ff5a5a", 200))
    return bubble(18, 18, ["ff7a6a", "ff5a5a", "ffa080"], "ff9a8a", vein)


def stanchion():
    """Barriere de file d'attente : deux poteaux chromes, une sangle rouge tendue entre eux."""
    w, h = 24, 18
    img = canvas(w, h)
    chrome = ramp("4a4e5a", "8a90a0", "c4cad6", "f4f8ff")
    for x0 in (2, 18):
        part(img, poly(w, h, [(x0, 2), (x0 + 3, 2), (x0 + 3, 15), (x0, 15)]), chrome, "1e2028")
        part(img, ell(w, h, (x0 - 2, 14, x0 + 5, 17)), chrome, "1e2028")
        part(img, ell(w, h, (x0 - 1, 0, x0 + 4, 3)), chrome, "1e2028")
    line(img, [(6, 5), (18, 5)], hexc("c81e2a"), 2)
    line(img, [(6, 5), (18, 5)], hexc("ff5a5a"))
    dots(img, [(3, 3), (19, 3)], hexc("ffffff"))
    return img


def rubber_stamp():
    """Le tampon : manche de bois, socle d'encre, et sa marque rouge REFUSE sur une feuille."""
    w, h = 22, 20
    img = canvas(w, h)
    part(img, poly(w, h, [(1, 11), (15, 9), (17, 18), (3, 19)]), ramp("a8a294", "d2ccbc", "ece6d6", "fffcf2"), "5a5448")
    for x, y in ((5, 13), (6, 13), (7, 13), (9, 13), (10, 12), (11, 12), (12, 14), (5, 16), (8, 16), (11, 15), (12, 15)):
        dots(img, [(x, y)], hexc("d03030"))
    line(img, [(4, 12), (13, 11), (14, 16), (5, 17), (4, 12)], hexc("d03030"))
    part(img, poly(w, h, [(13, 8), (21, 8), (21, 11), (13, 11)]), ramp("2a2c34", "44464e", "5e6068", "7a7c84"), "16181c")
    part(img, poly(w, h, [(15, 4), (19, 4), (19, 8), (15, 8)]), ramp("4a2a14", "7a4824", "a46a36", "c88e52"), "2a160a")
    part(img, ell(w, h, (14, 0, 20, 5)), ramp("7a1424", "b02434", "d8444a", "f47a74"), "3a0a12")
    dots(img, [(15, 1), (16, 1)], hexc("ffc0b8"))
    return img


def ticket_machine():
    """Le distributeur de tickets : boitier rouge sur pied, un ticket qui depasse."""
    w, h = 14, 28
    img = canvas(w, h)
    part(img, poly(w, h, [(6, 12), (8, 12), (8, 25), (6, 25)]), ramp("2a2c34", "44464e", "5e6068", "7a7c84"), "16181c")
    part(img, ell(w, h, (2, 24, 11, 27)), ramp("2a2c34", "44464e", "5e6068", "7a7c84"), "16181c")
    part(img, poly(w, h, [(2, 1), (11, 1), (12, 2), (12, 12), (1, 12), (1, 2)]), ramp("8a1a1a", "c02a26", "e84a3a", "ff8a6a"), "3a0808")
    shade(img, poly(w, h, [(3, 3), (10, 3), (10, 7), (3, 7)]), ramp("1a1c22", "24262c", "2e3038", "3a3c44"), edge_dark=False)
    dots(img, [(4, 5), (5, 5), (7, 4), (7, 5), (7, 6), (8, 5), (9, 5)], hexc("ff7040"))  # le numero en cours
    line(img, [(4, 10), (9, 10)], hexc("3a0808"))
    part(img, poly(w, h, [(5, 11), (9, 11), (10, 16), (6, 16)]), ramp("a89a78", "d8cca8", "f0e6c8", "fffae8"), "4a4438")
    dots(img, [(3, 3), (3, 5)], hexc("ffc0b0"))
    return img


def closed_gate():
    """Barriere des Portes closes (regle du jeudi) : deux poteaux, deux lisses rayees rouge et blanc."""
    w, h = 28, 19
    img = canvas(w, h)
    post = ramp("2a2c34", "4a4e58", "6e727c", "9a9ea8")
    for x0 in (1, 24):
        part(img, poly(w, h, [(x0, 1), (x0 + 2, 1), (x0 + 2, 18), (x0, 18)]), post, "121418")
    for y0 in (3, 10):
        mask = poly(w, h, [(2, y0), (25, y0), (25, y0 + 4), (2, y0 + 4)])
        layer = canvas(w, h)
        shade(layer, mask, ramp("8a1414", "c82828", "e84a3e", "ff8a7a"))
        for y in range(h):
            for x in range(w):
                if mask.getpixel((x, y)) and ((x - y) // 4) % 2 == 0:
                    layer.putpixel((x, y), hexc("f4ece4") if y > y0 else hexc("ffffff"))
        ink(layer, hexc("3a0a0a"))
        img.alpha_composite(layer)
    for x0 in (1, 24):
        dots(img, [(x0, 1), (x0 + 1, 1)], hexc("c8ccd8"))
    return img


# --- Jeudi : la Fournaise (profond) ----------------------------------------------------------

IRON = [hexc("1e1a1c"), hexc("2a2426"), hexc("362e2e"), hexc("443a38"), hexc("54484a")]
EMBER = [hexc("8a1e0a"), hexc("d04a12"), hexc("ff8a2a"), hexc("ffd070")]


def glow_line(img, pts, width=1):
    """Fissure de braise : coeur jaune, bord orange, halo rouge."""
    for x, y in pts:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            r, g, b, a = img.getpixel(((x + dx) % TILE, (y + dy) % TILE))
            put(img, x + dx, y + dy, (min(255, r + 50), g + 8, b, a))
    for x, y in pts:
        put(img, x, y, EMBER[2])
    for x, y in pts[::3]:
        put(img, x, y, EMBER[3])


def path_pts(seed, x0, y0, length, dx=1, wiggle=1):
    rng = random.Random(seed)
    pts, x, y = [], x0, y0
    for _ in range(length):
        pts.append((x, y))
        x += dx
        y += rng.choice((-wiggle, 0, 0, wiggle))
    return pts


def furnace_floor(variant):
    """Plaques de fonte sombre rivetees, chaleur aux joints ; variantes : longue fissure de braise,
    grille sur le feu, escarbilles."""
    img = tile()

    def px(x, y):
        e = bevel(x, y, TILE, TILE)
        if e == "seam":
            return EMBER[1] if (x * 7 + y * 3) % 11 == 0 else hexc("1a0e0c")
        if e == "hi":
            return IRON[4]
        if e == "lo":
            return hexc("120e10")
        v = 0.45 + tnoise(x, y, 171) * 0.35
        return band(IRON[1:4], v, x, y, soft=0.2)
    each(img, px)
    for rx, ry in ((4, 4), (45, 4), (4, 45), (45, 45)):
        put(img, rx, ry, IRON[4])
        put(img, rx + 1, ry + 1, hexc("0e0a0a"))
    if variant == 1:  # fissure de braise d'un bord a l'autre
        glow_line(img, path_pts(173, 0, 26, TILE))
    elif variant == 2:  # grille : le feu dessous
        for i in range(5):
            x = 15 + i * 4
            for y in range(15, 35):
                put(img, x, y, IRON[0])
                put(img, x + 1, y, EMBER[1] if (y + i) % 5 else EMBER[2])
                put(img, x + 2, y, EMBER[0])
        for y in (14, 35):
            for x in range(14, 35):
                put(img, x, y, IRON[4] if y == 14 else hexc("0e0a0a"))
    elif variant == 3:  # escarbilles
        for sx, sy in ((12, 14), (33, 22), (21, 36), (39, 39), (9, 30)):
            put(img, sx, sy, EMBER[2])
            put(img, sx + 1, sy, EMBER[0])
            put(img, sx, sy + 1, hexc("2a1a14"))
    return img


def ember_top():
    """Le vide autour : nuit rougeoyante, braises qui flottent."""
    img = tile()
    tones = [hexc("120808"), hexc("1a0c0a"), hexc("24100c"), hexc("30140e")]
    each(img, lambda x, y: band(tones, 0.4 + tnoise(x, y, 181) * 0.6, x, y, soft=0.5))
    for sx, sy in ((7, 9), (31, 15), (43, 38), (18, 40), (26, 28)):
        put(img, sx, sy, EMBER[2])
        put(img, sx, sy + 1, EMBER[0])
    return img


def hot_brick_face():
    """Briques chauffees : rangees decalees, chaque brique modelee, de plus en plus rouge vers le
    pied ou le feu couve."""
    img = tile()
    bricks = [[hexc("2e1612"), hexc("44201a"), hexc("5a2c22"), hexc("6e3a2c")],
              [hexc("3e1a12"), hexc("58261a"), hexc("743424"), hexc("8a4430")],
              [hexc("5a2214"), hexc("7a321a"), hexc("9a4622"), hexc("b85e30")],
              [hexc("7a2e14"), hexc("a8461c"), hexc("cc6426"), hexc("e88a3a")]]

    def px(x, y):
        row, ly = y // 7, y % 7
        lx = (x + (12 if row % 2 else 0)) % 25
        brick = bricks[min(3, max(0, row - 3))]  # plus on descend, plus c'est chaud
        if ly == 6 or lx == 24:
            return EMBER[1] if row >= 6 and (x + y) % 4 == 0 else hexc("140a08")
        if ly == 0 or lx == 0:
            return brick[3]
        v = 0.45 + tnoise(x, y, 191) * 0.3 - (ly - 3) * 0.06
        return band(brick[:3], v, x, y, 0.2)
    each(img, px)
    return img


def ember_heap():
    """Le tas de braises (s'allume) : charbons noirs fendus de feu, une petite flamme."""
    w, h = 22, 16
    img = canvas(w, h)
    coal = ramp("120c0c", "221816", "322422", "443432")
    for box in ((1, 7, 9, 15), (6, 4, 15, 13), (12, 8, 21, 15), (4, 10, 13, 15)):
        part(img, ell(w, h, box), coal, "080404")
    for pts in (((3, 11), (5, 12), (7, 11)), ((8, 7), (10, 9), (12, 8)), ((14, 11), (16, 12), (18, 11)), ((7, 13), (10, 13))):
        line(img, pts, EMBER[2])
    part(img, poly(w, h, [(9, 6), (10, 0), (12, 3), (13, 1), (14, 6)]), ramp("c03a10", "f06a1a", "ffa83a", "fff0a0"), None)
    dots(img, [(11, 4), (12, 5)], hexc("fff8d0"))
    return img


def pressure_cooker():
    """La cocotte qui siffle (lance un combat) : marmite d'acier, soupape qui crache, sourcils fronces."""
    w, h = 24, 22
    img = canvas(w, h)
    steel = ramp("3a3e4a", "6a707e", "9aa2b0", "d0d6e0")
    for s, (x, y) in enumerate(((10, 0), (13, 1), (8, 2), (14, 3))):
        dots(img, [(x, y)], hexc("e8eef8", 200 - s * 30))
    part(img, poly(w, h, [(10, 4), (13, 4), (13, 7), (10, 7)]), ramp("1a1c22", "34363e", "4e505a", "6a6c76"), "0e0e12")
    part(img, ell(w, h, (3, 6, 20, 11)), steel, "1a1c24")
    part(img, poly(w, h, [(3, 10), (20, 10), (19, 20), (4, 20)]), steel, "1a1c24")
    for x0 in (0, 20):
        part(img, poly(w, h, [(x0, 11), (x0 + 3, 11), (x0 + 3, 13), (x0, 13)]), ramp("1a1c22", "34363e", "4e505a", "6a6c76"), "0e0e12")
    dots(img, [(7, 13), (8, 14), (15, 13), (14, 14)], hexc("1a1c24"))
    dots(img, [(8, 15), (14, 15)], hexc("ff5a2a"))
    line(img, [(9, 18), (13, 18)], hexc("1a1c24"))
    dots(img, [(5, 11), (5, 13)], hexc("f4f8ff"))
    return img


def safe_box():
    """Le coffre-fort (contient un objet) : acier vert sombre, cadran, poignee de laiton."""
    w, h = 20, 20
    img = canvas(w, h)
    green = ramp("1a2a26", "2a423c", "3e5e54", "5a8070")
    part(img, poly(w, h, [(1, 1), (18, 1), (18, 17), (1, 17)]), green, "0a1210")
    shade(img, poly(w, h, [(3, 3), (16, 3), (16, 15), (3, 15)]), green, light=(0.6, 0.6))
    part(img, ell(w, h, (5, 5, 11, 11)), ramp("6a6c76", "a8acb6", "d4d8e0", "ffffff"), "1a1c22")
    dots(img, [(8, 6), (8, 7)], hexc("1a1c22"))
    line(img, [(13, 7), (13, 12)], BRASS[2])
    dots(img, [(13, 6), (13, 13)], BRASS[3])
    for x in (2, 17):
        dots(img, [(x, 18)], hexc("0a1210"))
    dots(img, [(2, 2), (3, 2)], hexc("8ab8a8"))
    return img


def pipe_valve():
    """Un tuyau coude, une vanne rouge, un jet de vapeur."""
    w, h = 24, 18
    img = canvas(w, h)
    pipe = ramp("3a2a24", "5e4438", "84604e", "aa8068")
    part(img, poly(w, h, [(0, 10), (16, 10), (16, 15), (0, 15)]), pipe, "1a100c")
    part(img, poly(w, h, [(12, 4), (17, 4), (17, 15), (12, 15)]), pipe, "1a100c")
    for x in (5, 11):
        part(img, poly(w, h, [(x, 9), (x + 1, 9), (x + 1, 16), (x, 16)]), pipe, "1a100c")
    part(img, ell(w, h, (9, 0, 20, 5)), ramp("7a1414", "b82424", "e04a3a", "ff8a7a"), "3a0808")
    dots(img, [(14, 2), (15, 2)], hexc("3a0808"))
    for s, (x, y) in enumerate(((19, 8), (21, 7), (22, 9), (23, 6))):
        dots(img, [(x, y)], hexc("e8eef8", 210 - s * 40))
    dots(img, [(1, 11), (13, 5)], hexc("d8b098"))
    return img


def boiler():
    """La chaudiere : ventre de fonte, porte du foyer ouverte sur le feu, cheminee."""
    w, h = 20, 26
    img = canvas(w, h)
    part(img, poly(w, h, [(12, 0), (16, 0), (16, 8), (12, 8)]), IRON[1:], "08060a")
    part(img, ell(w, h, (1, 5, 18, 24)), [IRON[1], IRON[2], IRON[3], IRON[4]], "08060a")
    shade(img, ell(w, h, (5, 12, 14, 20)), ramp("c03a10", "f06a1a", "ffa83a", "fff0a0"), light=(0, 0.8), edge_dark=False)
    line(img, [(5, 13), (14, 13)], hexc("120c0c"))
    for x in (7, 10, 13):
        dots(img, [(x, 9)], IRON[4])
    for x in (3, 15):
        dots(img, [(x, 24), (x, 25)], hexc("08060a"))
    dots(img, [(5, 8), (4, 10)], hexc("8a7a78"))
    return img


def jeudi():
    tiles("jeudi", "paradoxal", [concrete_floor(v) for v in range(4)], tread_top(), shutter_face())
    tiles("jeudi", "profond", [furnace_floor(v) for v in range(4)], ember_top(), hot_brick_face())
    for name, make in {"etoile": golden_ticket, "lune": exit_sign, "horloge": red_light, "bulle": anger_bubble,
                       "barriere": stanchion, "tampon": rubber_stamp, "tickets": ticket_machine}.items():
        save(make(), "decor", "jeudi", "paradoxal", f"{name}.png")
    for name, make in {"bougie": ember_heap, "champignon": pressure_cooker, "cristal": safe_box,
                       "tuyau": pipe_valve, "chaudiere": boiler}.items():
        save(make(), "decor", "jeudi", "profond", f"{name}.png")
    save(closed_gate(), "decor", "jeudi", "porte_close.png")


# --- Vendredi : la Montagne de cartons (paradoxal) -------------------------------------------

OAK = [ramp("8a6440", "a47c52", "ba9264", "d0a87a"), ramp("94704a", "ae885c", "c49e70", "d8b486"),
       ramp("84603c", "9c764e", "b28c60", "c8a274")]
TAPE = [hexc("a8783a"), hexc("c8964e"), hexc("dcae66"), hexc("f0cc8a")]


def tape_strip(img, pts_fn):
    for x, y in pts_fn():
        put(img, x, y, TAPE[2] if (x + y) % 7 else TAPE[3])


def oak_floor(variant):
    """Parquet clair de demenagement, lames longues ; variantes : ruban adhesif, croix de ruban,
    etiquette FRAGILE tombee."""
    img = tile()

    def px(x, y):
        row, ly = y // 10, y % 10
        off = (row * 23) % TILE
        tones = OAK[row % 3]
        lx = (x + off) % TILE
        if ly == 0 or lx == 0:
            return hexc("5a3e24")
        if ly == 1:
            return tones[3]
        grain = math.sin(y * 2.1 + _value(x, y, 201 + row, 2) * 5) * 0.1
        return band(tones[:3], 0.55 + grain + tnoise(x, y, 203) * 0.2, x, y, soft=0.12)
    each(img, px)
    if variant == 1:  # un ruban adhesif colle de travers
        def strip():
            for i in range(30):
                for k in range(3):
                    yield 10 + i, 16 + i // 3 + k
        tape_strip(img, strip)
    elif variant == 2:  # croix de ruban (meuble a enlever)
        def cross():
            for i in range(22):
                for k in range(3):
                    yield 14 + i, 14 + i + k
                    yield 35 - i, 14 + i + k
        tape_strip(img, cross)
    elif variant == 3:  # etiquette FRAGILE tombee
        lab = canvas(14, 9)
        part(lab, poly(14, 9, [(0, 1), (13, 0), (13, 7), (1, 8)]), ramp("b8b0a0", "e0d8c8", "f4eee2", "ffffff"), "6a5a48")
        for x in range(2, 12):
            dots(lab, [(x, 2)], hexc("d03030"))
        dots(lab, [(3, 4), (4, 4), (6, 4), (8, 5), (9, 5), (10, 4), (3, 6)], hexc("d03030"))
        stamp(img, lab, 28, 31)
    return img


KRAFT_DARK = [hexc("3a2818"), hexc("46301e"), hexc("523a26"), hexc("5e442e")]


def box_tops():
    """Le dessus des piles de cartons, vu d'en haut, dans l'ombre : rabats et rubans."""
    img = tile()

    def px(x, y):
        lx, ly = x % 25, y % 25
        if lx == 0 or ly == 0:
            return hexc("1e140c")
        if lx == 1 or ly == 1:
            return KRAFT_DARK[3]
        if ly == 12:
            return hexc("2a1c10")  # jointure des rabats
        if 11 <= lx <= 13:
            return hexc("6a5034") if lx != 13 else hexc("5a422a")  # ruban
        return band(KRAFT_DARK[:3], 0.5 + tnoise(x, y, 211) * 0.4 - (0.12 if ly > 12 else 0), x, y, soft=0.25)
    return each(img, px)


KRAFT = [hexc("6a4a28"), hexc("8a6234"), hexc("a67a44"), hexc("c09458"), hexc("d4ac70")]


def box_face():
    """Cartons empiles : chaque carton modele, ruban au milieu, fleches HAUT et coins ecrases ; plus
    sombre vers le pied."""
    img = tile()

    def px(x, y):
        row, ly = y // 25, y % 25
        lx = (x + (13 if row else 0)) % 25
        idx = ((x + (13 if row else 0)) // 25 + row) % 2
        if lx == 0 or ly == 0:
            return hexc("2a1c10")
        if lx == 1 or ly == 1:
            return KRAFT[4]
        if lx == 24 or ly == 24:
            return KRAFT[0]
        if 11 <= lx <= 13 and ly < 12:
            return TAPE[2] if lx < 13 else TAPE[1]
        v = 0.55 + tnoise(x, y, 213) * 0.25 - 0.18 * ly / 25 - 0.1 * idx
        return band(KRAFT[1:4], v, x, y, soft=0.15)
    each(img, px)
    for ox in (4, 30):  # fleches HAUT au feutre
        oy = 15 if ox == 4 else 40
        dots(img, [(ox + 2, oy - 4), (ox + 1, oy - 3), (ox + 3, oy - 3), (ox + 2, oy - 2), (ox + 2, oy - 1), (ox + 2, oy)], hexc("3a2a1a"))
    return darken_down(img, 0.3)


def tea_cup():
    """Tasse de the chaud (soigne) : tasse blanche, the ambre, soucoupe, vapeur qui ondule."""
    w, h = 20, 20
    img = canvas(w, h)
    porcelain = ramp("9a98a8", "c8c6d4", "e8e6f0", "ffffff")
    part(img, ell(w, h, (1, 15, 18, 19)), porcelain, "4a4858")
    part(img, ell(w, h, (13, 9, 18, 14)), porcelain, "4a4858")
    clear_ring(img, 15.5, 11.5, 1.2)
    part(img, mask_wh(w, h, polys=[[(3, 9), (15, 9), (14, 15), (4, 15)]], ellipses=[(3, 7, 15, 11)]), porcelain, "4a4858")
    shade(img, ell(w, h, (4, 8, 14, 10)), ramp("8a4a1a", "b0682a", "d08a3e", "eeb060"), edge_dark=False)
    line(img, [(5, 13), (13, 13)], hexc("d86a6a"))
    for s, pts in enumerate((((7, 6), (6, 4), (7, 2), (6, 0)), ((11, 6), (12, 4), (11, 2)))):
        line(img, pts, hexc("f4f0ff", 170 - s * 40))
    dots(img, [(4, 10), (4, 12)], hexc("ffffff"))
    return img


def flashlight():
    """Le phare de poche (guide) : une lampe torche debout, la lentille allumee."""
    w, h = 14, 24
    img = canvas(w, h)
    body = ramp("1a3a6a", "2a5a9a", "4a7ec4", "86b0e8")
    part(img, poly(w, h, [(4, 8), (9, 8), (9, 23), (4, 23)]), body, "0a1a34")
    part(img, poly(w, h, [(2, 3), (11, 3), (10, 9), (3, 9)]), ramp("4a4e5a", "8a90a0", "c4cad6", "f4f8ff"), "1e2028")
    shade(img, ell(w, h, (2, 0, 11, 5)), ramp("e8b040", "ffd870", "fff2b0", "ffffff"), edge_dark=False)
    for y in (12, 15, 18):
        line(img, [(5, y), (8, y)], body[0])
    dots(img, [(7, 10), (7, 11)], hexc("e04a3a"))
    dots(img, [(5, 9), (5, 13)], hexc("c8e0ff"))
    return img


def cozy_bench():
    """Le banc (pause) : un petit banc de bois avec un coussin moelleux pour souffler."""
    w, h = 24, 16
    img = canvas(w, h)
    wood = ramp("5a3a20", "84582e", "a8763e", "c89656")
    for x0 in (2, 19):
        part(img, poly(w, h, [(x0, 8), (x0 + 2, 8), (x0 + 2, 15), (x0, 15)]), wood, "2a180a")
    part(img, poly(w, h, [(0, 7), (23, 7), (23, 10), (0, 10)]), wood, "2a180a")
    part(img, ell(w, h, (3, 2, 14, 9)), ramp("8a3a4a", "b85a6a", "dc7e8a", "f8aab2"), "4a1a24")
    dots(img, [(8, 5)], hexc("6a2a3a"))
    dots(img, [(5, 3), (6, 3)], hexc("ffd8dc"))
    return img


def sigh_bubble():
    """Bulle de soupir : bulle gris-bleu, trois points de suspension dedans."""
    def dots3(img):
        for x in (5, 8, 11):
            dots(img, [(x, 9), (x + 1, 9), (x, 10), (x + 1, 10)], hexc("6a7a9a", 220))
    return bubble(18, 18, ["c8d4e8", "b0bcd4", "dce4f0"], "c8d0e0", dots3)


def cardboard_box():
    """Un carton de demenagement (se pousse) : rabats, ruban, une fleche au feutre."""
    w, h = 22, 20
    img = canvas(w, h)
    part(img, poly(w, h, [(1, 6), (20, 6), (20, 19), (1, 19)]), [KRAFT[0], KRAFT[1], KRAFT[2], KRAFT[3]], "2a1c10")
    part(img, poly(w, h, [(1, 6), (10, 6), (8, 1), (0, 2)]), [KRAFT[1], KRAFT[2], KRAFT[3], KRAFT[4]], "2a1c10")
    part(img, poly(w, h, [(11, 6), (20, 6), (22, 3), (13, 1)]), [KRAFT[1], KRAFT[2], KRAFT[3], KRAFT[4]], "2a1c10")
    for y in range(7, 13):
        dots(img, [(10, y), (11, y)], TAPE[2])
    dots(img, [(15, 11), (14, 12), (16, 12), (15, 13), (15, 14), (15, 15)], hexc("3a2a1a"))
    dots(img, [(2, 7), (3, 7)], KRAFT[4])
    return img


def drawstring_sack():
    """Un gros sac de toile bourre, ferme par un cordon."""
    w, h = 20, 22
    img = canvas(w, h)
    cloth = ramp("3a4a5a", "56687a", "74889a", "98acbc")
    part(img, mask_wh(w, h, polys=[[(7, 2), (12, 2), (14, 8), (6, 8)]], ellipses=[(1, 6, 18, 21)]), cloth, "1a2228")
    line(img, [(6, 8), (13, 8)], hexc("c8a070"))
    line(img, [(13, 8), (15, 11), (14, 13)], hexc("c8a070"))
    line(img, [(5, 12), (8, 16)], cloth[0])
    line(img, [(12, 13), (14, 18)], cloth[0])
    dots(img, [(4, 9), (3, 11)], hexc("c8d8e4"))
    return img


def box_pile():
    """Une pile de cartons qui penche dangereusement."""
    w, h = 22, 28
    img = canvas(w, h)
    k = [KRAFT[0], KRAFT[1], KRAFT[2], KRAFT[3]]
    part(img, poly(w, h, [(1, 18), (20, 18), (20, 27), (1, 27)]), k, "2a1c10")
    part(img, poly(w, h, [(3, 10), (19, 9), (20, 18), (4, 19)]), k, "2a1c10")
    part(img, poly(w, h, [(6, 2), (18, 1), (19, 9), (7, 10)]), k, "2a1c10")
    for x0, y0, y1 in ((10, 18, 22), (11, 10, 13), (12, 2, 5)):
        line(img, [(x0, y0), (x0, y1)], TAPE[2])
        line(img, [(x0 + 1, y0), (x0 + 1, y1)], TAPE[2])
    dots(img, [(2, 19), (4, 11), (7, 3)], KRAFT[4])
    return img


# --- Vendredi : les Mines de plomb (profond) -------------------------------------------------

ROCK = [ramp("1e2028", "2a2c36", "363a46", "444a58"), ramp("22222a", "2e2e38", "3a3a48", "4a4a5a"),
        ramp("1c1e24", "282a32", "343844", "424654")]
GRAVEL_CELLS = seeds(25, 221)


def mine_floor(variant):
    """Sol de galerie : graviers et cailloux plats, gris de plomb ; variantes : rails, eclats de
    plomb, flaque."""
    img = tile()

    dirt = [hexc("16171c"), hexc("1c1d24"), hexc("22242c"), hexc("282a34")]

    def px(x, y):
        _, _, i = voronoi(x, y, GRAVEL_CELLS)
        c, _, edge = stones(x, y, GRAVEL_CELLS, ROCK[i % 3], hexc("121318"), flat=-0.05)
        if i % 3 == 0 or edge < 2.5:
            return band(dirt, 0.5 + tnoise(x, y, 225, 2.0) * 0.6, x, y, 0.4)
        return c
    each(img, px)
    if variant == 1:  # rails d'un bord a l'autre, sur leurs traverses
        wood = [hexc("2a1c12"), hexc("3e2a1a"), hexc("523a24")]
        for x0 in range(2, TILE, 12):
            for x in range(x0, x0 + 5):
                for y in range(14, 37):
                    put(img, x, y, wood[1] if x - x0 not in (0, 4) else wood[0])
                put(img, x, 14, wood[2])
        for ry in (18, 31):
            for x in range(TILE):
                put(img, x, ry - 1, hexc("9aa0b0"))
                put(img, x, ry, hexc("6a7080"))
                put(img, x, ry + 1, hexc("2a2c34"))
    elif variant == 2:  # eclats de plomb, brillants
        for sx, sy in ((12, 15), (35, 31), (24, 38)):
            dots(img, [(sx, sy), (sx + 1, sy), (sx, sy + 1)], hexc("8a94b0"))
            dots(img, [(sx, sy)], hexc("d8e0f4"))
            dots(img, [(sx + 1, sy + 1)], hexc("3a4050"))
    elif variant == 3:  # flaque d'eau noire
        for y in range(TILE):
            for x in range(TILE):
                dx, dy = tdist(x, y, 24, 26)
                k = 1 - math.hypot(dx / 10, dy / 6) + tnoise(x, y, 223, 2.0) * 0.3
                if k > 0:
                    img.putpixel((x, y), band([hexc("0e1016"), hexc("161a24"), hexc("222838")], 0.3 + k, x, y, 0.3))
                    if 0.05 < k < 0.15 and y < 26:
                        img.putpixel((x, y), hexc("5a6478"))
    return img


ROCK_CELLS = seeds(9, 231)


def rock_top():
    """Le vide autour : la roche massive, dans le noir."""
    img = tile()
    dark = [ramp("0c0d10", "121318", "181a20", "1e2028")]
    return each(img, lambda x, y: stones(x, y, ROCK_CELLS, dark[0], hexc("060608"), light_shift=2)[0])


def timber_face():
    """Paroi de roche etayee : roche modelee, poteau et chapeau de bois brut."""
    img = tile()
    cells = seeds(12, 233)
    wood = [hexc("2a1a0e"), hexc("3e2814"), hexc("56381e"), hexc("6e4a2a")]

    def px(x, y):
        c = stones(x, y, cells, ROCK[0], hexc("0c0d10"), light_shift=1.5)[0]
        if y < 7:  # chapeau (poutre horizontale)
            if y == 0:
                return wood[3]
            if y == 6:
                return hexc("140c06")
            return band(wood, 0.6 - y * 0.06 + math.sin(x * 0.7 + y) * 0.08, x, y, 0.2)
        if 20 <= x <= 27:  # poteau
            if x == 20:
                return wood[3]
            if x == 27:
                return hexc("140c06")
            return band(wood, 0.55 - (x - 20) * 0.05 + math.sin(y * 0.6 + x) * 0.08, x, y, 0.2)
        return c
    each(img, px)
    for x, y in ((21, 8), (26, 8)):
        put(img, x, y, hexc("8a8e9a"))  # clous
    return darken_down(img, 0.3)


def miner_lamp():
    """La lampe de mineur (s'allume) : lampe-tempete, verre chaud, anse de fer."""
    w, h = 14, 22
    img = canvas(w, h)
    iron = ramp("1a1c22", "2e3038", "464a56", "626876")
    line(img, [(3, 5), (3, 2), (5, 0), (8, 0), (10, 2), (10, 5)], hexc("626876"))
    part(img, poly(w, h, [(3, 4), (10, 4), (11, 7), (2, 7)]), iron, "0a0a0e")
    part(img, ell(w, h, (2, 6, 11, 18)), ramp("c88a3a", "f0b858", "ffe08e", "fff8d8"), "4a3414")
    for x in (2, 11):
        line(img, [(x, 7), (x, 17)], iron[1])
    dots(img, [(6, 11), (7, 11), (6, 12), (7, 12), (6, 10)], hexc("ffffff"))
    part(img, poly(w, h, [(1, 17), (12, 17), (12, 20), (1, 20)]), iron, "0a0a0e")
    dots(img, [(4, 8), (4, 9)], hexc("ffffff"))
    return img


def moving_sack():
    """Le sac qui bouge (lance un combat) : un sac de jute bossele, deux yeux dans l'ouverture."""
    w, h = 22, 20
    img = canvas(w, h)
    jute = ramp("4a3a24", "6e5634", "927448", "b49460")
    part(img, mask_wh(w, h, polys=[[(7, 1), (14, 1), (16, 7), (5, 7)]], ellipses=[(2, 5, 19, 19)]), jute, "1e160a")
    shade(img, ell(w, h, (7, 2, 14, 6)), ramp("0a0806", "120e0a", "1a140e", "221a12"), edge_dark=False)
    dots(img, [(9, 4), (12, 4)], hexc("f0e070"))
    line(img, [(5, 8), (16, 8)], hexc("2a1e10"))
    for y in range(10, 18, 3):
        line(img, [(5, y), (16, y)], jute[1])
    for x, y in ((0, 9), (0, 12), (21, 10), (21, 13)):
        dots(img, [(x, y)], hexc("c8b890"))
    dots(img, [(4, 10), (5, 8)], jute[3])
    return img


def ore_vein():
    """Le filon (contient un objet) : un rocher, des cubes de galene qui brillent dedans."""
    w, h = 22, 18
    img = canvas(w, h)
    part(img, mask_wh(w, h, ellipses=[(1, 4, 14, 17), (7, 1, 21, 17)]), ROCK[0], "08080c")
    galena = ramp("3a4256", "6a7690", "a2aec8", "e4ecff")
    for x0, y0, s in ((5, 8, 4), (12, 5, 5), (14, 11, 3)):
        part(img, poly(w, h, [(x0, y0), (x0 + s, y0), (x0 + s, y0 + s), (x0, y0 + s)]), galena, "1a1e2a")
        dots(img, [(x0, y0)], hexc("ffffff"))
    return img


def mine_cart():
    """Le wagonnet (se pousse) : caisse de fer rivetee, pleine de minerai, sur ses roues."""
    w, h = 24, 18
    img = canvas(w, h)
    iron = ramp("2a2420", "4a3e36", "6a5a4e", "8a786a")
    for box in ((1, 4, 7, 9), (6, 2, 13, 8), (12, 3, 19, 9), (17, 5, 22, 9)):
        part(img, ell(w, h, box), ROCK[0], "08080c")
    dots(img, [(9, 4), (15, 5)], hexc("a2aec8"))
    part(img, poly(w, h, [(0, 7), (23, 7), (21, 14), (2, 14)]), iron, "120e0c")
    for x in (3, 8, 13, 18):
        dots(img, [(x, 9), (x, 12)], iron[3])
    for cx in (6, 17):
        part(img, ell(w, h, (cx - 3, 12, cx + 3, 17)), ramp("16161a", "26262c", "3a3a42", "54545e"), "08080a")
        dots(img, [(cx, 14)], hexc("8a8e9a"))
    dots(img, [(1, 8), (2, 8)], iron[3])
    return img


def pickaxe():
    """Une pioche abandonnee, plantee de biais."""
    w, h = 22, 22
    img = canvas(w, h)
    line(img, [(4, 20), (15, 5)], hexc("2a1a0e"), 3)
    line(img, [(4, 20), (15, 5)], hexc("8a5e36"))
    line(img, [(5, 20), (16, 5)], hexc("6a4428"))
    head = ramp("2a2e38", "4a505e", "727a8a", "a8b0c0")
    part(img, poly(w, h, [(7, 2), (12, 3), (17, 4), (21, 9), (16, 6), (12, 6), (8, 5), (3, 7)]), head, "0e1016")
    dots(img, [(8, 3), (12, 4)], hexc("e0e8f4"))
    return img


def rubble():
    """Un tas de gravats : blocs de roche et poussiere."""
    w, h = 24, 14
    img = canvas(w, h)
    for box, tones in (((1, 6, 9, 13), ROCK[1]), ((6, 2, 15, 12), ROCK[0]), ((13, 5, 22, 13), ROCK[2]),
                       ((9, 8, 15, 13), ROCK[1])):
        part(img, ell(w, h, box), tones, "08080c")
    for x, y in ((0, 13), (2, 12), (22, 12), (23, 13), (17, 4)):
        dots(img, [(x, y)], hexc("3a3e4a"))
    dots(img, [(8, 3), (9, 3)], hexc("6a7080"))
    return img


def vendredi():
    tiles("vendredi", "paradoxal", [oak_floor(v) for v in range(4)], box_tops(), box_face())
    tiles("vendredi", "profond", [mine_floor(v) for v in range(4)], rock_top(), timber_face())
    for name, make in {"etoile": tea_cup, "lune": flashlight, "horloge": cozy_bench, "bulle": sigh_bubble,
                       "carton": cardboard_box, "sac": drawstring_sack, "pile": box_pile}.items():
        save(make(), "decor", "vendredi", "paradoxal", f"{name}.png")
    for name, make in {"bougie": miner_lamp, "champignon": moving_sack, "cristal": ore_vein,
                       "wagonnet": mine_cart, "pioche": pickaxe, "gravats": rubble}.items():
        save(make(), "decor", "vendredi", "profond", f"{name}.png")


# --- Samedi : la Salle de bal vide (paradoxal) -----------------------------------------------

MARBLE_W = ramp("a8aabe", "c6c8d8", "dfe0ec", "f6f6fc")
MARBLE_B = ramp("2e3450", "3c4464", "4c5678", "5e6a8e")


def vein(x, y, seed):
    """Veine de marbre : la ou un bruit doux passe pres de zero."""
    return abs(tnoise(x, y, seed, 2.0)) < 0.022


def marble_floor(variant):
    """Marbre en damier blanc et bleu nuit, veines fines, biseau ; variantes : une veine doree, une
    etoile doree incrustee, un rectangle de clair de lune."""
    img = tile()

    def px(x, y):
        lx, ly = x % 25, y % 25
        tones = MARBLE_W if ((x // 25) + (y // 25)) % 2 == 0 else MARBLE_B
        e = bevel(lx, ly, 25, 25)
        if e == "seam":
            return hexc("1e2234")
        if e == "hi":
            return tones[3]
        if e == "lo":
            return tones[0]
        if vein(x, y, 241):
            return tones[0] if tones is MARBLE_W else tones[3]
        v = 0.55 + tnoise(x, y, 245) * 0.3
        return band(tones[1:], v, x, y, soft=0.1)
    each(img, px)
    if variant == 1:  # un filet d'or incruste qui serpente
        for x in range(TILE):
            y = round(25 + 8 * math.sin(x / TILE * math.tau) + 3 * math.sin(x / TILE * math.tau * 2 + 1))
            put(img, x, y + 1, hexc("6a4a18"))
            put(img, x, y, hexc("e8c060") if x % 6 else hexc("fff0b0"))
    elif variant == 2:  # etoile doree incrustee au croisement des dalles
        pts = []
        for k in range(8):
            a = -math.pi / 2 + k * math.pi / 4
            r = 7 if k % 2 == 0 else 2.5
            pts.append((25 + math.cos(a) * r, 25 + math.sin(a) * r))
        m = poly(TILE, TILE, pts)
        for y in range(TILE):
            for x in range(TILE):
                if m.getpixel((x, y)):
                    img.putpixel((x, y), hexc("f0d070") if x + y < 50 else hexc("b88a30"))
        put(img, 25, 25, hexc("fff8d0"))
    elif variant == 3:  # la lune passe par une fenetre : un rectangle clair a croisillons
        for y in range(12, 40):
            for x in range(14 + (y - 12) // 3, 32 + (y - 12) // 3):
                lx = x - (14 + (y - 12) // 3)
                if lx in (8, 9) or y in (25, 26):
                    continue
                if dither(x, y) < 0.55:
                    r, g, b, a = img.getpixel((x, y))
                    img.putpixel((x, y), (min(255, r + 24), min(255, g + 28), min(255, b + 40), a))
    return img


def ballroom_top():
    """Le vide autour : nuit bleue, poussiere qui flotte dans le clair de lune."""
    img = tile()
    tones = [hexc("0e1226"), hexc("12172e"), hexc("171d36"), hexc("1d2440")]
    each(img, lambda x, y: band(tones, 0.5 + tnoise(x, y, 251) * 0.5, x, y, soft=0.5))
    for sx, sy in ((8, 7), (33, 18), (21, 37), (44, 44), (13, 26)):
        put(img, sx, sy, hexc("8a9ac8"))
    put(img, 33, 18, hexc("dce4ff"))
    return img


def window_face():
    """Colonne d'ivoire et haute fenetre en arc ou entre la lune ; plus sombre vers le pied."""
    img = tile()
    ivory = [hexc("8a8478"), hexc("b0aa9a"), hexc("d0cab8"), hexc("ece6d4")]
    pane = [hexc("1e2a5a"), hexc("2a3a74"), hexc("3a5090"), hexc("5a74b4"), hexc("9ab0e4")]

    def px(x, y):
        lx = x % 25
        if lx < 6:  # pilastre cannele
            if lx in (0, 5):
                return ivory[0]
            return ivory[3] if lx == 1 else (ivory[1] if lx == 3 else ivory[2])
        if y < 3:
            return ivory[3] if y == 0 else ivory[1]
        cx = 15
        top = 12 - math.sqrt(max(0.0, 64 - (lx - cx) ** 2)) * 0.9
        if 7 <= lx <= 23 and top <= y <= 44:
            if lx in (7, 23) or y == 44 or abs(y - top) < 1:
                return ivory[2]
            if lx == 15 or y in (24,):
                return hexc("3a3a4a")  # croisillons
            moon = max(0.0, 1 - math.hypot(lx - 11, y - 16) / 10)
            return band(pane, 0.35 + moon * 0.7 - y * 0.004, x, y, 0.2)
        return band([hexc("2a2838"), hexc("34324a"), hexc("3e3c56")], 0.5 + tnoise(x, y, 253) * 0.4, x, y, 0.3)
    each(img, px)
    return darken_down(img, 0.3)


def letter():
    """Lettre recue (soigne) : enveloppe creme, cachet de cire rouge en coeur."""
    w, h = 22, 16
    img = canvas(w, h)
    paper = ramp("a89a80", "d0c4a8", "ece2ca", "fffaec")
    part(img, poly(w, h, [(1, 2), (20, 2), (20, 14), (1, 14)]), paper, "5a4c38")
    line(img, [(2, 3), (10, 9), (11, 9), (19, 3)], paper[0])
    line(img, [(2, 13), (8, 8)], paper[1])
    line(img, [(19, 13), (13, 8)], paper[1])
    for x, y in ((9, 9), (10, 9), (11, 9), (12, 9), (9, 10), (10, 10), (11, 10), (12, 10), (10, 11), (11, 11),
                 (9, 8), (12, 8)):
        dots(img, [(x, y)], hexc("c8283a"))
    dots(img, [(10, 9)], hexc("ff7a7a"))
    dots(img, [(2, 3), (3, 3)], hexc("ffffff"))
    return img


def lighthouse():
    """Le phare lointain (guide) : petit phare raye, la lanterne allumee qui balaie."""
    w, h = 22, 28
    img = canvas(w, h)
    for s, (x, y) in enumerate(((14, 4), (16, 3), (18, 3), (20, 2))):
        dots(img, [(x, y), (x, y + 1)], hexc("fff0b0", 200 - s * 40))
    part(img, poly(w, h, [(7, 9), (13, 9), (15, 25), (5, 25)]), ramp("8a8a9a", "c4c4d0", "e6e6ee", "ffffff"), "2a2a3a")
    for y0 in (12, 18):
        for y in range(y0, y0 + 3):
            for x in range(4, 17):
                c = img.getpixel((x, y))
                if c[3] > 200 and c != hexc("2a2a3a"):
                    img.putpixel((x, y), hexc("c83a3a") if x < 11 else hexc("8a2028"))
    part(img, poly(w, h, [(7, 4), (13, 4), (13, 9), (7, 9)]), ramp("c88a3a", "f0b858", "ffe08e", "fff8d8"), "4a3414")
    part(img, poly(w, h, [(6, 2), (10, 0), (14, 2)]), ramp("4a1a1a", "7a2a2a", "a83a3a", "c85a5a"), "2a0a0a")
    part(img, poly(w, h, [(3, 25), (17, 25), (18, 27), (2, 27)]), ramp("2a2e3a", "40465a", "565e76", "707a94"), "10121a")
    dots(img, [(8, 10), (7, 14)], hexc("ffffff"))
    return img


def music_box():
    """La boite a musique (pause) : coffret ouvert, une danseuse minuscule, la manivelle."""
    w, h = 22, 22
    img = canvas(w, h)
    wood = ramp("4a2418", "743a26", "9a5434", "be744a")
    part(img, poly(w, h, [(2, 1), (19, 1), (19, 8), (2, 8)]), wood, "200c06")
    shade(img, poly(w, h, [(4, 3), (17, 3), (17, 7), (4, 7)]), ramp("4a5288", "6a74aa", "98a2cc", "c8d0ee"))
    part(img, poly(w, h, [(1, 13), (20, 13), (20, 21), (1, 21)]), wood, "200c06")
    dots(img, [(x, 16) for x in range(3, 19, 2)], hexc("e0b85a"))
    dancer = ramp("b85a7a", "e07aa0", "f8a8c4", "ffd8e8")
    part(img, poly(w, h, [(8, 12), (13, 12), (11, 9), (10, 9)]), dancer, "5a1a34")
    dots(img, [(10, 7), (10, 8), (10, 6)], hexc("ffd8c0"))
    dots(img, [(9, 8), (11, 7), (12, 6)], hexc("ffd8c0"))
    line(img, [(20, 17), (21, 17), (21, 15)], hexc("c8a050"))
    dots(img, [(3, 14), (4, 14)], wood[3])
    return img


def memory_bubble():
    """Bulle-souvenir : une petite maison eclairee flotte dedans."""
    def house(img):
        part(img, poly(18, 18, [(5, 9), (12, 9), (12, 13), (5, 13)]), ramp("6a4a3a", "8a6450", "aa806a", "c8a088"), None)
        part(img, poly(18, 18, [(4, 9), (8.5, 5), (13, 9)]), ramp("6a2a2a", "8a3a3a", "aa5050", "c86a6a"), None)
        dots(img, [(7, 10), (10, 10), (7, 11), (10, 11)], hexc("ffe08a"))
    return bubble(18, 18, ["d0d8ff", "e8d0ff", "c8e8ff"], "d0d8f4", house)


def ball_chair():
    """Une chaise de bal doree, coussin de velours rouge (se pousse)."""
    w, h = 16, 24
    img = canvas(w, h)
    gold = ramp("7a5010", "b88424", "e8b84a", "fff0a0")
    for x0 in (2, 12):
        part(img, poly(w, h, [(x0, 1), (x0 + 1, 1), (x0 + 1, 23), (x0, 23)]), gold, "3a2408")
    for y in (3, 6, 9):
        line(img, [(3, y), (12, y)], gold[2])
    part(img, poly(w, h, [(1, 12), (14, 12), (15, 15), (0, 15)]), ramp("6a1424", "9a2234", "c8384a", "ea6a78"), "3a0812")
    line(img, [(4, 16), (4, 23)], gold[1])
    line(img, [(11, 16), (11, 23)], gold[1])
    dots(img, [(2, 1), (3, 13)], hexc("fff8d0"))
    return img


def light_garland():
    """Une guirlande lumineuse qui flotte, en arc, ampoules de toutes les couleurs."""
    w, h = 26, 12
    img = canvas(w, h)
    pts = [(x, 2 + 6 * math.sin(x / (w - 1) * math.pi)) for x in range(w)]
    line(img, pts, hexc("2a3a2a"))
    for i, x in enumerate(range(2, w - 1, 4)):
        y = round(2 + 6 * math.sin(x / (w - 1) * math.pi)) + 1
        c = ["ffd070", "ff8a8a", "8ad0ff", "a8ff9a", "ffa8e8", "ffd070"][i % 6]
        dots(img, [(x, y), (x, y + 1), (x + 1, y + 1)], hexc(c))
        dots(img, [(x, y)], hexc("ffffff"))
        dots(img, [(x - 1, y + 1), (x + 2, y + 1), (x, y + 3)], hexc(c, 90))
    return img


def lone_glass():
    """Une coupe de champagne oubliee, a moitie pleine."""
    w, h = 12, 22
    img = canvas(w, h)
    glass = canvas(w, h)
    shade(glass, poly(w, h, [(1, 1), (10, 1), (7, 9), (4, 9)]), ramp("8a9ac0", "b4c4e0", "d8e4f4", "ffffff"))
    fade(glass, 0.55)
    img.alpha_composite(glass)
    shade(img, poly(w, h, [(3, 5), (8, 5), (7, 8), (4, 8)]), ramp("c8962a", "e8b840", "f8d870", "fff0b0"), edge_dark=False)
    line(img, [(1, 1), (10, 1)], hexc("e8f0ff"))
    line(img, [(5, 9), (5, 18)], hexc("c8d4f0"))
    line(img, [(6, 9), (6, 18)], hexc("8a9ac0"))
    shade(img, ell(w, h, (2, 18, 9, 21)), ramp("8a9ac0", "b4c4e0", "d8e4f4", "ffffff"))
    dots(img, [(5, 4), (6, 7)], hexc("ffffff"))
    ink(img, hexc("3a4468", 200))
    return img


# --- Samedi : le Quai desert (profond) -------------------------------------------------------

PLANKS = [ramp("2e3442", "3c4454", "4c5566", "5e6878"), ramp("343846", "424858", "52596a", "646c7e"),
          ramp("2a303c", "38404e", "464f60", "586272")]


def dock_floor(variant):
    """Planches de ponton gris-bleu, l'eau noire entre elles, clous ; variantes : clous rouilles,
    planche usee plus claire, rouleau de cordage."""
    img = tile()

    def px(x, y):
        row, ly = y // 10, y % 10
        tones = PLANKS[row % 3]
        if variant == 2 and row == 2:
            tones = ramp("4a5262", "5e6678", "727c8e", "8892a4")
        if ly >= 8:
            return hexc("06080e") if ly == 9 else hexc("0e121c")  # l'eau entre les planches
        if ly == 0:
            return tones[3]
        grain = math.sin(y * 2.3 + _value(x, y, 261 + row, 2) * 5) * 0.1
        return band(tones[:3], 0.55 + grain + tnoise(x, y, 263) * 0.2 - ly * 0.03, x, y, 0.15)
    each(img, px)
    nail = hexc("8a7060") if variant == 1 else hexc("7a8090")
    for row in range(5):
        for nx in ((6, 44) if row % 2 else (20,)):
            put(img, nx, row * 10 + 3, nail)
            put(img, nx, row * 10 + 6, nail)
            if variant == 1:
                put(img, nx + 1, row * 10 + 4, hexc("6a3a20"))
    if variant == 3:  # rouleau de cordage
        rope = canvas(18, 13)
        hemp = ramp("6a5a3a", "8e7a52", "b4a070", "dcc898")
        for y in range(13):
            for x in range(18):
                d = math.hypot((x - 8.5) / 1.3, y - 6)
                ring = d % 2.4
                if d < 6.5 and ring > 0.7:
                    lit = (x - 8.5) + (y - 6) < 0
                    hemp_t = hemp[3] if lit and ring > 1.5 else (hemp[2] if lit or ring > 1.5 else hemp[1])
                    rope.putpixel((x, y), hemp_t if (x + y) % 3 else hemp[1])
        ink(rope, hexc("2a2214"))
        stamp(img, rope, 25, 25)
    return img


def black_water_top():
    """Le vide autour : eau noire et immobile, quelques rides qui accrochent la lumiere."""
    img = tile()
    tones = [hexc("05070c"), hexc("080b12"), hexc("0c1018"), hexc("10161f")]
    each(img, lambda x, y: band(tones, 0.45 + tnoise(x, y, 271) * 0.5 + 0.15 * math.sin(y * 0.75 + x * 0.06), x, y, 0.4))
    for sx, sy, n in ((6, 9, 6), (28, 21, 8), (12, 37, 5), (38, 43, 6), (40, 6, 4)):
        for i in range(n):
            put(img, sx + i, sy, hexc("2a3648") if 0 < i < n - 1 else hexc("1a2230"))
    return img


def pier_face():
    """Le bord du quai : poutre de rive, pilotis qui plongent dans l'eau noire, brume au ras de l'eau."""
    img = tile()
    wood = PLANKS[1]

    def px(x, y):
        if y < 6:  # poutre de rive
            if y == 0:
                return wood[3]
            if y == 5:
                return hexc("0a0c12")
            return band(wood[:3], 0.65 - y * 0.08 + math.sin(x * 0.5) * 0.06, x, y, 0.2)
        for cx in (12, 37):  # pilotis ronds
            dx = x - cx
            if abs(dx) <= 3:
                v = 0.55 - dx * 0.15
                c = band(ramp("1e1a1a", "2e2826", "403834", "524842"), v - y * 0.006, x, y, 0.15)
                if y > 30:  # mouille, plus sombre sous la ligne d'eau
                    c = band(ramp("0e0c0e", "16141a", "201e24", "2a2830"), v, x, y, 0.15)
                return c
        fog = max(0.0, 1 - abs(y - 30) / 8)
        v = 0.3 + fog * 0.6 + tnoise(x, y, 273) * 0.25 - (0.2 if y > 30 else 0)
        return band([hexc("06080e"), hexc("0c1018"), hexc("161c28"), hexc("242c3c"), hexc("3a4458")], v, x, y, 0.4)
    each(img, px)
    for x in range(TILE):
        if x % 6 < 4:
            put(img, x, 31, hexc("3a4458"))  # la ligne de l'eau
    return img


def floating_lantern():
    """La lanterne flottante (s'allume) : lanterne de papier posee sur l'eau, son reflet."""
    w, h = 16, 22
    img = canvas(w, h)
    part(img, ell(w, h, (2, 2, 13, 14)), ramp("c86a2a", "f0a040", "ffd070", "fff4c0"), "5a2a0a")
    for y in (5, 8, 11):
        line(img, [(4, y), (11, y)], hexc("d07a30"))
    part(img, poly(w, h, [(4, 13), (11, 13), (12, 15), (3, 15)]), ramp("2a1a10", "4a2e1a", "6a4428", "8a5a36"), "120a04")
    refl = canvas(w, h)
    for y in range(16, 22):
        for x in range(4, 12):
            if (x + y) % 2 == 0 and abs(x - 7.5) < 4 - (y - 16) * 0.5:
                refl.putpixel((x, y), hexc("ffb040", 150 - (y - 16) * 20))
    img.alpha_composite(refl)
    dots(img, [(5, 4), (4, 6)], hexc("ffffff"))
    return img


def ringing_phone():
    """Le telephone qui sonne (lance un combat) : vieux telephone a cadran, le combine qui saute."""
    w, h = 22, 20
    img = canvas(w, h)
    bake = ramp("1a1a22", "2a2a36", "3e3e4e", "565668")
    part(img, mask_wh(w, h, polys=[[(3, 9), (18, 9), (20, 19), (1, 19)]], ellipses=[(4, 6, 17, 13)]), bake, "08080c")
    shade(img, ell(w, h, (7, 10, 14, 17)), ramp("8a8a9a", "b8b8c8", "dcdce8", "f6f6ff"))
    for a in range(8):
        t = a / 8 * math.tau
        dots(img, [(10.5 + 2.5 * math.cos(t), 13.5 + 2.5 * math.sin(t))], hexc("2a2a36"))
    part(img, mask_wh(w, h, polys=[[(5, 3), (16, 3), (16, 5), (5, 5)]], ellipses=[(2, 1, 7, 6), (14, 1, 19, 6)]), bake, "08080c")
    for x, y in ((0, 2), (1, 0), (21, 2), (20, 0), (0, 6), (21, 6)):
        dots(img, [(x, y)], hexc("c8d4ff"))
    dots(img, [(4, 2), (5, 7)], bake[3])
    return img


def bottle():
    """La bouteille a la mer (contient un objet) : verre vert, bouchon, un message roule dedans."""
    w, h = 22, 12
    img = canvas(w, h)
    glass = canvas(w, h)
    part(glass, mask_wh(w, h, polys=[[(13, 4), (19, 4), (19, 8), (13, 8)]], ellipses=[(1, 1, 16, 11)]),
         ramp("1a4a3a", "2a6e54", "44967a", "7ac8a8"), "0a2018")
    fade(glass, 0.85)
    img.alpha_composite(glass)
    part(img, poly(w, h, [(4, 4), (12, 4), (12, 8), (4, 8)]), ramp("a89a80", "d0c4a8", "ece2ca", "fffaec"), None)
    line(img, [(6, 6), (10, 6)], hexc("8a7a60"))
    part(img, poly(w, h, [(19, 4), (21, 4), (21, 8), (19, 8)]), ramp("6a4a2a", "8e6a3e", "b08a54", "d0aa70"), "2a1a0a")
    dots(img, [(4, 2), (3, 3), (5, 2)], hexc("d8fff0"))
    return img


def life_buoy():
    """Une bouee de sauvetage rouge et blanche, sa corde."""
    w, h = 20, 20
    img = canvas(w, h)
    m = ell(w, h, (1, 1, 18, 18))
    for y in range(h):
        for x in range(w):
            if math.hypot(x - 9.5, y - 9.5) < 4.2:
                m.putpixel((x, y), 0)
    layer = canvas(w, h)
    shade(layer, m, ramp("8a1414", "c82828", "e84a3e", "ff8a7a"))
    for y in range(h):
        for x in range(w):
            if layer.getpixel((x, y))[3] and int((math.atan2(y - 9.5, x - 9.5) + math.pi) / (math.pi / 2) + 0.5) % 2:
                c = layer.getpixel((x, y))
                layer.putpixel((x, y), (min(255, c[0] + 40), min(255, c[1] + 160), min(255, c[2] + 150), 255))
    ink(layer, hexc("3a0a0a"))
    img.alpha_composite(layer)
    for a in range(0, 360, 90):
        t = math.radians(a + 45)
        dots(img, [(9.5 + 7.6 * math.cos(t), 9.5 + 7.6 * math.sin(t))], hexc("d8c8a0"))
    dots(img, [(4, 4), (5, 3)], hexc("ffffff"))
    return img


def harbor_bench():
    """Un banc vide face a l'eau : bois delave, pieds de fonte, personne."""
    w, h = 26, 16
    img = canvas(w, h)
    wood = ramp("3a4250", "505a6a", "687284", "848ea0")
    iron = ramp("0e1016", "181c24", "242a34", "323a46")
    for x0 in (3, 20):
        part(img, poly(w, h, [(x0, 3), (x0 + 2, 3), (x0 + 2, 15), (x0, 15)]), iron, "06080a")
    for y in (1, 4):
        part(img, poly(w, h, [(1, y), (24, y), (24, y + 1), (1, y + 1)]), wood, "141820")
    part(img, poly(w, h, [(1, 9), (24, 9), (25, 11), (0, 11)]), wood, "141820")
    dots(img, [(2, 1), (3, 9)], hexc("b8c4d4"))
    return img


def dark_lamppost():
    """Le lampadaire eteint : fonte noire, verre sombre, plus aucune lumiere."""
    w, h = 14, 30
    img = canvas(w, h)
    iron = ramp("10141a", "1c222a", "2a323c", "3a4450")
    part(img, poly(w, h, [(6, 9), (8, 9), (8, 26), (6, 26)]), iron, "04060a")
    part(img, poly(w, h, [(3, 26), (11, 26), (12, 29), (2, 29)]), iron, "04060a")
    part(img, poly(w, h, [(3, 1), (11, 1), (12, 3), (2, 3)]), iron, "04060a")
    part(img, poly(w, h, [(3, 3), (11, 3), (10, 9), (4, 9)]), ramp("1a2230", "242e40", "303c52", "3e4c66"), "04060a")
    line(img, [(7, 3), (7, 8)], hexc("10141a"))
    dots(img, [(5, 4), (5, 5)], hexc("5a6a88"))
    return img


def samedi():
    tiles("samedi", "paradoxal", [marble_floor(v) for v in range(4)], ballroom_top(), window_face())
    tiles("samedi", "profond", [dock_floor(v) for v in range(4)], black_water_top(), pier_face())
    for name, make in {"etoile": letter, "lune": lighthouse, "horloge": music_box, "bulle": memory_bubble,
                       "chaise": ball_chair, "guirlande": light_garland, "verre": lone_glass}.items():
        save(make(), "decor", "samedi", "paradoxal", f"{name}.png")
    for name, make in {"bougie": floating_lantern, "champignon": ringing_phone, "cristal": bottle,
                       "bouee": life_buoy, "banc_vide": harbor_bench, "lampadaire_eteint": dark_lamppost}.items():
        save(make(), "decor", "samedi", "profond", f"{name}.png")


# --- Dimanche : le Crepuscule sans fin (paradoxal) -------------------------------------------

DUSK_WARM = ramp("7a3a4a", "9e4e5a", "c26a62", "e09272")
DUSK_COOL = ramp("3e2e5a", "523a74", "6a4c8e", "8a66aa")
DUSK_SKY = [hexc("cc7e6a"), hexc("b86a68"), hexc("a05a6c"), hexc("884e78"), hexc("704686"), hexc("5c3e84")]


def dusk_floor(variant):
    """Dalles de verre teinte : chaque dalle passe de l'orange au violet, comme le ciel ; variantes :
    une longue ombre, le soleil couchant qui s'y reflete, une premiere etoile."""
    img = tile()

    def px(x, y):
        e = bevel(x, y, TILE, TILE)
        if e == "seam":
            return hexc("1e1424")
        if e == "hi":
            return hexc("f0b088")
        if e == "lo":
            return DUSK_COOL[0]
        t = (x + y) / 98 * 0.85 + tnoise(x, y, 281) * 0.2
        sheen = max(0.0, 1 - abs((x - y) % TILE - 12) / 2.5)
        if sheen > 0.3:
            return DUSK_WARM[3] if t < 0.5 else DUSK_COOL[3]
        return band(DUSK_SKY, t, x, y, 0.2)
    each(img, px)
    if variant == 1:  # une longue ombre en travers (quelqu'un, ou personne)
        m = poly(TILE, TILE, [(6, 44), (9, 41), (40, 10), (43, 9), (44, 12), (12, 46)])
        for y in range(TILE):
            for x in range(TILE):
                if m.getpixel((x, y)):
                    r, g, b, a = img.getpixel((x, y))
                    img.putpixel((x, y), (r * 6 // 10, g * 5 // 10, b * 7 // 10, a))
        for x, y in ((41, 7), (42, 7), (43, 8), (40, 8)):
            r, g, b, a = img.getpixel((x, y))
            img.putpixel((x, y), (r * 6 // 10, g * 5 // 10, b * 7 // 10, a))
    elif variant == 2:  # le soleil couchant reflete : demi-disque raye
        for y in range(18, 32):
            for x in range(14, 37):
                d = math.hypot(x - 25, y - 31)
                if d < 11 and (y % 3 != 0 or y > 29):
                    img.putpixel((x, y), hexc("ffd08a") if d < 7 else hexc("f0a060"))
        for x in range(10, 41):
            img.putpixel((x, 32), hexc("ffe0b0"))
    elif variant == 3:  # premiere etoile
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (0, 2), (0, -2), (2, 0), (-2, 0)):
            put(img, 33 + dx, 16 + dy, hexc("fff4d0") if abs(dx) + abs(dy) < 2 else hexc("f0b8a0"))
    return img


def dusk_top():
    """Le vide autour : ciel du soir en longues bandes de nuages violets, une etoile ou deux."""
    img = tile()
    tones = [hexc("1e1430"), hexc("281a3a"), hexc("342046"), hexc("442852"), hexc("5a3256")]

    def px(x, y):
        streak = _value(x, y * 5, 291, 5) * 0.5 + math.sin((y + _value(x, y, 293, 2) * 6) * math.tau / 12.5) * 0.35
        return band(tones, 0.4 + streak * 0.5, x, y, 0.4)
    each(img, px)
    for sx, sy in ((11, 8), (37, 33)):
        put(img, sx, sy, hexc("ffe8d0"))
    return img


def tree_face():
    """Ciel couchant en bandes (violet en haut, orange a l'horizon), arbres noirs decoupes devant."""
    img = tile()
    sky = [hexc("3a2450"), hexc("5a2e5e"), hexc("8a3e5e"), hexc("c05a50"), hexc("e8884a"), hexc("ffb860")]

    def px(x, y):
        return band(sky, y / 46 + (dither(x, y) - 0.5) * 0.08, x, y)
    each(img, px)
    shade_t = hexc("120a14")
    canopy = [(10, 14, 9, 6), (18, 10, 7, 5), (40, 18, 8, 7), (46, 12, 6, 5), (32, 24, 5, 4)]
    for y in range(TILE):
        for x in range(TILE):
            hit = False
            for cx, cy, rx, ry in canopy:
                dx = (x - cx + TILE / 2) % TILE - TILE / 2
                if math.hypot(dx / rx, (y - cy) / ry) + _value(x, y, 295, 5) * 0.35 < 1:
                    hit = True
            if hit or (13 <= x <= 15 and y > 16) or (41 <= x <= 43 and y > 22) or y >= 44:
                img.putpixel((x, y), shade_t)
    for x, y in ((14, 18), (15, 22), (42, 26)):  # branches
        for i in range(4):
            put(img, x + i, y - i // 2, shade_t)
    for x in range(TILE):
        if img.getpixel((x, 43)) != shade_t:
            put(img, x, 43, hexc("ffd890"))  # la derniere ligne de lumiere
    return img


def last_ray():
    """Dernier rayon de soleil (soigne) : un eclat de soleil chaud pose au sol, qui rayonne."""
    w, h = 22, 22
    img = canvas(w, h)
    for k in range(8):
        a = k * math.pi / 4
        r0, r1 = 6.5, 10 if k % 2 == 0 else 8.5
        line(img, [(10.5 + math.cos(a) * r0, 10.5 + math.sin(a) * r0), (10.5 + math.cos(a) * r1, 10.5 + math.sin(a) * r1)],
             hexc("ffb860"))
    part(img, ell(w, h, (5, 5, 16, 16)), ramp("e0702a", "ff9a3a", "ffc860", "fff0b0"), "8a3010")
    dots(img, [(8, 10), (13, 10)], hexc("8a3010"))
    dots(img, [(9, 13), (10, 13), (11, 13), (12, 13)], hexc("b04a1a"))
    dots(img, [(8, 7), (7, 8)], hexc("ffffff"))
    return img


def light_spool():
    """Le fil de lumiere (guide) : une bobine de bois, son fil dore qui brille et s'en va."""
    w, h = 22, 18
    img = canvas(w, h)
    wood = ramp("5a3420", "84502e", "aa6e42", "cc905c")
    part(img, poly(w, h, [(2, 1), (12, 1), (12, 3), (2, 3)]), wood, "2a160a")
    part(img, poly(w, h, [(2, 13), (12, 13), (12, 15), (2, 15)]), wood, "2a160a")
    part(img, poly(w, h, [(3, 3), (11, 3), (11, 13), (3, 13)]), ramp("c88a2a", "f0b840", "ffe070", "fff8c0"), "6a4010")
    for y in range(4, 13, 2):
        line(img, [(3, y), (11, y)], hexc("e0a030"))
    line(img, [(11, 10), (14, 12), (17, 11), (19, 14), (21, 13)], hexc("ffe070"))
    dots(img, [(14, 12), (19, 14)], hexc("ffffff"))
    dots(img, [(4, 4), (4, 6)], hexc("ffffff"))
    return img


def frozen_sun():
    """Le soleil fige (pause) : un demi-soleil pose sur sa ligne d'horizon, qui ne se couche plus."""
    w, h = 24, 14
    img = canvas(w, h)
    for x, y0 in ((3, 3), (7, 0), (16, 0), (20, 3)):  # rayons arretes
        dots(img, [(x, y0 + 2)], hexc("ffc870"))
    m = ell(w, h, (5, 3, 18, 22))
    part(img, m, ramp("d0502a", "f07a36", "ffaa50", "ffd890"), "7a2a10")
    for y in (6, 9):
        line(img, [(2, y), (21, y)], hexc("c04a3a"))
    line(img, [(0, 12), (23, 12)], hexc("3a1e3a"), 2)
    dots(img, [(9, 5), (8, 6)], hexc("fff4d0"))
    return img


def dusk_bubble():
    """Bulle de crepuscule : un bord qui passe de l'orange au violet, un petit soleil dedans."""
    def sun(img):
        part(img, ell(18, 18, (6, 9, 11, 14)), ramp("d0502a", "f07a36", "ffaa50", "ffd890"), None)
    return bubble(18, 18, ["ffb070", "e080a0", "a080d0", "ff9a80"], "e8a8c0", sun)


def dusk_lamppost():
    """Un reverbere courbe, allume trop tot, sa lumiere orange."""
    w, h = 18, 32
    img = canvas(w, h)
    iron = ramp("140e18", "241a2a", "36283e", "4a3854")
    part(img, poly(w, h, [(3, 6), (5, 6), (5, 28), (3, 28)]), iron, "06040a")
    line(img, [(4, 6), (6, 2), (10, 1), (13, 3)], hexc("241a2a"), 2)
    part(img, poly(w, h, [(0, 28), (8, 28), (9, 31), (-1, 31)]), iron, "06040a")
    part(img, poly(w, h, [(10, 4), (16, 4), (15, 10), (11, 10)]), ramp("d06a2a", "f8a040", "ffd070", "fff4c0"), "5a2a0a")
    part(img, poly(w, h, [(9, 3), (17, 3), (16, 5), (10, 5)]), iron, "06040a")
    dots(img, [(12, 6), (12, 7)], hexc("ffffff"))
    return img


def melted_clock():
    """Une horloge fondue qui coule par terre, ses aiguilles tordues."""
    w, h = 24, 16
    img = canvas(w, h)
    m = mask_wh(w, h, polys=[[(3, 8), (20, 6), (22, 12), (17, 13), (14, 15), (12, 12), (4, 13)]],
                ellipses=[(2, 1, 17, 12)])
    part(img, m, ramp("8a5a2a", "c88a3a", "e8b85a", "fce69a"), "3a2208")
    shade(img, mask_wh(w, h, polys=[[(5, 8), (18, 8), (19, 11), (6, 11)]], ellipses=[(4, 3, 15, 10)]),
          ramp("c8bca0", "e2d8c0", "f2ecdc", "fffaf0"), edge_dark=False)
    line(img, [(9, 7), (9, 4)], hexc("2a1e18"))
    line(img, [(9, 7), (12, 8), (14, 10)], hexc("2a1e18"))
    for x in (6, 12, 16):
        dots(img, [(x, 5 if x < 14 else 9)], hexc("8a7a60"))
    dots(img, [(5, 3), (4, 4)], hexc("ffffff"))
    return img


def long_shadow():
    """Une ombre allongee au sol, sans personne pour la porter."""
    w, h = 28, 14
    img = canvas(w, h)
    m = mask_wh(w, h, polys=[[(4, 7), (20, 5), (23, 6), (20, 8), (5, 10)]], ellipses=[(21, 3, 27, 9)])
    for y in range(h):
        for x in range(w):
            if m.getpixel((x, y)):
                img.putpixel((x, y), hexc("1a0e24", 150 + (x * 3)))
    line(img, [(6, 7), (2, 12)], hexc("1a0e24", 130))
    line(img, [(8, 8), (5, 13)], hexc("1a0e24", 130))
    return img


# --- Dimanche : le Coeur de la nuit (profond) ------------------------------------------------

FLESH = [hexc("1a080e"), hexc("240c14"), hexc("30101a"), hexc("3e1622"), hexc("4e1e2c")]
VEIN = [hexc("6a0e1e"), hexc("a01a2a"), hexc("e0303a"), hexc("ff7a6a")]
FLESH_CELLS = seeds(7, 301)


def vein_pts(seed, length, x0, y0):
    """Veine qui serpente d'un bord a l'autre (douce, pas de zigzag)."""
    pts = []
    for i in range(length):
        x = x0 + i
        y = y0 + 5 * math.sin(i / length * math.tau + seed) + 2 * math.sin(i / length * math.tau * 2 + seed * 3)
        pts.append((x, round(y)))
    return pts


def draw_vein(img, pts, glow=True):
    for x, y in pts:
        if glow:
            for dx, dy in ((0, -1), (0, 1)):
                c = img.getpixel(((x + dx) % TILE, (y + dy) % TILE))
                put(img, x + dx, y + dy, (min(255, c[0] + 40), c[1], c[2] + 6, 255))
    for x, y in pts:
        put(img, x, y, VEIN[2])
    for x, y in pts[::5]:
        put(img, x, y, VEIN[3])


def heart_floor(variant):
    """Chair sombre en replis modeles, parcourue de veines qui luisent ; variantes : deux veines,
    une tache qui pulse, des spores lumineuses."""
    img = tile()
    each(img, lambda x, y: stones(x, y, FLESH_CELLS, FLESH[1:], FLESH[0], light_shift=2, flat=-0.05)[0])
    # une veine courte et ramifiee, differente sur chaque dalle (pas de lignes qui courent d'une
    # case a l'autre) ; elle s'affine aux deux bouts
    x0, y0, length, amp, slope = ((4, 30, 40, 4, -0.25), (8, 12, 36, -3, 0.35), (16, 38, 30, 3, -0.2),
                                  (6, 20, 38, -4, 0.3))[variant]
    pts = [(x0 + i, round(y0 + amp * math.sin(i / length * math.pi) + slope * i + 0.8 * math.sin(i * 0.45)))
           for i in range(length)]
    draw_vein(img, pts[3:-3])
    for x, y in pts[:3] + pts[-3:]:
        put(img, x, y, VEIN[1])
    mid = pts[length // 2]
    for i in range(1, 7):  # une branche
        put(img, mid[0] + i, mid[1] - i + i // 3, VEIN[2] if i < 4 else VEIN[1])
    if variant == 2:  # une tache qui pulse
        for y in range(TILE):
            for x in range(TILE):
                dx, dy = tdist(x, y, 20, 14)
                d = math.hypot(dx, dy)
                if d < 6:
                    img.putpixel((x, y), band(VEIN, 1 - d / 6, x, y, 0.3))
    elif variant == 3:  # spores qui luisent
        for sx, sy in ((12, 12), (14, 15), (36, 40), (39, 38), (35, 15)):
            put(img, sx, sy, hexc("ff9a8a"))
            put(img, sx + 1, sy, VEIN[1])
    return img


def black_top():
    """Le vide autour : un noir presque complet, une pulsation rouge a peine visible."""
    img = tile()
    tones = [hexc("060204"), hexc("0a0306"), hexc("10050a"), hexc("18070e")]
    return each(img, lambda x, y: band(tones, 0.35 + tnoise(x, y, 311) * 0.6, x, y, 0.5))


def vein_face():
    """Paroi de chair sombre : des veines rouges qui descendent, ramifiees, et luisent."""
    img = tile()
    cells = seeds(6, 313)
    each(img, lambda x, y: stones(x, y, cells, FLESH[1:], FLESH[0], light_shift=2)[0])
    for x0, seed in ((10, 0.7), (34, 2.9)):
        pts = []
        for y in range(TILE):
            x = x0 + 4 * math.sin(y / TILE * math.tau + seed)
            pts.append((round(x), y))
        draw_vein(img, pts)
        for i in range(1, 8):  # une branche
            put(img, pts[18][0] + i, 18 + i, VEIN[1])
    return darken_down(img, 0.25)


def firefly():
    """La luciole (s'allume) : un petit insecte au ventre qui brille, son halo."""
    w, h = 18, 16
    img = canvas(w, h)
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - 8.5, y - 9.5)
            if d < 7.5 and (x + y) % 2 == 0:
                img.putpixel((x, y), hexc("d8ff8a", int(110 * (1 - d / 7.5))))
    wing = canvas(w, h)
    shade(wing, ell(w, h, (2, 2, 8, 8), (9, 2, 15, 8)), ramp("8a9ab8", "b4c4e0", "d8e4f4", "ffffff"))
    fade(wing, 0.6)
    img.alpha_composite(wing)
    part(img, ell(w, h, (6, 5, 11, 10)), ramp("1a1a22", "2a2a36", "3e3e4e", "565668"), "08080c")
    part(img, ell(w, h, (6, 9, 11, 14)), ramp("a0d040", "d0f060", "f0ff9a", "ffffe0"), "3a5a10")
    dots(img, [(7, 6), (10, 6)], hexc("f0f0ff"))
    return img


def closed_eye():
    """L'oeil ferme (lance un combat) : une grande paupiere close dans la chair, cils, et une larme."""
    w, h = 26, 16
    img = canvas(w, h)
    almond = mask_wh(w, h)
    for y in range(h):
        for x in range(w):
            u = (x - 12.5) / 12
            if abs(u) < 1 and abs(y - 7) < 6.5 * (1 - u * u):
                almond.putpixel((x, y), 255)
    part(img, almond, ramp("5a1e2e", "843446", "aa5062", "cc7484"), "1a0408")
    lid = [(1, 7), (5, 8), (9, 9), (13, 9), (17, 9), (21, 8), (24, 7)]
    line(img, lid, hexc("1a0408"), 2)
    for x, y in ((5, 9), (9, 10), (13, 10), (17, 10), (21, 9)):  # cils, bien noirs, vers le bas
        lean = -1 if x < 13 else (1 if x > 13 else 0)
        dots(img, [(x, y + 1), (x + lean, y + 2), (x + lean, y + 3)], hexc("1a0408"))
    line(img, [(4, 4), (9, 2), (16, 2), (21, 4)], hexc("e8a0aa"))  # pli de la paupiere
    dots(img, [(14, 13)], hexc("ff9aa0"))
    dots(img, [(14, 14)], hexc("ffd0d4"))
    dots(img, [(7, 4), (8, 3)], hexc("f4b8c0"))
    return img


def sealed_box():
    """La boite scellee (contient un objet) : bois noir, chaine croisee, cachet rouge."""
    w, h = 20, 18
    img = canvas(w, h)
    part(img, poly(w, h, [(1, 3), (18, 3), (18, 16), (1, 16)]), ramp("120a10", "201418", "2e1e24", "3e2a32"), "040204")
    part(img, poly(w, h, [(0, 1), (19, 1), (19, 5), (0, 5)]), ramp("1a0e14", "2a1a20", "3a262e", "4c343e"), "040204")
    chain = hexc("8a8e9a")
    for i in range(0, 14, 2):
        dots(img, [(3 + i, 4 + i * 11 // 14), (16 - i, 4 + i * 11 // 14)], chain)
    part(img, ell(w, h, (7, 7, 12, 12)), ramp("6a0e1e", "a01a2a", "e0303a", "ff7a6a"), "2a0408")
    dots(img, [(9, 9)], hexc("6a0e1e"))
    dots(img, [(2, 2), (3, 2)], hexc("6a4a5a"))
    return img


def vein_knot():
    """Un noeud de veines qui palpite, sorti du sol."""
    w, h = 20, 18
    img = canvas(w, h)
    for pts in (((1, 16), (5, 10), (9, 8), (13, 3), (18, 2)), ((2, 3), (6, 7), (11, 10), (14, 15), (18, 16)),
                ((9, 17), (10, 12), (8, 6), (10, 1))):
        line(img, pts, hexc("2a0408"), 4)
    for pts in (((1, 16), (5, 10), (9, 8), (13, 3), (18, 2)), ((2, 3), (6, 7), (11, 10), (14, 15), (18, 16)),
                ((9, 17), (10, 12), (8, 6), (10, 1))):
        line(img, pts, VEIN[1], 2)
        line(img, pts, VEIN[2])
    part(img, ell(w, h, (6, 6, 13, 12)), VEIN, "2a0408")
    dots(img, [(8, 7), (7, 8)], hexc("ffc0b0"))
    return img


def glowing_eyes():
    """Deux yeux qui luisent dans un coin d'ombre."""
    w, h = 24, 12
    img = canvas(w, h)
    for y in range(h):
        for x in range(w):
            d = math.hypot((x - 11.5) / 11, (y - 5.5) / 5.5)
            if d < 1:
                img.putpixel((x, y), hexc("06020a", int(200 * (1 - d * d))))
    for cx in (6, 16):
        part(img, ell(w, h, (cx - 3, 3, cx + 3, 8)), ramp("a08a30", "e0c050", "fff08a", "ffffe0"), "3a2a08")
        dots(img, [(cx, 5), (cx, 6)], hexc("1a0a04"))
        dots(img, [(cx - 1, 4)], hexc("ffffff"))
    return img


def dimanche():
    tiles("dimanche", "paradoxal", [dusk_floor(v) for v in range(4)], dusk_top(), tree_face())
    tiles("dimanche", "profond", [heart_floor(v) for v in range(4)], black_top(), vein_face())
    for name, make in {"etoile": last_ray, "lune": light_spool, "horloge": frozen_sun, "bulle": dusk_bubble,
                       "reverbere": dusk_lamppost, "horloge_fondue": melted_clock, "ombre": long_shadow}.items():
        save(make(), "decor", "dimanche", "paradoxal", f"{name}.png")
    for name, make in {"bougie": firefly, "champignon": closed_eye, "cristal": sealed_box,
                       "veine": vein_knot, "yeux": glowing_eyes}.items():
        save(make(), "decor", "dimanche", "profond", f"{name}.png")


WEEK = {"mardi": mardi, "mercredi": mercredi, "jeudi": jeudi, "vendredi": vendredi, "samedi": samedi,
        "dimanche": dimanche}

if __name__ == "__main__":
    for night in sys.argv[1:] or WEEK:
        WEEK[night]()
        print("decors redessines :", night)
