"""The arm blades' sounds (CoopMechBlade, the Mech's and the Light Mech's), cut from real CC0 recordings as the Arm
Cannon's draw and reload are (tools/storm_foley.py's helpers; art/sounds/cc0, README there): synthesized, their thuds
were the "bouncing ball" the user heard in the cannon's. Timed to the owner's view (tools/blade_view.py): drawn, the
housing rises, runs out of its port and the blade slides out, locked at about 0.63 s; put away, the reverse, in by
0.4 s.

- BladeOut     the housing rising (a click), running out of its port (a slide), steel drawn out of it (a knife's
               draw, lower), locked (a latch, a dull knock)
- BladeIn      the steel slid back (a draw, backwards), the housing let go and run back in, seated with a click and a
               knock
- BladeSwing   a cut: a heavy blade's swish

  python -I tools/blade_sounds.py [out dir]     (default src/RevNet/Sounds; needs ffmpeg)
"""
import os, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from storm_foley import body, cut, lay
from storm_sounds import RATE, finish, n_, reverb, write_wav


def blade_out():
    """On the draw's beats (blade_view.drawn, 0.7 s): the housing rises onto its line (0.2 s), runs out of its port
    over the wrist (0.29-0.5 s), the blade is drawn out of it (0.49 s) and locks (0.63 s)."""
    out = np.zeros(n_(0.85))
    lay(out, cut("metalClick.ogg", 0.07, 0.16, 0.85), 0.19, 0.55)
    lay(out, cut("drawKnife1.ogg", 0.1, 0.36, 0.7), 0.29, 0.35)
    lay(out, cut("drawKnife3.ogg", 0.08, 0.42, 0.85), 0.48, 0.9)
    lay(out, cut("metalLatch.ogg", 0.02, 0.2, 0.9), 0.62, 0.8)
    lay(out, cut("doorClose_4.ogg", 0.08, 0.26, 0.9), 0.63, 0.35)
    return finish(reverb(body(out, 0.6), 0.22, 0.12))


def blade_in():
    """On the put-away's beats (blade_view.put_away, 0.6 s): the blade slides in (0-0.17 s), the housing lets go
    (0.15 s), runs back into its port (0.2-0.34 s) and sinks out of sight (0.4 s)."""
    out = np.zeros(n_(0.6))
    lay(out, cut("drawKnife3.ogg", 0.08, 0.36, 0.95)[::-1], 0.0, 0.8)
    lay(out, cut("metalClick.ogg", 0.07, 0.16, 0.85), 0.15, 0.5)
    lay(out, cut("drawKnife1.ogg", 0.1, 0.36, 0.7)[::-1], 0.2, 0.3)
    lay(out, cut("metalClick.ogg", 0.25, 0.34, 0.8), 0.39, 0.7)
    lay(out, cut("doorClose_4.ogg", 0.08, 0.26, 0.85), 0.4, 0.4)
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
