# Blender: the arm gun (tools/mech_storm.py) in its poses into one sheet: textured, unlit (the skins
# carry their own light), nearest-texel sampling as the game draws them.
# blender -b --factory-startup --python tools/blender_storm.py -- <out.png> <on.obj> <spin.obj> <under.obj> <reload.obj>
import bpy, sys
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out, objs = args[0], args[1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
poses = []
for path in objs:
    before = set(bpy.data.objects)
    bpy.ops.wm.obj_import(filepath=path, forward_axis="Y", up_axis="Z")
    poses.append([o for o in bpy.data.objects if o not in before])
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
scene.render.resolution_x, scene.render.resolution_y = 560, 400
scene.world = bpy.data.worlds.new("w")
scene.world.color = (0.05, 0.05, 0.055)
cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
centre = Vector((10.0, 0.0, 2.0))
fp = (Vector((-12.0, 9.0, 11.0)), Vector((40.0, -1.0, 2.0)))       # as the Mech sees it
# (pose, direction to the camera or None for fp, distance, target, lens): on the hand from the left, three-
# quarter front, the muzzle, first person; mid-spin; under the forearm; the reload, first person and aside.
shots = [(0, (0, 1, 0.1), 55, centre, 50), (0, (0.9, -0.8, 0.45), 45, centre, 50),
         (0, (1, 0, 0.05), 14, Vector((21.0, 0, 4.9)), 50), (0, None, 0, None, 22),
         (1, (0.3, 1, 0.3), 48, centre, 50), (2, (0.6, 0.9, -0.3), 48, centre, 50),
         (3, None, 0, None, 22), (3, (-0.5, 1, 0.6), 50, centre, 50)]
tmp = []
for k, (pose, d, where, target, lens) in enumerate(shots):
    for i, objs_ in enumerate(poses):
        for o in objs_:
            o.hide_render = i != pose
    cam_data.lens = lens
    if d is None:
        cam.location, target = fp
    else:
        cam.location = target + Vector(d).normalized() * where
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    p = out + ".%d.png" % k
    scene.render.filepath = p
    bpy.ops.render.render(write_still=True)
    tmp.append(p)
imgs = [bpy.data.images.load(p) for p in tmp]
w, h = imgs[0].size
cols, rows = 4, 2
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
