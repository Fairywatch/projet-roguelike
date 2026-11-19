"""Exporte le jeu pour Windows et prepare un zip a envoyer aux testeurs.

Lancer depuis la racine du projet :
    python tools/export_game.py [chemin de l'executable Godot] [--publish "notes de version"]
(par defaut : $GODOT, sinon "godot"). Il faut le modele d'export Windows de la meme version que
l'editeur (Editeur > Gerer les modeles d'export).

--publish : cree aussi la release GitHub "v<version>" avec le zip (outil gh, connecte une fois
avec "gh auth login"). Les jeux deja installes la trouvent au lancement et se mettent a jour
(scripts/menu/updater.gd). Avant chaque publication, augmenter config/version dans project.godot.

Produit build/windows/DreamDive.exe (un seul fichier, donnees incluses) et
build/DreamDive-v<version>-windows.zip : l'exe, LISEZMOI.txt, les credits et les licences.

Le plugin Godot MCP ajoute un autoload (MCPRuntime) qui ouvre une connexion vers l'editeur : il ne
doit pas partir chez les joueurs. Le dossier addons/ est exclu de l'export (export_presets.cfg), et
cet autoload est retire de project.godot le temps de l'export, puis remis.
"""
import os
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PRESET = "Windows Desktop"
EXE = os.path.join(ROOT, "build", "windows", "DreamDive.exe")
EDITOR_ONLY_AUTOLOADS = ("MCPRuntime=",)
LICENSES = ["assets/fonts/OFL.txt", "assets/fonts/PixelifySans-OFL.txt", "assets/audio/sfx/LICENSE_Kenney.txt"]

README = """Dream Dive v{version}
=====================

Lancer : double-clic sur DreamDive.exe (Windows 10 ou 11, 64 bits). Rien a installer.

Windows peut afficher "Windows a protege votre ordinateur" : le jeu n'est pas signe (c'est
normal pour un jeu en test). Cliquer sur "Informations complementaires" puis "Executer quand meme".

Clavier : ZQSD ou fleches pour bouger, J attaque, K dash, I rafale de plumes, L objet actif,
E interagir, Tab objets passifs, Echap menu.
Manette : stick gauche, X attaque, B dash, RB rafale, Y objet actif, A interagir, Select objets,
Start menu.
Tout se change dans Parametres > Touches. Plein ecran : Parametres > Plein ecran.

Sauvegardes : %APPDATA%\\Godot\\app_userdata\\Dream Dive\\

Mises a jour : au lancement, le jeu verifie s'il existe une nouvelle version et propose de se
mettre a jour tout seul (il faut internet ; desactivable dans Parametres). Garde DreamDive.exe
dans un dossier ou tu peux ecrire (pas dans le zip ni dans Program Files).

Retours bienvenus ! Dis surtout :
- la version (en bas a droite du menu principal) ;
- jusqu'ou tu es alle (nuit, etage) et combien de temps tu as joue ;
- ce qui t'a plu, ce qui t'a ennuye ou frustre, ce que tu n'as pas compris ;
- si c'etait trop dur ou trop facile, et ou ;
- les bugs : ce que tu faisais juste avant, et une capture d'ecran si possible.
"""


def version():
    text = open(os.path.join(ROOT, "project.godot"), encoding="utf-8").read()
    found = re.search(r'^config/version="([^"]*)"', text, re.M)
    return found.group(1) if found else "0"


def export(godot):
    project = os.path.join(ROOT, "project.godot")
    original = open(project, encoding="utf-8", newline="").read()
    stripped = "".join(line for line in original.splitlines(keepends=True) if not line.startswith(EDITOR_ONLY_AUTOLOADS))
    os.makedirs(os.path.dirname(EXE), exist_ok=True)
    try:
        open(project, "w", encoding="utf-8", newline="").write(stripped)
        result = subprocess.run([godot, "--headless", "--path", ROOT, "--export-release", PRESET, EXE],
                                capture_output=True, text=True, encoding="utf-8", errors="replace")
    finally:
        open(project, "w", encoding="utf-8", newline="").write(original)
    errors = [line for line in (result.stdout + result.stderr).splitlines() if line.startswith("ERROR")]
    if result.returncode != 0 or not os.path.exists(EXE) or errors:
        print(result.stdout[-3000:], result.stderr[-3000:])
        sys.exit("Export rate (code %d)" % result.returncode)


def package():
    name = "DreamDive-v%s-windows" % version()
    archive = os.path.join(ROOT, "build", name + ".zip")
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(EXE, f"{name}/DreamDive.exe")
        z.writestr(f"{name}/LISEZMOI.txt", README.format(version=version()).replace("\n", "\r\n"))
        z.write(os.path.join(ROOT, "CREDITS.md"), f"{name}/CREDITS.txt")
        for path in LICENSES:
            z.write(os.path.join(ROOT, path), f"{name}/licences/{os.path.basename(path)}")
    return archive


def publish(archive, notes):
    """Release GitHub v<version> avec le zip : les jeux installes la verront au lancement."""
    gh = shutil.which("gh") or os.path.join(os.environ.get("ProgramFiles", ""), "GitHub CLI", "gh.exe")
    if not os.path.exists(gh):
        sys.exit("Outil gh introuvable : installer GitHub CLI puis lancer \"gh auth login\".")
    tag = "v" + version()
    existing = subprocess.run([gh, "release", "view", tag], cwd=ROOT, capture_output=True)
    if existing.returncode == 0:
        sys.exit("La version %s est deja publiee : augmenter config/version dans project.godot." % tag)
    subprocess.run([gh, "release", "create", tag, archive, "--title", "Dream Dive " + tag,
                    "--notes", notes or "Nouvelle version.", "--latest"], cwd=ROOT, check=True)
    print("Publie :", tag)


if __name__ == "__main__":
    args = sys.argv[1:]
    notes = None
    if "--publish" in args:
        i = args.index("--publish")
        notes = args[i + 1] if i + 1 < len(args) else ""
        del args[i:i + 2]
    godot = args[0] if args else os.environ.get("GODOT", "godot")
    if not shutil.which(godot) and not os.path.exists(godot):
        sys.exit("Godot introuvable : " + godot)
    export(godot)
    archive = package()
    print("%s  (%d Mo)" % (EXE, os.path.getsize(EXE) // 1048576))
    print("%s  (%d Mo)" % (archive, os.path.getsize(archive) // 1048576))
    if notes is not None:
        publish(archive, notes)
