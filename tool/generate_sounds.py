#!/usr/bin/env python3
"""Synthesizes the PourSort sounds into assets/audio/*.wav.

Python 3 standard library only. Output is deterministic (fixed random seeds),
so running it twice produces identical files.

  select, pour, invalid, level_clear   44100 Hz  original effects
  cork, level_up, unlock               44100 Hz  tube sorted, player level up,
                                                 menu confirm
  music_loop                           16000 Hz  bubbly, relaxed loop (25 s)

Everything is mono 16-bit PCM. The music runs at 16 kHz so the loop stays
under 1 MB. It is rendered on a circular timeline: note tails wrap around the
end and every filter or echo runs over two tiled periods with the second one
kept, so the last sample flows into the first one without a click.
"""
import math
import os
import random
import struct
import wave

RATE = 44100
PEAK = 0.7  # about -3 dBFS


def envelope(n, attack=0.006, release=0.04):
    a = max(1, int(attack * RATE))
    r = max(1, int(release * RATE))
    env = []
    for i in range(n):
        g = 1.0
        if i < a:
            g = i / a
        if i > n - r:
            g = min(g, (n - i) / r)
        env.append(g)
    return env


def tone(freq, dur, kind="sine", glide=None, decay=6.0, attack=0.006):
    """A decaying tone; glide is an optional end frequency."""
    n = int(dur * RATE)
    env = envelope(n, attack)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq if glide is None else freq + (glide - freq) * (i / n)
        phase += 2 * math.pi * f / RATE
        if kind == "triangle":
            s = 2 / math.pi * math.asin(math.sin(phase))
        else:
            s = math.sin(phase)
        out.append(s * env[i] * math.exp(-decay * t / dur))
    return out


def noise(dur, seed, lowpass=0.15, decay=3.0):
    rng = random.Random(seed)
    n = int(dur * RATE)
    env = envelope(n, 0.01, 0.06)
    out = []
    y = 0.0
    for i in range(n):
        y += lowpass * (rng.uniform(-1, 1) - y)
        out.append(y * env[i] * math.exp(-decay * i / n))
    return out


def mix(*parts):
    n = max(len(p[1]) + p[0] for p in parts)
    out = [0.0] * n
    for offset, samples, gain in parts:
        for i, s in enumerate(samples):
            out[offset + i] += s * gain
    return out


def write(name, samples, rate=RATE, peak_target=PEAK):
    peak = max(abs(s) for s in samples) or 1.0
    scale = peak_target / peak
    path = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", name + ".wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", int(s * scale * 32767)) for s in samples))


def ms(v):
    return int(v * RATE / 1000)


# --------------------------------------------------------------------------
# Retention update: new effects and the music loop
# --------------------------------------------------------------------------

TAU = 2.0 * math.pi
MUSIC_RATE = 16000
MUSIC_PEAK = 0.25  # about -12 dBFS, sits under the effects


def midi_hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def lowpass(x, cutoff, rate):
    a = 1.0 - math.exp(-TAU * cutoff / rate)
    y = 0.0
    out = []
    for v in x:
        y += a * (v - y)
        out.append(y)
    return out


def highpass(x, cutoff, rate):
    lp = lowpass(x, cutoff, rate)
    return [v - l for v, l in zip(x, lp)]


def circular(fn, x, *args):
    """Runs fn over two tiled periods and keeps the second (seamless loop)."""
    n = len(x)
    return fn(x + x, *args)[n:]


def echo(x, delay, feedback, damp_hz, rate):
    a = 1.0 - math.exp(-TAU * damp_hz / rate)
    wet = [0.0] * len(x)
    lp = 0.0
    for i in range(len(x)):
        if i >= delay:
            lp += a * (wet[i - delay] + x[i - delay] - lp)
        wet[i] = feedback * lp
    return wet


def mix_into(buf, sig, start, wrap=False):
    n = len(buf)
    for i, v in enumerate(sig):
        j = start + i
        if wrap:
            buf[j % n] += v
        elif j < n:
            buf[j] += v


def mallet(freq, dur, rate, decay=5.0, bright=0.35):
    """Soft marimba-like note: fundamental plus a fast-fading 3.9x partial."""
    n = int(dur * rate)
    out = []
    att = max(1, int(0.004 * rate))
    for i in range(n):
        t = i / rate
        g = min(1.0, i / att)
        v = math.sin(TAU * freq * t) * math.exp(-decay * t)
        v += bright * math.sin(TAU * freq * 3.9 * t) * math.exp(-decay * 4.0 * t)
        v += 0.12 * math.sin(TAU * freq * 2.0 * t) * math.exp(-decay * 1.6 * t)
        out.append(v * g)
    rel = max(1, int(0.03 * rate))
    for i in range(min(rel, n)):
        out[n - 1 - i] *= i / rel
    return out


def bubble(f0, dur, rate, rise=2.2):
    """Water bubble 'bloop': a sine whose pitch rises quickly."""
    n = int(dur * rate)
    out = []
    phase = 0.0
    for i in range(n):
        u = i / n
        f = f0 * (rise ** u)
        phase += TAU * f / rate
        env = math.sin(math.pi * u) ** 1.5 * math.exp(-2.0 * u)
        out.append(math.sin(phase) * env)
    return out


def cork():
    """Tube sorted: a soft cork pop and a short glass ting."""
    pop = mix(
        (0, noise(0.05, 31, lowpass=0.35, decay=8.0), 0.8),
        (0, tone(900, 0.07, "sine", glide=260, decay=5.0, attack=0.001), 1.0),
    )
    ting = [v * 0.5 for v in mallet(2093.0, 0.35, RATE, decay=9.0, bright=0.2)]
    ting2 = [v * 0.35 for v in mallet(2637.0, 0.3, RATE, decay=10.0, bright=0.2)]
    return mix((0, pop, 1.0), (ms(45), ting, 1.0), (ms(95), ting2, 1.0))


def level_up():
    """Player level up: rising mallet arpeggio with bubbles on top."""
    notes = [65, 69, 72, 77, 81]
    parts = []
    for i, m in enumerate(notes):
        parts.append((ms(85 * i), mallet(midi_hz(m), 0.6, RATE, decay=4.5), 0.8))
    parts.append((ms(420), mallet(midi_hz(84), 0.9, RATE, decay=3.0), 0.9))
    parts.append((ms(380), bubble(700, 0.09, RATE), 0.35))
    parts.append((ms(470), bubble(950, 0.08, RATE), 0.3))
    return mix(*parts)


def unlock():
    """Menu confirm: two quick bubbles."""
    return mix(
        (0, bubble(520, 0.07, RATE, rise=2.0), 1.0),
        (ms(70), bubble(780, 0.08, RATE, rise=2.1), 0.9),
    )


BPM = 96
EIGHTH = 60.0 / BPM / 2.0
BARS = 10

CHORDS = {
    "F": ([53, 57, 60, 65], 41),
    "Dm": ([53, 57, 62], 38),
    "Bb": ([53, 58, 62], 46),
    "C": ([52, 55, 60, 64], 48),
    "Am": ([52, 57, 60], 45),
    "Gm": ([50, 55, 58, 62], 43),
}
PROGRESSION = ["F", "Dm", "Bb", "C", "F", "Am", "Bb", "C", "Gm", "C"]

# (eighth offset in bar, midi note, length in eighths); F major pentatonic.
MELODY = [
    [(0, 77, 2), (3, 81, 1), (4, 84, 3)],
    [(0, 81, 2), (2, 79, 2), (4, 77, 4)],
    [(1, 74, 1), (2, 77, 2), (4, 79, 1), (5, 81, 3)],
    [(0, 79, 3), (4, 76, 2), (6, 72, 2)],
    [(0, 77, 2), (3, 81, 1), (4, 86, 2), (6, 84, 2)],
    [(0, 81, 3), (4, 76, 2), (6, 77, 2)],
    [(0, 74, 2), (2, 77, 1), (3, 79, 1), (4, 81, 4)],
    [(0, 84, 2), (2, 81, 2), (4, 79, 2), (6, 76, 2)],
    [(0, 79, 2), (2, 74, 2), (4, 77, 2), (6, 79, 2)],
    [(0, 76, 3), (4, 79, 2), (6, 72, 2)],
]


def music_loop():
    rate = MUSIC_RATE
    bar = EIGHTH * 8
    n = int(round(bar * BARS * rate))
    rng = random.Random(4242)
    pad = [0.0] * n
    bass = [0.0] * n
    lead = [0.0] * n
    bubbles = [0.0] * n

    # Pad: detuned sine stacks with long raised-cosine swells.
    cache = {}
    for b, name in enumerate(PROGRESSION):
        if name not in cache:
            notes = CHORDS[name][0]
            m = int((bar + 0.9) * rate)
            voice = [0.0] * m
            for note in notes:
                f = midi_hz(note)
                for detune, amp in ((0.997, 0.5), (1.0, 0.7), (1.003, 0.5)):
                    w1 = TAU * f * detune / rate
                    w2 = 2.0 * w1
                    for i in range(m):
                        voice[i] += amp * (math.sin(w1 * i) + 0.18 * math.sin(w2 * i))
            att = int(0.7 * rate)
            rel = int(0.9 * rate)
            for i in range(m):
                g = 1.0
                if i < att:
                    g = math.sin(0.5 * math.pi * i / att) ** 2
                if i > m - rel:
                    g = min(g, math.sin(0.5 * math.pi * (m - i) / rel) ** 2)
                voice[i] *= g
            cache[name] = voice
        mix_into(pad, [0.06 * v for v in cache[name]], int(b * bar * rate), wrap=True)
    pad = circular(lowpass, pad, 1100, rate)

    # Bass: round sine plucks on beats 1 and 3.
    bcache = {}
    for b, name in enumerate(PROGRESSION):
        root = CHORDS[name][1]
        if root not in bcache:
            bcache[root] = mallet(midi_hz(root), 1.3, rate, decay=2.6, bright=0.05)
        base = int(b * bar * rate)
        mix_into(bass, [0.5 * v for v in bcache[root]], base, wrap=True)
        mix_into(bass, [0.32 * v for v in bcache[root]], base + int(4 * EIGHTH * rate), wrap=True)
    bass = circular(lowpass, bass, 500, rate)

    # Lead: mallets, plus a soft octave-down answer on long notes.
    lcache = {}
    for b, notes in enumerate(MELODY):
        for off, midi, length in notes:
            key = (midi, length)
            if key not in lcache:
                lcache[key] = mallet(midi_hz(midi), min(2.2, 0.7 + 0.3 * length), rate,
                                     decay=3.2, bright=0.3)
            start = int((b * bar + off * EIGHTH) * rate)
            mix_into(lead, [0.3 * v for v in lcache[key]], start, wrap=True)
    lead = circular(lowpass, lead, 3000, rate)

    # Bubbles: a few quiet bloops per bar at deterministic offbeats.
    for b in range(BARS):
        for _ in range(2 + (b % 2)):
            e = rng.choice([1, 3, 5, 6, 7])
            jitter = rng.uniform(0.0, 0.08)
            f0 = rng.uniform(420.0, 820.0)
            dur = rng.uniform(0.05, 0.09)
            sig = bubble(f0, dur, rate, rise=rng.uniform(1.8, 2.6))
            gain = rng.uniform(0.05, 0.09)
            mix_into(bubbles, [gain * v for v in sig],
                     int((b * bar + e * EIGHTH + jitter) * rate), wrap=True)

    delay = int(round(EIGHTH * 3 * rate))
    lead_echo = circular(echo, lead, delay, 0.38, 1800, rate)
    bub_echo = circular(echo, bubbles, int(round(EIGHTH * 2 * rate)), 0.3, 2400, rate)
    out = [p + b + l + 0.5 * le + u + 0.6 * ue
           for p, b, l, le, u, ue in zip(pad, bass, lead, lead_echo, bubbles, bub_echo)]
    return circular(highpass, out, 35, rate)


def main():
    # select: short rising blip.
    write("select", tone(520, 0.09, "triangle", glide=720, decay=4.0))
    # pour: bubbling glide with soft filtered noise.
    write(
        "pour",
        mix(
            (0, noise(0.34, 11, lowpass=0.12, decay=1.6), 0.5),
            (0, tone(430, 0.34, "sine", glide=250, decay=2.5), 0.6),
            (ms(70), tone(560, 0.2, "sine", glide=380, decay=3.0), 0.35),
        ),
    )
    # invalid: low double thud.
    write(
        "invalid",
        mix(
            (0, tone(180, 0.1, "triangle", glide=150, decay=4.0), 1.0),
            (ms(90), tone(150, 0.12, "triangle", glide=120, decay=4.0), 1.0),
        ),
    )
    # level_clear: rising major arpeggio.
    notes = [523.25, 659.25, 783.99, 1046.5]
    parts = [(ms(70 * i), tone(f, 0.15, "sine", decay=3.0), 1.0) for i, f in enumerate(notes)]
    write("level_clear", mix(*parts))
    write("cork", cork())
    write("level_up", level_up())
    write("unlock", unlock())
    write("music_loop", music_loop(), MUSIC_RATE, MUSIC_PEAK)


if __name__ == "__main__":
    main()
