"""Synthetise les musiques du jeu (boucles, style chiptune reveur).

Lancer depuis la racine du projet : python tools/gen_audio.py
Ecrit des WAV 16 bits mono dans assets/audio/music/ ; relancer le script les ecrase.
Les effets sonores sont des enregistrements CC0 importes par tools/import_sfx.py.
Les musiques sont des boucles : scripts/audio/sound.gd les fait boucler a la lecture.
"""
import os
import wave

import numpy as np

RATE = 22050
ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)


# --- Briques de synthese --------------------------------------------------------

def t_axis(duration):
    return np.arange(int(RATE * duration)) / RATE


def osc(freq, duration, shape="sine"):
    """freq : nombre ou tableau (glissando). Phase integree pour les frequences variables."""
    t = t_axis(duration)
    f = np.broadcast_to(np.asarray(freq, dtype=float), t.shape)
    phase = 2 * np.pi * np.cumsum(f) / RATE
    if shape == "sine":
        return np.sin(phase)
    if shape == "square":
        return np.sign(np.sin(phase)) * 0.6
    if shape == "triangle":
        return 2 / np.pi * np.arcsin(np.sin(phase))
    if shape == "saw":
        return 2 * ((phase / (2 * np.pi)) % 1.0) - 1
    raise ValueError(shape)


def noise(duration):
    return rng.uniform(-1, 1, int(RATE * duration))


def env(n, attack=0.005, release=None, curve=3.0):
    """Enveloppe attaque lineaire puis decroissance exponentielle."""
    t = np.arange(n) / RATE
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    total = n / RATE
    d = np.exp(-curve * np.clip(t - attack, 0, None) / max(total - attack, 1e-4))
    out = a * d
    if release:
        tail = int(release * RATE)
        out[-tail:] *= np.linspace(1, 0, tail)
    return out


def lowpass(x, cutoff):
    """Passe-bas simple a un pole (suffisant pour adoucir bruit et carres)."""
    alpha = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def supersaw(freq, duration, detune=0.012, voices=3):
    """Plusieurs dents de scie legerement desaccordees : son ample (cuivres, orgue, choeur)."""
    spread = np.linspace(-detune, detune, voices)
    return sum(osc(freq * (1 + d), duration, "saw") for d in spread) / voices


def boom(duration=0.9, f0=70, f1=32):
    """Coup grave (timbale / impact) : sinus qui plonge + souffle."""
    x = osc(glide(f0, f1, duration), duration, "sine")
    return x * env(len(x), 0.002, curve=4) + lowpass(noise(duration), 500) * env(len(x), 0.002, curve=12) * 0.5


def glide(f0, f1, duration):
    return np.geomspace(f0, f1, int(RATE * duration))


def note(freq, duration, shape="triangle", attack=0.005, curve=4.0, vol=1.0):
    x = osc(freq, duration, shape)
    return x * env(len(x), attack, curve=curve) * vol


def seq(*parts):
    return np.concatenate(parts)


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = np.zeros(n)
    for t in tracks:
        out[: len(t)] += t
    return out


def at(x, offset, total):
    out = np.zeros(int(RATE * total))
    start = int(RATE * offset)
    end = min(len(out), start + len(x))
    out[start:end] += x[: end - start]
    return out


def echo(x, delay=0.18, feedback=0.35, taps=3):
    out = np.copy(x)
    d = int(delay * RATE)
    out = np.concatenate([out, np.zeros(d * taps)])
    for k in range(1, taps + 1):
        out[d * k: d * k + len(x)] += x * feedback ** k
    return out


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def save(x, *parts, peak=0.8):
    x = np.asarray(x, dtype=float)
    m = np.max(np.abs(x)) or 1.0
    data = (x / m * peak * 32767).astype(np.int16)
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


# --- Musiques (boucles) -------------------------------------------------------------

def pad(chord, duration, shape="sine", vol=0.25):
    return mix(*[note(midi(m), duration, shape, attack=duration * 0.3, curve=1.5, vol=vol) for m in chord])


def music_reve():
    """Sommeil paradoxal et menu : accords de septieme majeure et arpege lumineux."""
    bar = 2.4
    chords = [(60, 64, 67, 71), (57, 60, 64, 67), (65, 69, 72, 76), (67, 71, 74, 77)]
    total = bar * len(chords) * 2
    out = np.zeros(int(RATE * total))
    for rep in range(2):
        for i, chord in enumerate(chords):
            start = (rep * len(chords) + i) * bar
            out += at(pad(chord, bar, "sine", 0.18), start, total)
            for k in range(8):
                m = chord[k % 4] + (12 if k >= 4 else 0)
                out += at(note(midi(m), 0.28, "triangle", curve=4, vol=0.22), start + k * bar / 8, total)
            out += at(note(midi(chord[0] - 24), bar, "sine", 0.05, 1.2, 0.3), start, total)
    return echo(out, 0.3, 0.3, 2)[: len(out)]


def music_profond():
    """Sommeil profond : bourdon grave mineur, cloches lentes et lointaines."""
    total = 19.2
    t = t_axis(total)
    drone = (np.sin(2 * np.pi * midi(38) * t) * 0.35 + np.sin(2 * np.pi * midi(45) * t) * 0.2
             + lowpass(osc(midi(26), total, "saw"), 200) * 0.25)
    drone *= 0.75 + 0.25 * np.sin(2 * np.pi * t / total * 2)
    out = drone
    for offset, m in ((0.0, 62), (2.4, 65), (4.8, 69), (7.2, 68), (9.6, 62), (12.0, 65), (14.4, 70), (16.8, 69)):
        out += at(note(midi(m), 2.2, "sine", 0.01, 3.5, 0.3), offset, total)
    return echo(out, 0.45, 0.35, 2)[: len(out)]


def pluck(freq, duration, brightness=3000, decay=0.996):
    """Corde pincee (Karplus-Strong) : une salve de bruit qui circule dans une boucle de la
    longueur de la periode et s'amortit, comme une vraie corde. Son naturel de harpe."""
    n = int(RATE * duration)
    period = max(2, int(RATE / freq))
    buf = list(lowpass(rng.uniform(-1, 1, period), brightness))
    out = np.zeros(n)
    for i in range(n):
        j = i % period
        out[i] = buf[j]
        buf[j] = decay * 0.5 * (buf[j] + buf[(j + 1) % period])
    return out * env(n, 0.002, curve=1.5)


def cello(freq, duration, vol=0.5):
    """Basse facon violoncelle : dents de scie adoucies, attaque lente, vibrato qui arrive."""
    t = t_axis(duration)
    vibrato = 1 + 0.004 * np.sin(2 * np.pi * 5 * t) * np.clip(t / 0.4, 0, 1)
    x = lowpass(lowpass(osc(freq * vibrato, duration, "saw"), 700), 700)
    shape = np.clip(t / 0.18, 0, 1) * np.clip((duration - t) / 0.25, 0, 1)
    return x * shape * vol


def flute(freq, duration, vol=0.4):
    """Flute : sinus et une harmonique douce, souffle filtre, vibrato retarde."""
    t = t_axis(duration)
    vibrato = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.15) / 0.3, 0, 1)
    x = osc(freq * vibrato, duration, "sine") + 0.15 * osc(2 * freq * vibrato, duration, "sine")
    breath = lowpass(lowpass(noise(duration), 2500), 2500) * 0.08
    shape = np.clip(t / 0.08, 0, 1) * np.clip((duration - t) / 0.15, 0, 1)
    return (x + breath) * shape * vol


def frame_drum(duration=0.4):
    x = osc(glide(110, 62, duration), duration, "sine") * env(int(RATE * duration), 0.002, curve=6)
    return x + lowpass(noise(duration), 900) * env(int(RATE * duration), 0.001, curve=14) * 0.3


def brush(duration=0.09):
    return lowpass(lowpass(noise(duration), 4000), 4000) * np.sin(np.linspace(0, np.pi, int(RATE * duration))) * 0.18


def music_combat():
    """Combat : tendu mais pas frenetique (104 BPM). Harpe pincee en croches, violoncelle,
    tambour sur cadre et balais ; une melodie de flute sur la deuxieme moitie. La mineur."""
    bpm = 104
    beat = 60 / bpm
    bar = beat * 4
    # La m | Fa | Do | Sol | La m | Fa | Re m | Mi  (Mi majeur : tension avant le retour)
    chords = [(57, 60, 64), (53, 57, 60), (48, 52, 55), (55, 59, 62),
              (57, 60, 64), (53, 57, 60), (50, 53, 57), (52, 56, 59)]
    melody = [  # (mesure, temps de depart, note, duree en temps) sur les mesures 8 a 15
        (8, 0, 76, 2), (8, 2, 74, 1), (8, 3, 72, 1), (9, 0, 72, 3), (9, 3, 69, 1),
        (10, 0, 71, 2), (10, 2, 72, 2), (11, 0, 74, 4),
        (12, 0, 76, 2), (12, 2, 77, 2), (13, 0, 76, 1.5), (13, 1.5, 74, 0.5), (13, 2, 72, 2),
        (14, 0, 74, 2), (14, 2, 71, 2), (15, 0, 68, 3), (15, 3, 71, 1),
    ]
    bars = 16
    total = bar * bars
    out = np.zeros(int(RATE * total))
    plucks = {}
    for b in range(bars):
        root, third, fifth = chords[b % len(chords)]
        start = b * bar
        out += at(cello(midi(root - 12), bar, 0.45), start, total)
        pattern = [root, third, fifth, root + 12, fifth + 12, root + 12, fifth, third]
        for k, m in enumerate(pattern):
            if m not in plucks:
                plucks[m] = pluck(midi(m), beat * 1.5)
            out += at(plucks[m] * 0.35, start + k * beat / 2, total)
        out += at(frame_drum() * 0.55, start, total)
        out += at(frame_drum() * 0.4, start + 2 * beat, total)
        if b % 2 == 1:  # petite relance du tambour une mesure sur deux
            out += at(frame_drum(0.25) * 0.25, start + 3.5 * beat, total)
        for k in range(4):
            out += at(brush(), start + k * beat + beat / 2, total)
    for b, t0, m, d in melody:
        out += at(flute(midi(m), d * beat * 0.95, 0.32), b * bar + t0 * beat, total)
    return echo(out, beat * 0.75, 0.2, 2)[: len(out)]


def music_boss():
    """Boss : piece a part, lente et solennelle. Ostinato grave chromatique, timbales,
    choeur/orgue sur Rem - Sib - Solm - La (mineur harmonique), theme lent au-dessus."""
    bpm = 96
    beat = 60 / bpm
    bar = beat * 4
    chords = [(50, 53, 57), (46, 50, 53), (43, 46, 50), (45, 49, 52)]  # Rem, Sib, Solm, La
    melody = [  # (demi-temps de depart, note midi, duree en temps), sur 2 mesures
        (0, 74, 1.5), (3, 77, 0.5), (4, 76, 1), (6, 74, 1), (8, 73, 3), (14, 69, 1),
    ]
    bars = 8
    total = bar * bars
    out = np.zeros(int(RATE * total))
    for b in range(bars):
        root, third, fifth = chords[b % len(chords)]
        start = b * bar
        # Choeur / orgue : accord tenu, ample.
        pad = sum(supersaw(midi(m), bar, 0.008) for m in (root, third, fifth, root + 12)) / 4
        out += at(lowpass(pad, 1100) * env(int(RATE * bar), bar * 0.25, curve=0.8) * 0.45, start, total)
        # Ostinato de basse chromatique en croches.
        for k, step in enumerate((0, 0, 1, 0, -1, 0, 1, 0)):
            out += at(lowpass(note(midi(root - 12 + step), beat / 2 * 0.95, "saw", curve=3, vol=0.5), 600), start + k * beat / 2, total)
        # Timbales sur les temps 1 et 3, roulement en fin de phrase.
        for k in (0, 2):
            out += at(boom(0.5, 90, 45) * 0.7, start + k * beat, total)
        if b % 4 == 3:
            for k in range(8):
                out += at(boom(0.15, 110, 70) * (0.25 + 0.05 * k), start + 2 * beat + k * beat / 4, total)
        # Cloche en debut de mesure paire.
        if b % 2 == 0:
            out += at(note(midi(root + 24), 1.5, "sine", 0.002, 3, 0.18), start, total)
    # Theme au-dessus (carre avec vibrato), une phrase sur deux mesures, jouee a partir de la mesure 3.
    for phrase in (2, 6):
        for half, m, dur in melody:
            t0 = phrase * bar + half * beat / 2
            d = dur * beat
            vib = midi(m) * (1 + 0.006 * np.sin(2 * np.pi * 5.5 * t_axis(d)))
            out += at(lowpass(note(vib, d, "square", 0.02, 1.5, 0.22), 2500), t0, total)
    return echo(out, beat * 0.75, 0.25, 2)[: len(out)]



# Une graine par morceau : retoucher un morceau ne change pas le bruit des autres.
TRACKS = [("reve", music_reve, 11), ("profond", music_profond, 12), ("combat", music_combat, 13), ("boss", music_boss, 14)]


def main():
    global rng
    for name, make, seed in TRACKS:
        rng = np.random.default_rng(seed)
        save(make(), "music", f"{name}.wav", peak=0.6)


if __name__ == "__main__":
    main()
