"""A contact sheet of render folders (docs/ASSETS.md: look at what exists before making art).
    python -I tools/contact_sheet.py <out.png> <every nth> <columns> <tile width> <dir> [<dir> ...]
"""
import os, sys
from PIL import Image

out, step, cols, tw = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
fs = []
for d in sys.argv[5:]:
    ff = sorted(f for f in os.listdir(d) if f.endswith(".png") or f.endswith(".jpg"))
    fs += [os.path.join(d, f) for f in ff[::step]]
ims = []
for f in fs:
    im = Image.open(f).convert("RGB")
    w, h = im.size
    ims.append(im.resize((tw, int(tw * h / w))))
th = max(i.size[1] for i in ims)
rows = (len(ims) + cols - 1) // cols
S = Image.new("RGB", (cols * tw, rows * th))
for i, im in enumerate(ims):
    S.paste(im, ((i % cols) * tw, (i // cols) * th))
S.save(out)
print(len(ims), "tiles", S.size)
