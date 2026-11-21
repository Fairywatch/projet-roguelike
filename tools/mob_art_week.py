"""Creatures redessinees du mardi au dimanche (suite de tools/mob_art.py, meme direction : volume,
lumiere en haut a gauche, 4 tons, contour d'encre colore, reflets, 4 images d'animation).

Les sprites "a etats" (Examen, Masque, Miroir Brise, Pile ou Face, Absence) gardent 2 images,
choisies par leur script (scripts/visual/mob_frames.gd). La taille d'une image ne change pas : les
collisions en dependent. Lance par tools/mob_art.py.
"""
import math
import random

from PIL import Image, ImageDraw

from mob_art import canvas, mask_wh, sheet
from proj_art import dots, hexc, ink, ramp, rot, shade


# --- Outils ------------------------------------------------------------------------------------

def ell(w, h, *boxes):
    return mask_wh(w, h, ellipses=boxes)


def poly(w, h, *polys):
    return mask_wh(w, h, polys=polys)


def rect(img, x0, y0, x1, y1, color):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < img.width and 0 <= y < img.height:
                img.putpixel((x, y), color)


def line(img, pts, color, width=1):
    ImageDraw.Draw(img).line([(round(x), round(y)) for x, y in pts], fill=color, width=width)


def part(img, mask, tones, outline=None, **kw):
    """Une piece modelee sur son propre calque, avec son contour : elle se detache de ce qu'elle
    recouvre (feuilles empilees, tetes, passagers...)."""
    layer = canvas(*img.size)
    solid = shade(layer, mask, tones, **kw)
    if outline:
        ink(layer, hexc(outline))
    img.alpha_composite(layer)
    return solid


def fade(img, alpha):
    """Rend le sprite translucide (apres le contour, qui demande des pixels opaques)."""
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            c = px[x, y]
            if c[3]:
                px[x, y] = c[:3] + (round(c[3] * alpha),)


def heart_mask(w, h, cx, cy, s):
    m = Image.new("L", (w, h), 0)
    for y in range(h):
        for x in range(w):
            nx, ny = (x - cx) / s, (cy - y) / s
            if (nx * nx + ny * ny - 1) ** 3 - nx * nx * ny ** 3 <= 0:
                m.putpixel((x, y), 255)
    return m


def tone_of(tones, lum):
    return tones[0 if lum < 0.2 else (1 if lum < 0.42 else (2 if lum < 0.68 else 3))]


PLAYER_OUTLINE = (20, 12, 30)
PLAYER_EYE = (34, 22, 34)
WALK = [2, 3, 4, 3]  # images de marche du reveur (gen_pixel_art.player_frames)


def player_copy(tones, outline, eyes=None, alpha=1.0, shine=None):
    """Les doubles du reveur (Reflet, Autre Soi, Ombre portee) : sa silhouette qui marche,
    repeinte en 4 tons. shine : couleur d'un reflet de verre qui glisse en diagonale."""
    import gen_pixel_art
    frames = gen_pixel_art.player_frames()

    def make(f):
        img = frames[WALK[f]].copy()
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                c = px[x, y]
                if not c[3]:
                    continue
                if c[:3] == PLAYER_OUTLINE:
                    px[x, y] = hexc(outline)
                elif c[:3] == PLAYER_EYE and eyes:
                    px[x, y] = hexc(eyes)
                else:
                    px[x, y] = tone_of(tones, (0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]) / 255)
                    if shine and (x + y - f * 4) % 14 in (0, 1):
                        px[x, y] = hexc(shine)
        if alpha < 1.0:
            fade(img, alpha)
        return img
    w, h = frames[0].size
    return sheet(w, h, 4, make)


# --- Mardi (Stress) ----------------------------------------------------------------------------

def trotteuse():
    """La Trotteuse : une aiguille de laiton sur pattes, la pointe en avant, l'oeil presse."""
    w, h = 18, 10
    brass = ramp("6e4a12", "b8862a", "e6c25a", "fff0a8")

    def make(f):
        img = canvas(w, h)
        for i, x in enumerate((4, 7, 10)):  # pattes qui trottent
            o = [-1, 0, 1, 0][(f + i * 2) % 4]
            dots(img, [(x, 6), (x + o, 7), (x + o, 8)], hexc("3a2618"))
        shade(img, poly(w, h, [(3, 3), (12, 3), (12, 5), (3, 5)]), brass, light=(0, -1))
        shade(img, ell(w, h, (1, 2, 5, 6)), brass)
        shade(img, poly(w, h, [(11, 1), (16, 4), (11, 7)]), brass)
        dots(img, [(3, 4)], hexc("6e4a12"))  # le pivot
        dots(img, [(16, 4), (15, 4)], hexc("d83a3a"))  # la pointe rouge
        dots(img, [(12, 3), (13, 3)], hexc("3a1a0a"))  # sourcil presse
        dots(img, [(13, 4)], hexc("fff6e0"))
        dots(img, [(14, 4)], hexc("1a1010"))
        ink(img, hexc("2a1a0c"))
        dots(img, [(2, 3), (12, 2)], hexc("ffffff"))
        if f % 2 == 0:  # traits de vitesse
            dots(img, [(0, 3 + f)], hexc("e6c25a", 160))
        return img
    return sheet(w, h, 4, make)


def pile_devoirs():
    """La Pile de devoirs : trois copies empilees, celle du dessus se souleve ; la copie du bas
    a un visage inquiet et transpire."""
    w, h = 16, 16
    paper = ramp("8a8678", "c8c4b4", "ecebe2", "ffffff")

    def make(f):
        img = canvas(w, h)
        lift = [0, 1, 0, 0][f]
        bottom = part(img, poly(w, h, [(1, 8), (14, 7), (14, 14), (1, 14)]), paper, "6a6658")
        mid = part(img, poly(w, h, [(2, 5), (13, 4), (14, 8), (2, 9)]), paper, "6a6658")
        top = part(img, poly(w, h, [(3, 3 - lift), (13, 2), (13, 5), (3, 6)]), paper, "6a6658")
        for x in range(5, 12):  # lignes d'ecriture
            if (x, 4) in top:
                img.putpixel((x, 4), hexc("8aa6d8"))
            if (x, 7) in mid and (x, 7) not in top:
                img.putpixel((x, 7), hexc("8aa6d8"))
        for y in range(10, 14):
            if (3, y) in bottom:
                img.putpixel((3, y), hexc("e07a80"))  # marge rouge
        dots(img, [(6, 10), (10, 10)], hexc("2a2030"))
        dots(img, [(5, 9), (11, 9)], hexc("6a6478"))  # sourcils inquiets
        dots(img, [(7, 12), (8, 12)], hexc("b03040"))
        ink(img, hexc("2a2638"))
        if f in (1, 2):
            dots(img, [(13, 9 + f)], hexc("a8d8ff"))  # une goutte de stress
        dots(img, [(4, 3 - lift + 1)], hexc("ffffff"))
        return img
    return sheet(w, h, 4, make)


def stylo_rouge():
    """Le Stylo rouge : capuchon blanc, corps rouge aux yeux fronces, plume qui goutte."""
    w, h = 8, 17
    red = ramp("6e1018", "b8222e", "e0404a", "ff8a8a")
    steel = ramp("4a4a58", "8a8a9a", "c8c8d4", "f4f4fa")

    def make(f):
        img = canvas(w, h)
        shade(img, poly(w, h, [(2, 1), (5, 1), (6, 2), (6, 5), (1, 5), (1, 2)]), steel)
        shade(img, poly(w, h, [(1, 5), (6, 5), (6, 11), (1, 11)]), red, light=(-1, -0.3))
        shade(img, poly(w, h, [(2, 12), (5, 12), (5, 13), (2, 13)]), steel)
        shade(img, poly(w, h, [(2, 14), (5, 14), (4, 16), (3, 16)]), ramp("2a2a34", "50505c", "7a7a88", "a8a8b4"))
        dots(img, [(5, y) for y in range(2, 7)], hexc("8a8a9a"))  # l'agrafe du capuchon
        dots(img, [(2, 8), (5, 8)], hexc("fff4f0"))
        dots(img, [(2, 7), (3, 7), (4, 7), (5, 7)], hexc("4a0810"))  # sourcils fronces
        dots(img, [(3, 10), (4, 10)], hexc("4a0810"))
        dots(img, [(3, 16)], hexc("c01828"))
        ink(img, hexc("3a0a10"))
        if f in (1, 2, 3):  # la goutte d'encre
            dots(img, [(3, 16)], hexc("e0404a" if f == 2 else "c01828"))
        dots(img, [(2, 2), (2, 6)], hexc("ffffff"))
        return img
    return sheet(w, h, 4, make)


def battement():
    """Le Battement : un coeur nerveux qui se gonfle et se serre, les yeux ecarquilles."""
    w, h = 16, 14
    red = ramp("6a0e22", "b8243e", "e4485e", "ff9aa8")

    def make(f):
        img = canvas(w, h)
        s = [5.4, 4.9, 5.2, 5.1][f]
        shade(img, heart_mask(w, h, 7.5, 7.2, s), red)
        dots(img, [(4, 6), (5, 6), (4, 7), (5, 7), (10, 6), (11, 6), (10, 7), (11, 7)], hexc("fff4f4"))
        dots(img, [(5, 7), (10, 7)], hexc("2a0812"))
        dots(img, [(6, 9), (7, 10), (8, 9), (9, 10)], hexc("4a0a18"))
        ink(img, hexc("3a0814"))
        dots(img, [(3, 3), (4, 3), (3, 4)], hexc("ffffff"))
        if f in (1, 2):
            dots(img, [(14, 3 + f)], hexc("a8d8ff"))
        return img
    return sheet(w, h, 4, make)


def tableau_noir():
    """Le Tableau Noir : un visage dessine a la craie qui regarde a droite et a gauche ; une
    formule s'ecrit dans le coin."""
    w, h = 30, 18
    wood = ramp("3a2010", "6a4024", "9a6438", "c8905a")
    board = ramp("12261c", "1e3a2c", "2a4c3a", "3a6050")
    chalk = hexc("e8ece2")
    rng = random.Random(3)
    dust = [(rng.randrange(4, 26), rng.randrange(4, 11)) for _ in range(14)]

    def make(f):
        img = canvas(w, h)
        for x0 in (4, 24):  # pieds
            shade(img, poly(w, h, [(x0, 13), (x0 + 1, 13), (x0 + 1, 16), (x0, 16)]), wood)
        shade(img, poly(w, h, [(1, 1), (28, 1), (28, 13), (1, 13)]), wood)
        shade(img, poly(w, h, [(3, 3), (26, 3), (26, 11), (3, 11)]), board, edge_dark=False)
        dots(img, dust, hexc("4a6a5a"))
        d = ImageDraw.Draw(img)
        look = [-1, 0, 1, 0][f]
        for ex in (7, 18):
            d.ellipse([ex, 4, ex + 4, 8], outline=chalk)
            dots(img, [(ex + 2 + look, 6), (ex + 2 + look, 7)], chalk)
        line(img, [(10, 9), (12, 10), (17, 10), (19, 9)], chalk)
        scribble = [(22, 9), (23, 8), (24, 9), (25, 8)]
        dots(img, scribble[:f + 1], hexc("c8d0c4"))
        dots(img, [(x, 12) for x in range(3, 27)], hexc("3a2010"))  # la rainure a craies
        dots(img, [(6, 12), (7, 12)], chalk)
        dots(img, [(21, 12)], hexc("f0a0b0"))
        ink(img, hexc("1a0e08"))
        dots(img, [(2, 2), (3, 2)], hexc("f0c890"))
        if f == 2:
            dots(img, [(8, 11), (9, 10)], hexc("c8d0c4", 150))  # poussiere de craie
        return img
    return sheet(w, h, 4, make)


def cloche():
    """La Cloche : une cloche d'ecole en laiton, la bouche ouverte ; le battant se balance."""
    w, h = 22, 18
    bell = ramp("6a4410", "b8801e", "e8bc48", "fff2a8")
    body = [(9, 2), (12, 2), (15, 4), (16, 8), (17, 11), (20, 13), (20, 14), (1, 14), (1, 13), (4, 11), (5, 8), (6, 4)]

    def make(f):
        img = canvas(w, h)
        sw = [-2, 0, 2, 0][f]
        shade(img, ell(w, h, (9 + sw, 14, 11 + sw, 16)), ramp("2a2420", "5a5048", "8a8070", "c0b8a8"))
        tilt = [-0.07, 0, 0.07, 0][f]
        solid = shade(img, poly(w, h, rot(body, tilt, 10.5, 1)), bell)
        shade(img, ell(w, h, (9, 0, 12, 3)), bell)
        dots(img, [(10, 1), (11, 1)], (0, 0, 0, 0))
        for x, y in solid:
            if y == 13:
                img.putpixel((x, y), hexc("8a5a14"))
            elif y == 12:
                img.putpixel((x, y), hexc("f0cc60"))
        dots(img, [(7, 7), (7, 8), (14, 7), (14, 8)], hexc("3a2408"))
        dots(img, [(10, 9), (11, 9), (10, 10), (11, 10)], hexc("4a2a0a"))
        dots(img, [(11, 10)], hexc("b06a3a"))
        ink(img, hexc("2a1a06"))
        dots(img, [(7, 4), (6, 5), (6, 6)], hexc("ffffff"))
        if f % 2 == 0:  # ondes de sonnerie
            dots(img, [(0, 6), (0, 9), (21, 6), (21, 9)], hexc("fff0a0", 200))
        return img
    return sheet(w, h, 4, make)


def horloge_classe():
    """L'Horloge de Classe : cadran cercle de metal, regard severe ; l'aiguille avance."""
    w = h = 28
    metal = ramp("2a2e3a", "4a5064", "7a8298", "b8c0d4")
    dial = ramp("b8b098", "dcd6c0", "f2eedc", "ffffff")
    c = 13.5

    def make(f):
        img = canvas(w, h)
        shade(img, ell(w, h, (1, 1, 26, 26)), metal)
        shade(img, ell(w, h, (4, 4, 23, 23)), dial, edge_dark=False)
        for i in range(12):  # graduations
            a = i * math.pi / 6
            pts = [(c + math.cos(a) * 8.4, c + math.sin(a) * 8.4)]
            if i % 3 == 0:
                pts.append((c + math.cos(a) * 7.4, c + math.sin(a) * 7.4))
            dots(img, pts, hexc("3a3a48"))
        for r, a, color in ((8, -2.2 + f * math.pi / 8, "c83a3a"), (5, 0.9, "8a2a30")):  # aiguilles
            line(img, [(c, c), (c + math.cos(a) * r, c + math.sin(a) * r)], hexc(color))
        for ex in (9, 17):
            dots(img, [(ex, 10), (ex + 1, 10), (ex, 11), (ex + 1, 11)], hexc("1e1a28"))
            dots(img, [(ex, 10)], hexc("8a8aa0"))
        dots(img, [(8, 8), (9, 8), (10, 9), (19, 8), (18, 8), (17, 9)], hexc("1e1a28"))  # sourcils severes
        dots(img, [(12, 18), (13, 18), (14, 18), (15, 18)], hexc("5a3a40"))
        dots(img, [(13, 13), (14, 14)], hexc("e6c25a"))
        ink(img, hexc("141420"))
        dots(img, [(6, 9), (7, 8), (8, 7)], hexc("ffffff", 170))
        dots(img, [(5, 4), (4, 5)], hexc("e8eef8"))
        return img
    return sheet(w, h, 4, make)


QMARK = [(0, 0), (1, -1), (2, 0), (2, 1), (1, 2), (1, 4)]


def examen():
    """L'Examen (2 images d'etat) : une grande copie au coin corne et a la note entouree ;
    0 l'oeil clos, 1 l'oeil grand ouvert, injecte, iris rouge."""
    w, h = 30, 38
    paper = ramp("9a9488", "d6d2c4", "f0eee4", "ffffff")
    almond = [(7, 18), (11, 14), (15, 13), (19, 14), (23, 18), (19, 22), (15, 23), (11, 22)]

    def make(f):
        img = canvas(w, h)
        solid = shade(img, poly(w, h, [(1, 1), (28, 1), (28, 30), (22, 36), (1, 36)]), paper, light=(-0.6, -0.8))
        for y in range(5, 35, 4):
            for x in range(6, 28):
                if (x, y) in solid and (x, y + 1) in solid:
                    img.putpixel((x, y), hexc("a8bce0"))
        for y in range(2, 36):
            if (5, y) in solid:
                img.putpixel((5, y), hexc("e08088"))
        shade(img, poly(w, h, [(22, 30), (28, 30), (22, 36)]), ramp("8a8476", "b8b2a4", "d6d2c4", "ecebe2"), light=(0.7, 0.7))
        dots(img, [(x, 3 + (x % 3 == 0)) for x in range(7, 16)], hexc("5a5468"))  # le nom griffonne
        ImageDraw.Draw(img).ellipse([21, 2, 27, 8], outline=hexc("d02838"))
        dots(img, [(23, 4), (24, 3), (25, 4), (24, 5), (24, 7)], hexc("d02838"))
        if f == 0:
            shade(img, poly(w, h, almond), ramp("a89a90", "ccc0b4", "e4dcd0", "f6f0e8"))
            lash = [(x, 18 + (1 if 11 <= x <= 19 else 0)) for x in range(8, 23)]
            dots(img, lash, hexc("3a2a34"))
            for x in range(9, 22, 3):
                y = 18 + (1 if 11 <= x <= 19 else 0)
                dots(img, [(x, y + 1), (x - 1, y + 2)], hexc("3a2a34"))
        else:
            shade(img, poly(w, h, almond), ramp("c8b8b8", "e8dcdc", "f8f2f2", "ffffff"), edge_dark=False)
            dots(img, [(9, 16), (10, 17), (20, 16), (21, 18), (10, 20), (19, 21)], hexc("d85a6a"))
            shade(img, ell(w, h, (11, 14, 19, 22)), ramp("5a0a14", "a01828", "d83a48", "ff8a90"))
            shade(img, ell(w, h, (13, 16, 17, 20)), ramp("0a0408", "1a0a10", "2a1018", "3a1820"), edge_dark=False)
            dots(img, [(13, 16), (14, 16), (13, 17)], hexc("ffffff"))
        for qx, qy in ((6, 27), (12, 29), (17, 26)):
            dots(img, [(qx + dx, qy + dy) for dx, dy in QMARK], hexc("c82838"))
        ink(img, hexc("2a2430"))
        return img
    return sheet(w, h, 2, make)


# --- Mercredi (Doute) --------------------------------------------------------------------------

def reflet():
    """Le Reflet : le reveur en verre bleute ; un reflet glisse sur lui quand il marche."""
    return player_copy(ramp("2a4a8a", "5a86c4", "9ac4ec", "e4f6ff"), "1e3a6a", alpha=0.85, shine="f4fcff")


def autre_soi():
    """L'Autre Soi : le double sombre du reveur, cerne d'une lueur violette, les yeux rouges."""
    return player_copy(ramp("0a0614", "1e1232", "36245a", "5a4288"), "a060e8", eyes="ff4a6a")


def pile_ou_face():
    """Pile ou Face (2 images d'etat) : une piece d'or bombee ; 0 pile (une lune gravee),
    1 face (un visage qui sourit)."""
    w, h = 16, 13
    gold = ramp("6a4810", "b88a24", "e8c04c", "fff2a0")
    inner = ramp("8a6018", "c89a30", "f0cc5c", "fff6b8")

    def make(f):
        img = canvas(w, h)
        shade(img, ell(w, h, (1, 1, 14, 11)), gold)
        shade(img, ell(w, h, (3, 3, 12, 9)), inner, light=(0.7, 0.7), edge_dark=False)
        if f == 0:
            moon = [(x, y) for y in range(h) for x in range(w)
                    if math.hypot(x - 7.2, y - 6) <= 2.7 and math.hypot(x - 8.6, y - 5.2) > 2.2]
            dots(img, [(x + 1, y + 1) for x, y in moon], hexc("8a6018"))
            dots(img, moon, hexc("fff2a0"))
        else:
            dots(img, [(6, 5), (9, 5)], hexc("5a3a08"))
            dots(img, [(5, 7), (6, 8), (7, 8), (8, 8), (9, 8), (10, 7)], hexc("5a3a08"))
            dots(img, [(5, 6), (10, 6)], hexc("f8a860"))
        ink(img, hexc("3a2606"))
        dots(img, [(4, 2), (3, 3), (2, 4)], hexc("ffffff"))
        return img
    return sheet(w, h, 2, make)


def carrefour():
    """Le Carrefour : un poteau et deux panneaux qui pointent en sens contraires, chacun ses yeux ;
    ils hesitent et se balancent."""
    w, h = 20, 16
    sign_a = ramp("6a4a28", "a8804c", "d4b07a", "f0d8a8")
    sign_b = ramp("5a3e22", "94703f", "c49a64", "e6c48e")

    def make(f):
        img = canvas(w, h)
        shade(img, ell(w, h, (6, 12, 13, 15)), ramp("3a3a44", "5a5a68", "84849a", "b0b0c4"))
        shade(img, poly(w, h, [(9, 1), (10, 1), (10, 13), (9, 13)]), ramp("3a2412", "5a3a20", "7a5430", "9a7040"))
        da, db = [0, 1, 1, 0][f], [0, 0, -1, -1][f]
        part(img, poly(w, h, [(5 + da, 1), (14 + da, 1), (16 + da, 2.5), (14 + da, 4), (5 + da, 4)]), sign_a, "2a1a0c")
        part(img, poly(w, h, [(14 + db, 7), (6 + db, 7), (4 + db, 8.5), (6 + db, 10), (14 + db, 10)]), sign_b, "2a1a0c")
        dots(img, [(12 + da, 2), (14 + da, 2)], hexc("fff6e0"))
        dots(img, [(13 + da, 2), (15 + da, 2)], hexc("1e140a"))  # regardent a droite
        dots(img, [(6 + db, 8), (8 + db, 8)], hexc("fff6e0"))
        dots(img, [(5 + db, 8), (7 + db, 8)], hexc("1e140a"))  # regardent a gauche
        dots(img, [(x + da, 3) for x in range(6, 11) if x % 2 == 0], hexc("8a6a3a"))
        dots(img, [(x + db, 9) for x in range(9, 14) if x % 2 == 1], hexc("7a5a32"))
        ink(img, hexc("2a1a0c"))
        dots(img, [(6 + da, 1), (7 + db, 7)], hexc("fff6e0"))
        return img
    return sheet(w, h, 4, make)


def masque():
    """Le Masque (2 images d'etat) : masque de porcelaine ; 0 joyeux (yeux plisses, joues roses),
    1 triste (sourcils tombants, larmes)."""
    w, h = 16, 12

    def make(f):
        img = canvas(w, h)
        tones = ramp("8a8494", "c8c4d0", "eeeaf2", "ffffff") if f == 0 else ramp("7a8098", "b8c0d4", "e2e8f4", "ffffff")
        shade(img, ell(w, h, (1, 1, 14, 10)), tones)
        dark = hexc("1e1828")
        if f == 0:
            dots(img, [(4, 4), (5, 3), (6, 4), (9, 4), (10, 3), (11, 4)], dark)
            dots(img, [(4, 7), (5, 8), (6, 8), (7, 8), (8, 8), (9, 8), (10, 8), (11, 7)], dark)
            dots(img, [(6, 9), (7, 9), (8, 9), (9, 9)], hexc("c04a6a"))
            dots(img, [(3, 6), (12, 6)], hexc("f0a0b4"))
            dots(img, [(7, 2), (8, 2)], hexc("e8c04c"))
        else:
            dots(img, [(4, 4), (5, 4), (6, 3), (9, 3), (10, 4), (11, 4)], dark)
            dots(img, [(5, 5), (5, 6), (10, 5), (10, 6)], hexc("6aa8e8"))
            dots(img, [(5, 9), (6, 8), (7, 8), (8, 8), (9, 8), (10, 9)], dark)
            dots(img, [(7, 2), (8, 2)], hexc("8aa0c8"))
        ink(img, hexc("1e1828"))
        dots(img, [(3, 2), (2, 3)], hexc("ffffff"))
        if f == 1:
            dots(img, [(5, 7), (10, 7)], hexc("a8d4ff"))
        return img
    return sheet(w, h, 2, make)


def miroir_brise():
    """Le Miroir Brise (2 images d'etat) : miroir ovale dans un cadre dore, un oeil dans le verre ;
    0 intact, 1 fendu en etoile, un eclat manquant."""
    w, h = 22, 30
    gold = ramp("6a4410", "b8862a", "e6c25a", "fff0a8")
    glass = ramp("3a5a8a", "6a90c0", "a8c8e8", "e8f6ff")
    c = (11, 15)

    def make(f):
        img = canvas(w, h)
        shade(img, ell(w, h, (1, 1, 20, 28)), gold)
        for i in range(10):  # clous du cadre
            a = i * math.tau / 10 + 0.3
            dots(img, [(10.5 + math.cos(a) * 8.6, 14.5 + math.sin(a) * 12.6)], hexc("8a5a14"))
        shade(img, ell(w, h, (4, 4, 17, 25)), glass, light=(-0.5, -1), edge_dark=False)
        line(img, [(6, 11), (10, 7)], hexc("f0faff"))
        line(img, [(6, 15), (13, 8)], hexc("d8ecfa"))
        dots(img, [(9, 15), (10, 15), (12, 15), (13, 15)], hexc("f6f2ff"))
        dots(img, [(11, 15)], hexc("1e2a4a"))
        dots(img, [(10, 14), (11, 14), (12, 14)], hexc("3a5a8a"))
        if f == 1:
            shade(img, poly(w, h, [(13, 6), (16, 10), (13, 12)]), ramp("06080e", "0e1424", "16203a", "1e2a4a"), edge_dark=False)
            for k in range(6):
                a = k * math.pi / 3 + 0.35
                end = (c[0] + math.cos(a) * 7, c[1] + math.sin(a) * 10)
                line(img, [c, end], hexc("1e2a4a"))
                dots(img, [(round(end[0]) + 1, round(end[1]))], hexc("ffffff"))
        ink(img, hexc("2a1a08"))
        dots(img, [(5, 3), (4, 4), (3, 6)], hexc("fff6c8"))
        return img
    return sheet(w, h, 2, make)


LABYRINTHE = [
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
]


def labyrinthe():
    """Le Labyrinthe : un bloc de pierre moussue creuse de couloirs, deux yeux verts au centre ;
    une lueur court dans les couloirs."""
    w, h = 22, 16
    stone = ramp("3a403a", "5a645a", "808a80", "aab4a8")
    rng = random.Random(11)
    moss = [(rng.randrange(1, 21), rng.choice((1, 2, 14))) for _ in range(9)]
    path = [(x + 1, y + 1) for y, row in enumerate(LABYRINTHE) for x, ch in enumerate(row) if ch == "l"]

    def make(f):
        img = canvas(w, h)
        shade(img, poly(w, h, [(1, 1), (20, 1), (20, 14), (1, 14)]), stone)
        for y, row in enumerate(LABYRINTHE):
            for x, ch in enumerate(row):
                p = (x + 1, y + 1)
                if ch == "l":
                    img.putpixel(p, hexc("262c26"))
                    if y + 1 < len(LABYRINTHE) and LABYRINTHE[y + 1][x] == "S":
                        img.putpixel((p[0], p[1] + 1), hexc("aab4a8"))
                elif ch == "s":
                    img.putpixel(p, hexc("4a524a"))
        for i, p in enumerate(path):  # la lueur qui court
            if i % 9 == f * 2:
                img.putpixel(p, hexc("6aff9a"))
        glow = ["8affa8", "b8ffcc", "8affa8", "5ad880"][f]
        for y, row in enumerate(LABYRINTHE):
            for x, ch in enumerate(row):
                if ch == "G":
                    img.putpixel((x + 1, y + 1), hexc(glow))
                elif ch == "k":
                    img.putpixel((x + 1, y + 1), hexc("0e3a1a"))
        dots(img, moss, hexc("5a8a3a"))
        ink(img, hexc("1a1e1a"))
        return img
    return sheet(w, h, 4, make)


def deux_voies():
    """Les Deux Voies : une silhouette encapuchonnee au visage partage, moitie clair moitie
    ombre (un oeil sage, un oeil rouge) ; la cape ondule."""
    w, h = 16, 16
    cloak = ramp("1e1832", "3a3060", "5a4c8a", "8a7ab8")

    def make(f):
        img = canvas(w, h)
        sway = [0, 1, 0, -1][f]
        shade(img, poly(w, h, [(4, 7), (11, 7), (14, 13), (12 + sway, 14), (8, 13), (4 + sway, 14), (1, 13)]), cloak)
        shade(img, ell(w, h, (3, 1, 12, 9)), cloak)
        face = ell(w, h, (5, 3, 10, 8))
        for y in range(h):
            for x in range(w):
                if face.getpixel((x, y)):
                    light = x < 8
                    img.putpixel((x, y), hexc(("f0e6d2" if y < 6 else "d4c8b4") if light else ("1a1224" if y < 6 else "0e0a18")))
        dots(img, [(6, 5)], hexc("2a2030"))
        dots(img, [(9, 5)], hexc("e84a4a"))
        dots(img, [(6, 7)], hexc("a89a88"))
        ink(img, hexc("120c20"))
        dots(img, [(5, 2), (4, 3)], hexc("b0a4d8"))
        return img
    return sheet(w, h, 4, make)


# --- Jeudi (Frustration) -----------------------------------------------------------------------

def grogne():
    """La Grogne : une boule de poils herissee, sourcils fronces, dents serrees, qui fume."""
    w, h = 16, 12
    fur = ramp("5a1010", "a82a26", "d8483a", "ff8a6a")

    def make(f):
        img = canvas(w, h)
        spikes = []
        for i, x in enumerate((3, 6, 9, 12)):
            tip = 1 if (i + f) % 2 else 2
            spikes.append([(x - 1, 4), (x + 1, 4), (x, tip)])
        spikes += [[(1, 6), (2, 9), (0, 8)], [(14, 6), (13, 9), (15, 8)]]
        shade(img, mask_wh(w, h, polys=spikes, ellipses=[(1, 2, 14, 11)]), fur)
        dark = hexc("2a0808")
        dots(img, [(3, 4), (4, 4), (5, 5), (12, 4), (11, 4), (10, 5)], dark)
        dots(img, [(4, 6), (11, 6)], hexc("fff0e0"))
        dots(img, [(5, 6), (10, 6)], dark)
        dots(img, [(4, 8), (11, 8)] + [(x, 9) for x in range(5, 11)], dark)
        dots(img, [(x, 8) for x in range(5, 11)], hexc("fff0e0"))
        dots(img, [(7, 8), (9, 8)], hexc("c8b8a8"))
        ink(img, hexc("2a0606"))
        dots(img, [(4, 3), (3, 4)], hexc("ffc8a8"))
        puff = [[(1, 1)], [(1, 0), (14, 1)], [(14, 0)], []][f]
        dots(img, puff, hexc("e0d8d8", 190))
        return img
    return sheet(w, h, 4, make)


def porte_close():
    """La Porte Close : porte a panneaux aux yeux mauvais, la fente a courrier pour bouche ;
    elle avance a petits pas."""
    w, h = 16, 17
    wood = ramp("3a2014", "6a4028", "9a6440", "c48c5c")

    def make(f):
        img = canvas(w, h)
        legs = [[(4, 0), (11, 0)], [(4, 1), (11, 0)], [(4, 0), (11, 0)], [(4, 0), (11, 1)]][f]
        for x, lift in legs:
            dots(img, [(x, 14), (x, 15 - lift)], hexc("2a160c"))
            dots(img, [(x + (-1 if x < 8 else 1), 15 - lift)], hexc("2a160c"))
        shade(img, poly(w, h, [(1, 1), (14, 1), (14, 13), (1, 13)]), ramp("24140a", "3a2014", "5a3420", "7a4a2c"))
        shade(img, poly(w, h, [(2, 2), (13, 2), (13, 13), (2, 13)]), wood)
        for x0, y0, x1, y1 in ((4, 3, 11, 6), (4, 8, 11, 12)):  # panneaux moulures
            dots(img, [(x, y0) for x in range(x0, x1 + 1)] + [(x0, y) for y in range(y0, y1 + 1)], hexc("5a3420"))
            dots(img, [(x, y1) for x in range(x0, x1 + 1)] + [(x1, y) for y in range(y0, y1 + 1)], hexc("c48c5c"))
        dots(img, [(5, 4), (6, 5), (10, 4), (9, 5)], hexc("1a0c08"))
        dots(img, [(5, 5), (10, 5)], hexc("ffd860"))
        dots(img, [(x, 9) for x in range(6, 10)], hexc("e0b048"))
        dots(img, [(x, 10) for x in range(6, 10)], hexc("1a0c08"))
        dots(img, [(12, 9), (12, 10)], hexc("f0c048"))
        ink(img, hexc("1a0c06"))
        dots(img, [(2, 2), (3, 2)], hexc("e0a878"))
        return img
    return sheet(w, h, 4, make)


def ressort():
    """Le Ressort : trois spires d'acier sous une tete verte au grand sourire ; il se comprime."""
    w, h = 14, 13
    steel = ramp("4a4a58", "8a8a9a", "c4c4d0", "f0f0f8")
    head = ramp("1e5a2a", "3a9a4a", "6acc70", "b8f0b0")

    def make(f):
        img = canvas(w, h)
        sp = [2.0, 1.5, 1.0, 1.5][f]
        shade(img, poly(w, h, [(2, 11), (11, 11), (11, 11), (2, 11)]), ramp("2a2a34", "50505e", "70707e", "90909e"))
        rect(img, 2, 11, 11, 11, hexc("50505e"))
        ys = [10 - sp * k for k in range(3)]
        for y in ys:
            part(img, ell(w, h, (1, round(y) - 1, 12, round(y) + 1)), steel, "2a2a38", light=(0, -1))
        hy = round(ys[-1]) - 2
        part(img, ell(w, h, (2, hy - 4, 11, hy)), head, "143a1a", edge_dark=False)
        dots(img, [(4, hy - 3), (5, hy - 3), (8, hy - 3), (9, hy - 3)], hexc("ffffff"))
        dots(img, [(5, hy - 2), (8, hy - 2)], hexc("0e2a12"))
        dots(img, [(6, hy - 1), (7, hy - 1)], hexc("0e2a12"))
        ink(img, hexc("1a1a24"))
        dots(img, [(3, hy - 3)], hexc("e8ffe0"))
        return img
    return sheet(w, h, 4, make)


def cocotte():
    """La Cocotte-minute : une marmite d'acier aux yeux orange, la soupape qui siffle, le
    couvercle qui tressaute."""
    w, h = 20, 15
    steel = ramp("4a4e5a", "80869a", "b4bac8", "e8ecf4")

    def make(f):
        img = canvas(w, h)
        jump = [0, -1, 0, 0][f]
        shade(img, poly(w, h, [(0, 5), (2, 5), (2, 7), (0, 7)]), ramp("14141a", "28282e", "3a3a44", "50505a"))
        shade(img, poly(w, h, [(17, 5), (19, 5), (19, 7), (17, 7)]), ramp("14141a", "28282e", "3a3a44", "50505a"))
        shade(img, poly(w, h, [(2, 5), (17, 5), (17, 12), (15, 13), (4, 13), (2, 12)]), steel)
        part(img, ell(w, h, (2, 2 + jump, 17, 6 + jump)), steel, "2a2c36")
        shade(img, poly(w, h, [(9, 0 + jump + 1), (10, 0 + jump + 1), (10, 2 + jump), (9, 2 + jump)]), ramp("6a1010", "b02828", "d84040", "ff8080"))
        dots(img, [(5, 6), (6, 7), (14, 6), (13, 7)], hexc("1a1c24"))
        dots(img, [(6, 8), (7, 8), (12, 8), (13, 8)], hexc("ff8a3a"))
        dots(img, [(7, 11), (8, 10), (9, 11), (10, 10), (11, 11), (12, 10)], hexc("1a1c24"))
        dots(img, [(4, 9), (15, 9)], hexc("5a5e6a"))  # rivets
        ink(img, hexc("1a1c24"))
        dots(img, [(4, 3 + jump), (3, 6)], hexc("ffffff"))
        steam = [[], [(7, 0)], [(6, 0), (12, 0)], [(13, 0)]][f]
        dots(img, steam, hexc("f0f4fa", 210))
        return img
    return sheet(w, h, 4, make)


def patron():
    """Le Patron sans visage : un costume sombre, cravate rouge, une tete lisse sans traits."""
    w, h = 20, 19
    suit = ramp("14141e", "24243a", "383852", "54547a")
    skin = ramp("8a8480", "bcb6b0", "dcd6d0", "f4f0ec")

    def make(f):
        img = canvas(w, h)
        step = [0, 1, 0, -1][f]
        for x0 in (4, 11):
            off = step if x0 == 4 else -step
            shade(img, poly(w, h, [(x0, 14), (x0 + 4, 14), (x0 + 4, 16 + max(off, 0)), (x0, 16 + max(off, 0))]), suit)
            dots(img, [(x, 17) for x in range(x0 - 1, x0 + 5)] if off <= 0 else [(x, 16) for x in range(x0 - 1, x0 + 5)], hexc("08080c"))
        shade(img, poly(w, h, [(3, 8), (16, 8), (18, 10), (18, 15), (1, 15), (1, 10)]), suit)
        dots(img, [(4, y) for y in range(10, 15)] + [(15, y) for y in range(10, 15)], hexc("14141e"))  # bras
        shade(img, poly(w, h, [(8, 7), (11, 7), (9.5, 11)]), ramp("a8a8b4", "d4d4dc", "f0f0f4", "ffffff"))
        sway = [0, 0, 1, 0][f]
        shade(img, poly(w, h, [(9, 8), (10, 8), (10 + sway, 12), (9.5 + sway, 13), (9 + sway, 12)]), ramp("5a0a10", "a01828", "d02838", "f06070"))
        part(img, ell(w, h, (6, 1, 13, 7)), skin, "3a3638")
        dots(img, [(9, 5), (10, 5)], hexc("cac4be"))  # pas de visage : a peine une ombre
        ink(img, hexc("0c0c14"))
        dots(img, [(7, 2), (8, 2)], hexc("ffffff"))
        dots(img, [(3, 9)], hexc("6a6a90"))
        return img
    return sheet(w, h, 4, make)


def tapis_roulant():
    """Le Tapis Roulant : une bande de caoutchouc qui defile, hérissee de dents, entre deux
    rouleaux aux yeux rouges."""
    w, h = 34, 12
    metal = ramp("3a3a48", "6a6a7a", "a0a0b0", "d8d8e4")

    def make(f):
        img = canvas(w, h)
        for y in range(2, 10):
            for x in range(4, 30):
                band = (x + f) % 4 < 2
                c = "3a3a48" if band else "2a2a34"
                if y == 3:
                    c = "5a5a6a"
                elif y == 9:
                    c = "1a1a22"
                img.putpixel((x, y), hexc(c))
        for x in range(4, 30):  # les dents
            if (x + f) % 4 == 0:
                img.putpixel((x, 1), hexc("e8e8e0"))
                img.putpixel((x, 2), hexc("bcbcb0"))
        for cx, look in ((4.5, 1), (29.5, -1)):
            shade(img, ell(w, h, (cx - 3.5, 1, cx + 3.5, 10)), metal)
            a = f * math.pi / 2
            dots(img, [(cx + math.cos(a) * 2.6, 5.5 + math.sin(a) * 3)], hexc("2a2a34"))
            ex = round(cx) + look - (1 if look < 0 else 0)
            dots(img, [(ex - 1, 5), (ex, 5), (ex - 1, 6), (ex, 6)], hexc("f4f0e8"))
            dots(img, [(ex if look > 0 else ex - 1, 5), (ex if look > 0 else ex - 1, 6)], hexc("e83a3a"))
        ink(img, hexc("141418"))
        dots(img, [(3, 2), (28, 2)], hexc("ffffff"))
        return img
    return sheet(w, h, 4, make)


BRICKS = [ramp("5a2018", "8a3424", "b04a32", "d4704e"), ramp("4e1c16", "7e2e20", "a2422c", "c86448"),
          ramp("62261a", "94402a", "b8583a", "dc8060")]


def mur():
    """Le Mur : un pan de briques modelees, regard furieux, dents serrees, une fissure ; des
    miettes de brique tombent."""
    w, h = 22, 38
    rng = random.Random(4)
    moss = [(rng.randrange(1, 21), rng.choice((35, 36))) for _ in range(8)]

    def make(f):
        img = canvas(w, h)
        for y in range(1, 37):
            for x in range(1, 21):
                row, yy = (y - 1) // 5, (y - 1) % 5
                shifted = x - 1 + (5 if row % 2 else 0)
                xx = shifted % 10
                if yy == 0 or xx == 0:
                    img.putpixel((x, y), hexc("9a8e84" if (x + y) % 3 == 0 else "bcb0a4"))
                    continue
                tones = BRICKS[(row * 7 + (shifted // 10) * 3) % 3]
                t = 3 if yy == 1 else (2 if yy in (2, 3) and xx < 8 else 1)
                if yy == 4 and xx == 9:
                    t = 0
                img.putpixel((x, y), tones[t])
        look = [-1, 0, 1, 0][f]
        for x0 in (5, 13):
            rect(img, x0, 12, x0 + 3, 13, hexc("f4e8dc"))
            rect(img, x0 + 1 + look + (1 if look < 0 else 0), 12, x0 + 2 + look - (1 if look > 0 else 0), 13, hexc("1a0a08"))
        dots(img, [(4, 10), (5, 10), (6, 11), (7, 11), (17, 10), (16, 10), (15, 11), (14, 11)], hexc("1a0a08"))
        rect(img, 7, 18, 14, 19, hexc("1a0a08"))
        dots(img, [(x, 18) for x in range(8, 14)], hexc("f0e4d8"))
        dots(img, [(10, 18), (12, 18)], hexc("c8b8a8"))
        crack = [(12, 22), (11, 24), (12, 26), (10, 28), (11, 30), (9, 33)]
        line(img, crack, hexc("2a1410"))
        dots(img, [(x + 1, y) for x, y in crack], hexc("d48a6a"))
        dots(img, moss, hexc("4a7a3a"))
        ink(img, hexc("2a1410"))
        dots(img, [(3, 28 + f * 2), (18, 6 + f * 3)], hexc("8a3424"))  # miettes
        return img
    return sheet(w, h, 4, make)


def colere():
    """La Colere : un nuage d'orage bouillonnant aux yeux rouges ; les eclairs et la pluie
    tombent dessous."""
    w, h = 36, 26
    cloud = ramp("1e1a2a", "3a3450", "5a5274", "8a84a8")
    puffs = [(2, 6, 15, 19), (8, 2, 22, 15), (16, 3, 29, 16), (22, 7, 34, 19), (6, 10, 20, 20), (16, 10, 30, 20)]

    def make(f):
        img = canvas(w, h)
        boil = [0, 1, 0, -1][f]
        for i, (x0, y0, x1, y1) in enumerate(puffs):
            d = boil if i % 2 else -boil
            part(img, ell(w, h, (x0, y0 + d * (i < 4), x1, y1)), cloud, "141020")
        dots(img, [(11, 9), (12, 9), (13, 10), (14, 10), (24, 9), (23, 9), (22, 10), (21, 10)], hexc("0e0a14"))
        dots(img, [(12, 11), (13, 11), (14, 11), (21, 11), (22, 11), (23, 11)], hexc("ff3a3a"))
        dots(img, [(13, 12), (22, 12)], hexc("ff8a6a"))
        dots(img, [(14, 16), (15, 15), (16, 16), (17, 15), (18, 16), (19, 15), (20, 16)], hexc("0e0a14"))
        ink(img, hexc("0e0a18"))
        dots(img, [(9, 4), (10, 3), (17, 4), (18, 4)], hexc("b8b4d4"))
        bolts = {1: [(12, 20), (11, 21), (12, 22), (11, 23), (12, 24)], 2: [(24, 20), (25, 21), (24, 22), (25, 23), (24, 24), (25, 25)]}
        if f in bolts:
            dots(img, bolts[f], hexc("fff07a"))
            dots(img, [(x + 1, y) for x, y in bolts[f]], hexc("ffffff"))
        for i, x in enumerate((6, 15, 19, 29, 9, 27)):  # la pluie
            dots(img, [(x, 21 + (f + i) % 4)], hexc("6a8ad8", 200))
        return img
    return sheet(w, h, 4, make)


# --- Vendredi (Epuisement) ---------------------------------------------------------------------

PASSENGER = ramp("8a6a50", "c8a07a", "e8c8a0", "fff0d8")


def fardeau():
    """Le Fardeau : une grosse bete grise aux yeux cernes, trois petits passagers sur le dos ;
    elle avance lourdement."""
    w, h = 22, 14
    hide = ramp("3a3430", "645a52", "8a8076", "b4aa9e")

    def make(f):
        img = canvas(w, h)
        plod = [0, 1, 0, 1][f]
        for x, lift in ((4, f == 1), (16, f == 3)):
            dots(img, [(x, 12), (x, 13 - lift)], hexc("2a2420"))
        shade(img, ell(w, h, (1, 4 + plod, 20, 12)), hide)
        for i, x in enumerate((3, 9, 14)):
            bob = 1 if (f + i) % 2 else 0
            part(img, ell(w, h, (x, 1 + bob + plod, x + 4, 5 + bob + plod)), PASSENGER, "3a2a1e")
            dots(img, [(x + 1, 3 + bob + plod), (x + 3, 3 + bob + plod)], hexc("2a1a10"))
        dots(img, [(5, 7 + plod), (6, 7 + plod), (13, 7 + plod), (14, 7 + plod)], hexc("4a4038"))  # paupieres lourdes
        dots(img, [(5, 8 + plod), (6, 8 + plod), (13, 8 + plod), (14, 8 + plod)], hexc("e8e0d0"))
        dots(img, [(6, 8 + plod), (13, 8 + plod)], hexc("1a1410"))
        dots(img, [(5, 9 + plod), (14, 9 + plod)], hexc("7a5a6a"))  # cernes
        dots(img, [(9, 10 + plod), (10, 10 + plod), (11, 10 + plod)], hexc("2a2420"))
        ink(img, hexc("1e1a16"))
        return img
    return sheet(w, h, 4, make)


def passager():
    """Le Passager : une petite bete beige aux grands yeux et a la dent pointue, qui trottine."""
    w, h = 10, 8

    def make(f):
        img = canvas(w, h)
        for i, x in enumerate((3, 6)):
            lift = 1 if (f + i * 2) % 4 == 1 else 0
            dots(img, [(x, 6 - lift), (x, 7 - lift)], hexc("5a4030"))
        shade(img, ell(w, h, (1, 1 - (f % 2), 8, 6)), PASSENGER)
        dots(img, [(3, 3), (6, 3)], hexc("1e140a"))
        dots(img, [(4, 5)], hexc("ffffff"))
        ink(img, hexc("3a2a1e"))
        dots(img, [(2, 2 - (f % 2)), (3, 2)], hexc("ffffff"))
        return img
    return sheet(w, h, 4, make)


def sangsue():
    """La Sangsue de sommeil : un corps violet anneles qui ondule, yeux jaunes, ventouse rose."""
    w, h = 14, 8
    body = ramp("3a1a4a", "6a3a86", "9a5ab8", "c890e0")

    def make(f):
        img = canvas(w, h)
        boxes = []
        for i in range(5):
            cx = 2.4 + i * 2.2
            cy = 4 + math.sin(f * math.pi / 2 + i) * 0.8
            boxes.append((cx - 2, cy - 2.5, cx + 2, cy + 2.5))
        shade(img, ell(w, h, *boxes), body)
        for i in range(4):
            dots(img, [(3 + i * 2, 2 + round(math.sin(f * math.pi / 2 + i) * 0.8))], hexc("d8b0f0"))
        dots(img, [(12, 3), (12, 4)], hexc("2a0a2a"))
        dots(img, [(12, 4)], hexc("e07ab0"))
        dots(img, [(10, 2)], hexc("fff07a"))
        ink(img, hexc("1e0a26"))
        return img
    return sheet(w, h, 4, make)


def soignant():
    """Le Soignant : un petit esprit en blouse et coiffe blanches, croix rouge sur le coeur ; il
    flotte, entoure d'etincelles de soin."""
    w, h = 12, 15
    robe = ramp("9a9cb0", "d0d2e0", "eeeff6", "ffffff")
    face = ramp("4a4258", "6e6484", "928aac", "b8b0d0")

    def make(f):
        img = canvas(w, h)
        fl = [0, -1, -1, 0][f]
        hem = [0, 1, 0, -1][f]
        shade(img, poly(w, h, [(3, 6 + fl), (8, 6 + fl), (10, 12 + fl), (7 + hem, 13 + fl), (4 + hem, 12 + fl), (1, 13 + fl)]), robe)
        shade(img, ell(w, h, (3, 1 + fl, 8, 6 + fl)), face)
        rect(img, 3, 1 + fl, 8, 1 + fl, hexc("f4f4fa"))
        dots(img, [(5, 1 + fl), (6, 1 + fl)], hexc("e03a48"))
        dots(img, [(4, 3 + fl), (7, 3 + fl)], hexc("e8e8ff"))
        dots(img, [(5, 7 + fl), (6, 7 + fl), (5, 8 + fl), (6, 8 + fl), (5, 9 + fl), (6, 9 + fl), (4, 8 + fl), (7, 8 + fl)], hexc("e03a48"))
        ink(img, hexc("2a2638"))
        sparks = [[(0, 4)], [(11, 3), (0, 9)], [(11, 9)], [(1, 2), (10, 11)]][f]
        dots(img, sparks, hexc("8aff9a", 220))
        return img
    return sheet(w, h, 4, make)


def bougie_fondue():
    """La Bougie fondue : une chandelle qui coule en larmes de cire, yeux lourds de sommeil ;
    la flamme vacille."""
    w, h = 10, 15
    wax = ramp("a89878", "d8cbb0", "f0e8d6", "fffaf0")
    flame = ramp("c24a1a", "f08a2a", "ffc85a", "fff6d0")

    def make(f):
        img = canvas(w, h)
        shade(img, ell(w, h, (0, 11, 9, 13)), wax)
        shade(img, mask_wh(w, h, polys=[[(2, 5), (7, 5), (7, 12), (2, 12)], [(1, 6), (3, 6), (2, 9)], [(6, 6), (8, 6), (8, 10), (7, 10)]]), wax)
        dots(img, [(3, 8), (6, 8)], hexc("5a4030"))
        dots(img, [(3, 7), (6, 7)], hexc("a89878"))
        dots(img, [(4, 10)], hexc("7a6050"))
        dots(img, [(5, 11), (5, 12)], hexc("fffaf0"))  # une larme de cire
        ink(img, hexc("3a2a1a"))
        dots(img, [(4, 4), (4, 5)], hexc("2a1a10"))  # la meche
        dx = [0, 1, 0, -1][f]
        tip = [(4 + dx, 0)] if f != 2 else [(4, 1)]
        shade(img, mask_wh(w, h, polys=[[(3, 3), (6, 3), (4.5 + dx, 0)]], ellipses=[(3, 1, 6, 4)]), flame)
        dots(img, tip, hexc("ffc85a"))
        dots(img, [(4, 3)], hexc("fff6d0"))
        return img
    return sheet(w, h, 4, make)


def oeuf():
    """L'Oeuf : une coquille mouchetee, fendillee, qui tangue (quelque chose bouge dedans)."""
    w, h = 10, 10
    shell = ramp("9a8c74", "d0c4aa", "eee6d4", "fffaf0")

    def make(f):
        img = canvas(w, h)
        shade(img, ell(w, h, (1, 1, 8, 9)), shell)
        dots(img, [(3, 3), (6, 4), (4, 6), (6, 7), (2, 6)], hexc("a08a64"))
        dots(img, [(4, 3), (5, 4), (4, 5)], hexc("5a4a34"))
        ink(img, hexc("3a3020"))
        dots(img, [(3, 2)], hexc("ffffff"))
        tilt = [0, 1, 0, -1][f]
        if tilt:  # le haut de l'oeuf tangue
            top = img.crop((0, 0, w, 5))
            out = canvas(w, h)
            out.alpha_composite(img.crop((0, 5, w, h)), (0, 5))
            out.alpha_composite(top, (tilt, 0))
            img = out
        return img
    return sheet(w, h, 4, make)


def atlas():
    """Atlas : un geant courbe, tete baissee, qui porte a bout de bras un monde qui tourne."""
    w, h = 30, 40
    ocean = ramp("143a6a", "1e5a9a", "3a82c4", "8ac4f0")
    land = ramp("1e4a24", "2e6a34", "4a9a4a", "8ac46a")
    skin = ramp("4a3426", "7a5a42", "a8805e", "d0aa82")
    cloth = ramp("4a1810", "7a2a1e", "a8402e", "d06a50")

    def make(f):
        img = canvas(w, h)
        lift = [0, -1, -1, 0][f]
        for x0 in (7, 18):  # jambes flechies
            shade(img, poly(w, h, [(x0, 34), (x0 + 4, 34), (x0 + 4 + (1 if x0 > 10 else -1), 38), (x0 + (1 if x0 > 10 else -1), 38)]), skin)
        shade(img, poly(w, h, [(8, 20), (21, 20), (25, 27), (24, 35), (5, 35), (4, 27)]), skin)
        shade(img, poly(w, h, [(6, 31), (23, 31), (21, 36), (8, 36)]), cloth)
        for side in (1, -1):  # bras leves
            arm = [(4, 25), (9, 20), (9, 13 + lift), (6, 12 + lift), (4, 17)]
            if side < 0:
                arm = [(29 - x, y) for x, y in arm]
            shade(img, poly(w, h, arm), skin)
        globe = ell(w, h, (6, 2 + lift, 23, 17 + lift))
        tmp = canvas(w, h)
        shade(tmp, globe, ocean)
        for y in range(h):
            for x in range(w):
                c = tmp.getpixel((x, y))
                if not c[3]:
                    continue
                u = x + f * 2
                if math.sin(u * 0.55 + 1.0) + math.cos(y * 0.7) + math.sin((u + y) * 0.35) > 0.8:
                    c = land[ocean.index(c)]
                if math.sin(u * 0.9 + y * 0.3) > 0.93:
                    c = hexc("f4f8ff")
                img.putpixel((x, y), c)
        part(img, ell(w, h, (11, 16, 18, 22)), skin, "1a120c")
        dots(img, [(12, 18), (13, 19), (17, 18), (16, 19)], hexc("2a1a10"))  # yeux plisses par l'effort
        dots(img, [(x, 21) for x in range(13, 17)], hexc("f0e6d8"))
        ink(img, hexc("1a120c"))
        dots(img, [(9, 5 + lift), (10, 4 + lift), (8, 7 + lift)], hexc("e8f6ff"))
        if f == 2:
            dots(img, [(19, 18), (19, 19)], hexc("a8d8ff"))
        return img
    return sheet(w, h, 4, make)


def nid():
    """Le Nid : une mere-oiseau ebouriffee couve dans son nid de branches ; elle ouvre le bec et
    gonfle ses plumes."""
    w, h = 30, 22
    feather = ramp("2e2048", "54407a", "7e66a8", "b09ad4")
    twig = ramp("3a2412", "6a4424", "9a6a3a", "c49a5a")
    rng = random.Random(8)
    twigs = [((rng.randrange(2, 27), rng.randrange(13, 20)), rng.choice((-1, 1)), rng.choice(("3a2412", "c49a5a", "9a6a3a"))) for _ in range(26)]

    def make(f):
        img = canvas(w, h)
        puff = -1 if f == 2 else 0
        shade(img, mask_wh(w, h, polys=[[(2, 6), (8, 5), (9, 10), (3, 9)]]), feather)
        shade(img, ell(w, h, (7, 3 + puff, 22, 15)), feather)
        part(img, ell(w, h, (8, 6 + puff, 18, 13)), ramp("241838", "40305e", "604c84", "8a74ac"), "1a1028")
        for x in range(10, 17, 2):
            dots(img, [(x, 10 + puff), (x + 1, 11 + puff)], hexc("2e2048"))
        shade(img, ell(w, h, (15, 1 + puff, 24, 9 + puff)), feather)
        dots(img, [(18, 1 + puff), (19, 0 + puff + 1), (20, 1 + puff)], hexc("b09ad4"))
        open_beak = f in (1, 2)
        shade(img, poly(w, h, [(23, 4 + puff), (27, 5 + puff), (23, 6 + puff)]), ramp("8a4a10", "d08020", "f0aa40", "ffd890"))
        if open_beak:
            shade(img, poly(w, h, [(23, 7 + puff), (26, 8 + puff), (23, 8 + puff)]), ramp("8a4a10", "d08020", "f0aa40", "ffd890"))
            dots(img, [(23, 6 + puff), (24, 7 + puff)], hexc("5a1a20"))
        dots(img, [(20, 4 + puff), (21, 4 + puff)], hexc("fff6d0"))
        dots(img, [(21, 4 + puff)], hexc("1a1020"))
        nest = part(img, ell(w, h, (1, 12, 28, 20)), twig, "1a1008")
        for (x, y), d, c in twigs:
            for k in range(3):
                p = (x + k, y + d * (k // 2))
                if p in nest:
                    img.putpixel(p, hexc(c))
        ink(img, hexc("1a1020"))
        dots(img, [(10, 4 + puff), (11, 4 + puff), (17, 2 + puff)], hexc("d8ccf0"))
        if f == 3:
            dots(img, [(5, 3), (6, 2)], hexc("d8ccf0", 200))  # une plume qui s'envole
        return img
    return sheet(w, h, 4, make)


def balancier():
    """Le Balancier : une vieille horloge de bois aux paupieres lourdes ; le pendule se balance
    dessous."""
    w, h = 20, 13
    wood = ramp("3a2010", "6a4024", "9a6438", "c8905a")
    dial = ramp("b8ac90", "dcd2b8", "f2ead6", "fffaf0")

    def make(f):
        img = canvas(w, h)
        bx = 9.5 + [-3, 0, 3, 0][f]
        line(img, [(9.5, 9), (bx, 11)], hexc("8a6a2a"))
        shade(img, ell(w, h, (bx - 1, 10, bx + 1.6, 12)), ramp("6e4a12", "b8862a", "e6c25a", "fff0a8"))
        shade(img, poly(w, h, [(1, 3), (18, 3), (18, 9), (1, 9)]), wood)
        shade(img, ell(w, h, (6, 0, 13, 4)), wood)
        for x in (3, 16):
            dots(img, [(x, y) for y in range(4, 9)], hexc("3a2010"))
            dots(img, [(x, 3)], hexc("e6c25a"))
        shade(img, ell(w, h, (5, 1, 14, 10)), dial, edge_dark=False)
        for a in range(0, 12, 3):
            ang = a * math.pi / 6
            dots(img, [(9.5 + math.cos(ang) * 3.6, 5.5 + math.sin(ang) * 3.4)], hexc("5a4a3a"))
        dots(img, [(7, 4), (8, 4), (11, 4), (12, 4)], hexc("3a2a20"))  # paupieres lourdes
        dots(img, [(7, 5), (12, 5)], hexc("1a120c"))
        dots(img, [(9, 7), (10, 7)], hexc("5a3a2a"))
        ink(img, hexc("1e120a"))
        dots(img, [(7, 1), (2, 4)], hexc("f0d0a0"))
        return img
    return sheet(w, h, 4, make)


HEAD_TONES = [ramp("2a2438", "4a4062", "6a5e88", "9488b0"), ramp("2a2830", "4a4654", "6e6a7c", "9a96a8"),
              ramp("30242c", "54404c", "7a6070", "a48a9a")]


def poids_du_monde():
    """Le Poids du Monde : une masse faite de toutes les tetes qu'il porte, sur un grand corps
    affaisse aux yeux mi-clos ; il respire lourdement."""
    w, h = 36, 42
    body = ramp("1e1a2a", "383250", "524a72", "746a98")
    rng = random.Random(5)
    heads = sorted([(rng.randrange(7, 29), rng.randrange(4, 21), rng.choice((3, 3, 4)), rng.randrange(3)) for _ in range(14)], key=lambda t: t[1])

    def make(f):
        img = canvas(w, h)
        slump = [0, 1, 2, 1][f]
        shade(img, poly(w, h, [(8, 18 + slump), (28, 18 + slump), (34, 40), (2, 40)]), body)
        for cx, cy, r, k in heads:
            cy += slump
            part(img, ell(w, h, (cx - r, cy - r, cx + r, cy + r)), HEAD_TONES[k], "120e1c")
            dots(img, [(cx - 1, cy), (cx + 1, cy)], hexc("1a1428"))
        ey = 28 + slump // 2
        for x0 in (12, 21):
            rect(img, x0, ey, x0 + 3, ey, hexc("e6dcf0"))
            rect(img, x0, ey - 1, x0 + 3, ey - 1, hexc("2a2438"))
            dots(img, [(x0 + 1, ey), (x0 + 2, ey)], hexc("1a1428"))
        dots(img, [(x, 34 + slump // 2) for x in range(15, 22)], hexc("120e1c"))
        ink(img, hexc("120e1c"))
        return img
    return sheet(w, h, 4, make)


# --- Samedi (Solitude) -------------------------------------------------------------------------

def silhouette():
    """La Silhouette : l'ombre translucide de quelqu'un, un liseré de lune sur l'epaule, deux
    yeux a peine visibles ; elle se balance."""
    w, h = 12, 16
    shadow = ramp("1a1a2e", "2e2e4a", "464668", "626288")

    shape = ["...SSSS...", "..SSSSSS..", "..SSSSSS..", "...SSSS...", "....SS....", ".SSSSSSSS.", "SSSSSSSSSS",
             "SS.SSSS.SS", "SS.SSSS.SS", "...SSSS...", "...SSSS...", "...S..S...", "...S..S...", "..SS..SS.."]

    def make(f):
        img = canvas(w, h)
        sway = [0, 0, 1, 0][f]  # la tete et le buste se balancent, les pieds restent
        step = [0, 1, 0, -1][f]
        m = Image.new("L", (w, h), 0)
        for y, row in enumerate(shape):
            for x, ch in enumerate(row):
                dx = sway if y < 5 else 0
                if y >= 11 and ch == "S":
                    dx = (step if x < 5 else -step) if y == 13 else 0
                if ch == "S" and 0 <= x + 1 + dx < w:
                    m.putpixel((x + 1 + dx, y + 1), 255)
        shade(img, m, shadow)
        dots(img, [(5 + sway, 3), (7 + sway, 3)], hexc("b8b8e8"))
        ink(img, hexc("12121e"))
        dots(img, [(4 + sway, 2), (2, 7), (3, 7)], hexc("9a9ac8"))
        fade(img, 0.82)
        return img
    return sheet(w, h, 4, make)


def chaise():
    """La Chaise vide : une chaise de bois, une echarpe oubliee sur le dossier ; elle grince."""
    w, h = 16, 16
    wood = ramp("4a2c18", "7a4a2a", "a8703e", "d09a60")

    def make(f):
        img = canvas(w, h)
        creak = [0, 1, 0, 0][f]
        for x in (5, 10):  # pieds arriere
            rect(img, x, 10, x, 13, wood[0])
        shade(img, poly(w, h, [(3, 1), (9, 1), (9, 8), (3, 8)]), wood)
        for x in (5, 7):
            dots(img, [(x, y) for y in range(3, 8)], hexc("2a180c"))
        shade(img, poly(w, h, [(3, 8), (13, 8), (13, 10), (3, 10)]), wood, light=(0, -1))
        rect(img, 3, 10, 3, 14, wood[1])
        rect(img, 12, 10, 12, 14 - creak, wood[1])
        scarf = [(9, 2), (10, 2), (10, 3), (10, 4), (11, 5), (11, 6)]
        dots(img, scarf, hexc("6a8ab8"))
        dots(img, [(11, 7 + (f % 2))], hexc("4a6a98"))
        ink(img, hexc("1e1008"))
        dots(img, [(3, 1), (4, 1)], hexc("f0c890"))
        if f == 2:
            dots(img, [(14, 6)], hexc("c8c4e0", 160))
        return img
    return sheet(w, h, 4, make)


def lettre():
    """La Lettre sans reponse : une enveloppe cachetee d'un coeur, au regard triste ; son rabat
    s'entrouvre en volant."""
    w, h = 18, 12
    paper = ramp("a8a294", "d8d2c4", "f0ece2", "ffffff")

    def make(f):
        img = canvas(w, h)
        dy = [0, -1, 0, 1][f]
        if f in (1, 2):
            shade(img, poly(w, h, [(2, 3 + dy), (15, 3 + dy), (8.5, 0)]), ramp("8a8476", "b8b2a4", "d6d0c2", "ecebe2"))
        shade(img, poly(w, h, [(1, 2 + dy), (16, 2 + dy), (16, 10 + dy), (1, 10 + dy)]), paper)
        if f not in (1, 2):
            line(img, [(1, 2 + dy), (8.5, 6 + dy), (16, 2 + dy)], hexc("bcb4a4"))
        line(img, [(1, 10 + dy), (6, 6 + dy)], hexc("c8c0b0"))
        line(img, [(16, 10 + dy), (11, 6 + dy)], hexc("c8c0b0"))
        dots(img, [(8, 6 + dy), (9, 6 + dy), (8, 7 + dy), (9, 7 + dy)], hexc("c02838"))
        dots(img, [(8, 6 + dy)], hexc("f06070"))
        dots(img, [(4, 7 + dy), (13, 7 + dy)], hexc("2a2430"))
        dots(img, [(3, 6 + dy), (14, 6 + dy)], hexc("8a8476"))
        rect(img, 13, 3 + dy, 15, 4 + dy, hexc("6a8ad8"))
        ink(img, hexc("2a2430"))
        dots(img, [(2, 3 + dy)], hexc("ffffff"))
        return img
    return sheet(w, h, 4, make)


def echo():
    """L'Echo : une forme floue qui crie, les contours qui se repetent en ondes autour d'elle."""
    w, h = 18, 20
    core = ramp("6a76b0", "98a4d8", "c0caf0", "e8eeff")

    def make(f):
        img = canvas(w, h)
        for k in range(3):  # ondes trames qui s'eloignent
            r = 6.5 + k * 1.5 + f * 0.375
            for y in range(h):
                for x in range(w):
                    d = math.hypot((x - 8.5) / 0.85, y - 9.5)
                    if r <= d < r + 0.7 and (x + y) % 2 == 0:
                        img.putpixel((x, y), hexc("a8b4e8", 150 - k * 35))
        for dx, a in ((-1, 90), (1, 90)):  # deux doubles flous
            ghost = canvas(w, h)
            shade(ghost, ell(w, h, (4 + dx, 4, 13 + dx, 15)), core, edge_dark=False)
            fade(ghost, a / 255)
            img.alpha_composite(ghost)
        shade(img, ell(w, h, (4, 4, 13, 15)), core)
        dots(img, [(7, 8), (10, 8), (7, 9), (10, 9)], hexc("2a2a50"))
        o = [(8, 11), (9, 11), (8, 12), (9, 12)] if f % 2 == 0 else [(8, 11), (9, 11)]
        dots(img, o, hexc("3a3a68"))
        dots(img, [(6, 5), (5, 6)], hexc("ffffff"))
        fade(img, 0.92)
        return img
    return sheet(w, h, 4, make)


def telephone():
    """Le Telephone Muet : un vieux telephone a cadran, visage triste sur le cadran ; le combine
    saute quand il sonne."""
    w, h = 20, 15
    bake = ramp("141418", "2a2a34", "44444f", "6a6a7a")

    def make(f):
        img = canvas(w, h)
        jump = [0, -1, 0, -1][f]
        tilt = [0, 1, 0, -1][f]
        shade(img, poly(w, h, [(3, 6), (16, 6), (18, 13), (1, 13)]), bake)
        shade(img, ell(w, h, (6, 7, 13, 12)), ramp("a8a294", "d4cfc0", "ece8dc", "fffcf4"), edge_dark=False)
        for k in range(8):
            a = k * math.tau / 8 - 2.0
            dots(img, [(9.5 + math.cos(a) * 2.6, 9.5 + math.sin(a) * 2.2)], hexc("6a6458"))
        dots(img, [(8, 9), (11, 9)], hexc("1a1a22"))
        dots(img, [(8, 11), (9, 10), (10, 10), (11, 11)], hexc("4a4038"))
        handset = mask_wh(w, h, polys=[[(4, 2 + jump + tilt), (15, 2 + jump - tilt), (15, 3 + jump - tilt), (4, 3 + jump + tilt)]],
                          ellipses=[(1, 1 + jump + tilt, 5, 5 + jump + tilt), (14, 1 + jump - tilt, 18, 5 + jump - tilt)])
        part(img, handset, bake, "08080c")
        dots(img, [(18, y) for y in range(8, 13) if y % 2 == 0], hexc("2a2a34"))
        ink(img, hexc("0c0c10"))
        dots(img, [(3, 2 + jump + tilt), (4, 7)], hexc("b0b0c4"))
        if f % 2 == 1:
            dots(img, [(0, 7), (19, 7), (0, 10), (19, 10)], hexc("fff0a0", 200))
        return img
    return sheet(w, h, 4, make)


def maison_vide():
    """La Maison Vide : maison sombre aux volets clos, une seule fenetre allumee ou passe parfois
    une ombre ; la lumiere vacille."""
    w, h = 30, 32
    roof = ramp("1e1020", "3a2038", "5a3454", "7a4c70")
    walls = ramp("2a2834", "484458", "6a6680", "8e8aa8")

    def make(f):
        img = canvas(w, h)
        shade(img, poly(w, h, [(20, 3), (23, 3), (23, 9), (20, 9)]), ramp("2a1e24", "4a3440", "6a4c5c", "8a6a7a"))
        rsolid = shade(img, poly(w, h, [(1, 13), (15, 1), (28, 13)]), roof)
        for x, y in rsolid:
            if y % 3 == 0 and (x + y) % 4 == 0:
                img.putpixel((x, y), roof[0])
        wsolid = shade(img, poly(w, h, [(3, 13), (26, 13), (26, 30), (3, 30)]), walls)
        for x, y in wsolid:
            if y % 3 == 2:
                img.putpixel((x, y), walls[max(0, walls.index(img.getpixel((x, y))) - 1)])
        lit = ["ffd87a", "ffc860", "ffe49a", "ffd070"][f]
        for i, (wx, wy) in enumerate(((6, 16), (19, 16), (6, 23))):
            on = i == 1
            rect(img, wx, wy, wx + 4, wy + 4, hexc(lit if on else "141220"))
            if on:
                rect(img, wx, wy + 3, wx + 4, wy + 4, hexc("e8a850"))
                if f == 2:  # une ombre passe derriere la fenetre
                    dots(img, [(wx + 2, wy + 1), (wx + 2, wy + 2), (wx + 1, wy + 3), (wx + 2, wy + 3), (wx + 3, wy + 3)], hexc("5a3a2a"))
            dots(img, [(wx + 2, wy + k) for k in range(5)] + [(wx + k, wy + 2) for k in range(5)], hexc("2a2234" if not on else "8a5a3a"))
        rect(img, 18, 23, 22, 30, hexc("2a1a18"))
        dots(img, [(21, 27)], hexc("e6c25a"))
        dots(img, [(4, 30), (5, 29), (25, 30), (24, 29), (9, 30)], hexc("3a5a3a"))  # herbes folles
        ink(img, hexc("0e0a14"))
        dots(img, [(14, 2), (13, 3), (12, 4)], hexc("b8a4d0"))
        for k in range(1, 4):  # halo de la fenetre allumee
            dots(img, [(18, 15 + k), (24, 15 + k)], hexc(lit, 90))
        return img
    return sheet(w, h, 4, make)


def absence():
    """L'Absence (2 images d'etat) : une forme pale aux bras ouverts qui se dissout vers le bas ;
    0 froide et vide, 1 la forme chaude d'un etre aime, qui sourit."""
    w, h = 22, 32

    def make(f):
        img = canvas(w, h)
        tones = ramp("6a7aa8", "9aaad4", "c8d4f0", "eef4ff") if f == 0 else ramp("a86a5a", "d4a088", "f0c8b0", "fff0e4")
        shade(img, mask_wh(w, h, polys=[[(8, 10), (13, 10), (17, 29), (4, 29)], [(1, 11), (20, 11), (20, 13), (1, 13)]],
                           ellipses=[(0, 10, 3, 14), (18, 10, 21, 14)]), tones)
        shade(img, ell(w, h, (7, 1, 14, 8)), tones)
        if f == 1:
            dots(img, [(x, 1) for x in range(8, 14)] + [(7, 2), (14, 2), (7, 3), (14, 3), (8, 2), (13, 2)], hexc("6a4030"))
            dots(img, [(9, 5), (12, 5)], hexc("6a3a30"))
            dots(img, [(9, 6), (10, 7), (11, 7), (12, 6)], hexc("a8504a"))
        ink(img, hexc("4a5a8a" if f == 0 else "6a3a30"))
        px = img.load()
        for y in range(22, h):  # le bas se dissout
            for x in range(w):
                if px[x, y][3] and ((x * 7 + y * 3) % 5) < (y - 21) // 2:
                    px[x, y] = (0, 0, 0, 0)
        fade(img, 0.62)
        return img
    return sheet(w, h, 2, make)


# --- Dimanche (Angoisse) -----------------------------------------------------------------------

def compte_a_rebours():
    """Le Compte a rebours : une bombe noire au ventre de cadran (le chiffre s'y affiche), la
    meche qui crepite."""
    w, h = 16, 15
    bomb = ramp("141220", "2a2638", "464058", "6a6280")

    def make(f):
        img = canvas(w, h)
        shade(img, ell(w, h, (1, 3, 14, 13)), bomb)
        shade(img, ell(w, h, (3, 5, 12, 12)), ramp("a8a294", "d4cfc0", "ece8dc", "fffcf4"), edge_dark=False)
        dots(img, [(5, 4), (10, 4)], hexc("f0f0ff"))
        line(img, [(8, 3), (9, 2), (10, 1)], hexc("8a6a4a"))
        ink(img, hexc("0c0a14"))
        spark = [[(11, 0), (10, 0)], [(11, 0), (12, 1), (11, 1)], [(10, 0), (12, 0)], [(11, 0), (11, 1), (12, 0)]][f]
        dots(img, spark, hexc("ffd060"))
        dots(img, [spark[0]], hexc("fff6c0"))
        dots(img, [(3, 6), (4, 5)], hexc("9a92b0"))
        if f in (1, 2):
            dots(img, [(14, 5 + f)], hexc("a8d8ff"))
        return img
    return sheet(w, h, 4, make)


def mains():
    """Les Mains du lundi : une main pale qui sort d'un trou sombre et agrippe le vide."""
    w, h = 14, 13
    skin = ramp("5a5470", "8a84a4", "bab4d0", "e6e2f4")

    def make(f):
        img = canvas(w, h)
        shade(img, ell(w, h, (0, 9, 13, 12)), ramp("0a060e", "140e1a", "1e1626", "2a2034"), edge_dark=False)
        curl = [0, 1, 3, 1][f]  # les doigts s'ouvrent, se replient, agrippent
        hand = canvas(w, h)
        shade(hand, mask_wh(w, h, polys=[[(1, 5), (11, 5), (11, 10), (1, 10)], [(11, 6), (12, 5 + curl // 2), (12, 7), (11, 9)]]), skin)
        for i, x in enumerate((1, 4, 7, 10)):  # quatre doigts separes
            top = (0 if i in (1, 2) else 1) + curl
            for y in range(top, 6):
                hand.putpixel((x, y), skin[2] if y < 4 else skin[1])
                hand.putpixel((x + 1, y), skin[3] if y < 3 else skin[2])
            dots(hand, [(x, top), (x + 1, top)], hexc("9a8aac"))  # ongles
        dots(hand, [(4, 8), (8, 8)], hexc("8a84a4"))
        ink(hand, hexc("1a1424"))
        img.alpha_composite(hand)
        front = canvas(w, h)
        shade(front, mask_wh(w, h, polys=[[(0, 10), (13, 10), (13, 12), (0, 12)]]), ramp("0a060e", "140e1a", "1e1626", "2a2034"), edge_dark=False)
        hole = ell(w, h, (0, 9, 13, 12))
        for y in range(10, 13):
            for x in range(w):
                if hole.getpixel((x, y)) and front.getpixel((x, y))[3]:
                    img.putpixel((x, y), front.getpixel((x, y)))
        dots(img, [(1, 10), (12, 10)], hexc("3a2a4a"))
        return img
    return sheet(w, h, 4, make)


def spirale():
    """La Spirale : un tourbillon violet aux bras qui s'enroulent vers un coeur brillant."""
    size = 22
    tones = ramp("1a0e2e", "3a1e5a", "6a3a96", "b080e0")
    c = (size - 1) / 2

    def make(f):
        img = canvas(size, size)
        for y in range(size):
            for x in range(size):
                d = math.hypot(x - c, y - c)
                if d > c - 0.5:
                    continue
                a = math.atan2(y - c, x - c)
                arm = math.sin(a * 2 + d * 0.7 - f * math.pi / 2) > 0.15
                k = 1.0 - d / c
                t = (1 + min(2, int(k * 3.2))) if arm else 0
                if d > c - 2 and (x + y) % 2:
                    continue  # bord trame, flou
                img.putpixel((x, y), tones[t])
        dots(img, [(10, 10), (11, 10), (10, 11), (11, 11)], hexc("f0dcff"))
        for k in range(3):
            a = f * math.pi / 2 + k * math.tau / 3
            dots(img, [(c + math.cos(a) * 6, c + math.sin(a) * 6)], hexc("e8c8ff"))
        fade(img, 0.94)
        return img
    return sheet(size, size, 4, make)


def ombre_portee():
    """L'Ombre portee : la silhouette du reveur, noire et sans visage, detachee de lui."""
    return player_copy(ramp("06040c", "0e0a1a", "1a1430", "2a2244"), "3a2a5a", eyes="06040c", alpha=0.8)


def dimanche_soir():
    """Le Dimanche Soir : une bete crepusculaire, un soleil couchant et une ville sur le dos ;
    les rayons tournent, les yeux clignent."""
    w, h = 32, 22
    dusk = [hexc("2a1840"), hexc("5a2a5a"), hexc("a8485a"), hexc("e8885a")]
    sun = ramp("c24a2a", "f08a3a", "ffc060", "fff0b0")

    def make(f):
        img = canvas(w, h)
        for k in range(8):  # rayons
            a = math.pi + k * math.pi / 7 + f * 0.11
            for r in (7.5, 8.5):
                dots(img, [(15.5 + math.cos(a) * r, 8 + math.sin(a) * r)], hexc("ffd27a", 170 if r < 8 else 110))
        sunm = ell(w, h, (10, 2, 21, 13))
        shade(img, sunm, sun, edge_dark=False)
        for x in (5, 26):
            dots(img, [(x, 19), (x, 20)], hexc("1e1030"))
        body = ell(w, h, (1, 9, 30, 20))
        for y in range(h):
            for x in range(w):
                if body.getpixel((x, y)):
                    img.putpixel((x, y), dusk[3 - min(3, (y - 9) // 3)])
        for x, top in ((9, 8), (10, 8), (11, 7), (12, 7), (13, 9), (17, 8), (18, 6), (19, 6), (20, 8), (22, 9)):
            rect(img, x, top, x, 10, hexc("1e1030"))  # la ville sur le dos
        dots(img, [(11, 8), (19, 7)], hexc("ffe6a0"))
        blink = f == 3
        for ex in (9, 20):
            if blink:
                dots(img, [(ex, 14), (ex + 1, 14), (ex + 2, 14)], hexc("2a1030"))
            else:
                dots(img, [(ex, 14), (ex + 1, 14), (ex + 2, 14), (ex + 1, 13)], hexc("ffe6a0"))
                dots(img, [(ex + 1, 14)], hexc("2a1030"))
        dots(img, [(13, 17), (14, 18), (15, 18), (16, 18), (17, 18), (18, 17)], hexc("1e1030"))
        dots(img, [(14, 17), (17, 17)], hexc("f0e0d0"))
        ink(img, hexc("120a1a"))
        dots(img, [(12, 4), (13, 3)], hexc("ffffff"))
        return img
    return sheet(w, h, 4, make)


def liste_lendemain():
    """La Liste du Lendemain : un parchemin de taches aux cases vides et aux yeux inquiets ; il se
    deroule et la liste s'allonge."""
    w, h = 20, 19
    parch = ramp("a8946a", "d8c49a", "f0e2bc", "fff6dc")
    roll = ramp("5a3a1e", "8a5a30", "b88050", "e0b078")

    def make(f):
        img = canvas(w, h)
        down = [0, 1, 2, 1][f]
        paper = shade(img, poly(w, h, [(2, 3), (17, 3), (17, 14 + down), (2, 14 + down)]), parch)
        shade(img, ell(w, h, (1, 1, 18, 3)), roll, light=(0, -1))
        shade(img, ell(w, h, (1, 14 + down, 18, 16 + down)), roll, light=(0, -1))
        dots(img, [(5, 5), (6, 5), (13, 5), (14, 5)], hexc("fff6ec"))
        dots(img, [(6, 5), (13, 5)], hexc("2a1a10"))
        dots(img, [(5, 4), (6, 4), (13, 4), (14, 4)], hexc("7a5a3a"))
        words = [[3, 4, 2], [5, 3], [2, 6], [4, 2, 2], [3, 4]]  # des mots, pas une grille
        for y, lens in zip((7, 9, 11, 13, 15), words):
            if y >= 14 + down:
                break
            dots(img, [(3, y), (4, y)], hexc("8a6a4a"))  # la case vide
            x = 6
            for n in lens:
                dots(img, [(x + k, y) for k in range(n) if (x + k, y) in paper], hexc("5a4a3a"))
                x += n + 1
        ink(img, hexc("2a1e10"))
        dots(img, [(3, 1), (4, 1)], hexc("fff0c8"))
        return img
    return sheet(w, h, 4, make)


def coeur_qui_bat():
    """Le Coeur qui Bat : un coeur geant aux veines sombres, deux arteres en haut, des yeux
    affoles ; il bat."""
    w = h = 30
    red = ramp("4a0818", "8a1630", "c42a48", "f06a80")
    # Veines sur les cotes, loin du visage.
    veins = [[(6, 9), (5, 13), (6, 17), (8, 20)], [(5, 13), (3, 15)], [(23, 8), (24, 12), (22, 16), (20, 21)],
             [(24, 12), (26, 14)], [(12, 22), (14, 25)]]

    def make(f):
        img = canvas(w, h)
        s = [10.5, 11.3, 10.1, 10.5][f]
        for x0, tones in ((11, ramp("3a2a5a", "5a4a8a", "7a6aac", "a898d0")), (17, ramp("5a0a18", "8a1630", "b8203a", "e05a70"))):
            part(img, poly(w, h, [(x0, 1), (x0 + 3, 1), (x0 + 3, 7), (x0, 7)]), tones, "2a040e", light=(-1, 0))
        solid = shade(img, heart_mask(w, h, 14.5, 15, s), red)
        for pts in veins:
            sc = [(14.5 + (x - 14.5) * s / 10.5, 15 + (y - 15) * s / 10.5) for x, y in pts]
            for a, b in zip(sc, sc[1:]):
                layer = canvas(w, h)
                line(layer, [a, b], hexc("5a0a1e"))
                for y in range(h):
                    for x in range(w):
                        if layer.getpixel((x, y))[3] and (x, y) in solid:
                            img.putpixel((x, y), hexc("5a0a1e"))
        for ex in (10, 18):
            dots(img, [(ex, 13), (ex + 1, 13), (ex, 14), (ex + 1, 14)], hexc("fff0f0"))
            dots(img, [(ex + (f % 2), 14)], hexc("1a0408"))
        dots(img, [(13, 19), (14, 18), (15, 18), (16, 19)], hexc("2a040e"))
        ink(img, hexc("2a040e"))
        dots(img, [(6, 7), (7, 6), (6, 8), (8, 6)], hexc("ffd0d8"))
        return img
    return sheet(w, h, 4, make)


def derniere_nuit():
    """La Derniere Nuit : un immense croissant de nuit seme d'etoiles, constelle d'yeux qui
    s'ouvrent et se ferment tour a tour."""
    w, h = 36, 40
    night = ramp("06040e", "120c22", "22183a", "3a2a5a")
    rng = random.Random(9)
    eyes, stars = [], []
    crescent = lambda x, y: (x - 18) ** 2 + (y - 20) ** 2 <= 17 ** 2 and (x - 25) ** 2 + (y - 16) ** 2 > 14 ** 2
    while len(eyes) < 9:
        ex, ey = rng.randrange(3, 22), rng.randrange(6, 36)
        if all(crescent(ex + dx, ey + dy) for dx in (-1, 0, 2, 3) for dy in (-1, 0, 2)) and all(abs(ex - a) + abs(ey - b) > 4 for a, b in eyes):
            eyes.append((ex, ey))
    while len(stars) < 14:
        sx, sy = rng.randrange(2, 30), rng.randrange(3, 38)
        if crescent(sx, sy):
            stars.append((sx, sy))

    def make(f):
        img = canvas(w, h)
        mask = Image.new("L", (w, h), 0)
        for y in range(h):
            for x in range(w):
                if crescent(x, y):
                    mask.putpixel((x, y), 255)
        solid = shade(img, mask, night, light=(0.7, -0.5))
        for x, y in solid:  # le bord interieur, eclaire par une lune absente
            if (x + 1, y) not in solid and (x - 25) ** 2 + (y - 16) ** 2 <= 15.5 ** 2:
                img.putpixel((x, y), hexc("6a5a9a"))
        dots(img, [s for i, s in enumerate(stars) if (i + f) % 3], hexc("c8b8ff"))
        for i, (ex, ey) in enumerate(eyes):
            if (i + f) % 4 == 0:
                dots(img, [(ex, ey), (ex + 1, ey), (ex + 2, ey)], hexc("8a78b8"))
            else:
                dots(img, [(ex, ey), (ex + 1, ey), (ex + 2, ey), (ex + 1, ey - 1), (ex + 1, ey + 1)], hexc("fff0c0"))
                dots(img, [(ex + 1, ey)], hexc("2a0a1a"))
        ink(img, hexc("4a3a7a"))
        return img
    return sheet(w, h, 4, make)


WEEK = {
    "mardi": {"trotteuse": trotteuse, "pile_devoirs": pile_devoirs, "stylo_rouge": stylo_rouge,
              "battement": battement, "tableau_noir": tableau_noir, "cloche": cloche,
              "horloge_classe": horloge_classe, "examen": examen},
    "mercredi": {"reflet": reflet, "autre_soi": autre_soi, "pile_ou_face": pile_ou_face, "carrefour": carrefour,
                 "masque": masque, "miroir_brise": miroir_brise, "labyrinthe": labyrinthe, "deux_voies": deux_voies},
    "jeudi": {"grogne": grogne, "porte_close": porte_close, "ressort": ressort, "cocotte": cocotte,
              "patron": patron, "tapis_roulant": tapis_roulant, "mur": mur, "colere": colere},
    "vendredi": {"fardeau": fardeau, "passager": passager, "sangsue": sangsue, "soignant": soignant,
                 "bougie_fondue": bougie_fondue, "oeuf": oeuf, "atlas": atlas, "nid": nid,
                 "balancier": balancier, "poids_du_monde": poids_du_monde},
    "samedi": {"silhouette": silhouette, "chaise": chaise, "lettre": lettre, "echo": echo,
               "telephone": telephone, "maison_vide": maison_vide, "absence": absence},
    "dimanche": {"compte_a_rebours": compte_a_rebours, "mains": mains, "spirale": spirale,
                 "ombre_portee": ombre_portee, "dimanche_soir": dimanche_soir,
                 "liste_lendemain": liste_lendemain, "coeur_qui_bat": coeur_qui_bat,
                 "derniere_nuit": derniere_nuit},
}
