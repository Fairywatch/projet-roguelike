"""Synthetise les effets sonores et les musiques du jeu (style chiptune reveur).

Lancer depuis la racine du projet : python tools/gen_audio.py
Ecrit des WAV 16 bits mono dans assets/audio/{sfx,music}/. Comme pour le pixel art, les
fichiers peuvent ensuite etre remplaces par de vrais sons ; relancer le script les ecrase.
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


# --- Effets sonores -------------------------------------------------------------

def stinger(chord, swell, tail, drop=False):
    """Coup de theatre : souffle inverse qui monte, impact grave, accord de cuivres
    tremolo qui s'eteint (et plonge d'un demi-ton si drop)."""
    total = swell + tail
    n = noise(swell)
    rise = lowpass(n, 2500) * np.linspace(0, 1, len(n)) ** 3 * 0.8
    brass_f = [midi(m) * (np.geomspace(1, 0.944, int(RATE * tail)) if drop else 1) for m in chord]
    brass = sum(supersaw(f, tail) for f in brass_f) / len(chord)
    brass = lowpass(brass, 1800) * env(int(RATE * tail), 0.01, curve=2.5)
    brass *= 1 + 0.35 * np.sin(2 * np.pi * 11 * t_axis(tail))
    hit = mix(boom(min(tail, 1.2)), brass * 0.9)
    return echo(mix(at(rise, 0, total), at(hit, swell, total)), 0.22, 0.3, 2)


# Style des effets : organique et etouffe (facon The Binding of Isaac) plutot que des "bips"
# synthetiques. Des "plop", "splat" et coups sourds, tres courts, filtres sous ~1500 Hz.
# Les evenements tres frequents (telegraphes, survol des menus, decors) n'ont pas de son.
SFX_PEAKS = {
    "slash": 0.12, "hit": 0.22, "crit": 0.26, "hurt": 0.28, "dash": 0.08, "mob_die": 0.22,
    "shoot": 0.1, "pickup": 0.22, "chest": 0.25, "boss": 0.38, "portal": 0.2, "encounter": 0.32,
    "ui_select": 0.12, "active": 0.22, "heal": 0.2, "dodge": 0.1, "shield": 0.18, "sparkle": 0.15,
    "pop": 0.14, "victory": 0.24, "death": 0.28, "quest": 0.2, "coin": 0.18,
}


def soft(x, cutoff=1500):
    """Etouffe le son : c'est surtout l'aigu qui rend un effet agressif. Trois filtres en
    cascade (pente raide) : un seul laisse passer trop d'aigu sur du bruit."""
    return lowpass(lowpass(lowpass(x, cutoff), cutoff), cutoff)


def thud(duration=0.08, f0=120, f1=55, body=0.6):
    """Coup sourd : un sinus grave qui plonge, avec un peu de souffle etouffe."""
    x = osc(glide(f0, f1, duration), duration, "sine") * env(int(RATE * duration), 0.002, curve=6)
    return x + soft(noise(duration), 1400) * env(int(RATE * duration), 0.001, curve=14) * body


def splat(duration=0.16, cutoff=900):
    """Eclaboussure organique : bruit filtre dont le filtre se referme, sur un coup sourd."""
    n = noise(duration)
    closing = soft(n, cutoff) * env(len(n), 0.002, curve=7)
    return mix(closing, thud(duration * 0.7, 100, 45) * 0.8)


def plop(f0=420, f1=180, duration=0.06):
    """Goutte / bulle : sinus qui descend vite (tir des larmes d'Isaac)."""
    return osc(glide(f0, f1, duration), duration, "sine") * env(int(RATE * duration), 0.003, curve=5)


def chime(midi_note, duration=0.35, vol=1.0):
    """Clochette douce : fondamentale et une harmonique discrete, sans attaque seche."""
    t = t_axis(duration)
    f = midi(midi_note)
    x = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2.01 * f * t)
    return x * env(len(t), 0.006, curve=5) * vol


def sfx():
    s = {}
    n = noise(0.07)
    s["slash"] = soft(n, 700) * np.sin(np.linspace(0, np.pi, len(n))) ** 2
    s["hit"] = thud(0.09, 200, 90, 0.9)
    s["crit"] = mix(thud(0.12, 150, 50, 0.9), chime(72, 0.15, 0.25))
    x = osc(glide(210, 140, 0.16), 0.16, "saw")
    s["hurt"] = soft(x * env(len(x), 0.004, curve=4) * (1 + 0.15 * np.sin(2 * np.pi * 9 * t_axis(0.16))), 650)
    n = noise(0.12)
    s["dash"] = soft(n, 500) * np.sin(np.linspace(0, np.pi, len(n)))
    s["mob_die"] = splat(0.2, 1100)
    s["shoot"] = plop(380, 170, 0.05)
    s["pickup"] = mix(plop(300, 520, 0.05), at(chime(76, 0.3, 0.5), 0.04, 0.34))
    s["chest"] = mix(thud(0.12, 90, 50, 1.0), at(chime(72, 0.4, 0.4), 0.08, 0.48), at(chime(79, 0.4, 0.3), 0.16, 0.56))
    s["boss"] = soft(mix(stinger(chord=(38, 41, 44, 50, 51), swell=0.7, tail=2.2, drop=True),
                         at(echo(chime(62, 1.6, 0.35) + chime(69, 1.6, 0.2), 0.3, 0.35, 2), 0.7, 3.5)), 1300)
    n = noise(0.4)
    s["portal"] = soft(n, 600) * np.sin(np.linspace(0, np.pi, len(n))) + plop(160, 320, 0.4) * 0.4
    s["encounter"] = soft(stinger(chord=(50, 53, 56, 62), swell=0.45, tail=1.3), 1300)
    s["ui_select"] = mix(thud(0.04, 260, 180, 0.3), chime(79, 0.08, 0.3))
    s["active"] = mix(thud(0.1, 110, 60, 0.4), at(echo(chime(74, 0.4, 0.6), 0.12, 0.25, 2), 0.03, 0.8))
    s["heal"] = echo(seq(chime(72, 0.12, 0.6), chime(76, 0.22, 0.6)), 0.1, 0.2, 2)
    n = noise(0.08)
    s["dodge"] = soft(n, 1200) * np.sin(np.linspace(0, np.pi, len(n)))
    s["shield"] = mix(thud(0.08, 180, 120, 0.5), chime(84, 0.2, 0.35))
    s["sparkle"] = echo(seq(*[chime(m, 0.08, 0.4) for m in (76, 79, 83)]), 0.07, 0.2, 2)
    s["pop"] = plop(600, 250, 0.05)
    s["victory"] = echo(seq(chime(67, 0.12, 0.6), chime(72, 0.12, 0.6), chime(76, 0.35, 0.6)), 0.12, 0.2, 2)
    s["death"] = soft(echo(seq(*[note(midi(m), 0.3, "triangle", 0.01, 2) for m in (60, 56, 53, 48)]), 0.22, 0.25, 2), 900)
    s["quest"] = echo(seq(chime(69, 0.12, 0.6), chime(74, 0.22, 0.6)), 0.1, 0.2, 2)
    s["coin"] = seq(chime(79, 0.05, 0.5), chime(84, 0.15, 0.5))
    for name, x in s.items():
        save(x, "sfx", f"{name}.wav", peak=SFX_PEAKS[name])
    # Sons retires (evenements trop frequents) : on supprime les anciens fichiers.
    for name in ("telegraph", "ui_move", "decor"):
        for ext in (".wav", ".wav.import"):
            path = os.path.join(ROOT, "sfx", name + ext)
            if os.path.exists(path):
                os.remove(path)


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


def music_combat(bpm=132, root=57, total_bars=8):
    """Combat : basse pulsee, arpege rapide."""
    beat = 60 / bpm
    bar = beat * 4
    total = bar * total_bars
    out = np.zeros(int(RATE * total))
    third = 3
    progression = [0, 0, -4, -2, 0, 0, -5, -2]
    for b in range(total_bars):
        r = root + progression[b % len(progression)]
        start = b * bar
        for k in range(8):
            out += at(note(midi(r - 12), beat / 2 * 0.9, "square", curve=5, vol=0.35), start + k * beat / 2, total)
        arp = [r, r + third, r + 7, r + 12]
        for k in range(16):
            out += at(note(midi(arp[k % 4] + 12), beat / 4 * 0.9, "triangle", curve=4, vol=0.18), start + k * beat / 4, total)
        for k in range(4):
            kick = osc(glide(120, 45, 0.12), 0.12, "sine") * env(int(RATE * 0.12), 0.001, curve=5) * 0.6
            out += at(kick, start + k * beat, total)
            if k % 2 == 1:
                hat = lowpass(noise(0.05), 6000) * env(int(RATE * 0.05), curve=8) * 0.15
                out += at(hat, start + k * beat + beat / 2, total)
    return out


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



def main():
    sfx()
    save(music_reve(), "music", "reve.wav", peak=0.6)
    save(music_profond(), "music", "profond.wav", peak=0.6)
    save(music_combat(), "music", "combat.wav", peak=0.6)
    save(music_boss(), "music", "boss.wav", peak=0.6)


if __name__ == "__main__":
    main()
