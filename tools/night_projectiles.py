"""Projectiles des nuits (mardi a dimanche), en pixel art modele et anime sur 4 images.

Utilise par tools/gen_projectiles.py (meme sortie : assets/sprites/projectiles/<nuit>/<mob>.png).
Chaque projectile garde le sujet de l'ancien (feuille, craie, eclat de miroir...), mais avec du
volume, un contour d'encre colore, des reflets et une petite animation.
Les projectiles "aim" pointent vers la droite (le jeu les tourne dans leur direction).
"""
import math

from proj_art import blank, dots, hexc, ink, mask_of, ramp, rot, shade, strip

F = 4


# --- Mardi (Stress : l'ecole, les devoirs, l'heure) -----------------------------------------------

def pile_devoirs():
    """Une copie qui volette : le coin se corne, les lignes d'ecriture, la note rouge."""
    size = 16
    paper = ramp("8f8a9e", "c9c3d6", "efeaf4", "ffffff")

    def make(f):
        img = blank(size)
        skew = [0, 1, 0, -1][f]
        corner = [3, 4, 2, 3][f]
        poly = [(3, 2 + skew), (12, 2 - skew), (12, 13 - corner), (12 - corner, 13), (3, 13 + skew)]
        shade(img, mask_of(size, [poly]), paper)
        for y in (5, 7, 9):  # lignes d'ecriture
            dots(img, [(x, y + (skew if x < 8 else -skew) // 2) for x in range(5, 11)], hexc("7f95c9"))
        dots(img, [(9, 10), (10, 11), (11, 9)], hexc("d8464f"))  # coche rouge
        dots(img, [(12 - corner + i, 13 - i) for i in range(corner)], hexc("b7b0c6"))  # pli du coin
        ink(img, hexc("2e2a48"))
        return img
    return strip(size, F, make)


def tableau_noir():
    """Un baton de craie qui file, une poussiere blanche derriere lui."""
    size = 16

    def make(f):
        img = blank(size)
        stick = [(5, 6), (14, 6), (14, 9), (5, 9)]
        shade(img, mask_of(size, [stick]), ramp("a49c8c", "d9d2c2", "f3efe4", "ffffff"), light=(0, -1))
        dots(img, [(13, 7), (13, 8)], hexc("ffffff"))
        ink(img, hexc("3b3a4a"))
        for i in range(3):  # poussiere de craie qui reste en arriere
            x = 3 - ((f + i * 2) % 4)
            y = 5 + (i * 3 + f) % 6
            dots(img, [(x, y)], hexc("f4f1e8", 200 - i * 40))
        return img
    return strip(size, F, make)


def horloge_classe():
    """Un rouage de laiton qui tourne (les dents avancent d'un cran par image)."""
    size = 14
    brass = ramp("6e4a1c", "b07a2e", "e2b04e", "fde39a")

    def make(f):
        img = blank(size)
        teeth = []
        for i in range(8):
            a = i * math.pi / 4 + f * math.pi / 16
            tooth = rot([(9.5, 5.8), (13, 5.8), (13, 8.2), (9.5, 8.2)], a, 7, 7)
            teeth.append(tooth)
        m = mask_of(size, teeth, [(3, 3, 11, 11)])
        shade(img, m, brass)
        for x in range(size):  # le trou du milieu
            for y in range(size):
                if (x - 7) ** 2 + (y - 7) ** 2 <= 2.2:
                    img.putpixel((x, y), (0, 0, 0, 0))
        ink(img, hexc("3d2812"))
        dots(img, [(5, 4)], hexc("fff6d0"))
        return img
    return strip(size, F, make)


# --- Mercredi (Doute : miroirs, chemins, pile ou face) ---------------------------------------------

def carrefour():
    """Une fleche de panneau en bois qui file, un clou qui brille."""
    size = 16

    def make(f):
        img = blank(size)
        bob = [0, 0, 1, 1][f]
        arrow = [(2, 6 + bob), (10, 6 + bob), (10, 4 + bob), (14, 8 + bob), (10, 12 + bob), (10, 10 + bob), (2, 10 + bob)]
        shade(img, mask_of(size, [arrow]), ramp("5c3a22", "8f5f37", "c18a55", "e6b884"), light=(0, -1))
        dots(img, [(x, 8 + bob) for x in range(3, 10, 2)], hexc("8f5f37"))  # veines du bois
        dots(img, [(4, 7 + bob)], hexc("ffffff") if f % 2 == 0 else hexc("d9d6e6"))  # le clou
        ink(img, hexc("2e1c10"))
        return img
    return strip(size, F, make)


def deux_voies():
    """Un point d'interrogation qui flotte et luit doucement."""
    size = 16
    lilac = ramp("4b3a86", "7e68c8", "b49cf0", "ece2ff")

    def make(f):
        img = blank(size)
        bob = [0, -1, 0, 1][f]
        hook = [(4, 4 + bob), (6, 2 + bob), (10, 2 + bob), (12, 4 + bob), (12, 7 + bob), (9, 9 + bob),
                (9, 11 + bob), (7, 11 + bob), (7, 8 + bob), (10, 6 + bob), (10, 5 + bob), (9, 4 + bob),
                (7, 4 + bob), (6, 6 + bob), (4, 6 + bob)]
        m = mask_of(size, [hook], [(7, 12 + bob, 9, 14 + bob)])
        shade(img, m, lilac)
        ink(img, hexc("2a1f52"))
        if f in (1, 2):
            dots(img, [(2, 2 + bob), (13, 12 + bob)], hexc("ece2ff", 180))
        return img
    return strip(size, F, make)


def labyrinthe():
    """Une pierre du labyrinthe, mousse sur le dessus, une poussiere qui s'en detache."""
    size = 14

    def make(f):
        img = blank(size)
        stone = [(3, 4), (7, 2), (11, 3), (12, 8), (9, 12), (4, 11), (2, 8)]
        shade(img, mask_of(size, [stone]), ramp("3e4344", "6b7272", "9aa19c", "c9cec6"))
        dots(img, [(5, 3), (6, 3), (7, 3), (8, 3), (4, 4), (9, 4)], hexc("6fae5a"))  # mousse
        dots(img, [(6, 3), (8, 4)], hexc("a3d977"))
        dots(img, [(8, 7), (9, 8), (6, 9)], hexc("4f5656"))  # fissures
        ink(img, hexc("1f2324"))
        dots(img, [(12 - f, 12 + (f % 2))], hexc("9aa19c", 170))
        return img
    return strip(size, F, make)


def masque():
    """Une larme du masque triste : la tete ronde devant, la pointe derriere, un reflet qui glisse."""
    size = 16
    water = ramp("2d4f8f", "4f86d0", "8cc0f2", "e4f4ff")

    def make(f):
        img = blank(size)
        drop = [(2, 8), (8, 4), (11, 4), (14, 6), (14, 10), (11, 12), (8, 12)]
        shade(img, mask_of(size, [drop]), water, light=(0.3, -1))
        ink(img, hexc("1b2f5a"))
        glint = [(11, 6), (10, 6), (8, 7), (6, 8)][f]
        dots(img, [glint], hexc("ffffff"))
        return img
    return strip(size, F, make)


def miroir_brise():
    """Un eclat de miroir effile ; un reflet le parcourt de la pointe au talon."""
    size = 16
    glass = ramp("4a6f9a", "86b0d8", "c4e2f6", "ffffff")

    def make(f):
        img = blank(size)
        shard = [(1, 9), (7, 5), (15, 7), (8, 11)]
        shade(img, mask_of(size, [shard]), glass, light=(0, -1))
        dots(img, [(7, 6), (8, 6), (9, 7)], hexc("ffffff"))
        sweep = [3, 6, 9, 12][f]
        dots(img, [(sweep, 8), (sweep + 1, 7)], hexc("ffffff"))
        ink(img, hexc("253b5c"))
        return img
    return strip(size, F, make)


def pile_ou_face():
    """Une piece qui tourne sur elle-meme (de face, de biais, de profil, de biais)."""
    size = 14
    gold = ramp("7a4f12", "c48a24", "f0c34a", "fff0a8")

    def make(f):
        img = blank(size)
        half = [5, 3, 1, 3][f]
        m = mask_of(size, [], [(7 - half, 2, 7 + half, 12)])
        shade(img, m, gold)
        if half >= 3:
            dots(img, [(7, 5), (7, 6), (7, 7), (6, 8), (8, 8)] if f == 0 else [(7, 6), (7, 7)], hexc("9c6a1a"))
        ink(img, hexc("3a240a"))
        dots(img, [(7 - half + 1, 4)], hexc("ffffff"))
        return img
    return strip(size, F, make)


# --- Jeudi (Frustration : le travail, la colere) ---------------------------------------------------

def colere():
    """Un eclair qui crepite : sa forme change un peu a chaque image, des etincelles l'entourent."""
    size = 16
    bolt = ramp("8a5a08", "e0a21e", "ffe066", "ffffff")

    def make(f):
        img = blank(size)
        jitter = [0, 1, -1, 0][f]
        zig = [(1, 7), (6, 4 + jitter), (8, 6), (15, 3), (10, 9 - jitter), (8, 8), (2, 11)]
        shade(img, mask_of(size, [zig]), bolt, light=(0, -1))
        ink(img, hexc("3a2402"))
        sparks = [[(3, 3), (13, 12)], [(12, 1), (4, 13)], [(14, 8), (1, 4)], [(6, 13), (11, 1)]][f]
        dots(img, sparks, hexc("fff3a6"))
        return img
    return strip(size, F, make)


def mur():
    """Une brique qui tourne et s'effrite (des miettes s'en echappent)."""
    size = 14

    def make(f):
        img = blank(size)
        brick = [(2, 4), (12, 4), (12, 10), (2, 10)]
        shade(img, mask_of(size, [brick]), ramp("4e1f15", "8a3a26", "b8553a", "e08a68"))
        dots(img, [(5, 6), (9, 8), (4, 8)], hexc("5e2619"))  # trous
        dots(img, [(3, 5), (4, 5)], hexc("f2b597"))
        ink(img, hexc("2a0f09"))
        crumbs = [[(13, 11)], [(13, 12), (1, 12)], [(12, 13)], [(0, 11)]][f]
        dots(img, crumbs, hexc("b8553a"))
        return img
    return strip(size, F, make)


def tapis_roulant():
    """Un ecrou d'acier qui tourne ; un eclat de lumiere fait le tour."""
    size = 14
    steel = ramp("3c4250", "6c7488", "a6aec0", "e6ebf4")

    def make(f):
        img = blank(size)
        hexa = [(7 + 5.5 * math.cos(a), 7 + 5.5 * math.sin(a)) for a in [i * math.pi / 3 + f * math.pi / 12 for i in range(6)]]
        shade(img, mask_of(size, [hexa]), steel)
        for x in range(size):
            for y in range(size):
                if (x - 7) ** 2 + (y - 7) ** 2 <= 4:
                    img.putpixel((x, y), (0, 0, 0, 0))
        ink(img, hexc("1c2028"))
        glint = rot([(10, 4)], f * math.pi / 2, 7, 7)[0]
        dots(img, [glint], hexc("ffffff"))
        return img
    return strip(size, F, make)


# --- Vendredi (Epuisement : porter les autres) -----------------------------------------------------

def bougie_fondue():
    """Une goutte de cire en feu : la flamme devant, la cire qui s'etire derriere."""
    size = 16

    def make(f):
        img = blank(size)
        stretch = [0, 1, 2, 1][f]
        wax = [(1 - stretch, 8), (6, 6), (9, 7), (9, 9), (6, 10)]
        shade(img, mask_of(size, [wax]), ramp("9c8a6a", "d9c9a2", "f3e7c8", "fffaf0"), light=(0, -1))
        flame = [(8, 8), (11, 4 + (f % 2)), (15, 8), (11, 12 - (f % 2))]
        shade(img, mask_of(size, [flame]), ramp("b3301c", "f07a2a", "ffc24a", "fff4c4"), light=(1, 0))
        ink(img, hexc("4a1a0c"))
        dots(img, [(12, 8)], hexc("ffffff"))
        return img
    return strip(size, F, make)


def nid():
    """Une plume du nid : la tige, les barbes qui ondulent."""
    size = 16
    down = ramp("6a5a8a", "a796c6", "d6cbea", "fbf8ff")

    def make(f):
        img = blank(size)
        wave = [0, 1, 0, -1][f]
        vane = [(2, 8), (5, 5 + wave), (12, 5), (15, 8), (12, 11), (5, 11 - wave)]
        shade(img, mask_of(size, [vane]), down, light=(0, -1))
        for x in range(4, 13, 2):  # les barbes, en biais vers l'arriere
            dots(img, [(x, 7), (x - 1, 6 + (wave if x < 8 else 0))], hexc("a796c6"))
            dots(img, [(x, 9), (x - 1, 10 - (wave if x < 8 else 0))], hexc("8a7aaa"))
        dots(img, [(x, 8) for x in range(1, 15)], hexc("6a5a8a"))  # la tige
        dots(img, [(6, 6 + wave), (11, 6)], hexc("fbf8ff"))
        ink(img, hexc("2f2548"))
        return img
    return strip(size, F, make)


# --- Samedi (Solitude : ceux qui sont loin, ceux qui sont partis) ---------------------------------

def absence():
    """Un coeur pale, recousu, qui bat faiblement."""
    size = 16
    pink = ramp("9a4a62", "d77a95", "f3b4c4", "fff0f4")

    def make(f):
        img = blank(size)
        k = [1.0, 1.08, 1.0, 0.94][f]
        cx, cy = 8, 8

        def p(x, y):
            return (cx + (x - cx) * k, cy + (y - cy) * k)
        heart = [p(8, 13), p(2, 7), p(2, 4), p(5, 2), p(8, 4), p(11, 2), p(14, 4), p(14, 7)]
        shade(img, mask_of(size, [heart]), pink)
        dots(img, [(8, 5), (8, 7), (8, 9), (7, 6), (9, 6), (7, 8), (9, 8)], hexc("8a3a52"))  # couture
        ink(img, hexc("4a1a2c"))
        dots(img, [(4, 4)], hexc("ffffff"))
        return img
    return strip(size, F, make)


def foule_lointaine():
    """Une photo souvenir qui volette : un cadre blanc, une silhouette au loin."""
    size = 16

    def make(f):
        img = blank(size)
        tilt = [0, 1, 0, -1][f]
        frame = [(2, 2 + tilt), (13, 2 - tilt), (13, 14 - tilt), (2, 14 + tilt)]
        shade(img, mask_of(size, [frame]), ramp("8e8a9a", "cfcad8", "f1eef6", "ffffff"))
        for x in range(4, 12):  # le ciel de la photo
            for y in range(4, 10):
                img.putpixel((x, y), hexc("9cb4e8") if y < 7 else hexc("c9b8e6"))
        dots(img, [(8, 5), (7, 6), (8, 6), (9, 6), (6, 8), (7, 7), (8, 7), (9, 7), (10, 8), (7, 8), (8, 8), (9, 8),
                   (7, 9), (8, 9), (9, 9)], hexc("3c3460"))  # quelqu'un, au loin : la tete, les epaules
        ink(img, hexc("2c2838"))
        return img
    return strip(size, F, make)


def lettre():
    """Un avion de papier : les ailes battent un peu, un pli au milieu."""
    size = 16
    paper = ramp("8f8a9e", "cbc6d8", "f2eff8", "ffffff")

    def make(f):
        img = blank(size)
        flap = [0, 1, 2, 1][f]
        wing_top = [(1, 3 + flap), (15, 8), (6, 8)]
        wing_low = [(1, 13 - flap), (15, 8), (6, 8)]
        shade(img, mask_of(size, [wing_top]), paper, light=(0, -1))
        shade(img, mask_of(size, [wing_low]), [paper[0], paper[0], paper[1], paper[2]], light=(0, -1))
        dots(img, [(x, 8) for x in range(5, 15)], hexc("9a94b0"))
        ink(img, hexc("2c2838"))
        return img
    return strip(size, F, make)


def maison_vide():
    """Un papillon de nuit sorti de la maison vide : ses ailes battent (ouvertes, a demi, fermees)."""
    size = 16
    wing = ramp("5e4a32", "9c8460", "d4bf94", "f2e6c6")

    def make(f):
        img = blank(size)
        spread = [6, 4, 1, 4][f]
        left = [(8, 7), (8 - spread, 3), (8 - spread - 1, 7), (8 - spread, 12), (8, 9)]
        right = [(8, 7), (8 + spread, 3), (8 + spread + 1, 7), (8 + spread, 12), (8, 9)]
        shade(img, mask_of(size, [left, right]), wing)
        body = mask_of(size, [], [(7, 4, 9, 12)])
        shade(img, body, ramp("2c2216", "4a3a26", "6a563a", "8a7452"))
        if spread >= 4:
            dots(img, [(8 - spread + 2, 6), (8 + spread - 2, 6)], hexc("5e4a32"))  # yeux des ailes
        dots(img, [(7, 3), (9, 3)], hexc("4a3a26"))  # antennes
        ink(img, hexc("241a10"))
        return img
    return strip(size, F, make)


def silhouette():
    """Un souvenir : une etincelle a quatre branches qui scintille, un reste de lueur autour."""
    size = 15
    glow = ramp("6b72b8", "a7b0ee", "dfe4ff", "ffffff")

    def make(f):
        img = blank(size)
        arm = [5, 6, 4, 6][f]
        star = [(7, 7 - arm), (8, 6), (7 + arm, 7), (8, 8), (7, 7 + arm), (6, 8), (7 - arm, 7), (6, 6)]
        shade(img, mask_of(size, [star]), glow)
        ink(img, hexc("2c2f5c"))
        dots(img, [(7, 7)], hexc("ffffff"))
        halo = [[(3, 3), (11, 11)], [(11, 3), (3, 11)], [(2, 7), (12, 7)], [(7, 2), (7, 12)]][f]
        dots(img, halo, hexc("dfe4ff", 160))
        return img
    return strip(size, F, make)


# --- Dimanche (Angoisse : le soir qui tombe, le lendemain) ----------------------------------------

def derniere_nuit():
    """Un croissant de lune qui tourne, une etoile qui s'allume et s'eteint a cote."""
    size = 15
    moon = ramp("7a6a3a", "c9b46a", "f0e2a2", "fffbe0")

    def make(f):
        img = blank(size)
        full = mask_of(size, [], [(2, 2, 12, 12)])
        cut = mask_of(size, [], [(5, 0, 15, 10)])
        for x in range(size):
            for y in range(size):
                if cut.getpixel((x, y)):
                    full.putpixel((x, y), 0)
        shade(img, full, moon)
        ink(img, hexc("2e2810"))
        if f in (1, 2):
            dots(img, [(12, 11), (11, 12), (13, 12), (12, 13)] if f == 1 else [(12, 12)], hexc("fff6c0"))
        return img
    return strip(size, F, make)


def coeur_qui_bat():
    """Un coeur affole : il bat (gros, petit) et une onde rouge s'en echappe."""
    size = 16
    red = ramp("5a0e1c", "a0182e", "dc3a4c", "ff9aa4")

    def make(f):
        img = blank(size)
        k = [1.12, 0.92, 1.05, 0.92][f]
        cx, cy = 8, 8

        def p(x, y):
            return (cx + (x - cx) * k, cy + (y - cy) * k)
        heart = [p(8, 13), p(2, 7), p(2, 4), p(5, 2), p(8, 4), p(11, 2), p(14, 4), p(14, 7)]
        shade(img, mask_of(size, [heart]), red)
        ink(img, hexc("2a0610"))
        dots(img, [(5, 4)], hexc("ffffff"))
        if f == 0:  # l'onde du battement
            dots(img, [(1, 1), (14, 1), (0, 8), (15, 8)], hexc("ff9aa4", 170))
        return img
    return strip(size, F, make)


SETS = {
    "mardi": {"pile_devoirs": pile_devoirs, "tableau_noir": tableau_noir, "horloge_classe": horloge_classe},
    "mercredi": {"carrefour": carrefour, "deux_voies": deux_voies, "labyrinthe": labyrinthe, "masque": masque,
                 "miroir_brise": miroir_brise, "pile_ou_face": pile_ou_face},
    "jeudi": {"colere": colere, "mur": mur, "tapis_roulant": tapis_roulant},
    "vendredi": {"bougie_fondue": bougie_fondue, "nid": nid},
    "samedi": {"absence": absence, "foule_lointaine": foule_lointaine, "lettre": lettre, "maison_vide": maison_vide,
               "silhouette": silhouette},
    "dimanche": {"derniere_nuit": derniere_nuit, "coeur_qui_bat": coeur_qui_bat},
}
