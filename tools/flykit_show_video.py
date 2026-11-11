# The fly kits' show on video (CoopTestFlyKitShow, docs/FLY_KITS.md): its frames (tools/shot_take.py) on the game's
# clock as its log has them, captioned from the show's own "cap Title | line" events (each until the next), with a
# soundtrack mixed from the game's own sounds on the show's logged events, through tools/shot_video.py.
#   python -I tools/flykit_show_video.py <NetHost.log> <frames dir> <sounds dir> <out.mp4> [music.ogg]
# Sounds dir: DeusExSounds exported to WAV (HCC batchexport ..\System\DeusExSounds.u sound wav <dir>). Each payload's
# blast is its projectile's own ImpactSound ("payload boom ... sound S"), once per real release (an exploding payload
# still there, or a rocket lingering hidden, may be seen again); the module's AugActivate / AugDeactivate; the targets'
# death cries; the kits' buzz (src/RevNet/Sounds/FPVBuzz.wav, CoopFPV's AmbientSound) by each kit's distance from the
# camera frame by frame, the flown kit's pitched with its speed (CoopFPV.GearPitch 54 / 64 / 80 of 64); Revision's own
# music for the level quiet under it all.
import json, os, re, subprocess, sys, wave
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from drone_video import load, dist, RATE, REV_MUSIC, VOL

HERE = os.path.dirname(os.path.abspath(__file__))
FPS = 30
KIT_R = 25 * (24 + 1)           # a kit's ambient radius (UE1: 25 * (SoundRadius + 1))
PITCH = {0: 54 / 64.0, 1: 1.0, 2: 80 / 64.0}


def parse(log):
    shots, ev = [], []
    for line in open(log, encoding="latin-1"):
        m = re.search(r"droneshow: shot (\d+) at ([\d.]+) buzz ?(.*?) gear (\d)\s*$", line)
        if m:
            parts = m.group(3).split(",") if m.group(3) else []
            fpv = float(parts[0]) if parts and parts[0] != "" else None
            guided = [float(x) for x in parts[1:] if x]
            shots.append((float(m.group(2)), fpv, guided, int(m.group(4))))
            continue
        m = re.search(r"droneshow: (.*) at ([\d.]+)\s*$", line)
        if m:
            ev.append((float(m.group(2)), m.group(1)))
    t0 = shots[0][0]
    return [(t - t0, f, g, gr) for t, f, g, gr in shots], [(t - t0, w) for t, w in ev]


def real_booms(ev):
    """Each payload's blast once: its first "payload boom" after a real "payload let go" (not one logged in the same
    instant as a blast of that payload: the same payload seen again)."""
    booms_at, real = {}, set()
    for t, w in ev:
        m = re.match(r"payload boom (.*) sound ", w)
        if m:
            booms_at.setdefault(m.group(1), []).append((t, w))
    for t, w in ev:
        m = re.match(r"payload let go (.*) dist ", w)
        if not m or any(bt == t for bt, _ in booms_at.get(m.group(1), [])):
            continue
        nxt = [b for b in booms_at.get(m.group(1), []) if b[0] >= t and b not in real]
        if nxt:
            real.add(nxt[0])
    return real


def main(ending="the Mech's FK-7 Fly Kits  ·  in-game footage", grade="eq=gamma=1.6:saturation=1.12:contrast=1.04"):
    log, frames, sdir, out = sys.argv[1:5]
    music = sys.argv[5] if len(sys.argv) > 5 else REV_MUSIC
    out = os.path.abspath(out)
    shots, ev = parse(log)
    times = [s[0] for s in shots]
    files = sorted(f for f in os.listdir(frames) if f.startswith("f") and f.endswith(".bmp"))
    if len(files) != len(shots):
        sys.exit("%d frames but %d shots logged" % (len(files), len(shots)))
    intro = next(t for t, w in ev if w == "seg intro")
    done = next(t for t, w in ev if w == "done")
    keep = [[intro + 0.05, done + 1.8]]
    hold, fade = 3.5, 1.2
    starts = [0.0, keep[0][1] - keep[0][0]]
    total = starts[-1] + hold
    e = lambda g: None if g < keep[0][0] else min(g, keep[0][1]) - keep[0][0]

    # Captions: the title big over the opening, then each scene's as a lower third until the next; each up at least
    # READ seconds, one at a time (a short scene's pushes the next one later, never over it).
    READ = 2.2
    caps = []
    cs = [(t, w[4:]) for t, w in ev if w.startswith("cap ")]
    last = -1.0
    for i, (t, w) in enumerate(cs):
        title, _, line = w.partition(" | ")
        t1 = cs[i + 1][0] if i + 1 < len(cs) else done
        a = max(e(t) or 0.0, last + 0.1)
        b = max(e(t1) - 0.15, a + READ)
        last = b
        if i == 0:
            caps.append(dict(t0=a + 0.3, t1=b, text=title, size=64, x=56, y="h-214"))
            caps.append(dict(t0=a + 0.5, t1=b, text=line, size=23, x=56, y="h-112"))
        else:
            caps.append(dict(t0=a + 0.1, t1=b, text=title, size=36, x=56, y="h-160"))
            caps.append(dict(t0=a + 0.25, t1=b, text=line, size=23, x=56, y="h-112"))
    end = starts[-1]
    caps.append(dict(t0=end + 0.2, t1=total - 0.2, text="RevNet  ·  Deus Ex: Revision co-op", size=46, x="(w-tw)/2", y="h/2-60", box=False))
    caps.append(dict(t0=end + 0.4, t1=total - 0.2, text=ending,
                     size=23, x="(w-tw)/2", y="h/2+10", box=False))

    # The soundtrack.
    n = int(total * RATE) + RATE
    mix = np.zeros(n)
    placed = []

    def put(t, x, gain):
        if t is None:
            return
        i = int(t * RATE)
        j = min(n, i + len(x))
        if j > i:
            mix[i:j] += x[:j - i] * gain
            placed.append((round(float(t), 3), round(gain, 3)))

    real = real_booms(ev)
    cry = load(sdir, "MaleDeath")
    fallback = load(sdir, "SmallExplosion1")
    for t, w in ev:
        if w == "aug on":
            put(e(t), load(sdir, "AugActivate"), 0.5)
        elif w.startswith("aps shot"):                                      # Active Protection's 20 mm charge
            put(e(t), load(sdir, "AssaultGunFire20mm"), 0.7)
        elif w.startswith("boom fpv"):
            put(e(t) + 0.05 if e(t) is not None else None, load(sdir, "AugDeactivate"), 0.35)
        elif w.startswith("payload boom") and (t, w) in real:
            m = re.search(r"sound (\S+) dist (\d+)", w)
            name = m.group(1) if m else "none"
            x = load(sdir, name) if os.path.exists(os.path.join(sdir, name + ".wav")) else fallback
            put(e(t), x, 0.35 + 0.65 * max(0.0, 1 - dist(w) / 3000))
        elif w.startswith("foe") and "down" in w and "dist" in w:
            pitch = 0.92 + 0.04 * (int(w.split()[1]) % 5)
            x = np.interp(np.arange(0, len(cry) - 1, pitch), np.arange(len(cry)), cry)
            put(e(t), x, max(0.08, 0.3 * (1 - dist(w) / 1600)))
    # The kits' buzz: each live kit's by its distance from the camera; the flown one's pitched with its speed.
    loop = load(os.path.join(HERE, "..", "src", "RevNet", "Sounds"), "FPVBuzz")
    tt = np.arange(n) / RATE
    gt = np.array([min(keep[0][0] + t, keep[0][1]) for t in tt[::RATE // FPS]])
    idx = np.clip(np.searchsorted(times, gt, side="right") - 1, 0, len(shots) - 1)
    g_fpv = np.array([(VOL * max(0.0, 1 - shots[j][1] / KIT_R) ** 1.5) if shots[j][1] is not None else 0.0 for j in idx])
    g_guided = np.array([np.sqrt(sum((VOL * max(0.0, 1 - d / KIT_R) ** 1.5) ** 2 for d in shots[j][2])) for j in idx])
    rate = np.array([PITCH.get(shots[j][3], 1.0) for j in idx])
    ft = tt[::RATE // FPS]
    rate_s = np.interp(tt, ft, rate)
    phase = np.cumsum(rate_s) % len(loop)
    fpv_track = np.interp(phase, np.arange(len(loop)), loop)
    guided_track = np.tile(loop, n // len(loop) + 1)[:n]
    alive = tt < end
    mix += fpv_track * np.interp(tt, ft, g_fpv) * 0.45 * alive
    mix += guided_track * np.interp(tt, ft, g_guided) * 0.4 * alive
    # Revision's music for the level under it all, faded in and out.
    track = out[:-4] + "_track.wav"
    mus_wav = out[:-4] + "_music.wav"
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", "6", "-stream_loop", "-1", "-i", music,
                    "-t", "%.2f" % (total + 1), "-ac", "2", "-ar", str(RATE), mus_wav], check=True)
    mw = wave.open(mus_wav)
    mus = np.frombuffer(mw.readframes(mw.getnframes()), "<i2").astype(float).reshape(-1, 2) / 32768.0
    mus = np.pad(mus, ((0, max(0, n - len(mus))), (0, 0)))[:n]
    mus *= (np.clip(tt / 1.5, 0, 1) * np.clip((total - tt) / 2.5, 0, 1))[:, None] * 0.18
    st = mix[:, None] + mus
    st = np.tanh(st * 1.2) / np.tanh(1.2)
    st *= 0.93 / max(1e-9, np.abs(st).max())
    st = st[:int(total * RATE)]
    w = wave.open(track, "wb")
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes((np.clip(st, -1, 1) * 32767).astype("<i2").tobytes())
    w.close()

    edit = dict(frames=[os.path.join(os.path.abspath(frames), f) for f in files], times=times, keep=keep, hold=hold,
                fade=fade, track=track, captions=caps, grade=grade, dim=[float(end), 0.22])
    ej = out[:-4] + "_edit.json"
    json.dump(edit, open(ej, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    json.dump(dict(placed=placed, segments={w[4:]: round(float(e(t) or 0), 3) for t, w in ev if w.startswith("seg ")},
                   captions=[(round(float(e(t) or 0), 2), w[4:]) for t, w in cs]),
              open(out[:-4] + "_events.json", "w"), indent=1)
    subprocess.run([sys.executable, "-I", os.path.join(HERE, "shot_video.py"), ej, out], check=True)


if __name__ == "__main__":
    main()
