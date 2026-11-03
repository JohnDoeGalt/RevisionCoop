"""The FK-7 in-setting promo (docs/FK7_PROMO.md; the user, 2026-10-30: "an in-setting defense promo video... like one of
those defense contractors promo videos"): voice E's whole take (voice library fk7_E_broadcast, the user's
pick) over the fly-kit preview's flight, the swarm on Liberty Island with its gun-cam strikes, and product shots made
here (the kit turning on each payload, the bonding pads close up), with the script's title card, lower thirds and
capability cards, a quiet synthesized bed (no licence to clear) and the footage's own sounds low under the voice.
  python -I tools/flykit_promo.py shots [out dir]          the product shots' OBJs and shots.json (default build/mech/flykit)
  blender -b --factory-startup --python tools/flykit_render.py -- <shots.json> <png dir>
  python -I tools/flykit_promo.py cut <out.mp4>            the edit (frames from the three renders), the mix, the cards
"""
import json, math, os, subprocess, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flykit
from flykit import rot

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
FK = os.path.join(ROOT, "build", "mech", "flykit")
FPS = 30
# The product shots: (name, payload, seconds, kind): a turntable (the kit turning 18 degrees a second, fans spinning,
# a slow bob) or the pads close up (the camera pushing in on the near pad, the kit still).
SHOTS = [("lam", "LAM", 12.0, "turn"), ("lam2", "LAM", 5.0, "turn"), ("gep", "GEP rocket", 5.0, "turn"),
         ("round", "20 mm HE", 5.0, "turn"), ("pads", "LAM", 12.5, "pads"), ("price", "GEP rocket", 7.5, "turn")]


def shots(out):
    """Every product shot's frames (an OBJ each), its camera and its place in shots.json."""
    dirn = os.path.join(out, "promo")
    os.makedirs(dirn, exist_ok=True)
    kits, frames, states, index = {}, [], [], {}
    for name, payload, seconds, kind in SHOTS:
        if payload not in kits:
            kits[payload] = flykit.build(payload, out)
        st = kits[payload]
        index[name] = [len(frames), int(round(seconds * FPS))]
        for f in range(index[name][1]):
            t = f / FPS
            faces = flykit.tilted(flykit.spun(st["p"], 720.0 * t), st["p"], 0.0, 0.0)
            if kind == "turn":
                Rb, at = rot(35 + 18 * t, "z"), np.array([0, 0, 0.25 * math.sin(2 * math.pi * 0.6 * t)])
                eye, look, lens = [21.0, -14.8, 6.5], [0.0, 0.0, -0.6], 50.0
            else:
                Rb, at = rot(0, "z"), np.zeros(3)
                u = t / seconds
                eye = [5.5 - 1.5 * u, -12.0 + 4.0 * u, -1.0 - 0.6 * u]
                look, lens = [2.3, -3.3, -3.0], 50.0
            path = os.path.join(dirn, "%s_%04d.obj" % (name, f))
            frames.append(flykit.obj(path, st, faces, lambda q, Rb=Rb, at=at: Rb @ q + at, blur=True))
            states.append(dict(eye=eye, look=look, lens=lens))
    json.dump(dict(frames=frames, states=states, index=index, fps=FPS, studio=flykit.STUDIO),
              open(os.path.join(dirn, "shots.json"), "w"))
    print("shots: %d frames" % len(frames))


# ---- the cut
VO = os.environ.get("FK7_VO", "fk7_vo.wav")  # (the user's pick: E, its whole take)
OFF = 1.0                                   # the voice starts a beat in
# Where each script section starts in that take (faster-whisper "small" word times, the script aligned to them), and
# where it ends.
SECTIONS = [0.0, 5.16, 16.96, 31.48, 43.64, 56.30, 64.16, 80.22, 91.42, 98.80]
VO_END, HOLD = 102.76, 5.0                  # (the end card held after the last word)
# The picture, section by section: (source, from, seconds) in the source's own time. kit: the fly-kit preview (60 fps,
# tools/flykit.py motion); swarm: the swarm on Liberty Island with its gun-cam overlay and static (30 fps,
# tools/flykit_swarm.py); a shot's name: the product shots above.
EDIT = [[("kit", 0.4, None)],
        [("lam", 0.0, None)],
        [("lam2", 0.0, 1 / 3), ("gep", 0.0, 1 / 3), ("round", 0.0, 1 / 3)],
        [("pads", 0.0, None)],
        [("kit", 4.6, 2.0), ("kit", 7.0, 2.5), ("kit", 12.1, 2.5), ("kit", 14.6, 2.0), ("kit", 21.7, None)],
        [("swarm", 0.2, None)],
        [("swarm", 7.5, 4.5), ("swarm", 12.0, 9.5), ("swarm", 21.5, None)],
        [("swarm", 9.6, 2.4), ("kit", 17.2, 4.8), ("kit", 9.6, 2.4), ("kit", 4.6, None)],
        [("price", 0.0, None)],
        [("kit", 22.8, 5.7)]]                       # (then its last frame held, dimmed, under the end card)
# The cards (the script's on-screen text): (from, to, text, size, where) on the video's clock; where: "title" centred
# big, "lower" a lower third, "top" top left, "pov" top middle (clear of the gun-cam overlay), "fine" small bottom right.
CARDS = [(3.6, 6.1, "FK-7 FLY KIT", 64, "title"), (3.9, 6.1, "CORVANE ORDNANCE  \u00b7  AFFORDABLE PRECISION", 26, "sub"),
         (7.2, 12.2, "FK-7 FLY KIT  \u00b7  LOT 52-0318  \u00b7  MFD 03/2052", 26, "lower"),
         (12.6, 17.7, "18 x 31 CM  \u00b7  MODULAR  \u00b7  STOCKPILE-AGNOSTIC", 26, "lower"),
         (18.6, 32.2, "PAYLOADS: 7  \u00b7  MISSION-CONFIGURABLE", 34, "top"),
         (18.8, 22.6, "LAM", 30, "lower"), (23.6, 27.4, "GEP ROCKET  \u00b7  HE / WP", 30, "lower"),
         (28.4, 32.2, "20 MM HE  \u00b7  GAS  \u00b7  EMP  \u00b7  SCRAMBLE", 30, "lower"),
         (27.0, 32.2, "Not rated for the LAW.", 18, "fine"),
         (34.0, 44.4, "ThresholdBond\u2122  \u00b7  VOLTAGE-SWITCHABLE ADHESION", 34, "top"),
         (35.5, 44.4, "PAT. 2049-77410  \u00b7  NO CURRENT, NO HEAT AT THE FUZE", 24, "lower"),
         (49.3, 53.4, "TwinVector\u2122  \u00b7  INDEPENDENT THRUST VECTORING  \u00b7  1000\u00b0/S", 30, "top"),
         (53.8, 57.4, "TriGear\u2122  \u00b7  26 / 47 / 100 MPH", 34, "top"),
         (58.0, 61.6, "BareFrame\u2122 RECON MODE  \u00b7  25 S FLAT OUT / 60 S AS LEAD", 28, "lower"),
         (61.9, 65.0, "ATTRITABLE  \u00b7  SCALABLE  \u00b7  FORCE MULTIPLIER", 28, "lower"),
         (66.0, 69.6, "Shepherd\u2122 SWARM CONTROL  \u00b7  LEAD + UP TO 4", 30, "top"),
         (70.6, 75.0, "TallySight\u2122  \u00b7  BOX  \u00b7  LOCK  \u00b7  MARK", 28, "pov"),
         (81.6, 85.2, "IN SERVICE WITH UNATCO SINCE 2051  \u00b7  ORGANIC PRECISION SUPPORT", 26, "top"),
         (85.6, 92.2, "MAJ. INGRID HALLORAN  \u00b7  UNATCO TACTICAL SUPPORT", 26, "lower"),
         (92.8, 100.6, "UNIT COST: FROM 390 CR (LOT PRICING)", 30, "top"),
         (94.4, 100.6, "ONE PART NUMBER  \u00b7  ONE AFTERNOON OF TRAINING", 26, "top2"),
         (96.0, 100.6, "LOWER COST PER EFFECT  \u00b7  REDUCED LOGISTICS TAIL", 26, "top3"),
         (101.4, 108.6, "CORVANE ORDNANCE", 58, "title"), (101.7, 108.6, "AFFORDABLE PRECISION", 24, "sub"),
         (102.4, 108.6, "Precision you already own.", 30, "sub2"),
         (103.0, 108.6, "FK-7 Fly Kit. Export subject to licence. Corvane Ordnance accepts no liability for payloads "
                        "outside the certified list.", 15, "fine1"),
         (103.0, 108.6, "RevNet  \u00b7  Deus Ex: Revision co-op  \u00b7  concept render", 15, "fine2")]
PLACE = {"title": ("(w-tw)/2", "h/2-90", True), "sub": ("(w-tw)/2", "h/2-10", False), "sub2": ("(w-tw)/2", "h/2+40", False),
         "lower": (48, "h-130", True), "top": (48, 40, True), "top2": (48, 96, True), "top3": (48, 146, True),
         "pov": ("(w-tw)/2", 100, True), "fine": ("w-tw-24", "h-34", False),
         "fine1": ("(w-tw)/2", "h-58", False), "fine2": ("(w-tw)/2", "h-34", False)}


def source(kind, t):
    """A source's frame at its time t: its path."""
    if kind == "kit":
        return os.path.join(FK, "motion_png", "r%04d.png" % min(1709, int(round(t * 60))))
    if kind == "swarm":
        return os.path.join(FK, "swarm_png_cut", "c%04d.png" % min(794, int(round(t * 30))))
    shots_ = json.load(open(os.path.join(FK, "promo", "shots.json")))
    a, n = shots_["index"][kind]
    return os.path.join(FK, "promo_png", "r%04d.png" % (a + min(n - 1, int(round(t * 30)))))


def bed(n, rate):
    """A quiet bed: slow minor chords on a soft pad (a few harmonics, slow swell), a low pulse, a faint tick."""
    t = np.arange(n) / rate
    chords = [(110.0, 164.8, 220.0, 261.6), (87.3, 130.8, 174.6, 220.0), (130.8, 196.0, 261.6, 329.6),
              (98.0, 146.8, 196.0, 246.9)]
    out = np.zeros(n)
    bar = 8.0
    for k in range(int(n / rate / bar) + 1):
        a, b = int(k * bar * rate), min(n, int((k + 1.25) * bar * rate))
        if a >= n:
            break
        tt = t[a:b] - t[a]
        env = np.clip(tt / 2.5, 0, 1) * np.clip((bar * 1.25 - tt) / 2.5, 0, 1)
        for f in chords[k % 4]:
            for h in range(1, 6):
                out[a:b] += env * np.sin(2 * math.pi * f * h * tt * (1 + 0.002 * h)) / (h * h) * 0.25
    beat = 60 / 92.0
    ph = (t % beat) / beat
    out += 0.35 * np.sin(2 * math.pi * 52 * t) * np.exp(-ph * 9)
    tick = np.random.default_rng(1).normal(0, 1, n) * np.exp(-((t % (beat / 2)) / (beat / 2)) * 40)
    sp = np.fft.rfft(tick)
    sp[np.fft.rfftfreq(n, 1 / rate) < 5000] = 0
    out += 0.03 * np.fft.irfft(sp, n)
    return out / (np.abs(out).max() + 1e-9)


def cut(out):
    from storm_sounds import RATE, write_wav
    from flykit_video import mono
    out = os.path.abspath(out)
    starts = [s + OFF for s in SECTIONS] + [VO_END + OFF + HOLD]
    total = starts[-1]
    frames, times, sfx = [], [], []                     # (sfx: each clip's own sound: source, from, at, seconds)
    for k, clips in enumerate(EDIT):
        t0 = 0.0 if k == 0 else starts[k]
        span = starts[k + 1] - t0
        # (a clip's length: seconds given; a fraction (< 1) of its section; none: an equal share of what is left)
        given = sum(d if d >= 1 else span * d for _, _, d in clips if d)
        free = sum(1 for _, _, d in clips if not d)
        at = t0
        for kind, frm, d in clips:
            dur = d if d and d >= 1 else span * d if d else (span - given) / free
            for q in range(int(round(dur * FPS))):
                frames.append(source(kind, frm + q / FPS))
                times.append(at + q / FPS)
            sfx.append((kind, frm, at, dur))
            at += dur
    # The sound: the voice, the footage's own sounds low under it, the bed lower still.
    n = int(total * RATE)
    mix = np.zeros(n)
    vo = mono(VO)
    a = int(OFF * RATE)
    mix[a:a + len(vo)] += vo[:n - a] / (np.abs(vo).max() + 1e-9) * 0.95
    tracks = {"kit": mono(os.path.join(ROOT, "build", "video", "flykit_flight_track.wav")),
              "swarm": mono(os.path.join(ROOT, "build", "video", "flykit_swarm_track.wav"))}
    hum = mono(os.path.join(ROOT, "src", "RevNet", "Sounds", "FPVBuzz.wav"))
    for kind, frm, at, dur in sfx:
        src = tracks.get(kind)
        if src is None:                                  # (a product shot: its fans' hum, quiet)
            src, frm = np.tile(hum, int(dur * RATE / len(hum)) + 2), 0.0
        s0, a0, m = int(frm * RATE), int(at * RATE), int(dur * RATE)
        piece = src[s0:s0 + m]
        fade = np.clip(np.arange(len(piece)) / (0.08 * RATE), 0, 1) * np.clip((len(piece) - np.arange(len(piece))) / (0.08 * RATE), 0, 1)
        mix[a0:a0 + len(piece)] += piece * fade * (0.32 if kind in tracks else 0.08)
    mix += bed(n, RATE) * 0.16 * np.clip(np.arange(n) / (2.5 * RATE), 0, 1)
    mix = np.tanh(mix * 1.15)
    mix *= 0.92 / (np.abs(mix).max() + 1e-9)
    mix *= np.clip((n - np.arange(n)) / (1.5 * RATE), 0, 1)
    wav = out[:-4] + "_track.wav"
    write_wav(wav, mix)
    caps = []
    for t0, t1, text, size, where in CARDS:
        x, y, box = PLACE[where]
        caps.append(dict(t0=t0, t1=min(t1, total - 0.2), text=text, size=size, x=x, y=y, box=box))
    edit = dict(frames=frames, times=times, keep=[[0.0, total]], hold=0, fade=1.5, track=wav, captions=caps, fps=FPS,
                dim=[starts[-2] + 2.6, 0.45])
    ej = out[:-4] + "_edit.json"
    json.dump(edit, open(ej, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools", "shot_video.py"), ej, out], check=True)


if __name__ == "__main__":
    if sys.argv[1] == "shots":
        shots(os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else FK))
    elif sys.argv[1] == "cut":
        cut(sys.argv[2])
