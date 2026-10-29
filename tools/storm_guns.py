"""The Arm Cannon's gunfire from real recordings (the user: the synthesized shots "feel very dated", wanting them "more
aggressive and realistic", and "maybe it's the lack of echo"): cut from the CC0 Free Firearm Sound Library
(art/sounds/cc0, README there), made heavier, and put in a room: early reflections off its walls, then a long tail.

- StormShot    full auto, one round: an AK-47's, a little lower, a Mosin Nagant's weight under it, the room
- StormBlast   Spread, all five barrels at once: a 12-gauge doubled a few ms apart, a big rifle's crack, a long echo
- StormLoop    Storm, a seamless second of 66 rounds: real rounds' cracks at a minigun's rate, the room ringing
- StormTail    its last rounds and the room dying away after the trigger is let go

  python -I tools/storm_guns.py [out dir]     (default src/RevNet/Sounds; needs ffmpeg)
"""
import os, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from storm_foley import body, cut, lay, rec
from storm_sounds import RATE, band, drive, finish, n_, reverb, write_wav

rng = np.random.default_rng(66)
EARLY = ((0.021, 0.42), (0.037, 0.33), (0.058, 0.27), (0.083, 0.2), (0.115, 0.15), (0.16, 0.1))   # walls: delay, level


def room(x, t60=1.3, wet=0.32, circular=False):
    """x in a hard room: its early reflections (darker than the shot), then a diffuse tail t60 long."""
    if not circular:
        x = np.concatenate([x, np.zeros(n_(t60))])
    dark = band(x, 50, 4500, circular=circular)
    y = x.copy()
    for d, g in EARLY:
        y += np.roll(dark, n_(d)) * g if circular else np.concatenate([np.zeros(n_(d)), dark[:len(x) - n_(d)]]) * g
    return reverb(y, t60, wet, circular=circular)


def onsets(x, thr=0.3, gap=0.03):
    """Where each round starts (5 ms loudness crossing thr of the peak, at least gap apart)."""
    k = n_(0.005)
    e = np.array([np.sqrt((x[i:i + k] ** 2).mean()) for i in range(0, len(x) - k, k)])
    out, last = [], -1.0
    for i in range(1, len(e)):
        if e[i] > thr * e.max() >= e[i - 1] and i * 0.005 - last > gap:
            out.append(i * 0.005)
            last = i * 0.005
    return out


def storm_shot():
    out = np.zeros(n_(0.9))
    lay(out, cut("fx_ak47_single.wav", 0.12, 1.0, 0.92), 0.0, 1.0)
    lay(out, band(cut("fx_mosin_single.wav", 0.09, 0.9, 0.85), 35, 380), 0.0, 0.7)
    return finish(room(drive(body(out, 0.7), 1.8), 1.2, 0.3), peak=0.95)


def storm_blast():
    out = np.zeros(n_(1.4))
    s = cut("fx_mossberg_blast.wav", 0.1, 1.4, 0.85)
    lay(out, s, 0.0, 1.0)
    lay(out, cut("fx_mossberg_blast.wav", 0.1, 1.4, 0.8), 0.006, 0.7)
    lay(out, cut("fx_mosin_single.wav", 0.09, 0.8, 0.95), 0.002, 0.45)
    lay(out, band(s, 30, 200), 0.0, 0.8)
    return finish(room(drive(body(out, 0.8), 2.0), 1.6, 0.38), peak=0.97)


def cracks():
    """The automatic burst's rounds, each its first 45 ms (the crack and the start of its body)."""
    x = rec("fx_ak47_auto.wav")
    x = x / (np.abs(x).max() + 1e-9)
    out = []
    for t in onsets(x):
        seg = x[n_(t) - n_(0.002):n_(t) + n_(0.045)].copy()
        if len(seg) < n_(0.04):
            continue
        seg[-n_(0.01):] *= np.linspace(1, 0, n_(0.01))
        out.append(seg / (np.abs(seg).max() + 1e-9))
    return out


def storm_loop():
    """One second, 66 rounds, wrapping round seamlessly (CoopSoundLoop's AmbientSound)."""
    cs = cracks()
    L = n_(1.0)
    out = np.zeros(L)
    for k in range(66):
        c = cs[rng.integers(len(cs))]
        r = rng.uniform(0.9, 1.0)
        c = np.interp(np.arange(0, len(c) - 1, r), np.arange(len(c)), c) * 10 ** (rng.uniform(-1.5, 1.5) / 20)
        i = (n_(k / 66.0) + rng.integers(-30, 30)) % L
        idx = (np.arange(len(c)) + i) % L
        np.add.at(out, idx, c)
    out = out + band(out, 40, 220, circular=True) * 0.7       # the growl of the rounds' overlap
    out = room(drive(out * 0.6, 1.8), 0.9, 0.3, circular=True)
    return finish(out, peak=0.95, fade=0)


def storm_tail():
    """The last few rounds, fading, and the room ringing on (the loop stops a round or two late)."""
    cs = cracks()
    out = np.zeros(n_(0.25))
    for k in range(8):
        c = cs[rng.integers(len(cs))] * (1 - k / 8.0) ** 1.5
        lay(out, c, k / 66.0, 1.0)
    return finish(room(drive(body(out, 0.6), 1.6), 1.8, 0.45), peak=0.85)


SOUNDS = {"StormShot": storm_shot, "StormBlast": storm_blast, "StormLoop": storm_loop, "StormTail": storm_tail}


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join("src", "RevNet", "Sounds")
    os.makedirs(out, exist_ok=True)
    for name, make in SOUNDS.items():
        x = make()
        write_wav(os.path.join(out, name + ".wav"), x)
        print("%-12s %.2f s" % (name, len(x) / RATE))


if __name__ == "__main__":
    main()
