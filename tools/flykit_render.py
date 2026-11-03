# The fly kit's motion frames (tools/flykit.py motion) rendered with EEVEE (its fans' blur discs translucent), one PNG a
# frame, from a fixed three-quarter camera that turns to each frame's "look" (it pans after the fly-past), over a faint
# checker floor fading into the distance (so a pan reads as speed). A frame with several moments ("subs": the fly-past's
# shutter) is the mean of their renders (motion blur). A frame may also give (tools/flykit_swarm.py) several OBJs, the
# camera's place ("eye") and lens, flashes ("fx": x, y, z, radius, strength) and scorch marks ("scorch": x, y, radius),
# or be "blank" (black: a picture laid over it later); the spec its "floor_z".
#   blender -b --factory-startup --python tools/flykit_render.py -- <motion.json> <out dir>
# (absolute paths: Blender reads relative ones against no file)
import json, math, os, sys
import bpy
import numpy as np
from mathutils import Vector

src, out = sys.argv[sys.argv.index("--") + 1:][:2]
spec = json.load(open(src))
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE_NEXT"
sc.render.resolution_x, sc.render.resolution_y = 960, 720
sc.eevee.taa_render_samples = 16
sc.world = bpy.data.worlds.new("w")
sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.44, 0.47, 1)
sc.world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
sc.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.lens = 50
cam.data.clip_end = 30000                  # (the fly-past starts some 1400 units out; the floor runs further)
a, e, d = math.radians(35), math.radians(17), 30.0
cam.location = Vector((d * math.cos(e) * math.cos(a), -d * math.cos(e) * math.sin(a), d * math.sin(e) + 1.0))
cam.rotation_euler = (Vector((0, 0, 0.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()

# The floor: 64-unit squares (about 1.2 m) a little darker than the sky, 120 units below the kit, faded to the sky's own
# colour from 300 out to 4000 (its own light: no shading to clash with the sky).
SKY = (0.42 * 0.9, 0.44 * 0.9, 0.47 * 0.9, 1)
bpy.ops.mesh.primitive_plane_add(size=20000, location=(0, 0, spec.get("floor_z", -120)))
floor = bpy.context.object
floor.name = "floor"
FLOOR = bpy.data.materials.new("floor")
FLOOR.use_nodes = True
nt = FLOOR.node_tree
nt.nodes.clear()
tc, ck, cd = nt.nodes.new("ShaderNodeTexCoord"), nt.nodes.new("ShaderNodeTexChecker"), nt.nodes.new("ShaderNodeCameraData")
ck.inputs["Scale"].default_value = 20000 / 64 / 2          # (a checker square is half its period)
ck.inputs["Color1"].default_value = tuple(c * 0.78 for c in SKY[:3]) + (1,)
ck.inputs["Color2"].default_value = tuple(c * 0.9 for c in SKY[:3]) + (1,)
mr, mx = nt.nodes.new("ShaderNodeMapRange"), nt.nodes.new("ShaderNodeMix")
mr.inputs["From Min"].default_value, mr.inputs["From Max"].default_value = 300, 4000
mx.data_type = "RGBA"
col = lambda socks, name: next(x for x in socks if x.name == name and x.type == "RGBA")     # (Mix has one A per type)
col(mx.inputs, "B").default_value = SKY
em, fo = nt.nodes.new("ShaderNodeEmission"), nt.nodes.new("ShaderNodeOutputMaterial")
nt.links.new(tc.outputs["UV"], ck.inputs["Vector"])
nt.links.new(cd.outputs["View Distance"], mr.inputs["Value"])
nt.links.new(mr.outputs["Result"], mx.inputs["Factor"])
nt.links.new(ck.outputs["Color"], col(mx.inputs, "A"))
nt.links.new(col(mx.outputs, "Result"), em.inputs["Color"])
nt.links.new(em.outputs[0], fo.inputs[0])
floor.data.materials.append(FLOOR)

# A studio backdrop instead (the user, 2026-10-30: "a solid color" behind the kit): no floor, the sky one flat colour.
if spec.get("studio"):
    floor.hide_render = True
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (*spec["studio"], 1)
    sc.world.node_tree.nodes["Background"].inputs[1].default_value = 1.0

# A game map instead (tools/ue1map.py): its level once, kept every frame, lit by its own light actors (each a point
# light of its colour, cut off at its game reach; power by its brightness and reach); no floor, no sky haze, no sun.
KEEP = {floor}
if spec.get("map"):
    import colorsys
    mp = json.load(open(spec["map"]))
    bpy.ops.wm.obj_import(filepath=mp["obj"])
    if mp.get("actors"):                                        # (its mesh actors: the statue, trees, crates)
        bpy.ops.wm.obj_import(filepath=mp["actors"])
    for ob in sc.objects:
        if ob.type == "MESH" and ob is not floor:
            KEEP.add(ob)
            for slot in ob.material_slots:                      # (the game filters its textures)
                if slot.material and slot.material.node_tree:
                    for n in slot.material.node_tree.nodes:
                        if n.type == "TEX_IMAGE":
                            n.interpolation = "Linear"
    floor.hide_render = True
    sun.data.energy = spec.get("map_moon", 0.0)                 # (a moon over an outdoor map, if asked: a fill)
    sun.data.color = (0.62, 0.72, 1.0)
    sun.rotation_euler = (math.radians(55), 0, math.radians(-30))
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.012, 0.012, 0.014, 1)
    for k, L in enumerate(mp["lights"]):
        rgb = colorsys.hsv_to_rgb(L["hue"] / 255.0, 1 - L["saturation"] / 255.0, 1.0)
        lt = bpy.data.lights.new("map%d" % k, "POINT")
        lt.color = rgb
        lt.energy = spec.get("map_power", 2.0) * L["brightness"] / 64.0 * L["radius"] ** 2
        lt.shadow_soft_size = 8.0
        lt.use_custom_distance, lt.cutoff_distance = True, L["radius"]
        ob = bpy.data.objects.new("map%d" % k, lt)
        ob.location = L["at"]
        sc.collection.objects.link(ob)
    sc.view_settings.exposure = spec.get("map_exposure", 0.0)

# The fans' blur: glowing streaks, clear where its skin is dark (one material, put on every blur disc).
BLUR = bpy.data.materials.new("FlyKitBlur")
BLUR.use_nodes = True
nt = BLUR.node_tree
nt.nodes.clear()
img = nt.nodes.new("ShaderNodeTexImage")
first = next((p for fr in spec["frames"] for p in (fr if isinstance(fr, list) else [fr])), "")
blur_png = os.path.join(os.path.dirname(os.path.dirname(first)), "flykit_blur.png") if first else ""
if os.path.exists(blur_png):
    img.image = bpy.data.images.load(blur_png)
tr, em, mix = nt.nodes.new("ShaderNodeBsdfTransparent"), nt.nodes.new("ShaderNodeEmission"), nt.nodes.new("ShaderNodeMixShader")
o = nt.nodes.new("ShaderNodeOutputMaterial")
nt.links.new(img.outputs["Color"], em.inputs["Color"])
nt.links.new(img.outputs["Alpha"], mix.inputs[0])
nt.links.new(tr.outputs[0], mix.inputs[1])
nt.links.new(em.outputs[0], mix.inputs[2])
nt.links.new(mix.outputs[0], o.inputs[0])
BLUR.surface_render_method = "BLENDED"
BLUR.use_fake_user = True



def glow(name, rgb, strength, alpha):
    """A material of its own light, see-through by 1 - alpha (a flash, a scorch)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    em, tr, mx, o = (nt.nodes.new(t) for t in ("ShaderNodeEmission", "ShaderNodeBsdfTransparent", "ShaderNodeMixShader",
                                               "ShaderNodeOutputMaterial"))
    em.inputs["Color"].default_value = (*rgb, 1)
    em.inputs["Strength"].default_value = strength
    mx.inputs[0].default_value = alpha
    nt.links.new(tr.outputs[0], mx.inputs[1])
    nt.links.new(em.outputs[0], mx.inputs[2])
    nt.links.new(mx.outputs[0], o.inputs[0])
    m.surface_render_method = "BLENDED"
    return m


def billow(name, smoke, a, seed):
    """A fireball's (white-hot to orange to dark red, by a noise) or smoke's (grey) light, soft at its edges (facing
    away: clear) and torn by the same noise."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    N = lambda t: nt.nodes.new(t)
    tc, nz, ramp, lw, em, tr, mx, o = (N(t) for t in (
        "ShaderNodeTexCoord", "ShaderNodeTexNoise", "ShaderNodeValToRGB", "ShaderNodeLayerWeight", "ShaderNodeEmission",
        "ShaderNodeBsdfTransparent", "ShaderNodeMixShader", "ShaderNodeOutputMaterial"))
    nz.noise_dimensions = "4D"                                   # (its W, the seed, only in 4D)
    nz.inputs["Scale"].default_value = 0.035
    nz.inputs["Detail"].default_value = 6
    nz.inputs["W"].default_value = seed
    els = ramp.color_ramp.elements
    if smoke:
        els[0].color, els[1].color = (0.05, 0.05, 0.05, 1), (0.32, 0.31, 0.3, 1)
    else:                                                        # (not too bright: the view transform whitens it)
        els[0].color, els[1].color = (0.35, 0.03, 0.0, 1), (1.0, 0.78, 0.28, 1)
        els.new(0.45).color = (1.0, 0.32, 0.03, 1)
    em.inputs["Strength"].default_value = 0.6 if smoke else 1.0 + 1.6 * a
    lw.inputs["Blend"].default_value = 0.6
    soft, torn, alpha = N("ShaderNodeMath"), N("ShaderNodeMath"), N("ShaderNodeMath")
    soft.operation, torn.operation, alpha.operation = "SUBTRACT", "MULTIPLY", "MULTIPLY"
    soft.inputs[0].default_value = 1.0
    alpha.inputs[1].default_value = min(1.0, 1.5 * a)
    L = nt.links.new
    L(tc.outputs["Object"], nz.inputs["Vector"])
    L(nz.outputs["Fac"], ramp.inputs["Fac"])
    L(ramp.outputs["Color"], em.inputs["Color"])
    L(lw.outputs["Facing"], soft.inputs[1])
    L(soft.outputs[0], torn.inputs[0])
    L(nz.outputs["Fac"], torn.inputs[1])
    L(torn.outputs[0], alpha.inputs[0])
    L(alpha.outputs[0], mx.inputs[0])
    L(tr.outputs[0], mx.inputs[1])
    L(em.outputs[0], mx.inputs[2])
    L(mx.outputs[0], o.inputs[0])
    m.surface_render_method = "BLENDED"
    return m


def shoot(path, look, png, state=None):
    state = state or {}
    for ob in [x for x in sc.objects if x.type == "MESH" and x not in KEEP]:
        bpy.data.objects.remove(ob, do_unlink=True)
    for ob in [x for x in sc.objects if x.name.startswith("lamp")]:
        bpy.data.objects.remove(ob, do_unlink=True)
    for p in (path if isinstance(path, list) else [path]):
        bpy.ops.wm.obj_import(filepath=p)
    for k, (x, y, z, r, g, b) in enumerate(state.get("lamps", [])):     # a kit's status light: a lamp (no bead:
                                                                        # a bright one renders white, the user's "white dots")
        lt = bpy.data.lights.new("lamp%d" % k, "POINT")
        lt.color, lt.energy, lt.shadow_soft_size = (r, g, b), 20000.0, 1.0
        lt.use_custom_distance, lt.cutoff_distance = True, 260.0
        ob = bpy.data.objects.new("lamp%d" % k, lt)
        ob.location = (x, y, z)
        sc.collection.objects.link(ob)
    if state.get("eye"):
        cam.location = Vector(state["eye"])
    if state.get("lens"):
        cam.data.lens = state["lens"]
    cam.rotation_euler = (Vector(look) - cam.location).to_track_quat("-Z", "Y").to_euler()
    for fx in state.get("fx", []):                              # a fireball or its smoke: five puffs round it
        x, y, z, r, a = fx[:5]
        smoke = len(fx) > 5 and fx[5] == 1
        seed = (x * 0.013 + y * 0.029) % 10
        for i in range(5):
            ang, up = seed * 2.1 + i * 1.257, math.sin(seed + i * 2.3)
            off = Vector((math.cos(ang), math.sin(ang), 0.6 * up)) * r * (0 if i == 0 else 0.4)
            bpy.ops.mesh.primitive_uv_sphere_add(radius=r * (0.75 if i == 0 else 0.5 + 0.08 * (i % 3)),
                                                 location=Vector((x, y, z)) + off, segments=24, ring_count=12)
            bpy.context.object.data.materials.append(billow("smoke" if smoke else "fire", smoke, a, seed + i))
    for x, y, r in state.get("scorch", []):
        bpy.ops.mesh.primitive_circle_add(radius=r, location=(x, y, spec.get("floor_z", -120) + 0.6), vertices=24, fill_type="NGON")
        bpy.context.object.data.materials.append(glow("scorch", (0.02, 0.02, 0.02), 1, 0.55))
    for ob in sc.objects:
        if ob.type != "MESH" or ob in KEEP:
            continue
        for slot in ob.material_slots:
            m = slot.material
            if m is None:
                continue
            if m.name.startswith("blur"):
                slot.material = BLUR
            elif m.node_tree:
                for n in m.node_tree.nodes:
                    if n.type == "TEX_IMAGE":
                        n.interpolation = "Closest"
    sc.render.filepath = png
    bpy.ops.render.render(write_still=True)


subs = spec.get("subs") or [None] * len(spec["frames"])
for k, path in enumerate(spec["frames"]):
    png = os.path.join(out, "r%04d.png" % k)
    if spec["states"][k].get("blank"):
        im = bpy.data.images.new("blank", sc.render.resolution_x, sc.render.resolution_y)
        im.pixels.foreach_set(np.tile(np.array([0, 0, 0, 1], np.float32), sc.render.resolution_x * sc.render.resolution_y))
        im.filepath_raw, im.file_format = png, "PNG"
        im.save()
        bpy.data.images.remove(im)
    elif not subs[k]:
        shoot(path, spec["states"][k].get("look", (0, 0, 0.5)), png, spec["states"][k])
    else:
        acc = None
        for q, sub in enumerate(subs[k]):
            tmp = os.path.join(out, "sub%d.png" % q)
            shoot(sub["obj"], sub["look"], tmp)
            im = bpy.data.images.load(tmp)
            px = np.empty(len(im.pixels), np.float32)
            im.pixels.foreach_get(px)
            acc = px if acc is None else acc + px
            bpy.data.images.remove(im)
        im = bpy.data.images.new("mean", sc.render.resolution_x, sc.render.resolution_y, alpha=True)
        im.pixels.foreach_set(acc / len(subs[k]))
        im.filepath_raw, im.file_format = png, "PNG"
        im.save()
        bpy.data.images.remove(im)
    if k % 20 == 19:
        bpy.ops.outliner.orphans_purge(do_recursive=True)
print("rendered", len(spec["frames"]))
