# A filmed show's video (CoopTestBladeShow, CoopTestHopperShow: "<show>: ..." lines in the host's log): its frames
# (tools/shot_take.py) on the game's clock as its log has them; captions where it logged "caption <text>" (each up
# till the next, top left: the arms fill the bottom of the picture), a title over the start; the Mech's own sounds
# (src/RevNet/Sounds) where it logged "sound <name>"; held at "done" under an end card. Through tools/shot_video.py.
#   python -I tools/demo_video.py <NetHost.log> <frames dir> <out.mp4> <show> <title> <end card's line>
#   e.g. bladeshow "ARM BLADES" "the Mech's arm blades"
import json, os, re, subprocess, sys, textwrap, wave
import numpy as np

RATE = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
SND = os.path.join(HERE, "..", "src", "RevNet", "Sounds")
GAIN = {"BladeOut": 1.0, "BladeIn": 0.9, "BladeSwing": 0.8, "StormShot": 0.5, "StormDraw": 0.9, "StormReloadOut": 1.0,
        "StormReloadIn": 1.0, "StormHopper": 1.0, "StormDry": 0.7}


def parse(log, show):
    shots, ev = [], []
    for line in open(log, encoding="latin-1"):
        m = re.search(show + r": shot (\d+) at ([\d.]+)\s*$", line)
        if m:
            shots.append(float(m.group(2)))
            continue
        m = re.search(show + r": (.*) at ([\d.]+)\s*$", line)
        if m:
            ev.append((float(m.group(2)), m.group(1)))
    t0 = shots[0]
    return [t - t0 for t in shots], [(t - t0, w) for t, w in ev]


def read(text):
    """Seconds to read a caption: 1.2 and 0.3 a word, at least 2.5."""
    return max(2.5, 1.2 + 0.3 * len(text.split()))


def load(name):
    w = wave.open(os.path.join(SND, name + ".wav"))
    x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(float) / 32768.0
    assert w.getframerate() == RATE and w.getnchannels() == 1, name
    return x


def main():
    log, frames, out, show, title, line = sys.argv[1:7]
    out = os.path.abspath(out)
    times, ev = parse(log, show)
    files = sorted(f for f in os.listdir(frames) if f.startswith("f") and f.endswith(".bmp"))
    if len(files) != len(times):
        sys.exit("%d frames but %d shots logged" % (len(files), len(times)))
    done = next((t for t, w in ev if w == "done"), None)
    if done is None:
        sys.exit("no 'done' in the log")
    hold, fade = 2.6, 1.0
    start = times[1] if len(times) > 1 else 0.0      # (the first shot can be the view from before the show: skipped)

    # The captions on the show's own clock, never the picture frozen under them (the user, 2026-10-30: "make longer
    # videos... the transitions between different things timed for the text"): the show gives each step as long as
    # its caption takes to read (CoopTestBladeShow.ReadTime); a caption up for less is reported, for its show to fix.
    small = 28
    hold = max(hold, read(line + " in-game footage") + 0.6)
    cues = [(t - start, w[len("caption "):]) for t, w in ev if w.startswith("caption ")]
    end = done - start
    total = end + hold
    first = cues[0][0] if cues else end
    caps = [dict(t0=0.15, t1=first - 0.05, text=title, size=54, x=48, y=40),
            dict(t0=0.3, t1=first - 0.05, size=small, x=48, y=112, text=line)]
    for k, (t, text) in enumerate(cues):
        caps.append(dict(t0=t + 0.05, t1=(cues[k + 1][0] if k + 1 < len(cues) else end) - 0.05,
                         text=textwrap.fill(text, 44), size=38, x=48, y=40, line_spacing=-21))
    for c, text in [(caps[0], title + " " + line)] + [(c, c["text"]) for c in caps[2:]]:
        if c["t1"] - c["t0"] < read(text) - 0.1:
            print("SHORT: %r up %.1f s, needs %.1f s: give its step longer in the show"
                  % (text, c["t1"] - c["t0"], read(text)))
    caps.append(dict(t0=end + 0.2, t1=total - 0.2, text="RevNet  ·  Deus Ex: Revision co-op", size=46, x="(w-tw)/2", y="h/2-60", box=False))
    caps.append(dict(t0=end + 0.4, t1=total - 0.2, text=line + "  ·  in-game footage", size=small, x="(w-tw)/2", y="h/2+10", box=False))

    # The soundtrack: each logged sound where the game played it.
    n = int(total * RATE) + RATE
    mix = np.zeros(n)
    placed = []
    for t, w in ev:
        if w.startswith("sound "):
            name = w.split()[1]
            x = load(name)
            i = int(max(0.0, t - start) * RATE)
            j = min(n, i + len(x))
            mix[i:j] += x[:j - i] * GAIN.get(name, 0.9)
            placed.append((round(t - start, 3), w))
    mix = np.tanh(mix * 1.1) / np.tanh(1.1)
    mix *= 0.92 / max(1e-9, np.abs(mix).max())
    mix = mix[:int(total * RATE)]
    track = out[:-4] + "_track.wav"
    wf = wave.open(track, "wb")
    wf.setnchannels(1)
    wf.setsampwidth(2)
    wf.setframerate(RATE)
    wf.writeframes((np.clip(mix, -1, 1) * 32767).astype("<i2").tobytes())
    wf.close()

    edit = dict(frames=[os.path.join(os.path.abspath(frames), f) for f in files], times=times, keep=[[start, done]], hold=hold,
                fade=fade, track=track, captions=caps, grade="eq=gamma=1.1:saturation=1.05", dim=[float(end), 0.3])
    ej = out[:-4] + "_edit.json"
    json.dump(edit, open(ej, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    json.dump(dict(placed=placed), open(out[:-4] + "_events.json", "w"), indent=1)
    subprocess.run([sys.executable, "-I", os.path.join(HERE, "shot_video.py"), ej, out], check=True)


if __name__ == "__main__":
    main()
