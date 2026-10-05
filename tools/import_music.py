"""Telecharge les musiques du jeu : morceaux enregistres sous licence CC0 (OpenGameArt).

Lancer depuis la racine du projet : python tools/import_music.py
Ecrit assets/audio/music/<morceau>.<ext> (Sound.music() accepte .ogg, .mp3 et .wav) et
CREDITS.md. Pour changer un morceau : modifier la table MUSIC et relancer le script.
CC0 = domaine public : aucune obligation de credit, mais on credite les auteurs quand meme.
"""
import os
import urllib.request

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT_DIR = os.path.join(ROOT, "assets", "audio", "music")

# morceau du jeu -> (titre, auteur, page OpenGameArt, fichier a telecharger)
MUSIC = {
    "reve": ("Mysterious Ambience (song21)", "cynicmusic",
             "https://opengameart.org/content/mysterious-ambience-song21",
             "https://opengameart.org/sites/default/files/song21_0.mp3"),
    "profond": ("Enchanted Tiki 86", "cynicmusic",
                "https://opengameart.org/content/enchanted-tiki-86",
                "https://opengameart.org/sites/default/files/enchanted%20tiki%2086_0.mp3"),
    "combat": ("Battle Theme", "Wolfgang_",
               "https://opengameart.org/content/battle-theme-0",
               "https://opengameart.org/sites/default/files/Battle.mp3"),
    "boss": ("Battle Theme A", "cynicmusic",
             "https://opengameart.org/content/battle-theme-a",
             "https://opengameart.org/sites/default/files/battleThemeA.mp3"),
}
USES = {"reve": "etages du sommeil paradoxal et menus", "profond": "etages du sommeil profond",
        "combat": "combats", "boss": "combats de boss"}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for f in os.listdir(OUT_DIR):  # repart de zero (anciennes musiques synthetisees incluses)
        if f.endswith((".wav", ".ogg", ".mp3", ".import")):
            os.remove(os.path.join(OUT_DIR, f))
    for name, (title, author, page, url) in MUSIC.items():
        ext = os.path.splitext(url)[1].lower()
        path = os.path.join(OUT_DIR, name + ext)
        print(f"{name}: {title} - {author}")
        urllib.request.urlretrieve(url, path)
    with open(os.path.join(ROOT, "CREDITS.md"), "w", encoding="utf-8", newline="\n") as c:
        c.write("# Credits\n\nTous les sons et musiques ci-dessous sont sous licence CC0 (domaine public).\n\n")
        c.write("## Musiques (OpenGameArt)\n\n")
        for name, (title, author, page, _) in MUSIC.items():
            c.write(f"- **{title}** par {author} ({USES[name]}) : {page}\n")
        c.write("\n## Effets sonores\n\n")
        c.write("- Packs *Impact Sounds*, *RPG Audio* et *UI Audio* par Kenney : https://www.kenney.nl\n")


if __name__ == "__main__":
    main()
