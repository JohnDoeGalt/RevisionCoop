# The fly kit's motion preview (tools/flykit.py motion, rendered by tools/flykit_render.py) made a video. Its
# soundtrack, as the game would make it (the user, 2026-10-30: "the Doppler effect... an increased whizzing sound when
# it goes at high speed... versus its normal loitering sound"): its hum (FPVBuzz, the CC0 FPV recording) pitched up
# and louder with its throttle; a rush (the CC0 quadcopter fly-past's whoosh, its air only) swelling with its throttle;
# both shifted by Doppler from its closing speed on the camera (sound's real speed: 343 m/s, 18000 units a second) and
# quieter with distance; on the fly-past (100 mph, 2347 units a second: a drop of about 4.5 semitones) the real
# recording's own pass laid under it, its loudest at the closest approach, bent by the same Doppler (it was a slow
# pass: its tones barely move, and unbent they masked the drop). Then the frames, the captions and this into an MP4,
# with the demo videos' title and end card (tools/shot_video.py).
#   python -I tools/flykit_video.py build/mech/flykit/motion/motion.json build/mech/flykit/motion_png build/video/flykit_flight.mp4
import glob, json, os, subprocess, sys
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from storm_sounds import RATE, write_wav
from demo_video import read

CAM = np.array([23.5, -16.5, 9.8])      # the preview's camera (tools/flykit_render.py), in the kit's frame
SOUND = 343.0 * 52.5                    # units a second (sound's real speed: 16 units a foot)
PASS_PEAK = 1.29                        # seconds into quadcopter_flyby.mp3 of its loudest (measured)


def mono(path, ss=None, t=None):
    cmd = ["ffmpeg", "-v", "error"] + (["-ss", str(ss)] if ss is not None else []) + (["-t", str(t)] if t else []) + \
          ["-i", path, "-ac", "1", "-ar", str(RATE), "-f", "s16le", "-"]
    return np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, "<i2") / 32768.0


def looped(x, xfade=0.3):
    k = int(xfade * RATE)
    a = np.linspace(0, np.pi / 2, k)
    y = x[:-k].copy()
    y[:k] = y[:k] * np.sin(a) + x[-k:] * np.cos(a)
    return y


def played(loop, rate):
    """The loop played at a rate changing every sample (1: as recorded)."""
    ph = np.cumsum(rate) % len(loop)
    i = ph.astype(int)
    f = ph - i
    return loop[i] * (1 - f) + loop[(i + 1) % len(loop)] * f


def main():
    spec = json.load(open(sys.argv[1]))
    frames, out = sys.argv[2], os.path.abspath(sys.argv[3])
    fps, st = spec["fps"], spec["states"]
    n = int(len(st) / fps * RATE)
    tf = np.arange(len(st)) / fps
    ts = np.arange(n) / RATE
    thr = np.interp(ts, tf, [s["throttle"] for s in st])
    at = np.array([s["at"] for s in st])
    dist = np.linalg.norm(at - CAM, axis=1)
    closing = -np.gradient(dist) * fps                       # units a second toward the camera
    closing[np.abs(closing) > 3000] = 0                       # (the cuts to and from the fly-past are no speed)
    dop = np.interp(ts, tf, SOUND / (SOUND - closing))
    gain = np.interp(ts, tf, np.clip(120.0 / (dist + 90.0), 0.02, 1.6))     # (1 at the hover's 30)
    hum = played(looped(mono(os.path.join(ROOT, "src", "RevNet", "Sounds", "FPVBuzz.wav"))), (1.1 + 0.3 * thr) * dop)
    rush_src = mono(os.path.join(ROOT, "art", "sounds", "cc0", "quadcopter_flyby.mp3"), 0.6, 1.6)
    sp = np.fft.rfft(rush_src)
    fr = np.fft.rfftfreq(len(rush_src), 1 / RATE)
    sp[fr < 900] = 0                                          # (its air, not its motors)
    rush = np.fft.irfft(sp, len(rush_src))
    rush = played(looped(rush / (np.abs(rush).max() + 1e-9), 0.4), (0.85 + 0.4 * thr) * dop)
    mix = gain * (hum * (0.5 + 0.4 * thr) + rush * (0.08 + 0.85 * thr ** 1.6))
    if dist.max() > 400:                                      # a fly-past: the real one's pass at its closest
        near = int(np.argmin(np.where(dist > 60, dist, np.inf)))          # (the hover is nearer: 30)
        rec = mono(os.path.join(ROOT, "art", "sounds", "cc0", "quadcopter_flyby.mp3"))
        rec = rec / (np.abs(rec).max() + 1e-9)
        cum = np.cumsum(dop)                                  # (its pass bent by the same Doppler: it was slow)
        ph = PASS_PEAK * RATE + cum - cum[int(near / fps * RATE)]
        ok = (ph >= 0) & (ph < len(rec) - 1)
        i = ph[ok].astype(int)
        mix[ok] += 0.5 * (rec[i] * (1 - (ph[ok] - i)) + rec[i + 1] * (ph[ok] - i))
        print("pass at %.2f s, %.0f units" % (near / fps, dist[near]))
    mix = np.tanh(mix * 1.2)
    mix *= 0.9 / (np.abs(mix).max() + 1e-9)
    mix *= np.clip((n / RATE - ts) / 1.0, 0, 1)               # (out with the picture's fade to black)
    wav = out[:-4] + "_track.wav"
    write_wav(wav, mix)

    # The picture, the captions and the cards as every demo video has them (tools/demo_video.py, tools/shot_video.py):
    # the title and its line over the opening hover, each manoeuvre's caption top left, the end card over the closing
    # hover (the picture dimmed, still moving), a fade to black.
    total = len(st) / fps
    caps = [dict(t0=0.15, t1=spec["captions"][0][0] - 0.05, text=spec["title"], size=54, x=48, y=40),
            dict(t0=0.3, t1=spec["captions"][0][0] - 0.05, text=spec["line"], size=28, x=48, y=112)]
    caps += [dict(t0=a + 0.05, t1=b - 0.05, text=label, size=38, x=48, y=40) for a, b, label in spec["captions"]]
    caps += [dict(t0=spec["outro"] + 0.2, t1=total - 0.2, text="RevNet  ·  Deus Ex: Revision co-op", size=46,
                  x="(w-tw)/2", y="h/2-60", box=False),
             dict(t0=spec["outro"] + 0.4, t1=total - 0.2, text=spec["line"] + "  ·  concept render", size=28,
                  x="(w-tw)/2", y="h/2+10", box=False)]
    for c in caps[:1] + caps[2:-2]:
        text = c["text"] + (" " + spec["line"] if c is caps[0] else "")
        if c["t1"] - c["t0"] < read(text) - 0.1 - 1e-6:          # (to the hundredth: not rounding)
            print("SHORT: %r up %.1f s, needs %.1f s" % (text, c["t1"] - c["t0"], read(text)))
    shots = sorted(glob.glob(os.path.join(os.path.abspath(frames), "r*.png")))
    edit = dict(frames=shots, times=[k / fps for k in range(len(shots))], keep=[[0.0, total]], hold=0, fade=1.0,
                track=wav, captions=caps, fps=fps, dim=[spec["outro"], 0.3])
    ej = out[:-4] + "_edit.json"
    json.dump(edit, open(ej, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools", "shot_video.py"), ej, out], check=True)


if __name__ == "__main__":
    main()
