"""The arm blades' sounds (CoopMechBlade, the Mech's and the Light Mech's), cut from real CC0 recordings as the Arm
Cannon's draw and reload are (tools/storm_foley.py's helpers; art/sounds/cc0, README there): synthesized, their thuds
were the "bouncing ball" the user heard in the cannon's. Timed to the owner's view (tools/blade_view.py): drawn, the
blades slide out and lock at about 0.3 s; put away, they are in by 0.2 s.

- BladeOut     steel drawn out of the forearms (a knife's draw, lower), locked (a latch, a dull knock)
- BladeIn      the latch let go, the steel slid back (a draw, backwards), seated with a click and a knock
- BladeSwing   a cut: a heavy blade's swish

  python -I tools/blade_sounds.py [out dir]     (default src/RevNet/Sounds; needs ffmpeg)
"""
import os, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from storm_foley import body, cut, lay
from storm_sounds import RATE, finish, n_, reverb, write_wav


def blade_out():
    out = np.zeros(n_(0.6))
    lay(out, cut("drawKnife3.ogg", 0.08, 0.42, 0.85), 0.04, 0.9)
    lay(out, cut("drawKnife1.ogg", 0.1, 0.36, 0.7), 0.06, 0.4)
    lay(out, cut("metalLatch.ogg", 0.02, 0.2, 0.9), 0.29, 0.8)
    lay(out, cut("doorClose_4.ogg", 0.08, 0.26, 0.9), 0.3, 0.35)
    return finish(reverb(body(out, 0.6), 0.22, 0.12))


def blade_in():
    out = np.zeros(n_(0.45))
    lay(out, cut("metalClick.ogg", 0.07, 0.16, 0.85), 0.0, 0.5)
    lay(out, cut("drawKnife3.ogg", 0.08, 0.36, 0.95)[::-1], 0.02, 0.8)
    lay(out, cut("metalClick.ogg", 0.25, 0.34, 0.8), 0.2, 0.7)
    lay(out, cut("doorClose_4.ogg", 0.08, 0.26, 0.85), 0.2, 0.4)
    return finish(reverb(body(out, 0.6), 0.2, 0.12), peak=0.85)


def blade_swing():
    out = np.zeros(n_(0.4))
    lay(out, cut("knifeSlice2.ogg", 0.0, 0.2, 0.8), 0.02, 1.0)
    return finish(reverb(body(out, 0.5), 0.2, 0.1), peak=0.8)


SOUNDS = {"BladeOut": blade_out, "BladeIn": blade_in, "BladeSwing": blade_swing}


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join("src", "RevNet", "Sounds")
    os.makedirs(out, exist_ok=True)
    for name, make in SOUNDS.items():
        x = make()
        write_wav(os.path.join(out, name + ".wav"), x)
        print("%-12s %.2f s" % (name, len(x) / RATE))


if __name__ == "__main__":
    main()
