# Blender: the blade arm (tools/blade_arms.py) from four sides into one sheet: textured, unlit (the skins carry their
# own light), nearest-texel sampling as the game draws them.
# blender -b --factory-startup --python tools/blender_arm.py -- <out.png> <arm.obj>
import bpy, sys
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out, obj = args[0], args[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.wm.obj_import(filepath=obj, forward_axis="Y", up_axis="Z")
for img in bpy.data.images:
    img.alpha_mode = "NONE"
for mat in bpy.data.materials:
    if mat.use_nodes:
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE":
                n.interpolation = "Closest"
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "FLAT"
scene.display.shading.color_type = "TEXTURE"
scene.render.resolution_x, scene.render.resolution_y = 640, 420
scene.world = bpy.data.worlds.new("w")
scene.world.color = (0.30, 0.31, 0.33)
cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
centre = Vector((14.0, 0.0, 0.5))
# (direction to the camera, distance, target): three-quarter from above and behind (as its owner sees it), the side,
# the fist from the front, from above.
shots = [((-0.8, -0.55, 0.75), 30, centre), ((0.05, 1, 0.15), 34, centre), ((1, -0.35, 0.2), 16, Vector((17.0, 0, 0.0))),
         ((0.1, 0.05, 1), 36, centre)]
tmp = []
for k, (d, dist, target) in enumerate(shots):
    cam_data.lens = 50
    cam.location = target + Vector(d).normalized() * dist
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    p = out + ".%d.png" % k
    scene.render.filepath = p
    bpy.ops.render.render(write_still=True)
    tmp.append(p)
imgs = [bpy.data.images.load(p) for p in tmp]
w, h = imgs[0].size
cols, rows = 2, 2
sheet = bpy.data.images.new("sheet", w * cols, h * rows)
px = [0.0] * (w * cols * h * rows * 4)
for k, im in enumerate(imgs):
    src = list(im.pixels)
    cx, cy = k % cols, rows - 1 - k // cols
    for y in range(h):
        dst = ((cy * h + y) * w * cols + cx * w) * 4
        px[dst:dst + w * 4] = src[y * w * 4:(y + 1) * w * 4]
sheet.pixels = px
sheet.filepath_raw = out
sheet.file_format = "PNG"
sheet.save()
