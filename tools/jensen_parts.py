"""The Light Mech's own parts on JC's trench body (GM_Trench, standing frame 41): Adam Jensen's arm blades out of
both forearms, past the fists, while the blades are held (JensenBlades: CoopLightMechPlayer.MountParts,
CoopMechParts). Built as the Mech's parts are (tools/mech_parts.py): each blade rigid on three of the body's
vertices that keep their distances in every frame, so the mesh has the body's animations frame for frame; its
frames are filled in at install from each PC's own body (bindings.json "also": mech_art.fill, MechParts.cs). (Its own view
of them: tools/blade_view.py, from mech_parts.)
Run after tools/mech_parts.py build (it adds to that build's bindings.json and art folder).

  python -I tools/jensen_parts.py [art dir]     (default build/mech/art)
"""
import json, os, sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blade_view
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
        p.ends = (e, w)
        parts.append(p)
        print("forearm %s: elbow %s wrist %s radius %.2f" % (side, np.round(e, 2), np.round(w, 2), rad))

    # The blades out, and in steps out of the forearms for others' screens (CoopMechParts.Stages).
    meshes = {}
    for name, ext in [("JensenBlades", 1.0)] + [("JensenBlades%d" % (k + 1), x) for k, x in enumerate(blade_view.STAGES)]:
        mesh = meshes[name] = dict(verts=[], tris=[], parts=[])
        for p in parts:
            P = np.array(p.verts) if ext == 1.0 else blade_view.staged(p.verts, p.ends[0], p.ends[1], ext)
            (i, j, k), score = choose_anchors(F, p.anchor_verts, P.mean(axis=0))
            o, M = frame_of(R[i], R[j], R[k])
            local = (P - o) @ M.T
            base = len(mesh["verts"])
            mesh["verts"] += list(P)
            mesh["tris"] += [(x + base, y + base, z + base, ua, ub, uc) for x, y, z, ua, ub, uc in p.tris]
            mesh["parts"].append(dict(part=p.name, anchors=[int(i), int(j), int(k)], first=base, count=len(P),
                                      local=[[round(float(x), 5) for x in v] for v in local]))
            print("%-13s %-8s %2d verts, %2d tris, anchors %s (score %.4f)" % (name, p.name, len(P), len(p.tris), (i, j, k), score))
        nv = len(mesh["verts"])
        baked = bake(F, mesh["parts"], nv)
        raw = np.rint(baked / np.array(m["scale"]) + np.array(m["origin"])).astype(np.int16)
        write_d3d(os.path.join(art, "Models", name + "_d.3d"), nv, mesh["tris"])
        write_a3d(os.path.join(art, "Models", name + "_a.3d"), raw)
        mech_parts.write_obj(os.path.join(art, name + "_rest.obj"), baked[REST], mesh["tris"])
    blade_view.steel_texture(os.path.join(art, "Textures", "JensenBlade.pcx"))

    # Its import, with the trench body's own origin, scale and animations.
    s, o, rot = m["scale"], m["origin"], m["rot_origin"]
    lines = ["//=============================================================================",
             "// JensenArt: the Light Mech's own parts on JC's trench body (generated by tools/jensen_parts.py).",
             "// Built on each PC from its own copy of the game's body (tools/mech_art.py fill: \"also\").",
             "//=============================================================================",
             "class JensenArt extends Object abstract;", "",
             "#exec TEXTURE IMPORT NAME=JensenBlade FILE=Textures\\JensenBlade.pcx GROUP=Skins",
             "// Its skins on JC's trench body, Adam Jensen's look (tools/jensen_bake.py): CoopLightMechPlayer.LightSkin;",
             "// its arms in its own view. (Here: this class is parsed before MechArt.)",
             "#exec TEXTURE IMPORT NAME=JensenSkin FILE=Textures\\JensenSkin.pcx GROUP=Skins",
             "#exec TEXTURE IMPORT NAME=JensenCoat FILE=Textures\\JensenCoat.pcx GROUP=Skins",
             "#exec TEXTURE IMPORT NAME=JensenPants FILE=Textures\\JensenPants.pcx GROUP=Skins",
             "#exec TEXTURE IMPORT NAME=JensenShirt FILE=Textures\\JensenShirt.pcx GROUP=Skins", ""]
    for name in meshes:
        lines += ["#exec MESH IMPORT MESH=%s ANIVFILE=Models\\%s_a.3d DATAFILE=Models\\%s_d.3d X=0 Y=0 Z=0 MLOD=0" % (name, name, name),
                  "#exec MESH ORIGIN MESH=%s X=%d Y=%d Z=%d PITCH=%d YAW=%d ROLL=%d" % (
                      name, o[0], o[1], o[2], rot[0] * 256 // 65536, rot[1] * 256 // 65536, rot[2] * 256 // 65536)]
        for q in m["seqs"]:
            lines.append("#exec MESH SEQUENCE MESH=%s SEQ=%s STARTFRAME=%d NUMFRAMES=%d RATE=%g" % (
                name, q["name"], q["start"], q["frames"], q["rate"]))
        lines += ["#exec MESHMAP SCALE MESHMAP=%s X=%g Y=%g Z=%g" % ((name,) + tuple(s)),
                  "#exec MESHMAP SETTEXTURE MESHMAP=%s NUM=0 TEXTURE=JensenBlade" % name, ""]
    open(os.path.join(art, "Classes", "JensenArt.uc"), "w", newline="\r\n").write("\n".join(lines) + "\n")

    # The fill's second body (mech_art.fill, MechParts.cs).
    bp = os.path.join(art, "bindings.json")
    B = json.load(open(bp))
    B["also"] = [dict(body=BODY, frame_verts=m["frame_verts"], frames=int(F.shape[0]), rest=REST, scale=m["scale"],
                      origin=m["origin"], meshes={n: dict(verts=len(x["verts"]), parts=x["parts"]) for n, x in meshes.items()})]
    json.dump(B, open(bp, "w"), indent=1)
    print("JensenBlades: %d verts, %d tris, %d frames, %d steps -> %s" % (
        len(meshes["JensenBlades"]["verts"]), len(meshes["JensenBlades"]["tris"]), F.shape[0], len(meshes) - 1, art))


if __name__ == "__main__":
    main()
