"""The Mech's FPV drones' buzz (FPVBuzz: CoopFPV, CoopFPVGuided): a cheap racing quad's motors, not the Spy Drone's hum
(the user, 2026-10-30: "maybe making a different sound... not as advanced as the spy drone"). From a real CC0 recording
of a small FPV quad hovering (art/sounds/cc0/tinyhawk2_flight.mp3, README there): a steady stretch of its hover, pitched
down a quarter for a bigger quad's props, its ends crossfaded so it loops without a seam (a drone's ambient sound).

  python -I tools/drone_sound.py [out dir]     (default src/RevNet/Sounds; needs ffmpeg)
"""
import os, subprocess, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from storm_sounds import RATE, finish, write_wav

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "sounds", "cc0", "tinyhawk2_flight.mp3")
CUT = (30.0, 34.0)      # seconds of its steady hover (15-40 s; its tone about 1450 Hz)
PITCH = 0.76            # a bigger quad's lower whine (about 1100 Hz)
XFADE = 0.35            # seconds the loop's end blends into its start


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "RevNet", "Sounds")
    # More samples than it had (resampled to RATE / PITCH), played at RATE: slower, lower.
    raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", str(CUT[0]), "-t", str(CUT[1] - CUT[0]), "-i", SRC, "-f", "s16le",
                          "-ac", "1", "-ar", str(int(RATE / PITCH)), "-"], capture_output=True, check=True).stdout
    x = np.frombuffer(raw, "<i2") / 32768.0
    k = int(XFADE * RATE)
    a = np.linspace(0, np.pi / 2, k)
    body, tail = x[:-k].copy(), x[-k:]
    body[:k] = body[:k] * np.sin(a) + tail * np.cos(a)      # (equal power: the end fades into the start)
    y = finish(body, peak=0.9, fade=0)
    path = os.path.join(out, "FPVBuzz.wav")
    write_wav(path, y)
    print("FPVBuzz", path, "%.2f s loop" % (len(y) / RATE))


if __name__ == "__main__":
    main()
