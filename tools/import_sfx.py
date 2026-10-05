"""Importe les effets sonores du jeu depuis les packs CC0 de Kenney (enregistrements reels).

Usage : python tools/import_sfx.py <dossier contenant les packs Kenney decompresses>
Packs utilises (kenney.nl, licence CC0, credit non obligatoire mais apprecie) :
  kenney_impact-sounds, kenney_rpg-audio, kenney_ui-audio
Copie les variantes de chaque famille dans assets/audio/sfx/<evenement>_<n>.ogg et ecrit
scripts/audio/sfx_manifest.gd (nombre de variantes, hauteur, volume) lu par Sound.play().
Pour changer un son : modifier la table SFX ci-dessous et relancer le script.
"""
import os
import re
import shutil
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MANIFEST = os.path.join(ROOT, "scripts", "audio", "sfx_manifest.gd")
PACKS = {"impact": "kenney_impact-sounds", "rpg": "kenney_rpg-audio", "ui": "kenney_ui-audio"}

# evenement -> (pack, famille de fichiers, hauteur de lecture, volume en dB)
# Uniquement des bruitages enregistres (tissu, impacts, verre, cloches, pieces...) : naturels.
SFX = {
    "slash": ("rpg", "cloth", 1.1, -10.0),            # froissement de l'attaque
    "dash": ("rpg", "clothBelt", 1.0, -9.0),
    "dodge": ("rpg", "cloth", 1.35, -12.0),
    "hit": ("impact", "impactSoft_medium", 1.0, -6.0),  # coup qui porte
    "crit": ("impact", "impactPunch_heavy", 1.0, -6.0),
    "hurt": ("impact", "impactPunch_medium", 0.9, -5.0),
    "mob_die": ("impact", "impactSoft_heavy", 1.1, -6.0),
    "shoot": ("impact", "impactGeneric_light", 1.3, -14.0),
    "pickup": ("impact", "impactGlass_light", 1.0, -8.0),  # tintement de verre
    "sparkle": ("impact", "impactGlass_light", 1.25, -11.0),
    "heal": ("impact", "impactGlass_medium", 1.2, -10.0),
    "coin": ("rpg", "handleCoins", 1.0, -8.0),
    "chest": ("rpg", "metalLatch", 1.0, -6.0),
    "shield": ("impact", "impactMetal_light", 1.1, -10.0),
    "active": ("impact", "impactBell_heavy", 1.2, -12.0),
    "victory": ("impact", "impactBell_heavy", 1.5, -12.0),
    "quest": ("rpg", "bookOpen", 1.0, -6.0),
    "portal": ("rpg", "doorOpen", 0.85, -8.0),
    "pop": ("impact", "impactGeneric_light", 1.7, -12.0),
    "ui_select": ("ui", "click", 1.0, -14.0),
    "death": ("impact", "impactWood_heavy", 0.8, -4.0),
    "encounter": ("impact", "impactBell_heavy", 0.7, -6.0),  # cloche grave : bascule dans le combat
    "boss": ("impact", "impactMetal_heavy", 0.6, -4.0),      # coup de gong pour un boss
}


def family_files(pack_dir, family):
    audio = os.path.join(pack_dir, "Audio")
    pattern = re.compile(re.escape(family) + r"(_?\d+)?\.ogg$")
    return sorted(f for f in os.listdir(audio) if pattern.fullmatch(f))


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    src = sys.argv[1]
    os.makedirs(OUT_DIR, exist_ok=True)
    for f in os.listdir(OUT_DIR):  # repart de zero (anciens .wav synthetises inclus)
        if f.endswith((".wav", ".ogg", ".import")):
            os.remove(os.path.join(OUT_DIR, f))
    lines = []
    for event, (pack, family, pitch, volume_db) in SFX.items():
        pack_dir = os.path.join(src, PACKS[pack])
        files = family_files(pack_dir, family)
        if not files:
            sys.exit(f"Aucun fichier '{family}' dans {pack_dir}")
        for i, name in enumerate(files):
            shutil.copy(os.path.join(pack_dir, "Audio", name), os.path.join(OUT_DIR, f"{event}_{i}.ogg"))
        lines.append(f'\t"{event}": {{"variants": {len(files)}, "pitch": {pitch}, "db": {volume_db}}},')
    shutil.copy(os.path.join(src, PACKS["impact"], "License.txt"), os.path.join(OUT_DIR, "LICENSE_Kenney.txt"))
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as m:
        m.write("class_name SfxManifest\nextends RefCounted\n\n")
        m.write("# Genere par tools/import_sfx.py : ne pas modifier a la main.\n")
        m.write("# Effets sonores : enregistrements CC0 de Kenney (www.kenney.nl).\n")
        m.write("const SFX := {\n" + "\n".join(lines) + "\n}\n")
    print(f"{len(SFX)} effets importes dans {OUT_DIR}")


if __name__ == "__main__":
    main()
