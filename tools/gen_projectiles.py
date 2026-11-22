"""Projectiles ennemis detailles et animes (pixel art, 4 images cote a cote).

Lancer depuis la racine du projet : python tools/gen_projectiles.py
Ecrit assets/sprites/projectiles/<nuit>/<mob>.png : une bande de FRAMES images carrees ; le jeu
les anime (Hazards.shoot : largeur = FRAMES x hauteur). Remplace, pour les mobs listes ici, les
projectiles fixes de tools/gen_pixel_art.py.
Direction artistique (voir la memoire du projet) : modele (ombre, lumiere, reflet), contour sombre
colore, petite animation (vacille, se balance, tourne), lisible a 2x.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "projectiles")
FRAMES = 4


def strip(size, draw):
    """Bande de FRAMES images size x size ; draw(img, frame, ox) dessine l'image `frame`."""
    img = Image.new("RGBA", (size * FRAMES, size), (0, 0, 0, 0))
    for f in range(FRAMES):
        draw(img, f, f * size)
    return img


def px(img, x, y, color):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color if len(color) == 4 else color + (255,))


def outline(img, ox, size, color):
    """Contour d'un pixel autour de tout ce qui est opaque (dans l'image commencant a ox)."""
    solid = {(x, y) for x in range(ox, ox + size) for y in range(size) if img.getpixel((x, y))[3] > 200}
    for x, y in list(solid):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if ox <= n[0] < ox + size and 0 <= n[1] < size and n not in solid and img.getpixel(n)[3] < 200:
                px(img, n[0], n[1], color)


# --- Lundi (Fatigue) ---------------------------------------------------------------------------

def veilleuse():
    """Flamme de veilleuse : un coeur chaud dans un halo tramé, une pointe qui vacille."""
    size = 14
    white, yellow, orange, ember = (255, 251, 232), (255, 222, 120), (246, 160, 70), (196, 92, 58)
    ink = (74, 34, 46)
    halo = (255, 226, 150, 110)
    tips = [(0, 4), (1, 3), (0, 5), (-1, 3)]  # (decalage, hauteur) de la flamme par image

    def draw(img, f, ox):
        cx, cy = ox + 7, 8
        for y in range(size):  # halo trame qui tourne
            for x in range(size):
                d = math.hypot(x - 7, y - 8)
                if 4.6 < d < 6.4 and (x + y + f) % 3 == 0:
                    px(img, ox + x, y, halo)
        for y in range(size):  # le coeur : boule degradee, lumiere en haut a gauche
            for x in range(size):
                d = math.hypot(x - 7 + 0.4, y - 8 + 0.4)
                if d <= 3.6:
                    shade = white if d < 1.4 else (yellow if d < 2.6 else orange)
                    if x > 8 and y > 9 and d > 2.2:
                        shade = ember
                    px(img, ox + x, y, shade)
        dx, h = tips[f]
        for i in range(h):  # la pointe de la flamme
            x = cx + (dx if i >= h // 2 else 0)
            px(img, x, cy - 4 - i, yellow if i < h - 1 else white)
            if i < h - 2:
                px(img, x + 1, cy - 4 - i, orange)
        outline(img, ox, size, ink)
        px(img, cx - 1, cy - 1, (255, 255, 255))  # reflet

    return strip(size, draw)


def reveil_grincheux():
    """Cloche de reveil : elle se balance, le battant tape, des ondes de son partent."""
    size = 16
    gold, gold_l, gold_d, shine = (240, 190, 70), (255, 224, 120), (190, 124, 40), (255, 250, 220)
    ink = (70, 38, 30)
    sound = (255, 236, 180, 220)
    swing = [-1, 0, 1, 0]

    def draw(img, f, ox):
        s = swing[f]
        top = 3
        profile = [1, 2, 3, 3, 3, 3, 4, 4, 5]  # demi-largeur par ligne : dome, puis evasement
        for y in range(top, top + 9):  # corps de la cloche
            half = profile[y - top]
            row_shift = round(s * (y - top) / 8)
            for x in range(-half, half + 1):
                c = gold
                if x <= -half + 1:
                    c = gold_l
                elif x >= half - 1:
                    c = gold_d
                px(img, ox + 8 + x + row_shift, y, c)
        for x in range(-6, 7):  # rebord
            px(img, ox + 8 + x + s, top + 9, gold_d if x > 2 else gold)
        px(img, ox + 8, top - 1, gold_d)  # anneau du haut
        px(img, ox + 8, top - 2, gold)
        px(img, ox + 6 + s // 2, top + 2, shine)  # reflet
        px(img, ox + 6 + s // 2, top + 3, shine)
        clap = -s  # le battant part a l'oppose
        px(img, ox + 8 + clap, top + 10, gold_d)
        px(img, ox + 8 + clap, top + 11, gold)
        outline(img, ox, size, ink)
        if f in (0, 2):  # ondes de son, du cote ou elle frappe
            side = -1 if f == 0 else 1
            for dy in range(-2, 3):
                px(img, ox + 8 + side * (7 - abs(dy) // 2), top + 5 + dy, sound)

    return strip(size, draw)


# --- Motifs des effets (semes par les shaders des dangers : assets/shaders/pixel_*.gdshader) -------
# Une bande de motifs de 8x8 pixels d'art, en deux tons : blanc (le motif, teinte du ton clair du
# danger) et noir (son contour, teinte du cerne). 1 texel = 1 pixel d'art.
MOTIF = 8
LUNDI_MOTIFS = [
    # z de sommeil
    ["........", ".KKKKK..", ".KWWWWK.", "..KKWK..", "..KWK...", ".KWKKK..", ".KWWWWK.", "..KKKK.."],
    # etoile
    ["...K....", "..KWK...", ".KKWKK..", "KWWWWWK.", ".KKWKK..", "..KWK...", "...K....", "........"],
    # croissant de lune
    ["..KKK...", ".KWWK...", "KWWK....", "KWK.....", "KWWK....", ".KWWKK..", "..KKK...", "........"],
    # plume / duvet
    ["......K.", ".....KWK", "....KWK.", "..KKWK..", ".KWWK...", "KWWK....", ".KK.....", "........"],
    # petit eclat
    ["........", "...K....", "..KWK...", ".KWWWK..", "..KWK...", "...K....", "........", "........"],
]

NIGHT_MOTIFS = {
    "mardi": [
        # tache d'encre
        ["..KK....", ".KWWK.K.", "KWWWWKWK", "KWWWWWK.", ".KWWWWK.", "KWKWWK..", ".K.KK...", "........"],
        # coche
        ["........", "......KK", ".....KWK", "K...KWK.", "WK.KWK..", "KWKWK...", ".KWK....", "..K....."],
        # croix
        ["KK...KK.", "KWK.KWK.", ".KWKWK..", "..KWK...", ".KWKWK..", "KWK.KWK.", "KK...KK.", "........"],
        # petit reveil
        ["KK...KK.", "K.KKK.K.", ".KWWWK..", "KWWKWWK.", "KWWKKWK.", "KWWWWWK.", ".KWWWK..", "K.KKK.K."],
        # crayon
        ["......KK", ".....KWK", "....KWK.", "...KWK..", "..KWK...", ".KWK....", "KKK.....", "K......."],
    ],
    "mercredi": [
        # eclat de verre
        ["...K....", "..KWK...", "..KWWK..", ".KWWWK..", ".KWWWWK.", "KWWWKK..", "KWKK....", "KK......"],
        # piece
        ["..KKKK..", ".KWWWWK.", "KWWKWWWK", "KWWKWWWK", "KWWKWWWK", "KWWWWWWK", ".KWWWWK.", "..KKKK.."],
        # point d'interrogation
        [".KKKK...", "KWWWWK..", "KK..KWK.", "...KWK..", "..KWK...", "..KK....", "..KWK...", "...K...."],
        # fleche
        ["....K...", "....KK..", "KKKKKWK.", "KWWWWWWK", "KKKKKWK.", "....KK..", "....K...", "........"],
        # oeil (le masque)
        ["........", "..KKKK..", ".KWWWWK.", "KWWKKWWK", "KWWKKWWK", ".KWWWWK.", "..KKKK..", "........"],
    ],
    "jeudi": [
        # eclair
        ["....KK..", "...KWK..", "..KWK...", ".KWWWWK.", "...KWK..", "..KWK...", "..KK....", "........"],
        # vapeur
        ["..K.....", ".KWK.K..", "KWWKKWK.", ".KWWWWK.", "KWWWWWWK", ".KWWWWK.", "..KKKK..", "........"],
        # brique
        ["........", "KKKKKKKK", "KWWKWWWK", "KKKKKKKK", "KWWWKWWK", "KKKKKKKK", "........", "........"],
        # rouage
        ["..K..K..", ".KWKKWK.", "KWWWWWWK", ".KWKKWK.", ".KWKKWK.", "KWWWWWWK", ".KWKKWK.", "..K..K.."],
        # gribouillis de colere
        [".KKKKK..", "KWKKKWK.", "KWKWKWK.", "KWKKWWK.", "KWWWWK..", ".KKKK...", "........", "........"],
    ],
    "vendredi": [
        # plume
        ["......K.", ".....KWK", "....KWK.", "..KKWK..", ".KWWK...", "KWWK....", ".KK.....", "........"],
        # goutte de cire
        ["...K....", "..KWK...", "..KWK...", ".KWWWK..", "KWWWWWK.", "KWWWWWK.", ".KWWWK..", "..KKK..."],
        # pansement
        ["..KKK...", "..KWK...", "KKKWKKK.", "KWWWWWK.", "KKKWKKK.", "..KWK...", "..KKK...", "........"],
        # goutte
        ["........", "...K....", "..KWK...", ".KWWWK..", ".KWWWK..", "..KKK...", "........", "........"],
        # poids
        ["...KK...", "..K..K..", ".KKKKKK.", "KWWWWWWK", "KWWWWWWK", "KWWWWWWK", ".KKKKKK.", "........"],
    ],
    "samedi": [
        # enveloppe
        ["........", "KKKKKKKK", "KKWWWWKK", "KWKWWKWK", "KWWKKWWK", "KWWWWWWK", "KKKKKKKK", "........"],
        # feuille qui tombe
        ["......K.", "...KKKWK", "..KWWWK.", ".KWWWWK.", "KWWWWK..", "KWWKK...", ".KK.....", "K......."],
        # petit coeur
        ["........", ".KK.KK..", "KWWKWWK.", "KWWWWWK.", ".KWWWK..", "..KWK...", "...K....", "........"],
        # combine de telephone
        [".KK.....", "KWWK....", "KWK.....", ".KWK....", "..KWK...", "...KWWK.", "....KWWK", ".....KK."],
        # etoile
        ["...K....", "..KWK...", ".KKWKK..", "KWWWWWK.", ".KKWKK..", "..KWK...", "...K....", "........"],
    ],
    "dimanche": [
        # sablier
        ["KKKKKKK.", ".KWWWK..", "..KWK...", "...K....", "..KWK...", ".KWWWK..", "KKKKKKK.", "........"],
        # spirale
        [".KKKKK..", "KWWWWWK.", "KWKKKWK.", "KWKWKWK.", "KWKKWWK.", "KWWWK...", ".KKKK...", "........"],
        # page de calendrier
        [".K..K...", "KKKKKKK.", "KWWWWWK.", "KWKWKWK.", "KWWWWWK.", "KWKWKWK.", "KKKKKKK.", "........"],
        # lune
        ["..KKK...", ".KWWK...", "KWWK....", "KWK.....", "KWWK....", ".KWWKK..", "..KKK...", "........"],
        # reveil-matin
        ["K.....K.", ".KKKKK..", "KWWKWWK.", "KWWKWWK.", "KWWWKWK.", ".KWWWK..", "..KKK...", ".K...K.."],
    ],
}


def motifs(rows_list, name):
    img = Image.new("RGBA", (MOTIF * len(rows_list), MOTIF), (0, 0, 0, 0))
    for i, rows in enumerate(rows_list):
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == "W":
                    img.putpixel((i * MOTIF + x, y), (255, 255, 255, 255))
                elif ch == "K":
                    img.putpixel((i * MOTIF + x, y), (0, 0, 0, 255))
    path = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "fx")
    os.makedirs(path, exist_ok=True)
    img.save(os.path.join(path, name + ".png"))
    print("motifs", name, img.size)


# --- Le reveur ---------------------------------------------------------------------------------

def oreiller():
    """Petit oreiller du Lance-pierre (scripts/combat/pellet.gd, assets/sprites/player/) : il tournoie d'un huitieme de tour
    par image (symetrique : 4 images font un demi-tour, la boucle ne saute pas), coins pointus, bords
    creuses, bouton au centre et plis qui partent des coins."""
    from proj_art import blank, dots, hexc, ink, mask_of, ramp, rot, shade, strip as strip_of
    size = 16
    c = 7.5
    linen = ramp("6f6aa8", "aeaadc", "e2e0f6", "ffffff")
    a, b = 5.6, 3.9
    body = []  # rectangle bombe (super-ellipse), avec une petite pointe a chaque coin
    for i in range(48):
        t = i / 48 * math.tau
        ct, st = math.cos(t), math.sin(t)
        k = 1.0 + 0.32 * max(0.0, abs(math.sin(2 * t)) - 0.86) / 0.14  # pointe vers 45 degres
        body.append((c + a * k * math.copysign(abs(ct) ** 0.6, ct), c + b * k * math.copysign(abs(st) ** 0.6, st)))
    tips = [(sx, sy) for sx in (-1, 1) for sy in (-1, 1)]

    def make(f):
        img = blank(size)
        angle = f * math.pi / 4
        shade(img, mask_of(size, [rot(body, angle, c, c)]), linen)
        for sx, sy in tips:  # plis : des coins vers le centre
            dots(img, rot([(c + sx * 4.2, c + sy * 2.7), (c + sx * 3.2, c + sy * 2.0)], angle, c, c), linen[1])
        dots(img, rot([(c, c)], angle, c, c), hexc("7f95c9"))  # le bouton
        ink(img, hexc("2e2a58"))
        return img
    return strip_of(size, FRAMES, make)


SETS = {
    "lundi": {"veilleuse": veilleuse, "reveil_grincheux": reveil_grincheux},
}
# Les tirs du reveur vont avec ses sprites (projectiles/<nuit>/ ne garde que ceux des mobs).
PLAYER_OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "player")

if __name__ == "__main__":
    import night_projectiles
    SETS.update(night_projectiles.SETS)
    motifs(LUNDI_MOTIFS, "motifs_lundi")
    for night, rows in NIGHT_MOTIFS.items():
        motifs(rows, "motifs_" + night)
    for night, makers in SETS.items():
        os.makedirs(os.path.join(OUT, night), exist_ok=True)
        for name, make in makers.items():
            img = make()
            img.save(os.path.join(OUT, night, name + ".png"))
            print(night, name, img.size)
    oreiller().save(os.path.join(PLAYER_OUT, "oreiller.png"))
    print("reveur oreiller")
