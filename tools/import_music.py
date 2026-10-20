"""Telecharge les musiques du jeu : morceaux enregistres sous licence CC0 (OpenGameArt).

Lancer depuis la racine du projet : python tools/import_music.py
Ecrit assets/audio/music/<morceau>.<ext> (Sound.music() accepte .ogg, .mp3 et .wav) ; credits a
jour a la main dans CREDITS.md. Les compositions originales viennent de tools/compose_music.py. Pour changer un morceau : modifier la table MUSIC et relancer le script.
CC0 = domaine public : aucune obligation de credit, mais on credite les auteurs quand meme.
"""
import os
import urllib.request

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT_DIR = os.path.join(ROOT, "assets", "audio", "music")

# morceau du jeu -> (titre, auteur, page OpenGameArt, fichier a telecharger)
MUSIC = {
    "boss": ("Battle Theme A", "cynicmusic",
             "https://opengameart.org/content/battle-theme-a",
             "https://opengameart.org/sites/default/files/battleThemeA.mp3"),
}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for f in os.listdir(OUT_DIR):  # seulement nos morceaux : les compositions originales restent
        if f.split(".")[0] in MUSIC:
            os.remove(os.path.join(OUT_DIR, f))
    for name, (title, author, page, url) in MUSIC.items():
        ext = os.path.splitext(url)[1].lower()
        path = os.path.join(OUT_DIR, name + ext)
        print(f"{name}: {title} - {author}")
        urllib.request.urlretrieve(url, path)

if __name__ == "__main__":
    main()
