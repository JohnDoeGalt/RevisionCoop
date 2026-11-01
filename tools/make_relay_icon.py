"""Draws src/relay/revcoop.ico: RevCoop.exe's own icon (two linked rings, Revision Co-op's amber on
dark). The window shows Revision's icon when it finds Revision.exe; this one is the file's."""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "src", "relay", "revcoop.ico")
S = 1024  # drawn large, scaled down per size

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rounded_rectangle((32, 32, S - 32, S - 32), radius=180, fill=(24, 27, 33, 255), outline=(70, 76, 88, 255), width=16)
amber, white = (255, 170, 51, 255), (236, 240, 245, 255)
r, w, cy = 230, 78, S // 2
# Two rings, linked: the left one's right side passes over the right one.
d.ellipse((S // 2 - 120 - r, cy - r, S // 2 - 120 + r, cy + r), outline=white, width=w)
d.ellipse((S // 2 + 120 - r, cy - r, S // 2 + 120 + r, cy + r), outline=amber, width=w)
d.arc((S // 2 - 120 - r, cy - r, S // 2 - 120 + r, cy + r), start=300, end=360, fill=white, width=w)

img.save(OUT, sizes=[(256, 256), (64, 64), (48, 48), (32, 32), (24, 24), (16, 16)])
print(OUT)
