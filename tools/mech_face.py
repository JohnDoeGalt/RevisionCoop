"""The Mech's own face, head and hands (slot 3 of the body: 512x512): the user's character art
(art/mech/concept_nanosuit.png: its head front and right profile) projected onto the head by each
texel's 3D position: the front view where the head faces forward (eyes and mouth on the head's),
the profile (mirrored for the left side) for the sides, back and top; black gloves on the hands.

  python -I tools/mech_face.py <out.pcx> [preview.png]
"""
import os, sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mech_art
import mech_bake
from mech_bake import S, bleed, save_pcx

REST = 32
ART = os.path.join(mech_bake.HERE, "art", "mech", "concept_nanosuit.png")
FRONT_BOX, PROFILE_BOX = (1060, 20, 1272, 276), (1275, 20, 1512, 276)   # the sheet's head views
# The head's landmarks (game units, standing frame: +X the body's right, -Y forward).
HEAD_EYE_RIGHT, HEAD_EYE_LEFT, HEAD_EYE_Z, HEAD_MOUTH_Z = 1.4, -2.0, 37.9, 35.0
HEAD_NOSE_Y, HEAD_EAR_Y, HEAD_CHIN_Z = -9.34, -1.6, 32.9
# The art's (pixels in the crops): front eyes (OpenCV's eye cascade) and the line between the lips;
# the profile's nose tip, ear centre, eye height and chin.
FRONT_EYES, FRONT_MOUTH_Y = ((67.1, 118.9), (139.4, 117.9)), 186.0
PROFILE_NOSE_U, PROFILE_EAR_U, PROFILE_EYE_V, PROFILE_CHIN_V = 222.0, 99.0, 120.0, 222.0


def sample(img, u, v):
    """Bilinear samples of img at float pixel coordinates."""
    h, w, _ = img.shape
    u = np.clip(u, 0, w - 2)
    v = np.clip(v, 0, h - 2)
    u0, v0 = np.floor(u).astype(int), np.floor(v).astype(int)
    fu, fv = (u - u0)[..., None], (v - v0)[..., None]
    a, b = img[v0, u0], img[v0, u0 + 1]
    c, d = img[v0 + 1, u0], img[v0 + 1, u0 + 1]
    return (a * (1 - fu) + b * fu) * (1 - fv) + (c * (1 - fu) + d * fu) * fv


def main():
    sheet = Image.open(ART).convert("RGB")
    front_img = np.asarray(sheet.crop(FRONT_BOX), float)
    prof_img = np.asarray(sheet.crop(PROFILE_BOX), float)
    pkg, m = mech_art.load_body()
    R = mech_art.game_frames(pkg, m)[REST]
    va = mech_bake.body_attributes(m, R, mech_bake.parts_tris(os.path.join(mech_bake.HERE, "build", "mech", "art")))
    pos, nrm, ao, mask = mech_bake.raster(m, R, 3, va)
    x, y, z = pos[..., 0], pos[..., 1], pos[..., 2]

    # Front view: the eye line and the eye-to-mouth height set the scales.
    (lu, lv), (ru, rv) = FRONT_EYES
    eye_v = (lv + rv) / 2
    sx = (ru - lu) / (HEAD_EYE_RIGHT - HEAD_EYE_LEFT)
    sz = (FRONT_MOUTH_Y - eye_v) / (HEAD_EYE_Z - HEAD_MOUTH_Z)
    mid_x = (HEAD_EYE_RIGHT + HEAD_EYE_LEFT) / 2
    front = sample(front_img, (lu + ru) / 2 - (x - mid_x) * sx, eye_v - (z - HEAD_EYE_Z) * sz)

    # Profile (the right side; the left side mirrors it): nose-to-ear across, eye-to-chin down.
    su = (PROFILE_NOSE_U - PROFILE_EAR_U) / (HEAD_EAR_Y - HEAD_NOSE_Y)
    sv = (PROFILE_CHIN_V - PROFILE_EYE_V) / (HEAD_EYE_Z - HEAD_CHIN_Z)
    side = sample(prof_img, PROFILE_EAR_U + (HEAD_EAR_Y - y) * su, PROFILE_EYE_V - (z - HEAD_EYE_Z) * sv)

    w = np.clip((-nrm[..., 1] - 0.35) / 0.35, 0, 1)
    w *= np.clip((5.2 - np.abs(x - mid_x)) / 1.2, 0, 1)
    head = w[..., None] * front + (1 - w[..., None]) * side

    img = head * (0.92 + 0.08 * np.clip(ao, 0, 1))[..., None]          # the art has its own shading
    # The armoured collar up to the jaw (under the chin at the front, below the ears at the sides and
    # back), its top edge dark; the hands gloved in the suit's plating.
    jaw = 32.2 + np.clip((y + 4.0) / 4.0, 0, 1) * 1.7
    neck = mask & (z > 15) & (z < jaw)
    img[neck] = mech_bake.collar(pos[neck], nrm[neck], ao[neck]) * (1 - 0.6 * mech_bake.line(jaw - z, 0.12)[neck])[:, None]
    hand = mask & (z < 15)
    img[hand] = mech_bake.nanosuit(pos[hand], nrm[hand], ao[hand], base=36.0, big=1.6, fine=0.6)
    img = np.clip(bleed(img, mask, passes=12), 0, 255)
    im = save_pcx(img, sys.argv[1])
    if len(sys.argv) > 2:
        im.save(sys.argv[2])
    print("wrote", sys.argv[1])


if __name__ == "__main__":
    main()
