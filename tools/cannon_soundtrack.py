# The Arm Cannon show's soundtrack, mixed from its own sounds (src/RevNet/Sounds) on CoopTestCannonShow's timeline
# (seconds from the draw, as the game logged them): drawn, full auto held 1.8 s (a shot every 0.1 s), the mode chirp,
# Storm held 1.4 s (its loop, then its tail), Spread's three blasts, the reload.
#   python -I tools/cannon_soundtrack.py <out.wav> [lead seconds]
import json, os, sys, wave
import numpy as np

SND = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "RevNet", "Sounds")
RATE = 44100


def load(name):
    w = wave.open(os.path.join(SND, name + ".wav"))
    x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(float) / 32768.0
    if w.getnchannels() == 2:
        x = x.reshape(-1, 2).mean(1)
    assert w.getframerate() == RATE, name
    return x


def events(lead):
    # The filmed take's log (seconds from the draw); the reload's second half where its frames show the new brick
    # seated (17.91 s into the video: the slam, 0.33 s into StormReloadIn), as the game plays it with ReloadEnd.
    ev = [(0.0, "StormDraw", 1.0)]
    ev += [(2.0 + 0.105 * k, "StormShot", 0.75) for k in range(17)]
    ev += [(t, "StormMode", 0.6) for t in (4.61, 8.45, 12.36)]
    ev += [(5.81, "StormLoop:1.4", 0.9), (7.21, "StormTail", 0.9)]
    ev += [(t, "StormBlast", 1.0) for t in (9.65, 10.55, 11.46)]
    ev += [(13.36, "StormReloadOut", 1.0), (16.07, "StormReloadIn", 1.0)]
    return [(t + lead, n, g) for t, n, g in ev]


def main():
    out = sys.argv[1]
    lead = float(sys.argv[2]) if len(sys.argv) > 2 else 0.8
    total = lead + 17.2
    mix = np.zeros(int(total * RATE))
    for t, name, gain in events(lead):
        if ":" in name:                                   # a loop held for so long
            name, held = name.split(":")
            x = load(name)
            x = np.tile(x, int(float(held) * RATE / len(x)) + 2)[:int(float(held) * RATE)]
            x[-int(0.03 * RATE):] *= np.linspace(1, 0, int(0.03 * RATE))
        else:
            x = load(name)
        i = int(t * RATE)
        j = min(len(mix), i + len(x))
        mix[i:j] += x[:j - i] * gain
    mix = np.tanh(mix * 1.1) / np.tanh(1.1) * 0.92 / max(1e-9, np.abs(np.tanh(mix * 1.1) / np.tanh(1.1)).max())
    w = wave.open(out, "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes((np.clip(mix, -1, 1) * 32767).astype("<i2").tobytes())
    w.close()
    json.dump(events(lead), open(out[:-4] + "_events.json", "w"))
    print("soundtrack", out, "%.1f s" % total)


if __name__ == "__main__":
    main()
