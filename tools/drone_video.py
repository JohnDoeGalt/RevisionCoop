# The FPV Drones show's video (CoopTestDroneShow): its frames (tools/shot_take.py) on the game's clock as its log has
# them, cut and captioned, with a soundtrack mixed from the game's own sounds on the show's logged events, through
# tools/shot_video.py.
#   python -I tools/drone_video.py [--kits] <NetHost.log> <frames dir> <sounds dir> <out.mp4> [music.ogg]
# --kits: the fly kits' show (CoopTestFlyKitShow, docs/FLY_KITS.md): its captions; each payload's blast its own sound
# ("payload boom ... sound S": the projectile's ImpactSound, LAMExplode and the rest) instead of the drones' stand-ins;
# the kits' own buzz (src/RevNet/Sounds/FPVBuzz.wav, CoopFPV's AmbientSound).
# Sounds dir: DeusExSounds exported to WAV (HCC batchexport ..\System\DeusExSounds.u sound wav <dir>): the module's
# AugActivate/AugDeactivate, the drones' AugDroneLoop (each drone's AmbientSound, by its logged distance from the
# camera, frame by frame), the flown drone's blast SmallExplosion2 (CoopFPV's ImpactSound) and the hostiles' MaleDeath.
# The guided drones (levels 2-4) play no blast (CoopFPVGuided has no ImpactSound): SmallExplosion1/2 stand in.
# Music: Revision's own track for the level (01_NYC_Combat.ogg), quiet under it.
import json, os, re, subprocess, sys, wave
import numpy as np

RATE = 44100
FPS = 30
HERE = os.path.dirname(os.path.abspath(__file__))
REV_MUSIC = r"C:\Program Files (x86)\Steam\steamapps\common\Deus Ex\Revision\Music\01_NYC_Combat.ogg"
FPV_R, GUIDED_R = 25 * (24 + 1), 25 * (48 + 1)      # the drones' ambient radius (UE1: 25 * (SoundRadius + 1))
VOL = 192 / 255.0                                   # their SoundVolume


def parse(log):
    shots, ev = [], []
    for line in open(log, encoding="latin-1"):
        m = re.search(r"droneshow: shot (\d+) at ([\d.]+) buzz ?(.*?)\s*$", line)
        if m:
            fpv, guided = None, []
            parts = m.group(3).split(",") if m.group(3) else []
            if parts and parts[0] != "":
                fpv = float(parts[0])
            guided = [float(x) for x in parts[1:] if x]
            shots.append((float(m.group(2)), fpv, guided))
            continue
        m = re.search(r"droneshow: (.*) at ([\d.]+)\s*$", line)
        if m:
            ev.append((float(m.group(2)), m.group(1)))
    t0 = shots[0][0]
    return [(t - t0, f, g) for t, f, g in shots], [(t - t0, w) for t, w in ev]


def first(ev, prefix):
    for t, w in ev:
        if w.startswith(prefix):
            return t
    raise SystemExit("no '%s' in the log" % prefix)


def dist(w):
    m = re.search(r"dist (\d+)", w)
    return float(m.group(1)) if m else 1000.0


def load(sdir, name):
    w = wave.open(os.path.join(sdir, name + ".wav"))
    x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(float) / 32768.0
    if w.getnchannels() == 2:
        x = x.reshape(-1, 2).mean(1)
    r = w.getframerate()
    if r != RATE:
        x = np.interp(np.arange(int(len(x) * RATE / r)) * r / RATE, np.arange(len(x)), x)
    return x


def main():
    args = [a for a in sys.argv[1:] if a != "--kits"]
    kits = "--kits" in sys.argv
    log, frames, sdir, out = args[:4]
    music = args[4] if len(args) > 4 else REV_MUSIC
    out = os.path.abspath(out)
    shots, ev = parse(log)
    times = [t for t, f, g in shots]
    files = sorted(f for f in os.listdir(frames) if f.startswith("f") and f.endswith(".bmp"))
    if len(files) != len(shots):
        sys.exit("%d frames but %d shots logged" % (len(files), len(shots)))

    # The edit, on the show's clock: from the intro's first frame on the stage (the first are taken before the host
    # is moved there) to just after "done"; the white-out after the flown drone's blast (ThrownProjectile's
    # ClientFlash on the Mech, fading for ~1.8 s) cut short: its first instant kept, then on from when it has faded.
    intro, l1, l2, l3, l4 = (first(ev, "seg " + s) for s in ("intro", "L1", "L2", "L3", "L4"))
    done = first(ev, "done")
    booms = [t for t, w in ev if w.startswith("boom fpv")]
    l1b = next((t for t, w in ev if w == "seg L1b"), None)     # (the second flight, set off with the fire button)
    keep, a = [], intro + 0.1
    for b in booms:
        keep.append([a, b + 0.22])
        a = b + 1.45
    keep.append([a, done + 0.5])
    hold, fade = 3.0, 1.2
    starts = np.cumsum([0] + [b - a for a, b in keep])
    total = starts[-1] + hold

    def e(g):                                       # the edited time of g on the show's clock (None: cut before it)
        for i, (a, b) in enumerate(keep):
            if g < a:
                return None if i == 0 else starts[i]
            if g <= b:
                return starts[i] + g - a
        return starts[-1] + (g - keep[-1][1])

    def g_of(t):                                    # back: the show's clock at edited time t
        i = min(int(np.searchsorted(starts, t, side="right")) - 1, len(keep) - 1)
        return min(keep[i][0] + t - starts[i], keep[-1][1])

    # Captions, as lower thirds; the title over the intro, a card over the held end.
    big, small = 36, 23
    caps = []

    def card(t0, t1, title, sub):
        caps.append(dict(t0=t0, t1=t1, text=title, size=big, x=56, y="h-160"))
        caps.append(dict(t0=t0 + 0.15, t1=t1, text=sub, size=small, x=56, y="h-112"))

    if kits:
        caps.append(dict(t0=0.3, t1=e(l1) - 0.1, text="FK-7 FLY KITS", size=64, x=56, y="h-214"))
        caps.append(dict(t0=0.5, t1=e(l1) - 0.1, size=small, x=56, y="h-112",
                         text="the Mech's own explosives, flown in  ·  Deus Ex: Revision co-op (RevNet)"))
        card(e(l1) + 0.1, e(booms[0]) + 0.15, "Level 1  ·  a fly kit flown by the player, a LAM aboard",
             "seen from the kit; on contact it lets the LAM go")
        if l1b is not None and len(booms) > 1:
            card(e(l1b) + 0.1, e(booms[1]) + 0.15, "Level 1  ·  or let go with the fire button", "a LAM over two hostiles: one blast takes both")
        card(e(l2) + 0.05, e(l3) - 0.15, "Level 2  ·  a GEP rocket, guided to the crosshair", "the kit lets the rocket go: it flies on into its target")
        card(e(l3) + 0.05, e(l4) - 0.15, "Level 3  ·  a 20 mm HE round, locked on", "aimed 12° off the target: the kit locks on and chases it")
        card(e(l4) + 0.1, e(done) - 0.2, "Level 4  ·  a swarm of four, four explosives",
             "a LAM, a GEP rocket, a WP rocket, a 20 mm round: each goes off as itself")
    else:
        caps.append(dict(t0=0.3, t1=e(l1) - 0.1, text="FPV DRONES", size=64, x=56, y="h-214"))
        caps.append(dict(t0=0.5, t1=e(l1) - 0.1, size=small, x=56, y="h-112",
                         text="the Mech's Arsenal module  ·  Deus Ex: Revision co-op (RevNet)"))
        card(e(l1) + 0.1, e(booms[0]) + 0.15, "Level 1  ·  an FPV drone, flown by the player",
             "seen from the drone; steered by the view, it goes off on contact")
        if l1b is not None and len(booms) > 1:
            card(e(l1b) + 0.1, e(booms[1]) + 0.15, "Level 1  ·  or set off with the fire button", "over two hostiles: one blast takes both")
        card(e(l2) + 0.05, e(l3) - 0.15, "Level 2  ·  guided to the crosshair", "aim and launch: it flies to what the crosshair is on")
        card(e(l3) + 0.05, e(l4) - 0.15, "Level 3  ·  lock-on", "aimed 12° off the target: it locks on and chases it")
        card(e(l4) + 0.1, e(done) - 0.2, "Level 4  ·  a swarm of four",
             "they hover over the Mech; each press sends one at the hostile nearest the crosshair")
    end = starts[-1]
    caps.append(dict(t0=end + 0.2, t1=total - 0.2, text="RevNet  ·  Deus Ex: Revision co-op", size=46, x="(w-tw)/2", y="h/2-60", box=False))
    caps.append(dict(t0=end + 0.4, t1=total - 0.2, text=("the Mech's FK-7 Fly Kits" if kits else "the Mech's FPV Drones") + "  ·  in-game footage",
                     size=small, x="(w-tw)/2", y="h/2+10", box=False))

    # The soundtrack on the edited timeline.
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
            placed.append((round(float(t), 3), gain))

    blasts = [load(sdir, "SmallExplosion2"), load(sdir, "SmallExplosion1")]
    # Each payload's blast once: its first "payload boom" after a real "payload let go" (an early take's show logged an
    # exploding payload, still there, as let go again in the same instant; a rocket lingers, hidden, for seconds).
    real_booms = set()
    booms_at = {}
    for t, w in ev:
        m = re.match(r"payload boom (.*) sound ", w)
        if m:
            booms_at.setdefault(m.group(1), []).append((t, w))
    for t, w in ev:
        m = re.match(r"payload let go (.*) dist ", w)
        if not m or any(bt == t for bt, _ in booms_at.get(m.group(1), [])):
            continue
        nxt = [b for b in booms_at.get(m.group(1), []) if b[0] >= t]
        if nxt:
            real_booms.add(nxt[0])
    cry = load(sdir, "MaleDeath")
    k = 0
    for t, w in ev:
        if w == "aug on":
            put(e(t), load(sdir, "AugActivate"), 0.6)
        elif w.startswith("boom fpv"):
            if not kits:
                put(e(t), blasts[0], 1.0)                                   # the flown drone's own ImpactSound
            put(e(t) + 0.05, load(sdir, "AugDeactivate"), 0.45)            # the module off (Spent)
        elif w.startswith("payload boom") and (t, w) in real_booms:         # a kit's payload, its own sound
            m = re.search(r"sound (\S+) dist (\d+)", w)
            name = m.group(1) if m else "none"
            x = load(sdir, name) if os.path.exists(os.path.join(sdir, name + ".wav")) else blasts[1]
            put(e(t), x, 0.35 + 0.65 * max(0.0, 1 - dist(w) / 3000))
        elif w.startswith("boom guided") and not kits:
            put(e(t), blasts[k % 2], 0.3 + 0.7 * max(0.0, 1 - dist(w) / 3000))
            k += 1
        elif w.startswith("foe") and "down" in w and "dist" in w:
            # The hostile's death cry (PlaySound(Die)), quiet at a distance; a little higher or lower each time.
            pitch = 0.92 + 0.04 * (int(w.split()[1]) % 5)
            x = np.interp(np.arange(0, len(cry) - 1, pitch), np.arange(len(cry)), cry)
            put(e(t), x, max(0.08, 0.3 * (1 - dist(w) / 1600)))
    # The drones' buzz: each live drone's AmbientSound by its distance from the camera, frame by frame.
    env = np.zeros(int(total * FPS) + 2)
    for f in range(len(env)):
        t = f / FPS
        if t >= starts[-1]:
            break
        j = max(0, int(np.searchsorted(times, g_of(t) + 1e-4, side="right")) - 1)
        _, fpv, guided = shots[j]
        g2 = 0.0
        if fpv is not None:
            g2 += (VOL * max(0.0, 1 - fpv / FPV_R) ** 1.5) ** 2
        for d in guided:
            g2 += (VOL * max(0.0, 1 - d / GUIDED_R) ** 1.5) ** 2
        env[f] = np.sqrt(g2)
    loop = load(sdir, "AugDroneLoop") if not kits else load(os.path.join(HERE, "..", "src", "RevNet", "Sounds"), "FPVBuzz")
    buzz = np.tile(loop, n // len(loop) + 1)[:n]
    mix += buzz * np.interp(np.arange(n) / RATE, np.arange(len(env)) / FPS, env) * 0.42
    # Revision's music for the level under it all, faded in and out.
    track = out[:-4] + "_track.wav"
    mus_wav = out[:-4] + "_music.wav"
    # (From 6 s in: the end of its quiet opening, the full band 2 s later, under the title.)
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", "6", "-i", music, "-t", "%.2f" % (total + 1),
                    "-ac", "2", "-ar", str(RATE), mus_wav], check=True)
    mw = wave.open(mus_wav)
    mus = np.frombuffer(mw.readframes(mw.getnframes()), "<i2").astype(float).reshape(-1, 2) / 32768.0
    mus = np.pad(mus, ((0, max(0, n - len(mus))), (0, 0)))[:n]
    tt = np.arange(n) / RATE
    mus *= (np.clip(tt / 1.5, 0, 1) * np.clip((total - tt) / 2.5, 0, 1))[:, None] * 0.2
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
                fade=fade, track=track, captions=caps, grade="eq=gamma=1.6:saturation=1.12:contrast=1.04", dim=[float(end), 0.22])
    ej = out[:-4] + "_edit.json"
    json.dump(edit, open(ej, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    json.dump(dict(placed=placed, segments={s: round(float(e(t) or 0), 3) for s, t in
                                            [("intro", intro), ("L1", l1), ("L1b", l1b), ("L2", l2), ("L3", l3), ("L4", l4), ("done", done)]
                                            + [("boom%d" % i, b) for i, b in enumerate(booms)] if t is not None}),
              open(out[:-4] + "_events.json", "w"), indent=1)
    subprocess.run([sys.executable, "-I", os.path.join(HERE, "shot_video.py"), ej, out], check=True)


if __name__ == "__main__":
    main()
