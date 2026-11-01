"""The FK-7 swarm preview (docs/FLY_KITS.md; the user, 2026-10-30: "now let's work on swarming animations... and the POV
for targeting hud"): a lead and four kits in the game's own formation (CoopFPVGuided.Follow, its numbers), flown
forward, turned and stopped; then the lead's own view with its gun-cam overlay (CoopFPVView, drawn as it draws it) as
the four are sent one at a time at hostiles, each going
off with its payload's own sound, and the lead goes in last, its feed to static. The targets are NSF terrorists (the
game's own model and skins), UNATCO's open enemy in 2052: the footage serves the in-setting promo too.
  python -I tools/flykit_swarm.py frames [out dir]      the frames' OBJs and swarm.json (default build/mech/flykit)
  build/tools/blender-4.2.23-windows-x64/blender.exe -b --factory-startup --python tools/flykit_render.py -- <swarm.json> <png dir>
  python -I tools/flykit_swarm.py video <swarm.json> <png dir> <out.mp4>     the overlay, the soundtrack, the cut
"""
import json, math, os, subprocess, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flykit
from flykit import rot, unit

flykit.PACKAGES["DeusExCharacters"] = os.path.join(flykit.REV, "System", "DeusExCharacters.u")
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

# The NSF terrorist as the game has it (HCC.exe RevNet.CoopExplosiveFacts DeusEx.Terrorist): its mesh, its MultiSkins by
# slot (PinkMaskTex: not drawn), its collision (what the overlay boxes).
TROOPER = ("GM_Jumpsuit", ["TerroristTex0", "TerroristTex2", "TerroristTex1", "TerroristTex0", "TerroristTex0", None,
                           "GogglesTex1", None], 20.0, 47.5)


def trooper(out, seq="BreatheLight2H", k=0):
    """The terrorist posed as frame k of its animation seq, feet at z 0, facing +x: an OBJ (nsf_terrorist_<seq>_<k>)
    and its skins into out. A character's faces count their vertices after the weapon's (special_verts: the first of
    each frame's)."""
    from PIL import Image
    mesh, skins, radius, height = TROOPER
    pkg = flykit.package("DeusExCharacters")
    m = pkg.read_mesh(mesh)
    f0 = next(q["start"] for q in m["seqs"] if q["name"] == seq) + k
    V = (np.array(pkg.frames(m)[f0], float)[m["special_verts"]:] - np.array(m["origin"])) * np.array(m["scale"])
    V[:, 1] *= -1                                               # (the game's frame is left-handed)
    V[:, 2] -= V[:, 2].min()
    path = os.path.join(out, "nsf_terrorist_%s_%d.obj" % (seq, k))
    with open(path, "w") as f, open(os.path.join(out, "nsf_terrorist.mtl"), "w") as mt:
        f.write("mtllib nsf_terrorist.mtl\n")
        for name in sorted(set(s for s in skins if s)):
            w, h, data, pal = pkg.read_texture(name)
            idx = np.frombuffer(data[:w * h], np.uint8).reshape(h, w)
            rgb = np.array(pal, np.uint8)[idx]
            if tuple(pal[0]) == (255, 0, 255) and (idx == 0).any():    # masked (the goggles): colour 0 not drawn
                Image.fromarray(np.dstack([rgb, np.where(idx == 0, 0, 255).astype(np.uint8)]), "RGBA").save(
                    os.path.join(out, name + ".png"))
                mt.write("newmtl %s\nKd 1 1 1\nmap_Kd %s.png\nmap_d %s.png\n\n" % (name, name, name))
            else:
                Image.fromarray(rgb).save(os.path.join(out, name + ".png"))
                mt.write("newmtl %s\nKd 1 1 1\nmap_Kd %s.png\n\n" % (name, name))
        for v in V:
            f.write("v %.4f %.4f %.4f\n" % (v[0], v[2], -v[1]))
        k = 0
        for w0, w1, w2, mat in m["faces"]:
            _, slot = m["materials"][mat]
            name = skins[slot] if slot < len(skins) else None
            if name is None:
                continue
            c = [m["wedges"][w] for w in (w0, w2, w1)]
            for _, u, v in c:
                f.write("vt %.5f %.5f\n" % (u / 256.0, 1 - v / 256.0))
            f.write("usemtl %s\nf %d/%d %d/%d %d/%d\n" % (name, c[0][0] + 1, k + 1, c[1][0] + 1, k + 2, c[2][0] + 1, k + 3))
            k += 3
    span = V.max(0) - V.min(0)
    print("terrorist: %.1f x %.1f x %.1f units (the game's collision: %.0f across, %.0f tall)" % (*span, 2 * radius, 2 * height))
    return path


# ---- the swarm (CoopFPVGuided.Follow's numbers; the game's frame turned right-handed: y to the left)
FPS, ALT = 30, 600.0                        # frames a second; the lead's height over the floor (units: 11 m)
# Where (the user, 2026-10-30: "an actual map in the game... outdoors"): Liberty Island (01_NYC_UNATCOIsland, through
# tools/ue1map.py), its own lights and a little moon. In over the north-west lawn heading south, a left turn towards the
# statue, stopped west of the plaza facing it; the NSF on the plaza (where they hold it in the game's first mission).
MAP = os.path.join(ROOT, "build", "maps", "01_NYC_UNATCOIsland", "01_NYC_UNATCOIsland.json")
FLOOR, START, YAW0, MOON = -144.0, (-6320.0, 2110.0), -90.0, 1.6
SLOTS = [np.array(v, float) for v in ((10, -80, -25), (10, 80, -25), (-55, -135, -12), (-55, 135, -12))]
LEAD_PAYLOAD, PAYLOADS = "GEP rocket", ["LAM", "20 mm HE", "GEP rocket", "LAM"]
# Each payload's own sound (its ImpactSound: HCC.exe RevNet.CoopExplosiveFacts DeusEx.LAM DeusEx.Rocket ...) and a
# flash about a third of its blast radius.
BANG = {"LAM": ("LAMExplode", 130.0), "GEP rocket": ("SmallExplosion1", 80.0), "20 mm HE": ("MediumExplosion2", 110.0)}
POSES = [("BreatheLight2H", 0), ("Shoot2H", 2), ("Idle12H", 4), ("BreatheLight2H", 3), ("Shoot2H", 0)]
SPOTS = [(1150, 180), (1400, -260), (1650, 60), (1250, -420), (1850, -60)]     # the targets: ahead, to the left
PLAN = [("", "hover", 4.5), ("forward", "forward", 2.5), ("turn left", "turn", 2.5), ("stop", "stop", 2.5),
        ("the pilot's view", "pov", 3.0), ("sent, one at a time", "send", 5.0), ("the lead goes in", "dive", 2.5),
        ("", "static", 4.0)]
SENDS = (0.5, 1.6, 2.7, 3.8)                # into "send": the fire button, each the next kit at the next lock
LEAD_SPEED, RACER = 700.0, 1100.0           # a lead's top speed (medium); a kit going in (Speed, to MaxSpeed 1300)
CHASE, POV_FOV = 22.0, 70.0                 # the chase camera's lens (mm); the pilot's view across (degrees)
TITLE, LINE = "FK-7 Swarm", "four kits and a lead, in formation"


def ahead(yaw):
    a = math.radians(yaw)
    return np.array([math.cos(a), math.sin(a), 0.0])


def smooth(u):
    u = min(1.0, max(0.0, u))
    return u * u * (3 - 2 * u)


def lens(fov):
    return 18.0 / math.tan(math.radians(fov) / 2)          # (a 36 mm wide sensor)


def project(eye, look, fov, q, W=960, H=720):
    """Where q falls in a W x H picture from eye towards look (None: behind the camera)."""
    f = unit(np.asarray(look) - eye)
    r = unit(np.cross(f, [0, 0, 1.0]))
    u = np.cross(r, f)
    d = np.asarray(q) - eye
    z = d @ f
    if z < 1:
        return None
    k = (W / 2) / math.tan(math.radians(fov) / 2)
    return W / 2 + k * (d @ r) / z, H / 2 - k * (d @ u) / z


def framed(eye, look, fov, at, pad=4.0):
    """The overlay's box round a target's collision (CoopFPVView.Framed), or None off screen."""
    _, _, radius, height = TROOPER
    pts = [project(eye, look, fov, at + np.array([i * radius, j * radius, height + k * height]))
           for i in (-1, 1) for j in (-1, 1) for k in (-1, 1)]
    pts = [p for p in pts if p]
    if not pts:
        return None
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    box = [min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad]
    return box if box[2] > 0 and box[3] > 0 and box[0] < 960 and box[1] < 720 else None


def placed(src, dst, yaw, at):
    """A copy of an OBJ (Blender's y up) turned yaw about z and moved to at."""
    R = rot(yaw, "z")
    with open(src) as f, open(dst, "w") as o:
        for line in f:
            if line.startswith("v "):
                a, b, c = map(float, line.split()[1:4])
                x, y, z = R @ np.array([a, -c, b]) + at
                line = "v %.4f %.4f %.4f\n" % (x, z, -y)
            elif line.startswith("mtllib "):                   # (its skins where the source's are)
                mtl = os.path.join(os.path.dirname(src), line.split(None, 1)[1].strip())
                line = "mtllib %s\n" % os.path.relpath(mtl, os.path.dirname(dst)).replace("\\", "/")
            o.write(line)
    return dst


def lead_flight():
    """The lead's flight up to the pilot's view (the targets are placed from where it stops): where, how fast, its
    heading, frame by frame."""
    p, v, yaw, out = np.array([START[0], START[1], FLOOR + ALT]), np.zeros(3), YAW0, []
    dt = 1.0 / FPS
    for label, kind, length in PLAN[:4]:
        for f in range(int(round(length * FPS))):
            if kind == "turn":
                yaw = YAW0 + 90.0 * smooth(f * dt / 1.2)
            want = ahead(yaw) * LEAD_SPEED if kind in ("forward", "turn") else np.zeros(3)
            v = v + (want - v) * min(1.0, dt * 4)              # (CoopFPV.Tick: a lead on its pilot's keys)
            p = p + v * dt
            out.append((p.copy(), v.copy(), yaw))
    return out


def pose(yaw, push, yaw_rate):
    """A kit's body and fans from its push (CoopFPVGuided.Follow: nose down to speed up, over to slide, 3 a unit up
    to 3600 of the game's 65536 a turn) and its turning (the fans apart)."""
    f, r = ahead(yaw), ahead(yaw - 90)
    nose = np.clip((push @ f) * 3, -3600, 3600) * 360 / 65536
    bank = np.clip((push @ r) * 3, -3600, 3600) * 360 / 65536
    tilt = float(np.clip((push @ f) / 3000 * 30, -25, 35))
    diff = float(np.clip(yaw_rate * 0.12, -20, 20))
    return rot(yaw, "z") @ rot(bank, "x") @ rot(nose, "y"), tilt, diff


def frames(out):
    """Every frame's OBJs (the kits, the targets), camera, overlay and sounds: <out>/swarm/swarm.json."""
    dirn = os.path.join(out, "swarm")
    os.makedirs(dirn, exist_ok=True)
    kits = {name: flykit.build(name, out) for name in set(PAYLOADS + [LEAD_PAYLOAD])}
    flight = lead_flight()
    P_s, _, yaw_s = flight[-1]
    targets = []
    for (seq, k), (fwd, side) in zip(POSES, SPOTS):
        at = np.array([P_s[0], P_s[1], FLOOR]) + ahead(yaw_s) * fwd + ahead(yaw_s + 90) * side
        face = math.degrees(math.atan2(P_s[1] - at[1], P_s[0] - at[0]))
        src = trooper(out, seq, k)
        targets.append(dict(at=at, obj=placed(src, os.path.join(dirn, "target%d.obj" % len(targets)), face, at),
                            alive=True, centre=at + np.array([0, 0, TROOPER[3]])))
    starts = np.cumsum([0.0] + [length for _, _, length in PLAN])
    n = int(round(starts[-1] * FPS))
    dt, sub = 1.0 / FPS, 4
    seeds = np.random.default_rng(7).uniform(0, 2 * math.pi, (4, 6))
    lead = dict(p=flight[0][0].copy(), v=np.zeros(3), yaw=YAW0, acc=np.zeros(3), rate=0.0)
    fol = [dict(p=flight[0][0] + rot(YAW0, "z") @ SLOTS[i], v=np.zeros(3), push=np.zeros(3), sent=None, gone=False, speed=0.0)
           for i in range(4)]
    view, look_at, fired, impact, eye_c, cyaw = None, None, 0, None, None, YAW0
    bangs, scorch, flashes, paths, states = [], [], [], [], []
    for f in range(n):
        t = f * dt
        i = min(len(PLAN) - 1, int(np.searchsorted(starts, t, side="right")) - 1)
        label, kind, length = PLAN[i]
        u = t - starts[i]
        alive = [g for g in targets if g["alive"]]
        marked = [id(k["sent"]) for k in fol if k["sent"] is not None and not k["gone"]]
        # The lead: flown (the chase), then hovering and aiming (the overlay's lock: the free hostile nearest the
        # crosshair), sending the swarm one at a time, then going in itself.
        yaw0, v0 = lead["yaw"], lead["v"].copy()
        eye = lead["p"] + rot(lead["yaw"], "z") @ np.array([10.0, 0, 0])
        if f < len(flight):
            lead["p"], lead["v"], lead["yaw"] = flight[f][0].copy(), flight[f][1].copy(), flight[f][2]
        elif kind in ("pov", "send"):
            free = [g for g in alive if id(g) not in marked]
            if view is None:
                view = unit(np.mean([g["centre"] for g in alive], 0) - eye)
            look_at = max(free, key=lambda g: unit(g["centre"] - eye) @ view) if free else None
            aim = unit((look_at["centre"] if look_at else np.mean([g["centre"] for g in alive], 0)) - eye)
            view = unit(view + (aim - view) * (1 - math.exp(-dt / 0.3)))
            lead["yaw"] = math.degrees(math.atan2(view[1], view[0]))
            lead["v"] = lead["v"] * max(0.0, 1 - dt * 4)
            lead["p"] = lead["p"] + lead["v"] * dt
            if kind == "send" and fired < 4 and u >= SENDS[fired] and look_at is not None:
                k = fol[fired]
                k["sent"], k["speed"] = look_at, RACER
                k["v"] = unit(look_at["centre"] - k["p"]) * RACER     # (CoopFPVGuided.Send: straight at it)
                fired += 1
        elif kind == "dive" and impact is None:
            if look_at is None or not look_at["alive"]:
                look_at = alive[0] if alive else look_at
            want = unit(look_at["centre"] - lead["p"]) * RACER
            lead["v"] = lead["v"] + (want - lead["v"]) * min(1.0, dt * 6)
            lead["p"] = lead["p"] + lead["v"] * dt
            view = unit(view + (unit(lead["v"]) - view) * (1 - math.exp(-dt / 0.15)))
            lead["yaw"] = math.degrees(math.atan2(view[1], view[0]))
            if np.linalg.norm(look_at["centre"] - lead["p"]) < 40:
                impact = t
                look_at["alive"] = False
                bangs.append((t, LEAD_PAYLOAD, look_at["centre"].copy()))
                flashes.append((t, look_at["centre"] + np.array([0, 0, 10.0]), BANG[LEAD_PAYLOAD][1]))
                scorch.append([*look_at["at"][:2], 70.0])
        lead["acc"] = (lead["v"] - v0) / dt
        lead["rate"] = (lead["yaw"] - yaw0) / dt
        # The swarm, a quarter frame at a time: in formation (CoopFPVGuided.Follow), or sent (chasing its target).
        for _ in range(sub):
            h = dt / sub
            for j, k in enumerate(fol):
                if k["gone"]:
                    continue
                if k["sent"] is None:
                    s6 = seeds[j]
                    want = lead["p"] + rot(lead["yaw"], "z") @ SLOTS[j] + np.array(
                        [9 * math.sin(0.83 * t + s6[0]) + 4 * math.sin(2.1 * t + s6[1]),
                         11 * math.sin(0.67 * t + s6[2]) + 4 * math.sin(1.7 * t + s6[3]),
                         7 * math.sin(1.05 * t + s6[4]) + 3 * math.sin(2.9 * t + s6[5])])
                    push = (want - k["p"]) * 20 - (k["v"] - lead["v"]) * 7
                    cap = max(3000.0, 2.5 * np.linalg.norm(lead["v"]))
                    if np.linalg.norm(push) > cap:
                        push = unit(push) * cap
                    k["push"] = push
                    k["v"] = k["v"] + push * h
                    most = max(2000.0, 1.2 * np.linalg.norm(lead["v"]))
                    if np.linalg.norm(k["v"]) > most:
                        k["v"] = unit(k["v"]) * most
                else:
                    d0, d1 = unit(k["v"]), unit(k["sent"]["centre"] - k["p"])
                    ang = math.acos(float(np.clip(d0 @ d1, -1, 1)))
                    most = math.radians(330) * h                # (RotationRate 60000 of 65536 a second)
                    d = d1 if ang <= most else unit(d0 * math.sin(ang - most) + d1 * math.sin(most))
                    k["speed"] = min(1300.0, k["speed"] + 1500 * h)
                    k["v"] = d * k["speed"]
                    if np.linalg.norm(k["sent"]["centre"] - k["p"]) < 28:
                        g = k["sent"]
                        k["gone"], g["alive"] = True, False
                        bangs.append((t, PAYLOADS[j], g["centre"].copy()))
                        flashes.append((t, g["centre"] + np.array([0, 0, 10.0]), BANG[PAYLOADS[j]][1]))
                        scorch.append([*g["at"][:2], 70.0])
                        continue
                k["p"] = k["p"] + k["v"] * h
        # The camera: chasing the lead from behind and to its right, or the lead's own nose (its pilot's view).
        pov = kind in ("pov", "send", "dive")
        blank = kind == "static" or (impact is not None and t > impact + 0.05)
        if pov:
            eye = lead["p"] + rot(lead["yaw"], "z") @ np.array([10.0, 0, 0])
            look, fov = eye + view * 100, POV_FOV
        else:
            # (under the title, from close on the lead, back to show the swarm round it: a kit is 31 cm, the
            # formation 5 m)
            cyaw += (lead["yaw"] - cyaw) * (1 - math.exp(-dt / 0.6))
            w = smooth(t / 4.2) if kind == "hover" else 1.0
            back = np.array([-70.0, -30, 15]) * (1 - w) + np.array([-230.0, -80, 60]) * w
            want_eye = lead["p"] + rot(cyaw, "z") @ back
            eye_c = want_eye if eye_c is None or kind == "hover" else eye_c + (want_eye - eye_c) * (1 - math.exp(-dt / 0.25))
            eye, look = eye_c, lead["p"] + rot(cyaw, "z") @ (np.array([0.0, 0, 0]) * (1 - w) + np.array([60.0, 0, -20]) * w)
            fov = 2 * math.degrees(math.atan(18 / CHASE))
        # The kits (not the lead in its own view: its camera is in its nose), their sounds, the targets.
        bodies = [] if pov else [("lead", LEAD_PAYLOAD, lead["p"], *pose(lead["yaw"], lead["acc"], lead["rate"]))]
        sounds = [[*map(float, lead["p"]), float(min(1, np.linalg.norm(lead["v"]) / LEAD_SPEED * 0.6
                                                    + np.linalg.norm(lead["acc"]) / 3000)), 1.0 if pov else 0.0]]
        for j, k in enumerate(fol):
            if k["gone"]:
                continue
            if k["sent"] is None:
                Rb, tilt, diff = pose(lead["yaw"], k["push"], lead["rate"])
            else:
                d = unit(k["v"])
                Rb = rot(math.degrees(math.atan2(d[1], d[0])), "z") @ rot(math.degrees(math.asin(-d[2])), "y")
                tilt, diff = 40.0, 0.0
            bodies.append(("k%d" % j, PAYLOADS[j], k["p"], Rb, tilt, diff))
            sounds.append([*map(float, k["p"]),
                           1.0 if k["sent"] is not None else float(min(1, np.linalg.norm(k["push"]) / 2500)), 0.0])
        objs, lamps = [], []
        if not blank:
            for name, payload, at, Rb, tilt, diff in bodies:
                st = kits[payload]
                faces = flykit.tilted(flykit.spun(st["p"], 720.0 * t + 37 * len(objs)), st["p"], tilt + diff, tilt - diff)
                objs.append(flykit.obj(os.path.join(dirn, "f%04d_%s.obj" % (f, name)), st, faces,
                                       lambda q, Rb=Rb, at=at: Rb @ q + at, blur=True))
                # its status light lit (the lead's green, as the game's lead: CoopFPV.Dress), on its spine
                lamps.append([*map(float, Rb @ np.array([0.0, 0, 3.0]) + at),
                              *((0.3, 1.0, 0.4) if name == "lead" else (1.0, 0.6, 0.15))])
            objs += [g["obj"] for g in targets if g["alive"]]
        fx = []
        for t0, at, R in flashes:                               # a fireball (0.45 s), then its smoke rising (1.4 s)
            tau = (t - t0) / 0.45
            if 0 <= tau <= 1:
                fx.append([*map(float, at), R * (0.35 + 0.65 * math.sqrt(tau)), (1 - tau) ** 1.5, 0])
            tau = (t - t0 - 0.15) / 1.4
            if 0 <= tau <= 1:
                fx.append([float(at[0]), float(at[1]), float(at[2] + 70 * tau), R * (0.45 + 0.6 * math.sqrt(tau)),
                           0.45 * (1 - tau), 1])
        hud = None
        if pov and not blank:                                   # what the overlay shows (CoopFPVView.DrawWindow)
            marked = [id(k["sent"]) for k in fol if k["sent"] is not None and not k["gone"] and k["sent"]["alive"]]
            lock = look_at if look_at is not None and look_at["alive"] and id(look_at) not in marked else None
            free = [g for g in targets if g["alive"] and g is not lock and id(g) not in marked]
            hud = dict(seen=[b for b in (framed(eye, look, fov, g["at"]) for g in free
                                         if np.linalg.norm(g["centre"] - eye) < 3200) if b],
                       lock=framed(eye, look, fov, lock["at"], 7) if lock else None,
                       lock_m=int(np.linalg.norm(lock["centre"] - eye) / 52.5 + 0.5) if lock else 0,
                       marked=[[j + 1, framed(eye, look, fov, k["sent"]["at"])] for j, k in enumerate(fol)
                               if k["sent"] is not None and not k["gone"] and k["sent"]["alive"]],
                       swarm=sum(1 for k in fol if k["sent"] is None), t=t,
                       alt=int((eye[2] - FLOOR) / 52.5 + 0.5), spd=int(np.linalg.norm(lead["v"]) / 52.5 + 0.5),
                       hdg=(-lead["yaw"]) % 360, bat=int(100 * (1 - t / 60)),
                       rng=int(((eye[2] - FLOOR) / -view[2] if view[2] < -0.01 else 6000) / 52.5 + 0.5))
        paths.append(objs if objs else [targets[0]["obj"]])
        states.append(dict(eye=[float(v) for v in eye], look=[float(v) for v in look], lens=lens(fov), fov=fov,
                           blank=bool(blank), fx=fx, scorch=[[float(v) for v in s3] for s3 in scorch], hud=hud, lamps=lamps,
                           kits=sounds, pov=pov))
    caps = [(float(starts[i]), float(starts[i + 1]), label) for i, (label, _, _) in enumerate(PLAN) if label]
    spec = dict(frames=paths, states=states, captions=caps, fps=FPS, floor_z=FLOOR, map=MAP, map_moon=MOON, title=TITLE, line=LINE,
                outro=float(starts[-2]), bangs=[(float(t0), p, [float(v) for v in at]) for t0, p, at in bangs],
                impact=impact)
    json.dump(spec, open(os.path.join(dirn, "swarm.json"), "w"))
    print("swarm: %d frames, %d hits, the lead in at %s s" % (n, len(bangs), "%.2f" % impact if impact else "-"))


# ---- the overlay (CoopFPVView.DrawWindow, at 720 lines: s = 1, t = 1), the glows, the static
INK, LOCK, MARK = (225, 240, 225), (255, 72, 48), (255, 190, 64)


def gun_cam(img, hud):
    """The FPV gun-cam overlay over a frame (PIL, RGB), as CoopFPVView draws it."""
    from PIL import ImageDraw, ImageFont
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(r"C:\Windows\Fonts\consola.ttf", 13)
    W, H = img.size
    cx, cy, t = W // 2, H // 2, 1

    def bar(x, y, w, h, c):                                     # (a shadow down and right of it)
        d.rectangle([x + 1, y + 1, x + w, y + h], fill=(0, 0, 0))
        d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)

    def say(x, y, s, c, right=False):
        if right:
            x -= d.textlength(s, font=font)
        d.text((x + 1, y + 1), s, font=font, fill=(0, 0, 0))
        d.text((x, y), s, font=font, fill=c)

    def corners(x1, y1, x2, y2, L, t, c):
        L = min(L, min(x2 - x1, y2 - y1) / 2)
        for x, y, w, h in ((x1, y1, L, t), (x1, y1, t, L), (x2 - L, y1, L, t), (x2 - t, y1, t, L), (x1, y2 - t, L, t),
                           (x1, y2 - L, t, L), (x2 - L, y2 - t, L, t), (x2 - t, y2 - L, t, L)):
            bar(int(x), int(y), max(1, int(w)), max(1, int(h)), c)

    corners(26, 26, W - 26, H - 26, 46, t, INK)                 # the screen's corners, the cross, its dot, the gate
    bar(cx - 39, cy, 30, t, INK)
    bar(cx + 9, cy, 30, t, INK)
    bar(cx, cy - 39, t, 30, INK)
    bar(cx, cy + 9, t, 30, INK)
    bar(cx - t, cy - t, 3 * t, 3 * t, INK)
    corners(cx - 64, cy - 48, cx + 64, cy + 48, 14, t, INK)
    head = hud["hdg"]                                           # the heading tape
    for k in range(int(head / 10) * 10 - 50, int(head) + 51, 10):
        rel = k - head
        if abs(rel) > 45:
            continue
        x = int(cx + rel * 5)
        if k % 30 == 0:
            bar(x, 62, t, 10, INK)
            say(x - 9, 48, "%03d" % ((k + 360) % 360), INK)
        else:
            bar(x, 66, t, 6, INK)
    bar(cx - 4, 76, 8 + t, t, INK)
    bar(cx, 76, t, 6, INK)
    for b in hud["seen"]:                                       # the hostiles, the sent kits' targets, the lock
        corners(*b, 9, t, INK)
    for n, b in hud["marked"]:
        if b:
            corners(*b, 9, t, MARK)
            say(b[0], b[1] - 14, "D%d" % n, MARK)
    if hud["lock"]:
        x1, y1, x2, y2 = hud["lock"]
        corners(x1, y1, x2, y2, 14, t + 1, LOCK)
        bar(int((x1 + x2) / 2) - t, int((y1 + y2) / 2) - t, 3 * t, 3 * t, LOCK)
        say(x1, y1 - 14, "LOCK %dM" % hud["lock_m"], LOCK)
    say(40, 88, "FPV-LEAD", INK)                                # the readouts
    say(40, 102, "SWARM %d" % hud["swarm"], INK)
    T = hud["t"]
    say(W - 40, 88, "T+%02d:%02d.%d" % (T // 60, int(T) % 60, int((T - int(T)) * 10)), INK, True)
    if int(T * 2) % 2 == 0:
        bar(W - 74, 104, 6, 6, LOCK)
    say(W - 40, 102, "REC", INK, True)
    say(40, H - 118, "GEAR MED", INK)
    say(40, H - 104, "BAT %d%%" % hud["bat"], INK)
    say(40, H - 90, "ALT %dM" % hud["alt"], INK)
    say(40, H - 76, "SPD %d M/S" % hud["spd"], INK)
    say(W - 40, H - 90, "HDG %03d" % (int(hud["hdg"] + 0.5) % 360), INK, True)
    say(W - 40, H - 76, "RNG %dM" % hud["rng"], INK, True)
    if hud["lock"]:
        say(cx - 30, cy + 58, "TGT LOCK", LOCK)
    elif hud["swarm"] > 0:
        say(cx - 16, cy + 58, "SCAN", INK)


def glows(px, st):
    """Each fireball's light over the frame (added, as the game's explosion sprites are): px float RGB 0-1."""
    H, W = px.shape[:2]
    eye, look, fov = np.array(st["eye"]), st["look"], st["fov"]
    k = (W / 2) / math.tan(math.radians(fov) / 2)
    yy, xx = np.mgrid[0:H, 0:W]
    for fx in st["fx"]:
        if len(fx) > 5 and fx[5] == 1:
            continue
        q = project(eye, look, fov, fx[:3], W, H)
        if q is None:
            continue
        r = fx[3] * k / max(1.0, np.linalg.norm(np.array(fx[:3]) - eye))
        g = np.exp(-((xx - q[0]) ** 2 + (yy - q[1]) ** 2) / (2 * (1.1 * r) ** 2)) * fx[4]
        px += g[..., None] * np.array([1.0, 0.55, 0.18]) * 1.3


def static(W, H, seed, t):
    """A dead feed: grey noise, torn lines, SIGNAL LOST."""
    from PIL import Image, ImageDraw, ImageFont
    rng = np.random.default_rng(seed)
    n = rng.normal(0.32, 0.13, (H // 2, W // 2))
    n += rng.normal(0, 0.08, (H // 2, 1))                       # (whole lines brighter or darker)
    n = np.kron(np.clip(n, 0, 1), np.ones((2, 2)))
    img = Image.fromarray((np.dstack([n] * 3) * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(r"C:\Windows\Fonts\consola.ttf", 22)
    s = "SIGNAL LOST"
    w = d.textlength(s, font=font)
    d.rectangle([W / 2 - w / 2 - 12, H / 2 - 18, W / 2 + w / 2 + 12, H / 2 + 18], fill=(0, 0, 0))
    if int(t * 2) % 2 == 0:
        d.text((W / 2 - w / 2, H / 2 - 12), s, font=font, fill=LOCK)
    return img


def video(spec_path, pngs, out):
    """The frames with their overlay, the soundtrack, the cut (tools/shot_video.py, the demo videos' cards)."""
    from PIL import Image
    import flykit_video
    from flykit_video import mono, looped, played
    from storm_sounds import RATE, write_wav
    spec = json.load(open(spec_path))
    st, fps = spec["states"], spec["fps"]
    out = os.path.abspath(out)
    over = os.path.abspath(pngs) + "_cut"
    os.makedirs(over, exist_ok=True)
    shots = []
    for f, s in enumerate(st):
        path = os.path.join(over, "c%04d.png" % f)
        if s["blank"]:
            img = static(960, 720, f, f / fps)
        else:
            px = np.asarray(Image.open(os.path.join(pngs, "r%04d.png" % f)).convert("RGB"), np.float32) / 255
            glows(px, s)
            img = Image.fromarray((np.clip(px, 0, 1) * 255).astype(np.uint8))
            if s["hud"]:
                gun_cam(img, s["hud"])
        img.save(path)
        shots.append(path)
    # The soundtrack: each kit's buzz (its throttle, its distance and closing speed on the camera), each hit with its
    # payload's own sound (later by its distance), the dead feed's hiss.
    n = int(len(st) / fps * RATE)
    tf, ts = np.arange(len(st)) / fps, np.arange(n) / RATE
    eyes = np.array([s["eye"] for s in st])
    tracks, mix = [], np.zeros(n)
    for f, s in enumerate(st):                                  # (each kit followed by where it is)
        for e in s["kits"]:
            p = np.array(e[:3])
            near = [tr for tr in tracks if tr["last"] == f - 1 and np.linalg.norm(tr["p"][-1] - p) < 120]
            tr = min(near, key=lambda tr: np.linalg.norm(tr["p"][-1] - p)) if near else None
            if tr is None:
                tr = dict(f0=f, p=[], thr=[], pov=[], last=f - 1)
                tracks.append(tr)
            tr["p"].append(p)
            tr["thr"].append(e[3])
            tr["pov"].append(e[4] if len(e) > 4 else 0.0)
            tr["last"] = f
    loop = looped(mono(os.path.join(ROOT, "src", "RevNet", "Sounds", "FPVBuzz.wav")))
    for k, tr in enumerate(tracks):
        f0, m = tr["f0"], len(tr["p"])
        P = np.array(tr["p"])
        dist = np.linalg.norm(P - eyes[f0:f0 + m], axis=1)
        closing = -np.gradient(dist) * fps if m > 1 else np.zeros(m)
        closing[np.abs(closing) > 3000] = 0
        gain = np.where(np.array(tr["pov"]) > 0, 0.45, np.clip(120 / (dist + 90), 0.01, 1.4))
        rate = (1.0 + 0.35 * np.array(tr["thr"])) * (0.97 + 0.015 * (k % 5)) * 18000 / (18000 - closing)
        a, b = int(f0 / fps * RATE), min(n, int((f0 + m) / fps * RATE))
        tt = ts[a:b]
        fade = np.clip((tt - tt[0]) / 0.05, 0, 1) * np.clip((tt[-1] - tt) / 0.03, 0, 1)
        mix[a:b] += played(loop, np.interp(tt, tf[f0:f0 + m], rate)) * np.interp(tt, tf[f0:f0 + m], gain) * 0.35 * fade
    for t0, payload, at in spec["bangs"]:
        f = min(len(st) - 1, int(t0 * fps))
        dist = np.linalg.norm(np.array(at) - eyes[f])
        snd = flykit_video.mono(os.path.join(ROOT, "build", "tmp", "sounds_dx", BANG[payload][0] + ".wav"))
        a = int((t0 + dist / 18000) * RATE)
        b = min(n, a + len(snd))
        mix[a:b] += snd[:b - a] * float(np.clip(500 / (dist + 250), 0.15, 1.2))
    blank = np.interp(ts, tf, [1.0 if s["blank"] else 0.0 for s in st]) > 0.5
    hiss = np.random.default_rng(3).normal(0, 1, n)
    sp = np.fft.rfft(hiss)
    fr = np.fft.rfftfreq(n, 1 / RATE)
    sp[(fr < 300) | (fr > 7000)] = 0
    hiss = np.fft.irfft(sp, n)
    mix += np.where(blank, hiss / (np.abs(hiss).max() + 1e-9) * 0.25, 0)
    mix = np.tanh(mix * 1.2)
    mix *= 0.9 / (np.abs(mix).max() + 1e-9)
    mix *= np.clip((n / RATE - ts) / 1.0, 0, 1)
    wav = out[:-4] + "_track.wav"
    write_wav(wav, mix)
    # The cards as every demo video has them.
    total, outro = len(st) / fps, spec["outro"]
    caps = [dict(t0=0.15, t1=spec["captions"][0][0] - 0.05, text=spec["title"], size=54, x=48, y=40),
            dict(t0=0.3, t1=spec["captions"][0][0] - 0.05, text=spec["line"], size=28, x=48, y=112)]
    for a, b, label in spec["captions"]:                        # (in the pilot's view: under its readouts)
        caps.append(dict(t0=a + 0.05, t1=b - 0.05, text=label, size=38, x=48,
                         y=130 if st[min(len(st) - 1, int((a + b) / 2 * fps))]["pov"] else 40))
    caps += [dict(t0=outro + 0.2, t1=total - 0.2, text="RevNet  \u00b7  Deus Ex: Revision co-op", size=46,
                  x="(w-tw)/2", y="h/2-60", box=False),
             dict(t0=outro + 0.4, t1=total - 0.2, text=spec["line"] + "  \u00b7  concept render", size=28,
                  x="(w-tw)/2", y="h/2+10", box=False)]
    edit = dict(frames=shots, times=[k / fps for k in range(len(shots))], keep=[[0.0, total]], hold=0, fade=1.0,
                track=wav, captions=caps, fps=fps, dim=[outro, 0.3])
    ej = out[:-4] + "_edit.json"
    json.dump(edit, open(ej, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools", "shot_video.py"), ej, out], check=True)


if __name__ == "__main__":
    out = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else os.path.join("build", "mech", "flykit"))
    if sys.argv[1] == "video":
        video(*sys.argv[2:5])
    elif sys.argv[1] == "trooper":
        trooper(out, *(sys.argv[3:4] or []), *[int(a) for a in sys.argv[4:5]])
    elif sys.argv[1] == "frames":
        frames(out)
