"""Icone du jeu : la tete du reveur endormi (bonnet de nuit, yeux fermes), sur un fond de nuit avec
une lune et des "z". Dessinee en 32x32 pixels a partir du sprite du joueur (gen_pixel_art.py).

Lancer depuis la racine du projet : python tools/gen_icon.py
Produit assets/ui/icon.png (fenetre du jeu, 256x256) et assets/ui/icon.ico (l'executable Windows,
de 16 a 256 pixels).
"""
import os

from PIL import Image, ImageDraw

import gen_pixel_art as art

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT_DIR = os.path.join(ROOT, "assets", "ui")
GRID = 32
SKY_TOP = (58, 40, 104)
SKY_BOTTOM = (22, 15, 42)
BORDER = (122, 98, 196)
MOON = (250, 232, 170)
MOON_SHADE = (214, 186, 120)
STAR = (220, 214, 255)
Z_COLOR = (236, 232, 255)
Z_SMALL = ["####", "..#.", ".#..", "####"]
Z_BIG = ["#####", "...#.", "..#..", ".#...", "#####"]
ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]


def sleeping_head():
    """Bonnet et visage du reveur, paupieres closes, contour compris."""
    rows = list(art.PLAYER_BODY[:13])
    rows[8] = rows[8].replace("E", "S")
    rows[9] = "...SEESSSSEES....."  # paupieres closes : un trait sous chaque oeil
    return art.from_ascii(rows, art.PLAYER_PALETTE, art.PLAYER_OUTLINE)


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def base():
    img = Image.new("RGBA", (GRID, GRID), (0, 0, 0, 0))
    sky = Image.new("RGBA", (GRID, GRID))
    for y in range(GRID):
        sky.paste(art.mix(SKY_TOP, SKY_BOTTOM, y / (GRID - 1)) + (255,), (0, y, GRID, y + 1))
    img.paste(sky, (0, 0), rounded_mask(GRID, 6))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((0, 0, GRID - 1, GRID - 1), radius=6, outline=BORDER + (255,))
    # Lune en croissant, en haut a gauche : un disque dont on retire un disque decale.
    moon = Image.new("RGBA", (GRID, GRID), (0, 0, 0, 0))
    ImageDraw.Draw(moon).ellipse((4, 4, 12, 12), fill=MOON + (255,))
    ImageDraw.Draw(moon).ellipse((7, 2, 15, 10), fill=(0, 0, 0, 0))
    moon.putpixel((5, 9), MOON_SHADE + (255,))
    img.alpha_composite(moon)
    for x, y in [(16, 4), (26, 13), (3, 16), (13, 13)]:
        img.putpixel((x, y), STAR + (255,))
    # "z" de plus en plus grands vers le haut a droite.
    for (x, y, glyph) in [(20, 11, Z_SMALL), (24, 4, Z_BIG)]:
        for dy, row in enumerate(glyph):
            for dx, c in enumerate(row):
                if c == "#":
                    img.putpixel((x + dx, y + dy), Z_COLOR + (255,))
    head = sleeping_head()
    img.alpha_composite(head, ((GRID - head.width) // 2 - 1, GRID - head.height - 3))
    return img


def main():
    icon = base()
    big = icon.resize((256, 256), Image.NEAREST)
    big.save(os.path.join(OUT_DIR, "icon.png"))
    # Petites tailles : 32 et 16 au pixel pres, les autres agrandies sans flou.
    sizes = []
    for size in ICO_SIZES:
        if size >= GRID:
            sizes.append(icon.resize((size, size), Image.NEAREST))
        else:
            sizes.append(icon.resize((size, size), Image.BOX))
    sizes[-1].save(os.path.join(OUT_DIR, "icon.ico"), format="ICO", sizes=[(s, s) for s in ICO_SIZES],
                   append_images=sizes[:-1])
    print("icon.png, icon.ico ->", os.path.abspath(OUT_DIR))


if __name__ == "__main__":
    main()
