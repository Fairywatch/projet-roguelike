"""Themes des sept nuits (un par nuit, joue sur la carte), ecrits pour tools/compose_music.py.

Chaque nuit a sa couleur, tiree de son emotion :
  lundi     Fatigue      berceuse de boite a musique (celesta, harpe), sol majeur, lent
  mardi     Stress       pendule de marimba et de glockenspiel, violons inquiets, la mineur, rapide
  mercredi  Doute        piano qui hesite entre mineur et majeur, mi mineur
  jeudi     Frustration  cors et timbales qui butent, violoncelles martelés, re mineur
  vendredi  Epuisement   altos et choeur, tres lent, fa majeur
  samedi    Solitude     piano clairseme, vibraphone qui repond dans les silences, si mineur
  dimanche  Angoisse     battement de coeur aux timbales, puis l'aube en do majeur aux cors

Forme commune (32 mesures, en boucle) : introduction (4), A (8), B (8), C (8, A varie ou
reharmonise), conclusion (4). Les parties ont un role (lead, accomp, pad, bass, extra) : leur
volume est regle par compose_music.balance_stems, qui mesure chaque piste rendue au lieu de
deviner (les instruments de MuseScore sortent a des niveaux tres differents).
"""

REST = "r8"

# Niveau vise pour chaque role, en dB par rapport a la melodie.
ROLE_LEVELS = {"lead": 0.0, "accomp": -6.0, "pad": -9.0, "bass": -8.0, "extra": -10.0}


def held(notes):
    return ",".join(notes) + ":8"


def pattern(notes, order, dur):
    return " ".join(f"{notes[i]}:{dur}" for i in order)


def lay(sections, total=32):
    """sections : [(premiere mesure, [mesures])] -> 32 mesures, silences ailleurs."""
    out = [REST] * total
    for start, measures in sections:
        for i, m in enumerate(measures):
            out[start + i] = m
    return out


def dyn(measures, marks):
    return [(m, marks.get(i + 1)) for i, m in enumerate(measures)]


def piece(spec):
    """Assemble une nuit : accompagnement genere a partir des accords, melodies ecrites a la main."""
    chords = spec["chords"]
    order = spec["intro"] + spec["A"] + spec["B"] + spec.get("C", spec["A"]) + spec["outro"]
    assert len(order) == 32, (spec["title"], len(order))
    arp = [chords[c][0] for c in order]
    pad = [chords[c][1] for c in order]
    bass = [chords[c][2] for c in order]
    melodies = {"A": spec["melody_A"], "B": spec["melody_B"], "C": spec.get("melody_C", spec["melody_A"])}
    parts = []
    # Melodies : chaque section sur son instrument (le meme instrument peut porter plusieurs sections).
    leads = {}
    for section, start in (("A", 4), ("B", 12), ("C", 20)):
        inst = spec["leads"][section]
        leads.setdefault(inst, []).append((start, melodies[section]))
    for inst, sections in leads.items():
        parts.append((inst, dyn(lay(sections), spec.get("lead_dynamics", {5: "mp", 13: "mf", 21: "mp"})), "lead", spec.get("pan", {}).get(inst, 0.0)))
    # Accompagnement : arpege ou ostinato sur les accords.
    acc_inst, acc_order, acc_dur, acc_from = spec["accomp"]
    accomp = [REST] * acc_from + [pattern(n, acc_order, acc_dur) for n in arp[acc_from:]]
    parts.append((acc_inst, dyn(accomp, spec.get("accomp_dynamics", {1: "p", 13: "mp", 29: "p"})), "accomp", -0.25))
    pad_inst, pad_from = spec["pad"]
    pads = [REST] * pad_from + [held(n) for n in pad[pad_from:]]
    parts.append((pad_inst, dyn(pads, {pad_from + 1: "pp", 13: "p", 29: "pp"}), "pad", 0.15))
    bass_inst, bass_style = spec["bass"]
    if bass_style == "held":
        lows = [held([n]) for n in bass]
    else:  # pulse : la basse bat les noires
        lows = [" ".join([f"{n}:2"] * 4) for n in bass]
    parts.append((bass_inst, dyn(lows, {1: "p", 13: "mp", 29: "p"}), "bass", 0.2))
    for inst, measures, marks, level, pan in spec.get("extras", []):
        parts.append((inst, dyn(measures, marks), ("extra", level), pan))
    return {"title": spec["title"], "tempo": spec["tempo"], "fifths": spec["fifths"], "parts": parts, "balance": True}


# --- Lundi : Fatigue (l'enfance, les disputes derriere la porte) -----------------------------

def lundi():
    chords = {  # (arpege 5 notes, nappe, basse)
        "G": (["G2", "D3", "G3", "B3", "D4"], ["B3", "D4", "G4"], "G2"),
        "Em": (["E2", "B2", "E3", "G3", "B3"], ["B3", "E4", "G4"], "E2"),
        "C": (["C3", "G3", "C4", "E4", "G4"], ["C4", "E4", "G4"], "C2"),
        "D": (["D3", "A3", "D4", "F#4", "A4"], ["A3", "D4", "F#4"], "D2"),
        "Am7": (["A2", "E3", "G3", "C4", "E4"], ["C4", "E4", "G4"], "A2"),
        "G/B": (["B2", "D3", "G3", "B3", "D4"], ["B3", "D4", "G4"], "B2"),
        "Am": (["A2", "E3", "A3", "C4", "E4"], ["C4", "E4", "A4"], "A2"),
        "Dsus": (["D3", "A3", "D4", "G4", "A4"], ["A3", "D4", "G4"], "D2"),
    }
    return piece({
        "title": "Lundi - Berceuse", "tempo": 60, "fifths": 1, "chords": chords,
        "intro": ["G", "Em", "C", "D"],
        "A": ["G", "Em", "C", "D", "G", "Em", "Am7", "D"],
        "B": ["C", "G/B", "Am", "Em", "C", "G", "Am", "Dsus"],
        "outro": ["G", "Em", "C", "Dsus"],
        "melody_A": ["D5:3 B4:1 D5:4", "E5:3 D5:1 B4:4", "C5:2 E5:2 G5:2 E5:2", "D5:6 r2",
                     "D5:3 B4:1 D5:2 G5:2", "F#5:2 E5:2 B4:4", "C5:2 A4:2 E5:2 C5:2", "D5:8"],
        "melody_B": ["E5:4 G5:4", "F#5:2 E5:2 D5:4", "C5:3 B4:1 A4:4", "B4:6 r2",
                     "E5:2 G5:2 C6:4", "B5:3 A5:1 G5:4", "A5:2 G5:2 E5:2 C5:2", "D5:4 r4"],
        # La reprise s'endort : le piano rejoue le theme, une octave plus bas.
        "melody_C": ["D4:3 B3:1 D4:4", "E4:3 D4:1 B3:4", "C4:2 E4:2 G4:2 E4:2", "D4:6 r2",
                     "D4:3 B3:1 D4:2 G4:2", "F#4:2 E4:2 B3:4", "C4:2 A3:2 E4:2 C4:2", "D4:8"],
        "leads": {"A": "celesta", "B": "celesta", "C": "piano"},
        "lead_dynamics": {5: "p", 13: "mp", 21: "pp"},
        "accomp": ("harp", [0, 1, 2, 3, 4, 3, 2, 1], 1, 0),
        "pad": ("violins", 4),
        "bass": ("cellos", "held"),
    })


# --- Mardi : Stress (l'ecole, la pression) ----------------------------------------------------

def mardi():
    chords = {
        "Am": (["A2", "E3", "A3", "C4", "E4"], ["C4", "E4", "A4"], "A2"),
        "F": (["F2", "C3", "F3", "A3", "C4"], ["C4", "F4", "A4"], "F2"),
        "G": (["G2", "D3", "G3", "B3", "D4"], ["B3", "D4", "G4"], "G2"),
        "Dm": (["D3", "A3", "D4", "F4", "A4"], ["D4", "F4", "A4"], "D2"),
        "E": (["E2", "B2", "E3", "G#3", "B3"], ["B3", "E4", "G#4"], "E2"),
        "Em": (["E2", "B2", "E3", "G3", "B3"], ["B3", "E4", "G4"], "E2"),
    }
    ticks = lay([(4, ["E6:1s r1 E6:1s r1 E6:1s r1 E6:1s r1"] * 24)])  # la pendule, sur chaque temps
    return piece({
        "title": "Mardi - Pendule", "tempo": 104, "fifths": 0, "chords": chords,
        "intro": ["Am", "Am", "F", "E"],
        "A": ["Am", "Am", "F", "G", "Am", "Am", "Dm", "E"],
        "B": ["F", "G", "Em", "Am", "F", "G", "E", "E"],
        "outro": ["Am", "F", "E", "E"],
        "melody_A": ["E5:2 A5:2 C6:2 B5:2", "A5:3 G5:1 E5:4", "F5:2 A5:2 C6:3 B5:1", "B5:4 D5:4",
                     "E5:2 A5:2 C6:2 E6:2", "D6:3 C6:1 A5:4", "F5:2 A5:2 D6:2 C6:2", "B5:4 G#5:4"],
        "melody_B": ["C6:1 C6:1 C6:2 A5:4", "B5:1 B5:1 B5:2 G5:4", "G5:2 B5:2 E6:4", "C6:4 A5:4",
                     "A5:1 C6:1 F6:2 E6:2 C6:2", "D6:1 B5:1 G6:2 F6:2 D6:2", "E6:2 D6:2 C6:2 B5:2", "G#5:8"],
        "leads": {"A": "violins", "B": "violins", "C": "violins"},
        "lead_dynamics": {5: "mp", 13: "f", 21: "mf"},
        # Marimba pique, comme des aiguilles qui tournent.
        "accomp": ("marimba", [0, 2, 3, 2, 1, 2, 3, 2], "1s", 0),
        "accomp_dynamics": {1: "mp", 13: "mf", 29: "mp"},
        "pad": ("violas", 12),
        "bass": ("cellos", "pulse"),
        "extras": [("glockenspiel", ticks, {5: "p"}, -14.0, 0.35)],
    })


# --- Mercredi : Doute (la jeunesse, qui devenir) ------------------------------------------------

def mercredi():
    chords = {
        "Em": (["E2", "B2", "E3", "G3", "B3"], ["B3", "E4", "G4"], "E2"),
        "C": (["C3", "G3", "C4", "E4", "G4"], ["C4", "E4", "G4"], "C2"),
        "G": (["G2", "D3", "G3", "B3", "D4"], ["B3", "D4", "G4"], "G2"),
        "D": (["D3", "A3", "D4", "F#4", "A4"], ["A3", "D4", "F#4"], "D2"),
        "Am": (["A2", "E3", "A3", "C4", "E4"], ["C4", "E4", "A4"], "A2"),
        "B": (["B2", "F#3", "B3", "D#4", "F#4"], ["B3", "D#4", "F#4"], "B1"),
        "D/F#": (["F#2", "D3", "A3", "D4", "F#4"], ["A3", "D4", "F#4"], "F#2"),
        "E": (["E2", "B2", "E3", "G#3", "B3"], ["B3", "E4", "G#4"], "E2"),
    }
    return piece({
        "title": "Mercredi - Carrefour", "tempo": 76, "fifths": 1, "chords": chords,
        "intro": ["Em", "C", "Em", "B"],
        "A": ["Em", "C", "G", "D", "Em", "C", "Am", "B"],
        # B finit en mi majeur : le doute s'eclaire, puis A revient en mineur.
        "B": ["G", "D/F#", "Em", "C", "G", "D", "C", "E"],
        "outro": ["Em", "C", "Am", "B"],
        "melody_A": ["B4:2 E5:2 G5:4", "E5:2 G5:2 C6:4", "B5:3 A5:1 G5:2 D5:2", "F#5:6 r2",
                     "B4:2 E5:2 G5:2 B5:2", "C6:4 B5:2 G5:2", "A5:3 G5:1 E5:2 C5:2", "D#5:4 F#5:4"],
        "melody_B": ["D5:2 G5:2 B5:4", "A5:2 F#5:2 D5:4", "E5:2 G5:2 B5:2 E6:2", "D6:4 C6:2 G5:2",
                     "B5:2 D6:2 G6:4", "F#6:2 E6:2 D6:4", "E6:3 D6:1 C6:2 A5:2", "G#5:8"],
        "leads": {"A": "piano", "B": "violins", "C": "vibraphone"},
        "accomp": ("harp", [0, 2, 1, 3, 2, 4, 3, 1], 1, 0),
        "pad": ("violas", 4),
        "bass": ("cellos", "held"),
    })


# --- Jeudi : Frustration (la vie active, les efforts sans recompense) --------------------------

def jeudi():
    chords = {
        "Dm": (["D2", "A2", "D3", "F3", "A3"], ["D3", "F3", "A3"], "D2"),
        "Bb": (["Bb1", "F2", "Bb2", "D3", "F3"], ["D3", "F3", "Bb3"], "Bb1"),
        "C": (["C2", "G2", "C3", "E3", "G3"], ["C3", "E3", "G3"], "C2"),
        "Gm": (["G1", "D2", "G2", "Bb2", "D3"], ["D3", "G3", "Bb3"], "G1"),
        "A": (["A1", "E2", "A2", "C#3", "E3"], ["C#3", "E3", "A3"], "A1"),
    }
    timp_roots = {"Dm": "D3", "Bb": "Bb2", "C": "C3", "Gm": "G2", "A": "A2"}
    order = ["Dm", "Dm", "Bb", "A"] + ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Gm", "A"] + \
            ["Bb", "C", "Dm", "Dm", "Bb", "C", "A", "A"] + ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Gm", "A"] + ["Dm", "Bb", "A", "A"]
    # Un coup, un silence trop long, puis deux coups presses : l'effort qui bute.
    timpani = [f"{timp_roots[c]}:2a r4 {timp_roots[c]}:1 {timp_roots[c]}:1" for c in order]
    return piece({
        "title": "Jeudi - Portes closes", "tempo": 92, "fifths": -1, "chords": chords,
        "intro": order[:4], "A": order[4:12], "B": order[12:20], "C": order[20:28], "outro": order[28:],
        "melody_A": ["D4:3 F4:1 A4:4", "G4:3 F4:1 E4:4", "F4:2 Bb4:2 D5:4", "C5:6 r2",
                     "D4:3 F4:1 A4:2 D5:2", "C5:3 A4:1 F4:4", "G4:2 Bb4:2 D5:2 Bb4:2", "A4:4 C#5:4"],
        "melody_B": ["F5:2 Bb5:2 D6:4", "E6:3 D6:1 C6:4", "D6:2 F6:2 A6:4", "G6:3 F6:1 D6:4",
                     "F6:2 D6:2 Bb5:4", "C6:2 E6:2 G6:4", "A6:3 G6:1 E6:2 C#6:2", "A5:8"],
        "leads": {"A": "horns", "B": "violins", "C": "horns"},
        "lead_dynamics": {5: "mf", 13: "f", 21: "f"},
        "accomp": ("cellos", [0, 0, 2, 0, 1, 0, 2, 1], "1s", 0),
        "accomp_dynamics": {1: "mf", 13: "f", 29: "mf"},
        "pad": ("trombones", 4),
        "bass": ("cellos", "held"),
        "extras": [("timpani", timpani, {1: "mf", 13: "f", 29: "mf"}, -8.0, 0.0)],
    })


# --- Vendredi : Epuisement (prendre soin des autres) -------------------------------------------

def vendredi():
    chords = {
        "F": (["F2", "C3", "F3", "A3", "C4"], ["A3", "C4", "F4"], "F2"),
        "Am": (["A2", "E3", "A3", "C4", "E4"], ["A3", "C4", "E4"], "A2"),
        "Bb": (["Bb2", "F3", "Bb3", "D4", "F4"], ["Bb3", "D4", "F4"], "Bb1"),
        "Gm": (["G2", "D3", "G3", "Bb3", "D4"], ["Bb3", "D4", "G4"], "G2"),
        "C": (["C3", "G3", "C4", "E4", "G4"], ["G3", "C4", "E4"], "C2"),
        "Dm": (["D3", "A3", "D4", "F4", "A4"], ["A3", "D4", "F4"], "D2"),
    }
    return piece({
        "title": "Vendredi - Repos", "tempo": 58, "fifths": -1, "chords": chords,
        "intro": ["F", "Bb", "F", "C"],
        "A": ["F", "Am", "Bb", "F", "Gm", "C", "F", "C"],
        "B": ["Dm", "Bb", "F", "C", "Dm", "Bb", "Gm", "C"],
        "outro": ["F", "Bb", "Gm", "C"],
        "melody_A": ["A4:4 C5:4", "E5:4 C5:2 A4:2", "Bb4:3 A4:1 F4:4", "C5:8",
                     "A4:4 G4:2 F4:2", "E4:4 G4:4", "A4:3 G4:1 F4:4", "G4:8"],
        "melody_B": ["D5:4 F5:4", "D5:3 C5:1 Bb4:4", "C5:2 F5:2 A5:4", "G5:8",
                     "F5:4 A5:2 D6:2", "C6:3 Bb5:1 F5:4", "G5:2 Bb5:2 D6:2 Bb5:2", "C6:4 E5:4"],
        "leads": {"A": "violas", "B": "piano", "C": "violas"},
        "lead_dynamics": {5: "p", 13: "mp", 21: "p"},
        # Harpe lente, a la noire : la fatigue.
        "accomp": ("harp", [0, 2, 4, 2], 2, 0),
        "pad": ("choir", 4),
        "bass": ("cellos", "held"),
    })


# --- Samedi : Solitude (les departs, la maison vide) -------------------------------------------

def samedi():
    chords = {
        "Bm": (["B2", "F#3", "B3", "D4", "F#4"], ["D4", "F#4", "B4"], "B1"),
        "G": (["G2", "D3", "G3", "B3", "D4"], ["D4", "G4", "B4"], "G1"),
        "D": (["D3", "A3", "D4", "F#4", "A4"], ["D4", "F#4", "A4"], "D2"),
        "A": (["A2", "E3", "A3", "C#4", "E4"], ["C#4", "E4", "A4"], "A1"),
        "Em": (["E2", "B2", "E3", "G3", "B3"], ["E4", "G4", "B4"], "E2"),
        "F#": (["F#2", "C#3", "F#3", "A#3", "C#4"], ["C#4", "F#4", "A#4"], "F#1"),
    }
    # Le vibraphone repond dans les silences du piano, comme un echo dans une piece vide.
    answers = ["r4 B5:2 F#5:2", "r4 D6:4", "r4 D6:2 A5:2", REST, "r4 D6:2 B5:2", REST, REST, REST]
    vibes = lay([(4, answers), (20, answers)])
    return piece({
        "title": "Samedi - Maison vide", "tempo": 64, "fifths": 2, "chords": chords,
        "intro": ["Bm", "G", "Em", "F#"],
        "A": ["Bm", "G", "D", "A", "Bm", "G", "Em", "F#"],
        "B": ["G", "A", "D", "Bm", "G", "A", "Em", "F#"],
        "outro": ["Bm", "G", "Em", "F#"],
        "melody_A": ["F#5:2 D5:2 r4", "B4:4 r4", "A5:2 F#5:2 r4", "E5:6 r2",
                     "F#5:2 B5:2 r4", "G5:4 r2 F#5:2", "E5:2 G5:2 B5:2 E5:2", "C#5:8"],
        "melody_B": ["D5:4 G5:4", "F#5:4 E5:2 C#5:2", "D5:6 F#5:2", "B4:8",
                     "D5:2 G5:2 B5:4", "A5:4 E5:2 C#6:2", "B5:3 G5:1 E5:4", "F#5:6 r2"],
        "leads": {"A": "piano", "B": "violins", "C": "piano"},
        "lead_dynamics": {5: "p", 13: "mp", 21: "pp"},
        # Harpe clairsemee : une note par temps, et des trous.
        "accomp": ("harp", [0, 2, 3, 1], 2, 4),
        "accomp_dynamics": {5: "pp", 13: "p", 29: "pp"},
        "pad": ("violins", 12),
        "bass": ("cellos", "held"),
        "extras": [("vibraphone", vibes, {5: "p", 21: "pp"}, -7.0, 0.4)],
    })


# --- Dimanche : Angoisse, puis l'aube -----------------------------------------------------------

def dimanche():
    chords = {
        "Cm": (["C3", "G3", "C4", "Eb4", "G4"], ["C4", "Eb4", "G4"], "C2"),
        "Ab": (["Ab2", "Eb3", "Ab3", "C4", "Eb4"], ["C4", "Eb4", "Ab4"], "Ab1"),
        "Fm": (["F2", "C3", "F3", "Ab3", "C4"], ["C4", "F4", "Ab4"], "F2"),
        "G": (["G2", "D3", "G3", "B3", "D4"], ["B3", "D4", "G4"], "G1"),
        "Db": (["Db3", "Ab3", "Db4", "F4", "Ab4"], ["Db4", "F4", "Ab4"], "Db2"),
        "Bb": (["Bb2", "F3", "Bb3", "D4", "F4"], ["D4", "F4", "Bb4"], "Bb1"),
        "Eb": (["Eb3", "Bb3", "Eb4", "G4", "Bb4"], ["Eb4", "G4", "Bb4"], "Eb2"),
        "F": (["F2", "C3", "F3", "A3", "C4"], ["C4", "F4", "A4"], "F2"),
        "C": (["C3", "G3", "C4", "E4", "G4"], ["C4", "E4", "G4"], "C2"),
        "Am": (["A2", "E3", "A3", "C4", "E4"], ["C4", "E4", "A4"], "A1"),
        "Em": (["E2", "B2", "E3", "G3", "B3"], ["B3", "E4", "G4"], "E2"),
    }
    # Le coeur bat (deux coups) pendant l'angoisse, et se calme a l'aube.
    heart = "C3:1a C3:1 r6"
    beats = [heart] * 20 + [REST] * 8 + [heart] * 4
    return piece({
        "title": "Dimanche - Aube", "tempo": 60, "fifths": -3, "chords": chords,
        "intro": ["Cm", "Ab", "Fm", "G"],
        "A": ["Cm", "Ab", "Fm", "G", "Cm", "Ab", "Db", "G"],
        "B": ["Ab", "Bb", "Eb", "Cm", "Ab", "Bb", "F", "G"],
        # L'aube : le meme chemin, en majeur.
        "C": ["C", "Am", "F", "G", "C", "Em", "F", "G"],
        "outro": ["Cm", "Ab", "Fm", "G"],
        "melody_A": ["G4:2 C5:2 Eb5:4", "Eb5:3 D5:1 C5:4", "F5:2 Ab5:2 C6:4", "B4:6 r2",
                     "G4:2 C5:2 Eb5:2 G5:2", "Ab5:4 G5:2 Eb5:2", "F5:3 Eb5:1 Db5:4", "D5:4 B4:4"],
        "melody_B": ["C5:2 Eb5:2 Ab5:4", "Bb5:3 Ab5:1 F5:4", "G5:2 Bb5:2 Eb6:4", "D6:4 C6:4",
                     "Ab5:2 C6:2 Eb6:4", "D6:3 C6:1 Bb5:4", "Ab5:2 C6:2 F6:4", "D6:4 B5:4"],
        "melody_C": ["G3:2 C4:2 E4:4", "E4:3 D4:1 C4:4", "F4:2 A4:2 C5:4", "B4:6 r2",
                     "G4:2 C5:2 E5:4", "D5:4 B4:2 G4:2", "A4:3 G4:1 F4:4", "D4:4 B3:4"],
        "leads": {"A": "piano", "B": "violins", "C": "horns"},
        "lead_dynamics": {5: "p", 13: "mf", 21: "mp"},
        "accomp": ("harp", [0, 1, 2, 3, 4, 3, 2, 1], 1, 0),
        "pad": ("choir", 4),
        "bass": ("cellos", "held"),
        "extras": [("timpani", beats, {1: "p", 13: "mp", 29: "p"}, -9.0, 0.0)],
    })


NIGHTS = {
    "nuit_lundi": lundi, "nuit_mardi": mardi, "nuit_mercredi": mercredi, "nuit_jeudi": jeudi,
    "nuit_vendredi": vendredi, "nuit_samedi": samedi, "nuit_dimanche": dimanche,
}
