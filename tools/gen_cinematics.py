"""Decors des cinematiques (pixel art haute definition, plus fin et plus doux que le jeu).

Lancer depuis la racine du projet : python tools/gen_cinematics.py [scene...]
Chaque scene est une pile de calques 640x360 (1 pixel = 1 unite de l'ecran du jeu, deux fois plus
fin que les sprites en jeu) ecrits dans assets/cinematics/<scene>/<calque>.png, du fond vers
l'avant. On dessine chaque calque 4 fois plus grand puis on le reduit : courbes lisses et bords
adoucis, toujours sur la grille de pixels. Lumieres, particules et camera viennent de l'animation.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "cinematics")
W, H = 640, 360
SS = 4  # sur-echantillonnage


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3])


def bezier(points, n=24):
    """Courbe de Bezier (3 ou 4 points de controle) -> liste de points."""
    out = []
    for i in range(n + 1):
        t = i / n
        if len(points) == 3:
            (x0, y0), (x1, y1), (x2, y2) = points
            x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * x1 + t * t * x2
            y = (1 - t) ** 2 * y0 + 2 * (1 - t) * t * y1 + t * t * y2
        else:
            (x0, y0), (x1, y1), (x2, y2), (x3, y3) = points
            x = (1 - t) ** 3 * x0 + 3 * (1 - t) ** 2 * t * x1 + 3 * (1 - t) * t * t * x2 + t ** 3 * x3
            y = (1 - t) ** 3 * y0 + 3 * (1 - t) ** 2 * t * y1 + 3 * (1 - t) * t * t * y2 + t ** 3 * y3
        out.append((x, y))
    return out


class Layer:
    """Calque dessine en grand (coordonnees 640x360 multipliees par SS), reduit a la fin."""

    def __init__(self, fill=(0, 0, 0, 0), size=(W, H)):
        self.size = size
        self.img = Image.new("RGBA", (size[0] * SS, size[1] * SS), fill)
        self.d = ImageDraw.Draw(self.img)

    @staticmethod
    def s(box):
        return [v * SS for v in box]

    def rect(self, box, fill, r=0):
        if r:
            self.d.rounded_rectangle(self.s(box), radius=r * SS, fill=fill)
        else:
            self.d.rectangle(self.s(box), fill=fill)

    def ellipse(self, box, fill):
        self.d.ellipse(self.s(box), fill=fill)

    def poly(self, pts, fill):
        self.d.polygon([(x * SS, y * SS) for x, y in pts], fill=fill)

    def line(self, pts, fill, width=1):
        self.d.line([(x * SS, y * SS) for x, y in pts], fill=fill, width=int(width * SS), joint="curve")

    def gradient(self, draw_mask, box, top, bottom, horizontal=False):
        """Remplit une forme (dessinee sur un masque par draw_mask) d'un degrade doux."""
        mask = Image.new("L", self.img.size, 0)
        draw_mask(ImageDraw.Draw(mask))
        x0, y0, x1, y1 = [int(v * SS) for v in box]
        w, h = max(1, x1 - x0), max(1, y1 - y0)
        strip = Image.new("RGBA", (1, 256) if not horizontal else (256, 1))
        for i in range(256):
            c = mix(top, bottom, i / 255) + (255,)
            strip.putpixel((0, i) if not horizontal else (i, 0), c)
        grad = strip.resize((w, h), Image.BILINEAR)
        full = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        full.paste(grad, (x0, y0))
        self.img.paste(full, (0, 0), Image.composite(mask, Image.new("L", self.img.size, 0), full.split()[3]))

    def soft(self, draw, blur):
        """Ajoute une forme floutee (ombre, halo, nuage) dessinee par draw(ImageDraw) sur un calque a part."""
        extra = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        draw(ImageDraw.Draw(extra))
        self.img.alpha_composite(extra.filter(ImageFilter.GaussianBlur(blur * SS)))

    def done(self):
        return self.img.resize(self.size, Image.BOX)

    def clip(self, draw_mask, draw):
        """Dessine draw(Layer) seulement a l'interieur de la forme draw_mask (rayures d'un pyjama...)."""
        extra = Layer(size=self.size)
        draw(extra)
        mask = Image.new("L", self.img.size, 0)
        draw_mask(ImageDraw.Draw(mask))
        alpha = Image.composite(extra.img.split()[3], Image.new("L", self.img.size, 0), mask)
        extra.img.putalpha(alpha)
        self.img.alpha_composite(extra.img)


def S(*v):
    return [x * SS for x in v]


def save(img, scene, name):
    path = os.path.join(ROOT, scene, name + ".png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


# --- Chambre du reveur (plans 01, 02, 03, 06) ------------------------------------------------

WIN = (380, 54, 556, 196)  # fenetre : x0, y0, x1, y1
WOOD, WOOD_LIGHT, WOOD_DARK = (112, 78, 56), (146, 104, 74), (72, 48, 36)


def bedroom_sky(rng):
    """Ciel nocturne vu par la fenetre : degrade doux, etoiles, lune et son halo."""
    L = Layer()
    L.gradient(lambda m: m.rectangle(S(0, 0, W, H), fill=255), (0, 0, W, H), (12, 14, 42), (58, 58, 120))
    for _ in range(150):
        x, y, r = rng.uniform(0, W), rng.uniform(0, H), rng.choice([0.5, 0.5, 0.8, 1.1])
        L.ellipse((x - r, y - r, x + r, y + r), rng.choice([(226, 230, 255), (255, 240, 205), (190, 200, 255)]))
    cx, cy, r = 500, 100, 24
    L.soft(lambda d: d.ellipse(S(cx - r * 2.2, cy - r * 2.2, cx + r * 2.2, cy + r * 2.2), fill=(150, 156, 230, 90)), 14)
    # la lune sur un calque a part, decoupe en disque : l'ombre du croissant ne deborde pas
    moon = Layer()
    moon.ellipse((cx - r, cy - r, cx + r, cy + r), (250, 244, 214))
    moon.soft(lambda d: d.ellipse(S(cx - r + 12, cy - r + 6, cx + r + 16, cy + r + 10), fill=(186, 178, 160, 255)), 3)
    moon.ellipse((cx - 9, cy + 2, cx - 1, cy + 9), (228, 220, 192))  # crateres
    moon.ellipse((cx + 4, cy - 12, cx + 10, cy - 6), (232, 224, 198))
    disc = Image.new("L", moon.img.size, 0)
    ImageDraw.Draw(disc).ellipse(S(cx - r, cy - r, cx + r, cy + r), fill=255)
    moon.img.putalpha(disc)
    L.img.alpha_composite(moon.img)
    return L.done()


def bedroom_clouds(rng):
    L = Layer()
    for _ in range(8):
        x, y, w = rng.uniform(0, W), rng.uniform(40, 210), rng.uniform(50, 100)
        def draw(d, x=x, y=y, w=w):
            for i in range(4):
                d.ellipse(S(x + i * w / 4, y - (i % 2) * 7, x + i * w / 4 + w / 2, y + 16 - (i % 2) * 7), fill=(72, 74, 132, 230))
            d.rounded_rectangle(S(x + 4, y + 4, x + w + w / 4, y + 16), radius=6 * SS, fill=(60, 62, 118, 230))
        L.soft(draw, 1.2)
    return L.done()


def bedroom_room(rng):
    """Mur, fenetre (vitre transparente), rideaux, porte, plancher, tapis, table de nuit, etagere."""
    L = Layer()
    # mur bleu nuit, plus sombre en haut, motif de petites etoiles
    L.gradient(lambda m: m.rectangle(S(0, 0, W, 280), fill=255), (0, 0, W, 280), (26, 26, 56), (46, 46, 90))
    for y in range(12, 270, 26):
        for x in range((y // 26 % 2) * 16, W, 32):
            L.poly([(x, y - 3), (x + 1, y - 1), (x + 3, y), (x + 1, y + 1), (x, y + 3), (x - 1, y + 1), (x - 3, y), (x - 1, y - 1)], (60, 60, 108))
    # plancher : lames en degrade, joints fins
    L.gradient(lambda m: m.rectangle(S(0, 280, W, H), fill=255), (0, 280, W, H), (66, 46, 42), (34, 24, 26))
    for i, y in enumerate(range(292, H, 13)):
        L.line([(0, y), (W, y)], (30, 20, 22), 0.8)
        for x in range((i * 53) % 110, W, 110):
            L.line([(x, y - 12), (x, y)], (30, 20, 22), 0.8)
    L.rect((0, 276, W, 284), (22, 18, 32))  # plinthe
    L.rect((0, 276, W, 278), (40, 34, 56))
    # tapis ovale
    L.soft(lambda d: d.ellipse(S(150, 306, 470, 360), fill=(10, 6, 16, 160)), 4)
    L.ellipse((150, 300, 470, 352), (74, 48, 102))
    L.ellipse((164, 306, 456, 346), (96, 66, 130))
    L.ellipse((194, 314, 426, 338), (78, 52, 108))
    # fenetre : cadre arrondi, vitre transparente, croisillon, rebord
    x0, y0, x1, y1 = WIN
    L.rect((x0 - 9, y0 - 9, x1 + 9, y1 + 9), WOOD_DARK, r=6)
    L.rect((x0 - 6, y0 - 6, x1 + 6, y1 + 6), WOOD_LIGHT, r=5)
    L.d.rounded_rectangle(S(x0, y0, x1, y1), radius=3 * SS, fill=(0, 0, 0, 0))
    mx, my = (x0 + x1) / 2, (y0 + y1) / 2
    L.rect((mx - 3, y0, mx + 3, y1), WOOD)
    L.rect((x0, my - 3, x1, my + 3), WOOD)
    L.rect((x0 - 16, y1 + 8, x1 + 16, y1 + 15), WOOD_LIGHT, r=3)
    L.rect((x0 - 16, y1 + 13, x1 + 16, y1 + 15), WOOD_DARK)
    # rideaux : plis arrondis, bas qui s'evase
    for cx0, cx1, flare in ((x0 - 50, x0 + 8, -8), (x1 - 8, x1 + 50, 8)):
        pts = [(cx0, y0 - 22), (cx1, y0 - 22), (cx1 + max(0, flare), y1 + 44), (cx0 + min(0, flare), y1 + 44)]
        L.gradient(lambda m, pts=pts: m.polygon([(a * SS, b * SS) for a, b in pts], fill=255),
                   (cx0 - 10, y0 - 22, cx1 + 10, y1 + 44), (110, 82, 170), (80, 58, 136))
        for k in range(1, 5):
            fx = cx0 + (cx1 - cx0) * k / 5
            L.line(bezier([(fx, y0 - 20), (fx + flare * 0.3, (y0 + y1) / 2), (fx + flare * 0.8, y1 + 42)]), (72, 52, 122), 1.6)
    L.rect((x0 - 64, y0 - 27, x1 + 64, y0 - 22), (184, 152, 104), r=2)  # tringle
    L.ellipse((x0 - 70, y0 - 30, x0 - 60, y0 - 19), (200, 168, 116))
    L.ellipse((x1 + 60, y0 - 30, x1 + 70, y0 - 19), (200, 168, 116))
    # encadrement de porte ; derriere, le couloir eclaire (visible quand la porte s'ouvre)
    L.rect((22, 94, 120, 280), (50, 36, 42), r=4)
    L.gradient(lambda m: m.rectangle(S(28, 100, 114, 280), fill=255), (28, 100, 114, 280), (255, 220, 160), (196, 140, 96))
    L.rect((60, 100, 114, 280), (230, 186, 132))  # mur du fond du couloir
    L.rect((28, 252, 114, 280), (170, 116, 80))  # sol du couloir
    # etagere et jouets
    L.soft(lambda d: d.rectangle(S(170, 110, 292, 116), fill=(8, 6, 16, 140)), 2)
    L.rect((166, 104, 292, 111), WOOD_LIGHT, r=2)
    L.rect((176, 82, 194, 104), (200, 86, 94), r=2)
    L.rect((196, 87, 210, 104), (92, 142, 204), r=2)
    L.rect((212, 78, 225, 104), (238, 200, 112), r=2)
    L.ellipse((238, 80, 268, 106), (176, 124, 82))  # ourson
    L.ellipse((236, 72, 250, 86), (176, 124, 82))
    L.ellipse((256, 72, 270, 86), (176, 124, 82))
    L.ellipse((247, 88, 259, 98), (214, 170, 124))
    L.ellipse((245, 84, 248, 87), (30, 20, 20))
    L.ellipse((258, 84, 261, 87), (30, 20, 20))
    # table de nuit arrondie, prise murale
    L.soft(lambda d: d.ellipse(S(470, 274, 552, 288), fill=(8, 6, 16, 170)), 3)
    L.rect((474, 218, 548, 282), WOOD_DARK, r=6)
    L.rect((478, 222, 544, 240), WOOD_LIGHT, r=4)
    L.rect((478, 245, 544, 278), WOOD, r=4)
    L.rect((503, 229, 519, 233), (214, 182, 112), r=2)
    L.rect((503, 258, 519, 262), (214, 182, 112), r=2)
    L.rect((482, 194, 536, 220), (44, 34, 46), r=6)  # reveil
    L.rect((487, 199, 531, 215), (14, 9, 15), r=3)
    L.rect((560, 236, 574, 254), (218, 212, 228), r=3)  # prise
    return L.done()


def bedroom_door():
    """Porte de la chambre (calque a part : elle s'ouvre en pivotant), rai de lumiere dessous."""
    L = Layer()
    L.rect((28, 100, 114, 280), (78, 58, 62), r=3)
    for top, bottom in ((110, 180), (190, 268)):
        L.rect((40, top, 102, bottom), (66, 48, 54), r=3)
        L.rect((42, top + 2, 100, bottom - 2), (84, 62, 66), r=2)
    L.ellipse((94, 184, 104, 194), (214, 182, 112))
    L.soft(lambda d: d.rectangle(S(26, 276, 116, 282), fill=(255, 214, 140, 220)), 1.5)
    return L.done()


def bedroom_dreamer_turned():
    """Le reveur tourne vers le mur : on ne voit que l'arriere de sa tete et son bonnet."""
    L = Layer()
    cx, cy, r = 152, 216, 17
    tip = bezier([(cx - 12, cy - 14), (cx - 32, cy - 26), (cx - 44, cy - 14), (cx - 42, cy + 4)], 20)
    back = bezier([(cx - 42, cy + 4), (cx - 34, cy - 8), (cx - 22, cy - 12), (cx - 4, cy - 8)], 20)
    L.poly(tip + back, (96, 70, 190))
    L.ellipse((cx - 49, cy, cx - 35, cy + 14), (244, 244, 255))
    L.ellipse((cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1), (60, 34, 30))
    L.ellipse((cx - r, cy - r, cx + r, cy + r), (98, 62, 44))  # cheveux
    for k in range(-2, 3):
        L.line(bezier([(cx + k * 5, cy - 12), (cx + k * 6 + 2, cy), (cx + k * 5, cy + 12)]), (80, 50, 36), 1)
    band = bezier([(cx - r - 2, cy - 2), (cx - r, cy - r - 8), (cx + r, cy - r - 8), (cx + r + 2, cy - 2)], 24)
    inner = bezier([(cx + r - 2, cy - 6), (cx + r - 4, cy - r + 2), (cx - r + 4, cy - r + 2), (cx - r + 2, cy - 6)], 24)
    L.poly(band + inner, (110, 82, 204))
    L.line(bezier([(cx - r + 3, cy - 7), (cx, cy - r - 2), (cx + r - 3, cy - 7)]), (238, 236, 255), 2.2)
    return L.done()


def speech_bubbles():
    """Bulles de paroles qui entrent par la porte, chacune en version nette et floue."""
    from PIL import ImageFont
    font = ImageFont.truetype(os.path.join(os.path.dirname(__file__), "..", "assets", "fonts", "Nunito.ttf"), 13 * SS)
    out = {}
    for i, text in enumerate(["...pas assez...", "plus tard", "pourquoi tu..."]):
        box = ImageDraw.Draw(Image.new("L", (1, 1))).textbbox((0, 0), text, font=font)
        w, h = box[2] - box[0] + 18 * SS, box[3] - box[1] + 12 * SS
        img = Image.new("RGBA", (w + 8 * SS, h + 10 * SS), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle((0, 0, w, h), radius=h // 2, fill=(236, 230, 250, 235))
        d.polygon([(w * 0.25, h - 2), (w * 0.25 + 10 * SS, h - 2), (w * 0.2, h + 8 * SS)], fill=(236, 230, 250, 235))
        d.text((9 * SS - box[0], 6 * SS - box[1]), text, font=font, fill=(52, 44, 80, 255))
        small = img.resize((img.width // SS, img.height // SS), Image.BOX)
        out["bubble%d" % i] = small
    return out


def bedroom_clock_digits():
    """3:12 en segments arrondis (calque a part pour la lueur), et les deux points clignotants."""
    L = Layer()
    red = (255, 84, 90)
    segs = {"3": "abgcd", "1": "bc", "2": "abged"}

    def digit(x, ch):
        s = segs[ch]
        if "a" in s: L.line([(x, 202), (x + 5, 202)], red, 1.4)
        if "b" in s: L.line([(x + 5, 202), (x + 5, 206.5)], red, 1.4)
        if "c" in s: L.line([(x + 5, 206.5), (x + 5, 211)], red, 1.4)
        if "d" in s: L.line([(x, 211), (x + 5, 211)], red, 1.4)
        if "e" in s: L.line([(x, 206.5), (x, 211)], red, 1.4)
        if "g" in s: L.line([(x, 206.5), (x + 5, 206.5)], red, 1.4)
    digit(492, "3")
    digit(508, "1")
    digit(518, "2")
    return L.done()


def bedroom_colon():
    L = Layer()
    L.ellipse((501, 203, 503.5, 205.5), (255, 84, 90))
    L.ellipse((501, 208, 503.5, 210.5), (255, 84, 90))
    return L.done()


def bedroom_bed():
    """Lit en bois arrondi : montants a boules, tete de lit, matelas, oreiller moelleux."""
    L = Layer()
    L.soft(lambda d: d.ellipse(S(100, 270, 470, 292), fill=(6, 4, 12, 180)), 4)  # ombre au sol
    # tete de lit
    L.rect((94, 176, 114, 284), WOOD_DARK, r=4)
    L.rect((98, 180, 110, 284), WOOD, r=3)
    L.ellipse((90, 160, 118, 186), WOOD_DARK)
    L.ellipse((93, 162, 115, 184), WOOD_LIGHT)
    L.ellipse((97, 166, 105, 173), (186, 140, 100))
    L.rect((110, 192, 146, 250), WOOD_DARK, r=8)
    L.rect((113, 195, 143, 247), WOOD, r=6)
    # cadre et pied de lit
    L.rect((110, 246, 460, 270), WOOD_DARK, r=5)
    L.rect((112, 248, 458, 258), WOOD_LIGHT, r=4)
    L.rect((438, 214, 458, 284), WOOD_DARK, r=4)
    L.rect((442, 218, 454, 284), WOOD, r=3)
    L.ellipse((434, 200, 462, 226), WOOD_DARK)
    L.ellipse((437, 202, 459, 224), WOOD_LIGHT)
    L.ellipse((441, 206, 449, 213), (186, 140, 100))
    # matelas et oreiller
    L.rect((116, 228, 446, 252), (204, 204, 222), r=8)
    L.rect((116, 228, 446, 238), (224, 224, 238), r=8)
    L.soft(lambda d: d.rounded_rectangle(S(122, 222, 202, 242), radius=12 * SS, fill=(150, 146, 180, 200)), 2.5)
    L.rect((120, 200, 200, 238), (232, 230, 244), r=14)
    L.rect((124, 203, 194, 226), (248, 246, 255), r=12)
    return L.done()


def bedroom_quilt():
    """Couverture moelleuse, matelassage doux, bord arrondi (calque a part : elle respire)."""
    L = Layer()
    # remontee jusqu'au menton a gauche, bord arrondi a droite
    outline = ([(130, 258)] + bezier([(130, 250), (138, 238), (164, 234), (190, 214)], 16)
               + bezier([(190, 214), (300, 210), (420, 211), (440, 212)], 16)
               + bezier([(440, 212), (452, 214), (452, 226), (452, 258)], 10))
    shape = lambda m: m.polygon([(x * SS, y * SS) for x, y in outline], fill=255)
    L.gradient(shape, (134, 210, 452, 258), (124, 108, 200), (68, 56, 136))
    for x in range(200, 440, 22):  # coutures en losange, en courbes douces
        L.line(bezier([(x, 214), (x + 6, 232), (x + 11, 250)]), (104, 90, 178), 0.7)
        L.line(bezier([(x + 11, 214), (x + 5, 232), (x, 250)]), (104, 90, 178), 0.7)
    L.line(bezier([(136, 246), (164, 236), (190, 217)]) + bezier([(190, 217), (300, 212), (440, 215)]), (156, 142, 226), 1.6)  # reflet du bord replie
    L.rect((134, 250, 452, 258), (58, 46, 118), r=4)
    return L.done()


def bedroom_dreamer():
    """Le reveur, tete sur l'oreiller, yeux grands ouverts ; bonnet de nuit pose sur le haut de la
    tete, la pointe qui retombe vers l'oreiller avec le pompon."""
    L = Layer()
    cx, cy, r = 152, 216, 17
    # bonnet : la pointe d'abord (derriere la tete), en courbe vers la gauche, pompon sur l'oreiller
    tip = bezier([(cx - 12, cy - 14), (cx - 32, cy - 26), (cx - 44, cy - 14), (cx - 42, cy + 4)], 20)
    back = bezier([(cx - 42, cy + 4), (cx - 34, cy - 8), (cx - 22, cy - 12), (cx - 4, cy - 8)], 20)
    L.poly(tip + back, (96, 70, 190))
    L.line(bezier([(cx - 14, cy - 12), (cx - 30, cy - 20), (cx - 38, cy - 10)]), (126, 100, 220), 1.4)
    L.ellipse((cx - 49, cy, cx - 35, cy + 14), (244, 244, 255))  # pompon pose sur l'oreiller
    L.ellipse((cx - 46, cy + 2, cx - 40, cy + 7), (255, 255, 255))
    # visage
    L.ellipse((cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1), (70, 40, 44))
    L.ellipse((cx - r, cy - r, cx + r, cy + r), (246, 204, 170))
    L.ellipse((cx - 13, cy + 3, cx - 5, cy + 9), (250, 168, 160))  # joues
    L.ellipse((cx + 5, cy + 3, cx + 13, cy + 9), (250, 168, 160))
    # revers du bonnet : bande qui couvre le haut de la tete
    band = bezier([(cx - r - 2, cy - 2), (cx - r, cy - r - 8), (cx + r, cy - r - 8), (cx + r + 2, cy - 2)], 24)
    inner = bezier([(cx + r - 2, cy - 6), (cx + r - 4, cy - r + 2), (cx - r + 4, cy - r + 2), (cx - r + 2, cy - 6)], 24)
    L.poly(band + inner, (110, 82, 204))
    L.line(bezier([(cx - r + 3, cy - 7), (cx, cy - r - 2), (cx + r - 3, cy - 7)]), (238, 236, 255), 2.2)  # bord blanc
    # yeux grands ouverts, petite bouche
    for ex in (cx - 7, cx + 7):
        L.ellipse((ex - 3, cy - 3, ex + 3, cy + 3), (255, 255, 255))
        L.ellipse((ex - 1.6, cy - 1.2, ex + 1.6, cy + 2.4), (40, 30, 60))
        L.ellipse((ex - 0.6, cy - 1, ex + 0.4, cy), (255, 255, 255))
    L.line(bezier([(cx - 3, cy + 9), (cx, cy + 10.5), (cx + 3, cy + 9)]), (190, 110, 100), 1)
    return L.done()


def bedroom_veilleuse():
    """Veilleuse en etoile aux branches arrondies, branchee a la prise."""
    L = Layer()
    cx, cy = 567, 240
    pts = []
    for i in range(40):
        a = -math.pi / 2 + i * math.pi / 20
        rr = 6.5 + 3.2 * math.cos(5 * (a + math.pi / 2))  # cinq branches douces
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    L.poly(pts, (255, 206, 104))
    inner = [(cx + (p[0] - cx) * 0.6, cy + (p[1] - cy) * 0.6 - 0.6) for p in pts]
    L.poly(inner, (255, 236, 170))
    L.line(bezier([(565, 239.5), (565.6, 240.4), (566.2, 239.5)]), (180, 120, 70), 0.6)
    L.line(bezier([(568, 239.5), (568.6, 240.4), (569.2, 239.5)]), (180, 120, 70), 0.6)
    return L.done()


def bedroom_foreground():
    """Premier plan sombre (floute a l'animation) : bord de rideau et pied de lit."""
    L = Layer()
    L.poly(bezier([(0, 0), (30, 120), (14, 250), (34, H)], 30) + [(0, H)], (10, 8, 18))
    L.ellipse((-26, 296, 64, 386), (10, 8, 18))
    L.poly([(604, H)] + bezier([(604, H), (596, 300), (608, 262), (640, 248)], 20) + [(W, H)], (12, 10, 20))
    L.ellipse((588, 232, 646, 274), (12, 10, 20))
    return L.done()


def chambre():
    rng = random.Random(11)
    for name, img in (("sky", bedroom_sky(rng)), ("clouds", bedroom_clouds(rng)), ("room", bedroom_room(rng)),
                      ("clock", bedroom_clock_digits()), ("colon", bedroom_colon()), ("bed", bedroom_bed()),
                      ("quilt", bedroom_quilt()), ("dreamer", bedroom_dreamer()), ("veilleuse", bedroom_veilleuse()),
                      ("foreground", bedroom_foreground()), ("door", bedroom_door()),
                      ("dreamer_turned", bedroom_dreamer_turned())):
        save(img, "chambre", name)
    for name, img in speech_bubbles().items():
        save(img, "chambre", name)


# --- Le reveur en HD (debout) et les soucis (plan 04, et reutilises ensuite) ------------------

PYJAMA_BLUE, PYJAMA_WHITE = (78, 112, 206), (236, 240, 255)
SKIN, SKIN_EDGE, CHEEK = (246, 204, 170), (70, 40, 44), (250, 168, 160)
CAP, CAP_LIGHT = (104, 76, 196), (126, 100, 220)


def draw_dreamer(L, x, y, eyes="open", arms="down"):
    """Le reveur debout, pieds en (x, y) ; environ 96 px de haut. eyes : open, closed, worried."""
    # jambes et chaussons
    for lx in (x - 10, x + 1):
        shape = lambda m, lx=lx: m.rounded_rectangle(S(lx, y - 28, lx + 9, y - 3), radius=4 * SS, fill=255)
        L.rect((lx, y - 28, lx + 9, y - 3), PYJAMA_WHITE, r=4)
        L.clip(shape, lambda e, lx=lx: [e.rect((lx, yy, lx + 9, yy + 3), PYJAMA_BLUE) for yy in range(y - 28, y - 3, 6)])
        L.ellipse((lx - 2, y - 7, lx + 11, y + 1), (226, 120, 130))
    # corps a rayures
    body = lambda m: m.rounded_rectangle(S(x - 18, y - 62, x + 18, y - 24), radius=10 * SS, fill=255)
    L.rect((x - 19, y - 63, x + 19, y - 23), (40, 50, 96), r=11)
    L.rect((x - 18, y - 62, x + 18, y - 24), PYJAMA_WHITE, r=10)
    L.clip(body, lambda e: [e.rect((x - 20, yy, x + 20, yy + 4), PYJAMA_BLUE) for yy in range(y - 60, y - 24, 8)])
    L.ellipse((x - 3, y - 54, x + 2, y - 49), (250, 230, 120))  # bouton
    # bras
    if arms == "down":
        for sx in (-1, 1):
            L.line(bezier([(x + sx * 17, y - 56), (x + sx * 24, y - 44), (x + sx * 22, y - 32)]), (40, 50, 96), 10)
            L.line(bezier([(x + sx * 17, y - 56), (x + sx * 24, y - 44), (x + sx * 22, y - 32)]), PYJAMA_WHITE, 8)
            L.ellipse((x + sx * 22 - 5, y - 36, x + sx * 22 + 5, y - 26), SKIN)
    else:  # bras serres contre soi (recroqueville)
        L.line(bezier([(x - 16, y - 54), (x - 6, y - 44), (x + 8, y - 46)]), PYJAMA_WHITE, 8)
        L.line(bezier([(x + 16, y - 54), (x + 6, y - 40), (x - 8, y - 42)]), PYJAMA_WHITE, 8)
        L.ellipse((x + 4, y - 51, x + 13, y - 42), SKIN)
        L.ellipse((x - 13, y - 47, x - 4, y - 38), SKIN)
    # tete
    hx, hy, r = x, y - 80, 18
    L.ellipse((hx - r - 1, hy - r - 1, hx + r + 1, hy + r + 1), SKIN_EDGE)
    L.ellipse((hx - r, hy - r, hx + r, hy + r), SKIN)
    L.rect((hx - r + 4, hy - r + 2, hx + r - 4, hy - r + 8), (98, 62, 44), r=3)  # frange
    L.ellipse((hx - 14, hy + 4, hx - 6, hy + 10), CHEEK)
    L.ellipse((hx + 6, hy + 4, hx + 14, hy + 10), CHEEK)
    for ex in (hx - 7, hx + 7):
        if eyes == "closed":
            L.line(bezier([(ex - 3, hy), (ex, hy + 2), (ex + 3, hy)]), (40, 30, 60), 1.2)
        else:
            L.ellipse((ex - 3, hy - 3, ex + 3, hy + 3), (255, 255, 255))
            L.ellipse((ex - 1.6, hy - 1.2, ex + 1.6, hy + 2.4), (40, 30, 60))
            L.ellipse((ex - 0.6, hy - 1, ex + 0.4, hy), (255, 255, 255))
    if eyes == "worried":
        L.line([(hx - 11, hy - 7), (hx - 4, hy - 5)], (90, 56, 40), 1.2)
        L.line([(hx + 11, hy - 7), (hx + 4, hy - 5)], (90, 56, 40), 1.2)
        L.line(bezier([(hx - 3, hy + 10), (hx, hy + 8.5), (hx + 3, hy + 10)]), (190, 110, 100), 1)
    else:
        L.line(bezier([(hx - 3, hy + 9), (hx, hy + 10.5), (hx + 3, hy + 9)]), (190, 110, 100), 1)
    # bonnet : revers sur le haut de la tete, pointe qui retombe sur le cote, pompon
    cone = bezier([(hx - 14, hy - 16), (hx - 4, hy - 46), (hx + 26, hy - 44), (hx + 32, hy - 18)], 24)
    cone_back = bezier([(hx + 32, hy - 18), (hx + 22, hy - 30), (hx + 6, hy - 30), (hx + 14, hy - 16)], 16)
    L.poly(cone + cone_back, CAP)
    L.line(bezier([(hx - 6, hy - 26), (hx + 4, hy - 40), (hx + 22, hy - 36)]), CAP_LIGHT, 1.6)
    L.ellipse((hx + 25, hy - 22, hx + 39, hy - 8), (244, 244, 255))
    band = bezier([(hx - r - 2, hy - 4), (hx - r, hy - r - 9), (hx + r, hy - r - 9), (hx + r + 2, hy - 4)], 24)
    inner = bezier([(hx + r - 2, hy - 8), (hx + r - 4, hy - r + 1), (hx - r + 4, hy - r + 1), (hx - r + 2, hy - 8)], 24)
    L.poly(band + inner, (110, 82, 204))
    L.line(bezier([(hx - r + 3, hy - 9), (hx, hy - r - 3), (hx + r - 3, hy - 9)]), (238, 236, 255), 2.2)


def dreamer_sprite(eyes, arms="down"):
    L = Layer(size=(100, 140))
    draw_dreamer(L, 50, 132, eyes, arms)
    return L.done()


WORRY_SIZE = (60, 60)


def worry(draw):
    L = Layer(size=WORRY_SIZE)
    draw(L)
    return L.done()


def w_reveil(L):  # le reveil grincheux (lundi)
    L.ellipse((12, 2, 26, 16), (236, 186, 90))
    L.ellipse((34, 2, 48, 16), (236, 186, 90))
    L.ellipse((8, 8, 52, 52), (196, 64, 70))
    L.ellipse((13, 13, 47, 47), (252, 246, 232))
    L.line([(30, 30), (30, 19)], (60, 40, 50), 2)
    L.line([(30, 30), (38, 33)], (60, 40, 50), 2)
    L.line([(19, 22), (25, 25)], (60, 40, 50), 1.6)  # sourcils fronces
    L.line([(41, 22), (35, 25)], (60, 40, 50), 1.6)
    L.line([(14, 50), (10, 57)], (120, 40, 50), 3)
    L.line([(46, 50), (50, 57)], (120, 40, 50), 3)


def w_devoirs(L):  # la pile de devoirs (mardi)
    for i, (dx, rot) in enumerate(((0, 0), (3, 1), (-2, 2))):
        y0 = 44 - i * 11
        L.poly([(10 + dx, y0), (50 + dx, y0 - rot * 2), (50 + dx, y0 + 9 - rot * 2), (10 + dx, y0 + 9)], (240, 236, 222))
        L.line([(14 + dx, y0 + 4), (44 + dx, y0 + 4 - rot * 2)], (150, 160, 200), 1)
    L.line(bezier([(16, 14), (26, 4), (40, 10)]), (220, 50, 60), 2.4)  # trait rouge du correcteur
    L.ellipse((38, 8, 50, 20), (220, 50, 60))
    L.ellipse((41, 11, 47, 17), (240, 236, 222))


def w_miroir(L):  # le miroir brise (mercredi)
    L.ellipse((12, 4, 48, 52), (214, 170, 80))
    L.ellipse((16, 8, 44, 48), (150, 190, 230))
    L.line([(30, 10), (27, 24), (34, 30), (28, 46)], (240, 248, 255), 1.4)
    L.line([(27, 24), (18, 28)], (240, 248, 255), 1.2)
    L.line([(34, 30), (42, 26)], (240, 248, 255), 1.2)
    L.rect((26, 50, 34, 58), (190, 146, 64), r=2)


def w_cocotte(L):  # la cocotte-minute (jeudi)
    L.soft(lambda d: [d.ellipse(S(20 + k * 6, 2 - k * 1, 32 + k * 6, 14 - k * 1), fill=(230, 236, 246, 200)) for k in range(3)], 1.2)
    L.rect((26, 14, 34, 22), (60, 60, 70), r=2)
    L.rect((8, 20, 52, 26), (110, 112, 124), r=3)
    L.rect((10, 24, 50, 54), (140, 142, 156), r=8)
    L.rect((10, 24, 50, 32), (166, 168, 182), r=6)
    L.rect((2, 30, 10, 36), (60, 60, 70), r=2)
    L.rect((50, 30, 58, 36), (60, 60, 70), r=2)
    L.ellipse((26, 38, 34, 46), (230, 80, 70))


def w_fardeau(L):  # le fardeau (vendredi)
    L.line(bezier([(18, 18), (30, 2), (42, 18)]), (60, 60, 72), 4)
    L.poly(bezier([(12, 56), (6, 30), (16, 18), (30, 16)], 16) + bezier([(30, 16), (44, 18), (54, 30), (48, 56)], 16), (96, 98, 116))
    L.poly(bezier([(16, 52), (12, 34), (20, 24), (30, 22)], 12) + [(30, 52)], (116, 118, 138))
    L.rect((20, 34, 40, 44), (70, 72, 88), r=3)


def w_chaise(L):  # la chaise vide (samedi)
    L.rect((14, 4, 20, 54), (150, 112, 78), r=2)
    L.rect((40, 4, 46, 54), (150, 112, 78), r=2)
    L.rect((14, 8, 46, 14), (176, 134, 94), r=2)
    L.rect((14, 18, 46, 22), (176, 134, 94), r=2)
    L.rect((10, 32, 50, 38), (186, 144, 102), r=2)
    L.rect((12, 38, 17, 58), (150, 112, 78), r=2)
    L.rect((43, 38, 48, 58), (150, 112, 78), r=2)


def w_compte(L):  # le compte a rebours (dimanche)
    L.rect((6, 12, 54, 48), (44, 36, 60), r=8)
    L.rect((10, 16, 50, 44), (14, 10, 22), r=5)
    for x0, ch in ((14, "0"), (34, "7")):  # 0:07 en segments
        if ch == "0":
            L.rect((x0, 21, x0 + 10, 39), (255, 84, 90), r=3)
            L.rect((x0 + 3, 24, x0 + 7, 36), (14, 10, 22), r=1)
        else:
            L.line([(x0, 22), (x0 + 10, 22), (x0 + 4, 39)], (255, 84, 90), 3)
    L.ellipse((28, 25, 31, 28), (255, 84, 90))
    L.ellipse((28, 32, 31, 35), (255, 84, 90))
    L.line([(20, 12), (24, 4)], (200, 200, 210), 2)
    L.line([(40, 12), (36, 4)], (200, 200, 210), 2)


WORRIES = {"reveil": w_reveil, "devoirs": w_devoirs, "miroir": w_miroir, "cocotte": w_cocotte,
           "fardeau": w_fardeau, "chaise": w_chaise, "compte": w_compte}


def void_background(rng):
    """Le noir du plan 04 : un halo violet autour du reveur, des poussieres d'etoiles."""
    L = Layer(fill=(6, 5, 16, 255))
    L.soft(lambda d: d.ellipse(S(140, 40, 500, 340), fill=(46, 38, 104, 255)), 60)
    L.soft(lambda d: d.ellipse(S(240, 110, 400, 290), fill=(70, 60, 140, 200)), 30)
    for _ in range(120):
        x, y, r = rng.uniform(0, W), rng.uniform(0, H), rng.choice([0.5, 0.6, 0.9])
        L.ellipse((x - r, y - r, x + r, y + r), rng.choice([(140, 130, 210), (200, 190, 255), (110, 100, 170)]))
    return L.done()


def soucis():
    rng = random.Random(4)
    save(void_background(rng), "soucis", "background")
    save(dreamer_sprite("worried", "hug"), "soucis", "dreamer")
    for name, draw in WORRIES.items():
        save(worry(draw), "soucis", "worry_" + name)


# --- L'horizon et les sept tours (plans 05, 06, 07) -------------------------------------------

TOWER_SIZE = (90, 200)


def draw_tower(L, day, lit=True, ox=0, oy=0, k=1.0):
    """Tour d'une nuit, base au centre-bas (45, 196) de son cadre 90x200 ; k = echelle."""
    def P(x, y):
        return (ox + 45 + (x - 45) * k, oy + 196 + (y - 196) * k)

    def R(x0, y0, x1, y1):
        a, b = P(x0, y0), P(x1, y1)
        return (a[0], a[1], b[0], b[1])
    glow = (255, 214, 140) if lit else (60, 56, 80)
    if day == 0:  # lundi : tour douce, toit en dome d'oreiller
        L.rect(R(22, 70, 68, 196), (150, 136, 214), r=10 * k)
        L.rect(R(22, 70, 36, 196), (172, 160, 230), r=8 * k)
        L.ellipse(R(14, 36, 76, 84), (196, 186, 240))
        L.ellipse(R(20, 40, 50, 62), (222, 216, 250))
        for wy in (100, 140):
            L.ellipse(R(38, wy, 52, wy + 14), glow)
    elif day == 1:  # mardi : laiton et horloge
        L.rect(R(24, 60, 66, 196), (176, 130, 70), r=4 * k)
        L.rect(R(24, 60, 34, 196), (200, 154, 90), r=3 * k)
        L.poly([P(18, 62), P(45, 22), P(72, 62)], (140, 96, 50))
        L.ellipse(R(31, 66, 59, 94), (240, 230, 206))
        L.line([P(45, 80), P(45, 70)], (60, 40, 30), 1.4 * k)
        L.line([P(45, 80), P(52, 82)], (60, 40, 30), 1.4 * k)
        for wy in (110, 146):
            L.rect(R(38, wy, 52, wy + 18), glow, r=3 * k)
    elif day == 2:  # mercredi : verre et fleche, panneaux-miroirs
        L.poly([P(26, 196), P(30, 70), P(60, 70), P(64, 196)], (150, 186, 220))
        L.poly([P(26, 196), P(30, 70), P(40, 70), P(36, 196)], (200, 224, 244))
        L.poly([P(28, 72), P(45, 8), P(62, 72)], (176, 206, 236))
        for wy in (90, 120, 150):
            L.rect(R(40, wy, 50, wy + 16), glow if wy != 120 else (220, 236, 255), r=2 * k)
    elif day == 3:  # jeudi : usine grise, cheminee qui fume
        L.rect(R(18, 80, 72, 196), (118, 120, 132), r=3 * k)
        L.rect(R(18, 120, 72, 128), (226, 132, 48))
        L.rect(R(54, 30, 66, 82), (96, 98, 110), r=2 * k)
        L.soft(lambda d: [d.ellipse(S(*R(48 + j * 4, 6 - j * 6, 68 + j * 4, 24 - j * 6)), fill=(170, 170, 184, 160)) for j in range(3)], 2 * k)
        for wx in (26, 42, 58):
            L.rect(R(wx, 92, wx + 8, 108), glow, r=1)
            L.rect(R(wx, 140, wx + 8, 156), glow, r=1)
    elif day == 4:  # vendredi : pile de cartons qui penche
        for j, (w, dx) in enumerate(((50, 0), (46, 3), (42, 7), (38, 12), (32, 16))):
            y1 = 196 - j * 30
            L.rect(R(45 - w / 2 + dx, y1 - 30, 45 + w / 2 + dx, y1), (196, 152, 98), r=3 * k)
            L.rect(R(45 - 2 + dx, y1 - 30, 45 + 2 + dx, y1), (226, 196, 136))
        L.rect(R(54, 118, 62, 128), glow, r=1)
    elif day == 5:  # samedi : ivoire elegant, fenetres en arc eteintes
        L.rect(R(24, 58, 66, 196), (226, 220, 206), r=6 * k)
        L.rect(R(24, 58, 34, 196), (240, 236, 226), r=5 * k)
        L.ellipse(R(20, 30, 70, 76), (210, 204, 190))
        L.rect(R(43, 14, 47, 34), (190, 184, 170))
        for wy in (90, 130, 164):
            L.rect(R(37, wy, 53, wy + 22), (70, 76, 110), r=8 * k)
    else:  # dimanche : fleche noire acérée, une seule fenetre rouge
        L.poly([P(22, 196), P(30, 60), P(60, 60), P(68, 196)], (40, 22, 40))
        L.poly([P(26, 62), P(45, 0), P(64, 62)], (30, 14, 30))
        L.poly([P(38, 196), P(30, 60), P(36, 60), P(44, 196)], (60, 36, 58))
        L.ellipse(R(40, 100, 50, 114), (255, 70, 80) if lit else (90, 30, 40))


def tower_sprite(day, lit=True):
    L = Layer(size=TOWER_SIZE)
    draw_tower(L, day, lit)
    return L.done()


def horizon_sky():
    """Ciel du crepuscule (lundi, a gauche) a la nuit noire (dimanche, a droite)."""
    L = Layer()
    L.gradient(lambda m: m.rectangle(S(0, 0, W, H), fill=255), (0, 0, W, H), (64, 54, 128), (6, 5, 14), horizontal=True)
    L.soft(lambda d: d.ellipse(S(-120, 120, 260, 420), fill=(150, 110, 170, 120)), 50)  # derniere lueur
    rng = random.Random(9)
    for _ in range(90):
        x, y = rng.uniform(W * 0.35, W), rng.uniform(0, 230)
        r = rng.choice([0.5, 0.6, 0.9])
        L.ellipse((x - r, y - r, x + r, y + r), (200, 200, 240))
    return L.done()


def horizon_clouds(depth):
    """Mer de nuages : trois profondeurs, plus claire et plus floue au loin."""
    L = Layer()
    rng = random.Random(20 + depth)
    base_y = (250, 280, 312)[depth]
    color = ((70, 62, 120), (52, 46, 96), (34, 30, 66))[depth]
    def draw(d):
        x = -30
        while x < W + 30:
            w = rng.uniform(60, 110)
            d.ellipse(S(x, base_y - rng.uniform(10, 26), x + w, base_y + 30), fill=color + (255,))
            x += w * 0.6
        d.rectangle(S(-10, base_y + 10, W + 10, H + 10), fill=color + (255,))
    L.soft(draw, (2.0, 1.2, 0.6)[depth])
    return L.done()


def window_towers_sky():
    """Ciel de la fenetre au plan 06 : les sept tours, petites, sur l'horizon."""
    img = bedroom_sky(random.Random(11))
    L = Layer()
    L.soft(lambda d: d.ellipse(S(360, 176, 580, 214), fill=(36, 34, 72, 255)), 2)
    for day in range(7):
        draw_tower(L, day, True, ox=398 + day * 23 - 45, oy=184 - 196, k=0.2)
    img.alpha_composite(L.done())
    return img


def dreamer_sitting_back():
    """Le reveur assis au bord du lit, de dos, face a la fenetre."""
    L = Layer()
    x, y = 300, 236
    body = lambda m: m.rounded_rectangle(S(x - 20, y - 40, x + 20, y), radius=10 * SS, fill=255)
    L.rect((x - 21, y - 41, x + 21, y + 1), (40, 50, 96), r=11)
    L.rect((x - 20, y - 40, x + 20, y), PYJAMA_WHITE, r=10)
    L.clip(body, lambda e: [e.rect((x - 22, yy, x + 22, yy + 4), PYJAMA_BLUE) for yy in range(y - 38, y, 8)])
    hx, hy, r = x, y - 56, 18
    L.ellipse((hx - r - 1, hy - r - 1, hx + r + 1, hy + r + 1), (60, 34, 30))
    L.ellipse((hx - r, hy - r, hx + r, hy + r), (98, 62, 44))
    cone = bezier([(hx - 14, hy - 16), (hx - 4, hy - 46), (hx + 26, hy - 44), (hx + 32, hy - 18)], 24)
    cone_back = bezier([(hx + 32, hy - 18), (hx + 22, hy - 30), (hx + 6, hy - 30), (hx + 14, hy - 16)], 16)
    L.poly(cone + cone_back, CAP)
    L.ellipse((hx + 25, hy - 22, hx + 39, hy - 8), (244, 244, 255))
    band = bezier([(hx - r - 2, hy - 4), (hx - r, hy - r - 9), (hx + r, hy - r - 9), (hx + r + 2, hy - 4)], 24)
    inner = bezier([(hx + r - 2, hy - 8), (hx + r - 4, hy - r + 1), (hx - r + 4, hy - r + 1), (hx - r + 2, hy - 8)], 24)
    L.poly(band + inner, (110, 82, 204))
    L.line(bezier([(hx - r + 3, hy - 9), (hx, hy - r - 3), (hx + r - 3, hy - 9)]), (238, 236, 255), 2.2)
    return L.done()


HUB_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "hub")
HUB_SCALE = 0.7  # les tours du hub, un peu plus petites que dans la cinematique
DAY_IDS = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]


def hub_towers():
    """Les tours du hub reprennent celles de la cinematique (meme dessin, recadre)."""
    for day, night in enumerate(DAY_IDS):
        L = Layer(size=TOWER_SIZE)
        draw_tower(L, day, True, k=HUB_SCALE)  # redessinee a la bonne taille : reste nette
        img = L.done()
        img.crop(img.getbbox()).save(os.path.join(HUB_DIR, "tower_%s.png" % night))


def horizon():
    hub_towers()
    save(horizon_sky(), "horizon", "sky")
    for depth in range(3):
        save(horizon_clouds(depth), "horizon", "clouds%d" % depth)
    for day in range(7):
        save(tower_sprite(day), "horizon", "tower%d" % day)
    save(window_towers_sky(), "chambre", "sky_towers")
    save(dreamer_sitting_back(), "chambre", "dreamer_sitting")


# --- La plongee et le titre (plans 08, 09) ----------------------------------------------------

BAND = 200  # hauteur d'un lieu dans la bande de la chute


def fall_strip():
    """Les lieux des sept nuits empiles (lundi en haut) : on tombe a travers."""
    L = Layer(size=(W, BAND * 7))
    rng = random.Random(8)
    def band(i, top, bottom):
        y0 = i * BAND
        L.gradient(lambda m: m.rectangle(S(0, y0, W, y0 + BAND), fill=255), (0, y0, W, y0 + BAND), top, bottom)
        return y0
    y = band(0, (200, 190, 240), (150, 134, 214))  # lundi : coton et plumes
    for _ in range(14):
        x, yy = rng.uniform(0, W), y + rng.uniform(10, BAND - 10)
        L.soft(lambda d, x=x, yy=yy: d.ellipse(S(x - 40, yy - 14, x + 40, yy + 14), fill=(236, 230, 252, 200)), 4)
    for _ in range(10):
        x, yy = rng.uniform(0, W), y + rng.uniform(10, BAND - 10)
        L.line(bezier([(x, yy), (x + 8, yy - 6), (x + 18, yy - 8)]), (255, 255, 255), 2)
    y = band(1, (206, 160, 96), (140, 96, 50))  # mardi : rouages
    for _ in range(9):
        x, yy, r = rng.uniform(0, W), y + rng.uniform(20, BAND - 20), rng.uniform(14, 30)
        teeth = 10
        pts = []
        for k in range(teeth * 2):
            a = k * math.pi / teeth
            rr = r if k % 2 == 0 else r * 0.8
            pts.append((x + rr * math.cos(a), yy + rr * math.sin(a)))
        L.poly(pts, (230, 186, 110))
        L.ellipse((x - r * 0.3, yy - r * 0.3, x + r * 0.3, yy + r * 0.3), (120, 84, 40))
    y = band(2, (190, 214, 240), (150, 170, 214))  # mercredi : miroirs
    for gx in range(0, W, 50):
        for gy in range(0, BAND, 50):
            L.rect((gx + 2, y + gy + 2, gx + 48, y + gy + 48), (206, 226, 248) if (gx + gy) % 100 else (226, 210, 236), r=3)
            L.line([(gx + 8, y + gy + 40), (gx + 40, y + gy + 8)], (255, 255, 255), 1.4)
    y = band(3, (150, 152, 160), (110, 112, 122))  # jeudi : beton et bandes jaunes
    for k in range(-2, 20):
        x = k * 40
        L.poly([(x, y + 80), (x + 20, y + 80), (x + 40, y + 110), (x + 20, y + 110)], (236, 190, 40))
    L.rect((0, y + 150, W, y + 158), (60, 62, 70))
    y = band(4, (214, 176, 126), (170, 130, 84))  # vendredi : cartons
    for _ in range(12):
        x, yy, w, h = rng.uniform(-20, W), y + rng.uniform(10, BAND - 60), rng.uniform(50, 90), rng.uniform(40, 60)
        L.rect((x, yy, x + w, yy + h), (196, 152, 98), r=4)
        L.rect((x + w / 2 - 3, yy, x + w / 2 + 3, yy + h), (226, 196, 136))
    y = band(5, (226, 224, 236), (160, 166, 192))  # samedi : marbre et chaises vides
    for gx in range(0, W, 40):
        for gy in range(0, BAND, 40):
            if (gx // 40 + gy // 40) % 2:
                L.rect((gx, y + gy, gx + 40, y + gy + 40), (180, 186, 210))
    for _ in range(5):
        x, yy = rng.uniform(20, W - 40), y + rng.uniform(30, BAND - 60)
        L.rect((x, yy, x + 4, yy + 40), (150, 112, 78), r=1)
        L.rect((x, yy + 20, x + 24, yy + 24), (176, 134, 94), r=1)
        L.rect((x + 20, yy + 20, x + 24, yy + 40), (150, 112, 78), r=1)
    y = band(6, (250, 170, 110), (120, 70, 150))  # dimanche : crepuscule, arbres noirs
    for x in range(10, W, 70):
        h = rng.uniform(80, 150)
        L.line([(x, y + BAND), (x, y + BAND - h)], (30, 14, 34), 4)
        for k in range(3):
            by = y + BAND - h * (0.5 + k * 0.15)
            L.line(bezier([(x, by), (x + 14 * (1 if k % 2 else -1), by - 10), (x + 22 * (1 if k % 2 else -1), by - 22)]), (30, 14, 34), 2)
    for i in range(1, 7):  # transitions douces entre les lieux
        L.soft(lambda d, i=i: d.rectangle(S(0, i * BAND - 6, W, i * BAND + 6), fill=(20, 16, 40, 200)), 5)
    return L.done()


def dreamer_falling():
    """Le reveur qui tombe, endormi, bras leves (le bonnet flotte au-dessus)."""
    L = Layer(size=(100, 140))
    draw_dreamer(L, 50, 132, "closed", "down")
    img = L.done()
    return img.rotate(180, resample=Image.BICUBIC)  # la tete en bas : il plonge


def title_background():
    """Fond du titre : reve lavande, halo, nuages doux et etoiles."""
    L = Layer(fill=(30, 26, 70, 255))
    L.soft(lambda d: d.ellipse(S(80, -40, 560, 380), fill=(140, 124, 220, 255)), 80)
    L.soft(lambda d: d.ellipse(S(220, 60, 420, 260), fill=(200, 186, 250, 200)), 40)
    rng = random.Random(3)
    for _ in range(6):
        x, y, w = rng.uniform(-40, W), rng.uniform(250, 340), rng.uniform(120, 200)
        L.soft(lambda d, x=x, y=y, w=w: d.ellipse(S(x, y, x + w, y + 50), fill=(180, 168, 236, 200)), 8)
    for _ in range(60):
        x, y, r = rng.uniform(0, W), rng.uniform(0, 240), rng.choice([0.6, 0.9, 1.2])
        L.ellipse((x - r, y - r, x + r, y + r), (255, 244, 210))
    return L.done()


def plongee():
    save(fall_strip(), "plongee", "strip")
    save(dreamer_falling(), "plongee", "dreamer")
    save(title_background(), "plongee", "title_bg")
    save(dreamer_sprite("closed"), "plongee", "dreamer_sleep")


# --- Fins de nuit -----------------------------------------------------------------------------

def gold_star(size=40):
    L = Layer(size=(size, size))
    c = size / 2
    pts = []
    for i in range(40):
        a = -math.pi / 2 + i * math.pi / 20
        rr = c * (0.62 + 0.32 * math.cos(5 * (a + math.pi / 2)))
        pts.append((c + rr * math.cos(a), c + rr * math.sin(a)))
    L.soft(lambda d: d.ellipse(S(2, 2, size - 2, size - 2), fill=(255, 220, 120, 120)), size / 10)
    L.poly(pts, (255, 206, 90))
    L.poly([(c + (x - c) * 0.6, c + (y - c) * 0.6 - 1) for x, y in pts], (255, 240, 180))
    return L.done()


def dreamer_lying_closed():
    """Le reveur couche qui s'endort enfin : yeux fermes, petit sourire."""
    L = Layer()
    cx, cy, r = 152, 216, 17
    tip = bezier([(cx - 12, cy - 14), (cx - 32, cy - 26), (cx - 44, cy - 14), (cx - 42, cy + 4)], 20)
    back = bezier([(cx - 42, cy + 4), (cx - 34, cy - 8), (cx - 22, cy - 12), (cx - 4, cy - 8)], 20)
    L.poly(tip + back, (96, 70, 190))
    L.ellipse((cx - 49, cy, cx - 35, cy + 14), (244, 244, 255))
    L.ellipse((cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1), SKIN_EDGE)
    L.ellipse((cx - r, cy - r, cx + r, cy + r), SKIN)
    L.ellipse((cx - 13, cy + 3, cx - 5, cy + 9), CHEEK)
    L.ellipse((cx + 5, cy + 3, cx + 13, cy + 9), CHEEK)
    band = bezier([(cx - r - 2, cy - 2), (cx - r, cy - r - 8), (cx + r, cy - r - 8), (cx + r + 2, cy - 2)], 24)
    inner = bezier([(cx + r - 2, cy - 6), (cx + r - 4, cy - r + 2), (cx - r + 4, cy - r + 2), (cx - r + 2, cy - 6)], 24)
    L.poly(band + inner, (110, 82, 204))
    L.line(bezier([(cx - r + 3, cy - 7), (cx, cy - r - 2), (cx + r - 3, cy - 7)]), (238, 236, 255), 2.2)
    for ex in (cx - 7, cx + 7):
        L.line(bezier([(ex - 3, cy), (ex, cy + 2), (ex + 3, cy)]), (40, 30, 60), 1.2)
    L.line(bezier([(cx - 3, cy + 8), (cx, cy + 10), (cx + 3, cy + 8)]), (190, 110, 100), 1)
    return L.done()


def gears_wall():
    """Mardi : un mur de rouages de laiton, chaud et calme."""
    L = Layer()
    L.gradient(lambda m: m.rectangle(S(0, 0, W, H), fill=255), (0, 0, W, H), (120, 84, 44), (60, 40, 24))
    rng = random.Random(12)
    for _ in range(18):
        x, y, r = rng.uniform(0, W), rng.uniform(0, H), rng.uniform(20, 60)
        teeth = int(r / 4)
        pts = []
        for k in range(teeth * 2):
            a = k * math.pi / teeth
            rr = r if k % 2 == 0 else r * 0.84
            pts.append((x + rr * math.cos(a), y + rr * math.sin(a)))
        L.poly(pts, mix((170, 126, 66), (110, 78, 40), rng.random()))
        L.ellipse((x - r * 0.62, y - r * 0.62, x + r * 0.62, y + r * 0.62), (98, 70, 38))
        L.ellipse((x - r * 0.18, y - r * 0.18, x + r * 0.18, y + r * 0.18), (200, 160, 96))
    L.rect((0, 290, W, H), (52, 36, 22))
    L.rect((0, 290, W, 296), (90, 64, 36))
    return L.done()


def exam_sheet(marked=True):
    """Une copie : lignes d'ecriture, et (si marked) des traits rouges du correcteur."""
    L = Layer(size=(120, 150))
    L.soft(lambda d: d.rounded_rectangle(S(6, 8, 118, 148), radius=4 * SS, fill=(0, 0, 0, 90)), 3)
    L.rect((2, 2, 112, 142), (246, 242, 230), r=4)
    for y in range(24, 132, 12):
        L.line([(14, y), (100, y)], (170, 180, 214), 1)
    if marked:
        L.line([(20, 40), (60, 70)], (220, 50, 60), 3)
        L.line([(60, 40), (20, 70)], (220, 50, 60), 3)
        L.line(bezier([(70, 96), (84, 84), (96, 100), (86, 116)]), (220, 50, 60), 3)
    return L.done()


def helping_hand():
    """Une main qui depose quelque chose (vue de cote, doigts arrondis)."""
    L = Layer(size=(140, 80))
    L.rect((0, 26, 70, 54), (90, 120, 200), r=10)  # manche
    L.rect((60, 22, 110, 58), SKIN, r=14)
    for k, y in enumerate((20, 30, 40, 50)):
        L.rect((96, y, 132 - k * 3, y + 10), SKIN, r=5)
    L.ellipse((84, 12, 104, 28), SKIN)  # pouce
    return L.done()


def crossroads():
    """Mercredi : le carrefour brumeux, panneaux contradictoires, un sol de paves sombre."""
    L = Layer()
    L.gradient(lambda m: m.rectangle(S(0, 0, W, H), fill=255), (0, 0, W, H), (44, 56, 60), (20, 26, 28))
    L.soft(lambda d: [d.ellipse(S(x, 150, x + 220, 260), fill=(110, 126, 128, 140)) for x in range(-60, W, 160)], 18)
    L.rect((0, 270, W, H), (36, 44, 44))
    for x in range(-20, W, 34):
        for row, y in enumerate(range(276, H, 16)):
            L.rect((x + (row % 2) * 17, y, x + 30 + (row % 2) * 17, y + 12), (52, 62, 60), r=4)
    for px, dirs in ((120, (-1, 1, -1)), (520, (1, -1, 1))):  # panneaux
        L.rect((px - 3, 150, px + 3, 276), (80, 64, 48), r=2)
        for k, d in enumerate(dirs):
            y = 160 + k * 24
            body = [(px, y), (px + d * 60, y), (px + d * 72, y + 9), (px + d * 60, y + 18), (px, y + 18)]
            L.poly(body, (196, 180, 140))
    L.soft(lambda d: d.rectangle(S(0, 240, W, 300), fill=(120, 136, 138, 110)), 14)  # brume au sol
    return L.done()


def glowing_path():
    """Le chemin qui s'allume sous ses pas : des paves dores, du centre vers la droite."""
    L = Layer()
    for i, x in enumerate(range(300, W + 40, 26)):
        y = 300 + math.sin(i * 0.5) * 6
        L.soft(lambda d, x=x, y=y: d.ellipse(S(x - 18, y - 8, x + 18, y + 12), fill=(255, 220, 140, 150)), 4)
        L.rect((x - 11, y - 4, x + 11, y + 6), (255, 226, 150), r=4)
    return L.done()


def furnace_bg():
    """Jeudi : la fournaise, briques chauffees au rouge."""
    L = Layer()
    L.gradient(lambda m: m.rectangle(S(0, 0, W, H), fill=255), (0, 0, W, H), (90, 26, 22), (200, 80, 40))
    for row, y in enumerate(range(0, 300, 22)):
        for x in range(-((row % 2) * 24), W, 48):
            L.rect((x + 2, y + 2, x + 46, y + 20), mix((140, 40, 30), (220, 100, 50), y / 300), r=4)
    L.rect((0, 296, W, H), (40, 16, 14))
    return L.done()


def calm_sky():
    """Le ciel qui apparait quand la colere est passee : bleu nuit apaise, etoiles."""
    L = Layer()
    L.gradient(lambda m: m.rectangle(S(0, 0, W, H), fill=255), (0, 0, W, H), (40, 60, 120), (150, 150, 200))
    rng = random.Random(14)
    for _ in range(70):
        x, y, r = rng.uniform(0, W), rng.uniform(0, 200), rng.choice([0.6, 0.9])
        L.ellipse((x - r, y - r, x + r, y + r), (240, 240, 255))
    return L.done()


def storm_cloud():
    """L'orage de colere : un nuage sombre et son eclair."""
    L = Layer(size=(320, 200))
    L.soft(lambda d: [d.ellipse(S(x, y, x + w, y + 70), fill=(50, 30, 40, 255)) for x, y, w in ((20, 40, 140), (90, 10, 150), (160, 40, 140), (60, 60, 200))], 4)
    L.poly([(160, 110), (140, 150), (158, 150), (136, 196), (186, 138), (166, 138), (184, 110)], (255, 230, 120))
    return L.done()


def boxes_bg():
    """Vendredi : la montagne de cartons au coucher du soleil."""
    L = Layer()
    L.gradient(lambda m: m.rectangle(S(0, 0, W, H), fill=255), (0, 0, W, H), (250, 190, 130), (180, 110, 90))
    rng = random.Random(15)
    for _ in range(26):
        w, h = rng.uniform(40, 90), rng.uniform(30, 60)
        x, y = rng.uniform(-20, W), rng.uniform(120, 260)
        L.rect((x, y, x + w, y + h), mix((196, 152, 98), (150, 108, 70), rng.random()), r=4)
        L.rect((x + w / 2 - 3, y, x + w / 2 + 3, y + h), (226, 196, 136))
    L.rect((0, 290, W, H), (120, 84, 60))
    L.rect((0, 290, W, 295), (160, 120, 84))
    return L.done()


def bench():
    L = Layer(size=(200, 90))
    L.rect((10, 10, 190, 22), (170, 120, 76), r=4)
    L.rect((10, 30, 190, 42), (186, 134, 86), r=4)
    L.rect((20, 42, 30, 88), (90, 70, 60), r=2)
    L.rect((170, 42, 180, 88), (90, 70, 60), r=2)
    return L.done()


def dreamer_sitting_front():
    """Le reveur assis sur le banc, de face, soulage : yeux fermes, petit sourire."""
    L = Layer(size=(100, 140))
    x, y = 50, 132
    body = lambda m: m.rounded_rectangle(S(x - 18, y - 66, x + 18, y - 28), radius=10 * SS, fill=255)
    L.rect((x - 19, y - 67, x + 19, y - 27), (40, 50, 96), r=11)
    L.rect((x - 18, y - 66, x + 18, y - 28), PYJAMA_WHITE, r=10)
    L.clip(body, lambda e: [e.rect((x - 20, yy, x + 20, yy + 4), PYJAMA_BLUE) for yy in range(y - 64, y - 28, 8)])
    for lx in (x - 16, x + 4):  # jambes pliees, vers l'avant
        L.rect((lx, y - 32, lx + 12, y - 20), PYJAMA_WHITE, r=5)
        L.rect((lx + 1, y - 22, lx + 11, y - 2), PYJAMA_WHITE, r=5)
        L.ellipse((lx - 1, y - 6, lx + 13, y + 2), (226, 120, 130))
    for sx in (-1, 1):
        L.line(bezier([(x + sx * 17, y - 60), (x + sx * 22, y - 46), (x + sx * 16, y - 34)]), PYJAMA_WHITE, 8)
        L.ellipse((x + sx * 16 - 5, y - 38, x + sx * 16 + 5, y - 28), SKIN)
    hx, hy, r = x, y - 84, 18
    L.ellipse((hx - r - 1, hy - r - 1, hx + r + 1, hy + r + 1), SKIN_EDGE)
    L.ellipse((hx - r, hy - r, hx + r, hy + r), SKIN)
    L.rect((hx - r + 4, hy - r + 2, hx + r - 4, hy - r + 8), (98, 62, 44), r=3)
    L.ellipse((hx - 14, hy + 4, hx - 6, hy + 10), CHEEK)
    L.ellipse((hx + 6, hy + 4, hx + 14, hy + 10), CHEEK)
    for ex in (hx - 7, hx + 7):
        L.line(bezier([(ex - 3, hy), (ex, hy + 2), (ex + 3, hy)]), (40, 30, 60), 1.2)
    L.line(bezier([(hx - 4, hy + 8), (hx, hy + 11), (hx + 4, hy + 8)]), (190, 110, 100), 1.2)
    cone = bezier([(hx - 14, hy - 16), (hx - 4, hy - 46), (hx + 26, hy - 44), (hx + 32, hy - 18)], 24)
    cone_back = bezier([(hx + 32, hy - 18), (hx + 22, hy - 30), (hx + 6, hy - 30), (hx + 14, hy - 16)], 16)
    L.poly(cone + cone_back, CAP)
    L.ellipse((hx + 25, hy - 22, hx + 39, hy - 8), (244, 244, 255))
    band = bezier([(hx - r - 2, hy - 4), (hx - r, hy - r - 9), (hx + r, hy - r - 9), (hx + r + 2, hy - 4)], 24)
    inner = bezier([(hx + r - 2, hy - 8), (hx + r - 4, hy - r + 1), (hx - r + 4, hy - r + 1), (hx - r + 2, hy - 8)], 24)
    L.poly(band + inner, (110, 82, 204))
    L.line(bezier([(hx - r + 3, hy - 9), (hx, hy - r - 3), (hx + r - 3, hy - 9)]), (238, 236, 255), 2.2)
    return L.done()


def dreamer_carrying():
    """Le reveur debout, une pile de cartons dans les bras."""
    L = Layer(size=(100, 180))
    draw_dreamer(L, 50, 172, "worried", "hug")
    for k, (w, dx) in enumerate(((56, 0), (48, 4))):  # deux cartons tenus contre la poitrine
        y1 = 148 - k * 24
        L.rect((50 - w / 2 + dx, y1 - 24, 50 + w / 2 + dx, y1), (196, 152, 98), r=4)
        L.rect((50 - 3 + dx, y1 - 24, 50 + 3 + dx, y1), (226, 196, 136))
    return L.done()


def tea_cup():
    L = Layer(size=(50, 50))
    L.rect((8, 22, 36, 44), (250, 246, 236), r=6)
    L.ellipse((30, 26, 44, 38), (250, 246, 236))
    L.ellipse((33, 29, 41, 35), (0, 0, 0, 0))
    L.rect((10, 22, 34, 28), (230, 170, 80), r=3)
    L.rect((4, 42, 40, 46), (200, 186, 170), r=2)
    return L.done()


def ballroom():
    """Samedi : la salle de bal vide, marbre, hautes fenetres, lustre eteint."""
    L = Layer()
    L.gradient(lambda m: m.rectangle(S(0, 0, W, 270), fill=255), (0, 0, W, 270), (30, 34, 70), (70, 70, 110))
    for x in range(40, W, 120):
        L.rect((x, 40, x + 50, 240), (60, 80, 140), r=24)
        L.rect((x + 4, 44, x + 46, 236), (90, 120, 190), r=21)
        L.rect((x + 23, 44, x + 27, 236), (60, 80, 140))
    for x in range(0, W, 120):
        L.rect((x - 8, 20, x + 8, 270), (220, 214, 200), r=4)
    L.ellipse((270, 6, 370, 50), (200, 180, 120))  # lustre
    for k in range(6):
        L.ellipse((276 + k * 16, 40, 284 + k * 16, 52), (240, 230, 190))
    for gx in range(0, W, 40):
        for gy in range(270, H, 30):
            L.rect((gx, gy, gx + 40, gy + 30), (226, 224, 236) if (gx // 40 + gy // 30) % 2 else (160, 166, 192))
    L.soft(lambda d: d.rectangle(S(0, 262, W, 278), fill=(20, 20, 40, 160)), 4)
    return L.done()


def glowing_dancer(flip=False):
    """Une silhouette lumineuse qui danse un instant (souvenir de quelqu'un)."""
    L = Layer(size=(80, 140))
    def draw(d):
        d.ellipse(S(28, 6, 52, 30), fill=(255, 240, 200, 230))
        d.polygon([(a * SS, b * SS) for a, b in [(30, 32), (50, 32), (62, 110), (18, 110)]], fill=(255, 230, 180, 200))
        d.line([(a * SS, b * SS) for a, b in [(32, 40), (14, 24)]], fill=(255, 230, 180, 220), width=6 * SS)
        d.line([(a * SS, b * SS) for a, b in [(48, 40), (66, 60)]], fill=(255, 230, 180, 220), width=6 * SS)
    L.soft(draw, 3)
    L.soft(lambda d: d.ellipse(S(10, 0, 70, 130), fill=(255, 220, 160, 70)), 12)
    img = L.done()
    return img.transpose(Image.FLIP_LEFT_RIGHT) if flip else img


def dawn_sky(phase):
    """Dimanche : le ciel avant l'aube (0) et a l'aube (1)."""
    L = Layer()
    top, bottom = ((14, 14, 40), (60, 50, 100)) if phase == 0 else ((90, 110, 190), (255, 200, 140))
    L.gradient(lambda m: m.rectangle(S(0, 0, W, H), fill=255), (0, 0, W, H), top, bottom)
    if phase == 1:
        L.soft(lambda d: d.ellipse(S(140, 150, 500, 420), fill=(255, 220, 160, 200)), 40)
    return L.done()


def sun():
    L = Layer(size=(180, 180))  # marge autour du halo : pas de bord coupe
    L.soft(lambda d: d.ellipse(S(20, 20, 160, 160), fill=(255, 230, 170, 160)), 14)
    L.ellipse((50, 50, 130, 130), (255, 244, 210))
    return L.done()


def dawn_land():
    L = Layer()
    L.poly([(0, 280)] + bezier([(0, 280), (200, 262), (420, 290), (W, 270)], 30) + [(W, H), (0, H)], (40, 30, 50))
    return L.done()


def fins():
    save(gold_star(), "fins", "star")
    save(dreamer_lying_closed(), "fins", "lundi_dreamer")
    save(gears_wall(), "fins", "mardi_bg")
    save(exam_sheet(True), "fins", "mardi_copy")
    save(exam_sheet(False), "fins", "mardi_sheet")
    save(helping_hand(), "fins", "mardi_hand")
    save(crossroads(), "fins", "mercredi_bg")
    save(glowing_path(), "fins", "mercredi_path")
    save(dreamer_sprite("open"), "fins", "dreamer_stand")
    save(furnace_bg(), "fins", "jeudi_bg")
    save(calm_sky(), "fins", "jeudi_sky")
    save(storm_cloud(), "fins", "jeudi_storm")
    save(boxes_bg(), "fins", "vendredi_bg")
    save(bench(), "fins", "vendredi_bench")
    save(dreamer_sitting_front(), "fins", "vendredi_sit")
    save(dreamer_carrying(), "fins", "vendredi_carry")
    save(tea_cup(), "fins", "vendredi_tea")
    save(ballroom(), "fins", "samedi_bg")
    save(glowing_dancer(), "fins", "samedi_dancer")
    save(glowing_dancer(True), "fins", "samedi_dancer2")
    save(dawn_sky(0), "fins", "dimanche_night")
    save(dawn_sky(1), "fins", "dimanche_dawn")
    save(sun(), "fins", "dimanche_sun")
    save(dawn_land(), "fins", "dimanche_land")


def preview(scene, names, out):
    """Apercu : superpose les calques (pour verifier le dessin sans animation)."""
    base = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    for n in names:
        base.alpha_composite(Image.open(os.path.join(ROOT, scene, n + ".png")))
    base.resize((W * 2, H * 2), Image.NEAREST).save(out)


SCENES = {"chambre": chambre, "soucis": soucis, "horizon": horizon, "plongee": plongee, "fins": fins}

if __name__ == "__main__":
    for scene in sys.argv[1:] or SCENES:
        SCENES[scene]()
        print("cinematique :", scene)
