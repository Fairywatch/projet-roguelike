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


# Style des effets : clair, aerien et cristallin, facon Celeste. Cloches FM sur une gamme
# pentatonique (toujours consonantes entre elles), souffles de bruit dans un filtre qui balaie,
# petites reverberations pour l'espace, et 44,1 kHz pour la nettete.
# Les evenements tres frequents (telegraphes, survol des menus, decors) n'ont pas de son.
SFX_RATE = 44100
MUSIC_RATE = 22050
SFX_PEAKS = {
    "slash": 0.16, "hit": 0.24, "crit": 0.28, "hurt": 0.3, "dash": 0.16, "mob_die": 0.24,
    "shoot": 0.12, "pickup": 0.26, "chest": 0.28, "boss": 0.4, "portal": 0.24, "encounter": 0.36,
    "ui_select": 0.14, "active": 0.26, "heal": 0.24, "dodge": 0.14, "shield": 0.22, "sparkle": 0.2,
    "pop": 0.16, "victory": 0.28, "death": 0.3, "quest": 0.24, "coin": 0.22,
}
# Pentatonique de Re majeur (D E F# A B), sur plusieurs octaves : notes "cristal".
PENTA = [62, 64, 66, 69, 71, 74, 76, 78, 81, 83, 86, 88, 90, 93, 95]


def bell(midi_note, duration=0.5, vol=1.0, ratio=3.5, index=2.2):
    """Cloche FM : l'index de modulation retombe vite, d'ou une attaque brillante puis un son
    pur (verre, cristal). ratio non entier = timbre de cloche plutot que d'instrument a vent."""
    t = t_axis(duration)
    fc = midi(midi_note)
    mod_env = np.exp(-t * 18)
    x = np.sin(2 * np.pi * fc * t + index * mod_env * np.sin(2 * np.pi * fc * ratio * t))
    return x * env(len(t), 0.002, curve=5) * vol


def sweep_filter(x, f_start, f_end, q=2.0):
    """Passe-bande (filtre a variable d'etat) dont la frequence balaie de f_start a f_end."""
    n = len(x)
    freqs = np.geomspace(f_start, f_end, n)
    low = band = 0.0
    damp = 1.0 / q
    y = np.zeros(n)
    for i in range(n):
        f = 2 * np.sin(np.pi * min(freqs[i], RATE / 6) / RATE)
        low += f * band
        high = x[i] - low - damp * band
        band += f * high
        y[i] = band
    return y


def whoosh(duration, f_start, f_end, q=1.8):
    """Souffle d'air : bruit dans un filtre qui balaie, enveloppe en cloche."""
    n = noise(duration)
    shape = np.sin(np.linspace(0, np.pi, len(n))) ** 1.5
    return polish(sweep_filter(n, f_start, f_end, q), 3500) * shape


def tick(freq=3000, duration=0.012, q=3.0):
    """Petit clic net (contact, menu) : bruit tres court centre sur freq."""
    n = noise(duration)
    return sweep_filter(n, freq, freq, q) * env(len(n), 0.0005, curve=8)


def reverb(x, wet=0.25, room=0.75, tail=0.6):
    """Reverberation de Schroeder (4 filtres en peigne amortis + 2 passe-tout) : donne de l'air."""
    dry = np.concatenate([x, np.zeros(int(RATE * tail))])
    out = np.zeros_like(dry)
    for delay_ms in (29.7, 37.1, 41.1, 43.7):
        d = int(RATE * delay_ms / 1000)
        y = np.zeros_like(dry)
        lp = 0.0
        for i in range(len(dry)):
            back = y[i - d] if i >= d else 0.0
            lp = 0.7 * back + 0.3 * lp  # amortit les aigus dans la queue
            y[i] = dry[i] + room * lp
        out += y
    for delay_ms, g in ((5.0, 0.7), (1.7, 0.7)):
        d = int(RATE * delay_ms / 1000)
        y = np.zeros_like(out)
        for i in range(len(out)):
            xd = out[i - d] if i >= d else 0.0
            yd = y[i - d] if i >= d else 0.0
            y[i] = -g * out[i] + xd + g * yd
        out = y
    return dry * (1 - wet) + out / 4 * wet


def polish(x, cutoff=5500):
    """Arrondit le haut du spectre (trois filtres en cascade) : brillant sans sifflement."""
    return lowpass(lowpass(lowpass(x, cutoff), cutoff), cutoff)


def arp(notes, step, duration, vol=0.6):
    return mix(*[at(bell(m, duration, vol), k * step, step * len(notes) + duration) for k, m in enumerate(notes)])


def sfx():
    global RATE
    RATE = SFX_RATE
    s = {}
    s["slash"] = whoosh(0.1, 1800, 600, 1.5)
    s["hit"] = mix(tick(2600, 0.014), osc(glide(240, 120, 0.05), 0.05, "sine") * env(int(RATE * 0.05), 0.001, curve=6) * 0.8)
    s["crit"] = reverb(mix(s["hit"], at(bell(88, 0.25, 0.35), 0.005, 0.3)), 0.2, 0.6, 0.3)
    s["hurt"] = reverb(mix(whoosh(0.12, 1800, 400, 1.2) * 0.8, osc(glide(520, 300, 0.22), 0.22, "triangle") * env(int(RATE * 0.22), 0.003, curve=4) * 0.6), 0.2, 0.6, 0.3)
    s["dash"] = mix(whoosh(0.2, 450, 2200, 1.6), at(bell(PENTA[10], 0.2, 0.12), 0.04, 0.24))
    s["mob_die"] = reverb(mix(whoosh(0.26, 1600, 280, 1.3), at(bell(PENTA[9], 0.25, 0.15), 0.03, 0.3)), 0.2, 0.6, 0.35)
    s["shoot"] = whoosh(0.07, 800, 1900, 2.5)
    s["pickup"] = reverb(arp([PENTA[5], PENTA[7], PENTA[9]], 0.06, 0.35, 0.6), 0.3, 0.75, 0.5)
    knock = mix(tick(800, 0.025, 2.0), at(tick(700, 0.025, 2.0), 0.08, 0.11))
    s["chest"] = reverb(mix(knock, at(arp([PENTA[3], PENTA[5], PENTA[7], PENTA[10]], 0.07, 0.5, 0.5), 0.15, 0.9)), 0.3, 0.75, 0.6)
    s["boss"] = reverb(lowpass(mix(stinger(chord=(38, 41, 44, 50, 51), swell=0.7, tail=2.2, drop=True),
                                   at(bell(62, 1.6, 0.4, ratio=1.4, index=3), 0.7, 3.5)), 3000), 0.3, 0.8, 1.0)
    s["portal"] = reverb(mix(whoosh(0.5, 300, 2400, 1.4), at(arp([PENTA[2], PENTA[5], PENTA[8]], 0.08, 0.4, 0.35), 0.15, 0.9)), 0.35, 0.8, 0.7)
    s["encounter"] = reverb(lowpass(stinger(chord=(50, 53, 56, 62), swell=0.45, tail=1.3), 3000), 0.3, 0.8, 0.8)
    s["ui_select"] = mix(tick(3200, 0.01, 4.0), bell(PENTA[7], 0.08, 0.3))
    s["active"] = reverb(mix(whoosh(0.18, 600, 2000), arp([PENTA[4], PENTA[6], PENTA[8], PENTA[11]], 0.04, 0.4, 0.5)), 0.3, 0.8, 0.6)
    s["heal"] = reverb(arp([PENTA[3], PENTA[5], PENTA[8]], 0.08, 0.3, 0.5), 0.3, 0.75, 0.5)
    s["dodge"] = whoosh(0.09, 1200, 2800, 2.0)
    s["shield"] = reverb(mix(tick(1800, 0.015), bell(PENTA[11], 0.3, 0.5, ratio=2.76, index=2.5)), 0.3, 0.75, 0.5)
    s["sparkle"] = reverb(arp([PENTA[12], PENTA[10], PENTA[13], PENTA[11]], 0.045, 0.25, 0.4), 0.35, 0.8, 0.6)
    s["pop"] = mix(osc(glide(900, 1500, 0.03), 0.03, "sine") * env(int(RATE * 0.03), 0.001, curve=5), tick(2200, 0.01))
    s["victory"] = reverb(arp([PENTA[5], PENTA[7], PENTA[8], PENTA[10]], 0.09, 0.6, 0.55), 0.3, 0.8, 0.8)
    s["death"] = reverb(arp([PENTA[8], PENTA[6], PENTA[4], PENTA[1]], 0.18, 0.7, 0.55), 0.4, 0.85, 1.2)
    s["quest"] = reverb(arp([PENTA[4], PENTA[7]], 0.1, 0.4, 0.55), 0.3, 0.75, 0.5)
    s["coin"] = reverb(arp([PENTA[9], PENTA[12]], 0.05, 0.25, 0.5), 0.25, 0.7, 0.4)
    for name, x in s.items():
        save(polish(x), "sfx", f"{name}.wav", peak=SFX_PEAKS[name])
    # Sons retires (evenements trop frequents) : on supprime les anciens fichiers.
    for name in ("telegraph", "ui_move", "decor"):
        for ext in (".wav", ".wav.import"):
            path = os.path.join(ROOT, "sfx", name + ext)
            if os.path.exists(path):
                os.remove(path)
    RATE = MUSIC_RATE


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
    global rng
    sfx()
    # Graine propre aux musiques : retoucher les effets ne doit plus modifier leurs fichiers.
    rng = np.random.default_rng(11)
    save(music_reve(), "music", "reve.wav", peak=0.6)
    save(music_profond(), "music", "profond.wav", peak=0.6)
    save(music_combat(), "music", "combat.wav", peak=0.6)
    save(music_boss(), "music", "boss.wav", peak=0.6)


if __name__ == "__main__":
    main()
