"""The fly kits' rush (docs/FLY_KITS.md "In flight": "an increased whizzing sound when it goes at high speed"): the air
of the CC0 quadcopter fly-past (art/sounds/cc0/quadcopter_flyby.mp3, qubodup: its motors filtered out, above 900 Hz),
as a seamless loop. In game each machine plays it on a kit's look (CoopKitLook), louder with the kit's speed and pitched
by its closing speed on that machine's player (Doppler), as tools/flykit_video.py mixed the preview.
    python -I tools/fpv_rush.py            -> src/RevNet/Sounds/FPVRush.wav
"""
import os, sys
import numpy as np

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
sys.dont_write_bytecode = True
from storm_sounds import RATE, write_wav  # noqa: E402
from flykit_video import mono, looped  # noqa: E402

ROOT = os.path.dirname(here)


def rush():
    x = mono(os.path.join(ROOT, "art", "sounds", "cc0", "quadcopter_flyby.mp3"), 0.6, 1.6)
    sp = np.fft.rfft(x)
    sp[np.fft.rfftfreq(len(x), 1 / RATE) < 900] = 0          # its air, not its motors
    y = np.fft.irfft(sp, len(x))
    y = looped(y / (np.abs(y).max() + 1e-9), 0.4)
    return 0.9 * y / (np.abs(y).max() + 1e-9)


def demo():
    y = rush()
    assert 1.0 < len(y) / RATE < 1.6, len(y) / RATE
    assert np.abs(y).max() <= 0.9 + 1e-6
    k = int(0.01 * RATE)                                       # a seamless loop: its end leads into its start
    assert abs(float(np.sqrt(np.mean(y[:k] ** 2))) - float(np.sqrt(np.mean(y[-k:] ** 2)))) < 0.2


if __name__ == "__main__":
    demo()
    out = os.path.join(ROOT, "src", "RevNet", "Sounds", "FPVRush.wav")
    write_wav(out, rush())
    print(out)
