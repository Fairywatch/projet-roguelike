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


NIGHTS = {"lundi": lundi}

if __name__ == "__main__":
    for night in sys.argv[1:] or NIGHTS:
        NIGHTS[night]()
        print("lieux :", night)
