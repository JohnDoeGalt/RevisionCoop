"""The Light Mech's skins: Adam Jensen's look (the user's ask, docs/LIGHT_MECH_CLASS.md) on JC's trench body
(GM_Trench, standing frame 41), our own art painted from the 3D surface as the Mech's are (tools/mech_bake.py):

- JensenCoat (slots 1 and 5, one layout): black leather, a thin gold trim along its edges. Palette index 0 stays
  unused: slot 5 (the coat's tails) is masked.
- JensenPants (slot 2): black trousers. JensenShirt (slot 4): a black ribbed turtleneck.
- JensenSkin (slot 0: head and hands): a head sheet made for it (art/lightmech/jensen_head.png, Z-Image Turbo: its
  front and right profile) projected by each texel's 3D point as tools/mech_face.py does; the hands black carbon
  with gold seams (prosthetics).

Slots 6 and 7 (the shades) keep the game's own textures.

  python -I tools/jensen_bake.py <outdir> [preview.png]
"""
import os, sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mech_art
import mech_bake
from mech_bake import S, bleed, save_pcx, triplanar, material, lit, line
from mech_face import sample

REST = 41
BODY = "GM_Trench"
HEAD = os.path.join(mech_bake.HERE, "art", "lightmech", "jensen_head.png")
FRONT_BOX, PROFILE_BOX = (150, 20, 700, 700), (700, 20, 1300, 700)      # the sheet's head views
# The head's landmarks (game units, standing frame: +X the body's right, -Y forward): the eyes from the lens
# faces (slot 7), the nose tip, the chin (build/tmp/trench_head.py).
HEAD_EYE_RIGHT, HEAD_EYE_LEFT, HEAD_EYE_Z, HEAD_MOUTH_Z = 1.9, -1.55, 37.7, 34.3
HEAD_NOSE_Y, HEAD_EAR_Y, HEAD_CHIN_Z = -10.0, -2.5, 32.0
# The sheet's (pixels in the crops): the lens centres and the line between the lips; the profile's nose tip,
# ear centre, eye height and chin.
FRONT_EYES, FRONT_MOUTH_Y = ((172.0, 325.0), (318.0, 325.0)), 463.0
PROFILE_NOSE_U, PROFILE_EAR_U, PROFILE_EYE_V, PROFILE_CHIN_V = 465.0, 215.0, 325.0, 523.0
GOLD = np.array([200.0, 152.0, 64.0])
WARM = np.array([1.05, 1.0, 0.94])          # the leather's warm black


def edges(mask, width):
    """Texels of mask within width texels of its edge (the garment's edges and seams)."""
    inner = mask.copy()
    for _ in range(width):
        inner = inner & np.roll(inner, 1, 0) & np.roll(inner, -1, 0) & np.roll(inner, 1, 1) & np.roll(inner, -1, 1)
    return mask & ~inner


def coat(pos, nrm, ao, mask):
    leather = material("leather")
    t = triplanar(leather, pos, nrm, 12.0)
    v = t.mean(-1, keepdims=True) / 128.0
    col = np.zeros((S, S, 3))
    col[mask] = lit((v[mask] * 40.0) * WARM, nrm[mask], ao[mask], gloss=70.0, power=24)
    trim = edges(mask, 2)
    col[trim] = lit(np.repeat(GOLD[None, :], trim.sum(), 0) * 0.8, nrm[trim], ao[trim], gloss=140.0, power=18)
    return col


def pants(pos, nrm, ao, mask):
    t = triplanar(material("webbing"), pos, nrm, 10.0)
    v = t.mean(-1, keepdims=True) / 128.0
    col = np.zeros((S, S, 3))
    col[mask] = lit(v[mask] * 30.0 * np.array([0.98, 1.0, 1.04]), nrm[mask], ao[mask], gloss=25.0)
    return col


def shirt(pos, nrm, ao, mask):
    ribs = line(np.mod(pos[..., 0] * 2.4, 1.0) - 0.5, 0.3)
    col = np.zeros((S, S, 3))
    base = (24.0 + 7.0 * ribs[mask])[:, None] * np.array([1.0, 1.0, 1.02])
    col[mask] = lit(base, nrm[mask], ao[mask], gloss=15.0)
    return col


def skin(pos, nrm, ao, mask):
    sheet = Image.open(HEAD).convert("RGB")
    front_img = np.asarray(sheet.crop(FRONT_BOX), float)
    prof_img = np.asarray(sheet.crop(PROFILE_BOX), float)
    x, y, z = pos[..., 0], pos[..., 1], pos[..., 2]
    (lu, lv), (ru, rv) = FRONT_EYES
    eye_v = (lv + rv) / 2
    sx = (ru - lu) / (HEAD_EYE_RIGHT - HEAD_EYE_LEFT)
    sz = (FRONT_MOUTH_Y - eye_v) / (HEAD_EYE_Z - HEAD_MOUTH_Z)
    mid_x = (HEAD_EYE_RIGHT + HEAD_EYE_LEFT) / 2
    front = sample(front_img, (lu + ru) / 2 - (x - mid_x) * sx, eye_v - (z - HEAD_EYE_Z) * sz)
    su = (PROFILE_NOSE_U - PROFILE_EAR_U) / (HEAD_EAR_Y - HEAD_NOSE_Y)
    sv = (PROFILE_CHIN_V - PROFILE_EYE_V) / (HEAD_EYE_Z - HEAD_CHIN_Z)
    side = sample(prof_img, PROFILE_EAR_U + (HEAD_EAR_Y - y) * su, PROFILE_EYE_V - (z - HEAD_EYE_Z) * sv)
    w = np.clip((-nrm[..., 1] - 0.35) / 0.35, 0, 1) * np.clip((4.4 - np.abs(x - mid_x)) / 1.0, 0, 1)
    img = (w[..., None] * front + (1 - w[..., None]) * side) * (0.92 + 0.08 * np.clip(ao, 0, 1))[..., None]
    # The hands: prosthetics, black carbon with gold seams at the knuckles and joints.
    hand = mask & (z < 15)
    carbon = triplanar(material("carbon"), pos, nrm, 14.0).mean(-1) / 128.0
    seam = line(np.mod(z * 0.9, 1.0) - 0.5, 0.07)
    base = (carbon[hand] * 30.0)[:, None] * np.array([1.0, 1.0, 1.05])
    base = base * (1 - seam[hand][:, None]) + GOLD[None, :] * 0.7 * seam[hand][:, None]
    img[hand] = lit(base, nrm[hand], ao[hand], gloss=120.0, power=26)
    return img


def save_masked_pcx(img, path):
    """A palette whose index 0 (masked: see-through) no texel uses."""
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    q = im.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
    pal = q.getpalette()[:255 * 3]
    idx = np.asarray(q, np.uint8) + 1
    out = Image.fromarray(idx, "P")
    out.putpalette([255, 0, 255] + pal)
    out.save(path)
    return im


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    mech_art.BODY = BODY
    pkg, m = mech_art.load_body()
    R = mech_art.game_frames(pkg, m)[REST]
    va = mech_bake.body_attributes(m, R, [])
    previews = []
    # The coat: slots 1 and 5 share one layout (JC's coat texture is on both).
    p1, n1, a1, k1 = mech_bake.raster(m, R, 1, va)
    p5, n5, a5, k5 = mech_bake.raster(m, R, 5, va)
    pos, nrm, ao = np.where(k5[..., None], p5, p1), np.where(k5[..., None], n5, n1), np.where(k5, a5, a1)
    mask = k1 | k5
    img = np.clip(bleed(coat(pos, nrm, ao, mask), mask, 12), 0, 255)
    previews.append(save_masked_pcx(img, os.path.join(out, "JensenCoat.pcx")))
    for slot, name, paint in ((2, "JensenPants", pants), (4, "JensenShirt", shirt), (0, "JensenSkin", skin)):
        pos, nrm, ao, mask = mech_bake.raster(m, R, slot, va)
        img = np.clip(bleed(paint(pos, nrm, ao, mask), mask, 12), 0, 255)
        previews.append(save_pcx(img, os.path.join(out, name + ".pcx")))
    if len(sys.argv) > 2:
        sheet = Image.new("RGB", (S * len(previews), S))
        for k, im in enumerate(previews):
            sheet.paste(im.convert("RGB"), (k * S, 0))
        sheet.save(sys.argv[2])
    print("wrote JensenCoat, JensenPants, JensenShirt, JensenSkin to", out)


if __name__ == "__main__":
    main()
