# Capture retention (the user, 2026-11-04): raw captures (frame and screenshot dumps, .bmp) under build/video,
# build/shots and build/tmp, a folder (a take) at a time: a folder whose newest capture is over 3 days old goes, then the
# oldest folders while all captures total over 20 GB. Kept: folders listed in build/capture_keep.txt (one path a line,
# relative to the repo). Concept art and demo videos (.png, .mp4, the sheets, the tracks) are never captures: never
# touched ("we shouldn't delete concept art, or demo videos"). Run at the end of every take and suite run.
#   python -I tools/capture_clean.py [--dry]
import os, sys, time

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DIRS = ("build/video", "build/shots", "build/tmp")
AGE, CAP = 3 * 86400, 20e9


def pick(folders, now, keep, age=AGE, cap=CAP):
    """folders: {path: (newest mtime, bytes)}. The folders to delete: the stale ones, then the oldest while over cap."""
    live = {f: v for f, v in folders.items() if f not in keep}
    gone = [f for f, (t, _) in live.items() if now - t > age]
    total = sum(b for f, (_, b) in folders.items() if f not in gone)
    for f in sorted((f for f in live if f not in gone), key=lambda f: live[f][0]):
        if total <= cap:
            break
        gone.append(f)
        total -= live[f][1]
    return gone


def demo():
    F = {"a": (0, 5e9), "b": (9 * 86400, 12e9), "c": (10 * 86400, 12e9), "k": (0, 1e9)}
    assert sorted(pick(F, 10 * 86400, {"k"})) == ["a", "b"], pick(F, 10 * 86400, {"k"})    # a stale; b oldest over cap; k kept
    assert pick({"c": (0, 1e9)}, 1.0, set()) == []


def main():
    demo()
    dry = "--dry" in sys.argv
    kf = os.path.join(ROOT, "build", "capture_keep.txt")
    keep = {os.path.normpath(os.path.join(ROOT, l.strip())) for l in open(kf)} if os.path.exists(kf) else set()
    folders, files = {}, {}
    for top in DIRS:
        for d, _, fs in os.walk(os.path.join(ROOT, top)):
            b = [os.path.join(d, f) for f in fs if f.lower().endswith(".bmp")]
            if b:
                d = os.path.normpath(d)
                files[d] = b
                folders[d] = (max(os.path.getmtime(p) for p in b), sum(os.path.getsize(p) for p in b))
    gone = pick(folders, time.time(), keep)
    freed = sum(folders[f][1] for f in gone)
    for f in gone:
        print(("would delete" if dry else "deleted"), "%.2f GB" % (folders[f][1] / 1e9), os.path.relpath(f, ROOT))
        if not dry:
            for p in files[f]:
                os.remove(p)
    left = sum(v[1] for f, v in folders.items() if f not in gone)
    print("captures: %.2f GB %s, %.2f GB left" % (freed / 1e9, "to free" if dry else "freed", left / 1e9))


if __name__ == "__main__":
    main()
