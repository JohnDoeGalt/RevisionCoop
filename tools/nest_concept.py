"""Concept art for the kit nest (docs/FLY_KITS.md; brainstormed with the user, 2026-11-03): a Corvane rack of fly kits
wired into a level's security system, launching one or two armed kits straight up when the alarm trips (kits launch
straight up: room above each), its kits lootable when it is taken out. Three designs in the FK-7's palette, each holding
FK-7s armed with 20 mm rounds (the commonest payload), beside the game's own security hardware (Revision's HDTP turret
base and alarm unit, the security computer, a military crate): A a drop box (an armoured crate whose lids open, after
real drone-in-a-box docks), B launch cells (a 2 x 2 block of vertical cells with hatches, after a warship's vertical
launch system), C a wall shelf (kits in a row on a bracket, open above). Each closed or at rest, and launching a kit.

  python -I tools/nest_concept.py build [outdir]   (default build/mech/nest)
  blender -b --factory-startup --python tools/flykit_render.py -- <outdir>/spec.json <outdir>/render
  python -I tools/nest_concept.py sheet [outdir]

Frame: x forward, y left, z up; game units (about 1.9 cm).
"""
import json, math, os, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flykit
from mech_parts import Part
from sensor_concept import C, eye, game_obj, moved, rot_x, rot_y, write_obj

DESIGNS = [("A", "Drop box", "an armoured crate; its lids open and the kits climb out"),
           ("B", "Launch cells", "four vertical cells with hatches, as a warship's launcher"),
           ("C", "Wall shelf", "kits in a row on a wall bracket, open above, a conduit to security")]


def kit_obj(out):
    """An FK-7 with a 20 mm round (tools/flykit.py), as written: (its state, its lowest point, its highest)."""
    st = flykit.build("20 mm HE", out)
    path = flykit.obj(os.path.join(out, "probe.obj"), st)
    V = np.array([[float(x) for x in l.split()[1:4]] for l in open(path) if l.startswith("v ")])
    return st, -0.0 + V[:, 1].min(), V[:, 1].max()      # (OBJ: y up)


def place(st, out, name, t, yaw=0.0):
    """The kit, turned yaw degrees and moved to t."""
    a = math.radians(yaw)
    R = np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])
    T = np.asarray(t, float)
    return flykit.obj(os.path.join(out, name + ".obj"), st, body=lambda q: R @ np.asarray(q, float) + T)


def lid(p, hinge, along, out_dir, w, d, ang, region="hull"):
    """A flat lid hinged on the line through hinge (along), w along it, d out from it, opened ang degrees up."""
    along, out_dir = np.asarray(along, float), np.asarray(out_dir, float)
    up = np.array([0, 0, 1.0])
    a = math.radians(ang)
    o = out_dir * math.cos(a) + up * math.sin(a)
    n = np.cross(along, o)
    c = np.asarray(hinge, float) + o * d / 2
    p.box(c, along, o, n if n[2] >= 0 else -n, (w, d, 0.8), (region, "panel"))


def drop_box(open_):
    p = Part("dropbox")
    W, L, H = 38.0, 26.0, 11.0                        # inside: y, x, depth
    t = 1.4
    p.box((0, 0, 0.7), (1, 0, 0), (0, 1, 0), (0, 0, 1), (L + 2 * t, W + 2 * t, 1.4), ("hull", "hull"))   # the floor
    for sy in (1, -1):
        p.box((0, sy * (W / 2 + t / 2), H / 2 + 0.7), (1, 0, 0), (0, 1, 0), (0, 0, 1), (L + 2 * t, t, H), ("hull", "panel"))
    for sx in (1, -1):
        p.box((sx * (L / 2 + t / 2), 0, H / 2 + 0.7), (1, 0, 0), (0, 1, 0), (0, 0, 1), (t, W, H), ("hull", "panel"))
    for sy in (1, -1):                                  # skids, an amber band round it, corner guards
        p.box((0, sy * (W / 2 - 4), -0.6), (1, 0, 0), (0, 1, 0), (0, 0, 1), (L + 4, 3, 1.2), ("duct", "duct"))
        p.box((0, sy * (W / 2 + t + 0.03), H * 0.62), (1, 0, 0), (0, 1, 0), (0, 0, 1), (L + 2 * t, 0.06, 0.9), ("rim", "rim"))
    for sx in (1, -1):
        for sy in (1, -1):
            p.box((sx * (L / 2 + t / 2), sy * (W / 2 + t / 2), H / 2 + 0.7), (1, 0, 0), (0, 1, 0), (0, 0, 1),
                  (t + 0.6, t + 0.6, H + 0.4), ("duct", "duct"))
    for k, sy in enumerate((1, -1)):                    # the lids, hinged along the long sides
        lid(p, (0, sy * (W / 2 + t), H + 0.9), (1, 0, 0), (0, -sy, 0), L + 2 * t, W / 2 + t, 105 if open_ else 0)
    for sx in (1, -1):                                  # the security link: a junction box and a status bar
        pass
    p.box((-(L / 2 + t + 0.6), 0, H * 0.55), (1, 0, 0), (0, 1, 0), (0, 0, 1), (1.2, 8, 4.5), ("panel", "panel"))
    p.box((-(L / 2 + t + 1.25), 0, H * 0.55 + 1.2), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.1, 6, 0.6), ("light", "light"))
    p.prism((-(L / 2 + t + 1.2), 0, H * 0.55 - 2.2), (-(L / 2 + t + 1.2), 0, -0.4), (1, 0, 0), 0.7, 10, "duct", None, None)
    for cx in (-L / 4, L / 4):                          # charging cradles
        for cy in (-W / 4, W / 4):
            p.box((cx, cy, 2.0), (1, 0, 0), (0, 1, 0), (0, 0, 1), (6, 3.2, 1.2), ("duct", "pad"))
            p.box((cx + 3.2, cy, 2.2), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.3, 1.2, 0.5), ("light", "light"))
    return p, dict(floor=2.6, slots=[(cx, cy) for cx in (-L / 4, L / 4) for cy in (-W / 4, W / 4)], top=H + 1.0)


def launch_cells(hatches_open):
    p = Part("cells")
    cw, cl, H, t = 19.0, 13.0, 12.0, 1.2            # a cell: y, x, depth; the walls
    Y, X = 2 * cw + 3 * t, 2 * cl + 3 * t
    p.box((0, 0, 0.7), (1, 0, 0), (0, 1, 0), (0, 0, 1), (X, Y, 1.4), ("hull", "hull"))
    for k in range(3):                                  # the walls along x and along y
        y = -Y / 2 + t / 2 + k * (cw + t)
        p.box((0, y, H / 2 + 0.7), (1, 0, 0), (0, 1, 0), (0, 0, 1), (X, t, H), ("hull", "panel"))
        x = -X / 2 + t / 2 + k * (cl + t)
        p.box((x, 0, H / 2 + 0.7), (1, 0, 0), (0, 1, 0), (0, 0, 1), (t, Y, H), ("hull", "panel"))
    slots = []
    for i in range(2):
        for j in range(2):
            cx = -X / 2 + t + cl / 2 + i * (cl + t)
            cy = -Y / 2 + t + cw / 2 + j * (cw + t)
            slots.append((cx, cy))
            ang = 100 if (i + j) in hatches_open else 0
            lid(p, (cx - cl / 2, cy, H + 0.9), (0, 1, 0), (1, 0, 0), cw, cl, ang)       # (hinged at the back)
            p.box((cx - cl / 2 + 0.5, cy + cw / 2 - 1.2, H + 1.0), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.6, 0.6, 0.3), ("light", "light"))
    for sy in (1, -1):                                  # hazard band, base skirt
        p.box((0, sy * (Y / 2 + 0.03), H * 0.7), (1, 0, 0), (0, 1, 0), (0, 0, 1), (X, 0.06, 1.0), ("rim", "rim"))
    p.box((0, 0, -0.5), (1, 0, 0), (0, 1, 0), (0, 0, 1), (X + 2, Y + 2, 1.0), ("duct", "duct"))
    p.box((-(X / 2 + 0.7), 0, H * 0.5), (1, 0, 0), (0, 1, 0), (0, 0, 1), (1.4, 10, 5), ("panel", "panel"))
    p.box((-(X / 2 + 1.45), 0, H * 0.5 + 1.4), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.1, 8, 0.6), ("light", "light"))
    return p, dict(floor=2.0, slots=slots, top=H + 1.0)


def wall_shelf():
    p = Part("shelf")
    W, D = 58.0, 15.0                                  # along the wall, out from it
    p.box((-0.6, 0, 6.0), (1, 0, 0), (0, 1, 0), (0, 0, 1), (1.2, W + 4, 16.0), ("hull", "panel"))   # the back plate
    p.box((D / 2, 0, 0.0), (1, 0, 0), (0, 1, 0), (0, 0, 1), (D, W, 1.4), ("hull", "panel"))          # the shelf
    for y in (-W / 2 + 1, 0, W / 2 - 1):               # brackets under it
        p.add_quad((0, y - 0.6, -0.7), (0, y + 0.6, -0.7), (0, y + 0.6, -9), (0, y - 0.6, -9), "duct")
        p.box((D * 0.35, y, -3.5), (1, 0, 0), (0, 1, 0), (0, 0, 1), (D * 0.7, 1.0, 5.5), ("duct", "duct"))
    p.box((D - 0.1, 0, 0.0), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.25, W, 0.6), ("rim", "rim"))     # amber lip
    slots = [(D / 2 + 0.5, y) for y in (-W / 3, 0, W / 3)]
    for cx, cy in slots:
        p.box((cx - 1, cy, 1.2), (1, 0, 0), (0, 1, 0), (0, 0, 1), (6, 3.2, 1.0), ("duct", "pad"))
        p.box((-0.0, cy, 11.0), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.2, 1.4, 0.8), ("light", "light"))
    p.prism((-0.4, W / 2 + 1.0, 13.0), (-0.4, W / 2 + 1.0, 40.0), (1, 0, 0), 0.9, 10, "duct", None, None)   # the conduit
    p.box((0.3, W / 2 - 3, 9.0), (1, 0, 0), (0, 1, 0), (0, 0, 1), (1.4, 6, 4.5), ("panel", "panel"))
    return p, dict(floor=1.7, slots=slots, top=8.0)


def build(out):
    os.makedirs(out, exist_ok=True)
    flykit.PACKAGES["DeusExDeco"] = os.path.join(flykit.REV, "System", "DeusExDeco.u")
    flykit.PACKAGES["HDTPDecos"] = os.path.join(flykit.REV, "HDTP", "System", "HDTPDecos.u")
    st, lo, hi = kit_obj(out)                         # (the kit's lowest point: the 20 mm round under it)
    frames, states = [], []
    # (Each stood on the ground, its middle at half its height: turret base 40 tall, its gun 21, alarm unit 19,
    # computer 15.5, crate 64.)
    refs = [game_obj("HDTPDecos", "HDTPAutoturretbase", 1.0, np.eye(3), (0, 34, 20.2), out, "turret"),
            game_obj("DeusExDeco", "AutoTurretGun", 1.0, np.eye(3), (0, 34, 50.0), out, "turretgun"),
            game_obj("HDTPDecos", "HDTPalarmunit", 1.0, np.eye(3), (0, 8, 9.7), out, "alarm"),
            game_obj("DeusExDeco", "ComputerSecurity", 1.0, np.eye(3), (0, -16, 7.8), out, "computer")]
    frames.append(refs)
    states.append(dict(eye=eye((0, 9, 22), 125, 14, 8), look=(0, 9, 22), lens=50))
    wall = Part("wall")
    wall.box((-1.6, 0, 20), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.6, 140, 80), ("wall", "wall"))
    floor_ = Part("floor")
    floor_.box((40, 0, -1.3), (1, 0, 0), (0, 1, 0), (0, 0, 1), (120, 140, 0.4), ("wall", "wall"))
    wpath = write_obj(wall, os.path.join(out, "wall.obj"))
    fpath = write_obj(floor_, os.path.join(out, "floor.obj"))
    for tag, name, _ in DESIGNS:
        if tag == "A":
            shut, g = drop_box(False)
            opened, _ = drop_box(True)
        elif tag == "B":
            shut, g = launch_cells(())
            opened, _ = launch_cells((0, 1))
        else:
            shut, g = wall_shelf()
            opened = shut
        kits = [place(st, out, "kit_%s_%d" % (tag, k), (cx, cy, g["floor"] - lo)) for k, (cx, cy) in enumerate(g["slots"])]
        # Closed (A, B: the lids down) or at rest (C).
        objs = [write_obj(shut, os.path.join(out, "shut_%s.obj" % tag))] + ([] if tag != "C" else kits) + ([fpath] if tag != "C" else [wpath])
        frames.append(objs)
        states.append(dict(eye=eye((0, 0, 6), 78, 35, 26), look=(0, 0, 6), lens=50))
        # Open, its kits in it.
        frames.append([write_obj(opened, os.path.join(out, "open_%s.obj" % tag))] + kits + ([fpath] if tag != "C" else [wpath]))
        states.append(dict(eye=eye((0, 0, 4), 66, 30, 38), look=(0, 0, 4), lens=50))
        # Launching: the first kit up out of it, straight up (B: from an open cell).
        rise = place(st, out, "kit_%s_up" % tag, (g["slots"][0][0], g["slots"][0][1], g["top"] + 14 - lo))
        frames.append([write_obj(opened, os.path.join(out, "open_%s.obj" % tag))] + kits[1:] + [rise] + ([fpath] if tag != "C" else [wpath]))
        states.append(dict(eye=eye((0, 0, 14), 86, 28, 12), look=(0, 0, 14), lens=50))
    json.dump(dict(frames=frames, states=states, studio=flykit.STUDIO), open(os.path.join(out, "spec.json"), "w"))
    print("spec:", len(frames), "renders ->", os.path.join(out, "spec.json"))


def sheet(out):
    from PIL import Image, ImageDraw, ImageFont
    rd = os.path.join(out, "render")
    font = lambda s: ImageFont.truetype(os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts", "segoeuib.ttf"), s)
    tw, th = 480, 360
    S = Image.new("RGB", (3 * tw, 120 + th + len(DESIGNS) * (60 + th)), (24, 26, 30))
    d = ImageDraw.Draw(S)
    d.text((24, 16), "Kit nest: concepts", fill=(240, 200, 120), font=font(40))
    d.text((24, 70), "The game's own security hardware, for scale and style: turret, alarm unit, security computer",
           fill=(200, 200, 205), font=font(22))
    S.paste(Image.open(os.path.join(rd, "r0000.png")).convert("RGB").resize((3 * tw, th), Image.LANCZOS), (0, 110))
    y = 120 + th
    for i, (tag, name, line) in enumerate(DESIGNS):
        d.text((24, y + 10), "%s  %s" % (tag, name), fill=(240, 200, 120), font=font(30))
        d.text((330, y + 18), line, fill=(200, 200, 205), font=font(20))
        for j, cap in enumerate(("closed" if tag != "C" else "at rest", "open, four FK-7s armed with 20 mm" if tag != "C"
                                 else "three FK-7s armed with 20 mm", "launching: one climbs straight up")):
            im = Image.open(os.path.join(rd, "r%04d.png" % (1 + i * 3 + j))).convert("RGB").resize((tw, th), Image.LANCZOS)
            S.paste(im, (j * tw, y + 60))
            d.text((j * tw + 12, y + 60 + th - 30), cap, fill=(255, 255, 255), font=font(18))
        y += 60 + th
    path = os.path.join(out, "nest_concepts.png")
    S.save(path)
    print(path)


# ---- hives (the user, 2026-11-03: the launch cells or the wall shelf, "maybe... one that's actually influenced by a hive in
# design... if they hung from little arms"): H1 a honeycomb on the wall, kits hanging from little arms out of its cells
# like bees on a comb; H2 a hexagonal pod hung from the ceiling like a wasp nest, a ring of kits hanging from its arms;
# H3 the launch cells as a honeycomb, seven hexagonal cells with hinged hex hatches. A hanging kit is let go, drops a
# little and flies off (no room above it needed); a cell's climbs straight up.
HIVES = [("H1", "Wall hive", "a honeycomb on the wall; kits hang from little arms out of its cells"),
         ("H2", "Ceiling hive", "a hexagonal pod hung from the ceiling, a ring of kits hanging from its arms"),
         ("H3", "Honeycomb cells", "the launch cells as a honeycomb: seven hex cells, hinged hex hatches")]


def turn(p, R, pivot):
    """p turned by R about pivot."""
    pivot = np.asarray(pivot, float)
    return moved(p, R, pivot - R @ pivot)


def rot_z(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])


def claw(p, tip, down=(0, 0, -1)):
    """A small claw gripping a kit's spine from above at tip: a knuckle and two short fingers."""
    tip = np.asarray(tip, float)
    p.prism(tip + [0, 0, 1.6], tip + [0, 0, 0.5], (1, 0, 0), 0.55, 8, "duct", "duct", "duct")
    for s in (1, -1):
        p.box(tip + [0, s * 0.9, 0.2], (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.9, 0.35, 1.2), ("steel", "steel"))
    p.box(tip + [0.75, 0, 1.1], (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.3, 0.5, 0.3), ("light", "light"))


def arm(p, start, pts):
    """A little arm from start through pts (each a joint: a knuckle), its last point the claw's."""
    a = np.asarray(start, float)
    for b in pts:
        b = np.asarray(b, float)
        d = b - a
        v = (0, 0, 1) if abs(d[2]) < 0.9 * np.linalg.norm(d) else (1, 0, 0)
        p.prism(a, b, v, 0.45, 8, "steel", None, None)
        p.prism(b - [0, 0, 0.55], b + [0, 0, 0.55], (1, 0, 0), 0.75, 10, "duct", "duct", "duct")
        a = b


def hex_cell(p, centre, axis, v, R, depth, lit=False):
    """A honeycomb cell: a hex prism along axis, its face an inset darker hex, an amber dot when lit."""
    c, ax = np.asarray(centre, float), np.asarray(axis, float)
    p.prism(c, c + ax * depth, v, R, 6, "hull", None, "panel")
    p.prism(c + ax * (depth - 0.2), c + ax * (depth + 0.08), v, R * 0.72, 6, "duct", None, "duct")
    if lit:
        p.prism(c + ax * (depth + 0.08), c + ax * (depth + 0.2), v, R * 0.16, 6, "light", None, "light")


def wall_hive():
    """Honeycomb cells on the wall (x = 0 plane, facing +x), arms from four of them, kits hanging below the claws."""
    p = Part("wallhive")
    R, gap = 5.0, 1.04
    cells = [(q, r) for q in range(-3, 4) for r in range(-2, 3) if abs(q + r / 2.0) + abs(r) * 0.6 <= 2.6]
    pos = {}
    for q, r in cells:
        y = R * math.sqrt(3) * (q + r / 2.0) * gap
        z = R * 1.5 * r * gap + 26
        pos[(q, r)] = (y, z)
        hex_cell(p, (0, y, z), (1, 0, 0), (0, 0, 1), R, 2.6 + 0.6 * ((q * 7 + r * 3) % 3), lit=((q + 2 * r) % 4 == 0))
    p.prism((-0.2, 0, 26), (-0.2, 0, 60), (1, 0, 0), 1.0, 10, "duct", None, None)        # the conduit to security
    slots = []
    for (q, r), side in (((-2, 0), -1), ((2, 0), 1), ((-1, -1), -1), ((1, -1), 1)):
        y, z = pos[(q, r)] if (q, r) in pos else (side * 10, 18)
        out = 5.5
        tip = (out + 6.5, y + side * 4.0, z - 6.0)
        arm(p, (3.2, y, z), [(out, y, z), (out + 3.5, y + side * 2.0, z - 2.5), tip])
        claw(p, tip)
        slots.append(tip)
    return p, slots


def ceiling_hive():
    """A hexagonal pod hung from the ceiling (at z = 46), six arms round it, a kit hanging from each."""
    p = Part("ceilinghive")
    prof = [(46, 2.0), (43, 2.0), (40, 6.5), (35, 10.5), (28, 12.5), (21, 12.0), (15, 9.0), (11, 4.5), (9.5, 1.2)]
    for k, ((z0, r0), (z1, r1)) in enumerate(zip(prof, prof[1:])):
        p.prism((0, 0, z0), (0, 0, z1), (1, 0, 0), r0, 6, "hull" if k % 2 == 0 else "panel", "panel" if k == 0 else None,
                "duct" if k == len(prof) - 2 else None, radius_end=r1)
    for z in (35.0, 28.0, 21.0):                        # amber seams between its bands
        r = {35.0: 10.5, 28.0: 12.5, 21.0: 12.0}[z]
        p.prism((0, 0, z - 0.15), (0, 0, z + 0.15), (1, 0, 0), r + 0.06, 6, "rim", None, None)
    for k in range(6):                                  # inset hex cells on its widest faces
        a = math.pi / 6 + k * math.pi / 3
        d = np.array([math.cos(a), math.sin(a), 0])
        c = d * 11.0 + [0, 0, 28.0]
        hex_cell(p, c, d, (0, 0, 1), 2.6, 0.9, lit=(k % 2 == 0))
    slots = []
    for k in range(6):                                  # the arms, between the cells
        a = k * math.pi / 3
        d = np.array([math.cos(a), math.sin(a), 0])
        tip = d * 25.0 + [0, 0, 22.0]
        arm(p, d * 11.5 + [0, 0, 33.0], [d * 17.0 + [0, 0, 33.5], d * 22.0 + [0, 0, 28.0], tip])
        claw(p, tip)
        slots.append((tuple(tip), math.degrees(a)))
    return p, slots


def honeycomb_cells(open_cells=()):
    """Seven vertical hex cells (one and six round it), each with a hex hatch hinged at its back vertex."""
    p = Part("honeycomb")
    R, H, t = 10.8, 12.0, 0.9
    cs = [(0.0, 0.0)] + [(math.sqrt(3) * R * math.cos(math.radians(90 + 60 * k)), math.sqrt(3) * R * math.sin(math.radians(90 + 60 * k)))
                         for k in range(6)]
    p.prism((0, 0, -0.6), (0, 0, 0.8), (1, 0, 0), 2.3 * R, 6, "duct", "duct", "hull")      # the base
    for i, (cx, cy) in enumerate(cs):
        V = [np.array([cx + R * math.cos(math.radians(60 * k)), cy + R * math.sin(math.radians(60 * k)), 0.0]) for k in range(6)]
        for k in range(6):                              # the cell's walls (shared walls twice: no matter)
            a, b = V[k], V[(k + 1) % 6]
            m = (a + b) / 2 + [0, 0, H / 2 + 0.8]
            e = (b - a) / np.linalg.norm(b - a)
            n = np.array([-e[1], e[0], 0])
            p.box(m, e, n, (0, 0, 1), (np.linalg.norm(b - a) + t, t, H), ("hull", "panel"))
        hatch = Part("hatch")
        hatch.prism((cx, cy, H + 0.8), (cx, cy, H + 1.6), (1, 0, 0), R * 0.94, 6, "hull", "panel", "panel")
        hatch.prism((cx, cy, H + 1.6), (cx, cy, H + 1.75), (1, 0, 0), R * 0.55, 6, "rim", None, "duct")
        if i in open_cells:
            hatch = turn(hatch, rot_y(-100), (cx - R, cy, H + 1.2))
        p.faces += hatch.faces
        p.box((cx + R * 0.55, cy, H + 1.7), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.6, 0.6, 0.3), ("light", "light"))
    p.box((-(2.1 * R), 0, H * 0.5), (1, 0, 0), (0, 1, 0), (0, 0, 1), (1.4, 10, 5), ("panel", "panel"))   # security box
    return p, [(cx, cy) for cx, cy in cs], H + 1.0


def hive_build(out):
    os.makedirs(out, exist_ok=True)
    st, lo, hi = kit_obj(out)
    frames, states = [], []
    wall = Part("wall")
    wall.box((-0.9, 0, 26), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.6, 140, 80), ("wall", "wall"))
    wpath = write_obj(wall, os.path.join(out, "hwall.obj"))
    ceil = Part("ceiling")
    ceil.box((0, 0, 46.3), (1, 0, 0), (0, 1, 0), (0, 0, 1), (150, 150, 0.6), ("wall", "wall"))
    cpath = write_obj(ceil, os.path.join(out, "ceiling.obj"))
    floor_ = Part("floor")
    floor_.box((0, 0, -1.0), (1, 0, 0), (0, 1, 0), (0, 0, 1), (150, 150, 0.4), ("wall", "wall"))
    fpath = write_obj(floor_, os.path.join(out, "hfloor.obj"))
    # H1: the wall hive.
    p, slots = wall_hive()
    hp = write_obj(p, os.path.join(out, "hive_H1.obj"))
    kits = [place(st, out, "h1kit%d" % k, (tx, ty, tz - hi)) for k, (tx, ty, tz) in enumerate(slots)]
    frames.append([wpath, hp] + kits)
    states.append(dict(eye=eye((4, 0, 22), 92, 32, 12), look=(4, 0, 22), lens=50))
    frames.append([wpath, hp] + kits)
    states.append(dict(eye=eye(slots[1], 30, 40, 18), look=(slots[1][0], slots[1][1], slots[1][2] - 3), lens=50))
    tx, ty, tz = slots[1]
    gone = place(st, out, "h1kit_off", (tx + 16, ty + 4, tz - hi - 7), yaw=-10)
    frames.append([wpath, hp] + kits[:1] + kits[2:] + [gone])
    states.append(dict(eye=eye((10, 4, 20), 100, 40, 10), look=(10, 4, 20), lens=50))
    # H2: the ceiling hive.
    p, slots = ceiling_hive()
    hp = write_obj(p, os.path.join(out, "hive_H2.obj"))
    kits = [place(st, out, "h2kit%d" % k, (tx, ty, tz - hi), yaw=a) for k, ((tx, ty, tz), a) in enumerate(slots)]
    frames.append([cpath, hp] + kits)
    states.append(dict(eye=eye((0, 0, 22), 105, 30, 2), look=(0, 0, 22), lens=50))
    (tx, ty, tz), a = slots[0]
    frames.append([cpath, hp] + kits)
    states.append(dict(eye=eye((tx, ty, tz), 30, 50, 8), look=(tx, ty, tz - 3), lens=50))
    gone = place(st, out, "h2kit_off", (tx + 18, ty, tz - hi - 9), yaw=a)
    frames.append([cpath, hp] + kits[1:] + [gone])
    states.append(dict(eye=eye((8, 0, 18), 110, 25, 2), look=(8, 0, 18), lens=50))
    # H3: the honeycomb cells.
    shut, cs, top = honeycomb_cells(())
    opened, _, _ = honeycomb_cells((0, 1, 3, 5))
    kits = [place(st, out, "h3kit%d" % k, (cx, cy, 2.0 - lo)) for k, (cx, cy) in enumerate(cs)]
    frames.append([fpath, write_obj(shut, os.path.join(out, "hive_H3s.obj"))])
    states.append(dict(eye=eye((0, 0, 6), 95, 35, 30), look=(0, 0, 6), lens=50))
    ho = write_obj(opened, os.path.join(out, "hive_H3o.obj"))
    frames.append([fpath, ho] + kits)
    states.append(dict(eye=eye((0, 0, 4), 80, 30, 50), look=(0, 0, 4), lens=50))
    up = place(st, out, "h3kit_up", (cs[0][0], cs[0][1], top + 16 - lo))
    frames.append([fpath, ho] + kits[1:] + [up])
    states.append(dict(eye=eye((0, 0, 14), 100, 28, 14), look=(0, 0, 14), lens=50))
    json.dump(dict(frames=frames, states=states, studio=flykit.STUDIO), open(os.path.join(out, "spec.json"), "w"))
    print("spec:", len(frames), "renders ->", os.path.join(out, "spec.json"))


def hive_sheet(out):
    from PIL import Image, ImageDraw, ImageFont
    rd = os.path.join(out, "render")
    font = lambda s: ImageFont.truetype(os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts", "segoeuib.ttf"), s)
    tw, th = 480, 360
    S = Image.new("RGB", (3 * tw, 90 + len(HIVES) * (60 + th)), (24, 26, 30))
    d = ImageDraw.Draw(S)
    d.text((24, 16), "Kit nest: hives", fill=(240, 200, 120), font=font(40))
    caps = [("on the wall, four kits hanging", "an arm and its claw, close", "one let go, flying off"),
            ("hung from the ceiling, six kits", "an arm and its claw, close", "one let go, flying off"),
            ("closed", "open, seven FK-7s armed with 20 mm", "launching: one climbs straight up")]
    y = 90
    for i, (tag, name, line) in enumerate(HIVES):
        d.text((24, y + 10), "%s  %s" % (tag, name), fill=(240, 200, 120), font=font(30))
        d.text((360, y + 18), line, fill=(200, 200, 205), font=font(20))
        for j in range(3):
            im = Image.open(os.path.join(rd, "r%04d.png" % (i * 3 + j))).convert("RGB").resize((tw, th), Image.LANCZOS)
            S.paste(im, (j * tw, y + 60))
            d.text((j * tw + 12, y + 60 + th - 30), caps[i][j], fill=(255, 255, 255), font=font(18))
        y += 60 + th
    path = os.path.join(out, "nest_hives.png")
    S.save(path)
    print(path)


# ---- hive-influenced, not literal (the user, 2026-11-03: "maybe less literally a hive lol"): what stays is the kits hanging
# from little arms in a cluster; the hexagons and the nest shapes go for plain industrial hardware beside the game's own
# security kit. I1 a ceiling rail (a beam of arms, after a factory's charging rail); I2 a security mast (arms branching
# at two heights round a pole, a beacon on top); I3 a wall dock (the wall shelf turned over: a slim armoured housing high
# on the wall, its arms folding out under its hood).
RACKS = [("I1", "Ceiling rail", "a beam on the ceiling, a row of arms hanging kits, a conduit along it"),
         ("I2", "Security mast", "a pole, arms branching at two heights, a beacon on top"),
         ("I3", "Wall dock", "a slim armoured housing high on a wall, arms folding out under its hood"),
         ("I4", "Rack system", "a modular frame, bays bolted side by side, two tiers of kits hanging, open in front")]


def hazard_strip(p, centre, u, v, w, size):
    """A row of alternating amber and dark blocks along u (on the face whose normal is w)."""
    c = np.asarray(centre, float)
    n = 8
    for k in range(n):
        off = (k - (n - 1) / 2) * size[0] / n
        p.box(c + np.asarray(u) * off, u, v, w, (size[0] / n, size[1], size[2]), ("rim" if k % 2 == 0 else "band",) * 2)


def ceiling_rail():
    p = Part("rail")
    L, z = 78.0, 43.0
    p.box((0, 0, z), (1, 0, 0), (0, 1, 0), (0, 0, 1), (8.0, L, 5.0), ("hull", "panel"))          # the beam
    for y in (-L / 2 + 4, L / 2 - 4):                  # its hangers to the ceiling
        p.box((0, y, z + 3.2), (1, 0, 0), (0, 1, 0), (0, 0, 1), (5, 2, 1.6), ("duct", "duct"))
    hazard_strip(p, (4.05, 0, z - 1.2), (0, 1, 0), (0, 0, 1), (1, 0, 0), (L - 6, 0.9, 0.08))
    p.prism((-3.2, -L / 2 - 6, z + 2.0), (-3.2, L / 2 + 6, z + 2.0), (0, 0, 1), 0.9, 10, "duct", None, None)   # conduit
    p.box((0, L / 2 + 2, z), (1, 0, 0), (0, 1, 0), (0, 0, 1), (6, 4, 6), ("panel", "panel"))      # the junction box
    p.box((3.05, L / 2 + 2, z + 1.5), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.1, 3, 0.6), ("light", "light"))
    slots = []
    for k in range(4):
        y = -L / 2 + 12 + k * (L - 24) / 3
        p.box((0, y, z - 3.2), (1, 0, 0), (0, 1, 0), (0, 0, 1), (5, 4, 1.6), ("duct", "duct"))  # a trolley
        p.box((2.6, y + 1.2, z - 3.2), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.2, 0.6, 0.6), ("light", "light"))
        tip = (2.5, y, z - 13.0)
        arm(p, (0, y, z - 4.0), [(0, y, z - 7.5), tip])
        claw(p, tip)
        slots.append((tip, 0.0))
    return p, slots


def security_mast():
    p = Part("mast")
    p.box((0, 0, 0.8), (1, 0, 0), (0, 1, 0), (0, 0, 1), (16, 16, 1.6), ("hull", "panel"))       # the base plate
    for sx in (1, -1):
        for sy in (1, -1):
            p.prism((sx * 6.2, sy * 6.2, 1.6), (sx * 6.2, sy * 6.2, 2.2), (1, 0, 0), 0.6, 6, "steel", None, "steel")
    p.box((0, 0, 7.0), (1, 0, 0), (0, 1, 0), (0, 0, 1), (7, 7, 10), ("hull", "panel"))           # the power housing
    hazard_strip(p, (3.55, 0, 3.0), (0, 1, 0), (0, 0, 1), (1, 0, 0), (6.6, 1.2, 0.08))
    p.box((3.56, 0, 9.5), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.1, 3.5, 0.6), ("light", "light"))
    p.prism((0, 0, 12), (0, 0, 64), (1, 0, 0), 1.5, 8, "steel", None, None)                     # the pole
    p.prism((0, 0, 64), (0, 0, 66.5), (1, 0, 0), 1.2, 10, "duct", None, None)
    p.prism((0, 0, 66.5), (0, 0, 68.5), (1, 0, 0), 1.0, 10, "light", None, "light")             # the beacon
    slots = []
    for h, a0 in ((54.0, 45.0), (38.0, 0.0)):
        p.prism((0, 0, h - 1.5), (0, 0, h + 1.5), (1, 0, 0), 2.6, 8, "duct", "duct", "duct")     # a collar
        for k in range(3 if h > 50 else 3):
            a = math.radians(a0 + k * 120)
            d = np.array([math.cos(a), math.sin(a), 0])
            tip = d * 15.0 + [0, 0, h - 8.0]
            arm(p, d * 2.4 + [0, 0, h], [d * 9.0 + [0, 0, h + 1.5], tip])
            claw(p, tip)
            slots.append((tuple(tip), math.degrees(a)))
    return p, slots


def wall_dock():
    p = Part("dock")
    W, z = 74.0, 40.0                                 # (arms 18 apart: a kit is 16.2 across)
    p.box((4.0, 0, z), (1, 0, 0), (0, 1, 0), (0, 0, 1), (8.0, W, 6.0), ("hull", "panel"))       # the housing
    p.box((8.4, 0, z - 2.6), (1, 0, 0), (0, 1, 0), (0, 0, 1), (1.2, W, 1.2), ("duct", "duct"))   # its hood lip
    hazard_strip(p, (8.05, 0, z + 1.2), (0, 1, 0), (0, 0, 1), (1, 0, 0), (W - 8, 1.0, 0.08))
    for y in (-W / 2 + 3, W / 2 - 3):                  # wall brackets
        p.box((1.0, y, z - 5.0), (1, 0, 0), (0, 1, 0), (0, 0, 1), (2, 1.5, 8), ("duct", "duct"))
    p.prism((0.4, W / 2 - 6, z + 3.0), (0.4, W / 2 - 6, z + 30.0), (1, 0, 0), 0.9, 10, "duct", None, None)   # conduit
    slots = []
    for k in range(4):
        y = -W / 2 + 10 + k * (W - 20) / 3
        p.box((8.05, y + 3.0, z), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.1, 0.8, 0.8), ("light", "light"))
        tip = (13.0, y, z - 10.0)
        arm(p, (6.0, y, z - 3.0), [(10.5, y, z - 4.5), tip])
        claw(p, tip)
        slots.append((tip, 0.0))
    return p, slots


def rack_system(bays=2, tiers=2):
    """A free-standing modular frame (the user: "maybe a rack system?"): bays side by side (y), tiers one above another,
    a kit hanging from a claw under each tier's rail, open in front (+x) for the kits to fly out; a power bay at its end."""
    p = Part("racksys")
    bw, dp, th = 22.0, 14.0, 18.0                      # a bay's width, its depth, a tier's height
    W, H = bays * bw, tiers * th + 4.0
    y0 = -W / 2
    for k in range(bays + 1):                          # the uprights (front and back), hazard-banded at the foot
        y = y0 + k * bw
        for x in (-dp / 2, dp / 2):
            p.box((x, y, H / 2), (1, 0, 0), (0, 1, 0), (0, 0, 1), (1.4, 1.4, H), ("hull", "panel"))
            for j in range(4):
                p.box((x + (0.72 if x > 0 else -0.72), y, 1.0 + j * 1.6), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.06, 1.3, 0.8),
                      ("rim" if j % 2 == 0 else "band",) * 2)
        p.box((0, y, H - 0.5), (1, 0, 0), (0, 1, 0), (0, 0, 1), (dp, 1.4, 1.0), ("hull", "panel"))   # the top ties
        p.box((0, y, 0.5), (1, 0, 0), (0, 1, 0), (0, 0, 1), (dp + 2, 2.0, 1.0), ("duct", "duct"))   # the feet
    slots = []
    for i in range(tiers):
        zr = (i + 1) * th + 2.0                         # this tier's rail
        for x in (-dp / 2, dp / 2):
            p.box((x, 0, zr), (1, 0, 0), (0, 1, 0), (0, 0, 1), (1.2, W, 1.6), ("hull", "panel"))
        for k in range(bays):
            y = y0 + (k + 0.5) * bw
            p.box((0, y, zr + 0.2), (1, 0, 0), (0, 1, 0), (0, 0, 1), (dp, 2.2, 1.2), ("duct", "duct"))    # the bay's rail
            tip = (1.0, y, zr - 4.0)
            arm(p, (0, y, zr - 0.6), [tip])
            claw(p, tip)
            p.box((dp / 2 + 0.65, y + 6, zr), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.1, 0.8, 0.6), ("light", "light"))
            slots.append((tip, 0.0))
    p.box((0, W / 2 + 5, H * 0.35), (1, 0, 0), (0, 1, 0), (0, 0, 1), (dp, 8, H * 0.7), ("hull", "panel"))   # power bay
    p.box((dp / 2 + 0.05, W / 2 + 5, H * 0.5), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.1, 5, 0.8), ("light", "light"))
    p.prism((-dp / 2 + 1, W / 2 + 5, H * 0.7), (-dp / 2 + 1, W / 2 + 5, H + 30), (1, 0, 0), 0.9, 10, "duct", None, None)
    return p, slots


def rack_build(out):
    os.makedirs(out, exist_ok=True)
    st, lo, hi = kit_obj(out)
    frames, states = [], []
    wall = Part("wall")
    wall.box((-0.9, 0, 30), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.6, 150, 90), ("wall", "wall"))
    ceil = Part("ceiling")
    ceil.box((0, 0, 46.3), (1, 0, 0), (0, 1, 0), (0, 0, 1), (160, 160, 0.6), ("wall", "wall"))
    floor_ = Part("floor")
    floor_.box((0, 0, -0.2), (1, 0, 0), (0, 1, 0), (0, 0, 1), (160, 160, 0.4), ("wall", "wall"))
    wp, cp, fp = (write_obj(x, os.path.join(out, n + ".obj")) for x, n in ((wall, "rwall"), (ceil, "rceil"), (floor_, "rfloor")))
    for tag, make, scene, view, near, off in (
            ("I1", ceiling_rail, [cp], ((0, 0, 30), 105, 30, -4), 34, (16, 0, -12)),
            ("I2", security_mast, [fp], ((0, 0, 38), 120, 30, 6), 32, (18, 4, -10)),
            ("I3", wall_dock, [wp], ((6, 0, 30), 100, 38, 8), 32, (18, 4, -10)),
            ("I4", rack_system, [fp], ((0, 4, 20), 100, 32, 14), 30, (20, 0, -6))):
        p, slots = make()
        hp = write_obj(p, os.path.join(out, "rack_%s.obj" % tag))
        kits = [place(st, out, "%skit%d" % (tag, k), (tx, ty, tz - hi), yaw=a) for k, ((tx, ty, tz), a) in enumerate(slots)]
        (look, dist, az, el) = view
        frames.append(scene + [hp] + kits)
        states.append(dict(eye=eye(look, dist, az, el), look=look, lens=50))
        (tx, ty, tz), a = slots[1]
        frames.append(scene + [hp] + kits)
        states.append(dict(eye=eye((tx, ty, tz), near, az + 20, 14), look=(tx, ty, tz - 3), lens=50))
        R = np.array([[math.cos(math.radians(a)), -math.sin(math.radians(a)), 0], [math.sin(math.radians(a)), math.cos(math.radians(a)), 0], [0, 0, 1]])
        gone = place(st, out, "%skit_off" % tag, np.array((tx, ty, tz - hi)) + R @ np.array(off, float), yaw=a)
        frames.append(scene + [hp] + kits[:1] + kits[2:] + [gone])
        states.append(dict(eye=eye(look, dist, az, el), look=look, lens=50))
    json.dump(dict(frames=frames, states=states, studio=flykit.STUDIO), open(os.path.join(out, "spec.json"), "w"))
    print("spec:", len(frames), "renders ->", os.path.join(out, "spec.json"))


def rack_sheet(out):
    from PIL import Image, ImageDraw, ImageFont
    rd = os.path.join(out, "render")
    font = lambda s: ImageFont.truetype(os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts", "segoeuib.ttf"), s)
    tw, th = 480, 360
    S = Image.new("RGB", (3 * tw, 90 + len(RACKS) * (60 + th)), (24, 26, 30))
    d = ImageDraw.Draw(S)
    d.text((24, 16), "Kit nest: hive-influenced, industrial", fill=(240, 200, 120), font=font(40))
    y = 90
    for i, (tag, name, line) in enumerate(RACKS):
        d.text((24, y + 10), "%s  %s" % (tag, name), fill=(240, 200, 120), font=font(30))
        d.text((330, y + 18), line, fill=(200, 200, 205), font=font(20))
        for j, cap in enumerate(("at rest, its kits hanging", "an arm and its claw, close", "one let go, flying off")):
            im = Image.open(os.path.join(rd, "r%04d.png" % (i * 3 + j))).convert("RGB").resize((tw, th), Image.LANCZOS)
            S.paste(im, (j * tw, y + 60))
            d.text((j * tw + 12, y + 60 + th - 30), cap, fill=(255, 255, 255), font=font(18))
        y += 60 + th
    path = os.path.join(out, "nest_racks.png")
    S.save(path)
    print(path)


# ---- the modular rack (the user, 2026-11-03: "the design should look scalable, and modular. it should be free standing
# capable, wall mountable, vehicular mountable, etc"): one standard module, Corvane's KR-7, one kit hanging from a claw
# under its top rail, open in front, couplers on its sides (power and data through copper pads) and stacking pins top
# and bottom, its own status light; modules lock side by side and on top of one another; the mounts are adapters: a
# base with feet and a power module (free-standing), a rail the modules hook onto (wall), a low clamp frame (a vehicle's
# roof: the game's own van).
BW, DP, TH = 21.0, 14.0, 17.0                          # a module: width (y), depth (x), height (z)


def kr_module(p, origin):
    """A KR-7 module with its bottom at origin (its middle, y and x): returns its claw's tip."""
    o = np.asarray(origin, float)
    for sx in (1, -1):                                  # corner posts
        for sy in (1, -1):
            p.box(o + [sx * (DP / 2 - 0.6), sy * (BW / 2 - 0.6), TH / 2], (1, 0, 0), (0, 1, 0), (0, 0, 1),
                  (1.2, 1.2, TH), ("hull", "panel"))
    for sx in (1, -1):                                  # top and bottom rails, front and back
        for z in (0.6, TH - 0.6):
            p.box(o + [sx * (DP / 2 - 0.6), 0, z], (1, 0, 0), (0, 1, 0), (0, 0, 1), (1.2, BW - 2.4, 1.2), ("hull", "panel"))
    for sy in (1, -1):                                  # side rails, and a coupler on each side
        for z in (0.6, TH - 0.6):
            p.box(o + [0, sy * (BW / 2 - 0.6), z], (1, 0, 0), (0, 1, 0), (0, 0, 1), (DP - 2.4, 1.2, 1.2), ("hull", "panel"))
        p.box(o + [0, sy * (BW / 2 - 0.35), TH * 0.62], (1, 0, 0), (0, 1, 0), (0, 0, 1), (5.0, 0.7, 3.2), ("duct", "duct"))
        p.box(o + [0, sy * (BW / 2 + 0.02), TH * 0.62], (1, 0, 0), (0, 1, 0), (0, 0, 1), (3.4, 0.06, 1.8), ("pad", "pad"))
    for sx in (1, -1):                                  # stacking pins on top
        for sy in (1, -1):
            p.prism(o + [sx * (DP / 2 - 0.6), sy * (BW / 2 - 0.6), TH], o + [sx * (DP / 2 - 0.6), sy * (BW / 2 - 0.6), TH + 0.5],
                    (1, 0, 0), 0.35, 6, "steel", None, "steel")
    p.box(o + [0, 0, TH - 1.6], (1, 0, 0), (0, 1, 0), (0, 0, 1), (DP - 2.4, 4.0, 1.6), ("duct", "duct"))   # the spine
    p.box(o + [DP / 2 - 0.55, BW / 2 - 3.0, TH - 0.6], (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.12, 2.0, 0.6), ("light", "light"))
    p.box(o + [DP / 2 - 0.55, -BW / 2 + 5.0, TH - 0.6], (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.1, 5.0, 0.9), ("rim", "rim"))
    tip = o + [0.6, 0, TH - 5.6]
    arm(p, o + [0.6, 0, TH - 2.4], [tip])
    claw(p, tip)
    return tuple(tip)


def kr_grid(p, origin, nx, nz):
    """nx modules side by side (y), nz high, from origin (the grid's bottom middle): their claws' tips."""
    tips = []
    for i in range(nx):
        for j in range(nz):
            tips.append(kr_module(p, np.asarray(origin, float) + [0, (i - (nx - 1) / 2) * BW, j * (TH + 0.5)]))
    return tips


def kr_power(p, origin, h):
    """A power and control module (a module's footprint, h tall) at origin: a beacon and a conduit up from it."""
    o = np.asarray(origin, float)
    flykit.chamfer_box(p, tuple(o + [-DP / 2, -BW / 4, 0]), tuple(o + [DP / 2, BW / 4, h]), 0.5, "hull", "panel")
    p.box(o + [DP / 2 + 0.05, 0, h * 0.7], (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.1, 6, 0.8), ("light", "light"))
    hazard_strip(p, o + [DP / 2 + 0.05, 0, h * 0.3], (0, 1, 0), (0, 0, 1), (1, 0, 0), (BW / 2 - 2, 1.2, 0.08))
    p.prism(o + [-DP / 2 + 2, 0, h], o + [-DP / 2 + 2, 0, h + 26], (1, 0, 0), 0.9, 10, "duct", None, None)


def kr_feet(p, origin, width):
    """The free-standing base: a beam under the modules, splayed feet with pads."""
    o = np.asarray(origin, float)
    p.box(o + [0, 0, 1.6], (1, 0, 0), (0, 1, 0), (0, 0, 1), (DP + 1, width, 1.6), ("duct", "duct"))
    for y in np.linspace(-width / 2 + 2, width / 2 - 2, max(2, int(width // BW) + 1)):
        p.box(o + [0, y, 0.5], (1, 0, 0), (0, 1, 0), (0, 0, 1), (DP + 8, 2.2, 1.0), ("hull", "panel"))
        for sx in (1, -1):
            p.prism(o + [sx * (DP / 2 + 3.4), y, 0], o + [sx * (DP / 2 + 3.4), y, -0.4], (1, 0, 0), 1.4, 8, "band", "band", None)


def kr_wall_mount(p, n, top, bottom, back):
    """The wall mount (wall at x = 0): a rail above the modules with a hook over each one's back rail, and a knee brace
    under every joint, from a wall plate out under the modules' floor. n modules, their backs at x = back."""
    width = n * BW
    p.box((1.2, 0, top + 2.6), (1, 0, 0), (0, 1, 0), (0, 0, 1), (2.4, width + 6, 3.6), ("hull", "panel"))
    hazard_strip(p, (2.45, 0, top + 2.6), (0, 1, 0), (0, 0, 1), (1, 0, 0), (width + 2, 1.2, 0.08))
    for k in range(n):
        y = -width / 2 + (k + 0.5) * BW
        p.box(((back + 1.6) / 2, y, top + 0.4), (1, 0, 0), (0, 1, 0), (0, 0, 1), (back + 1.6, 3.0, 0.8), ("duct", "duct"))
        p.box((back + 1.4, y, top - 0.2), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.4, 3.0, 2.0), ("duct", "duct"))
    for y in [-width / 2 + 0.8] + [-width / 2 + k * BW for k in range(1, n)] + [width / 2 - 0.8]:
        p.box((0.3, y, bottom - 7.0), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.6, 3.0, 15.0), ("duct", "duct"))
        p.box(((back + DP) / 2, y, bottom - 0.6), (1, 0, 0), (0, 1, 0), (0, 0, 1), (back + DP, 1.4, 1.2), ("hull", "panel"))
        p.prism((0.6, y, bottom - 13.0), (back + DP - 2.0, y, bottom - 1.2), (0, 1, 0), 0.6, 8, "steel", None, None)


def kr_vehicle_frame(p, origin, length, width):
    """The vehicle mount: a low frame clamped to a roof (rails along it, clamp feet), its own small power module."""
    o = np.asarray(origin, float)
    for sy in (1, -1):
        p.box(o + [0, sy * (width / 2 - 1), 1.0], (1, 0, 0), (0, 1, 0), (0, 0, 1), (length, 2.0, 2.0), ("hull", "panel"))
        for x in (-length / 2 + 4, length / 2 - 4):
            p.box(o + [x, sy * (width / 2 - 1), -0.2], (1, 0, 0), (0, 1, 0), (0, 0, 1), (3.0, 3.0, 1.2), ("duct", "duct"))
    for x in np.linspace(-length / 2 + 2, length / 2 - 2, 4):
        p.box(o + [x, 0, 2.2], (1, 0, 0), (0, 1, 0), (0, 0, 1), (2.0, width, 0.8), ("duct", "duct"))


def obj_bounds(path):
    V = np.array([[float(x) for x in l.split()[1:4]] for l in open(path) if l.startswith("v ")])
    G = np.stack([V[:, 0], -V[:, 2], V[:, 1]], 1)        # (back from OBJ's y up)
    return G.min(0), G.max(0)


def mod_build(out):
    os.makedirs(out, exist_ok=True)
    flykit.PACKAGES["DeusExDeco"] = os.path.join(flykit.REV, "System", "DeusExDeco.u")
    st, lo, hi = kit_obj(out)
    frames, states = [], []
    wall = Part("wall")
    wall.box((-0.3, 0, 30), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.6, 180, 100), ("wall", "wall"))
    floor_ = Part("floor")
    floor_.box((0, 0, -0.6), (1, 0, 0), (0, 1, 0), (0, 0, 1), (300, 300, 0.4), ("wall", "wall"))
    wp, fp = write_obj(wall, os.path.join(out, "mwall.obj")), write_obj(floor_, os.path.join(out, "mfloor.obj"))
    hang = lambda tips, tag: [place(st, out, "%s%d" % (tag, k), (tx, ty, tz - hi)) for k, (tx, ty, tz) in enumerate(tips)]

    # 0: one module, close.
    p = Part("one")
    tips = kr_grid(p, (0, 0, 0), 1, 1)
    frames.append([fp, write_obj(p, os.path.join(out, "m_one.obj"))] + hang(tips, "one"))
    states.append(dict(eye=eye((0, 0, 9), 42, 32, 16), look=(0, 0, 9), lens=50))
    # 1: scaling: one, two side by side, three by two (each on its feet).
    p = Part("scale")
    tips = []
    for (y, nx, nz) in ((-62, 1, 1), (-25, 2, 1), (40, 3, 2)):
        kr_feet(p, (0, y, 0), nx * BW)
        tips += kr_grid(p, (0, y, 2.4), nx, nz)
    frames.append([fp, write_obj(p, os.path.join(out, "m_scale.obj"))] + hang(tips, "sc"))
    states.append(dict(eye=eye((0, 8, 16), 240, 22, 12), look=(0, 8, 16), lens=50))
    # 2: free-standing, three by two, a power module at its end.
    p = Part("free")
    kr_feet(p, (0, 0, 0), 3 * BW + BW / 2 + 2)
    tips = kr_grid(p, (0, -BW / 4 - 1, 2.4), 3, 2)
    kr_power(p, (0, 3 * BW / 2 + BW / 4 - BW / 4 + 1, 2.4), 2 * TH)
    fpath = write_obj(p, os.path.join(out, "m_free.obj"))
    kits = hang(tips, "fr")
    frames.append([fp, fpath] + kits)
    states.append(dict(eye=eye((0, 0, 18), 112, 30, 14), look=(0, 0, 18), lens=50))
    # 3: wall-mounted: four in a row, hooked under a rail, knee braces below.
    p = Part("wallm")
    back, bottom = 2.4, 28.0
    tips = kr_grid(p, (back + DP / 2, 0, bottom), 4, 1)
    kr_wall_mount(p, 4, bottom + TH, bottom, back)
    frames.append([wp, write_obj(p, os.path.join(out, "m_wall.obj"))] + hang(tips, "wl"))
    states.append(dict(eye=eye((10, 0, 32), 130, 36, 10), look=(10, 0, 32), lens=50))
    # 4: on a vehicle's roof: the game's own van, a clamp frame along it, two rows of four back to back facing out
    # each side.
    van = game_obj("DeusExDeco", "Van", 1.0, np.eye(3), (0, 0, 0), out, "van")
    vlo, vhi = obj_bounds(van)
    van = game_obj("DeusExDeco", "Van", 1.0, np.eye(3), (0, 0, -vlo[2]), out, "van")
    vlo, vhi = obj_bounds(van)
    assert (vhi[0] - vlo[0]) >= (vhi[1] - vlo[1]), "the van runs along y"
    cx, cy, roof = (vlo[0] + vhi[0]) / 2, (vlo[1] + vhi[1]) / 2, vhi[2]
    p = Part("veh")
    kr_vehicle_frame(p, (cx, cy, roof), 4 * BW + 6, 2 * DP + 6)
    kits = []
    for s in (1, -1):                                   # a row facing +y (s = 1), one facing -y
        q = Part("vrow")
        R, t = rot_z(90 * s), np.array([cx, cy + s * (DP / 2 + 0.3), 0.0])
        tips = kr_grid(q, (0, 0, roof + 2.6), 4, 1)
        p.faces += moved(q, R, t).faces
        kits += [place(st, out, "vh%d%d" % (s + 1, k), R @ np.asarray(tp) + t - [0, 0, hi], yaw=90.0 * s)
                 for k, tp in enumerate(tips)]
    frames.append([fp, van, write_obj(p, os.path.join(out, "m_veh.obj"))] + kits)
    states.append(dict(eye=eye((cx, cy, roof * 0.65), 500, 62, 24), look=(cx, cy, roof * 0.65), lens=50))
    print("van: %.0f x %.0f x %.0f units, roof at %.0f" % (*(vhi - vlo), roof))
    # 5: launching: the free-standing rack, one kit let go, flying out of the front.
    tx, ty, tz = kr_grid(Part("tmp"), (0, -BW / 4 - 1, 2.4), 3, 2)[1]
    gone = place(st, out, "fr_off", (tx + 22, ty, tz - hi - 5))
    frames.append([fp, fpath] + kits_free_without(out, st, hi, 1) + [gone])
    states.append(dict(eye=eye((10, 0, 18), 118, 28, 12), look=(10, 0, 18), lens=50))
    json.dump(dict(frames=frames, states=states, studio=flykit.STUDIO), open(os.path.join(out, "spec.json"), "w"))
    print("spec:", len(frames), "renders ->", os.path.join(out, "spec.json"))


def kits_free_without(out, st, hi, skip):
    tips = kr_grid(Part("tmp"), (0, -BW / 4 - 1, 2.4), 3, 2)
    return [place(st, out, "frw%d" % k, (tx, ty, tz - hi)) for k, (tx, ty, tz) in enumerate(tips) if k != skip]


def mod_sheet(out):
    from PIL import Image, ImageDraw, ImageFont
    rd = os.path.join(out, "render")
    font = lambda s: ImageFont.truetype(os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts", "segoeuib.ttf"), s)
    tw, th = 640, 480
    caps = ("one KR-7 module: a kit on its claw, couplers on its sides, stacking pins on top",
            "scalable: one, two side by side, three by two", "free-standing: three by two, feet and a power module",
            "wall-mounted: four hooked under a rail, knee braces below",
            "vehicle-mounted: two rows of four, back to back, on the game's own van",
            "launching: one let go, flying out of the front")
    S = Image.new("RGB", (2 * tw, 80 + 3 * th), (24, 26, 30))
    d = ImageDraw.Draw(S)
    d.text((24, 16), "Kit nest: the KR-7 modular rack", fill=(240, 200, 120), font=font(38))
    for i, cap in enumerate(caps):
        im = Image.open(os.path.join(rd, "r%04d.png" % i)).convert("RGB").resize((tw, th), Image.LANCZOS)
        x, y = (i % 2) * tw, 80 + (i // 2) * th
        S.paste(im, (x, y))
        d.rectangle((x, y + th - 36, x + tw, y + th), fill=(24, 26, 30))
        d.text((x + 12, y + th - 30), cap, fill=(255, 255, 255), font=font(17))
    path = os.path.join(out, "nest_kr7_modular.png")
    S.save(path)
    print(path)


if __name__ == "__main__":
    out = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else os.path.join("build", "mech", "nest"))
    {"build": build, "sheet": sheet, "hive": hive_build, "hivesheet": hive_sheet, "rack": rack_build,
     "racksheet": rack_sheet, "mod": mod_build, "modsheet": mod_sheet}[sys.argv[1]](out)
