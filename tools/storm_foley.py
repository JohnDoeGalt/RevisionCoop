"""The Arm Cannon's mechanism sounds from real recordings: its draw (StormDraw) and its reload, in two (StormReloadOut,
StormReloadIn). The user wanted them "crunchy and mechanical", then "clunky and chunky": synthesized
(tools/storm_sounds.py), they came out high tech, then like a bouncing ball. These are cut from CC0 gun and metal foley
(art/sounds/cc0, README there), pitched down for the weight of a big gun, given more body, laid on the view's timing
(tools/mech_storm.py: drawn, it slides down the arm, swings over the hand and locks at about 0.6 s; reloading, the brick
comes off at 0.22-0.38 s into ReloadBegin, and the new one is slammed home 0.34 s into ReloadEnd, 2 s later). (Its
gunfire: tools/storm_guns.py.)

  python -I tools/storm_foley.py [out dir]     (default src/RevNet/Sounds; needs ffmpeg for the OGGs)
"""
import os, subprocess, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from storm_sounds import RATE, band, drive, env, finish, n_, noise, reverb, write_wav

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "sounds", "cc0")
_cache = {}


def rec(name):
    """A recording, mono, at RATE."""
    if name not in _cache:
        raw = subprocess.run(["ffmpeg", "-v", "error", "-i", os.path.join(SRC, name), "-f", "s16le", "-ac", "1", "-ar", str(RATE), "-"],
                             capture_output=True, check=True).stdout
        _cache[name] = np.frombuffer(raw, "<i2") / 32768.0
    return _cache[name]


def cut(name, t0, t1, rate=1.0, fade=0.004):
    """Part of a recording, faded at both ends, played at rate (below 1: lower and slower, heavier)."""
    x = rec(name)[int(t0 * RATE):int(t1 * RATE)].copy()
    k = min(n_(fade), len(x) // 2)
    x[:k] *= np.linspace(0, 1, k)
    x[-k:] *= np.linspace(1, 0, k)
    if rate != 1.0:
        x = np.interp(np.arange(0, len(x) - 1, rate), np.arange(len(x)), x)
    return x / (np.abs(x).max() + 1e-9)


def lay(out, x, at, gain=1.0):
    i = n_(at)
    j = min(len(out), i + len(x))
    out[i:j] += x[:j - i] * gain


def body(x, amount=0.9):
    """More weight (the low mids), a little grit; the clicks kept."""
    return drive(x + amount * band(x, 90, 700), 1.6)


def storm_draw():
    """Unlatched behind the shoulder; slid down the back of the arm, geared; swung over the hand; locked on (a pump's
    forward stroke and a bolt slamming home)."""
    out = np.zeros(n_(0.9))
    lay(out, cut("metalLatch.ogg", 0.02, 0.22, 0.72), 0.0, 0.55)
    lay(out, cut("doorClose_4.ogg", 0.08, 0.28, 0.8), 0.01, 0.6)
    lay(out, cut("gunreload1.wav", 0.04, 0.27, 0.8), 0.07, 0.85)
    click = cut("metalClick.ogg", 0.07, 0.15, 0.62)
    t = 0.09
    while t < 0.34:                                    # its gear's teeth
        lay(out, click, t, 0.22)
        t += 1.0 / (22 + 40 * (t - 0.09))
    lay(out, band(noise(0.9), 120, 900) * env(0.9, 0.06, 0.06, 0.38), 0.0, 0.5)       # the swing
    lay(out, cut("shotguncock.wav", 0.19, 0.42, 0.85), 0.58, 1.0)
    lay(out, cut("assaultriflereload1.wav", 1.25, 1.42, 0.8), 0.6, 0.55)
    return finish(reverb(body(out), 0.25, 0.14))


def storm_reload_out():
    """The reload's start (CockingSound, with ReloadBegin: the left hand pulls the brick off at 0.22-0.38 s): the latch
    thrown back, the brick dragged off its rails, set aside. (One sound for the whole reload ran ahead of the hand: the
    reload holds 2 s between the brick coming off and the new one going on.)"""
    out = np.zeros(n_(0.8))
    lay(out, cut("shotguncock.wav", 0.03, 0.18, 0.8), 0.0, 0.9)
    lay(out, cut("metalLatch.ogg", 0.02, 0.22, 0.75), 0.02, 0.35)
    lay(out, cut("assaultriflereload1.wav", 0.12, 0.38, 0.85), 0.2, 0.95)
    lay(out, cut("doorClose_4.ogg", 0.08, 0.3, 0.7), 0.58, 0.35)
    return finish(reverb(body(out), 0.28, 0.15))


def storm_reload_in():
    """The reload's end (AltFireSound, with ReloadEnd: the new brick set on its seat at 0.34 s, the jolt): slid on,
    slammed home, the latch racked shut, the feed taking up the first round."""
    out = np.zeros(n_(1.0))
    lay(out, cut("gunreload1.wav", 0.76, 1.0, 0.85), 0.04, 0.7)
    lay(out, cut("assaultriflereload1.wav", 1.02, 1.16, 0.8), 0.33, 1.0)
    lay(out, cut("doorClose_3.ogg", 0.23, 0.42, 0.7), 0.34, 0.45)
    lay(out, cut("gunreload1.wav", 1.24, 1.52, 0.85), 0.5, 0.9)
    lay(out, cut("metalClick.ogg", 0.07, 0.15, 0.7), 0.78, 0.4)
    return finish(reverb(body(out), 0.28, 0.15))


def storm_hopper():
    """A dry gun's second brick (with Hopper, after the first is seated: the user, 2026-10-29, a hopper "similar to the
    one for the auto cannon in helldivers... you hear a whirr and a rapid set of clinking noises"): the feed's motor
    spins up, the brick's rounds are stripped into the gun's hopper one after another, faster as it goes (real metal
    clicks, a little lower or higher each), the hopper full (a clunk), the motor winds down. The motor is ours (no
    recording of one): a low geared hum, kept gritty."""
    out = np.zeros(n_(1.15))
    t = np.arange(len(out)) / RATE
    level = np.clip(t / 0.14, 0, 1) * np.clip((1.05 - t) / 0.12, 0, 1)
    pitch = 62 + 58 * np.clip(t / 0.18, 0, 1) - 30 * np.clip((t - 0.93) / 0.15, 0, 1)
    phase = 2 * np.pi * np.cumsum(pitch) / RATE
    hum = (np.sin(phase) + 0.55 * np.sin(2 * phase) + 0.3 * np.sin(3 * phase + 0.4)) * (0.8 + 0.2 * np.sin(phase * 7))
    grind = band(noise(1.15), 180, 1400) * (0.5 + 0.5 * np.sin(phase * 4))
    lay(out, drive(0.5 * hum + 0.35 * grind, 2.0) * level, 0.0, 0.42)
    clicks = [cut("metalClick.ogg", 0.07, 0.15, r) for r in (0.66, 0.74, 0.7, 0.8)]
    at, k = 0.13, 0
    while at < 0.9:                                  # the rounds, one by one
        lay(out, clicks[k % 4], at + 0.004 * ((k * 7) % 3), 0.5 + 0.12 * (k % 3))
        at += 1.0 / (16 + 14 * (at - 0.13))
        k += 1
    lay(out, cut("shotguncock.wav", 0.19, 0.42, 0.8), 0.9, 0.7)               # full
    lay(out, cut("doorClose_4.ogg", 0.08, 0.28, 0.75), 0.91, 0.4)
    return finish(reverb(body(out), 0.28, 0.15))


SOUNDS = {"StormDraw": storm_draw, "StormReloadOut": storm_reload_out, "StormReloadIn": storm_reload_in,
          "StormHopper": storm_hopper}


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join("src", "RevNet", "Sounds")
    os.makedirs(out, exist_ok=True)
    for name, make in SOUNDS.items():
        x = make()
        write_wav(os.path.join(out, name + ".wav"), x)
        print("%-12s %.2f s" % (name, len(x) / RATE))


if __name__ == "__main__":
    main()
