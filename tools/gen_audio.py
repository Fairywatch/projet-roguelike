"""Synthetise les effets sonores et les musiques du jeu (style chiptune reveur).

Lancer depuis la racine du projet : python tools/gen_audio.py
Ecrit des WAV 16 bits mono dans assets/audio/{sfx,music}/. Comme pour le pixel art, les
fichiers peuvent ensuite etre remplaces par de vrais sons ; relancer le script les ecrase.
Les musiques sont des boucles : leur import Godot est regle en boucle (voir LOOP_IMPORT).
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

def sfx():
    s = {}
    n = noise(0.12)
    s["slash"] = lowpass(n, 3500) * env(len(n), 0.003, curve=5) + osc(glide(900, 300, 0.12), 0.12, "sine") * env(len(n), curve=6) * 0.3
    x = osc(glide(180, 55, 0.14), 0.14, "sine")
    s["hit"] = x * env(len(x), 0.001, curve=4) + lowpass(noise(0.14), 1200) * env(len(x), curve=10) * 0.6
    s["crit"] = mix(s["hit"], note(midi(88), 0.25, "square", curve=5, vol=0.35))
    x = osc(glide(520, 140, 0.3), 0.3, "square")
    s["hurt"] = x * env(len(x), curve=3) * (1 + 0.3 * np.sin(2 * np.pi * 30 * t_axis(0.3)))
    n = noise(0.2)
    s["dash"] = lowpass(n, 2000) * np.sin(np.linspace(0, np.pi, len(n))) * 0.7
    s["telegraph"] = note(glide(600, 900, 0.1), 0.1, "square", curve=2, vol=0.5)
    x = osc(glide(700, 90, 0.25), 0.25, "square")
    s["mob_die"] = x * env(len(x), curve=4) * 0.6 + lowpass(noise(0.25), 800) * env(len(x), curve=8) * 0.5
    s["shoot"] = note(glide(900, 400, 0.08), 0.08, "square", curve=3, vol=0.4)
    s["pickup"] = echo(seq(*[note(midi(m), 0.07, "square", curve=3, vol=0.5) for m in (72, 76, 79, 84)]), 0.09, 0.3, 2)
    s["chest"] = echo(mix(note(midi(67), 0.4, "triangle", curve=3), at(note(midi(74), 0.5, "triangle", curve=3), 0.1, 0.6),
                          at(note(midi(79), 0.5, "sine", curve=3, vol=0.6), 0.2, 0.7)), 0.12, 0.3, 2)
    x = osc(glide(55, 40, 1.2), 1.2, "saw")
    s["boss"] = lowpass(x, 400) * env(len(x), 0.05, curve=2) + note(midi(49), 1.2, "square", 0.05, 2, 0.25) + note(midi(50), 1.2, "square", 0.05, 2, 0.25)
    s["portal"] = echo(note(glide(200, 800, 0.5), 0.5, "sine", 0.05, 2), 0.1, 0.4, 3)
    x = osc(glide(300, 900, 0.45), 0.45, "triangle")
    s["encounter"] = x * env(len(x), 0.02, curve=2) * (1 + 0.5 * np.sin(2 * np.pi * 18 * t_axis(0.45)))
    s["ui_move"] = note(midi(84), 0.04, "square", curve=4, vol=0.3)
    s["ui_select"] = seq(note(midi(79), 0.05, "square", curve=3, vol=0.4), note(midi(86), 0.08, "square", curve=3, vol=0.4))
    s["active"] = echo(mix(note(midi(81), 0.6, "sine", curve=3), note(midi(88), 0.6, "sine", curve=3, vol=0.5)), 0.15, 0.35, 3)
    s["heal"] = echo(seq(note(midi(76), 0.1, "sine", vol=0.6), note(midi(83), 0.2, "sine", vol=0.6)), 0.1, 0.3, 2)
    s["dodge"] = note(glide(1200, 2000, 0.08), 0.08, "sine", curve=3, vol=0.4)
    s["shield"] = echo(note(midi(91), 0.3, "triangle", curve=4), 0.07, 0.4, 3)
    s["decor"] = note(midi(79) * (1 + 0.02 * np.sin(2 * np.pi * 8 * t_axis(0.15))), 0.15, "sine", curve=4, vol=0.4)
    s["sparkle"] = echo(seq(*[note(midi(m), 0.05, "sine", vol=0.4) for m in (84, 88, 91, 96)]), 0.06, 0.4, 3)
    s["pop"] = note(glide(1400, 600, 0.05), 0.05, "sine", curve=5)
    s["victory"] = echo(seq(*[note(midi(m), d, "square", curve=2.5, vol=0.5) for m, d in ((72, 0.1), (76, 0.1), (79, 0.1), (84, 0.35))]), 0.12, 0.25, 2)
    s["death"] = echo(seq(*[note(midi(m), 0.25, "triangle", curve=2) for m in (67, 63, 60, 55)]), 0.2, 0.3, 2)
    s["quest"] = echo(seq(note(midi(74), 0.12, "triangle"), note(midi(79), 0.2, "triangle")), 0.1, 0.3, 2)
    s["coin"] = seq(note(midi(88), 0.05, "square", vol=0.4), note(midi(95), 0.15, "square", curve=4, vol=0.4))
    for name, x in s.items():
        save(x, "sfx", f"{name}.wav")


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


def music_combat(bpm=132, root=57, minor=True, total_bars=8, heavy=False):
    """Combat : basse pulsee, arpege rapide. heavy=True pour les boss."""
    beat = 60 / bpm
    bar = beat * 4
    total = bar * total_bars
    out = np.zeros(int(RATE * total))
    third = 3 if minor else 4
    progression = [0, 0, -4, -2, 0, 0, -5, -2] if not heavy else [0, 1, 0, -2, 0, 1, 3, -1]
    for b in range(total_bars):
        r = root + progression[b % len(progression)]
        start = b * bar
        for k in range(8):
            out += at(note(midi(r - 12), beat / 2 * 0.9, "square", curve=5, vol=0.35 if not heavy else 0.45), start + k * beat / 2, total)
        arp = [r, r + third, r + 7, r + 12]
        for k in range(16):
            out += at(note(midi(arp[k % 4] + 12), beat / 4 * 0.9, "triangle", curve=4, vol=0.18), start + k * beat / 4, total)
        for k in range(4):
            kick = osc(glide(120, 45, 0.12), 0.12, "sine") * env(int(RATE * 0.12), 0.001, curve=5) * 0.6
            out += at(kick, start + k * beat, total)
            if heavy or k % 2 == 1:
                hat = lowpass(noise(0.05), 6000) * env(int(RATE * 0.05), curve=8) * 0.15
                out += at(hat, start + k * beat + beat / 2, total)
    return out


LOOP_IMPORT = ["reve", "profond", "combat", "boss"]


def main():
    sfx()
    save(music_reve(), "music", "reve.wav", peak=0.6)
    save(music_profond(), "music", "profond.wav", peak=0.6)
    save(music_combat(), "music", "combat.wav", peak=0.6)
    save(music_combat(bpm=146, root=52, heavy=True), "music", "boss.wav", peak=0.6)


if __name__ == "__main__":
    main()
