"""Pixel art des lieux des nuits (docs/nuits.md) : tuiles et decors de chaque nuit.

Lancer depuis la racine du projet : python tools/gen_places.py [nuit...]
Ecrit assets/sprites/tiles/<nuit>/{reve,cauchemar}_{paradoxal,profond}_*.png et
assets/sprites/decor/<nuit>/{paradoxal,profond}/<decor>.png. Les etages cauchemar reprennent les
tuiles du reve, assombries et rougies. Les donnees de jeu (noms, lumiere...) sont dans
scripts/visual/places.gd ; les decors interactifs gardent leur nom technique (etoile, lune...).
"""
import math
import random
import sys

from PIL import Image

from gen_pixel_art import TILE, from_ascii, mix, rgba, save, shade


def blank():
    return Image.new("RGBA", (TILE, TILE))


def nightmare(img):
    """Version cauchemar d'une tuile : plus sombre, tiree vers le pourpre."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            px[x, y] = shade(mix((r, g, b), (130, 30, 70), 0.35), 0.72) + (a,)
    return out


def blobs(px, rng, count, radius, color, strength, w=TILE, h=TILE):
    """Taches douces (brume, nuages) : melange la couleur vers `color`, plus fort au centre."""
    for _ in range(count):
        cx, cy, r = rng.uniform(0, w), rng.uniform(0, h), rng.uniform(*radius)
        for y in range(h):
            for x in range(w):
                # distance sur un tore : la tache deborde proprement de l'autre cote de la tuile
                dx = min(abs(x - cx), w - abs(x - cx))
                dy = min(abs(y - cy), h - abs(y - cy))
                d = math.hypot(dx, dy) / r
                if d < 1:
                    c = px[x, y]
                    px[x, y] = mix(c[:3], color, strength * (1 - d) ** 2) + (c[3],)


def tiles(night, family, floors, top, face):
    """Ecrit les tuiles reve et cauchemar d'un lieu (4 sols, dessus de mur, facade)."""
    for mood, transform in (("reve", lambda i: i), ("cauchemar", nightmare)):
        name = f"{mood}_{family}"
        for v, img in enumerate(floors):
            save(transform(img), "tiles", night, f"{name}_floor_{v}.png")
        save(transform(top), "tiles", night, f"{name}_wall_top.png")
        save(transform(face), "tiles", night, f"{name}_wall_face.png")


def decors(night, family, sprites):
    for name, (rows, pal) in sprites.items():
        save(from_ascii(rows, pal), "decor", night, family, f"{name}.png")


# --- Lundi (Fatigue) ------------------------------------------------------------------------

def cotton_floor(variant, rng):
    """Couette matelassee : coutures en losange, chaque case bombee comme un coussin."""
    hi, low, stitch = (216, 204, 250), (166, 146, 226), (132, 110, 200)
    img = blank()
    px = img.load()
    cell = 25
    for y in range(TILE):
        for x in range(TILE):
            u, v = (x + y) % cell, (x - y) % cell
            d = min(u, cell - u, v, cell - v)
            c = mix(low, hi, min(1.0, d / 7))
            if d == 0 and (x // 2) % 2 == 0:
                c = stitch
            elif rng.random() < 0.04:
                c = shade(c, 1.04)
            px[x, y] = c + (255,)
    if variant == 1:  # une plume posee
        x0, y0 = rng.randrange(10, 30), rng.randrange(15, 35)
        for i in range(12):
            px[x0 + i, y0 - i // 2] = (250, 248, 255, 255)
            px[x0 + i, y0 - i // 2 + 1] = (214, 206, 240, 255)
        px[x0 - 1, y0 + 1] = (180, 160, 140, 255)
    elif variant == 2:  # boutons de capiton au centre des losanges
        for cx, cy in ((12, 0), (37, 25), (12, 25), (37, 0)):
            cy = (cy + 12) % TILE
            px[cx, cy] = stitch + (255,)
            px[cx + 1, cy] = stitch + (255,)
            px[cx, cy - 1] = (240, 236, 255, 255)
    elif variant == 3:  # un pli
        y0 = rng.randrange(12, 38)
        for x in range(6, 44):
            y = y0 + int(2 * math.sin(x / 5))
            px[x, y] = shade(px[x, y][:3], 0.9) + (255,)
            px[x, y - 1] = shade(px[x, y - 1][:3], 1.05) + (255,)
    return img


def cotton_wall_top(rng):
    """Nuit cotonneuse autour des chemins : indigo, nuages tres doux."""
    img = Image.new("RGBA", (TILE, TILE), (44, 40, 88, 255))
    px = img.load()
    blobs(px, rng, 4, (8, 16), (78, 72, 132), 0.8)
    for _ in range(3):
        px[rng.randrange(TILE), rng.randrange(TILE)] = (230, 226, 255, 255)
    return img


def pillow_wall_face(rng):
    """Piles d'oreillers : trois rangees decalees d'oreillers bombes, coins pinces, sur fond sombre."""
    img = Image.new("RGBA", (TILE, TILE), (70, 60, 124, 255))
    px = img.load()
    rows = [(0, 16), (16, 17), (33, 17)]
    for r, (y0, h) in enumerate(rows):
        off = 12 if r % 2 else 0
        for y in range(y0, y0 + h):
            ly = y - y0
            k = 1.0 - 0.3 * (y / TILE)
            for x in range(TILE):
                lx = (x + off) % 25
                # coins arrondis : on laisse voir le fond entre les oreillers
                corner = min(lx, 24 - lx) + min(ly, h - 1 - ly)
                if lx in (0, 24) or ly in (0, h - 1) or corner < 3:
                    continue
                tuck = abs(lx - 12) < 2 and ly in (1, h - 2)  # pli au milieu des bords
                t = min(1.0, min(lx, 24 - lx, ly, h - 1 - ly) / 4) * (1.0 - ly / (h * 1.5))
                c = (150, 138, 206) if tuck else mix((170, 158, 224), (242, 238, 255), t)
                px[x, y] = shade(c, k) + (255,)
    return img


def moss_floor(variant, rng):
    """Mousse sombre et nappes de brume."""
    img = blank()
    px = img.load()
    for y in range(0, TILE, 2):
        for x in range(0, TILE, 2):
            c = mix((50, 64, 72), (64, 82, 88), rng.random())
            for dy in (0, 1):
                for dx in (0, 1):
                    px[x + dx, y + dy] = c + (255,)
    blobs(px, rng, 2, (8, 14), (112, 124, 140), 0.45)
    if variant == 1:  # flaque de brume
        blobs(px, rng, 1, (12, 16), (150, 160, 176), 0.7)
    elif variant == 2:  # touffes de mousse
        for _ in range(rng.randrange(4, 7)):
            x, y = rng.randrange(2, 47), rng.randrange(3, 47)
            for dx, dy in ((0, 0), (1, 0), (0, -1)):
                px[x + dx, y + dy] = (44, 76, 62, 255)
    elif variant == 3:  # cailloux
        for _ in range(3):
            x, y = rng.randrange(4, 45), rng.randrange(4, 45)
            px[x, y] = px[x + 1, y] = (92, 100, 112, 255)
            px[x, y + 1] = px[x + 1, y + 1] = (36, 44, 52, 255)
    return img


def mist_wall_top(rng):
    img = Image.new("RGBA", (TILE, TILE), (20, 26, 36, 255))
    px = img.load()
    blobs(px, rng, 3, (10, 18), (46, 54, 68), 0.7)
    return img


def curtain_wall_face(rng):
    """Lourds rideaux de velours : plis verticaux, tringle en haut, ourlet en bas."""
    img = blank()
    px = img.load()
    for y in range(TILE):
        k = 1.0 - 0.3 * (y / TILE)
        for x in range(TILE):
            fold = 0.72 + 0.28 * math.cos(2 * math.pi * x / 10)
            c = shade((70, 74, 108), fold * k)
            if y < 3:
                c = (150, 132, 92) if y == 1 else (96, 84, 60)
            elif y > TILE - 5:
                c = shade(c, 0.7)
            px[x, y] = c + (255,)
    return img


LUNDI_PARADOXAL = {
    # etoile (soin) : veilleuse en etoile, branchee au mur, qui dort
    "etoile": ([
        ".....Y.....",
        "....YWY....",
        "YYYYWWWYYYY",
        ".YYkWWWkYY.",
        "..YYWWWYY..",
        "..YYYyYYY..",
        ".YY.....YY.",
        "....ggg....",
        "....GGG....",
    ], {"Y": rgba(255, 220, 110), "W": rgba(255, 250, 210), "y": rgba(214, 160, 70), "k": rgba(150, 100, 60),
        "g": rgba(170, 170, 190), "G": rgba(120, 120, 140)}),
    # lune (guide) : lanterne de papier
    "lune": ([
        "...hhh...",
        "....h....",
        ".PPPPPPP.",
        "PPWWWWWPP",
        "PWWYYYWWP",
        "PWWYYYWWP",
        "PWWWYWWWP",
        "PPWWWWWPP",
        ".PPPPPPP.",
        "...hhh...",
    ], {"h": rgba(120, 100, 170), "P": rgba(150, 130, 210), "W": rgba(248, 246, 255), "Y": rgba(255, 244, 200)}),
    # horloge (pause) : reveil endormi, yeux fermes
    "horloge": ([
        "..BB....BB..",
        ".BBBGGGGBBB.",
        "...GWWWWG...",
        "..GWWWWWWG..",
        ".GWkkWWkkWG.",
        ".GWWWWWWWWG.",
        ".GWWWkkWWWG.",
        "..GWWWWWWG..",
        "...GGGGGG...",
        "..G......G..",
    ], {"B": rgba(230, 180, 80), "G": rgba(214, 150, 70), "W": rgba(252, 246, 232), "k": rgba(60, 40, 50)}),
    # bulle : bulle de baillement, mauve
    "bulle": ([
        "...CCCC...",
        "..CWccccC.",
        ".CWcccccC.",
        "CcWccccccC",
        "CccckkcccC",
        "CccckkcccC",
        ".CccccccC.",
        "..CCCCCC..",
    ], {"C": rgba(206, 186, 255), "W": rgba(255, 255, 255), "c": (206, 186, 255, 70), "k": (120, 90, 170, 150)}),
    "plume": ([
        "........WW",
        "......WWWw",
        ".....WWWw.",
        "....WWWw..",
        "...WWWw...",
        "..WWWw....",
        ".WWw......",
        "Ww........",
        "q.........",
    ], {"W": rgba(252, 250, 255), "w": rgba(200, 194, 232), "q": rgba(170, 150, 130)}),
    "rideau": ([
        "gggggggggg",
        "RrRRrRRrRR",
        "RrRRrRRrRR",
        "RrRRrRRrRR",
        "RrRRrRRrRR",
        "RrRRrRRrRR",
        "RrRRrRRrR.",
        "RrRRrRRr..",
        ".rRRrRR...",
    ], {"g": rgba(200, 170, 110), "R": rgba(190, 176, 240), "r": rgba(146, 130, 206)}),
    "lampe": ([
        "..SSSSS..",
        ".SSSSSSS.",
        "SSSSSSSSS",
        "....k....",
        "....k....",
        "....k....",
        "..BBBBB..",
    ], {"S": rgba(170, 160, 200), "k": rgba(90, 80, 110), "B": rgba(120, 108, 150)}),
}

LUNDI_PROFOND = {
    # bougie (lumiere) : lampe de chevet allumee
    "bougie": ([
        "..YYYYY..",
        ".YYWWWYY.",
        "YYWWWWWYY",
        "....k....",
        "....k....",
        "...kkk...",
        ".BBBBBBB.",
    ], {"Y": rgba(255, 200, 120), "W": rgba(255, 240, 200), "k": rgba(70, 60, 60), "B": rgba(110, 90, 80)}),
    # champignon (combat) : tas de draps qui respire
    "champignon": ([
        ".....SSSS...",
        "...SSSSSSSS.",
        "..SSsSSSSSsS",
        ".SSSSSkkSSSS",
        "SSsSSSSSSSsS",
        "SSSSSSSSSSSS",
        ".ssssssssss.",
    ], {"S": rgba(196, 204, 216), "s": rgba(132, 144, 162), "k": rgba(60, 66, 80)}),
    # cristal (objet) : coffre a jouets
    "cristal": ([
        ".bbbbbbbbbb.",
        "bBBBBBBBBBBb",
        "bBYBBBBBBYBb",
        "bbbbbbbbbbbb",
        "bRRRRRRRRRRb",
        "bRRYRRRRYRRb",
        "bRRRRRRRRRRb",
        ".bbbbbbbbbb.",
    ], {"b": rgba(70, 50, 70), "B": rgba(150, 110, 160), "R": rgba(120, 84, 140), "Y": rgba(240, 220, 140)}),
    "draps": ([
        "kkkkkkkkkk",
        ".SSSSSSSS.",
        ".SSSSSSSS.",
        ".SsSSSSsS.",
        ".SSSSSSSS.",
        ".SSsSSsSS.",
        ".SSSSSSSS.",
        ".S.SS.SS.S",
    ], {"k": rgba(60, 60, 70), "S": rgba(184, 192, 206), "s": rgba(136, 146, 164)}),
    "fauteuil": ([
        ".AAA....AAA.",
        ".AaA....AaA.",
        ".AAAAAAAAAA.",
        "AAaaaaaaaaAA",
        "AAAAAAAAAAAA",
        "mmmmmmmmmmmm",
    ], {"A": rgba(120, 86, 112), "a": rgba(92, 62, 88), "m": rgba(56, 78, 70)}),
}


def lundi():
    rng = random.Random(101)
    tiles("lundi", "paradoxal", [cotton_floor(v, rng) for v in range(4)], cotton_wall_top(rng), pillow_wall_face(rng))
    tiles("lundi", "profond", [moss_floor(v, rng) for v in range(4)], mist_wall_top(rng), curtain_wall_face(rng))
    decors("lundi", "paradoxal", LUNDI_PARADOXAL)
    decors("lundi", "profond", LUNDI_PROFOND)


# --- Mardi (Stress) -------------------------------------------------------------------------

def disc(px, cx, cy, r, color, w=TILE, h=TILE):
    for y in range(max(0, int(cy - r)), min(h, int(cy + r) + 1)):
        for x in range(max(0, int(cx - r)), min(w, int(cx + r) + 1)):
            if math.hypot(x - cx, y - cy) <= r:
                px[x, y] = color + (255,)


def gear(px, cx, cy, r, teeth, color, dark, w=TILE, h=TILE):
    """Rouage : disque denté avec un moyeu, ombré en bas."""
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - cx, y - cy)
            a = (math.atan2(y - cy, x - cx) / (2 * math.pi)) * teeth % 1
            if d <= r * 0.78 or (d <= r and a < 0.5):
                c = dark if d <= r * 0.25 or y > cy + r * 0.5 else color
                if r * 0.25 < d <= r * 0.32:
                    c = shade(color, 1.2)
                px[x, y] = c + (255,)


def gears_floor(variant, rng):
    """Plaque de laiton brossé ; cadran d'horloge ou rouages graves selon la variante."""
    brass, brass2 = (190, 146, 80), (206, 162, 94)
    img = blank()
    px = img.load()
    for y in range(TILE):
        for x in range(TILE):
            c = mix(brass, brass2, (math.sin(y * 1.7 + x * 0.05) + 1) / 2 * 0.6 + rng.random() * 0.2)
            if x in (0, TILE - 1) or y in (0, TILE - 1):
                c = shade(brass, 0.7)
            px[x, y] = c + (255,)
    for cx, cy in ((3, 3), (46, 3), (3, 46), (46, 46)):  # rivets
        px[cx, cy] = (240, 210, 140, 255)
        px[cx + 1, cy + 1] = (120, 84, 40, 255)
    if variant == 0:  # cadran
        disc(px, 25, 25, 20, (120, 84, 40))
        disc(px, 25, 25, 18, (238, 228, 204))
        for i in range(12):
            a = i * math.pi / 6
            r0 = 14 if i % 3 else 12
            for r in range(r0, 17):
                px[int(25 + r * math.cos(a)), int(25 + r * math.sin(a))] = (90, 70, 60, 255)
        for r in range(10):  # aiguilles
            px[25, 25 - r] = (60, 40, 40, 255)
        for r in range(7):
            px[25 + r, 25] = (60, 40, 40, 255)
    elif variant == 1:  # rouages graves
        gear(px, 16, 20, 11, 8, (176, 132, 70), (140, 100, 50))
        gear(px, 34, 34, 9, 7, (176, 132, 70), (140, 100, 50))
    elif variant == 3:  # un petit rouage dans un coin
        gear(px, 38, 12, 7, 7, (176, 132, 70), (140, 100, 50))
    return img


def gears_wall_top(rng):
    img = Image.new("RGBA", (TILE, TILE), (38, 28, 20, 255))
    px = img.load()
    gear(px, rng.randrange(10, 40), rng.randrange(10, 40), 12, 9, (52, 40, 28), (44, 33, 24))
    return img


def gears_wall_face(rng):
    """Rouages imbriqués sur fond de laiton sombre."""
    img = Image.new("RGBA", (TILE, TILE), (92, 66, 36, 255))
    px = img.load()
    gear(px, 12, 16, 13, 10, (214, 168, 90), (150, 108, 52))
    gear(px, 37, 30, 14, 11, (196, 150, 78), (138, 98, 46))
    gear(px, 6, 44, 8, 7, (230, 190, 110), (160, 118, 60))
    for y in range(TILE):
        k = 1.0 - 0.3 * (y / TILE)
        for x in range(TILE):
            px[x, y] = shade(px[x, y][:3], k) + (255,)
    for x in range(TILE):
        px[x, 0] = px[x, 1] = (230, 196, 120, 255)
    return img


def parquet_floor(variant, rng):
    """Parquet noir ciré : lames horizontales, veinage, reflets."""
    img = blank()
    px = img.load()
    plank = 8
    for y in range(TILE):
        row = y // plank
        off = (row * 19) % TILE
        tone = (row * 0.37) % 1
        for x in range(TILE):
            seam = (x + off) % TILE == 0
            c = mix((44, 30, 30), (60, 40, 36), (math.sin((x + row * 7) * 0.4) + 1) / 4 + tone * 0.5)
            if y % plank == 0 or seam:
                c = (26, 16, 16)
            elif y % plank == 1:
                c = shade(c, 1.25)
            px[x, y] = c + (255,)
    if variant == 1:  # noeuds du bois
        for _ in range(2):
            x, y = rng.randrange(5, 44), rng.randrange(3, 46)
            px[x, y] = px[x + 1, y] = (30, 18, 18, 255)
    elif variant == 2:  # papiers froisses
        for _ in range(2):
            x, y = rng.randrange(6, 40), rng.randrange(6, 40)
            for dx, dy in ((0, 0), (1, 0), (2, 1), (0, 1), (1, 1), (1, 2)):
                px[x + dx, y + dy] = (226, 218, 200, 255)
    elif variant == 3:  # reflet de cire
        for x in range(8, 40):
            px[x, 24] = shade(px[x, 24][:3], 1.4) + (255,)
    return img


def dark_wall_top(rng):
    img = Image.new("RGBA", (TILE, TILE), (20, 10, 12, 255))
    px = img.load()
    blobs(px, rng, 2, (10, 16), (40, 16, 20), 0.6)
    return img


def panel_wall_face(rng):
    """Boiseries sombres : panneaux moulurés, liseré bordeaux."""
    img = Image.new("RGBA", (TILE, TILE), (64, 40, 34, 255))
    px = img.load()
    for y in range(TILE):
        k = 1.0 - 0.3 * (y / TILE)
        for x in range(TILE):
            lx = x % 25
            c = (64, 40, 34)
            if 4 <= lx <= 20 and 8 <= y <= 42:
                c = (52, 32, 28)
                if lx in (4, 20) or y in (8, 42):
                    c = (90, 58, 46)
            if y < 3:
                c = (120, 30, 44)
            px[x, y] = shade(c, k) + (255,)
    return img


MARDI_PARADOXAL = {
    "etoile": ([  # etoile doree de bonne note
        ".....Y.....", "....YWY....", "YYYYWWWYYYY", ".YYWYYYWYY.", "..YYYYYYY..", "..YYYyYYY..",
        ".YYy...yYY.", "rr.......rr", ".r.......r.",
    ], {"Y": rgba(255, 210, 70), "W": rgba(255, 250, 200), "y": rgba(200, 140, 40), "r": rgba(220, 70, 80)}),
    "lune": ([  # boussole
        "..GGGGG..", ".GWWRWWG.", "GWWWRWWWG", "GWWWkWWWG", "GWWWBWWWG", ".GWWBWWG.", "..GGGGG..",
    ], {"G": rgba(200, 150, 70), "W": rgba(250, 244, 226), "R": rgba(220, 60, 60), "B": rgba(70, 90, 160), "k": rgba(40, 30, 30)}),
    "horloge": ([  # sablier retourne
        "GGGGGGGG", ".gssssg.", "..gssg..", "...gS...", "...SS...", "..gSSg..", ".gSSSSg.", "GGGGGGGG",
    ], {"G": rgba(170, 110, 60), "g": rgba(200, 230, 255), "s": rgba(170, 210, 235), "S": rgba(240, 210, 120)}),
    "bulle": ([  # bulle de stress
        "...CCCC...", "..CWccccC.", ".CWcccccC.", "CccrcrcccC", "CcrcrcrccC", "CccccccccC", ".CccccccC.", "..CCCCCC..",
    ], {"C": rgba(255, 160, 140), "W": rgba(255, 255, 255), "c": (255, 160, 140, 70), "r": (220, 60, 60, 200)}),
    "aiguille": ([
        "...k...", "..kkk..", ".kkkkk.", "...k...", "...k...", "...k...", "...k...", "..GGG..", ".GGGGG.",
    ], {"k": rgba(60, 40, 40), "G": rgba(170, 130, 70)}),
    "feuilles": ([
        "WWWW......", "WkkW..WWW.", "WWWW..WkW.", "WkkW..WWW.", "WWWW......", "....WWWW..", "....WkkW..", "....WWWW..",
    ], {"W": rgba(244, 240, 228), "k": rgba(140, 140, 160)}),
    "rouage": ([
        "..G.GG.G..", ".GGGGGGGG.", "GGGgggGGGG", ".GgG..gGG.", "GGg....gGG", "GGg....gGG", ".GgG..gGG.",
        "GGGgggGGGG", ".GGGGGGGG.", "..G.GG.G..",
    ], {"G": rgba(206, 160, 86), "g": rgba(150, 108, 52)}),
}

MARDI_PROFOND = {
    "bougie": ([  # lampe de bureau
        "...YYYY..", "..YYWWY..", ".YYWWWY..", "...kk....", "..k......", ".k.......", "kk.......", "BBBBB....",
    ], {"Y": rgba(255, 200, 110), "W": rgba(255, 240, 200), "k": rgba(60, 60, 60), "B": rgba(80, 60, 50)}),
    "champignon": ([  # reveil qui sonne
        "y.TT...TT.y", ".TTTCCCTTT.", "..CWWWWWC..", ".CWWWkWWWC.", ".CWWWkWWWC.", ".CWWWkkWWC.",
        "..CWWWWWC..", "y..CCCCC..y", "..C.....C..",
    ], {"T": rgba(90, 220, 200), "C": rgba(60, 170, 160), "W": rgba(240, 250, 250), "k": rgba(30, 40, 40), "y": rgba(150, 255, 240)}),
    "cristal": ([  # tiroir verrouille
        "bbbbbbbbbbbb", "bDDDDDDDDDDb", "bDDDDLLDDDDb", "bDDDDLLDDDDb", "bDDDDDDDDDDb", "bbbbbbbbbbbb",
    ], {"b": rgba(50, 30, 30), "D": rgba(110, 70, 120), "L": rgba(220, 190, 255)}),
    "balancier": ([
        "....k....", "....k....", "....k....", "....k....", "....k....", "...GGG...", "..GGWGG..", "..GGGGG..", "...GGG...",
    ], {"k": rgba(120, 90, 50), "G": rgba(200, 160, 80), "W": rgba(255, 230, 160)}),
    "papiers": ([
        "..WW.....", ".WWWW.WW.", "WWkWWWWWW", ".WWWWkWW.", "..WWWWW..",
    ], {"W": rgba(214, 206, 190), "k": rgba(140, 130, 120)}),
    "comtoise": ([
        "..BBBBB..", ".BWWWWWB.", ".BWWkWWB.", ".BWWkkWB.", ".BBBBBBB.", "..BdddB..", "..BdGdB..", "..BdGdB..",
        "..BdddB..", ".BBBBBBB.",
    ], {"B": rgba(70, 40, 30), "W": rgba(230, 220, 200), "k": rgba(30, 20, 20), "d": rgba(40, 24, 20), "G": rgba(200, 160, 80)}),
}


def mardi():
    rng = random.Random(202)
    tiles("mardi", "paradoxal", [gears_floor(v, rng) for v in range(4)], gears_wall_top(rng), gears_wall_face(rng))
    tiles("mardi", "profond", [parquet_floor(v, rng) for v in range(4)], dark_wall_top(rng), panel_wall_face(rng))
    decors("mardi", "paradoxal", MARDI_PARADOXAL)
    decors("mardi", "profond", MARDI_PROFOND)


# --- Mercredi (Doute) -----------------------------------------------------------------------

def mirror_floor(variant, rng):
    """Carrelage-miroir : damier argent et nacre, reflets en diagonale."""
    img = blank()
    px = img.load()
    a, b, joint = (178, 198, 224), (214, 198, 226), (120, 130, 168)
    for y in range(TILE):
        for x in range(TILE):
            c = a if ((x // 25) + (y // 25)) % 2 == 0 else b
            c = mix(c, (255, 255, 255), max(0.0, 0.5 - abs(((x + y) % 25) - 6) / 6) * 0.6)  # reflet
            c = shade(c, 1.0 - 0.12 * ((y % 25) / 25))
            if x % 25 == 0 or y % 25 == 0:
                c = joint
            px[x, y] = c + (255,)
    if variant == 1:  # un reflet de silhouette, a peine visible
        for y in range(8, 40):
            for x in range(18, 32):
                d = math.hypot((x - 25) / 6, (y - 14) / 5) if y < 20 else abs(x - 25) / 7 + (y - 20) / 60
                if d < 1:
                    px[x, y] = shade(px[x, y][:3], 0.9) + (255,)
    elif variant == 2:  # eclats irises
        for _ in range(4):
            x, y = rng.randrange(3, 47), rng.randrange(3, 47)
            px[x, y] = rng.choice([(255, 200, 240), (200, 240, 255), (255, 255, 210)]) + (255,)
    elif variant == 3:  # fissure dans le miroir
        x, y = rng.randrange(10, 40), 2
        while y < 48:
            px[x, y] = (250, 250, 255, 255)
            x = max(1, min(48, x + rng.choice([-1, 0, 1])))
            y += 1
    return img


def mirror_wall_top(rng):
    img = Image.new("RGBA", (TILE, TILE), (30, 34, 62, 255))
    px = img.load()
    for i in range(0, TILE, 10):
        for k in range(6):
            x, y = (i + k) % TILE, (i * 3 + k) % TILE
            px[x, y] = (54, 60, 100, 255)
    return img


def glass_wall_face(rng):
    """Parois de verre : panneaux bleutes encadres, reflets verticaux."""
    img = blank()
    px = img.load()
    for y in range(TILE):
        k = 1.0 - 0.3 * (y / TILE)
        for x in range(TILE):
            lx = x % 25
            c = mix((150, 190, 226), (200, 222, 244), 0.5 + 0.5 * math.sin(lx / 3.5))
            if lx in (0, 24) or y in (0, 1):
                c = (196, 200, 220)
            elif lx in (5, 6) and y > 4:
                c = (236, 244, 255)
            px[x, y] = shade(c, k) + (255,)
    return img


def cobble_floor(variant, rng):
    """Vieux paves gris-vert, joints sombres ; mousse, flaque ou pave fendu."""
    img = Image.new("RGBA", (TILE, TILE), (40, 48, 44, 255))
    px = img.load()
    stones = []
    for row in range(5):
        x = -(row % 2) * 5
        while x < TILE:
            w = rng.randrange(8, 13)
            stones.append((x, row * 10, w, 10))
            x += w
    for sx, sy, w, h in stones:
        tone = rng.random()
        for y in range(sy + 1, sy + h - 1):
            for x in range(sx + 1, sx + w - 1):
                cx = x % TILE
                edge = min(x - sx, sx + w - 1 - x, y - sy, sy + h - 1 - y)
                c = mix((94, 106, 100), (120, 130, 120), tone)
                c = shade(c, 0.85 if edge <= 1 and y > sy + h / 2 else (1.1 if edge <= 1 else 1.0))
                px[cx, y] = c + (255,)
    if variant == 1:  # mousse entre les paves
        for _ in range(10):
            x, y = rng.randrange(TILE), rng.choice([0, 10, 20, 30, 40]) + rng.choice([0, 9])
            px[x, min(y, TILE - 1)] = (70, 110, 70, 255)
    elif variant == 2:  # flaque
        blobs(px, rng, 1, (7, 10), (130, 150, 160), 0.6)
    return img


def fog_wall_top(rng):
    img = Image.new("RGBA", (TILE, TILE), (24, 32, 30, 255))
    px = img.load()
    blobs(px, rng, 3, (10, 18), (54, 64, 62), 0.6)
    return img


def hedge_wall_face(rng):
    """Haies taillees : feuillage dense, plus clair en haut."""
    img = blank()
    px = img.load()
    for y in range(TILE):
        k = 1.05 - 0.4 * (y / TILE)
        for x in range(TILE):
            c = mix((36, 70, 46), (58, 98, 62), rng.random())
            if rng.random() < 0.08:
                c = (78, 120, 76)
            px[x, y] = shade(c, k) + (255,)
    for x in range(TILE):
        px[x, 0] = (96, 140, 90, 255)
    return img


MERCREDI_PARADOXAL = {
    "etoile": ([  # reflet d'etoile : une etoile et son double
        "....Y....y..", "...YWY..yWy.", "YYYWWWyyyWWy", ".YYWWWYyWWy.", "..YY.YYyy.y.", ".YY...YY..y.",
    ], {"Y": rgba(255, 220, 110), "W": rgba(255, 250, 220), "y": rgba(200, 220, 255)}),
    "lune": ([  # fil d'Ariane : pelote de fil rouge
        "....RRRR..", "..RRrRRrR.", ".RrRRRrRRR", ".RRRrRRRrR", ".RrRRRRrRR", "..RRrRRRR.", "....RRR...", "RRRR......",
    ], {"R": rgba(230, 70, 80), "r": rgba(160, 40, 60)}),
    "horloge": ([  # piece figee en plein vol
        ".w..GGGG..w", "...GYYYYG..", "w.GYYgYYYG.", "..GYgYgYYG.", "..GYYgYYYG.", "w..GYYYYG..", "....GGGG..w",
    ], {"G": rgba(200, 150, 60), "Y": rgba(255, 220, 110), "g": rgba(214, 160, 70), "w": rgba(220, 230, 255)}),
    "bulle": ([  # bulle-point d'interrogation
        "...CCCC...", "..CccccC..", ".CcckkccC.", "CccccckccC", "CcccckcccC", "CccccccccC", ".CccckccC.", "..CCCCCC..",
    ], {"C": rgba(200, 220, 255), "c": (200, 220, 255, 70), "k": (90, 100, 160, 220)}),
    "cadre": ([
        "GGGGGGGGGG", "GgggggggGG", "Gg......gG", "Gg......gG", "Gg......gG", "Gg......gG", "GgggggggGG", "GGGGGGGGGG",
    ], {"G": rgba(220, 190, 110), "g": rgba(170, 130, 70)}),
    "statue": ([
        "...SSS...", "..SSSSS..", "..SSSSS..", "...SSS...", "..SSSSS..", ".SSSSSSS.", ".SsSSSsS.", "..SSSSS..", ".BBBBBBB.",
    ], {"S": rgba(220, 222, 232), "s": rgba(170, 172, 190), "B": rgba(140, 140, 160)}),
    "escalier": ([
        "......WW", "....WWWW", "....wwWW", "..WWWWWW", "..wwwwWW", "WWWWWWWW", "wwwwwwWW",
    ], {"W": rgba(230, 226, 244), "w": rgba(170, 166, 200)}),
}

MERCREDI_PROFOND = {
    "bougie": ([  # lampadaire allume
        "..YYY..", ".YWWWY.", ".YYYYY.", "...k...", "...k...", "...k...", "...k...", "...k...", "..kkk..",
    ], {"Y": rgba(255, 200, 120), "W": rgba(255, 240, 200), "k": rgba(50, 56, 60)}),
    "champignon": ([  # masque pose au sol
        "..WWWWWW..", ".WWWWWWWW.", "WWkkWWkkWW", "WWWWWWWWWW", ".WWWkkWWW.", "..WWWWWW..",
    ], {"W": rgba(230, 240, 238), "k": rgba(40, 60, 64)}),
    "cristal": ([  # valise abandonnee
        "...kkkk...", "...k..k...", "BBBBBBBBBB", "BbBBBBBBbB", "BBBBYYBBBB", "BbBBBBBBbB", "BBBBBBBBBB",
    ], {"k": rgba(60, 40, 30), "B": rgba(130, 90, 140), "b": rgba(100, 66, 110), "Y": rgba(230, 200, 120)}),
    "panneau": ([
        "WWWWWW...", "WWWWWWW..", "WWWWWW...", "..k......", "...WWWWWW", "..WWWWWWW", "...WWWWWW", "....k....", "....k....",
    ], {"W": rgba(200, 186, 150), "k": rgba(90, 70, 50)}),
    "banc": ([
        "BBBBBBBBBBBB", "bbbbbbbbbbbb", "BBBBBBBBBBBB", ".k........k.", ".k........k.",
    ], {"B": rgba(120, 96, 70), "b": rgba(90, 70, 50), "k": rgba(50, 50, 56)}),
}


def mercredi():
    rng = random.Random(303)
    tiles("mercredi", "paradoxal", [mirror_floor(v, rng) for v in range(4)], mirror_wall_top(rng), glass_wall_face(rng))
    tiles("mercredi", "profond", [cobble_floor(v, rng) for v in range(4)], fog_wall_top(rng), hedge_wall_face(rng))
    decors("mercredi", "paradoxal", MERCREDI_PARADOXAL)
    decors("mercredi", "profond", MERCREDI_PROFOND)


# --- Jeudi (Frustration) --------------------------------------------------------------------

def queue_floor(variant, rng):
    """Dalles de beton gris ; bande jaune de file d'attente, fleche peinte ou ticket."""
    img = blank()
    px = img.load()
    for y in range(TILE):
        for x in range(TILE):
            c = mix((132, 134, 140), (150, 152, 158), rng.random() * 0.5 + 0.25)
            if x % 25 == 0 or y % 25 == 0:
                c = (98, 100, 108)
            px[x, y] = c + (255,)
    if variant == 1:  # bande jaune et noire
        for y in range(21, 29):
            for x in range(TILE):
                px[x, y] = ((236, 190, 40) if ((x + y) // 4) % 2 == 0 else (40, 38, 40)) + (255,)
    elif variant == 2:  # fleche peinte
        for i in range(12):
            px[19 + i, 25] = (230, 230, 236, 255)
        for i in range(5):
            px[30 - i, 25 - i] = px[30 - i, 25 + i] = (230, 230, 236, 255)
    elif variant == 3:  # ticket tombe
        for y in range(30, 36):
            for x in range(14, 24):
                px[x, y] = (236, 220, 170, 255) if y not in (30, 35) else (200, 160, 80, 255)
        px[18, 32] = px[19, 32] = (200, 70, 60, 255)
    return img


def steel_wall_top(rng):
    img = Image.new("RGBA", (TILE, TILE), (34, 36, 42, 255))
    px = img.load()
    for y in range(4, TILE, 12):
        for x in range(4, TILE, 12):
            px[x, y] = (70, 72, 80, 255)
    return img


def counter_wall_face(rng):
    """Guichet ferme : rideau metallique baisse sous un bandeau orange."""
    img = blank()
    px = img.load()
    for y in range(TILE):
        k = 1.0 - 0.25 * (y / TILE)
        for x in range(TILE):
            if y < 8:
                c = (232, 130, 40) if 1 < y < 7 else (90, 50, 20)
            elif x % 25 in (0, 24):
                c = (70, 72, 80)
            else:
                c = (150, 154, 162) if (y // 3) % 2 == 0 else (120, 124, 132)
            px[x, y] = shade(c, k) + (255,)
    for x in (10, 11, 35, 36):  # cadenas
        px[x, 44] = px[x, 45] = (220, 180, 60, 255)
    return img


def furnace_floor(variant, rng):
    """Plaques de metal sombre rivetees ; fissures de braise."""
    img = blank()
    px = img.load()
    for y in range(TILE):
        for x in range(TILE):
            c = mix((58, 44, 44), (70, 54, 52), rng.random() * 0.4 + 0.3)
            if x % 25 == 0 or y % 25 == 0:
                c = (30, 22, 22)
            elif x % 25 == 1 or y % 25 == 1:
                c = shade(c, 1.2)
            px[x, y] = c + (255,)
    for cx in (4, 21, 29, 46):
        for cy in (4, 21, 29, 46):
            px[cx, cy] = (120, 100, 96, 255)
    if variant == 1:  # longue fissure rougeoyante en travers de la plaque
        x, y = rng.randrange(4, 12), rng.randrange(4, 12)
        while x < 46 and y < 46:
            px[x, y] = (255, 130, 50, 255)
            px[x, y + 1] = (150, 50, 30, 255)
            x += 1
            y += rng.choice([0, 1, 1])
    return img


def ember_wall_top(rng):
    img = Image.new("RGBA", (TILE, TILE), (18, 10, 10, 255))
    px = img.load()
    for _ in range(5):
        px[rng.randrange(TILE), rng.randrange(TILE)] = (200, 80, 30, 255)
    return img


def hot_brick_wall_face(rng):
    """Briques chauffees au rouge, plus brulantes vers le bas."""
    img = blank()
    px = img.load()
    for y in range(TILE):
        row = y // 10
        off = 8 if row % 2 else 0
        heat = y / TILE
        for x in range(TILE):
            c = mix((110, 36, 30), (220, 90, 40), heat * 0.7 + rng.random() * 0.15)
            if y % 10 == 0 or (x + off) % 16 == 0:
                c = (40, 16, 14)
            px[x, y] = c + (255,)
    return img


JEUDI_PARADOXAL = {
    "etoile": ([  # ticket gagnant dore
        "YYYYYYYYYYY", "Y.y.y.y.y.Y", "YWWWWWWWWWY", "YWkkWWWkkWY", "YWWWWWWWWWY", "Y.y.y.y.y.Y", "YYYYYYYYYYY",
    ], {"Y": rgba(255, 210, 70), "y": rgba(200, 150, 40), "W": rgba(255, 246, 200), "k": rgba(200, 80, 60)}),
    "lune": ([  # panneau SORTIE vert
        "GGGGGGGGGG", "GWGWWGWWWG", "GWWGWWGWWG", "GWGWWGWWWG", "GGGGGGGGGG", "....kk....", "....kk....",
    ], {"G": rgba(60, 190, 100), "W": rgba(230, 255, 230), "k": rgba(70, 70, 80)}),
    "horloge": ([  # feu rouge
        ".kkkk.", "kRRRRk", "kRRRRk", "kkkkkk", "kyyyyk", "kkkkkk", "kggggk", ".kkkk.", "..kk..", "..kk..",
    ], {"k": rgba(40, 40, 46), "R": rgba(255, 70, 60), "y": rgba(110, 90, 40), "g": rgba(40, 80, 50)}),
    "bulle": ([  # bulle de colere
        "...CCCC...", "..CccccC..", ".CccrcrcC.", "CcccrrccC.", "CccrcrcccC", "CccccccccC", ".CccccccC.", "..CCCCCC..",
    ], {"C": rgba(255, 120, 110), "c": (255, 120, 110, 70), "r": (200, 30, 40, 230)}),
    "barriere": ([
        ".k........k.", "kRRRRRRRRRRk", ".k........k.", ".k........k.", ".k........k.", "kkk......kkk",
    ], {"k": rgba(70, 72, 80), "R": rgba(220, 60, 60)}),
    "tampon": ([
        "...HHH...", "...HHH...", "..HHHHH..", ".RRRRRRR.", ".RWRWRWR.", ".RRRRRRR.",
    ], {"H": rgba(130, 90, 60), "R": rgba(200, 50, 50), "W": rgba(255, 220, 220)}),
    "tickets": ([
        "..WWWW....", ".WWkWWW...", "WWWWWWWWW.", ".WWWkWWWWW", "..WWWWWW..",
    ], {"W": rgba(236, 220, 170), "k": rgba(200, 80, 60)}),
}

JEUDI_PROFOND = {
    "bougie": ([  # tas de braises
        "....Y.....", "...YOY..Y.", "..YOROY.YO", ".OORRROOOR", "kkRRkRRkkk", "kkkkkkkkkk",
    ], {"Y": rgba(255, 220, 100), "O": rgba(255, 140, 40), "R": rgba(200, 50, 30), "k": rgba(50, 40, 40)}),
    "champignon": ([  # cocotte qui siffle
        "....C.....", "...CsC....", "..kkkkk...", ".kTTTTTk..", "kkkkkkkkkk", ".TTTTTTTT.", ".TTTTTTTT.", "..TTTTTT..",
    ], {"C": rgba(200, 255, 250), "s": rgba(140, 240, 230), "k": rgba(40, 60, 64), "T": rgba(80, 190, 180)}),
    "cristal": ([  # coffre-fort
        "kkkkkkkkkk", "kSSSSSSSSk", "kSSWWWSSSk", "kSWSSSWSSk", "kSWSPSWSSk", "kSSWWWSSSk", "kSSSSSSSSk", "kkkkkkkkkk",
    ], {"k": rgba(40, 40, 48), "S": rgba(110, 90, 130), "W": rgba(190, 170, 220), "P": rgba(230, 200, 255)}),
    "tuyau": ([
        "PPPPPPPPPP", "pPPPPPPPPp", "PPPPPPPPPP", "..PP..PP..", "..PP..PP..",
    ], {"P": rgba(120, 104, 100), "p": rgba(160, 140, 130)}),
    "chaudiere": ([
        "..kk..", ".BBBB.", "BBBBBB", "BOOOOB", "BORROB", "BOOOOB", "BBBBBB", "kk..kk",
    ], {"k": rgba(50, 40, 40), "B": rgba(90, 70, 66), "O": rgba(255, 140, 40), "R": rgba(255, 220, 120)}),
}
# Barriere des « Portes closes » (regle du jeudi), une par case bloquee.
JEUDI_PORTE = ([
    "kRRRRRRRRRRRRRRk", "kWWWWWWWWWWWWWWk", "kRRRRRRRRRRRRRRk", "k..k...k...k...k", "k..k...k...k...k",
    "kRRRRRRRRRRRRRRk", "kWWWWWWWWWWWWWWk", "kRRRRRRRRRRRRRRk", "k..k...k...k...k", "kk.kk.kkk.kk.kkk",
], {"k": rgba(60, 62, 70), "R": rgba(220, 60, 50), "W": rgba(250, 240, 230)})


def jeudi():
    rng = random.Random(404)
    tiles("jeudi", "paradoxal", [queue_floor(v, rng) for v in range(4)], steel_wall_top(rng), counter_wall_face(rng))
    tiles("jeudi", "profond", [furnace_floor(v, rng) for v in range(4)], ember_wall_top(rng), hot_brick_wall_face(rng))
    decors("jeudi", "paradoxal", JEUDI_PARADOXAL)
    decors("jeudi", "profond", JEUDI_PROFOND)
    save(from_ascii(*JEUDI_PORTE), "decor", "jeudi", "porte_close.png")


# --- Vendredi (Epuisement) ------------------------------------------------------------------

def tape_floor(variant, rng):
    """Parquet clair de demenagement, rubans adhesifs colles en croix."""
    img = blank()
    px = img.load()
    for y in range(TILE):
        row = y // 8
        off = (row * 23) % TILE
        tone = (row * 0.41) % 1
        for x in range(TILE):
            c = mix((204, 170, 120), (222, 190, 140), tone * 0.7 + (math.sin(x * 0.5 + row) + 1) * 0.1)
            if y % 8 == 0 or (x + off) % TILE == 0:
                c = (160, 124, 84)
            px[x, y] = c + (255,)
    if variant in (1, 2):  # ruban adhesif
        horizontal = variant == 1
        start = rng.randrange(14, 30)
        for i in range(TILE):
            for w in range(5):
                x, y = (i, start + w) if horizontal else (start + w, i)
                px[x, y] = ((186, 140, 80) if w in (0, 4) else (210, 168, 104)) + (255,)
    elif variant == 3:  # croix de ruban
        for i in range(8, 42):
            for w in range(4):
                px[i, i + w - 2] = (210, 168, 104, 255)
                px[i, 49 - i + w - 2] = (210, 168, 104, 255)
    return img


def box_wall_top(rng):
    img = Image.new("RGBA", (TILE, TILE), (52, 38, 30, 255))
    px = img.load()
    for _ in range(3):
        x0, y0, w, h = rng.randrange(0, 36), rng.randrange(0, 36), rng.randrange(10, 16), rng.randrange(8, 14)
        for y in range(y0, min(TILE, y0 + h)):
            for x in range(x0, min(TILE, x0 + w)):
                px[x, y] = (66, 50, 38, 255)
    return img


def box_wall_face(rng):
    """Cartons empiles : kraft, ruban au milieu, bords plus sombres."""
    img = Image.new("RGBA", (TILE, TILE), (120, 90, 60, 255))
    px = img.load()
    boxes = [(0, 0, 26, 18), (26, 0, 24, 18), (0, 18, 18, 16), (18, 18, 32, 16), (0, 34, 30, 16), (30, 34, 20, 16)]
    for bx, by, w, h in boxes:
        tone = rng.random()
        for y in range(by, by + h):
            for x in range(bx, bx + w):
                c = mix((190, 148, 96), (206, 164, 110), tone)
                if x in (bx, bx + w - 1) or y in (by, by + h - 1):
                    c = (120, 88, 56)
                elif abs(x - (bx + w // 2)) <= 1:
                    c = (220, 190, 130)  # ruban
                px[x, y] = shade(c, 1.0 - 0.25 * (y / TILE)) + (255,)
    return img


def mine_floor(variant, rng):
    """Roche sombre et graviers ; rails ou eclats de plomb."""
    img = blank()
    px = img.load()
    for y in range(0, TILE, 2):
        for x in range(0, TILE, 2):
            c = mix((50, 54, 66), (66, 70, 84), rng.random())
            for dy in (0, 1):
                for dx in (0, 1):
                    px[x + dx, y + dy] = c + (255,)
    if variant == 1:  # bout de rails abandonne
        for x in range(TILE):
            for y in (18, 31):
                px[x, y] = (150, 150, 160, 255)
                px[x, y + 1] = (80, 80, 92, 255)
            if x % 8 < 3:
                for y in range(16, 35):
                    if y not in (18, 19, 31, 32):
                        px[x, y] = (96, 70, 50, 255)
    elif variant == 2:  # eclats de plomb
        for _ in range(6):
            x, y = rng.randrange(2, 47), rng.randrange(2, 47)
            px[x, y] = (150, 156, 170, 255)
    return img


def mine_wall_top(rng):
    img = Image.new("RGBA", (TILE, TILE), (16, 18, 26, 255))
    px = img.load()
    blobs(px, rng, 2, (8, 14), (28, 30, 40), 0.6)
    return img


def timber_wall_face(rng):
    """Roche etayee : poutres de bois verticales et linteau."""
    img = blank()
    px = img.load()
    for y in range(TILE):
        k = 1.0 - 0.3 * (y / TILE)
        for x in range(TILE):
            c = mix((58, 60, 72), (76, 78, 90), rng.random())
            if x % 25 in range(2, 7) or y < 6:
                c = (120, 86, 56) if (x + y) % 7 else (96, 68, 44)
            px[x, y] = shade(c, k) + (255,)
    return img


VENDREDI_PARADOXAL = {
    "etoile": ([  # tasse de the chaud
        "..s.s....", "...s.s...", "WWWWWWW..", "WttttWWWW", "WttttW..W", "WttttWWWW", "WWWWWWW..", "ggggggggg",
    ], {"W": rgba(250, 246, 236), "t": rgba(230, 170, 80), "s": rgba(220, 220, 230), "g": rgba(180, 150, 110)}),
    "lune": ([  # phare de poche (lampe torche)
        "......YY", "....YYWY", "kkkkGGWY", "kkkkGGWY", "....YYWY", "......YY",
    ], {"k": rgba(70, 60, 60), "G": rgba(150, 150, 160), "Y": rgba(255, 240, 180), "W": rgba(255, 255, 230)}),
    "horloge": ([  # banc
        "BBBBBBBBBBBB", "bbbbbbbbbbbb", "............", "BBBBBBBBBBBB", "bbbbbbbbbbbb", ".k........k.", ".k........k.",
    ], {"B": rgba(200, 150, 90), "b": rgba(150, 104, 60), "k": rgba(70, 60, 60)}),
    "bulle": ([  # bulle de soupir
        "...CCCC...", "..CWccccC.", ".CWcccccC.", "CccccccccC", "CcckkkcccC", "CccccccccC", ".CccccccC.", "..CCCCCC..",
    ], {"C": rgba(230, 210, 180), "W": rgba(255, 255, 255), "c": (230, 210, 180, 70), "k": (140, 110, 80, 200)}),
    "carton": ([
        "TTTTTTTTTT", "TBBBBYBBBT", "TBBBBYBBBT", "TBBBBYBBBT", "TBBBBYBBBT", "TTTTTTTTTT",
    ], {"T": rgba(140, 100, 60), "B": rgba(200, 156, 100), "Y": rgba(226, 196, 136)}),
    "sac": ([
        "...kk...", "..BBBB..", ".BBBBBB.", "BBbBBBBB", "BBBBBbBB", "BBBBBBBB", ".BBBBBB.",
    ], {"k": rgba(90, 70, 50), "B": rgba(170, 150, 120), "b": rgba(130, 110, 86)}),
    "pile": ([
        "...TTTTT", "...TBBBT", "..TTTTTT.", "..TBBBBT.", ".TTTTTTT.", ".TBBBBBT.", "TTTTTTTT.", "TBBBBBBT.",
    ], {"T": rgba(140, 100, 60), "B": rgba(200, 156, 100)}),
}

VENDREDI_PROFOND = {
    "bougie": ([  # lampe de mineur
        "..kkk..", ".kYYYk.", ".kYWYk.", ".kYYYk.", "..kkk..", "...k...", "..kkk..",
    ], {"k": rgba(70, 70, 80), "Y": rgba(255, 200, 110), "W": rgba(255, 240, 200)}),
    "champignon": ([  # sac qui bouge
        ".....kk...", "...TTTTT..", "..TTTTTTT.", ".TTtTTTTTT", "TTTTTTtTTT", "TTTTTTTTTT", ".TTTTTTTT.",
    ], {"k": rgba(40, 60, 60), "T": rgba(90, 170, 160), "t": rgba(60, 120, 116)}),
    "cristal": ([  # filon
        "RRRRRRRRR", "RRVRRRRRR", "RVVVRRVRR", "RRVRRVVVR", "RRRRRRVRR", "RRRRRRRRR",
    ], {"R": rgba(70, 72, 86), "V": rgba(190, 150, 255)}),
    "wagonnet": ([
        "kkkkkkkkkk", "kGGGGGGGGk", "kGrGrGrGGk", ".kGGGGGGk.", ".kkkkkkkk.", "..O....O..",
    ], {"k": rgba(50, 50, 60), "G": rgba(110, 100, 96), "r": rgba(150, 150, 160), "O": rgba(40, 40, 46)}),
    "pioche": ([
        "GGGGGGG.", "G..W...G", "...W....", "...W....", "...W....", "...W....",
    ], {"G": rgba(160, 160, 176), "W": rgba(130, 96, 60)}),
    "gravats": ([
        "...rr.....", ".rRRr..r..", "rRRRRrrRr.", "rrrrrrrrrr",
    ], {"R": rgba(96, 98, 110), "r": rgba(66, 68, 80)}),
}


def vendredi():
    rng = random.Random(505)
    tiles("vendredi", "paradoxal", [tape_floor(v, rng) for v in range(4)], box_wall_top(rng), box_wall_face(rng))
    tiles("vendredi", "profond", [mine_floor(v, rng) for v in range(4)], mine_wall_top(rng), timber_wall_face(rng))
    decors("vendredi", "paradoxal", VENDREDI_PARADOXAL)
    decors("vendredi", "profond", VENDREDI_PROFOND)


# --- Samedi (Solitude) ----------------------------------------------------------------------

def marble_floor(variant, rng):
    """Marbre en damier, veines fines ; incrustation doree au centre."""
    img = blank()
    px = img.load()
    for y in range(TILE):
        for x in range(TILE):
            light = ((x // 25) + (y // 25)) % 2 == 0
            c = (226, 224, 234) if light else (150, 156, 184)
            px[x, y] = shade(c, 0.97 + rng.random() * 0.05) + (255,)
    for _ in range(2 if variant == 1 else 1):  # veines
        x, y = rng.randrange(TILE), 0
        while y < TILE:
            px[x % TILE, y] = shade(px[x % TILE, y][:3], 0.82) + (255,)
            x += rng.choice([-1, 0, 1, 1])
            y += 1
    if variant == 2:  # etoile doree incrustee
        for i in range(-4, 5):
            px[25 + i, 25] = px[25, 25 + i] = (220, 190, 110, 255)
        for i in range(-2, 3):
            px[25 + i, 25 + i] = px[25 + i, 25 - i] = (240, 214, 140, 255)
    return img


def night_wall_top(rng):
    img = Image.new("RGBA", (TILE, TILE), (20, 24, 50, 255))
    px = img.load()
    for _ in range(3):
        px[rng.randrange(TILE), rng.randrange(TILE)] = (200, 210, 255, 255)
    return img


def window_wall_face(rng):
    """Colonnes d'ivoire et hautes fenetres eclairees par la lune."""
    img = blank()
    px = img.load()
    for y in range(TILE):
        k = 1.0 - 0.25 * (y / TILE)
        for x in range(TILE):
            lx = x % 25
            if lx < 6:
                c = mix((206, 200, 186), (240, 236, 226), 1 - abs(lx - 2.5) / 3)
            elif 8 <= lx <= 22 and 6 <= y <= 46:
                c = (60, 80, 140) if lx != 15 and y != 26 else (40, 44, 70)
                if (lx - 8) < 4 and y < 30:
                    c = (110, 140, 210)  # clair de lune
            else:
                c = (90, 86, 110)
            px[x, y] = shade(c, k) + (255,)
    return img


def dock_floor(variant, rng):
    """Planches de ponton gris-bleu ; entre elles, l'eau noire."""
    img = blank()
    px = img.load()
    for y in range(TILE):
        for x in range(TILE):
            lx = x % 10
            tone = ((x // 10) * 0.37) % 1
            c = mix((92, 96, 110), (112, 116, 128), tone * 0.7 + rng.random() * 0.15)
            if lx == 9:
                c = (10, 14, 24)  # l'eau entre les planches
            elif lx == 0:
                c = shade(c, 1.15)
            px[x, y] = c + (255,)
    if variant == 1:  # clous
        for x in range(4, TILE, 10):
            px[x, 6] = px[x, 43] = (60, 62, 70, 255)
    elif variant == 2:  # planche usee, plus claire
        x0 = rng.randrange(5) * 10
        for y in range(TILE):
            for x in range(x0 + 1, x0 + 9):
                px[x, y] = shade(px[x, y][:3], 1.18) + (255,)
    return img


def water_wall_top(rng):
    img = Image.new("RGBA", (TILE, TILE), (10, 14, 24, 255))
    px = img.load()
    for _ in range(4):
        x, y = rng.randrange(2, 44), rng.randrange(TILE)
        for i in range(5):
            px[x + i, y] = (34, 44, 62, 255)
    return img


def pier_wall_face(rng):
    """Bord du quai : eau noire sous la brume, pilotis."""
    img = blank()
    px = img.load()
    for y in range(TILE):
        for x in range(TILE):
            c = mix((70, 78, 96), (12, 16, 26), min(1.0, y / 30))  # brume en haut, eau noire en bas
            if x % 25 in (10, 11, 12) and y > 4:
                c = shade((70, 60, 54), 1.0 - 0.4 * (y / TILE))  # pilotis
            elif y > 30 and (x + y * 3) % 17 == 0:
                c = (40, 52, 74)  # remous
            px[x, y] = c + (255,)
    return img


SAMEDI_PARADOXAL = {
    "etoile": ([  # lettre recue
        "WWWWWWWWWWW", "WwWWWWWWWwW", "WWwWWWWWwWW", "WWWwWRWwWWW", "WWWWRRRWWWW", "WWWWWRWWWWW", "WWWWWWWWWWW",
    ], {"W": rgba(250, 244, 226), "w": rgba(200, 186, 160), "R": rgba(220, 60, 80)}),
    "lune": ([  # phare lointain
        "..YYY..", ".kWWWk.", "..RRR..", "..WWW..", "..RRR..", "..WWW..", ".RRRRR.", "BBBBBBB",
    ], {"Y": rgba(255, 240, 170), "W": rgba(240, 240, 248), "R": rgba(210, 70, 70), "k": rgba(60, 60, 70), "B": rgba(70, 80, 110)}),
    "horloge": ([  # boite a musique
        "..k......", "..kk.....", ".BBBBBBB.", "BGGGGGGGB", "BBBBBBBBB", "BbGbGbGbB", "BBBBBBBBB",
    ], {"k": rgba(200, 180, 120), "B": rgba(150, 100, 70), "G": rgba(230, 190, 110), "b": rgba(110, 70, 50)}),
    "bulle": ([  # bulle-souvenir (une petite maison dedans)
        "...CCCC...", "..CccccC..", ".CcccRcccC", "CcccRRRccC", "CccRRRRRcC", "CcccWkWccC", ".CccWWWcC.", "..CCCCCC..",
    ], {"C": rgba(220, 210, 255), "c": (220, 210, 255, 70), "R": (200, 90, 90, 220), "W": (250, 240, 220, 230), "k": (90, 70, 60, 230)}),
    "chaise": ([
        ".BB......", ".BB......", ".BB......", ".BBBBBBB.", ".bbbbbbb.", ".B.....B.", ".B.....B.",
    ], {"B": rgba(196, 160, 110), "b": rgba(150, 116, 76)}),
    "guirlande": ([
        "k.........k", ".kk.....kk.", "..YkkRkkB..", "...........",
    ], {"k": rgba(80, 80, 96), "Y": rgba(160, 150, 100), "R": rgba(150, 90, 90), "B": rgba(90, 110, 150)}),
    "verre": ([
        "WWWWW", "W...W", ".W.W.", "..W..", "..W..", ".WWW.",
    ], {"W": rgba(210, 226, 250)}),
}

SAMEDI_PROFOND = {
    "bougie": ([  # lanterne flottante
        "...kk...", "..kkkk..", ".kYYYYk.", ".kYWWYk.", ".kYYYYk.", "..kkkk..", "~~~~~~~~",
    ], {"k": rgba(70, 60, 50), "Y": rgba(255, 200, 110), "W": rgba(255, 240, 200), "~": rgba(40, 60, 90)}),
    "champignon": ([  # telephone qui sonne
        "..TTTTTT..", ".TT....TT.", "TT.kkkk.TT", "...TTTT...", "..TWTWTT..", "..TTWTWT..", "..TTTTTT..",
    ], {"T": rgba(80, 190, 180), "k": rgba(40, 60, 60), "W": rgba(220, 250, 248)}),
    "cristal": ([  # bouteille a la mer
        ".......kk", "......GG.", ".GGGGGGG.", "GGWWWWGG.", "GGWkkWGG.", "GGWWWWGG.", ".GGGGGG..",
    ], {"k": rgba(120, 90, 60), "G": rgba(150, 120, 200), "W": rgba(240, 230, 210)}),
    "bouee": ([
        "..RWWR..", ".RW..WR.", "RW....WR", "W......W", "RW....WR", ".RW..WR.", "..RWWR..",
    ], {"R": rgba(210, 70, 70), "W": rgba(240, 240, 240)}),
    "banc_vide": ([
        "BBBBBBBBBBBB", "bbbbbbbbbbbb", "BBBBBBBBBBBB", ".k........k.", ".k........k.",
    ], {"B": rgba(110, 104, 110), "b": rgba(80, 76, 84), "k": rgba(40, 40, 50)}),
    "lampadaire_eteint": ([
        "..GGG..", ".GgggG.", ".GGGGG.", "...k...", "...k...", "...k...", "...k...", "..kkk..",
    ], {"G": rgba(80, 86, 100), "g": rgba(50, 54, 64), "k": rgba(50, 54, 64)}),
}


def samedi():
    rng = random.Random(606)
    tiles("samedi", "paradoxal", [marble_floor(v, rng) for v in range(4)], night_wall_top(rng), window_wall_face(rng))
    tiles("samedi", "profond", [dock_floor(v, rng) for v in range(4)], water_wall_top(rng), pier_wall_face(rng))
    decors("samedi", "paradoxal", SAMEDI_PARADOXAL)
    decors("samedi", "profond", SAMEDI_PROFOND)


NIGHTS = {"lundi": lundi, "mardi": mardi, "mercredi": mercredi, "jeudi": jeudi, "vendredi": vendredi, "samedi": samedi}

if __name__ == "__main__":
    for night in sys.argv[1:] or NIGHTS:
        NIGHTS[night]()
        print("lieux :", night)
