"""Interface "carnet de reves" : papier creme, encre, crayon, scotch. Pixel art.

Lancer depuis la racine du projet : python tools/gen_ui.py
Ecrit assets/ui/notebook/<nom>.png, dessines en pixels d'art puis agrandis x2 (un pixel d'art =
2 pixels du jeu, comme les sprites). Les panneaux sont des "9-slice" : les marges sont dans
assets/ui/theme.tres (StyleBoxTexture, en pixels du jeu = 2 x les marges ci-dessous).
"""
import os
import random

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "notebook")
SCALE = 2

PAPER = (239, 228, 207)
PAPER_SHADE = (222, 207, 178)
PAPER_DARK = (196, 177, 142)
PAPER_SPOT = (230, 216, 190)
INK = (43, 33, 64)
INK_SOFT = (92, 78, 120)
RULE = (170, 190, 222)       # lignes du cahier
MARGIN_RED = (214, 120, 130)  # marge rouge
HIGHLIGHT = (246, 214, 96)    # surligneur
RED_PENCIL = (200, 72, 82)
BLUE_PENCIL = (82, 112, 186)
TAPE = (236, 230, 196, 170)
SHADOW = (20, 12, 30, 110)
CLEAR = (0, 0, 0, 0)


def canvas(w, h):
    return Image.new("RGBA", (w, h), CLEAR)


def put(img, x, y, color):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color if len(color) == 4 else color + (255,))


def paper_fill(img, x0, y0, x1, y1, rng, base=PAPER, spots=0.05):
    """Papier : une couleur, quelques grains plus sombres (jamais deux voisins identiques en ligne)."""
    for y in range(y0, y1):
        for x in range(x0, x1):
            put(img, x, y, base)
            if rng.random() < spots:
                put(img, x, y, PAPER_SPOT)


def ink_border(img, x0, y0, x1, y1, color=INK, wobble=None):
    """Bord d'encre d'un pixel ; wobble : liste de (x, y) ou le trait saute d'un pixel (main levee)."""
    for x in range(x0, x1):
        put(img, x, y0, color)
        put(img, x, y1 - 1, color)
    for y in range(y0, y1):
        put(img, x0, y, color)
        put(img, x1 - 1, y, color)


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST).save(os.path.join(OUT, name + ".png"))


def panel():
    """Page de carnet : 22x22, marges 7 (le milieu, 8 pixels, contient deux lignes : il se repete
    sans casser l'ecart des lignes). Lignes bleues, marge rouge, coin corne en bas a droite, ombre
    portee d'un pixel."""
    rng = random.Random(1)
    w = h = 22
    img = canvas(w + 1, h + 1)
    for x in range(1, w + 1):  # ombre portee
        put(img, x, h, SHADOW)
    for y in range(1, h + 1):
        put(img, w, y, SHADOW)
    paper_fill(img, 0, 0, w, h, rng)
    for y in range(5, h - 2, 4):  # lignes du cahier (y = 5, 9, 13, 17)
        for x in range(1, w - 1):
            put(img, x, y, RULE)
    for y in range(1, h - 1):  # marge rouge
        put(img, 4, y, MARGIN_RED)
    ink_border(img, 0, 0, w, h)
    # Coin corne : le coin bas-droit replie (triangle plus sombre, bord d'encre en diagonale).
    for i in range(6):
        for j in range(6 - i):
            put(img, w - 1 - j, h - 1 - i, CLEAR)
    for i in range(6):
        for j in range(i + 1):
            put(img, w - 6 + j, h - 6 + i, PAPER_DARK if j < i else INK)
        put(img, w - 6 + i, h - 1, INK)
        put(img, w - 1, h - 6 + i, INK)
    put(img, w - 6, h - 6, INK)
    save(img, "panel")


def scrap(name, w=20, h=16, tape=True, torn_top=True, base=PAPER):
    """Bout de papier dechire (HUD, messages) : bord du haut dechire, scotch en haut a gauche."""
    rng = random.Random(len(name))
    img = canvas(w + 1, h + 1)
    for x in range(1, w + 1):
        put(img, x, h, SHADOW)
    for y in range(2, h + 1):
        put(img, w, y, SHADOW)
    tear = [rng.choice([0, 0, 1, 1, 2]) if torn_top else 0 for _ in range(w)]
    for x in range(w):
        for y in range(tear[x], h):
            put(img, x, y, base)
            if rng.random() < 0.05:
                put(img, x, y, PAPER_SPOT)
        put(img, x, tear[x], INK)
        put(img, x, h - 1, INK)
    for y in range(h):
        if y >= tear[0]:
            put(img, 0, y, INK)
        if y >= tear[-1]:
            put(img, w - 1, y, INK)
    for x in range(1, w - 1):  # papier un peu plus sombre en bas : epaisseur
        put(img, x, h - 2, PAPER_SHADE)
    if tape:
        for y in range(0, 4):
            for x in range(1 + y // 2, 7 + y // 2):
                put(img, x, y, TAPE)
    save(img, name)


def button(name, fill, border=INK, press=0, marker=None, alpha=255):
    """Etiquette de papier : 16x12, marges 5. press : decalage vers le bas (bouton enfonce)."""
    w, h = 16, 12
    img = canvas(w, h + 1)
    rng = random.Random(name)
    top = press
    for x in range(w):  # epaisseur sous l'etiquette
        put(img, x, h, (PAPER_DARK[0], PAPER_DARK[1], PAPER_DARK[2], alpha) if not press else CLEAR)
    for y in range(top, h + top - (1 if press else 0)):
        for x in range(w):
            put(img, x, y, fill + (alpha,))
            if rng.random() < 0.04:
                put(img, x, y, PAPER_SPOT + (alpha,))
    if marker:  # coup de surligneur en biais derriere le texte
        for y in range(top + 3, h + top - 3):
            for x in range(2 + (y - top) % 2, w - 2):
                put(img, x, y, marker + (alpha,))
    bottom = h + top - (1 if press else 0)
    for x in range(w):
        put(img, x, top, border + (alpha,))
        put(img, x, bottom - 1, border + (alpha,))
    for y in range(top, bottom):
        put(img, 0, y, border + (alpha,))
        put(img, w - 1, y, border + (alpha,))
    for c in [(0, top), (w - 1, top), (0, bottom - 1), (w - 1, bottom - 1)]:  # coins coupes
        put(img, c[0], c[1], CLEAR)
    save(img, name)


def focus():
    """Focus : un cadre d'encre trace a la main, double trait decale (on voit qu'il a ete repasse)."""
    w, h = 16, 12
    img = canvas(w + 2, h + 2)
    for x in range(1, w + 1):
        put(img, x, 0, HIGHLIGHT)
        put(img, x, h + 1, HIGHLIGHT)
    for y in range(1, h + 1):
        put(img, 0, y, HIGHLIGHT)
        put(img, w + 1, y, HIGHLIGHT)
    for x in range(2, w):
        put(img, x, 1, INK)
    for y in range(2, h):
        put(img, w, y, INK)
    save(img, "focus")


def key_badge():
    """Touche : petit carre de papier, bord d'encre, epaisseur dessous. 8x8, marges 3."""
    img = canvas(8, 9)
    for y in range(8):
        for x in range(8):
            put(img, x, y, PAPER)
    for x in range(8):
        put(img, x, 0, INK)
        put(img, x, 7, INK)
        put(img, x, 8, INK_SOFT)
    for y in range(8):
        put(img, 0, y, INK)
        put(img, 7, y, INK)
    for c in [(0, 0), (7, 0), (0, 8), (7, 8)]:
        put(img, c[0], c[1], CLEAR)
    save(img, "key_badge")


def slider():
    """Piste : trait d'encre sur papier ; remplissage : hachures au crayon bleu. 8x6, marges 3."""
    track = canvas(8, 6)
    for x in range(8):
        for y in range(1, 5):
            put(track, x, y, PAPER_SHADE)
        put(track, x, 1, INK)
        put(track, x, 4, INK)
    save(track, "slider_track")
    fill = canvas(8, 6)
    for x in range(8):
        for y in range(2, 4):
            put(fill, x, y, BLUE_PENCIL if (x + y) % 3 else (120, 150, 210))
        put(fill, x, 1, INK)
        put(fill, x, 4, INK)
    save(fill, "slider_fill")
    grab = canvas(7, 10)  # trombone / onglet de papier
    for y in range(10):
        for x in range(7):
            put(grab, x, y, PAPER if 0 < x < 6 and 0 < y < 9 else INK)
    for x in range(2, 5):
        put(grab, x, 3, RED_PENCIL)
        put(grab, x, 6, RED_PENCIL)
    for c in [(0, 0), (6, 0), (0, 9), (6, 9)]:
        put(grab, c[0], c[1], CLEAR)
    save(grab, "slider_grab")
    hi = grab.copy()
    for y in range(1, 9):
        for x in range(1, 6):
            if hi.getpixel((x, y))[:3] == PAPER:
                put(hi, x, y, HIGHLIGHT)
    save(hi, "slider_grab_hi")


def checkbox():
    """Case du carnet : vide, ou cochee d'un trait au crayon rouge qui deborde."""
    empty = canvas(10, 10)
    for y in range(1, 9):
        for x in range(1, 9):
            put(empty, x, y, PAPER)
    for i in range(1, 9):
        put(empty, i, 1, INK)
        put(empty, i, 8, INK)
        put(empty, 1, i, INK)
        put(empty, 8, i, INK)
    save(empty, "check_off")
    ticked = empty.copy()
    for x, y in [(2, 5), (3, 6), (4, 7), (5, 6), (6, 5), (7, 4), (8, 3), (9, 2), (9, 1)]:
        put(ticked, x, y, RED_PENCIL)
        put(ticked, x, y - 1, RED_PENCIL)
    save(ticked, "check_on")


def word_paper():
    """Bout de papier ou s'ecrivent les mots lances par les ennemis : bords gauche et droit
    dechires en dents, ombre d'un pixel. 10x9, marges 3."""
    w, h = 10, 9
    img = canvas(w + 1, h + 1)
    for x in range(1, w + 1):
        put(img, x, h, SHADOW)
    for y in range(h):
        bite = 1 if y % 3 == 1 else 0  # dents de la dechirure
        for x in range(bite, w - bite):
            put(img, x, y, PAPER)
        put(img, bite, y, INK)
        put(img, w - 1 - bite, y, INK)
    for x in range(w):
        put(img, x, 0, INK)
        put(img, x, h - 1, INK)
        put(img, x, h - 2, PAPER_SHADE) if 0 < x < w - 1 else None
    save(img, "word")


if __name__ == "__main__":
    panel()
    scrap("hud")
    scrap("toast", 24, 14, tape=True)
    button("button", PAPER)
    button("button_hover", PAPER, marker=HIGHLIGHT)
    button("button_pressed", PAPER_SHADE, press=1, marker=HIGHLIGHT)
    button("button_disabled", PAPER_SHADE, border=INK_SOFT, alpha=150)
    focus()
    key_badge()
    slider()
    checkbox()
    word_paper()
    print("ok :", sorted(os.listdir(OUT)))
