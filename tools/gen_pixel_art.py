"""Genere le pixel art des decors (tuiles, decorations, props).

Lancer depuis la racine du projet : python tools/gen_pixel_art.py
Les PNG sont ecrits dans assets/sprites/{tiles,decor,props}/ et peuvent ensuite
etre retouches a la main (Aseprite...). Relancer le script ecrase les retouches.
Tout est dessine a 1 pixel = 1 pixel, et affiche en x2 dans le jeu.
"""
import math
import os
import random

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
TILE = 50  # 50 px x2 = une case de 100 px (FloorGenerator.CELL_SIZE)

# Un theme par couple (intensite, famille). Couleurs RGB.
THEMES = {
    "reve_paradoxal": dict(
        floor=(168, 146, 212), floor2=(188, 166, 226), grout=(118, 96, 168),
        wall=(46, 36, 88), wall_hi=(78, 64, 136), face=(96, 78, 158), face_dark=(60, 46, 110),
        accents=[(255, 236, 150), (160, 230, 255), (255, 170, 220)],
    ),
    "reve_profond": dict(
        floor=(66, 92, 124), floor2=(76, 104, 138), grout=(40, 56, 82),
        wall=(16, 24, 42), wall_hi=(34, 48, 74), face=(42, 60, 90), face_dark=(22, 32, 54),
        accents=[(120, 200, 220), (90, 150, 190)],
    ),
    "cauchemar_paradoxal": dict(
        floor=(104, 52, 98), floor2=(118, 62, 110), grout=(64, 26, 62),
        wall=(26, 10, 30), wall_hi=(52, 22, 56), face=(70, 30, 72), face_dark=(40, 14, 44),
        accents=[(255, 90, 160), (180, 255, 120)],
    ),
    "cauchemar_profond": dict(
        floor=(62, 26, 32), floor2=(72, 32, 38), grout=(34, 12, 16),
        wall=(12, 4, 8), wall_hi=(32, 12, 18), face=(48, 18, 24), face_dark=(26, 8, 12),
        accents=[(190, 40, 40), (120, 30, 60)],
    ),
}


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def floor_tile(t, variant, rng):
    img = Image.new("RGBA", (TILE, TILE))
    px = img.load()
    slab = 25
    for y in range(TILE):
        row = y // slab
        off = 12 if row % 2 else 0
        for x in range(TILE):
            sx = (x + off) % TILE
            key = (row, sx // slab)
            local_x, local_y = sx % slab, y % slab
            slab_rng = random.Random(hash((variant, key)))
            c = mix(t["floor"], t["floor2"], slab_rng.random())
            if local_x == 0 or local_y == 0:
                c = t["grout"]
            elif local_x == 1 or local_y == 1:
                c = shade(c, 1.12)
            elif local_x == slab - 1 or local_y == slab - 1:
                c = shade(c, 0.88)
            elif rng.random() < 0.07:
                c = shade(c, rng.choice([0.92, 1.07]))
            px[x, y] = c + (255,)
    if variant == 1:  # fissure
        x, y = rng.randrange(8, 42), rng.randrange(8, 42)
        for _ in range(rng.randrange(8, 16)):
            px[x, y] = t["grout"] + (255,)
            x = max(2, min(TILE - 3, x + rng.choice([-1, 0, 1])))
            y = max(2, min(TILE - 3, y + rng.choice([0, 1])))
    elif variant == 2:  # petites lueurs
        for _ in range(rng.randrange(3, 6)):
            x, y = rng.randrange(3, 47), rng.randrange(3, 47)
            px[x, y] = rng.choice(t["accents"]) + (255,)
    return img


def wall_top(t, rng):
    img = Image.new("RGBA", (TILE, TILE))
    px = img.load()
    for y in range(TILE):
        for x in range(TILE):
            c = t["wall"]
            if rng.random() < 0.06:
                c = t["wall_hi"]
            px[x, y] = c + (255,)
    return img


def wall_face(t, rng):
    img = Image.new("RGBA", (TILE, TILE))
    px = img.load()
    brick_h, brick_w = 10, 16
    for y in range(TILE):
        row = y // brick_h
        off = 8 if row % 2 else 0
        k = 1.0 - 0.35 * (y / TILE)  # plus sombre vers le bas
        for x in range(TILE):
            c = shade(t["face"], k)
            if y < 3:
                c = t["wall_hi"]
            elif y % brick_h == 0 or (x + off) % brick_w == 0:
                c = shade(t["face_dark"], k)
            elif rng.random() < 0.05:
                c = shade(c, 0.9)
            px[x, y] = c + (255,)
    return img


def from_ascii(rows, palette, outline=(20, 12, 30)):
    h, w = len(rows), max(len(r) for r in rows)
    img = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in palette:
                px[x + 1, y + 1] = palette[ch]
    if outline:
        solid = {(x, y) for x in range(w + 2) for y in range(h + 2) if px[x, y][3] > 0}
        for x, y in solid:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in solid and 0 <= n[0] < w + 2 and 0 <= n[1] < h + 2:
                    px[n] = outline + (255,)
    return img


def rgba(*c):
    return tuple(c) + ((255,) if len(c) == 3 else ())


# Decors du sommeil paradoxal : objets de reve, legers et colores.
DECOR_PARADOXAL = {
    "etoile": ([
        ".....Y.....",
        "....YWY....",
        "....YWY....",
        "YYYYWWWYYYY",
        ".YYWWWWWYY.",
        "..YYWWWYY..",
        "..YYYyYYY..",
        ".YYy...yYY.",
        ".Yy.....yY.",
    ], {"Y": rgba(255, 220, 110), "W": rgba(255, 250, 210), "y": rgba(214, 160, 70)}),
    "lune": ([
        "...YYYY...",
        ".YYYYy....",
        "YYYYy.....",
        "YYYy......",
        "YYYy......",
        "YYYy......",
        "YYYYy.....",
        ".YYYYYy...",
        "...YYYY...",
    ], {"Y": rgba(250, 240, 190), "y": rgba(200, 180, 130)}),
    "nuage": ([
        ".....WWWW.......",
        "....WWWWWW.WWW..",
        "..WWWWWWWWWWWWW.",
        ".WWWWWWWWWWWWWWW",
        "WWWWWWWWWWWWWWWW",
        ".wwwwwwwwwwwwww.",
        "..wwwwwwwwwwww..",
    ], {"W": rgba(245, 242, 255), "w": rgba(196, 190, 230)}),
    "cube": ([
        ".TTTTTTTTTT.",
        "TTTTTTTTTTTr",
        "RRRRRRRRRRrr",
        "RRRWWWWRRRrr",
        "RRWRRRRWRRrr",
        "RRWWWWWWRRrr",
        "RRWRRRRWRRrr",
        "RRWRRRRWRRrr",
        "RRRRRRRRRRrr",
        ".rrrrrrrrrr.",
    ], {"T": rgba(255, 150, 150), "R": rgba(220, 80, 90), "r": rgba(150, 40, 60), "W": rgba(255, 245, 230)}),
    "horloge": ([
        "...GGGGGG...",
        "..GWWWWWWG..",
        ".GWWWWkWWWG.",
        "GWWWWWkWWWWG",
        "GWWWWWkWWWWG",
        "GWWWWWkkkWWG",
        "GWWWWWWWWWWG",
        ".GWWWWWWWWG.",
        "..GWWWWWWG..",
        "...GGGGGG...",
        "..GG....GG..",
    ], {"G": rgba(230, 180, 80), "W": rgba(250, 245, 235), "k": rgba(40, 30, 50)}),
    "bulle": ([
        "...CCCC...",
        "..CWccccC.",
        ".CWcccccC.",
        "CcWccccccC",
        "CcccccccC.",
        "CccccccccC",
        ".CccccccC.",
        "..CCCCCC..",
    ], {"C": rgba(170, 220, 255), "W": rgba(255, 255, 255), "c": (170, 220, 255, 70)}),
}

# Decors du sommeil profond : lourds, sombres, quelques lueurs.
DECOR_PROFOND = {
    "bougie": ([
        "..F...",
        ".FYF..",
        ".FYF..",
        "..k...",
        ".WWWw.",
        ".WWWw.",
        ".WWWw.",
        ".WWWw.",
        "wWWWww",
        "wwwwww",
    ], {"F": rgba(255, 150, 60), "Y": rgba(255, 240, 170), "k": rgba(40, 30, 30),
        "W": rgba(230, 220, 200), "w": rgba(170, 150, 140)}),
    "champignon": ([
        "....CCCC....",
        "..CCCCCCCC..",
        ".CCcCCCCcCC.",
        "CCCCCCCCCCCC",
        "CCcCCCCCCcCC",
        ".cccccccccc.",
        "....SSSS....",
        "....SSSs....",
        "...SSSSss...",
        "..ssssssss..",
    ], {"C": rgba(90, 220, 200), "c": rgba(40, 150, 150), "S": rgba(220, 210, 190), "s": rgba(150, 140, 130)}),
    "cristal": ([
        "...CC....",
        "..CCWC...",
        "..CCWC...",
        ".CCCWCC..",
        ".CCCWCc..",
        "CCCCCCcc.",
        "CCCCCCcc.",
        ".cCCCccc.",
        "..cccc...",
    ], {"C": rgba(170, 120, 255), "W": rgba(240, 220, 255), "c": rgba(100, 60, 170)}),
    "rocher": ([
        "....RRRR....",
        "..RRRRRRRR..",
        ".RRhRRRRRRR.",
        "RRRRRRRRrRRR",
        "RRRRRRRRRRRr",
        "RrRRRRRRRRrr",
        ".rrrRRRRrrr.",
        "..rrrrrrrr..",
    ], {"R": rgba(96, 90, 104), "h": rgba(140, 134, 150), "r": rgba(58, 52, 66)}),
    "arbre_mort": ([
        "B.......B..",
        ".B..B..B...",
        "..B.B.B....",
        "...BBB.....",
        "....BB.....",
        "....BB.....",
        "....BB.....",
        "....BBb....",
        "...BBBBb...",
        "..BB.B.bb..",
    ], {"B": rgba(84, 64, 60), "b": rgba(54, 40, 38)}),
}

CHEST_ROWS = [
    ".bbbbbbbbbbbbbb.",
    "bBBBBBBBBBBBBBBb",
    "bBhBBBBBBBBBBBBb",
    "bBBBBBBBBBBBBBBb",
    "bGGGGGGYYGGGGGGb",
    "bbbbbbbYYbbbbbbb",
    "bBBBBBBYYBBBBBBb",
    "bBBBBBBBBBBBBBBb",
    "bBBBBBBBBBBBBBBb",
    "bGGGGGGGGGGGGGGb",
    ".bbbbbbbbbbbbbb.",
]
CHEST_OPEN_ROWS = [
    ".bbbbbbbbbbbbbb.",
    "bBBBBBBBBBBBBBBb",
    "bGGGGGGGGGGGGGGb",
    "bkkkkkkkkkkkkkkb",
    "bkkkkkkkkkkkkkkb",
    "bbbbbbbbbbbbbbbb",
    "bBBBBBBBBBBBBBBb",
    "bBBBBBBBBBBBBBBb",
    "bBBBBBBBBBBBBBBb",
    "bGGGGGGGGGGGGGGb",
    ".bbbbbbbbbbbbbb.",
]
CHEST_PALETTE = {"B": rgba(170, 104, 56), "h": rgba(210, 140, 80), "b": rgba(96, 54, 30),
                 "G": rgba(240, 196, 80), "Y": rgba(255, 240, 160), "k": rgba(30, 18, 20)}
CHEST_SEALED_PALETTE = {"B": rgba(96, 60, 150), "h": rgba(130, 90, 190), "b": rgba(50, 28, 90),
                        "G": rgba(190, 120, 255), "Y": rgba(255, 220, 255), "k": rgba(20, 10, 30)}


def portal():
    size = 24
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            dx, dy = x - c, y - c
            d = math.hypot(dx, dy)
            if d > c:
                continue
            swirl = math.sin(math.atan2(dy, dx) * 3 + d * 0.9)
            v = 0.55 + 0.45 * swirl * (d / c)
            v = round(v * 3) / 3  # 4 niveaux de gris : rendu pixel art
            a = 255 if d < c - 1 else 180
            g = int(150 + 105 * v)
            px[x, y] = (g, g, g, a)
    return img


# --- Personnages ---------------------------------------------------------------

# Le reveur en pyjama et bonnet de nuit (sans contour : il est ajoute automatiquement).
PLAYER_BODY = [
    "......LPPPP.......",
    "....LLPPPPPPP.....",
    "...LPPPPPPPPPPP...",
    "...PPPPPPPPPPPPPP.",
    "..pPPPPPPPPPPpppWW",
    "..pppppppppppp..Ww",
    "..HHSSSSSSSSHH....",
    "..HSSSSSSSSSSH....",
    "..HSSESSSSESSH....",
    "...SSESSSSESS.....",
    "...SRSSSSSSRS.....",
    "....ssSSSSss......",
    "......ssss........",
    "...JJJJJJJJJJJ....",
    "..JJKKKKKKKKKJJ...",
    ".SJJJJJJJJJJJJJS..",
    ".SjKKKKKKKKKKKjS..",
    "..jJJJJJJJJJJJj...",
    "...KKKKKKKKKKK....",
    "...JJJJJJJJJJJ....",
]
PLAYER_LEGS = {
    "neutral": ["...jjjjj.jjjjj....", "...JKKJ...JKKJ....", "...JJJJ...JJJJ....", "..FFFFf...FFFFf..."],
    "left_up": ["...jjjjj.jjjjj....", "...JKKJ...JKKJ....", "..FFFFf...JJJJ....", "..........FFFFf..."],
    "right_up": ["...jjjjj.jjjjj....", "...JKKJ...JKKJ....", "...JJJJ...FFFFf...", "..FFFFf..........."],
}
PLAYER_PALETTE = {
    "P": rgba(112, 72, 172), "p": rgba(74, 46, 122), "L": rgba(156, 118, 214),
    "W": rgba(250, 245, 232), "w": rgba(196, 188, 214),
    "S": rgba(238, 192, 152), "s": rgba(204, 152, 120), "E": rgba(34, 22, 34), "R": rgba(240, 140, 140),
    "H": rgba(96, 62, 52),
    "J": rgba(124, 154, 224), "j": rgba(86, 108, 182), "K": rgba(232, 236, 252),
    "F": rgba(196, 112, 124), "f": rgba(144, 72, 92),
}
PLAYER_OUTLINE = (24, 16, 34)


def player_frames():
    blink = [row.replace("E", "s") for row in PLAYER_BODY]
    frames = [
        PLAYER_BODY + PLAYER_LEGS["neutral"],   # 0 : repos
        blink + PLAYER_LEGS["neutral"],         # 1 : clignement
        PLAYER_BODY + PLAYER_LEGS["left_up"],   # 2..4 : marche
        PLAYER_BODY + PLAYER_LEGS["neutral"],
        PLAYER_BODY + PLAYER_LEGS["right_up"],
    ]
    return [from_ascii(f, PLAYER_PALETTE, PLAYER_OUTLINE) for f in frames]


def sheet(frames):
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


def rim_light(src):
    """Ajoute un reflet de lune sur le haut des formes et une ombre sur le bas (volume)."""
    img = src.copy()
    s, px = src.load(), img.load()
    w, h = src.size

    def opaque(x, y):
        return 0 <= x < w and 0 <= y < h and s[x, y][3] > 0

    def edge(x, y):  # pixel de contour : touche le vide
        return opaque(x, y) and any(not opaque(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))

    for y in range(h):
        for x in range(w):
            if not opaque(x, y) or edge(x, y):
                continue
            c = s[x, y]
            if edge(x, y - 1):
                px[x, y] = mix(c[:3], (224, 218, 255), 0.3) + (c[3],)
            elif edge(x, y + 1):
                px[x, y] = shade(c[:3], 0.78) + (c[3],)
    return img


def shift_rows(src, y0, y1, dx):
    img = src.copy()
    s, px = src.load(), img.load()
    for y in range(y0, min(y1, src.height)):
        for x in range(src.width):
            sx = x - dx
            px[x, y] = s[sx, y] if 0 <= sx < src.width else (0, 0, 0, 0)
    return img


def squash(src, row):
    """Retire une ligne au milieu du corps : la moitie haute descend d'un pixel (respiration)."""
    img = Image.new("RGBA", src.size, (0, 0, 0, 0))
    img.paste(src.crop((0, 0, src.width, row)), (0, 1))
    img.paste(src.crop((0, row + 1, src.width, src.height)), (0, row + 1))
    return img


def remove_cols(src, cols):
    """Retire des colonnes (ailes qui se replient) et recentre."""
    keep = [x for x in range(src.width) if x not in cols]
    img = Image.new("RGBA", src.size, (0, 0, 0, 0))
    pad = len(cols) // 2
    for i, x in enumerate(keep):
        img.paste(src.crop((x, 0, x + 1, src.height)), (i + pad, 0))
    return img


# Deuxieme image d'animation de chaque monstre, a partir du sprite d'origine.
MOB_ANIMATIONS = {
    "berceuse": lambda im: shift_rows(im, 12, 22, 1),
    "eveilleur_de_peur": lambda im: shift_rows(im, 17, 24, 1),
    "nounours_egare": lambda im: squash(im, 11),
    "ombre_rampante": lambda im: shift_rows(im, 12, 19, 1),
    "songe_papillon": lambda im: remove_cols(im, [2, 3, 18, 19]),
    "terreur_nocturne": lambda im: shift_rows(shift_rows(im, 0, 4, 1), 24, 28, -1),
    "voix_murmurante": lambda im: shift_rows(im, 14, 22, 1),
}
SOURCES = os.path.join(os.path.dirname(__file__), "sprite_sources")

ITEM_ICONS = {
    "item_passive": ([
        "..CCCC..",
        ".CWWCCc.",
        "CWWCCCcc",
        "CWCCCCcc",
        "CCCCCCcc",
        "CCCCCccc",
        ".cCCccc.",
        "..cccc..",
    ], {"C": rgba(150, 200, 255), "W": rgba(255, 255, 255), "c": rgba(80, 110, 200)}),
    "item_active": ([
        "...YY...",
        "..YWWY..",
        "YYYWWYYY",
        ".YYWWYY.",
        "..YYYY..",
        ".YYyyYY.",
        "YYy..yYY",
        "Y......Y",
    ], {"Y": rgba(255, 210, 90), "W": rgba(255, 250, 220), "y": rgba(200, 140, 50)}),
}


def save(img, *parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def main():
    rng = random.Random(42)
    for name, t in THEMES.items():
        for v in range(4):
            save(floor_tile(t, v, rng), "tiles", f"{name}_floor_{v}.png")
        save(wall_top(t, rng), "tiles", f"{name}_wall_top.png")
        save(wall_face(t, rng), "tiles", f"{name}_wall_face.png")
    for family, sprites in (("paradoxal", DECOR_PARADOXAL), ("profond", DECOR_PROFOND)):
        for name, (rows, pal) in sprites.items():
            save(from_ascii(rows, pal), "decor", family, f"{name}.png")
    save(from_ascii(CHEST_ROWS, CHEST_PALETTE), "props", "chest_closed.png")
    save(from_ascii(CHEST_OPEN_ROWS, CHEST_PALETTE), "props", "chest_open.png")
    save(from_ascii(CHEST_ROWS, CHEST_SEALED_PALETTE), "props", "chest_sealed.png")
    save(portal(), "props", "portal.png")
    for name, (rows, pal) in ITEM_ICONS.items():
        save(from_ascii(rows, pal), "props", f"{name}.png")

    frames = player_frames()
    save(frames[0], "player", "idle.png")
    save(sheet(frames), "player", "sheet.png")
    for name, animate in MOB_ANIMATIONS.items():
        base = rim_light(Image.open(os.path.join(SOURCES, f"{name}.png")).convert("RGBA"))
        save(sheet([base, animate(base)]), "mobs", name, "idle.png")


if __name__ == "__main__":
    main()
