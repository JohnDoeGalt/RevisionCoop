# A video from the game's own screenshots (tools/cannon_video.py made general): the frames placed on a 30 fps timeline
# by their times, cut to an edit, with a soundtrack laid under them and captions over them, into an MP4 (H.264 yuv420p,
# AAC, faststart), and a contact sheet of the result to check by eye.
#   python -I tools/shot_video.py <edit.json> <out.mp4>
# edit.json:
#   frames    [paths] in the order taken, or a folder (its f*.bmp, else the dev folder's Shot*.bmp)
#   times     [seconds] each frame's time (the game's clock as the show logged it); absent: the files' times
#   timescale the files' times scaled by this (a show run at TimeDilation 0.4: 0.4), when there are no "times"
#   keep      [[from, to], ...] the stretches of that clock kept, in order (absent: all of it)
#   hold      seconds the last frame is held after the last stretch (the end card), fading to black over "fade"
#   track     a WAV laid under it from 0 (on the edited timeline), or absent: silent
#   captions  [{t0, t1, text, size, x, y}] on the edited timeline (x, y: drawtext expressions); fade in and out 0.3 s
#   font      a TrueType font for the captions
#   grade     an ffmpeg filter for the picture (e.g. "eq=gamma=1.6:saturation=1.1")
#   dim       [from, amount]: the picture darkened by amount from then (under an end card), the captions not
import glob, json, os, shutil, subprocess, sys
import numpy as np
from PIL import Image

NET = r"C:\Program Files (x86)\Steam\steamapps\common\Deus Ex\Revision\CoopNet"
FPS = 30


def frame_list(spec):
    if isinstance(spec, list):
        return spec
    found = sorted(glob.glob(os.path.join(spec or NET, "f*.bmp")))
    return found or sorted(glob.glob(os.path.join(spec or NET, "Shot*.bmp")))


def drawtext(c, work, k):
    # Each caption's text from a file of its own (no escaping), drawn with a soft box, faded in and out.
    name = "cap%02d.txt" % k
    with open(os.path.join(work, name), "w", encoding="utf-8") as f:
        f.write(c["text"])
    t0, t1 = c["t0"], c["t1"]
    alpha = "if(lt(t,%.3f),(t-%.3f)/0.3,if(gt(t,%.3f),(%.3f-t)/0.3,1))" % (t0 + 0.3, t0, t1 - 0.3, t1)
    opts = ["fontfile=font.ttf", "textfile=" + name, "fontsize=%d" % c.get("size", 34), "fontcolor=white",
            "x=" + str(c.get("x", 48)), "y=" + str(c.get("y", "h-150")), "alpha='%s'" % alpha,
            "enable='between(t,%.3f,%.3f)'" % (t0, t1)]
    if c.get("box", True):
        opts += ["box=1", "boxcolor=black@0.55", "boxborderw=14"]
    if c.get("shadow", True):
        opts += ["shadowcolor=black@0.7", "shadowx=2", "shadowy=2"]
    return "drawtext=" + ":".join(opts)


def main():
    edit = json.load(open(sys.argv[1], encoding="utf-8"))
    out = os.path.abspath(sys.argv[2])
    work = out[:-4] + "_work"
    os.makedirs(work, exist_ok=True)
    shots = frame_list(edit.get("frames"))
    if not shots:
        sys.exit("no frames")
    if edit.get("times"):
        times = np.array(edit["times"], float)
        if len(times) != len(shots):
            sys.exit("%d frames but %d times" % (len(shots), len(times)))
    else:
        times = np.array([os.stat(p).st_mtime_ns for p in shots], float) / 1e9 * edit.get("timescale", 1.0)
        times -= times[0]
    keep = edit.get("keep") or [[float(times[0]), float(times[-1]) + 1.0 / FPS]]
    hold = float(edit.get("hold", 0))
    total = sum(b - a for a, b in keep) + hold
    gaps = np.diff(times)
    print("%d frames over %.2f s of the show's clock (median gap %.4f s, longest %.4f s); edit %.2f s"
          % (len(shots), times[-1] - times[0], np.median(gaps), gaps.max(), total))
    w, h = Image.open(shots[0]).size
    w, h = w // 2 * 2, h // 2 * 2
    # The picture: each output frame shows the latest shot taken by its moment on the show's clock.
    shutil.copy(edit.get("font", r"C:\Windows\Fonts\bahnschrift.ttf"), os.path.join(work, "font.ttf"))
    vf = [edit.get("grade", "null")]
    if edit.get("dim"):                     # the picture dimmed from then on (under an end card), over 0.6 s
        t0, amount = edit["dim"]
        ramp = "clip((t-%.3f)/0.6\\,0\\,1)" % t0
        vf.append("eq=eval=frame:brightness=-%.3f*%s:saturation=1-0.5*%s" % (amount, ramp, ramp))
    vf += [drawtext(c, work, k) for k, c in enumerate(edit.get("captions", []))]
    fade = float(edit.get("fade", 0))
    if fade > 0:
        vf.append("fade=t=out:st=%.3f:d=%.3f" % (total - fade, fade))
    with open(os.path.join(work, "filter.txt"), "w", encoding="utf-8") as f:
        f.write("[0:v]" + ",".join(vf) + "[v]")
    ff = shutil.which("ffmpeg")
    cmd = [ff, "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{w}x{h}",
           "-r", str(FPS), "-i", "-"]
    if edit.get("track"):
        cmd += ["-i", os.path.abspath(edit["track"])]
    cmd += ["-filter_complex_script", "filter.txt", "-map", "[v]"]
    if edit.get("track"):
        cmd += ["-map", "1:a", "-c:a", "aac", "-b:a", "192k"]
    cmd += ["-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", "-r", str(FPS),
            "-t", "%.3f" % total, "-movflags", "+faststart", out]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, cwd=work)
    cache, starts = {}, np.cumsum([0] + [b - a for a, b in keep])
    for k in range(int(round(total * FPS))):
        e = k / FPS
        i = min(int(np.searchsorted(starts, e, side="right")) - 1, len(keep) - 1)
        g = min(keep[i][0] + (e - starts[i]), keep[-1][1] - 0.5 / FPS)       # (past the end: the last frame, held)
        j = max(0, int(np.searchsorted(times, g + 1e-4, side="right")) - 1)
        if j not in cache:
            cache.clear()
            cache[j] = Image.open(shots[j]).convert("RGB").crop((0, 0, w, h)).tobytes()
        p.stdin.write(cache[j])
    p.stdin.close()
    if p.wait():
        sys.exit("ffmpeg failed")
    subprocess.run([ff, "-hide_banner", "-loglevel", "error", "-y", "-i", out, "-vf", "fps=2,scale=320:-2,tile=6x6",
                    out[:-4] + "_sheet_%02d.png"], check=True)
    print("video", out, "%.1f s" % total)


if __name__ == "__main__":
    main()
