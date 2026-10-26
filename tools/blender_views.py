# Renders OBJ files from the front, side, back and three-quarter (Workbench, flat light) into one sheet.
# blender -b --factory-startup --python tools/blender_views.py -- <out.png> <a.obj> [b.obj ...]
# Each OBJ may carry a colour after a comma: part.obj,0.8,0.2,0.1
import bpy, sys, math, mathutils

args = sys.argv[sys.argv.index("--") + 1:]
out, objs = args[0], args[1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
for spec in objs:
    path, *col = spec.split(",")
    bpy.ops.wm.obj_import(filepath=path, forward_axis="Y", up_axis="Z")
    for o in bpy.context.selected_objects:
        if col:
            mat = bpy.data.materials.new("c")
            mat.diffuse_color = (float(col[0]), float(col[1]), float(col[2]), 1)
            o.data.materials.clear()
            o.data.materials.append(mat)
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_cavity = True
scene.render.resolution_x, scene.render.resolution_y = 420, 640
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new("w")
scene.world.color = (0.12, 0.12, 0.13)
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = 110
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
views = [("front -Y", 0), ("right side +X", 90), ("back +Y", 180), ("three-quarter", 35)]
import os
tmp = []
for name, yaw in views:
    a = math.radians(yaw)
    cam.location = (200 * math.sin(a), -200 * math.cos(a), 0)
    cam.rotation_euler = (math.radians(90), 0, a)
    p = out + ".%d.png" % yaw
    scene.render.filepath = p
    bpy.ops.render.render(write_still=True)
    tmp.append((name, p))
# Sheet: side by side.
imgs = [bpy.data.images.load(p) for _, p in tmp]
w, h = imgs[0].size
sheet = bpy.data.images.new("sheet", w * len(imgs), h)
px = [0.0] * (w * len(imgs) * h * 4)
for k, im in enumerate(imgs):
    src = list(im.pixels)
    for y in range(h):
        row = y * w * 4
        dst = (y * w * len(imgs) + k * w) * 4
        px[dst:dst + w * 4] = src[row:row + w * 4]
sheet.pixels = px
sheet.filepath_raw = out
sheet.file_format = "PNG"
sheet.save()
for _, p in tmp:
    os.remove(p)
print("sheet", out, [n for n, _ in views])
