"""Musiques originales du jeu : partitions ecrites ici, jouees par MuseScore 4 (Muse Sounds).

Lancer depuis la racine du projet : python tools/compose_music.py [morceau...]
Pour chaque morceau : ecrit music/<nom>.musicxml (a ouvrir et retoucher dans MuseScore), fait
jouer chaque instrument a part par MuseScore, les mixe (volume et panoramique par partie, voir
"parts"), puis replie la queue de reverb sur le debut pour une boucle sans coupure :
assets/audio/music/<nom>.wav. Si un music/<nom>.mscz existe (partition retouchee dans MuseScore),
c'est lui qui est joue, avec le mixage regle dans MuseScore.
"""
import array
import os
import struct
import subprocess
import sys
import tempfile
import wave

ROOT = os.path.join(os.path.dirname(__file__), "..")
SCORE_DIR = os.path.join(ROOT, "music")
OUT_DIR = os.path.join(ROOT, "assets", "audio", "music")
MUSESCORE = r"C:\Program Files\MuseScore 4\bin\MuseScore4.exe"

DIVISIONS = 2  # duree en croches : 1 croche, 2 noire, 4 blanche, 8 ronde
TYPES = {1: ("eighth", False), 2: ("quarter", False), 3: ("quarter", True), 4: ("half", False),
         6: ("half", True), 8: ("whole", False)}
MEASURE = 8  # 4/4
PEAK = 0.7  # volume normalise (crete a -3 dB)

# instrument -> (nom, son MuseScore, clef)
INSTRUMENTS = {
    "piano": ("Piano", "keyboard.piano", ("G", 2)),
    "harp": ("Harp", "pluck.harp", ("G", 2)),
    "violins": ("Violins", "strings.violin", ("G", 2)),
    "cellos": ("Violoncellos", "strings.cello", ("F", 4)),
    "celesta": ("Celesta", "keyboard.celesta", ("G", 2)),
    "violas": ("Violas", "strings.viola", ("C", 3)),
    "choir": ("Choir", "voice.aahs", ("G", 2)),
}
# Instruments installes en Muse Sounds (les autres sonnent avec la banque de base, bien moins
# belle) : piano, celesta, harpe, violons, altos, violoncelles, contrebasses, choeur.


def pitch_xml(name):
    step, rest = name[0], name[1:]
    alter = 0
    while rest and rest[0] in "#b":
        alter += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    alter_xml = f"<alter>{alter}</alter>" if alter else ""
    return f"<pitch><step>{step}</step>{alter_xml}<octave>{rest}</octave></pitch>"


def note_xml(pitches, dur):
    kind, dotted = TYPES[dur]
    dot = "<dot/>" if dotted else ""
    if not pitches:
        return f"<note><rest/><duration>{dur}</duration><type>{kind}</type>{dot}</note>"
    out = []
    for i, p in enumerate(pitches):
        chord = "<chord/>" if i else ""
        out.append(f"<note>{chord}{pitch_xml(p)}<duration>{dur}</duration><type>{kind}</type>{dot}</note>")
    return "".join(out)


def parse_measure(text):
    """'r2 A4:1 D5:1 F5,A5:4' -> [(pitches, duree)] ; r = silence, virgule = accord."""
    events = []
    for token in text.split():
        if token.startswith("r"):
            events.append(([], int(token[1:])))
        else:
            notes, dur = token.split(":")
            events.append((notes.split(","), int(dur)))
    total = sum(d for _, d in events)
    assert total == MEASURE, f"mesure de {total} croches : {text}"
    return events


def score_xml(piece, only=None):
    """Partition entiere, ou seulement la partie numero `only` (une piste du mixage)."""
    parts = [(inst, measures) for i, (inst, measures, *_) in enumerate(piece["parts"]) if only in (None, i)]
    head =['<?xml version="1.0" encoding="UTF-8"?>',
            '<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" '
            '"http://www.musicxml.org/dtds/partwise.dtd">',
            '<score-partwise version="4.0">',
            f'<work><work-title>{piece["title"]}</work-title></work>', "<part-list>"]
    for i, (inst, _) in enumerate(parts):
        name, sound, _ = INSTRUMENTS[inst]
        head.append(f'<score-part id="P{i}"><part-name>{name}</part-name><score-instrument id="P{i}-I1">'
                    f'<instrument-name>{name}</instrument-name><instrument-sound>{sound}</instrument-sound>'
                    f'</score-instrument></score-part>')
    head.append("</part-list>")
    body = []
    for i, (inst, measures) in enumerate(parts):
        sign, line = INSTRUMENTS[inst][2]
        body.append(f'<part id="P{i}">')
        for m, (text, dynamic) in enumerate(measures):
            body.append(f'<measure number="{m + 1}">')
            if m == 0:
                body.append(f'<attributes><divisions>{DIVISIONS}</divisions><key><fifths>{piece["fifths"]}</fifths></key>'
                            f'<time><beats>4</beats><beat-type>4</beat-type></time>'
                            f'<clef><sign>{sign}</sign><line>{line}</line></clef></attributes>')
                body.append(f'<direction placement="above"><direction-type><metronome><beat-unit>quarter</beat-unit>'
                            f'<per-minute>{piece["tempo"]}</per-minute></metronome></direction-type>'
                            f'<sound tempo="{piece["tempo"]}"/></direction>')
            if dynamic:
                body.append(f'<direction placement="below"><direction-type><dynamics><{dynamic}/></dynamics>'
                            f'</direction-type></direction>')
            body.extend(note_xml(p, d) for p, d in parse_measure(text))
            body.append("</measure>")
        body.append("</part>")
    return "\n".join(head + body + ["</score-partwise>"])


def read_float_wav(path):
    """WAV 32 bits flottants (ce qu'exporte MuseScore ; le module wave ne le lit pas)."""
    data = open(path, "rb").read()
    pos, channels, rate, samples = 12, 2, 44100, None
    while pos < len(data):
        chunk, size = data[pos:pos + 4], struct.unpack("<I", data[pos + 4:pos + 8])[0]
        if chunk == b"fmt ":
            fmt, channels, rate = struct.unpack("<HHI", data[pos + 8:pos + 16])
            assert fmt == 3, f"format WAV inattendu : {fmt}"
        elif chunk == b"data":
            samples = array.array("f", data[pos + 8:pos + 8 + size])
        pos += 8 + size + (size & 1)
    return channels, rate, samples


def render(source, wav):
    subprocess.run([MUSESCORE, "-o", wav, source], check=True, capture_output=True)
    return read_float_wav(wav)


def mix(stems):
    """stems : [(echantillons stereo, volume en dB, panoramique de -1 gauche a 1 droite)]."""
    out = array.array("f", bytes(4 * max(len(s) for s, _, _ in stems)))
    for samples, db, pan in stems:
        gain = 10 ** (db / 20)
        left, right = gain * min(1.0, 1.0 - pan), gain * min(1.0, 1.0 + pan)
        for i in range(0, len(samples) - 1, 2):
            out[i] += samples[i] * left
            out[i + 1] += samples[i + 1] * right
    return out


def write_loop(path, samples, channels, rate, seconds):
    """Coupe a la longueur exacte du morceau, ajoute ce qui depasse (reverb) au debut, normalise, 16 bits."""
    length = int(seconds * rate) * channels
    looped = samples[:length]
    for i, v in enumerate(samples[length:length * 2]):
        looped[i] += v
    gain = PEAK / max(abs(v) for v in looped)  # MuseScore exporte tres bas
    pcm = array.array("h", (max(-32768, min(32767, int(v * gain * 32767))) for v in looped))
    with wave.open(path, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm.tobytes())


def build(name, piece):
    os.makedirs(SCORE_DIR, exist_ok=True)
    xml_path = os.path.join(SCORE_DIR, name + ".musicxml")
    with open(xml_path, "w", encoding="utf-8") as f:
        f.write(score_xml(piece))
    mscz = os.path.join(SCORE_DIR, name + ".mscz")
    with tempfile.TemporaryDirectory() as tmp:
        if os.path.exists(mscz):  # retouches faites dans MuseScore : son propre mixage
            channels, rate, samples = render(mscz, os.path.join(tmp, "all.wav"))
        else:  # une piste par instrument, mixees ici (volume et panoramique de chaque partie)
            stems = []
            for i, (inst, _, db, pan) in enumerate(piece["parts"]):
                stem_xml = os.path.join(tmp, f"{inst}.musicxml")
                with open(stem_xml, "w", encoding="utf-8") as f:
                    f.write(score_xml(piece, only=i))
                channels, rate, samples = render(stem_xml, os.path.join(tmp, f"{inst}.wav"))
                stems.append((samples, db, pan))
            samples = mix(stems)
    out = os.path.join(OUT_DIR, name + ".wav")
    bars = len(piece["parts"][0][1])
    write_loop(out, samples, channels, rate, bars * 4 * 60.0 / piece["tempo"])
    print(f"{name} -> {out}")


# --- Partitions -------------------------------------------------------------------------------

# Accords de Reverie : arpege de harpe (5 notes montantes), nappe de cordes, basse de violoncelle.
REVE_CHORDS = {
    "Dm9": (["D3", "A3", "D4", "E4", "F4"], ["D4", "F4", "A4"], "D2"),
    "Bbmaj7": (["Bb2", "F3", "Bb3", "D4", "A4"], ["D4", "F4", "A4"], "Bb2"),
    "F/A": (["A2", "F3", "C4", "F4", "A4"], ["C4", "F4", "A4"], "A2"),
    "C": (["C3", "G3", "C4", "E4", "G4"], ["E4", "G4", "C5"], "C2"),
    "Gm7": (["G2", "D3", "F3", "Bb3", "D4"], ["D4", "F4", "Bb4"], "G2"),
    "Asus4": (["A2", "E3", "A3", "D4", "E4"], ["D4", "E4", "A4"], "A2"),
    "A": (["A2", "E3", "A3", "C#4", "E4"], ["C#4", "E4", "A4"], "A2"),
    "Am7": (["A2", "E3", "G3", "C4", "E4"], ["C4", "E4", "G4"], "A2"),
    "Gm": (["G2", "D3", "G3", "Bb3", "D4"], ["D4", "G4", "Bb4"], "G2"),
    "F": (["F2", "C3", "F3", "A3", "C4"], ["C4", "F4", "A4"], "F2"),
    "Bb": (["Bb2", "F3", "Bb3", "D4", "F4"], ["D4", "F4", "Bb4"], "Bb2"),
}
REST = "r8"


def arpeggio(notes, pattern, dur):
    """Une mesure d'arpege : les notes de `notes` dans l'ordre de `pattern`, chacune de `dur` croches."""
    return " ".join(f"{notes[i]}:{dur}" for i in pattern)


def held(notes):
    """Une mesure tenue : accord (ou note seule) en ronde."""
    return ",".join(notes) + ":8"


def with_dynamics(measures, dynamics):
    return [(m, dynamics.get(i + 1)) for i, m in enumerate(measures)]


def reve():
    """Reverie : menu et etages du sommeil paradoxal. Lent, mysterieux, comme une berceuse."""
    a = ["Dm9", "Bbmaj7", "F/A", "C", "Dm9", "Bbmaj7", "Gm7", "A"]
    c = ["Bb", "C", "Am7", "Dm9", "Gm", "C", "F", "A"]
    d = ["Dm9", "Bbmaj7", "Gm7", "A", "Dm9", "Bbmaj7", "Gm7", "Asus4"]
    chords = a + a + c + d
    arp, pad, bass = ([REVE_CHORDS[ch][i] for ch in chords] for i in range(3))
    melody = [REST] * 8 + [
        "r2 A4:2 D5:2 E5:2", "F5:6 E5:2", "D5:2 C5:2 A4:4", "G4:6 r2",
        "r2 A4:2 D5:2 F5:2", "G5:4 F5:2 D5:2", "E5:2 D5:2 Bb4:2 A4:2", "A4:8",
        "D5:2 F5:2 A5:4", "G5:6 E5:2", "E5:4 C5:2 D5:2", "A4:8",
        "Bb4:2 D5:2 G5:4", "E5:6 C5:2", "F5:2 E5:2 F5:2 A5:2", "E5:4 C#5:4",
        "r4 A4:2 D5:2", "F5:8", "E5:4 D5:4", "C#5:8",
    ] + [REST] * 4
    sparkle = ["r2 A5:1 D6:1 F6:4", "E6:4 D6:2 r2", "r4 D6:2 Bb5:2", "C#6:4 r4"]
    celesta = [REST] * 4 + sparkle + [REST] * 20 + sparkle
    cellos = [REST] * 4 + [held([b]) for b in bass[4:28]] + [REST] * 4
    return {
        "title": "Reverie", "tempo": 66, "fifths": -1,
        # (instrument, mesures, volume en dB, panoramique) : le piano reste en retrait, dans le decor.
        "parts": [
            ("piano", with_dynamics(melody, {9: "p", 17: "mp", 25: "p"}), -7.0, 0.0),
            ("celesta", with_dynamics(celesta, {5: "pp"}), 8.0, 0.35),  # tres doux a l'export
            ("harp", with_dynamics([arpeggio(n, [0, 1, 2, 3, 4, 3, 2, 1], 1) for n in arp], {1: "pp", 9: "p", 17: "mp", 25: "p", 29: "pp"}), 0.0, -0.25),
            ("violins", with_dynamics([held(n) for n in pad], {1: "pp", 17: "p", 25: "pp"}), -4.0, -0.15),
            ("cellos", with_dynamics(cellos, {5: "pp", 17: "p", 25: "pp"}), -2.0, 0.2),
        ],
    }


# Accords de Profond : battement de harpe (grave, medium, aigu), choeur, basse de violoncelle.
PROFOND_CHORDS = {
    "Cm": (["C3", "G3", "Eb4"], ["C4", "Eb4", "G4"], "C2"),
    "Ab": (["Ab2", "Eb3", "C4"], ["C4", "Eb4", "Ab4"], "Ab2"),
    "Fm": (["F2", "C3", "Ab3"], ["C4", "F4", "Ab4"], "F2"),
    "Db": (["Db3", "Ab3", "F4"], ["Db4", "F4", "Ab4"], "Db2"),
    "Bb": (["Bb2", "F3", "D4"], ["D4", "F4", "Bb4"], "Bb2"),
    "Gsus": (["G2", "D3", "C4"], ["C4", "D4", "G4"], "G2"),
    "G": (["G2", "D3", "B3"], ["B3", "D4", "G4"], "G2"),
}


def profond():
    """Profond : etages du sommeil profond. Plus lent et plus sombre que Reverie, un peu oppressant :
    bourdon grave, harpe qui bat comme un coeur, soupirs des altos, choeur. A la fin, le piano
    reprend le theme de Reverie en mineur, comme si le reve s'enfoncait."""
    a = ["Cm", "Cm", "Ab", "Ab", "Fm", "Fm", "Db", "Gsus"]
    b = ["Cm", "Ab", "Fm", "Db", "Cm", "Ab", "Fm", "G"]
    c = ["Ab", "Bb", "Cm", "Cm", "Db", "Db", "Gsus", "G"]
    d = ["Cm", "Ab", "Fm", "Db", "Cm", "Cm", "Db", "G"]
    chords = a + b + c + d
    beat, choir, bass = ([PROFOND_CHORDS[ch][i] for ch in chords] for i in range(3))
    piano = [REST] * 4 + ["r4 C6:4", "Ab5:8", "r4 F5:4", "G5:4 r4"] + [REST] * 16 + [
        "r2 G4:2 C5:2 D5:2", "Eb5:6 D5:2", "C5:2 Bb4:2 Ab4:4", "F4:6 r2",  # theme de Reverie, en mineur
        "r4 G5:4", "Eb5:8", REST, "r4 D5:2 B4:2",
    ]
    sighs = ["Eb4:4 D4:4", "C4:4 Bb3:4", "Ab3:4 G3:4", "F3:8", "Eb4:4 D4:4", "Eb4:4 C4:4", "C4:4 Ab3:4", "B3:8"]
    violas = [REST] * 8 + sighs + [REST] * 16
    violins = [REST] * 16 + ["C6:8", "D6:8", "Eb6:8", "D6:8", "F6:8", "Eb6:8", "D6:8", "B5:8"] + [REST] * 8
    return {
        "title": "Profond", "tempo": 54, "fifths": -3,
        "parts": [
            ("piano", with_dynamics(piano, {5: "pp", 25: "p", 29: "pp"}), -3.0, 0.1),
            ("harp", with_dynamics([arpeggio(n, [0, 1, 2, 1], 2) for n in beat], {1: "p", 17: "mp", 25: "p"}), 0.0, -0.3),
            ("choir", with_dynamics([REST] * 4 + [held(n) for n in choir[4:]], {5: "pp", 17: "p", 25: "pp"}), -1.0, 0.0),
            ("violas", with_dynamics(violas, {9: "p"}), -5.0, 0.25),
            ("violins", with_dynamics(violins, {17: "pp"}), 0.0, -0.2),
            ("cellos", with_dynamics([held([n]) for n in bass], {1: "p", 17: "mp", 25: "p"}), -8.0, 0.15)  # bourdon : present sans couvrir,
        ],
    }


PIECES = {"reve": reve, "profond": profond}

if __name__ == "__main__":
    for name in sys.argv[1:] or PIECES:
        build(name, PIECES[name]())
