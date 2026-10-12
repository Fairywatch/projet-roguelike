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


# Habitants du reve qui donnent des quetes (voir scripts/exploration/npc.gd).
NPCS = {
    "hibou": ([
        "..B........B..",
        "..BB......BB..",
        "..BBBBBBBBBB..",
        ".BBWWBBBBWWBB.",
        ".BWYYWBBWYYWB.",
        ".BWYkWBBWkYWB.",
        ".BBWWBOOBWWBB.",
        ".BBBBBOOBBBBB.",
        ".bBWWWWWWWWBb.",
        ".bBWbWWWWbWBb.",
        ".bBWWWWWWWWBb.",
        ".bBWbWWWWbWBb.",
        "..bBWWWWWWBb..",
        "..bbBBBBBBbb..",
        "....OO..OO....",
    ], {"B": rgba(140, 100, 70), "b": rgba(90, 60, 45), "W": rgba(230, 215, 180), "Y": rgba(255, 220, 90),
        "k": rgba(30, 20, 20), "O": rgba(230, 140, 60)}),
    "lapin": ([
        "...W.....W....",
        "..WPW...WPW...",
        "..WPW...WPW...",
        "..WPW...WPW...",
        "..WWW...WWW...",
        "..WWWWWWWWW...",
        ".WWWWWWWWWWW..",
        ".WWEWWWWWEWW..",
        ".WWWWWPWWWWW..",
        "..WWWWWWWWW...",
        "...RRRRRRR....",
        "..RRRGGRRRRR..",
        "..RRGGGGRRRR..",
        "..RRRGGRRRRR..",
        "..wRRRRRRRRw..",
        "...WWW..WWW...",
    ], {"W": rgba(240, 235, 244), "w": rgba(190, 185, 205), "P": rgba(240, 170, 190), "E": rgba(40, 20, 40),
        "R": rgba(180, 60, 70), "G": rgba(240, 200, 90)}),
    "marchande": ([
        "....MMMM......",
        "...MMMMm......",
        "..MMMm........",
        "..MMk.........",
        "..MMM.........",
        "..MMMm........",
        "...MMMMm......",
        "....MMMM......",
        "...CCCCCC.....",
        "..CCSCCCCC....",
        ".CCCCCCSCCC...",
        ".CCSCCCCCCC...",
        ".CCCCCCCCSC...",
        "CCCCCSCCCCCC..",
        "cCCCCCCCCCCc..",
        "ccccccccccccc.",
    ], {"M": rgba(250, 240, 190), "m": rgba(200, 185, 130), "k": rgba(40, 30, 50), "C": rgba(80, 66, 150),
        "c": rgba(48, 40, 104), "S": rgba(255, 230, 120)}),
}
QUEST_ITEM = ([
    "..YYY...",
    ".Y...Y..",
    ".Y...Y..",
    "..YYY...",
    "...Y....",
    "...YY...",
    "...Y....",
    "...YY...",
], {"Y": rgba(255, 215, 110)})


# --- Hub : les 7 tours de la semaine ----------------------------------------------
# Du lundi au dimanche, la tour s'assombrit, grandit, se tord et ses fenetres s'eteignent.
DAYS = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]


def tower_sprite(day):
    k = day / (len(DAYS) - 1)  # 0 = lundi, 1 = dimanche
    rng = random.Random(100 + day)
    wall = mix((176, 190, 236), (58, 22, 40), k)
    wall_dark = shade(wall, 0.7)
    roof = mix((236, 196, 120), (120, 24, 36), k)
    lit = mix((255, 236, 150), (200, 60, 50), k)
    w, body_h, roof_h = 20, 34 + day * 3, 12
    h = body_h + roof_h
    img = Image.new("RGBA", (w + 12, h + 2), (0, 0, 0, 0))
    px = img.load()
    lean = k * 5  # decalage max du sommet (tour tordue)

    def put(x, y, c):
        sx = x + 6 + int(round(lean * (1 - y / h)))
        if 0 <= sx < img.width and 0 <= y < img.height:
            px[sx, y] = c + (255,)

    for y in range(roof_h):  # toit pointu
        half = int((y + 1) / roof_h * (w / 2 + 2))
        for x in range(w // 2 - half, w // 2 + half):
            put(x, y, roof if x < w // 2 else shade(roof, 0.75))
    for y in range(roof_h, h):  # corps en briques
        for x in range(w):
            c = wall if x < w * 0.65 else wall_dark
            if (y - roof_h) % 6 == 0 or (x + (3 if (y - roof_h) // 6 % 2 else 0)) % 7 == 0:
                c = shade(c, 0.85)
            put(x, y, c)
    windows = max(1, 5 - day // 2)  # moins de fenetres allumees au fil de la semaine
    for i in range(3):
        wy = roof_h + 5 + i * 9
        if wy + 4 >= h - 10:
            break
        for j, wx in enumerate((4, 12)):
            on = (i * 2 + j) < windows and rng.random() > k * 0.4
            for dy in range(4):
                for dx in range(3):
                    put(wx + dx, wy + dy, lit if on else (20, 14, 24))
    for y in range(h - 9, h):  # porte en arc
        for x in range(7, 13):
            if y > h - 8 or 8 <= x <= 11:
                put(x, y, (24, 14, 20))
    return outline(img, (18, 10, 24))


def outline(img, color):
    px = img.load()
    w, h = img.size
    solid = {(x, y) for x in range(w) for y in range(h) if px[x, y][3] > 0}
    for x, y in solid:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n not in solid and 0 <= n[0] < w and 0 <= n[1] < h:
                px[n] = color + (255,)
    return img


PADLOCK = ([
    "..kkkk..",
    ".k....k.",
    ".k....k.",
    "GGGGGGGG",
    "GGGkkGGG",
    "GGGkkGGG",
    "GGGGGGGG",
], {"k": rgba(150, 150, 170), "G": rgba(220, 170, 70)})


BOOK = ([
    ".bbbbbbbbbbbb.",
    "bPPPPPPWPPPPPb",
    "bPPPPPPWPPPPPb",
    "bPPYYPPWPPYYPb",
    "bPPPPPPWPPPPPb",
    "bPPYYPPWPPYYPb",
    "bPPPPPPWPPPPPb",
    "bbbbbbbbbbbbbb",
    ".gggggggggggg.",
], {"b": rgba(60, 40, 90), "P": rgba(130, 100, 190), "W": rgba(240, 230, 250), "Y": rgba(255, 220, 120),
    "g": rgba(40, 28, 60)})


# --- Bestiaire du lundi (Fatigue) : voir docs/bestiaire.md ----------------------------
# Chaque sprite est une planche de 2 images (repos / anime), comme les autres monstres.

LUNDI_BAILLEUR = ([
    "....WWWWWWWWWW....",
    "..WWWWWWWWWWWWWW..",
    ".WWWWWWWWWWWWWWWW.",
    "WWWWWWWWWWWWWWWWWW",
    "WWWkkkWWWWWWkkkWWW",
    "WWWWWWWWWWWWWWWWWW",
    "WWWWWWmmmmmmWWWWWW",
    "WWWWWmrrrrrrmWWWWW",
    "WWWWWmrrrrrrmWWWWW",
    "WWWWWWmmmmmmWWWWWW",
    ".WWWWWWWWWWWWWWWW.",
    "..wwwwwwwwwwwwww..",
], {"W": rgba(226, 220, 242), "w": rgba(172, 166, 204), "k": rgba(92, 80, 124), "m": rgba(64, 32, 64),
    "r": rgba(184, 82, 112)})

LUNDI_MOUTON = ([
    "...WWWW..WWWW.....",
    "..WWWWWWWWWWWW....",
    ".WWWWWWWWWWWWWW...",
    "WWWWWWWWWWWWWWWFF.",
    "WWWWWWWWWWWWWWFeFF",
    "WWWWWWWWWWWWWWFbFF",
    ".WWWWWWWWWWWWWFFFF",
    "..WWWWWWWWWWWWFF..",
    "...ll..ll..ll.ll..",
    "...ll..ll..ll.ll..",
], {"W": rgba(236, 232, 226), "F": rgba(112, 100, 112), "e": rgba(244, 206, 206), "b": rgba(72, 40, 72),
    "l": rgba(62, 52, 62)})

LUNDI_VEILLEUSE = ([
    "...YYYYYY...",
    "..YyYYYYyY..",
    "..YYYYYYYY..",
    "..YkYYYYkY..",
    "..YYYmmYYY..",
    "...YYYYYY...",
    "....GGGG....",
    "...GGGGGG...",
    "..GGGGGGGG..",
    "..gggggggg..",
], {"Y": rgba(255, 228, 150), "y": rgba(255, 250, 224), "k": rgba(120, 90, 60), "m": rgba(160, 110, 70),
    "G": rgba(120, 110, 160), "g": rgba(76, 68, 110)})

PAUPIERE_PALETTE = {"L": rgba(214, 170, 160), "l": rgba(150, 104, 100), "c": rgba(50, 36, 44),
                    "W": rgba(240, 236, 236), "P": rgba(110, 150, 200), "k": rgba(20, 16, 30)}
LUNDI_PAUPIERE_CLOSED = [
    "..................",
    "..LLLLLLLLLLLLLL..",
    ".LLLLLLLLLLLLLLLL.",
    "LLLLLLLLLLLLLLLLLL",
    "LLLLLLLLLLLLLLLLLL",
    ".llllllllllllllll.",
    ".c.c.c.c.c.c.c.c..",
    ".c.c.c.c.c.c.c.c..",
]
LUNDI_PAUPIERE_OPEN = [
    "..LLLLLLLLLLLLLL..",
    ".LLWWWWWWWWWWWWLL.",
    "LLWWWWWPPPPWWWWWLL",
    "LLWWWWPPkkPPWWWWLL",
    ".LWWWWWPPPPWWWWWL.",
    "..llllllllllllll..",
    ".c.c.c.c.c.c.c.c..",
    ".c.c.c.c.c.c.c.c..",
]

LUNDI_REVEIL = ([
    ".BB..............BB.",
    "BBBB............BBBB",
    ".BBRRRRRRRRRRRRRRBB.",
    "..RRWWWWWWWWWWWWRR..",
    ".RRWWkkWWWWWWkkWWRR.",
    ".RWWWWkkWWWWkkWWWWR.",
    "RRWWWWWWWWWWWWWWWWRR",
    "RWWWWWWWWkWWWWWWWWWR",
    "RWWWWWWWWkWWWWWWWWWR",
    "RWWWWWWWWkkkkWWWWWWR",
    "RWWWWWWWWWWWWWWWWWWR",
    "RRWWWWWmmmmmmWWWWWRR",
    ".RWWWWmWWWWWWmWWWWR.",
    ".RRWWWWWWWWWWWWWWRR.",
    "..RRRRRRRRRRRRRRRR..",
    "...ll..........ll...",
    "..lll..........lll..",
], {"B": rgba(236, 196, 90), "R": rgba(196, 64, 72), "W": rgba(246, 240, 228), "k": rgba(40, 30, 40),
    "m": rgba(90, 40, 50), "l": rgba(70, 50, 60)})

LUNDI_TETE = ([
    "....HHHHHHHH....",
    "..HHHHHHHHHHHH..",
    ".HHHHHHHHHHHHHH.",
    "HHHkkHHHHHHkkHHH",
    "HHHHHHHHHHHHHHHH",
    "HHHHHmmmmmmHHHHH",
    "HHHHmrrrrrrmHHHH",
    "HHHHmrrrrrrmHHHH",
    "HHHHmrrrrrrmHHHH",
    ".HHHHmmmmmmHHHH.",
    "..HHHHHHHHHHHH..",
    "....hhhhhhhh....",
], {"H": rgba(206, 196, 222), "h": rgba(150, 140, 176), "k": rgba(70, 60, 96), "m": rgba(56, 28, 56),
    "r": rgba(160, 64, 96)})


def choir(head):
    """Le Choeur des Baillements : trois tetes cote a cote, celle du milieu un peu plus haute."""
    w, h = head.size
    img = Image.new("RGBA", (w * 3 - 4, h + 6), (0, 0, 0, 0))
    for i, dy in enumerate((6, 0, 6)):
        img.paste(head, (i * (w - 2), dy), head)
    return img


def quilt(rng):
    """La Grande Couette : patchwork qui ondule, deux yeux ensommeilles."""
    w, h = 40, 22
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    patches = [(150, 120, 200), (196, 160, 214), (120, 150, 206), (220, 190, 220), (170, 140, 190)]
    for x in range(w):
        bottom = h - 3 + int(round(math.sin(x / 3.0) * 2))  # bord du bas qui pend
        for y in range(2, bottom):
            c = patches[(x // 8 + y // 7 * 2) % len(patches)]
            if x % 8 == 0 or y % 7 == 0:
                c = shade(c, 0.75)  # coutures
            px[x, y] = c + (255,)
    for ex in (12, 27):  # yeux mi-clos
        for dx in range(5):
            px[ex + dx, 9] = (60, 40, 80, 255)
        px[ex, 8] = px[ex + 4, 8] = (60, 40, 80, 255)
    return outline(img, (30, 20, 44))


def door(light):
    """La Porte des Voix : porte de bois, lumiere qui filtre par les fentes et la serrure."""
    w, h = 28, 46
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    glow = (255, 214, 130) if light else (190, 140, 80)
    for y in range(h):
        for x in range(w):
            frame = x < 2 or x >= w - 2 or y < 2
            plank = (x - 2) % 6 == 0
            c = (74, 46, 34) if frame else ((110, 70, 48) if not plank else (88, 56, 40))
            if not frame and (y in (14, 15) or y in (32, 33)):
                c = (88, 56, 40)  # traverses
            px[x, y] = c + (255,)
    for y in range(4, h - 2):  # fentes entre les planches
        if y % 5 != 0:
            px[8, y] = px[20, y] = glow + (255,)
    for x in range(2, w - 2):  # jour sous la porte
        px[x, h - 1] = glow + (255,)
    px[21, 24] = px[21, 25] = (240, 200, 90, 255)  # poignee
    for dy in range(3):
        px[21, 28 + dy] = glow + (255,)  # serrure
    return outline(img, (24, 14, 18))


def dim(src, k=0.7):
    """Assombrit le sprite (veilleuse qui vacille)."""
    img = src.copy()
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            c = px[x, y]
            if c[3]:
                px[x, y] = shade(c[:3], k) + (c[3],)
    return img


def lundi_sprites(rng):
    bailleur = rim_light(from_ascii(*LUNDI_BAILLEUR))
    mouton = rim_light(from_ascii(*LUNDI_MOUTON))
    veilleuse = rim_light(from_ascii(*LUNDI_VEILLEUSE))
    reveil = rim_light(from_ascii(*LUNDI_REVEIL))
    tete = from_ascii(*LUNDI_TETE)
    couette = quilt(rng)
    return {
        "bailleur": [bailleur, squash(bailleur, 6)],
        "mouton": [mouton, shift_rows(mouton, 9, 12, 1)],
        "veilleuse": [veilleuse, dim(veilleuse)],
        # Paupiere : image 0 fermee (invulnerable), image 1 ouverte (choisie par le script).
        "paupiere": [from_ascii(LUNDI_PAUPIERE_CLOSED, PAUPIERE_PALETTE), from_ascii(LUNDI_PAUPIERE_OPEN, PAUPIERE_PALETTE)],
        "grande_couette": [couette, shift_rows(couette, 12, 30, 1)],
        "reveil_grincheux": [reveil, shift_rows(reveil, 0, 40, 1)],
        "choeur_baillements": [rim_light(choir(tete)), rim_light(choir(squash(tete, 6)))],
        "porte_des_voix": [door(False), door(True)],
    }


# --- Bestiaire du mardi (Stress) --------------------------------------------------------

MARDI_TROTTEUSE = ([
    "..............A.",
    ".............AAA",
    "GGGGGGGGGGGGAeAA",
    "GGGGGGGGGGGGAAAA",
    ".............AAA",
    "..............A.",
    ".l...l...l...l..",
    ".l...l...l...l..",
], {"G": rgba(220, 186, 90), "A": rgba(170, 130, 50), "e": rgba(30, 20, 20), "l": rgba(70, 50, 40)})

MARDI_PILE = ([
    "..PPPPPPPPPP..",
    "..PlllllllllP.",
    "..PPPPPPPPPPP.",
    ".PPPPPPPPPPP..",
    ".PlllllllllP..",
    ".PPPPPPPPPPP..",
    "..PPPPPPPPPPP.",
    "..PlllllllllP.",
    "..PPPPPPPPPPP.",
    ".PPPPPPPPPPPP.",
    ".PPeePPPPeePP.",
    ".PPPPPmmPPPPP.",
    ".PPPPPPPPPPPP.",
    ".pppppppppppp.",
], {"P": rgba(242, 240, 230), "l": rgba(150, 170, 214), "e": rgba(40, 30, 40), "m": rgba(190, 60, 60),
    "p": rgba(190, 186, 176)})

MARDI_STYLO = ([
    "..CC..",
    ".CRRC.",
    ".RRRR.",
    ".RRRR.",
    ".ReRe.",
    ".RRRR.",
    ".RkkR.",
    ".RRRR.",
    ".RRRR.",
    ".rrrr.",
    ".SSSS.",
    "..SS..",
    "..SS..",
    "..NN..",
    "...N..",
], {"C": rgba(240, 240, 240), "R": rgba(206, 46, 56), "r": rgba(140, 26, 36), "e": rgba(250, 250, 250),
    "k": rgba(60, 10, 20), "S": rgba(180, 180, 190), "N": rgba(150, 0, 20)})

MARDI_COEUR = ([
    "..HHH....HHH..",
    ".HHhHH..HHHHH.",
    "HHhHHHHHHHHHHH",
    "HHHHHHHHHHHHHH",
    "HHHeHHHHHHeHHH",
    "HHHHHHHHHHHHHH",
    ".HHHHHmmHHHHH.",
    "..HHHHHHHHHH..",
    "...HHHHHHHH...",
    "....HHHHHH....",
    ".....HHHH.....",
    "......HH......",
], {"H": rgba(222, 62, 84), "h": rgba(255, 150, 160), "e": rgba(40, 10, 20), "m": rgba(110, 20, 40)})

MARDI_TABLEAU = ([
    "WWWWWWWWWWWWWWWWWWWWWWWWWWWW",
    "WBBBBBBBBBBBBBBBBBBBBBBBBBBW",
    "WBBcBBBBcccBBBBBBBcBBBcBBBBW",
    "WBcBcBBBBBcBBccBBBcBBcBcBBBW",
    "WBcccBBBBccBBBBBBBcBBcBcBBBW",
    "WBcBcBBBcBBBBccBBBcBBBcBBBBW",
    "WBcBcBBBccccBBBBBBcBBBBBBBBW",
    "WBBBBBBBBBBBBBBBBBBBBBBBBBBW",
    "WBBBBBccBBBBBBBBBBBBccBBBBBW",
    "WBBBBBccBBBBBBBBBBBBccBBBBBW",
    "WBBBBBBBBBBBBBBBBBBBBBBBBBBW",
    "WBBBBBBBBccccccccccBBBBBBBBW",
    "WBBBBBBBBBBBBBBBBBBBBBBBBBBW",
    "WWWWWWWWWWWWWWWWWWWWWWWWWWWW",
    "..LL....................LL..",
    "..LL....................LL..",
], {"W": rgba(140, 92, 56), "B": rgba(42, 72, 58), "c": rgba(232, 236, 226), "L": rgba(96, 60, 36)})

MARDI_CLOCHE = ([
    ".........hh.........",
    "........hhhh........",
    ".......YYYYYY.......",
    "......YYYYYYYY......",
    ".....YYyYYYYYYY.....",
    ".....YYYYYYYYYY.....",
    "....YYYYYYYYYYYY....",
    "....YYeYYYYYYeYY....",
    "....YYYYYYYYYYYY....",
    "...YYYYYYYYYYYYYY...",
    "...YYYYYmmmmYYYYY...",
    "..YYYYYYYYYYYYYYYY..",
    ".YYYYYYYYYYYYYYYYYY.",
    "dddddddddddddddddddd",
    "........kk..........",
    ".......kkkk.........",
], {"Y": rgba(226, 184, 70), "y": rgba(255, 236, 160), "d": rgba(160, 120, 40), "h": rgba(110, 70, 40),
    "e": rgba(40, 30, 20), "m": rgba(110, 60, 30), "k": rgba(90, 80, 70)})


def wall_clock(hand_angle):
    """L'Horloge de Classe : cadran rond, chiffres en points, deux yeux et des aiguilles."""
    size = 28
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c)
            if d <= c:
                px[x, y] = ((60, 64, 80) if d > c - 2.5 else (240, 236, 222)) + (255,)
    for i in range(12):  # graduations
        a = i * math.pi / 6
        px[int(round(c + math.cos(a) * (c - 4))), int(round(c + math.sin(a) * (c - 4)))] = (60, 60, 70, 255)
    for ex in (9, 18):  # yeux
        px[ex, 10] = px[ex, 11] = (30, 24, 40, 255)
    for r, a in ((9, hand_angle), (6, hand_angle * 0.3 + 1.2)):  # aiguilles
        for k in range(r):
            px[int(round(c + math.cos(a) * k)), int(round(c + math.sin(a) * k))] = (190, 50, 50, 255)
    return outline(img, (24, 20, 30))


def exam_sheet(eye_open):
    """L'Examen : grande copie a lignes, coin corne, un oeil enorme et des points d'interrogation."""
    w, h = 30, 38
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            if x + y > w + h - 8:
                continue  # coin corne
            c = (244, 242, 232)
            if y % 4 == 0 and 3 < x < w - 2:
                c = (170, 190, 226)
            if x == 4:
                c = (226, 120, 130)  # marge rouge
            px[x, y] = c + (255,)
    cx, cy = 15, 17
    for y in range(cy - 5, cy + 6):
        for x in range(cx - 8, cx + 9):
            if ((x - cx) / 8) ** 2 + ((y - cy) / 5) ** 2 <= 1:
                px[x, y] = (255, 255, 255, 255) if eye_open else (200, 196, 190, 255)
    if eye_open:
        for y in range(cy - 3, cy + 4):
            for x in range(cx - 3, cx + 4):
                if (x - cx) ** 2 + (y - cy) ** 2 <= 9:
                    px[x, y] = (40, 20, 30, 255) if (x - cx) ** 2 + (y - cy) ** 2 <= 3 else (200, 40, 50, 255)
    else:
        for x in range(cx - 7, cx + 8):
            px[x, cy] = (60, 40, 50, 255)
    for qx, qy in ((7, 28), (20, 29), (12, 33)):  # "?" rouges
        for dx, dy in ((0, 0), (1, -1), (2, 0), (2, 1), (1, 2), (1, 4)):
            px[qx + dx, qy + dy] = (200, 30, 40, 255)
    return outline(img, (30, 24, 34))


def mardi_sprites():
    trotteuse = rim_light(from_ascii(*MARDI_TROTTEUSE))
    pile = rim_light(from_ascii(*MARDI_PILE))
    stylo = rim_light(from_ascii(*MARDI_STYLO))
    coeur = rim_light(from_ascii(*MARDI_COEUR))
    tableau = from_ascii(*MARDI_TABLEAU)
    cloche = rim_light(from_ascii(*MARDI_CLOCHE))
    return {
        "trotteuse": [trotteuse, shift_rows(trotteuse, 7, 12, 1)],
        "pile_devoirs": [pile, shift_rows(pile, 0, 6, 1)],
        "stylo_rouge": [stylo, shift_rows(stylo, 0, 20, 1)],
        "battement": [coeur, squash(coeur, 6)],
        "tableau_noir": [tableau, shift_rows(tableau, 14, 20, 1)],
        "horloge_classe": [wall_clock(-1.2), wall_clock(-0.9)],
        "cloche": [cloche, shift_rows(cloche, 14, 20, 2)],
        "examen": [exam_sheet(False), exam_sheet(True)],
    }


# --- Bestiaire du mercredi (Doute) ------------------------------------------------------

def recolor(src, dark, light, alpha=255):
    """Repeint un sprite en degrade de deux couleurs selon sa luminosite (copie de verre,
    double sombre...). Les contours restent les plus sombres."""
    img = src.copy()
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            c = px[x, y]
            if c[3]:
                lum = (0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]) / 255
                px[x, y] = mix(dark, light, lum) + (alpha,)
    return img


MERCREDI_PIECE_PILE = ([
    "....DDDDDD....",
    "..DDDDDDDDDD..",
    ".DDDdDDDDDDDD.",
    ".DDdDDDDDDDDD.",
    "DDDdDDDDDDDDDD",
    "DDDdDDDDDDDDDD",
    "DDDdDDDDDDDDDD",
    ".DDDdDDDDDDDD.",
    ".DDDDddDDDDDD.",
    "..DDDDDDDDDD..",
    "....DDDDDD....",
], {"D": rgba(150, 120, 60), "d": rgba(230, 210, 140)})
MERCREDI_PIECE_FACE = ([
    "....GGGGGG....",
    "..GGGGGGGGGG..",
    ".GGGGGGGGGGGG.",
    ".GGGkGGGGkGGG.",
    "GGGGkGGGGkGGGG",
    "GGGGGGGGGGGGGG",
    "GGGGGGGGGGGGGG",
    ".GGGkGGGGkGGG.",
    ".GGGGkkkkGGGG.",
    "..GGGGGGGGGG..",
    "....GGGGGG....",
], {"G": rgba(240, 200, 80), "k": rgba(110, 70, 20)})

MERCREDI_CARREFOUR = ([
    "......WW..........",
    "AAAAAAWWAAAAAAA...",
    "AAAAAAWWAAAAAAAA..",
    "AAAAAAWWAAAAAAA...",
    "......WW..........",
    "..BBBBWWBBBBBB....",
    ".BBBBBWWBBBBBBB...",
    "..BBBBWWBBBBBB....",
    "......WW..........",
    ".....eWWe.........",
    "......WW..........",
    "......WW..........",
    ".....WWWW.........",
    "....WWWWWW........",
], {"W": rgba(120, 84, 56), "A": rgba(200, 170, 120), "B": rgba(170, 140, 96), "e": rgba(30, 20, 20)})

MASQUE_PALETTE = {"M": rgba(240, 236, 228), "m": rgba(190, 184, 176), "k": rgba(30, 24, 36), "t": rgba(120, 170, 230)}
MERCREDI_MASQUE_JOIE = [
    "..MMMMMMMMMM..",
    ".MMMMMMMMMMMM.",
    "MMMkkMMMMkkMMM",
    "MMkMMkMMkMMkMM",
    "MMMMMMMMMMMMMM",
    "MMMMMMMMMMMMMM",
    "MMkMMMMMMMMkMM",
    "MMMkkkkkkkkMMM",
    ".MMMMMMMMMMMM.",
    "..mmmmmmmmmm..",
]
MERCREDI_MASQUE_TRISTE = [
    "..MMMMMMMMMM..",
    ".MMMMMMMMMMMM.",
    "MMMMkkMMkkMMMM",
    "MMMkMMMMMMkMMM",
    "MMMMtMMMMtMMMM",
    "MMMMtMMMMtMMMM",
    "MMMMMkkkkMMMMM",
    "MMMMkMMMMkMMMM",
    ".MMMMMMMMMMMM.",
    "..mmmmmmmmmm..",
]


def broken_mirror(cracked):
    """Le Miroir Brise : grand miroir ovale dans un cadre dore, fissure en etoile."""
    w, h = 22, 30
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    cx, cy = (w - 1) / 2, (h - 1) / 2
    for y in range(h):
        for x in range(w):
            e = ((x - cx) / (w / 2)) ** 2 + ((y - cy) / (h / 2)) ** 2
            if e <= 1:
                glass = mix((150, 180, 220), (220, 236, 250), (y / h))
                px[x, y] = ((210, 170, 80) if e > 0.72 else glass) + (255,)
    if cracked:
        for a in range(6):
            ang = a * math.pi / 3 + 0.3
            for k in range(2, 9):
                x, y = int(round(cx + math.cos(ang) * k)), int(round(cy + math.sin(ang) * k * 1.3))
                px[x, y] = (60, 70, 100, 255)
    return outline(img, (40, 30, 30))


MERCREDI_LABYRINTHE = ([
    "SSSSSSSSSSSSSSSSSSSS",
    "SllllllSlllllllllllS",
    "SlSSSSlSlSSSSSSSSSlS",
    "SlSlllllllllllllSlSS",
    "SlSlSSSSSSSSSSSSlSlS",
    "SlllSssssssssssSlllS",
    "SSSlSsGGGssGGGsSlSSS",
    "SlllSsGkGssGkGsSlllS",
    "SlSlSssssssssssSlSlS",
    "SlSlSSSSSSSSSSSSlSlS",
    "SlSllllllllllllllSlS",
    "SlSSSSSSSSSSSSSSSSlS",
    "SllllllllSllllllllll",
    "SSSSSSSSSSSSSSSSSSSS",
], {"S": rgba(120, 128, 120), "l": rgba(70, 80, 72), "s": rgba(90, 96, 90), "G": rgba(150, 255, 170),
    "k": rgba(20, 60, 30)})

MERCREDI_VOIE = ([
    "....HHHHHH....",
    "...HHHHHHHH...",
    "..HHHLLDDDHH..",
    "..HHLLLDDDDH..",
    "..HHLeLDDrDH..",
    "..HHLLLDDDDH..",
    "...HHLLDDDH...",
    "..HHHHHHHHHH..",
    ".HHHHHHHHHHHH.",
    ".HHHHHHHHHHHH.",
    "HHHHHHHHHHHHHH",
    "HHHHHHHHHHHHHH",
    "HHHHHHHHHHHHHH",
    ".hhhhhhhhhhhh.",
], {"H": rgba(80, 70, 110), "h": rgba(50, 42, 72), "L": rgba(240, 230, 210), "D": rgba(40, 30, 50),
    "e": rgba(60, 50, 80), "r": rgba(230, 60, 60)})


def mercredi_sprites():
    frames = player_frames()
    glass = [recolor(f, (70, 110, 170), (200, 230, 255), 210) for f in (frames[0], frames[3])]
    other = [recolor(f, (20, 10, 30), (130, 80, 160)) for f in (frames[0], frames[1])]
    carrefour = rim_light(from_ascii(*MERCREDI_CARREFOUR))
    labyrinthe = rim_light(from_ascii(*MERCREDI_LABYRINTHE))
    voie = rim_light(from_ascii(*MERCREDI_VOIE))
    return {
        "reflet": glass,
        "pile_ou_face": [from_ascii(*MERCREDI_PIECE_PILE), from_ascii(*MERCREDI_PIECE_FACE)],
        "carrefour": [carrefour, shift_rows(carrefour, 0, 9, 1)],
        "masque": [from_ascii(MERCREDI_MASQUE_JOIE, MASQUE_PALETTE), from_ascii(MERCREDI_MASQUE_TRISTE, MASQUE_PALETTE)],
        "miroir_brise": [broken_mirror(False), broken_mirror(True)],
        "labyrinthe": [labyrinthe, dim(labyrinthe, 0.85)],
        "deux_voies": [voie, squash(voie, 7)],
        "autre_soi": other,
    }


# --- Bestiaire du jeudi (Frustration) ----------------------------------------------------

JEUDI_GROGNE = ([
    "..f.f..f.f....",
    ".fRRRRRRRRRf..",
    "fRRRRRRRRRRRf.",
    "RRRkkRRRRkkRRR",
    "RRRRwkRRkwRRRR",
    "RRRRRRRRRRRRRR",
    "RRRRmmmmmmRRRR",
    "RRRmRRRRRRmRRR",
    ".RRRRRRRRRRRR.",
    "..rrrrrrrrrr..",
], {"f": rgba(240, 110, 90), "R": rgba(204, 62, 52), "r": rgba(140, 36, 34), "k": rgba(40, 10, 10),
    "w": rgba(255, 230, 200), "m": rgba(70, 10, 10)})

JEUDI_PORTE = ([
    ".DDDDDDDDDDDD.",
    "DDddddddddddDD",
    "DdWWWWWWWWWWdD",
    "DdWWkkWWkkWWdD",
    "DdWWWeWWeWWWdD",
    "DdWWWWWWWWWWdD",
    "DdWWWWmmWWWWdD",
    "DdWWWWWWWWWWdD",
    "DdWWWWWWWWWYdD",
    "DdWWWWWWWWWWdD",
    "DdWWWWWWWWWWdD",
    "DddddddddddddD",
    ".DDDDDDDDDDDD.",
    "..ll......ll..",
    "..ll......ll..",
], {"W": rgba(156, 100, 62), "D": rgba(80, 48, 32), "d": rgba(116, 72, 46), "k": rgba(30, 16, 10),
    "e": rgba(250, 220, 120), "m": rgba(40, 20, 12), "Y": rgba(240, 200, 80), "l": rgba(60, 40, 30)})

JEUDI_RESSORT = ([
    "...HHHHHH...",
    "..HHeHHeHH..",
    "..HHHHHHHH..",
    "...HHmmHH...",
    ".CCCCCCCCCC.",
    "..CCCCCCCC..",
    ".CCCCCCCCCC.",
    "..CCCCCCCC..",
    ".CCCCCCCCCC.",
    "..CCCCCCCC..",
    ".BBBBBBBBBB.",
], {"H": rgba(120, 204, 140), "e": rgba(20, 40, 20), "m": rgba(30, 80, 40), "C": rgba(196, 196, 206),
    "B": rgba(80, 80, 96)})

JEUDI_COCOTTE = ([
    "........VV........",
    ".......VVVV.......",
    "..LLLLLLLLLLLLLL..",
    ".LLLLLLLLLLLLLLLL.",
    "HHPPPPPPPPPPPPPPHH",
    ".PPPPPPPPPPPPPPPP.",
    ".PPPkkPPPPPPkkPPP.",
    ".PPPPePPPPPPePPPP.",
    ".PPPPPPPPPPPPPPPP.",
    ".PPPPPPmmmmPPPPPP.",
    ".PPPPPmPPPPmPPPPP.",
    ".PPPPPPPPPPPPPPPP.",
    "..pppppppppppppp..",
], {"V": rgba(210, 50, 50), "L": rgba(140, 144, 156), "H": rgba(40, 40, 46), "P": rgba(178, 182, 192),
    "p": rgba(120, 124, 134), "k": rgba(30, 30, 36), "e": rgba(250, 120, 60), "m": rgba(40, 30, 30)})

JEUDI_PATRON = ([
    "......HHHHHH......",
    ".....HHHHHHHH.....",
    ".....HHHHHHHH.....",
    ".....HHHHHHHH.....",
    "......HHHHHH......",
    ".......HHHH.......",
    "..SSSSSWWWWSSSSS..",
    ".SSSSSSWTTWSSSSSS.",
    "SSSSSSSSTTSSSSSSSS",
    "SSSSSSSSTTSSSSSSSS",
    "SSSSSSSSTTSSSSSSSS",
    "SSSSSSSSSSSSSSSSSS",
    "SSSSSSSSSSSSSSSSSS",
    ".SSSSSSSSSSSSSSSS.",
    "..SSSSSS..SSSSSS..",
    "..SSSSS....SSSSS..",
    "..kkkkk....kkkkk..",
], {"H": rgba(212, 206, 200), "S": rgba(52, 52, 66), "W": rgba(240, 240, 240), "T": rgba(190, 40, 50),
    "k": rgba(20, 20, 24)})


def conveyor(offset):
    """Le Tapis Roulant : une bande striee qui defile, deux rouleaux qui regardent."""
    w, h = 34, 12
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(2, h - 2):
        for x in range(2, w - 2):
            px[x, y] = ((70, 70, 80) if (x + offset) % 6 < 3 else (100, 100, 112)) + (255,)
    for cx in (3, w - 4):  # rouleaux avec un oeil
        for y in range(h):
            for x in range(cx - 3, cx + 4):
                if (x - cx) ** 2 + (y - h // 2) ** 2 <= 10:
                    px[x, y] = (160, 160, 170, 255)
        px[cx, h // 2] = px[cx, h // 2 - 1] = (220, 40, 40, 255)
    return outline(img, (24, 24, 30))


def brick_wall(cracked):
    """Le Mur : un pan de briques qui avance, deux yeux fermes de colere."""
    w, h = 22, 38
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            row = y // 5
            mortar = y % 5 == 0 or (x + (5 if row % 2 else 0)) % 10 == 0
            c = (150, 70, 56) if not mortar else (190, 180, 170)
            if not mortar and (x * 7 + y * 3) % 11 == 0:
                c = (128, 58, 46)
            px[x, y] = c + (255,)
    for ex in (6, 14):
        for dx in range(3):
            px[ex + dx, 12] = (30, 10, 10, 255)
        px[ex, 11] = px[ex + 2, 13] = (30, 10, 10, 255)
    if cracked:
        x = 11
        for y in range(16, 34):
            x = max(1, min(w - 2, x + ((y * 5) % 3) - 1))
            px[x, y] = (40, 20, 20, 255)
    return outline(img, (40, 20, 20))


def storm_cloud(bolt):
    """La Colere : un nuage d'orage aux yeux rouges, un eclair qui gronde dessous."""
    w, h = 36, 26
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for cx, cy, r in ((9, 10, 7), (18, 7, 8), (27, 10, 7), (14, 13, 7), (23, 13, 7)):
        for y in range(h):
            for x in range(w):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    px[x, y] = ((70, 66, 84) if y > 10 else (100, 96, 116)) + (255,)
    for ex in (13, 22):
        px[ex, 11] = px[ex + 1, 11] = px[ex, 12] = (230, 40, 40, 255)
    color = (255, 240, 120) if bolt else (160, 150, 90)
    x = 17
    for y in range(19, h):
        x += 1 if (y // 2) % 2 == 0 else -1
        px[x, y] = color + (255,)
        px[x + 1, y] = color + (255,)
    return outline(img, (30, 26, 40))


def jeudi_sprites():
    grogne = rim_light(from_ascii(*JEUDI_GROGNE))
    porte = rim_light(from_ascii(*JEUDI_PORTE))
    ressort = rim_light(from_ascii(*JEUDI_RESSORT))
    cocotte = rim_light(from_ascii(*JEUDI_COCOTTE))
    patron = rim_light(from_ascii(*JEUDI_PATRON))
    return {
        "grogne": [grogne, squash(grogne, 5)],
        "porte_close": [porte, shift_rows(porte, 13, 20, 1)],
        "ressort": [ressort, squash(ressort, 7)],
        "cocotte": [cocotte, shift_rows(cocotte, 0, 2, 1)],
        "patron": [patron, shift_rows(patron, 14, 20, 1)],
        "tapis_roulant": [conveyor(0), conveyor(3)],
        "mur": [brick_wall(False), brick_wall(True)],
        "colere": [storm_cloud(False), storm_cloud(True)],
    }


# --- Bestiaire du vendredi (Epuisement) --------------------------------------------------

VENDREDI_FARDEAU = ([
    "...pp...pp...pp.....",
    "..pkpp.pkpp.pkpp....",
    "..pppp.pppp.pppp....",
    ".GGGGGGGGGGGGGGGG...",
    "GGGGGGGGGGGGGGGGGG..",
    "GGGkkGGGGGGGkkGGGG..",
    "GGGGGGGGGGGGGGGGGGG.",
    "GGGGGGGmmmmGGGGGGGG.",
    "GGGGGGGGGGGGGGGGGGG.",
    ".GGGGGGGGGGGGGGGGG..",
    "..gggggggggggggggg..",
    "...ll..........ll...",
], {"p": rgba(200, 170, 140), "k": rgba(40, 30, 30), "G": rgba(130, 120, 110), "g": rgba(90, 82, 76),
    "m": rgba(50, 40, 40), "l": rgba(60, 54, 50)})
VENDREDI_PASSAGER = ([
    "..pppp..",
    ".pppppp.",
    "ppkppkpp",
    "pppppppp",
    ".pmmmmp.",
    "..l..l..",
], {"p": rgba(200, 170, 140), "k": rgba(40, 30, 30), "m": rgba(120, 70, 60), "l": rgba(90, 70, 60)})
VENDREDI_SANGSUE = ([
    "...SSSSSS...",
    ".SSSSSSSSSS.",
    "SSSeSSSSeSSS",
    "SSSSSSSSSSSS",
    "SSSSmmmmSSSS",
    ".ssssssssss.",
], {"S": rgba(150, 90, 170), "s": rgba(100, 56, 120), "e": rgba(250, 240, 160), "m": rgba(60, 20, 60)})
VENDREDI_SOIGNANT = ([
    "...HHHH...",
    "..HHHHHH..",
    "..HeHHeH..",
    "..HHHHHH..",
    "...HHHH...",
    ".WWWWWWWW.",
    "WWWWRRWWWW",
    "WWWRRRRWWW",
    "WWWWRRWWWW",
    "WWWWWWWWWW",
    "WWWWWWWWWW",
    ".WWWWWWWW.",
    ".ww....ww.",
], {"H": rgba(110, 100, 130), "e": rgba(230, 230, 255), "W": rgba(236, 238, 244), "w": rgba(170, 172, 186),
    "R": rgba(220, 60, 70)})
VENDREDI_BOUGIE = ([
    "...F....",
    "..FYF...",
    "..FYF...",
    "...k....",
    ".CCCCC..",
    ".CeCeC..",
    ".CCCCC..",
    "CCCCCCd.",
    ".CCCCCd.",
    ".CCdCC..",
    ".CCdCCd.",
    "CCCCCCCd",
    "cccccccc",
], {"F": rgba(255, 150, 60), "Y": rgba(255, 240, 170), "k": rgba(40, 30, 30), "C": rgba(236, 226, 206),
    "e": rgba(60, 40, 40), "d": rgba(250, 244, 230), "c": rgba(180, 168, 150)})
VENDREDI_OEUF = ([
    "..EEEE..",
    ".EEEEEE.",
    "EEEsEEEE",
    "EEEEEsEE",
    "EEsEEEEE",
    "EEEEEEEE",
    ".EEEEEE.",
    "..eeee..",
], {"E": rgba(240, 232, 214), "s": rgba(170, 150, 120), "e": rgba(190, 180, 160)})
VENDREDI_HORLOGE = ([
    "..WWWWWWWWWWWWWW..",
    ".WWwwwwwwwwwwwwWW.",
    "WWwFFFFFFFFFFFFwWW",
    "WWwFFkFFFFFFkFFwWW",
    "WWwFFFFFFFFFFFFwWW",
    "WWwFFFFFFFFFFFFwWW",
    "WWwFFFFFmmFFFFFwWW",
    "WWwFFFFFFFFFFFFwWW",
    "WWwwwwwwwwwwwwwwWW",
    ".WWWWWWWWWWWWWWWW.",
    "..WWWW......WWWW..",
], {"W": rgba(110, 70, 44), "w": rgba(80, 50, 32), "F": rgba(236, 226, 200), "k": rgba(30, 20, 20),
    "m": rgba(80, 40, 30)})


def atlas_sprite(lift):
    """Atlas : un geant courbe qui porte un monde au-dessus de sa tete."""
    w, h = 30, 40
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    cy = 9 - lift
    for y in range(h):
        for x in range(w):
            if (x - 15) ** 2 + (y - cy) ** 2 <= 64:  # le monde
                px[x, y] = ((80, 140, 200) if (x * 3 + y * 5) % 7 > 2 else (90, 170, 110)) + (255,)
    for y in range(18, 38):  # le corps
        half = 6 + (y - 18) // 4
        for x in range(15 - half, 15 + half):
            px[x, y] = (150, 120, 96, 255)
    for x, y in ((9, 17 - lift), (21, 17 - lift), (10, 18), (20, 18)):  # bras leves
        for k in range(3):
            px[x, y + k] = (150, 120, 96, 255)
    px[13, 23] = px[17, 23] = (40, 30, 30, 255)
    for x in range(12, 19):
        px[x, 27] = (90, 60, 50, 255)  # bouche crispee
    return outline(img, (30, 22, 20))


def nest_sprite(beak_open):
    """Le Nid : une mere-oiseau aux plumes ebouriffees dans son nid de branches."""
    w, h = 30, 22
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            if ((x - 15) / 9) ** 2 + ((y - 8) / 7) ** 2 <= 1:  # l'oiseau
                px[x, y] = (120, 96, 150, 255)
    for y in range(12, h):  # le nid
        for x in range(w):
            if ((x - 15) / 15) ** 2 + ((y - 15) / 6) ** 2 <= 1:
                px[x, y] = ((140, 100, 60) if (x + y) % 3 else (100, 70, 40)) + (255,)
    px[11, 6] = px[18, 6] = (250, 240, 200, 255)
    for k in range(3):
        px[22 + k, 8] = (240, 170, 60, 255)
        if beak_open:
            px[22 + k, 10] = (240, 170, 60, 255)
    return outline(img, (30, 22, 30))


def weight_sprite(slump):
    """Le Poids du Monde : une masse faite de toutes les silhouettes qu'il porte, les yeux las."""
    w, h = 36, 42
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    rng = random.Random(5)
    for i in range(14):  # tetes empilees
        cx, cy = rng.randrange(6, 30), rng.randrange(4, 22) + slump
        shade_k = rng.uniform(0.7, 1.0)
        for y in range(h):
            for x in range(w):
                if (x - cx) ** 2 + (y - cy) ** 2 <= 16:
                    px[x, y] = shade((110, 100, 130), shade_k) + (255,)
    for y in range(18, h):  # le grand corps qui porte tout
        half = 10 + (y - 18) // 3
        for x in range(max(0, 18 - half), min(w, 18 + half)):
            px[x, y] = (84, 76, 104, 255)
    for ex in (13, 22):
        for dx in range(3):
            px[ex + dx, 28 + slump // 2] = (230, 220, 240, 255)  # yeux mi-clos
    return outline(img, (24, 20, 34))


def vendredi_sprites():
    fardeau = rim_light(from_ascii(*VENDREDI_FARDEAU))
    passager = from_ascii(*VENDREDI_PASSAGER)
    sangsue = rim_light(from_ascii(*VENDREDI_SANGSUE))
    soignant = rim_light(from_ascii(*VENDREDI_SOIGNANT))
    bougie = rim_light(from_ascii(*VENDREDI_BOUGIE))
    oeuf = from_ascii(*VENDREDI_OEUF)
    horloge = rim_light(from_ascii(*VENDREDI_HORLOGE))
    return {
        "fardeau": [fardeau, squash(fardeau, 6)],
        "passager": [passager, shift_rows(passager, 5, 6, 1)],
        "sangsue": [sangsue, squash(sangsue, 3)],
        "soignant": [soignant, shift_rows(soignant, 12, 13, 1)],
        "bougie_fondue": [bougie, shift_rows(bougie, 0, 4, 1)],
        "oeuf": [oeuf, shift_rows(oeuf, 0, 8, 1)],
        "atlas": [atlas_sprite(0), atlas_sprite(1)],
        "nid": [nest_sprite(False), nest_sprite(True)],
        "balancier": [horloge, shift_rows(horloge, 0, 2, 1)],
        "poids_du_monde": [weight_sprite(0), weight_sprite(2)],
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

    for name, (rows, pal) in NPCS.items():
        save(from_ascii(rows, pal), "npcs", f"{name}.png")
    save(from_ascii(*QUEST_ITEM), "props", "quest_item.png")

    for day, name in enumerate(DAYS):
        save(tower_sprite(day), "hub", f"tower_{name}.png")
    save(from_ascii(*PADLOCK), "hub", "padlock.png")
    save(from_ascii(*BOOK), "hub", "book.png")

    for name, frames in lundi_sprites(random.Random(7)).items():
        save(sheet(frames), "mobs", "lundi", f"{name}.png")
    for name, frames in mardi_sprites().items():
        save(sheet(frames), "mobs", "mardi", f"{name}.png")
    for name, frames in mercredi_sprites().items():
        save(sheet(frames), "mobs", "mercredi", f"{name}.png")
    for name, frames in jeudi_sprites().items():
        save(sheet(frames), "mobs", "jeudi", f"{name}.png")
    for name, frames in vendredi_sprites().items():
        save(sheet(frames), "mobs", "vendredi", f"{name}.png")

    frames = player_frames()
    save(frames[0], "player", "idle.png")
    save(sheet(frames), "player", "sheet.png")
    for name, animate in MOB_ANIMATIONS.items():
        base = rim_light(Image.open(os.path.join(SOURCES, f"{name}.png")).convert("RGBA"))
        save(sheet([base, animate(base)]), "mobs", name, "idle.png")


if __name__ == "__main__":
    main()
