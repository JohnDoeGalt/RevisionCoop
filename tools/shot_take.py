# A filmed take: runs a live test (build/tmp/locked_live.ps1 under the desktop lock where there is one, else
# tools/run_net_live.ps1) and meanwhile moves the game's
# screenshots out of the dev folder as they are written, numbered in the order they were taken. The game names a shot
# ShotNNNN.bmp after the first free number and stops at Shot0255 (a 257th "shot" writes nothing), so a take longer
# than 256 frames needs them taken away; a file is moved once it has settled (same size and time on two looks).
#   python -I tools/shot_take.py <frames dir> <locked_live.ps1 arguments...>
import glob, os, subprocess, sys, threading, time

NET = r"C:\Program Files (x86)\Steam\steamapps\common\Deus Ex\Revision\CoopNet"
HERE = os.path.dirname(os.path.abspath(__file__))


def mover(dest, stop, count):
    seen = {}
    while True:
        last = stop.is_set()
        files = []
        for p in glob.glob(os.path.join(NET, "Shot*.bmp")):
            try:
                st = os.stat(p)
            except OSError:
                continue
            files.append((st.st_mtime_ns, p, st.st_size))
        files.sort()
        now = time.time_ns()
        blocked = False                                     # (in order: nothing newer moves before an older one)
        for mt, p, size in files:
            if blocked or not last and (now - mt < 300_000_000 or seen.get(p) != (size, mt)):
                seen[p] = (size, mt)                        # (every new file looked at once a pass, not only the
                blocked = True                              # first: one a pass fell behind 30 a second, the 256
                continue                                    # names filled and the game wrote nothing, 2026-10-30)
            try:
                os.replace(p, os.path.join(dest, "f%05d.bmp" % count[0]))
            except OSError:
                blocked = True                              # (still open: next look)
                continue
            count[0] += 1
            seen.pop(p, None)
        if last:
            return
        time.sleep(0.1)


def main():
    dest = os.path.abspath(sys.argv[1])
    os.makedirs(dest, exist_ok=True)
    for p in glob.glob(os.path.join(dest, "f*.bmp")) + glob.glob(os.path.join(NET, "Shot*.bmp")):
        os.remove(p)
    stop, count = threading.Event(), [0]
    t = threading.Thread(target=mover, args=(dest, stop, count))
    t.start()
    try:
        live = os.path.join(HERE, "..", "build", "tmp", "locked_live.ps1")    # (this PC's desktop-lock wrapper)
        if not os.path.exists(live):
            live = os.path.join(HERE, "run_net_live.ps1")
        p = subprocess.Popen(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", live] + sys.argv[2:],
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace")
        for line in p.stdout:
            sys.stdout.write(line)
            sys.stdout.flush()
        p.wait()
    finally:
        time.sleep(1)
        stop.set()
        t.join()
    print("frames moved: %d -> %s" % (count[0], dest))


if __name__ == "__main__":
    main()
