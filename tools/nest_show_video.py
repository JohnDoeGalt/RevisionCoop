# The kit nests' show on video (CoopTestNestShow, docs/FLY_KITS.md "Kit nests"): tools/flykit_show_video.py's cut,
# captions and soundtrack (the nests' kits buzz and their payloads go off as the Mech's own do), its own end card.
#   python -I tools/nest_show_video.py <NetHost.log> <frames dir> <sounds dir> <out.mp4> [music.ogg]
import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flykit_show_video

if __name__ == "__main__":
    flykit_show_video.main(ending="Corvane's kit nests and the SP-2 Burr  ·  in-game footage",
                           grade="eq=gamma=1.3:saturation=1.0:contrast=1.06")   # (a white lamp on each scene: less lift)
