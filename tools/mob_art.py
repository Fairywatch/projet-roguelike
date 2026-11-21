"""Creatures redessinees (pixel art modele, 4 images d'animation), nuit par nuit.

Lancer depuis la racine du projet : python tools/mob_art.py
Ecrit assets/sprites/mobs/<nuit>/<creature>.png (bande d'images ; leur nombre est dans
scripts/visual/mob_frames.gd). Remplace les sprites de tools/gen_pixel_art.py pour les creatures
listees ici (gen_pixel_art.py relance ce script a la fin pour ne pas les ecraser).
Direction artistique : volume (lumiere en haut a gauche, 4 tons), contour d'encre colore, reflets,
petite animation (respire, bat, tremble). Meme echelle qu'avant (affiche x2).
"""
import math
import os

from PIL import Image

from proj_art import blank, dots, hexc, ink, mask_of, ramp, shade

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "mobs")


def sheet(w, h, frames, make):
    out = Image.new("RGBA", (w * frames, h), (0, 0, 0, 0))
    for f in range(frames):
        out.alpha_composite(make(f), (f * w, 0))
    return out


def canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def mask_wh(w, h, polys=(), ellipses=()):
    """Comme mask_of, pour une image rectangulaire."""
    from PIL import ImageDraw
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    for p in polys:
        d.polygon([(round(x), round(y)) for x, y in p], fill=255)
    for e in ellipses:
        d.ellipse([round(v) for v in e], fill=255)
    return m


def clear(img, pts):
    for x, y in pts:
        if 0 <= x < img.width and 0 <= y < img.height:
            img.putpixel((x, y), (0, 0, 0, 0))


# --- Lundi (Fatigue) ---------------------------------------------------------------------------

def mouton():
    """Mouton insomniaque : laine en bosses qui respire, tete sombre aux paupieres lourdes et aux
    cernes, pattes qui pietinent."""
    w, h = 24, 17
    wool = ramp("8a7fae", "bfb7dc", "e9e5f6", "ffffff")
    head = ramp("2a2236", "463b58", "64587a", "857aa0")

    def make(f):
        img = canvas(w, h)
        b = [0, 0.5, 1, 0.5][f]
        bob = [0, 0, -1, 0][f]
        # Chaque bouclette est modelee a part (de l'arriere vers l'avant) : on voit les bosses.
        puffs = [(3, 7 + bob, 18, 14 + bob), (1, 8 + bob, 7, 14 + bob), (3, 4 + bob, 10 + b, 11 + bob + b),
                 (13, 3 + bob, 19, 10 + bob), (6, 1 + bob, 13 + b, 8 + bob + b), (10, 1 + bob, 16 + b, 7 + bob + b)]
        for puff in puffs:
            shade(img, mask_wh(w, h, ellipses=[puff]), wool)
            cx, cy = (puff[0] + puff[2]) // 2, (puff[1] + puff[3]) // 2
            dots(img, [(cx + 1, puff[3] - 1), (cx + 2, puff[3] - 1)], wool[0])  # le creux sous la bouclette
        legs = [[(6, 0), (9, 1), (14, 0), (17, 1)], [(6, 1), (9, 0), (14, 1), (17, 0)]][f % 2]
        for x, lift in legs:
            for y in range(14 + bob, 16 - lift):
                img.putpixel((x, y), hexc("3a3048"))
        face = mask_wh(w, h, ellipses=[(16, 5 + bob, 23, 13 + bob)])
        shade(img, face, head)
        dots(img, [(17, 5 + bob)], hexc("3a3048"))  # oreille
        dots(img, [(19, 8 + bob), (20, 8 + bob), (21, 8 + bob)], hexc("cfc6ea"))  # paupiere lourde
        dots(img, [(20, 9 + bob)], hexc("f4f0ff"))  # l'oeil qui ne se ferme pas
        dots(img, [(19, 10 + bob), (20, 10 + bob)], hexc("b06a88"))  # cernes
        dots(img, [(22, 11 + bob)], hexc("8a7a9a"))
        ink(img, hexc("261d34"))
        dots(img, [(7, 3 + bob), (8, 3 + bob), (11, 2 + bob)], hexc("ffffff"))
        return img
    return sheet(w, h, 4, make)


def bailleur():
    """Le Bailleur : un petit nuage endormi qui baille de plus en plus grand."""
    w, h = 24, 20
    cloud = ramp("7d78b0", "b3aee0", "e2dff6", "ffffff")

    def make(f):
        img = canvas(w, h)
        bob = [0, -1, -1, 0][f]
        body = [(2, 4 + bob, 22, 17 + bob), (5, 1 + bob, 14, 9 + bob), (11, 2 + bob, 20, 10 + bob),
                (1, 12 + bob, 8, 19 + bob), (9, 13 + bob, 16, 19 + bob), (16, 12 + bob, 23, 19 + bob)]
        shade(img, mask_wh(w, h, ellipses=body), cloud)
        for x in (7, 8):  # yeux fermes, arques
            dots(img, [(x, 8 + bob)], hexc("4a4070"))
        dots(img, [(6, 7 + bob), (9, 7 + bob)], hexc("4a4070"))
        for x in (15, 16):
            dots(img, [(x, 8 + bob)], hexc("4a4070"))
        dots(img, [(14, 7 + bob), (17, 7 + bob)], hexc("4a4070"))
        mouth_h = [2, 3, 5, 3][f]
        mouth = mask_wh(w, h, ellipses=[(9, 10 + bob, 14, 10 + bob + mouth_h)])
        for y in range(h):
            for x in range(w):
                if mouth.getpixel((x, y)):
                    img.putpixel((x, y), hexc("5a2038") if y < 10 + bob + mouth_h - 1 else hexc("d0607a"))
        if f == 2:
            dots(img, [(5, 9 + bob), (5, 10 + bob)], hexc("a8d8ff"))  # une larme de sommeil
        dots(img, [(4, 11 + bob), (19, 11 + bob)], hexc("f0b4c8"))  # joues
        ink(img, hexc("2e2850"))
        dots(img, [(7, 3 + bob), (8, 3 + bob)], hexc("ffffff"))
        return img
    return sheet(w, h, 4, make)


def veilleuse():
    """La Veilleuse : une ampoule chaude dans un abat-jour en forme de lune ; le halo vacille."""
    w, h = 18, 18
    shell = ramp("4e3f78", "7a68b0", "a898d8", "d6ccf4")
    glow = ramp("c26a2c", "f0a640", "ffd77a", "fff6d6")

    def make(f):
        img = canvas(w, h)
        bob = [0, -1, -1, 0][f]
        for y in range(h):  # halo trame
            for x in range(w):
                d = math.hypot(x - 9, y - 8 - bob)
                if 6.0 < d < 8.6 and (x + y + f) % 3 == 0:
                    img.putpixel((x, y), hexc("ffd77a", 120))
        bulb = mask_wh(w, h, ellipses=[(5, 3 + bob, 13, 11 + bob)])
        shade(img, bulb, glow)
        cap = mask_wh(w, h, polys=[[(4, 9 + bob), (14, 9 + bob), (12, 14 + bob), (6, 14 + bob)]])
        shade(img, cap, shell, light=(0, -1))
        dots(img, [(9, 15 + bob), (9, 16 + bob)], hexc("4e3f78"))  # la petite tige
        dots(img, [(7, 11 + bob), (11, 11 + bob)], hexc("2c2448"))  # yeux endormis sur l'abat-jour
        dots(img, [(8, 12 + bob), (10, 12 + bob)], hexc("2c2448"))
        ink(img, hexc("2c2448"))
        flick = [(8, 6), (7, 6), (8, 5), (9, 6)][f]
        dots(img, [(flick[0], flick[1] + bob)], hexc("ffffff"))
        return img
    return sheet(w, h, 4, make)


def paupiere():
    """La Paupiere (2 images d'etat) : 0 fermee (cils, peau qui frissonne), 1 ouverte (veines)."""
    w, h = 26, 15
    skin = ramp("8a4a5e", "c47a8c", "eab0bc", "fbdfe4")

    def make(f):
        img = canvas(w, h)
        lid = mask_wh(w, h, polys=[[(1, 7), (6, 2), (13, 1), (20, 2), (25, 7), (20, 12), (13, 13), (6, 12)]])
        shade(img, lid, skin)
        if f == 0:  # fermee : une fente et des cils
            dots(img, [(x, 8 + (1 if 8 < x < 18 else 0)) for x in range(4, 23)], hexc("5a2a3a"))
            for x in range(5, 22, 3):
                dots(img, [(x, 10 + (1 if 8 < x < 18 else 0)), (x - 1, 11 + (1 if 8 < x < 18 else 0))], hexc("2a1420"))
        else:  # ouverte : blanc injecte, iris, pupille, reflet
            white = mask_wh(w, h, polys=[[(4, 7), (8, 4), (13, 3), (18, 4), (22, 7), (18, 10), (13, 11), (8, 10)]])
            for y in range(h):
                for x in range(w):
                    if white.getpixel((x, y)):
                        img.putpixel((x, y), hexc("f6f0f2"))
            dots(img, [(6, 6), (7, 7), (19, 6), (20, 8), (8, 9)], hexc("d85a6a"))  # veines
            iris = mask_wh(w, h, ellipses=[(10, 4, 16, 10)])
            shade(img, iris, ramp("1e3a6a", "3a6ab0", "6aa0e0", "b0d8ff"))
            dots(img, [(12, 6), (13, 6), (12, 7), (13, 7)], hexc("0e0a18"))
            dots(img, [(11, 5)], hexc("ffffff"))
        ink(img, hexc("3a1a28"))
        return img
    return sheet(w, h, 2, make)


def grande_couette():
    """La Grande Couette : un patchwork cousu qui ondule, deux yeux qui epient sous le pli."""
    w, h = 50, 28
    patches = [ramp("4a3a7a", "7a64b8", "a890e0", "d4c4f6"), ramp("2e4a7a", "4f78b8", "7ea8e0", "bcd6f6"),
               ramp("7a3a5e", "b8648e", "e090b4", "f6c4dc")]

    def make(f):
        img = canvas(w, h)
        wave = [0, 1, 0, -1][f]
        top = [(2, 9), (8, 6), (16, 5), (25, 4), (34, 5), (42, 6), (48, 9)]
        bottom = [(48, 22 + wave), (41, 25 - wave), (33, 23 + wave), (25, 26 - wave), (17, 23 + wave), (9, 25 - wave), (2, 22 + wave)]
        body = mask_wh(w, h, polys=[top + bottom])
        # Patchwork : chaque carreau sa couleur, puis on modele le tout.
        solid = [(x, y) for y in range(h) for x in range(w) if body.getpixel((x, y))]
        for x, y in solid:
            k = ((x // 8) + (y // 7)) % 3
            depth = (y - 5) / 22.0 - (x - 25) / 80.0
            t = 3 if depth < 0.15 else (2 if depth < 0.55 else (1 if depth < 0.85 else 0))
            img.putpixel((x, y), patches[k][t])
        for x, y in solid:  # coutures entre les carreaux
            if (x % 8 == 0 or y % 7 == 0) and (x + y) % 2 == 0 and body.getpixel((x, y)):
                img.putpixel((x, y), hexc("f4eefc"))
        for x in range(6, 45):  # le pli du haut, plus sombre
            if body.getpixel((x, 9)):
                img.putpixel((x, 9), hexc("3a2c5e"))
        blink = f == 3
        for ex in (19, 30):  # les yeux sous le pli
            if blink:
                dots(img, [(ex, 11), (ex + 1, 11), (ex + 2, 11)], hexc("1a1430"))
            else:
                dots(img, [(ex, 10), (ex + 1, 10), (ex + 2, 10), (ex, 11), (ex + 1, 11), (ex + 2, 11)], hexc("f6f2ff"))
                dots(img, [(ex + 1, 11), (ex + 2, 11)], hexc("1a1430"))
        ink(img, hexc("1e1834"))
        return img
    return sheet(w, h, 4, make)


def reveil_grincheux():
    """Le Reveil Grincheux : boitier rouge, deux cloches, aiguilles en sourcils fronces ; il tremble."""
    w, h = 28, 26
    case = ramp("5a1418", "a82a30", "d8484c", "f48a84")
    bell = ramp("6e4a12", "c0861e", "f0c048", "fff0a0")

    def make(f):
        img = canvas(w, h)
        sx = [-1, 1, -1, 1][f]
        for cx in (7 + sx, 21 + sx):  # cloches
            shade(img, mask_wh(w, h, ellipses=[(cx - 4, 1, cx + 4, 8)]), bell)
        dots(img, [(14 + sx, 2), (14 + sx, 3)], hexc("6e4a12"))  # marteau
        body = mask_wh(w, h, ellipses=[(3 + sx, 5, 25 + sx, 24)])
        shade(img, body, case)
        face = mask_wh(w, h, ellipses=[(7 + sx, 9, 21 + sx, 21)])
        shade(img, face, ramp("b8b0a8", "e0dad2", "f6f2ea", "ffffff"), edge_dark=False)
        c = (14 + sx, 15)
        dots(img, [(c[0] - 4, 12), (c[0] - 3, 13), (c[0] - 2, 13)], hexc("1a1218"))  # sourcils-aiguilles
        dots(img, [(c[0] + 4, 12), (c[0] + 3, 13), (c[0] + 2, 13)], hexc("1a1218"))
        dots(img, [(c[0] - 3, 15), (c[0] + 3, 15)], hexc("1a1218"))  # yeux
        dots(img, [(c[0] - 2, 18), (c[0] - 1, 17), (c[0], 17), (c[0] + 1, 17), (c[0] + 2, 18)], hexc("1a1218"))  # moue
        for x in (6 + sx, 22 + sx):  # pieds
            dots(img, [(x, 24), (x, 25)], hexc("3a1012"))
        ink(img, hexc("2a0a0e"))
        dots(img, [(8 + sx, 9), (9 + sx, 8)], hexc("ffffff"))
        if f % 2 == 0:  # ondes de sonnerie
            dots(img, [(0, 3), (1, 5), (27, 3), (26, 5)], hexc("fff0a0", 200))
        return img
    return sheet(w, h, 4, make)


def choeur_baillements():
    """Le Choeur des Baillements : trois tetes endormies qui baillent a tour de role. Les bouches
    restent a leur place (le jeu s'en sert : MOUTHS dans choeur_baillements.gd)."""
    w, h = 50, 20
    cloud = ramp("6e68a4", "a8a2d8", "dcd8f2", "ffffff")
    mouths = [(11, 16), (25, 10), (39, 16)]

    def make(f):
        img = canvas(w, h)
        for i, (mx, my) in enumerate(mouths):
            bob = 1 if (f + i) % 4 == 0 else 0
            cy = my - 3 + bob
            shade(img, mask_wh(w, h, ellipses=[(mx - 7, cy - 6, mx + 7, min(h - 1, cy + 6))]), cloud)
            dots(img, [(mx - 3, cy - 2), (mx - 2, cy - 1), (mx + 2, cy - 1), (mx + 3, cy - 2)], hexc("3e3868"))
            open_h = [1, 2, 3, 2][(f + i) % 4]
            for y in range(my - 1 + bob, min(h - 1, my - 1 + bob + open_h)):
                for x in range(mx - 2, mx + 3):
                    img.putpixel((x, y), hexc("4a1830"))
            dots(img, [(mx - 1, my + bob)], hexc("d0607a"))
        ink(img, hexc("2a2450"))
        for mx, my in mouths:
            dots(img, [(mx - 4, my - 7)], hexc("ffffff"))
        return img
    return sheet(w, h, 4, make)


def porte_des_voix():
    """La Porte des Voix (2 images d'etat) : 0 close (bois veine, poignee, rai de lumiere dessous) ;
    1 entrouverte (le noir derriere, la lumiere qui deborde, des yeux)."""
    w, h = 28, 46
    wood = ramp("2e1a10", "52321e", "7a4c2c", "a87048")

    def make(f):
        img = canvas(w, h)
        frame = mask_wh(w, h, polys=[[(0, 0), (27, 0), (27, 45), (0, 45)]])
        shade(img, frame, ramp("1a0e08", "2e1a10", "3e2416", "52321e"))
        leaf_x0 = 3 if f == 0 else 9
        leaf = mask_wh(w, h, polys=[[(leaf_x0, 3), (24, 3), (24, 44), (leaf_x0, 44)]])
        if f == 1:  # le noir derriere la porte, la lumiere qui deborde, des yeux
            for y in range(3, 44):
                for x in range(3, leaf_x0):
                    img.putpixel((x, y), hexc("0c0610"))
            for y in range(3, 44):
                img.putpixel((leaf_x0 - 1, y), hexc("ffd77a"))
            dots(img, [(5, 18), (7, 18), (4, 30), (6, 30)], hexc("f6e6a0"))
        shade(img, leaf, wood, light=(-0.4, -1))
        for x in range(leaf_x0 + 2, 23, 4):  # veines du bois
            for y in range(5, 43):
                if (y + x) % 5 != 0:
                    img.putpixel((x, y), hexc("5e3a22"))
        for y0 in (6, 24):  # panneaux moulures
            for x in range(leaf_x0 + 2, 23):
                img.putpixel((x, y0), hexc("2e1a10"))
                img.putpixel((x, y0 + 15), hexc("a87048"))
        knob = (21, 26)
        dots(img, [knob, (knob[0] + 1, knob[1]), (knob[0], knob[1] + 1)], hexc("f0c048"))
        dots(img, [(knob[0], knob[1] - 1)], hexc("fff0a0"))
        if f == 0:
            for x in range(4, 24):  # rai de lumiere sous la porte
                img.putpixel((x, 45), hexc("ffd77a"))
        return img
    return sheet(w, h, 2, make)


NIGHTS = {
    "lundi": {"mouton": mouton, "bailleur": bailleur, "veilleuse": veilleuse, "paupiere": paupiere,
              "grande_couette": grande_couette, "reveil_grincheux": reveil_grincheux,
              "choeur_baillements": choeur_baillements, "porte_des_voix": porte_des_voix},
}


def main():
    from mob_art_week import WEEK  # mardi..dimanche (importe ici : il reutilise les outils ci-dessus)
    for night, makers in {**NIGHTS, **WEEK}.items():
        os.makedirs(os.path.join(ROOT, night), exist_ok=True)
        for name, make in makers.items():
            img = make()
            img.save(os.path.join(ROOT, night, name + ".png"))
            print(night, name, img.size)


if __name__ == "__main__":
    main()
