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


if __name__ == "__main__":
    out = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else os.path.join("build", "mech", "nest"))
    {"build": build, "sheet": sheet}[sys.argv[1]](out)
