"""Decors redessines, nuit par nuit (meme direction que les creatures : volume, lumiere en haut a
gauche, tons en aplats nets, contour d'encre colore, petites matieres dessinees).

Lancer depuis la racine du projet : python tools/place_art.py [nuit...]
Ecrit, pour les nuits listees dans PLACES, les tuiles (assets/sprites/tiles/<nuit>/, 50 x 50,
raccord sur les 4 bords, version cauchemar deduite) et les decors (assets/sprites/decor/<nuit>/).
tools/gen_places.py le relance apres ses propres dessins, pour ne pas les ecraser.
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
from mob_art_week import ell, line, part, poly, rect  # noqa: E402
from proj_art import dots, hexc, ink, ramp, shade  # noqa: E402

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def dither(x, y):
    return (BAYER[y % 4][x % 4] + 0.5) / 16


def band(tones, value, x=0, y=0, soft=0.0):
    """Choisit un ton dans la rampe selon value (0..1) ; soft ajoute un tramage aux frontieres."""
    v = value + (dither(x, y) - 0.5) * soft
    i = max(0, min(len(tones) - 1, int(v * len(tones))))
    return tones[i]


def tile():
    return Image.new("RGBA", (TILE, TILE), (0, 0, 0, 255))


def put(img, x, y, color):
    """Pixel sur une tuile qui se raccorde : ce qui depasse revient de l'autre cote."""
    img.putpixel((x % TILE, y % TILE), color)


def tdist(x, y, cx, cy):
    dx = min(abs(x - cx), TILE - abs(x - cx))
    dy = min(abs(y - cy), TILE - abs(y - cy))
    return dx, dy


_LATTICES = {}


def _lattice(seed, n):
    key = (seed, n)
    if key not in _LATTICES:
        rng = random.Random(seed * 131 + n)
        _LATTICES[key] = [[rng.uniform(-1, 1) for _ in range(n)] for _ in range(n)]
    return _LATTICES[key]


def _value(x, y, seed, n):
    """Bruit de valeur sur une grille n x n qui boucle sur la tuile (raccord parfait)."""
    g = _lattice(seed, n)
    fx, fy = (x % TILE) / TILE * n, (y % TILE) / TILE * n
    x0, y0 = int(fx), int(fy)
    tx, ty = fx - x0, fy - y0
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a, b = g[y0 % n][x0 % n], g[y0 % n][(x0 + 1) % n]
    c, d = g[(y0 + 1) % n][x0 % n], g[(y0 + 1) % n][(x0 + 1) % n]
    return (a + (b - a) * tx) * (1 - ty) + (c + (d - c) * tx) * ty


def tnoise(x, y, seed, scale=1.0):
    """Bruit doux et organique qui se raccorde sur la tuile (3 octaves de bruit de valeur)."""
    base = 2 if scale < 1.5 else 5
    return (_value(x, y, seed, base) * 0.55 + _value(x, y, seed + 1, base * 2) * 0.3
            + _value(x, y, seed + 2, base * 5) * 0.15)


def stamp(img, sprite, x, y):
    """Colle un petit dessin sur une tuile, en raccord."""
    for sy in range(sprite.height):
        for sx in range(sprite.width):
            c = sprite.getpixel((sx, sy))
            if c[3] > 0:
                put(img, x + sx, y + sy, c)


# --- Lundi : la Mer de coton (paradoxal) -------------------------------------------------------

COTTON = [ramp("968ad4", "aea2e4", "c4baf0", "d8d0f8"), ramp("a28ed4", "b8a6e4", "ccbcf0", "dfd2f8")]
STITCH = hexc("7a6cc0")


def cotton_floor(variant):
    """Couette matelassee en patchwork : chaque losange bombe, eclaire en haut a gauche, coutures
    piquees ; variantes : une plume, des boutons de capiton, une lune brodee."""
    img = tile()
    cell = 25
    for y in range(TILE):
        for x in range(TILE):
            u, v = (x + y) % cell, (x - y) % cell
            e = min(u, cell - 1 - u, v, cell - 1 - v)
            tones = COTTON[((x + y) // cell + (x - y) // cell) % 2]
            puff = min(1.0, e / 6.0)
            light = 0.3 + 0.55 * puff - 0.2 * (u - 12) / 12 * puff
            c = band(tones, light, x, y, soft=0.08)
            if e == 0:
                c = STITCH if (x // 2 + y // 2) % 2 == 0 else tones[0]
            elif e == 1 and u < 3:
                c = tones[0]
            img.putpixel((x, y), c)
    if variant == 1:
        stamp(img, feather_sprite(), 15, 20)
    elif variant == 2:  # boutons de capiton au centre des losanges
        for cx, cy in ((12, 0), (37, 0), (25, 12), (0, 12), (12, 25), (37, 25), (25, 37), (0, 37)):
            put(img, cx, cy, hexc("4a3c8c"))
            put(img, cx + 1, cy, hexc("4a3c8c"))
            put(img, cx, cy - 1, hexc("f4f0ff"))
            put(img, cx - 1, cy, hexc("8c7ed0"))
            put(img, cx + 1, cy + 1, hexc("6e62b4"))
    elif variant == 3:  # une lune et deux etoiles brodees au fil d'or
        gold, shadow = hexc("f0d27a"), hexc("a08a50")
        for y in range(TILE):
            for x in range(TILE):
                d1 = math.hypot(x - 24, y - 25)
                d2 = math.hypot(x - 26.5, y - 23)
                if d1 <= 5.2 and d2 > 4.4 and (x + y) % 2 == 0:
                    img.putpixel((x, y), gold)
                    if d1 <= 4:
                        img.putpixel((x + 1, y + 1), shadow)
        for sx, sy in ((33, 19), (31, 30)):
            dots(img, [(sx, sy), (sx - 1, sy), (sx + 1, sy), (sx, sy - 1), (sx, sy + 1)], gold)
    return img


def cotton_wall_top():
    """La nuit autour des chemins : indigo profond, nuages de coton modeles, etoiles qui piquent."""
    img = tile()
    sky = [hexc("1e1a44"), hexc("231f4a"), hexc("28244f")]
    cloud = [hexc("2e2a5c"), hexc("38346a"), hexc("443f78"), hexc("524c88")]
    puffs = [(8, 16, 6), (14, 13, 7), (21, 15, 6), (27, 17, 4), (34, 40, 5), (40, 38, 6), (46, 41, 5)]
    for y in range(TILE):
        for x in range(TILE):
            n = tnoise(x, y, 5)
            img.putpixel((x, y), band(sky, 0.5 + n * 0.6, x, y, soft=0.5))
            best, shade_v = 0.0, 0.0
            for cx, cy, r in puffs:  # nuages etires : plus larges que hauts, bas plats
                dx, dy = tdist(x, y, cx, cy)
                up = (y - cy) % TILE > TILE / 2
                k = 1 - math.hypot(dx / 1.4, dy * (1.0 if up else 2.2)) / r
                if k > best:
                    best = k
                    shade_v = 0.25 + 0.9 * k + (0.25 if up else -0.2)
            if best > 0:
                img.putpixel((x, y), band(cloud, shade_v, x, y, soft=0.25))
    for sx, sy, big in ((5, 40, True), (30, 6, False), (46, 18, False), (27, 27, False), (8, 30, False)):
        put(img, sx, sy, hexc("f4f0ff"))
        if big:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                put(img, sx + dx, sy + dy, hexc("a8a0e0"))
    return img


PILLOWS = [ramp("8a7ec8", "b0a6e0", "d0c8f2", "f0ecff"), ramp("a884b8", "c8a6d4", "e2c8ea", "f8eafa"),
           ramp("8a8cc8", "a8b0e2", "c8d0f2", "eaeeff")]


def pillow_wall_face():
    """Piles d'oreillers : deux rangees decalees d'oreillers dodus aux coins pinces en oreilles,
    couture en retrait du bord ; plus sombre vers le bas (on regarde le pied du mur)."""
    img = Image.new("RGBA", (TILE, TILE), hexc("2a2456"))
    for r in range(2):
        off = 12 if r else 0
        for ly in range(25):
            y = r * 25 + ly
            for x in range(TILE):
                lx = (x + off) % 25
                tones = PILLOWS[((x + off) // 25 + r) % 3]
                nx, ny = (lx - 12) / 12.4, (ly - 12) / 11.6
                s = abs(nx) ** 3 + abs(ny) ** 3
                ear = abs(nx) > 0.78 and abs(ny) > 0.74 and abs(abs(nx) - abs(ny)) < 0.13
                if s > 0.78 and not ear:
                    continue
                puff = max(0.0, 1 - s / 0.78)
                light = 0.22 + 0.62 * puff ** 0.7 - 0.22 * ny - 0.1 * nx - 0.12 * (y / TILE)
                c = band(tones, light, x, y, soft=0.1)
                if 0.5 < s < 0.56 and (lx + ly) % 3:
                    c = tones[1]  # la couture
                img.putpixel((x, y), c)
    return img


# --- Lundi : la Brume de sommeil (profond) -----------------------------------------------------

MOSS = [hexc("18242a"), hexc("1e2c32"), hexc("26363c"), hexc("2e4246"), hexc("3a5052")]
MIST = hexc("6a7a8e")


def moss_floor(variant):
    """Mousse sombre en touffes modelees, nappes de brume tramees ; variantes : une flaque de brume,
    des fleurs de sommeil, des cailloux."""
    img = tile()
    for y in range(TILE):
        for x in range(TILE):
            n = tnoise(x, y, 11, 2.0)
            m = tnoise(x - 1, y - 1, 11, 2.0)
            v = 0.5 + n * 0.5 + (n - m) * 1.2  # relief leger : le bord eclaire des touffes
            img.putpixel((x, y), band(MOSS[1:4], v, x, y, soft=0.3))
    fog = [(28, 18, 18, 9)] if variant == 1 else []
    for cx, cy, rx, ry in fog:
        for y in range(TILE):
            for x in range(TILE):
                dx, dy = tdist(x, y, cx, cy)
                k = 1 - math.hypot(dx / rx, dy / ry) + tnoise(x, y, 40 + cx, 2.0) * 0.5
                if k > 0 and dither(x, y) < k * (0.9 if variant == 1 else 0.5):
                    c = img.getpixel((x, y))
                    img.putpixel((x, y), tuple((a + b) // 2 for a, b in zip(c[:3], MIST[:3])) + (255,))
    if variant == 2:  # fleurs de sommeil : petites clochettes pales
        for fx, fy in ((13, 15), (36, 33)):
            dots(img, [(fx, fy + 1), (fx, fy + 2)], hexc("2e5a4a"))
            dots(img, [(fx - 1, fy), (fx, fy), (fx + 1, fy), (fx, fy - 1)], hexc("b8d0f0"))
            dots(img, [(fx - 1, fy)], hexc("e8f4ff"))
            dots(img, [(fx + 1, fy + 1)], hexc("5a7aa8"))
    elif variant == 3:  # cailloux modeles
        stones = ramp("2a3238", "46525a", "66747c", "8e9ca4")
        for sx, sy, rw in ((27, 21, 4),):
            pebble = canvas(rw * 2 + 3, rw + 4)
            shade(pebble, ell(pebble.width, pebble.height, (1, 1, rw * 2 + 1, rw + 2)), stones)
            ink(pebble, hexc("10181c"))
            stamp(img, pebble, sx, sy)
    return img


def mist_wall_top():
    """Le vide autour : nuit brumeuse, nappes tramees, quelques lucioles endormies."""
    img = tile()
    tones = [hexc("0e1218"), hexc("141a22"), hexc("1a222c"), hexc("222c38")]
    for y in range(TILE):
        for x in range(TILE):
            img.putpixel((x, y), band(tones, 0.45 + tnoise(x, y, 21) * 0.45, x, y, soft=0.5))
    for fx, fy in ((11, 33), (39, 12)):
        put(img, fx, fy, hexc("c8e0a0"))
        put(img, fx + 1, fy, hexc("5a6a4a"))
    return img


VELVET = [hexc("161a34"), hexc("222850"), hexc("30386a"), hexc("424c88"), hexc("5a66a6"), hexc("7a86c4")]


def curtain_wall_face():
    """Lourds rideaux de velours : plis ronds modeles, reflet sur chaque pli, tringle de laiton et
    anneaux en haut, ourlet a franges dorees en bas."""
    img = tile()
    for y in range(TILE):
        for x in range(TILE):
            warp = x + 1.2 * _value(x, y, 31, 2)  # les plis ondulent un peu
            p = (warp % 10) / 10
            fold = 0.5 + 0.5 * math.cos(math.tau * (p - 0.3))
            v = 0.1 + 0.7 * fold - 0.25 * (y / TILE)
            c = band(VELVET, v, x, y, soft=0.15)
            if abs(p - 0.25) < 0.05 and 6 < y < 43 and _value(x, y, 33, 5) > -0.2:
                c = VELVET[4]  # le reflet du velours
            img.putpixel((x, y), c)
    brass = ramp("6e4a12", "b8862a", "e6c25a", "fff0a8")
    for x in range(TILE):
        img.putpixel((x, 0), hexc("2a1a08"))
        img.putpixel((x, 1), brass[3] if x % 7 == 0 else brass[2])
        img.putpixel((x, 2), brass[1])
        img.putpixel((x, 3), hexc("2a1a08"))
    for cx in range(4, TILE, 10):  # anneaux
        dots(img, [(cx - 1, 2), (cx + 1, 2), (cx - 1, 4), (cx + 1, 4), (cx, 5)], brass[1])
        dots(img, [(cx - 1, 3)], brass[3])
    for x in range(TILE):  # ourlet et franges
        img.putpixel((x, 44), VELVET[0])
        img.putpixel((x, 45), VELVET[2] if x % 10 < 6 else VELVET[1])
        img.putpixel((x, 46), hexc("c8a050"))
        for y in (47, 48):
            img.putpixel((x, y), hexc("c8a050") if x % 2 == 0 else VELVET[0])
        img.putpixel((x, 49), hexc("8a6a30") if x % 2 == 0 else hexc("0e1022"))
    return img


# --- Lundi : decors ----------------------------------------------------------------------------

def feather_sprite():
    """Plume posee (aussi brodee sur la couette)."""
    w, h = 20, 10
    img = canvas(w, h)
    vane = ramp("9a8ed0", "c8c0ec", "eae6fc", "ffffff")
    shade(img, poly(w, h, [(2, 8), (7, 4), (14, 1), (18, 1), (15, 4), (9, 7)]), vane)
    line(img, [(1, 9), (17, 2)], hexc("b8a888"))
    for x in range(5, 16, 3):  # barbes
        dots(img, [(x, 8 - (x - 1) * 7 // 16 + 1)], hexc("aaa0d8"))
    ink(img, hexc("6a5ea8"))
    dots(img, [(14, 2), (15, 2)], hexc("ffffff"))
    return img


def etoile_sprite():
    """La Veilleuse etoile (soigne) : une etoile douce branchee au mur, qui dort."""
    w, h = 20, 21
    img = canvas(w, h)
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        r = 8.5 if k % 2 == 0 else 4.2
        pts.append((9.5 + math.cos(a) * r, 9 + math.sin(a) * r))
    shade(img, poly(w, h, pts), ramp("c2802a", "f0b040", "ffd870", "fff4c0"))
    dots(img, [(6, 9), (7, 10), (8, 9), (11, 9), (12, 10), (13, 9)], hexc("8a4a1a"))  # yeux clos
    dots(img, [(9, 12), (10, 12)], hexc("b05a2a"))
    dots(img, [(5, 11), (14, 11)], hexc("ffa070"))
    shade(img, poly(w, h, [(8, 16), (11, 16), (11, 18), (8, 18)]), ramp("4a4a58", "8a8a9a", "c4c4d0", "f0f0f8"))
    dots(img, [(8, 19), (11, 19)], hexc("6a6a78"))
    ink(img, hexc("6a3a10"))
    dots(img, [(8, 3), (7, 5)], hexc("ffffff"))
    return img


def lune_sprite():
    """La Lanterne de reve (guide) : lanterne de papier aux cotes de bambou, lueur chaude."""
    w, h = 16, 22
    img = canvas(w, h)
    line(img, [(8, 0), (8, 2)], hexc("6a5a8a"))
    shade(img, poly(w, h, [(5, 2), (10, 2), (10, 4), (5, 4)]), ramp("3a2a4a", "5a4a6a", "7a6a8a", "9a8aaa"))
    shade(img, ell(w, h, (1, 4, 14, 18)), ramp("d08a4a", "f0b870", "ffe0a8", "fff8e0"), light=(-0.4, -0.6))
    for x in (4, 7, 10):  # cotes de bambou
        for y in range(6, 17):
            if img.getpixel((x, y))[3]:
                img.putpixel((x, y), hexc("c0884a"))
    for y in (8, 12):
        for x in range(2, 14):
            if img.getpixel((x, y))[3] and (x + y) % 2:
                img.putpixel((x, y), hexc("e0a060"))
    shade(img, poly(w, h, [(5, 18), (10, 18), (10, 19), (5, 19)]), ramp("3a2a4a", "5a4a6a", "7a6a8a", "9a8aaa"))
    dots(img, [(7, 20), (8, 20), (7, 21)], hexc("e04a5a"))  # le pompon
    ink(img, hexc("5a3a2a"))
    dots(img, [(4, 6), (3, 8)], hexc("ffffff"))
    return img


def horloge_sprite():
    """Le Reveil endormi (pause) : un reveil de laiton aux yeux clos, deux cloches, un petit z."""
    w, h = 20, 20
    img = canvas(w, h)
    bell = ramp("6e4a12", "c0861e", "f0c048", "fff0a0")
    for cx in (5, 14):
        shade(img, ell(w, h, (cx - 3, 2, cx + 3, 7)), bell)
    shade(img, ell(w, h, (2, 4, 17, 18)), ramp("8a5a1a", "c48a32", "e8b858", "fce6a0"))
    shade(img, ell(w, h, (5, 7, 14, 16)), ramp("c8c0b0", "e4ded2", "f6f2ea", "ffffff"), edge_dark=False)
    dots(img, [(7, 11), (8, 12), (9, 11), (10, 11), (11, 12), (12, 11)], hexc("3a2a20"))
    dots(img, [(9, 14), (10, 14)], hexc("8a5a4a"))
    dots(img, [(4, 18), (15, 18)], hexc("5a3a10"))
    ink(img, hexc("3a2408"))
    dots(img, [(4, 3), (6, 8)], hexc("ffffff"))
    dots(img, [(16, 0), (17, 0), (16, 1)], hexc("c8c0ff"))  # z
    return img


def bulle_sprite():
    """La Bulle de baillement : une bulle irisee, reflet en haut a gauche, un z flou dedans."""
    w, h = 18, 18
    img = canvas(w, h)
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - 8.5, y - 8.5)
            if d <= 7.6:
                rim = d > 6.4
                a = 230 if rim else 70
                hue = ["c8b0ff", "a8c8ff", "ffc0e8"][int((math.atan2(y - 8.5, x - 8.5) + math.pi) / math.tau * 3) % 3]
                img.putpixel((x, y), hexc(hue if rim else "d8ccff", a))
    dots(img, [(5, 4), (4, 5), (4, 6), (6, 4)], hexc("ffffff"))
    dots(img, [(8, 8), (9, 8), (10, 8), (9, 9), (8, 10), (9, 10), (10, 10)], hexc("8a70c8", 170))
    return img


def rideau_sprite():
    """Un pan de rideau suspendu dans le vide, retenu par une embrasse doree."""
    w, h = 18, 22
    img = canvas(w, h)
    brass = ramp("6e4a12", "b8862a", "e6c25a", "fff0a8")
    shade(img, poly(w, h, [(1, 1), (16, 1), (16, 2), (1, 2)]), brass)
    fabric = ramp("6a5aa8", "8e80cc", "b4a8e6", "d6ceff")
    shade(img, poly(w, h, [(2, 3), (15, 3), (13, 11), (15, 20), (9, 18), (4, 20), (5, 11)]), fabric)
    for x in (5, 8, 11):
        line(img, [(x, 4), (x + (1 if x < 9 else -1), 10), (x - 1, 18)], fabric[0])
    dots(img, [(5, 11), (6, 11), (7, 11), (11, 11), (12, 11), (13, 11)], hexc("e6c25a"))
    dots(img, [(9, 12), (9, 13)], hexc("c8962a"))
    ink(img, hexc("3a2e6a"))
    dots(img, [(3, 4), (4, 6)], hexc("eae6ff"))
    return img


def lampe_sprite(lit=False):
    """Lampe de chevet : abat-jour plisse, pied de laiton, socle ; allumee : l'abat-jour rougeoie."""
    w, h = 16, 21
    img = canvas(w, h)
    shade_tones = ramp("c26a2c", "f0a640", "ffd77a", "fff6d6") if lit else ramp("6a5a9a", "8e80c0", "b0a6dc", "d0caf0")
    shade(img, poly(w, h, [(4, 1), (11, 1), (14, 9), (1, 9)]), shade_tones, light=(-0.6, -0.4))
    for x in (4, 7, 10):  # plis de l'abat-jour
        line(img, [(x + 1, 2), (x - (1 if x < 7 else -1 if x > 7 else 0), 8)], shade_tones[1])
    dots(img, [(x, 9) for x in range(2, 14)], shade_tones[0])
    shade(img, poly(w, h, [(7, 10), (8, 10), (8, 17), (7, 17)]), ramp("6e4a12", "b8862a", "e6c25a", "fff0a8"))
    shade(img, ell(w, h, (3, 16, 12, 20)), ramp("2a2040", "4a3e6a", "6a5e90", "8e84b0"))
    ink(img, hexc("2a1e3a" if not lit else "5a2a10"))
    dots(img, [(5, 2), (4, 4)], hexc("ffffff"))
    return img


def bougie_sprite():
    return lampe_sprite(lit=True)


def champignon_sprite():
    """Le tas de draps qui respire (lance un combat) : des draps en tas, des plis, et deux yeux
    qui luisent dans un repli sombre."""
    w, h = 24, 15
    img = canvas(w, h)
    sheet_t = ramp("4a5468", "7a8698", "a8b4c4", "d4dce6")
    for box in ((1, 5, 12, 14), (9, 2, 21, 14), (15, 6, 23, 14), (5, 1, 14, 10)):
        part(img, ell(w, h, box), sheet_t, "2a3242")
    dots(img, [(10, 8), (11, 9), (12, 9), (13, 9), (14, 8)], hexc("141a24"))
    dots(img, [(11, 8), (13, 8)], hexc("b8f0e0"))
    line(img, [(4, 12), (8, 9)], sheet_t[1])
    line(img, [(17, 12), (20, 9)], sheet_t[1])
    ink(img, hexc("1a202c"))
    dots(img, [(7, 2), (6, 3), (11, 3)], hexc("f0f4fa"))
    return img


def cristal_sprite():
    """Le coffre a jouets (contient un objet) : bois peint mauve seme d'etoiles, ferrures dorees."""
    w, h = 22, 17
    img = canvas(w, h)
    wood = ramp("3a2448", "5a3a6e", "7e5694", "a47ab8")
    shade(img, poly(w, h, [(2, 6), (19, 6), (19, 15), (2, 15)]), wood)
    shade(img, mask_wh(w, h, polys=[[(1, 3), (20, 3), (20, 6), (1, 6)]], ellipses=[(1, 1, 20, 6)]), ramp("4a2e5a", "6e4682", "9466aa", "b890cc"))
    gold = hexc("f0c858")
    dots(img, [(x, 6) for x in range(2, 20)], hexc("2a1838"))
    dots(img, [(5, 9), (16, 12), (12, 10), (7, 13)], gold)
    dots(img, [(10, 6), (11, 6), (10, 7), (11, 7), (10, 8), (11, 8)], gold)
    dots(img, [(10, 8)], hexc("8a6a20"))
    for x in (3, 18):
        dots(img, [(x, y) for y in range(4, 15)], hexc("c89a3a"))
    ink(img, hexc("1e1028"))
    dots(img, [(3, 2), (4, 2), (3, 7)], hexc("e8d0f4"))
    return img


def draps_sprite():
    """Un drap qui flotte, suspendu par deux pinces, l'ourlet effiloche."""
    w, h = 18, 20
    img = canvas(w, h)
    cloth = ramp("5a667a", "8894a8", "b4c0d0", "dde4ee")
    shade(img, poly(w, h, [(1, 2), (16, 2), (15, 10), (16, 18), (13, 16), (10, 18), (7, 16), (4, 18), (1, 16), (2, 10)]), cloth)
    for x in (5, 9, 13):
        line(img, [(x, 3), (x - 1, 10), (x, 16)], cloth[1])
    for x in (3, 14):
        dots(img, [(x, 1), (x, 2), (x, 3)], hexc("c8a070"))
    ink(img, hexc("2a3242"))
    dots(img, [(2, 3), (3, 5)], hexc("ffffff"))
    return img


def fauteuil_sprite():
    """Le fauteuil de velours, un plaid tricote jete sur l'accoudoir."""
    w, h = 24, 20
    img = canvas(w, h)
    velvet = ramp("3a1e3a", "5e3258", "844a7a", "aa6a9c")
    shade(img, ell(w, h, (4, 1, 19, 12)), velvet)  # dossier
    for x in (8, 11, 15):
        dots(img, [(x, 5), (x, 8)], velvet[0])  # capitons
    shade(img, poly(w, h, [(4, 10), (19, 10), (20, 15), (3, 15)]), velvet)  # assise
    for x0 in (1, 18):  # accoudoirs
        shade(img, ell(w, h, (x0, 7, x0 + 5, 16)), velvet)
    shade(img, poly(w, h, [(18, 7), (22, 8), (21, 15), (19, 16), (18, 12)]), ramp("2e5a4a", "4a8a6a", "6ab48a", "9ad8b0"))
    for y in range(9, 15, 2):
        dots(img, [(19, y), (20, y + 1)], hexc("2e5a4a"))  # mailles du plaid
    for x in (4, 19):
        dots(img, [(x, 16), (x, 17)], hexc("4a2e1a"))
    ink(img, hexc("1e0e1e"))
    dots(img, [(6, 2), (5, 4)], hexc("d8a0cc"))
    return img


def lundi():
    tiles("lundi", "paradoxal", [cotton_floor(v) for v in range(4)], cotton_wall_top(), pillow_wall_face())
    tiles("lundi", "profond", [moss_floor(v) for v in range(4)], mist_wall_top(), curtain_wall_face())
    for name, make in {"etoile": etoile_sprite, "lune": lune_sprite, "horloge": horloge_sprite, "bulle": bulle_sprite,
                       "plume": feather_sprite, "rideau": rideau_sprite, "lampe": lampe_sprite}.items():
        save(make(), "decor", "lundi", "paradoxal", f"{name}.png")
    for name, make in {"bougie": bougie_sprite, "champignon": champignon_sprite, "cristal": cristal_sprite,
                       "draps": draps_sprite, "fauteuil": fauteuil_sprite}.items():
        save(make(), "decor", "lundi", "profond", f"{name}.png")


def places():
    """Toutes les nuits redessinees (mardi a dimanche dans tools/place_art_week.py)."""
    from place_art_week import WEEK
    return {"lundi": lundi, **WEEK}


if __name__ == "__main__":
    nights = places()
    for night in sys.argv[1:] or nights:
        nights[night]()
        print("decors redessines :", night)
