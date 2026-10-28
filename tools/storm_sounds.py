"""The Mech's Arm Cannon's sounds (the user's ask: its own, not the stock rifle's; the minigun mode "a really aggressive
... A10 ... BRR"): synthesized here from shaped noise, pitch-falling thumps, servo sweeps and a room's reverb, so they
are ours to ship (src/RevNet/Sounds, imported into RevNet.u by CoopMechCannon: RevNet is in the package map, so every
player hears them). The gun's story: a Metal Storm gun, its stacked rounds fired electronically (an electric crack in
each shot), drawn from behind the shoulder down the arm and spun over the hand, a brick magazine swapped by hand.

- StormShot    full auto, one round                 StormBlast  the spread: all five barrels at once
- StormLoop    the Storm mode, a seamless loop of 66 rounds a second (the BRRRT)   StormTail  its roar dying away
- StormDown    unlock, servo back, clunk             StormDry    an empty electronic click
- StormMode    the mode switch's chirp
(StormDraw and StormReload: tools/storm_foley.py, from real CC0 recordings; synthesized here they were too
"high tech", then "like bouncing a bouncy ball", the user said.)

  python -I tools/storm_sounds.py [out dir]     (default src/RevNet/Sounds)
"""
import os, sys, wave

import numpy as np

RATE = 44100
rng = np.random.default_rng(1977)


def n_(seconds):
    return int(round(seconds * RATE))


def noise(seconds):
    return rng.normal(0, 1, n_(seconds))


def band(x, lo, hi, soft=0.15, circular=False):
    """x band-passed between lo and hi Hz (smooth edges), by FFT; zero-padded unless circular (a loop), so a
    sharp start doesn't wrap round to the end as an echo."""
    L = len(x) if circular else 2 * len(x)
    X = np.fft.rfft(x, L)
    f = np.fft.rfftfreq(L, 1 / RATE)
    lo_w = 1 / (1 + np.exp(-(np.log(f + 1) - np.log(lo)) / soft)) if lo > 0 else np.ones_like(f)
    hi_w = 1 / (1 + np.exp((np.log(f + 1) - np.log(hi)) / soft))
    return np.fft.irfft(X * lo_w * hi_w, L)[:len(x)]


def env(length, attack, decay, at=0.0):
    """An envelope: silence until at, a linear rise over attack, an exponential fall (decay: time to 1/e)."""
    t = np.arange(n_(length)) / RATE - at
    e = np.where(t < 0, 0, np.where(t < attack, t / max(attack, 1e-6), np.exp(-(t - attack) / decay)))
    return e


def sweep(length, f0, f1, at=0.0, dur=None, harmonics=(1.0,), vibrato=0.0):
    """A tone gliding f0 -> f1 Hz from at over dur (then holding), with harmonics and a little vibrato."""
    t = np.arange(n_(length)) / RATE
    dur = dur or (length - at)
    k = np.clip((t - at) / dur, 0, 1)
    f = f0 * (f1 / f0) ** k * (1 + vibrato * np.sin(2 * np.pi * 7.0 * t))
    ph = 2 * np.pi * np.cumsum(f) / RATE
    return sum(a * np.sin((i + 1) * ph) for i, a in enumerate(harmonics))


def thump(length, f0, f1, fall, decay, at=0.0):
    """A low thud: a sine falling f0 -> f1 Hz over fall seconds, dying over decay."""
    t = np.arange(n_(length)) / RATE - at
    f = np.where(t < 0, f0, f1 + (f0 - f1) * np.exp(-np.maximum(t, 0) / fall))
    ph = 2 * np.pi * np.cumsum(f) / RATE
    return np.sin(ph) * np.where(t < 0, 0, np.exp(-np.maximum(t, 0) / decay))


def click(length, at, bright=1.0, decay=0.004):
    """A metallic click: a very short bright burst with a little ring."""
    x = band(noise(length), 2500, 9000) * env(length, 0.0003, decay, at)
    t = np.arange(n_(length)) / RATE - at
    ring = (np.sin(2 * np.pi * 2730 * t) + 0.6 * np.sin(2 * np.pi * 4110 * t)) * np.where(t < 0, 0, np.exp(-np.maximum(t, 0) / 0.05))
    return bright * (x * 0.9 + ring * 0.12)


def reverb(x, t60, wet, circular=False, seed=3):
    """x in a room: convolved with decaying noise (t60: seconds to -60 dB); circular for loops."""
    g = np.random.default_rng(seed)
    m = n_(t60)
    ir = g.normal(0, 1, m) * np.exp(-6.9 * np.arange(m) / m)
    ir = band(ir, 120, 7000)
    ir /= np.sqrt((ir ** 2).sum()) + 1e-9
    if circular:
        wetx = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir, len(x)), len(x))
    else:
        L = len(x) + m
        wetx = np.fft.irfft(np.fft.rfft(x, L) * np.fft.rfft(ir, L), L)[:len(x)]
    return x * (1 - wet) + wetx * wet * 2.2


def drive(x, amount):
    """Saturation (grit and loudness)."""
    return np.tanh(x * amount) / np.tanh(amount)


def finish(x, peak=0.93, fade=0.004):
    x = x - x.mean()
    x = x / (np.abs(x).max() + 1e-9) * peak
    k = n_(fade)
    if k:
        x[-k:] *= np.linspace(1, 0, k)
    return x


def shot(length, at=0.0, size=1.0, tight=1.0):
    """One electronically fired round: the ignition's zap, the crack, the report's body, a thump."""
    t = np.arange(n_(length)) / RATE - at
    zap = np.sign(np.sin(2 * np.pi * 1850 * t)) * np.where((t >= 0) & (t < 0.006 * tight), 1.0, 0.0) * 0.25
    crack = band(noise(length), 2600, 10000) * env(length, 0.0003, 0.006 * tight, at) * 1.9
    body = band(noise(length), 180, 2600) * env(length, 0.0008, 0.04 * tight * size, at) * 1.5
    low = thump(length, 105 * size ** -0.3, 50, 0.02, 0.028 * tight * size, at) * 0.65 * size
    return zap + crack + body + low


def storm_shot():
    L = 0.5
    x = drive(shot(L) + 0.25 * click(L, 0.012, 0.6), 2.2)
    return finish(reverb(x, 0.38, 0.22))


def storm_blast():
    L = 1.3
    x = sum(shot(L, at, size=1.25) * (1.0 - 0.08 * i) for i, at in enumerate((0.0, 0.0016, 0.0031, 0.0045, 0.006)))
    x = x + thump(L, 80, 34, 0.08, 0.16) * 2.2 + band(noise(L), 60, 700) * env(L, 0.002, 0.11) * 1.6
    return finish(reverb(drive(x, 3.0), 0.85, 0.32))


def storm_loop(rate=66.0, seconds=1.0):
    """The BRRRT: rounds at rate a second over seconds (whole periods: it loops), each a tight shot, over a
    pulsing roar, saturated hard; built round the loop's edge so its end runs into its start."""
    L = seconds
    N = n_(L)
    x = np.zeros(N)
    k = int(round(rate * seconds))
    for i in range(k):
        at = i / rate + rng.uniform(-0.0012, 0.0012)
        s = shot(0.06, 0.0, size=0.85, tight=0.55) * rng.uniform(0.85, 1.12)
        j = n_(at) % N
        idx = (np.arange(len(s)) + j) % N
        x[idx] += s
    t = np.arange(N) / RATE
    pulse = 0.55 + 0.45 * np.abs(np.sin(np.pi * rate * t)) ** 3
    roar = band(noise(L), 55, 850, circular=True) * pulse * 0.9
    rattle = band(noise(L), 3200, 7000, circular=True) * pulse * 0.12
    x = drive(x + roar + rattle, 3.2)
    return finish(reverb(x, 0.45, 0.25, circular=True), fade=0)


def storm_tail():
    L = 1.4
    x = sum(shot(L, i / 66.0, size=0.85, tight=0.55) * (1 - i / 6) for i in range(5))
    x = x + band(noise(L), 40, 320) * env(L, 0.01, 0.38) * 1.6 + thump(L, 70, 30, 0.12, 0.3) * 1.2
    return finish(reverb(drive(x, 2.4), 1.1, 0.4))


def storm_down():
    L = 0.6
    whine = sweep(L, 1400, 450, 0.05, 0.32, (1.0, 0.3), 0.004) * env(L, 0.03, 0.35, 0.05) * np.where(np.arange(n_(L)) / RATE < 0.42, 1, 0) * 0.3
    slide = band(noise(L), 1200, 4200) * env(L, 0.04, 0.1, 0.08) * 0.35
    return finish(reverb(click(L, 0.0, 0.8) + whine + slide + thump(L, 120, 65, 0.02, 0.05, 0.44) * 0.8 + click(L, 0.44, 0.5), 0.3, 0.18))


def storm_dry():
    L = 0.18
    t = np.arange(n_(L)) / RATE
    buzz = np.sign(np.sin(2 * np.pi * 760 * t)) * ((t > 0.01) & (t < 0.06)) * 0.2
    return finish(click(L, 0.0, 1.0) * 0.8 + buzz, peak=0.6)


def storm_mode():
    L = 0.22
    t = np.arange(n_(L)) / RATE
    a = np.sin(2 * np.pi * 1600 * t) * ((t > 0.0) & (t < 0.05))
    b = np.sin(2 * np.pi * 2400 * t) * ((t > 0.07) & (t < 0.13))
    return finish((a + b) * 0.3 + click(L, 0.0, 0.4), peak=0.55)


SOUNDS = {"StormShot": storm_shot, "StormBlast": storm_blast, "StormLoop": storm_loop, "StormTail": storm_tail,
          "StormDown": storm_down, "StormDry": storm_dry, "StormMode": storm_mode}


def write_wav(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join("src", "RevNet", "Sounds")
    os.makedirs(out, exist_ok=True)
    for name, make in SOUNDS.items():
        x = make()
        write_wav(os.path.join(out, name + ".wav"), x)
        print("%-12s %.2f s" % (name, len(x) / RATE))


if __name__ == "__main__":
    main()
