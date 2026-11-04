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


if __name__ == "__main__":
    out = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else os.path.join("build", "mech", "nest"))
    {"build": build, "sheet": sheet, "hive": hive_build, "hivesheet": hive_sheet}[sys.argv[1]](out)
