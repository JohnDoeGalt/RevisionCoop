# The Arm Cannon show's video: the game's own screenshots (CoopTestCannonShow: ~12 a second, from 1.5 s before the
# draw), each placed by its file's time on a 30 fps timeline, with the soundtrack mixed from the gun's own sounds on the
# show's timeline (tools/cannon_soundtrack.py, lead 1.5 s), into an MP4.
#   python -I tools/cannon_video.py <out.mp4> [frames dir: default the dev folder's]
import glob, os, shutil, subprocess, sys
import numpy as np
from PIL import Image

NET = r"C:\Program Files (x86)\Steam\steamapps\common\Deus Ex\Revision\CoopNet"
HERE = os.path.dirname(os.path.abspath(__file__))
FPS = 30


def main():
    out = os.path.abspath(sys.argv[1])
    shots = sorted(glob.glob(os.path.join(sys.argv[2] if len(sys.argv) > 2 else NET, "Shot*.bmp")))
    if not shots:
        sys.exit("no shots")
    times = np.array([os.stat(p).st_mtime_ns for p in shots], float) / 1e9
    times -= times[0]
    gaps = np.diff(times)
    print("%d frames over %.2f s (median gap %.3f s, longest %.3f s)" % (len(shots), times[-1], np.median(gaps), gaps.max()))
    track = out[:-4] + "_track.wav"
    subprocess.run([sys.executable, "-I", os.path.join(HERE, "cannon_soundtrack.py"), track, "1.5"], check=True)
    w, h = Image.open(shots[0]).size
    w, h = w // 2 * 2, h // 2 * 2
    ff = shutil.which("ffmpeg")
    total = min(times[-1] + 0.3, 1.5 + 17.2)
    p = subprocess.Popen([ff, "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{w}x{h}",
                          "-r", str(FPS), "-i", "-", "-i", track, "-map", "0:v", "-map", "1:a", "-vf", "eq=gamma=1.18:saturation=1.05",
                          "-c:v", "libx264", "-preset", "medium", "-crf", "19", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k",
                          "-shortest", "-movflags", "+faststart", out], stdin=subprocess.PIPE)
    cache = {}
    for k in range(int(total * FPS)):
        t = k / FPS
        i = max(0, int(np.searchsorted(times, t, side="right")) - 1)
        if i not in cache:
            cache.clear()
            cache[i] = Image.open(shots[i]).convert("RGB").crop((0, 0, w, h)).tobytes()
        p.stdin.write(cache[i])
    p.stdin.close()
    p.wait()
    subprocess.run([ff, "-hide_banner", "-loglevel", "error", "-y", "-i", out, "-vf", "fps=2,scale=320:-2,tile=6x6",
                    out[:-4] + "_sheet_%02d.png"], check=True)
    print("video", out, "%.1f s" % total)


if __name__ == "__main__":
    main()
