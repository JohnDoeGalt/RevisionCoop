"""The Light Mech's own parts on JC's trench body (GM_Trench, standing frame 41): Adam Jensen's arm blades out of
both forearms, past the fists, while the blades are held (JensenBlades: CoopLightMechPlayer.MountParts,
CoopMechParts). Built as the Mech's parts are (tools/mech_parts.py): each blade rigid on three of the body's
vertices that keep their distances in every frame, so the mesh has the body's animations frame for frame; its
frames are filled in at install from each PC's own body (bindings.json "also": mech_art.fill, MechParts.cs).
Run after tools/mech_parts.py build (it adds to that build's bindings.json and art folder).

  python -I tools/jensen_parts.py [art dir]     (default build/mech/art)
"""
import json, os, sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mech_art
import mech_parts
from mech_art import bake, frame_of, norm
from mech_parts import Part, choose_anchors, write_a3d, write_d3d

BODY = "GM_Trench"
REST = 41                       # BreatheLight's first frame: standing, arms down


def forearms(F):
    """Each forearm's elbow and wrist (standing frame) and the vertices to anchor its blade on. The low-poly sleeve
    has no vertices between its rings: at a fine tolerance the rigid segments are the hand with the wrist ring (the
    right one holds the weapon triangle, vertex 0; the left its mirror) and the elbow ring (build/tmp/trench_segments.py)."""
    R = F[REST]
    segs = mech_art.segments(F, 0.2)
    right = [g for g in segs if 0 in g][0]
    c = R[right].mean(0)
    left = min((g for g in segs if g is not right and len(g) > 6), key=lambda g: np.linalg.norm(R[g].mean(0) - c * [-1, 1, 1]))
    out = {}
    for side, hand in (("r", right), ("l", left)):
        s = np.sign(R[hand, 0].mean())
        rings = [g for g in segs if len(g) >= 4 and 9 < R[g, 2].mean() < 15 and s * R[g, 0].mean() > 8]
        ring = min(rings, key=lambda g: np.linalg.norm(R[g].mean(0)[:2] - R[hand].mean(0)[:2]))
        P = R[hand]
        top = P[:, 2].max()
        out[side] = dict(verts=list(hand) + list(ring), elbow=R[ring].mean(0), wrist=P[P[:, 2] > top - 1.5].mean(0),
                         radius=float(np.ptp(R[ring, 0])) / 2)
    return out


def long_blade(p, root, tip, ax, out, half=0.85, thick=0.16, point=3.0):
    """Jensen's blade: flat (its flat facing out), narrow where it leaves the forearm, widest before its point."""
    side = norm(np.cross(ax, out))
    for a0, a1, h0, h1 in ((root, tip - ax * point, half * 0.55, half), (tip - ax * point, tip, half, 0.0)):
        p.add_quad(a0 - side * h0 + out * thick, a1 - side * h1 + out * thick, a1 + side * h1 + out * thick, a0 + side * h0 + out * thick, "steel")
        p.add_quad(a0 + side * h0 - out * thick, a1 + side * h1 - out * thick, a1 - side * h1 - out * thick, a0 - side * h0 - out * thick, "steel")


def blade_texture(path, size=256):
    """Brushed steel, a bright edge along one side of each face (its cell is the whole texture)."""
    u = np.arange(size)[None, :] / size
    v = np.arange(size)[:, None] / size
    rng = np.random.default_rng(7)
    streaks = rng.normal(0, 1, (1, size)).repeat(size, 0)
    base = 78 + 10 * streaks + 26 * (1 - v)
    edge = np.clip(1 - np.abs(v - 0.03) / 0.04, 0, 1)
    img = np.stack([base * 0.95, base, base * 1.06], -1) * (1 - edge[..., None]) + np.array([225.0, 230, 238]) * edge[..., None]
    mech_parts.mech_bake.save_pcx(np.clip(img, 0, 255) + 0 * u[..., None], path)


def main():
    art = sys.argv[1] if len(sys.argv) > 1 else os.path.join("build", "mech", "art")
    mech_art.BODY = BODY
    mech_parts.REST = REST
    pkg, m = mech_art.load_body()
    F = mech_art.game_frames(pkg, m)
    R = F[REST]
    arms = forearms(F)
    parts = []
    for side, out in (("r", np.array([1.0, 0, 0])), ("l", np.array([-1.0, 0, 0]))):
        a = arms[side]
        e, w = a["elbow"], a["wrist"]
        ax = norm(w - e)
        out = norm(out - (out @ ax) * ax)
        rad = a["radius"] * 0.85                       # on the sleeve's outer side, thinner at the wrist
        p = Part("blade_" + side, mesh="JensenBlades")
        long_blade(p, e + (w - e) * 0.3 + out * rad, w + ax * 14.0 + out * rad, ax, out)
        p.cells = [(0, 0, 255, 255)] * len(p.faces)
        p.finalize()
        p.anchor_verts = a["verts"]
        parts.append(p)
        print("forearm %s: elbow %s wrist %s radius %.2f" % (side, np.round(e, 2), np.round(w, 2), rad))

    mesh = dict(verts=[], tris=[], parts=[])
    for p in parts:
        P = np.array(p.verts)
        (i, j, k), score = choose_anchors(F, p.anchor_verts, P.mean(axis=0))
        o, M = frame_of(R[i], R[j], R[k])
        local = (P - o) @ M.T
        base = len(mesh["verts"])
        mesh["verts"] += list(P)
        mesh["tris"] += [(x + base, y + base, z + base, ua, ub, uc) for x, y, z, ua, ub, uc in p.tris]
        mesh["parts"].append(dict(part=p.name, anchors=[int(i), int(j), int(k)], first=base, count=len(P),
                                  local=[[round(float(x), 5) for x in v] for v in local]))
        print("JensenBlades %-8s %2d verts, %2d tris, anchors %s (score %.4f)" % (p.name, len(P), len(p.tris), (i, j, k), score))
    nv = len(mesh["verts"])
    baked = bake(F, mesh["parts"], nv)
    raw = np.rint(baked / np.array(m["scale"]) + np.array(m["origin"])).astype(np.int16)
    write_d3d(os.path.join(art, "Models", "JensenBlades_d.3d"), nv, mesh["tris"])
    write_a3d(os.path.join(art, "Models", "JensenBlades_a.3d"), raw)
    mech_parts.write_obj(os.path.join(art, "JensenBlades_rest.obj"), baked[REST], mesh["tris"])
    blade_texture(os.path.join(art, "Textures", "JensenBlade.pcx"))

    # Its import, with the trench body's own origin, scale and animations.
    s, o, rot = m["scale"], m["origin"], m["rot_origin"]
    lines = ["//=============================================================================",
             "// JensenArt: the Light Mech's own parts on JC's trench body (generated by tools/jensen_parts.py).",
             "// Built on each PC from its own copy of the game's body (tools/mech_art.py fill: \"also\").",
             "//=============================================================================",
             "class JensenArt extends Object abstract;", "",
             "#exec TEXTURE IMPORT NAME=JensenBlade FILE=Textures\\JensenBlade.pcx GROUP=Skins",
             "#exec MESH IMPORT MESH=JensenBlades ANIVFILE=Models\\JensenBlades_a.3d DATAFILE=Models\\JensenBlades_d.3d X=0 Y=0 Z=0 MLOD=0",
             "#exec MESH ORIGIN MESH=JensenBlades X=%d Y=%d Z=%d PITCH=%d YAW=%d ROLL=%d" % (
                 o[0], o[1], o[2], rot[0] * 256 // 65536, rot[1] * 256 // 65536, rot[2] * 256 // 65536)]
    for q in m["seqs"]:
        lines.append("#exec MESH SEQUENCE MESH=JensenBlades SEQ=%s STARTFRAME=%d NUMFRAMES=%d RATE=%g" % (
            q["name"], q["start"], q["frames"], q["rate"]))
    lines += ["#exec MESHMAP SCALE MESHMAP=JensenBlades X=%g Y=%g Z=%g" % tuple(s),
              "#exec MESHMAP SETTEXTURE MESHMAP=JensenBlades NUM=0 TEXTURE=JensenBlade"]
    open(os.path.join(art, "Classes", "JensenArt.uc"), "w", newline="\r\n").write("\n".join(lines) + "\n")

    # The fill's second body (mech_art.fill, MechParts.cs).
    bp = os.path.join(art, "bindings.json")
    B = json.load(open(bp))
    B["also"] = [dict(body=BODY, frame_verts=m["frame_verts"], frames=int(F.shape[0]), rest=REST, scale=m["scale"],
                      origin=m["origin"], meshes={"JensenBlades": dict(verts=nv, parts=mesh["parts"])})]
    json.dump(B, open(bp, "w"), indent=1)
    print("JensenBlades: %d verts, %d tris, %d frames -> %s" % (nv, len(mesh["tris"]), F.shape[0], art))


if __name__ == "__main__":
    main()
