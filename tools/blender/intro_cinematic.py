# Cinematique d'introduction en 3D, rendue en pixel art (640x360, sans lissage, couleurs
# posterisees). A lancer avec Blender 5.x, en trois etapes (IMAGES = un dossier temporaire) :
#
#   1. construire et animer les scenes, un .blend par decor dans tools/blender/scenes/ :
#        blender -b -P tools/blender/intro_cinematic.py -- build all
#   2. rendre les images de chaque scene (chambre, voix, soucis, horizon, fenetre, chute) :
#        blender -b tools/blender/scenes/intro_chambre.blend -o IMAGES/chambre/#### -a
#      et l'image unique des deux scenes de l'ecran-titre (-f 1 au lieu de -a), a copier en
#      assets/cinematics/intro/titre_fond.png et titre_reveur.png ;
#   3. monter les images en une video Ogg Theora par plan (le format que lit Godot) :
#        blender -b -P tools/blender/intro_cinematic.py -- assemble IMAGES assets/cinematics/intro all
#
# Les durees des plans et le texte restent ceux de scripts/story/intro.gd et scripts/story.gd.
# Le dossier contient un .gdignore : sans lui, Godot essaie d'importer les .blend comme scenes 3D.
# Reperes : X vers la droite, Y vers le fond (la camera regarde vers +Y), Z vers le haut, en metres.

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

FPS = 24
RES = (640, 360)
HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
SCENES_DIR = os.path.join(HERE, "scenes")
TAU = math.tau


def F(t):
    """Seconde -> numero d'image (l'image 1 est t = 0)."""
    return 1 + t * FPS


# --- Outils : scene, materiaux, maillages, cles ------------------------------------------

def reset(name, duration):
    # On vide le fichier a la main (sans recharger les reglages d'usine : les add-ons restent en place).
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for blocks in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras, bpy.data.node_groups,
                   bpy.data.worlds, bpy.data.actions, bpy.data.curves, bpy.data.fonts):
        for block in list(blocks):
            blocks.remove(block)
    _mats.clear()
    scene = bpy.context.scene
    scene.name = name
    scene.frame_start = 1
    scene.frame_end = int(round(duration * FPS))
    r = scene.render
    r.fps = FPS
    r.resolution_x, r.resolution_y = RES
    r.resolution_percentage = 100
    r.engine = "BLENDER_EEVEE"
    r.filter_size = 0.01  # pas de lissage : des pixels nets
    r.image_settings.media_type = "IMAGE"
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGB"
    r.film_transparent = False
    e = scene.eevee
    e.taa_render_samples = 24
    e.use_shadows = True
    e.use_volumetric_shadows = True
    e.volumetric_samples = 96
    e.volumetric_tile_size = "4"
    e.volumetric_start = 0.1
    e.volumetric_end = 40.0
    try:
        scene.view_settings.view_transform = "Standard"
        scene.view_settings.look = "None"
    except TypeError:
        pass
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    scene.world = world
    set_world((0.05, 0.06, 0.17), 1.0)
    return scene


def world_background():
    return bpy.context.scene.world.node_tree.nodes["Background"]


def set_world(color, strength):
    bg = world_background()
    bg.inputs["Color"].default_value = (*color, 1)
    bg.inputs["Strength"].default_value = strength


def hexc(code):
    """'#RRGGBB' (sRGB) -> couleur lineaire."""
    code = code.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(code[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


_mats = {}


def mat(name, color, emission=0.0, emit_color=None, rough=1.0):
    """Materiau mat (pas de reflet), avec une emission eventuelle. color : '#hex' ou triplet lineaire."""
    if name in _mats and _mats[name].name in bpy.data.materials:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    rgb = hexc(color) if isinstance(color, str) else color
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Specular IOR Level"].default_value = 0.0
    if emission > 0.0:
        e = hexc(emit_color) if isinstance(emit_color, str) else (emit_color or rgb)
        b.inputs["Emission Color"].default_value = (*e, 1)
        b.inputs["Emission Strength"].default_value = emission
    _mats[name] = m
    return m


def bsdf(material):
    return material.node_tree.nodes["Principled BSDF"]


def emission_socket(material):
    return bsdf(material).inputs["Emission Strength"]


def stripes_mat(name, color_a, color_b, freq, axis=2):
    """Rayures le long d'un axe de l'objet (pyjama)."""
    m = mat(name, color_a)
    nt = m.node_tree
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = freq
    frac = nt.nodes.new("ShaderNodeMath")
    frac.operation = "FRACT"
    gt = nt.nodes.new("ShaderNodeMath")
    gt.operation = "GREATER_THAN"
    gt.inputs[1].default_value = 0.5
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = (*hexc(color_a), 1)
    mix.inputs["B"].default_value = (*hexc(color_b), 1)
    nt.links.new(coord.outputs["Object"], sep.inputs[0])
    nt.links.new(sep.outputs[axis], mul.inputs[0])
    nt.links.new(mul.outputs[0], frac.inputs[0])
    nt.links.new(frac.outputs[0], gt.inputs[0])
    nt.links.new(gt.outputs[0], mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], bsdf(m).inputs["Base Color"])
    return m


def wallpaper_mat():
    """Papier peint bleu nuit seme de petites etoiles claires."""
    m = mat("wallpaper", "#20264f")
    nt = m.node_tree
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 2.6
    vor.inputs["Randomness"].default_value = 0.85
    lt = nt.nodes.new("ShaderNodeMath")
    lt.operation = "LESS_THAN"
    lt.inputs[1].default_value = 0.06
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = (*hexc("#20264f"), 1)
    mix.inputs["B"].default_value = (*hexc("#7f8ad0"), 1)
    nt.links.new(geo.outputs["Position"], vor.inputs["Vector"])
    nt.links.new(vor.outputs["Distance"], lt.inputs[0])
    nt.links.new(lt.outputs[0], mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], bsdf(m).inputs["Base Color"])
    return m


def planks_mat():
    """Parquet sombre : des lames le long de X, chacune d'une teinte un peu differente."""
    m = mat("planks", "#3a2a2c")
    nt = m.node_tree
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = 3.2
    floor = nt.nodes.new("ShaderNodeMath")
    floor.operation = "FLOOR"
    noise = nt.nodes.new("ShaderNodeTexWhiteNoise")
    noise.noise_dimensions = "1D"
    frac = nt.nodes.new("ShaderNodeMath")
    frac.operation = "FRACT"
    edge = nt.nodes.new("ShaderNodeMath")
    edge.operation = "LESS_THAN"
    edge.inputs[1].default_value = 0.06
    tone = nt.nodes.new("ShaderNodeMix")
    tone.data_type = "RGBA"
    tone.inputs["A"].default_value = (*hexc("#33262a"), 1)
    tone.inputs["B"].default_value = (*hexc("#4a3634"), 1)
    gap = nt.nodes.new("ShaderNodeMix")
    gap.data_type = "RGBA"
    gap.inputs["B"].default_value = (*hexc("#1c1418"), 1)
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    nt.links.new(sep.outputs[1], mul.inputs[0])
    nt.links.new(mul.outputs[0], floor.inputs[0])
    nt.links.new(floor.outputs[0], noise.inputs["W"])
    nt.links.new(noise.outputs["Value"], tone.inputs["Factor"])
    nt.links.new(mul.outputs[0], frac.inputs[0])
    nt.links.new(frac.outputs[0], edge.inputs[0])
    nt.links.new(tone.outputs["Result"], gap.inputs["A"])
    nt.links.new(edge.outputs[0], gap.inputs["Factor"])
    nt.links.new(gap.outputs["Result"], bsdf(m).inputs["Base Color"])
    return m


def sky_mat(name, top, bottom, strength=1.0, axis_span=8.0, axis=2):
    """Ciel emissif : degrade vertical (Z de l'objet), insensible aux lumieres."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.remove(nt.nodes["Principled BSDF"])
    out = nt.nodes["Material Output"]
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.name = "Emission"
    emit.inputs["Strength"].default_value = strength
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    rng = nt.nodes.new("ShaderNodeMapRange")
    rng.inputs["From Min"].default_value = -axis_span / 2
    rng.inputs["From Max"].default_value = axis_span / 2
    mix = nt.nodes.new("ShaderNodeMix")
    mix.name = "Gradient"
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = (*hexc(bottom), 1)
    mix.inputs["B"].default_value = (*hexc(top), 1)
    nt.links.new(coord.outputs["Object"], sep.inputs[0])
    nt.links.new(sep.outputs[axis], rng.inputs["Value"])
    nt.links.new(rng.outputs["Result"], mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], emit.inputs["Color"])
    nt.links.new(emit.outputs[0], out.inputs["Surface"])
    return m


def glow_mat(name, color, strength):
    """Emission pure (veilleuse, chiffres du reveil, lune, poussieres)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.remove(nt.nodes["Principled BSDF"])
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.name = "Emission"
    emit.inputs["Color"].default_value = (*(hexc(color) if isinstance(color, str) else color), 1)
    emit.inputs["Strength"].default_value = strength
    nt.links.new(emit.outputs[0], nt.nodes["Material Output"].inputs["Surface"])
    return m


def glow_strength(material):
    return material.node_tree.nodes["Emission"].inputs["Strength"]


def obj_from_bm(name, bm, material=None, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), smooth=False, parent=None):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    if smooth:
        for poly in mesh.polygons:
            poly.use_smooth = True
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = rot
    ob.scale = scale
    if material:
        mesh.materials.append(material)
    if parent:
        ob.parent = parent
    return ob


def box(name, size, loc, material, rot=(0, 0, 0), parent=None, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    ob = obj_from_bm(name, bm, material, loc, rot, size, parent=parent)
    if bevel > 0.0:
        mod = ob.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        for poly in ob.data.polygons:
            poly.use_smooth = True
    return ob


def sphere(name, radius, loc, material, scale=(1, 1, 1), parent=None, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=14, radius=radius)
    return obj_from_bm(name, bm, material, loc, rot, scale, smooth=True, parent=parent)


def cyl(name, radius, depth, loc, material, rot=(0, 0, 0), parent=None, radius_top=None, segments=20, scale=(1, 1, 1), caps=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=caps, segments=segments, radius1=radius,
                          radius2=radius if radius_top is None else radius_top, depth=depth)
    return obj_from_bm(name, bm, material, loc, rot, scale, smooth=True, parent=parent)


def star(name, outer, inner, thickness, loc, material, rot=(0, 0, 0), parent=None, points=5):
    """Etoile aux branches arrondies, dans le plan XZ, face vers -Y."""
    bm = bmesh.new()
    verts = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = math.pi / 2 + i * math.pi / points
        verts.append(bm.verts.new((r * math.cos(a), 0, r * math.sin(a))))
    bm.faces.new(verts)
    ob = obj_from_bm(name, bm, material, loc, rot, parent=parent)
    solid = ob.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = thickness
    solid.offset = 0.0
    bevel = ob.modifiers.new("Bevel", "BEVEL")
    bevel.width = thickness * 0.45
    bevel.segments = 3
    sub = ob.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = sub.render_levels = 2
    for poly in ob.data.polygons:
        poly.use_smooth = True
    return ob


def empty(name, loc=(0, 0, 0), parent=None):
    ob = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    if parent:
        ob.parent = parent
    return ob


def light(name, kind, loc, color, energy, parent=None, **props):
    data = bpy.data.lights.new(name, kind)
    data.color = hexc(color) if isinstance(color, str) else color
    data.energy = energy
    data.volume_factor = props.pop("volume_factor", 0.0)  # part de cette lumiere visible dans la brume
    for key, value in props.items():
        setattr(data, key, value)
    ob = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    if parent:
        ob.parent = parent
    return ob


def aim(ob, target):
    """Oriente -Z de l'objet (axe de visee des lumieres et cameras) vers un point."""
    direction = Vector(target) - ob.location
    ob.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def camera(lens=35.0):
    data = bpy.data.cameras.new("Camera")
    data.lens = lens
    data.clip_start = 0.05
    data.clip_end = 400.0
    cam = bpy.data.objects.new("Camera", data)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    target = empty("CameraTarget")
    track = cam.constraints.new("TRACK_TO")
    track.target = target
    track.track_axis = "TRACK_NEGATIVE_Z"
    track.up_axis = "UP_Y"
    return cam, target


def K(target, prop, t, value, index=-1):
    """Pose une cle : target.prop = value au temps t (secondes)."""
    if index >= 0:
        current = list(getattr(target, prop))
        current[index] = value
        setattr(target, prop, current)
    else:
        setattr(target, prop, value)
    target.keyframe_insert(prop, frame=F(t), index=index)


def KS(socket, t, value):
    """Cle sur la valeur d'une prise de noeud (force d'emission, de fond...)."""
    socket.default_value = value
    socket.keyframe_insert("default_value", frame=F(t))


def fcurves(idblock):
    ad = idblock.animation_data
    if not ad or not ad.action:
        return
    for layer in ad.action.layers:
        for strip in layer.strips:
            bag = strip.channelbag(ad.action_slot)
            if bag:
                yield from bag.fcurves


def interpolation(idblock, mode):
    """Change l'interpolation de toutes les cles d'un bloc ('LINEAR', 'CONSTANT', 'BEZIER')."""
    for curve in fcurves(idblock):
        for point in curve.keyframe_points:
            point.interpolation = mode


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def pixel_look(steps=22.0, bloom=True):
    """Compositeur : un peu de halo sur les lumieres, puis couleurs posterisees (aplats de pixel art)."""
    scene = bpy.context.scene
    tree = bpy.data.node_groups.new("PixelLook", "CompositorNodeTree")
    tree.interface.new_socket(name="Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    layers = tree.nodes.new("CompositorNodeRLayers")
    out = tree.nodes.new("NodeGroupOutput")
    last = layers.outputs["Image"]
    if bloom:
        glare = tree.nodes.new("CompositorNodeGlare")
        glare.name = "Glare"
        for key, value in (("Type", "Bloom"), ("Quality", "High"), ("Threshold", 1.3), ("Strength", 0.3), ("Size", 0.2), ("Saturation", 1.0)):
            if key in glare.inputs:
                try:
                    glare.inputs[key].default_value = value
                except TypeError:
                    pass
        if hasattr(glare, "glare_type"):
            glare.glare_type = "BLOOM"
        tree.links.new(last, glare.inputs["Image"])
        last = glare.outputs["Image"]
    # On posterise en espace "ecran" (gamma), sinon les tons sombres sont ecrases en noir.
    to_display = tree.nodes.new("ShaderNodeGamma")
    to_display.inputs["Gamma"].default_value = 1.0 / 2.2
    poster = tree.nodes.new("CompositorNodePosterize")
    poster.inputs["Steps"].default_value = steps
    to_linear = tree.nodes.new("ShaderNodeGamma")
    to_linear.inputs["Gamma"].default_value = 2.2
    tree.links.new(last, to_display.inputs["Color"])
    tree.links.new(to_display.outputs["Color"], poster.inputs["Image"])
    tree.links.new(poster.outputs["Image"], to_linear.inputs["Color"])
    tree.links.new(to_linear.outputs["Color"], out.inputs["Image"])
    scene.compositing_node_group = tree
    return tree


def fog(size, loc, density, anisotropy=0.4):
    """Brume legere : rend visibles les rayons de lune et les halos."""
    m = bpy.data.materials.new("fog")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.remove(nt.nodes["Principled BSDF"])
    scatter = nt.nodes.new("ShaderNodeVolumeScatter")
    scatter.name = "Scatter"
    scatter.inputs["Density"].default_value = density
    scatter.inputs["Anisotropy"].default_value = anisotropy
    nt.links.new(scatter.outputs[0], nt.nodes["Material Output"].inputs["Volume"])
    return box("Fog", size, loc, m)


# --- Le reveur ------------------------------------------------------------------------------

SKIN = "#f2c9a4"
HAIR = "#6b4a36"
CAP = "#7b55c9"
PJ_A = "#3f5fb8"
PJ_B = "#eef0fa"
SLIPPER = "#d9534f"


def dreamer(pose="standing", eyes="closed"):
    """Le reveur : bonnet violet a pompon, pyjama raye, chaussons rouges. Renvoie un dictionnaire
    de ses parties ; 'root' est a ses pieds (ou au bassin pour 'lying'). Taille debout : 1,15 m."""
    skin = mat("skin", SKIN)
    pj = stripes_mat("pajama", PJ_A, PJ_B, 9.0, axis=2)
    pj_arm = stripes_mat("pajama_arm", PJ_A, PJ_B, 9.0, axis=2)
    root = empty("Dreamer")
    parts = {"root": root}
    torso = sphere("Torso", 0.2, (0, 0, 0.55), pj, scale=(1.0, 0.82, 1.25), parent=root)
    parts["torso"] = torso
    head = empty("HeadPivot", (0, 0, 0.82), parent=root)
    parts["head"] = head
    sphere("Head", 0.19, (0, 0, 0.1), skin, parent=head)
    sphere("Hair", 0.2, (0, 0.03, 0.12), mat("hair", HAIR), scale=(1.0, 0.95, 0.95), parent=head)
    sphere("EarL", 0.045, (-0.185, 0.0, 0.08), skin, parent=head)
    sphere("EarR", 0.045, (0.185, 0.0, 0.08), skin, parent=head)
    sphere("Nose", 0.028, (0, -0.19, 0.07), mat("nose", "#e8b08c"), parent=head)
    sphere("CheekL", 0.04, (-0.105, -0.155, 0.03), mat("cheek", "#f0a3a0"), scale=(1, 0.4, 0.8), parent=head)
    sphere("CheekR", 0.04, (0.105, -0.155, 0.03), mat("cheek", "#f0a3a0"), scale=(1, 0.4, 0.8), parent=head)
    dark = mat("eye", "#2a1c1c")
    if eyes == "open":
        sphere("EyeL", 0.026, (-0.07, -0.172, 0.11), dark, scale=(1, 0.5, 1.25), parent=head)
        sphere("EyeR", 0.026, (0.07, -0.172, 0.11), dark, scale=(1, 0.5, 1.25), parent=head)
    else:
        sphere("EyeL", 0.03, (-0.07, -0.176, 0.1), dark, scale=(1.15, 0.4, 0.28), parent=head)
        sphere("EyeR", 0.03, (0.07, -0.176, 0.1), dark, scale=(1.15, 0.4, 0.28), parent=head)
    # Bonnet : une calotte, un cone qui retombe sur le cote, le pompon au bout.
    cap = mat("cap", CAP)
    sphere("CapBase", 0.205, (0, 0.02, 0.17), cap, scale=(1.03, 1.0, 0.72), parent=head)
    cyl("CapBand", 0.2, 0.06, (0, 0.01, 0.2), mat("cap_band", "#5d3fa6"), parent=head, scale=(1.04, 1.02, 1), rot=(math.radians(-8), 0, 0))
    cyl("CapCone", 0.17, 0.34, (0.1, 0.03, 0.4), cap, rot=(0, math.radians(38), 0), parent=head, radius_top=0.05)
    cyl("CapTip", 0.055, 0.2, (0.27, 0.03, 0.47), cap, rot=(0, math.radians(100), 0), parent=head, radius_top=0.03)
    sphere("Pompom", 0.065, (0.38, 0.03, 0.43), mat("pompom", "#f6f2ff"), parent=head)
    # Bras et jambes : un pivot a l'epaule / a la hanche, le membre pend vers -Z.
    for side, x in (("L", -1), ("R", 1)):
        arm = empty("Arm" + side, (x * 0.19, 0, 0.7), parent=root)
        cyl("Sleeve" + side, 0.062, 0.3, (0, 0, -0.15), pj_arm, parent=arm)
        sphere("Hand" + side, 0.062, (0, 0, -0.32), skin, parent=arm)
        parts["arm" + side] = arm
        leg = empty("Leg" + side, (x * 0.09, 0, 0.36), parent=root)
        cyl("Trouser" + side, 0.075, 0.3, (0, 0, -0.15), pj_arm, parent=leg)
        sphere("Slipper" + side, 0.08, (0, -0.04, -0.33), mat("slipper", SLIPPER), scale=(0.95, 1.5, 0.6), parent=leg)
        parts["leg" + side] = leg
    if pose == "standing":
        parts["armL"].rotation_euler = (0, math.radians(-10), 0)
        parts["armR"].rotation_euler = (0, math.radians(10), 0)
    elif pose == "sitting":
        for side in ("L", "R"):
            parts["leg" + side].rotation_euler = (math.radians(-80), 0, 0)
            parts["arm" + side].rotation_euler = (math.radians(-14), 0, 0)
    elif pose == "falling":
        parts["armL"].rotation_euler = (math.radians(20), math.radians(-150), 0)
        parts["armR"].rotation_euler = (math.radians(-15), math.radians(140), 0)
        parts["legL"].rotation_euler = (math.radians(25), math.radians(-28), 0)
        parts["legR"].rotation_euler = (math.radians(-30), math.radians(24), 0)
    return parts


# --- La chambre -----------------------------------------------------------------------------

VEILLEUSE = Vector((2.72, -0.07, 0.62))
WINDOW = (0.5, 2.1, 1.15, 2.45)  # x0, x1, z0, z1
DOOR = (-2.75, -1.85, 2.05)  # x0, x1, hauteur
PILLOW = Vector((-1.75, -1.5, 0.78))


def seven_segment(name, digit, loc, size, material, parent):
    """Chiffre a sept segments, face vers -Y."""
    w, h = size
    t = w * 0.22
    segs = {
        "a": ((0, h / 2), (w, t)), "g": ((0, 0), (w, t)), "d": ((0, -h / 2), (w, t)),
        "f": ((-w / 2, h / 4), (t, h / 2)), "b": ((w / 2, h / 4), (t, h / 2)),
        "e": ((-w / 2, -h / 4), (t, h / 2)), "c": ((w / 2, -h / 4), (t, h / 2)),
    }
    lit = {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd",
           "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg"}[digit]
    for key in lit:
        (dx, dz), (sx, sz) = segs[key]
        box("%s_%s" % (name, key), (sx, 0.004, sz), (loc[0] + dx, loc[1], loc[2] + dz), material, parent=parent)


def chambre(towers_outside=False):
    """La chambre du reveur, la nuit. Renvoie les elements a animer."""
    c = {}
    wall = wallpaper_mat()
    wood = mat("wood", "#6b4630")
    wood_dark = mat("wood_dark", "#4c3023")
    x0, x1, z0, z1 = WINDOW
    dx0, dx1, dh = DOOR
    # Sol, murs (le mur du fond est decoupe autour de la porte et de la fenetre).
    box("Floor", (9, 9, 0.2), (0, -3.5, -0.1), planks_mat())
    box("Skirting", (6.4, 0.04, 0.16), (0, -0.02, 0.08), mat("skirting", "#2c2a52"))
    for name, (ax, bx, az, bz) in {
        "WallLeft": (-3.2, dx0, 0, 3.2), "WallDoorTop": (dx0, dx1, dh, 3.2), "WallMid": (dx1, x0, 0, 3.2),
        "WallWinBottom": (x0, x1, 0, z0), "WallWinTop": (x0, x1, z1, 3.2), "WallRight": (x1, 3.2, 0, 3.2),
    }.items():
        box(name, (bx - ax, 0.2, bz - az), ((ax + bx) / 2, 0.1, (az + bz) / 2), wall)
    box("SideLeft", (0.2, 7, 3.2), (-3.3, -3.4, 1.6), wall)
    box("SideRight", (0.2, 7, 3.2), (3.3, -3.4, 1.6), wall)
    box("Ceiling", (6.8, 7.2, 0.2), (0, -3.4, 3.3), mat("ceiling", "#171a38"))
    # Fenetre : cadre en bois, croisillons, tringle et rideaux violets a plis.
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    for name, size, loc in (
        ("FrameTop", (x1 - x0 + 0.16, 0.26, 0.08), (cx, 0.08, z1 + 0.02)),
        ("FrameBottom", (x1 - x0 + 0.24, 0.34, 0.08), (cx, 0.04, z0 - 0.02)),
        ("FrameL", (0.08, 0.26, z1 - z0), (x0 - 0.02, 0.08, cz)), ("FrameR", (0.08, 0.26, z1 - z0), (x1 + 0.02, 0.08, cz)),
        ("BarV", (0.05, 0.06, z1 - z0), (cx, 0.1, cz)), ("BarH", (x1 - x0, 0.06, 0.05), (cx, 0.1, cz)),
    ):
        bar = box(name, size, loc, wood)
        bar.visible_shadow = not name.startswith("Bar")  # pas de trait d'ombre dans le rayon de lune
    cyl("Rod", 0.03, x1 - x0 + 1.5, (cx, -0.12, z1 + 0.22), mat("rod", "#b89a6a"), rot=(0, math.pi / 2, 0))
    for sx in (-1, 1):
        sphere("RodEnd", 0.055, (cx + sx * (x1 - x0 + 1.5) / 2, -0.12, z1 + 0.22), mat("rod", "#b89a6a"))
        curtain = mat("curtain", "#6a45b8")
        for i in range(5):
            px = (x0 - 0.42 + i * 0.105) if sx < 0 else (x1 + 0.42 - i * 0.105)
            cyl("Curtain", 0.075, 1.95, (px, -0.12 - 0.02 * (i % 2), z1 + 0.2 - 0.975), curtain, radius_top=0.06, segments=10)
    # Dehors : le ciel de nuit, la lune, des nuages qui derivent.
    sky = box("Sky", (40, 0.1, 26), (cx, 14, 3.5), sky_mat("sky", "#141a4a", "#3b2d6e", 1.0, axis_span=1.0))
    c["sky"] = sky
    moon_mat = glow_mat("moon", "#f4f1dc", 3.0)
    c["moon_mat"] = moon_mat
    sphere("Moon", 0.75, (cx + 2.2, 13.0, 6.3), moon_mat)
    cloud_mat = glow_mat("cloud", "#4b4690", 0.9)
    c["cloud_mat"] = cloud_mat
    clouds = empty("Clouds", (0, 12, 0))
    c["clouds"] = clouds
    rng = random.Random(7)
    for i in range(7):
        px = -6 + i * 2.6 + rng.uniform(-0.5, 0.5)
        pz = 3.2 + rng.uniform(-0.6, 2.2)
        for j in range(3):
            sphere("Cloud", 0.55 + rng.uniform(0, 0.3), (px + j * 0.6, rng.uniform(-0.3, 0.3), pz + (0.18 if j == 1 else 0)),
                   cloud_mat, scale=(1.5, 0.6, 0.55), parent=clouds)
    star_mat = glow_mat("stars", "#dfe4ff", 2.5)
    c["star_mat"] = star_mat
    for i in range(46):
        sphere("Star", 0.035, (cx + rng.uniform(-7, 7), 13.5, rng.uniform(1.5, 10)), star_mat)
    if towers_outside:
        c["outside_towers"] = week_towers(empty("OutsideTowers", (cx - 1.5, 11.0, 0.85)), spacing=0.95, scale=0.27, lit=1.6)
        light("OutsideLight", "POINT", (cx + 1.2, 7.8, 2.6), "#cfd4ff", 2600.0, shadow_soft_size=1.0)
        bank = glow_mat("outside_bank", "#5d58a8", 0.9)
        for i in range(12):
            sphere("Bank", 0.55, (cx - 2.2 + i * 0.66, 10.4, 0.85 + 0.12 * (i % 3)), bank, scale=(1.5, 0.6, 0.6))
    # Porte (pivot sur ses gonds, a gauche) et couloir eclaire derriere.
    hinge = empty("DoorHinge", (dx0, 0.02, 0))
    c["door"] = hinge
    door = box("Door", (dx1 - dx0, 0.06, dh), ((dx1 - dx0) / 2, 0, dh / 2), mat("door", "#5a3b2a"), parent=hinge)
    box("DoorPanelTop", (0.6, 0.02, 0.7), ((dx1 - dx0) / 2, -0.035, 1.45), mat("door_panel", "#4c3023"), parent=hinge)
    box("DoorPanelBottom", (0.6, 0.02, 0.75), ((dx1 - dx0) / 2, -0.035, 0.55), mat("door_panel", "#4c3023"), parent=hinge)
    sphere("Knob", 0.045, (dx1 - dx0 - 0.1, -0.07, 1.0), mat("knob", "#d9b45a"), parent=hinge)
    for name, size, loc in (("DoorFrameL", (0.08, 0.24, dh + 0.08), (dx0 - 0.04, 0.08, dh / 2 + 0.04)),
                            ("DoorFrameR", (0.08, 0.24, dh + 0.08), (dx1 + 0.04, 0.08, dh / 2 + 0.04)),
                            ("DoorFrameT", (dx1 - dx0 + 0.16, 0.24, 0.08), ((dx0 + dx1) / 2, 0.08, dh + 0.04))):
        box(name, size, loc, wood_dark)
    hall = mat("hall", "#e9b877")
    box("HallBack", (3.0, 0.1, 3.2), ((dx0 + dx1) / 2, 2.2, 1.6), hall)
    box("HallFloor", (3.0, 2.2, 0.1), ((dx0 + dx1) / 2, 1.3, -0.05), mat("hall_floor", "#a8794f"))
    box("HallLeft", (0.1, 2.2, 3.2), (dx0 - 0.9, 1.3, 1.6), hall)
    box("HallRight", (0.1, 2.2, 3.2), (dx1 + 0.9, 1.3, 1.6), hall)
    box("HallTop", (3.0, 2.2, 0.1), ((dx0 + dx1) / 2, 1.3, 2.6), hall)
    c["hall_light"] = light("HallLight", "POINT", ((dx0 + dx1) / 2 + 0.3, 1.3, 2.0), "#ffc27a", 0.0, shadow_soft_size=0.25, volume_factor=0.45)
    # Etagere : livres et ours en peluche.
    box("Shelf", (1.5, 0.3, 0.05), (-0.75, -0.15, 2.0), wood)
    for i, (color, h) in enumerate((("#c8525a", 0.3), ("#5b8ad6", 0.24), ("#e8c35a", 0.33), ("#6fb38a", 0.27))):
        box("Book%d" % i, (0.11, 0.2, h), (-1.3 + i * 0.13, -0.15, 2.025 + h / 2), mat("book%d" % i, color))
    teddy = mat("teddy", "#a9764a")
    sphere("TeddyBody", 0.15, (-0.42, -0.15, 2.15), teddy, scale=(1, 0.9, 1.05))
    sphere("TeddyHead", 0.12, (-0.42, -0.16, 2.4), teddy)
    sphere("TeddyMuzzle", 0.055, (-0.42, -0.265, 2.37), mat("teddy_light", "#dcb991"))
    for sx in (-1, 1):
        sphere("TeddyEar", 0.05, (-0.42 + sx * 0.1, -0.15, 2.5), teddy)
        sphere("TeddyArm", 0.06, (-0.42 + sx * 0.16, -0.17, 2.2), teddy)
        sphere("TeddyLeg", 0.065, (-0.42 + sx * 0.1, -0.24, 2.06), teddy)
    # Table de nuit et reveil a chiffres rouges.
    box("Nightstand", (0.7, 0.5, 0.62), (1.55, -0.3, 0.31), wood, bevel=0.02)
    for z in (0.44, 0.18):
        box("Drawer", (0.6, 0.03, 0.22), (1.55, -0.555, z), wood_dark, bevel=0.01)
        sphere("DrawerKnob", 0.028, (1.55, -0.58, z), mat("knob", "#d9b45a"))
    box("Clock", (0.5, 0.18, 0.24), (1.55, -0.34, 0.74), mat("clock", "#16141c"), bevel=0.03)
    digits = glow_mat("digits", "#ff3b3f", 6.0)
    c["digits_mat"] = digits
    clock_face = empty("ClockFace", (1.55, -0.435, 0.74))
    for i, (digit, px) in enumerate((("0", -0.165), ("3", -0.075), ("1", 0.075), ("7", 0.165))):
        seven_segment("Digit%d" % i, digit, (px, 0, 0), (0.055, 0.12), digits, clock_face)
    colon = empty("Colon", (0, 0, 0), parent=clock_face)
    c["colon"] = colon
    for z in (-0.03, 0.03):
        box("ColonDot", (0.014, 0.004, 0.014), (0, 0, z), digits, parent=colon)
    c["clock_light"] = light("ClockLight", "POINT", (1.55, -0.62, 0.74), "#ff4548", 0.0, shadow_soft_size=0.05)
    # Veilleuse : une etoile endormie branchee sur sa prise.
    box("Socket", (0.16, 0.03, 0.16), (VEILLEUSE.x, -0.01, VEILLEUSE.z - 0.02), mat("socket", "#d8d4e6"), bevel=0.01)
    veil_mat = glow_mat("veilleuse", "#ffd9a0", 0.0)
    c["veilleuse_mat"] = veil_mat
    lamp = star("Veilleuse", 0.17, 0.095, 0.07, VEILLEUSE, veil_mat)
    c["veilleuse"] = lamp
    eye = mat("veilleuse_eye", "#8a5a2c")
    for sx in (-1, 1):
        sphere("VeilleuseEye", 0.02, (VEILLEUSE.x + sx * 0.045, VEILLEUSE.y - 0.045, VEILLEUSE.z + 0.005), eye, scale=(1.2, 0.4, 0.35))
    sphere("VeilleuseMouth", 0.014, (VEILLEUSE.x, VEILLEUSE.y - 0.045, VEILLEUSE.z - 0.04), eye, scale=(1.4, 0.4, 0.5))
    c["veilleuse_light"] = light("VeilleuseLight", "POINT", (VEILLEUSE.x, VEILLEUSE.y - 0.3, VEILLEUSE.z), "#ffb866", 0.0, shadow_soft_size=0.12)
    # Lit de profil, tete a gauche : montants a boules, matelas, oreiller, couette.
    bx0, bx1, by = -2.25, 0.55, -1.5
    for px, h in ((bx0, 1.25), (bx1, 0.95)):
        for py in (by - 0.5, by + 0.5):
            cyl("BedPost", 0.055, h, (px, py, h / 2), wood)
            sphere("BedKnob", 0.085, (px, py, h + 0.05), mat("wood_light", "#8a5e3f"))
        box("BedBoard", (0.07, 1.0, h - 0.45), (px, by, 0.35 + (h - 0.45) / 2), wood_dark)
    box("BedFrame", (bx1 - bx0, 1.05, 0.14), ((bx0 + bx1) / 2, by, 0.42), wood)
    box("Mattress", (bx1 - bx0 - 0.12, 1.0, 0.2), ((bx0 + bx1) / 2, by, 0.59), mat("mattress", "#cfcbe6"), bevel=0.05)
    box("Pillow", (0.62, 0.82, 0.16), (PILLOW.x, by, PILLOW.z - 0.04), mat("pillow", "#f3f1ff"), bevel=0.07)
    quilt = box("Quilt", (1.95, 1.08, 0.46), (-0.48, by, 0.83), stripes_mat("quilt", "#8f7fd6", "#a898e6", 2.2, axis=0), bevel=0.12)
    c["quilt"] = quilt
    # Tapis ovale et jouets au premier plan.
    cyl("Rug", 1.0, 0.03, (0.15, -3.3, 0.015), mat("rug", "#5b3f9e"), scale=(1.7, 0.75, 1), segments=40)
    cyl("RugInner", 1.0, 0.035, (0.15, -3.3, 0.016), mat("rug_inner", "#6c4fb5"), scale=(1.3, 0.52, 1), segments=40)
    for i, (color, loc, rz) in enumerate((("#c8525a", (-2.3, -5.2, 0.14), 0.4), ("#5b8ad6", (-1.95, -5.0, 0.14), -0.3),
                                          ("#e8c35a", (-2.15, -5.1, 0.42), 0.9))):
        box("Block%d" % i, (0.28, 0.28, 0.28), loc, mat("block%d" % i, color), rot=(0, 0, rz), bevel=0.02)
    sphere("Ball", 0.2, (2.5, -5.3, 0.2), stripes_mat("ball", "#e2574c", "#f3f1ff", 2.5, axis=2))
    # Lumieres : la lune a travers la fenetre, un appoint bleu tres doux, la brume qui montre le rayon.
    moon = light("MoonLight", "SPOT", (cx + 1.25, 3.3, cz + 2.35), "#a9bcff", 0.0, spot_size=math.radians(36), spot_blend=0.35, shadow_soft_size=0.3, volume_factor=1.0)
    aim(moon, (0.2, -2.6, 0.0))
    c["moon_light"] = moon
    fill = light("Fill", "AREA", (0, -6.5, 2.6), "#5f6fd0", 0.0, size=5.0)
    aim(fill, (0, -1.0, 0.8))
    c["fill"] = fill
    c["fog"] = fog((6.4, 7.0, 3.2), (0, -3.4, 1.6), 0.035)
    return c


def night_levels(c, t, amount):
    """Niveau de la nuit dans la chambre (0 = noir complet, 1 = clair de lune)."""
    K(c["moon_light"].data, "energy", t, 9000.0 * amount)
    K(c["fill"].data, "energy", t, 420.0 * amount)
    KS(world_background().inputs["Strength"], t, 1.0 * amount)
    KS(c["sky"].data.materials[0].node_tree.nodes["Emission"].inputs["Strength"], t, 1.0 * amount)
    for key, full in (("moon_mat", 3.0), ("cloud_mat", 0.9), ("star_mat", 2.5)):
        KS(glow_strength(c[key]), t, full * amount)
    K(c["clock_light"].data, "energy", t, 0.6 * amount)
    KS(glow_strength(c["digits_mat"]), t, 6.0 * (0.25 + 0.75 * amount) if amount > 0 else 0.0)


def veilleuse_on(c, t, level):
    K(c["veilleuse_light"].data, "energy", t, 5.0 * level)
    KS(glow_strength(c["veilleuse_mat"]), t, 4.5 * level)


def breathing(ob, duration, period=3.4, amount=0.04, axis=2):
    t = 0.0
    up = False
    base = ob.scale[axis]
    while t <= duration + period:
        K(ob, "scale", t, base * (1 + amount) if up else base, index=axis)
        up = not up
        t += period / 2


def blink_colon(colon, duration):
    t = 0.0
    on = True
    while t <= duration:
        K(colon, "scale", t, (1, 1, 1) if on else (0, 0, 0))
        on = not on
        t += 0.5
    interpolation(colon, "CONSTANT")


def drift_clouds(clouds, duration, speed=0.12):
    K(clouds, "location", 0.0, clouds.location.x, index=0)
    K(clouds, "location", duration, clouds.location.x - speed * duration, index=0)
    interpolation(clouds, "LINEAR")


def lying_dreamer():
    """Le reveur couche sur le dos dans son lit, la tete sur l'oreiller (a gauche), sous la couette."""
    d = dreamer("standing", "closed")
    # Axes du personnage : +Z (la tete) vers -X du monde, -Y (le visage) vers le plafond.
    d["root"].matrix_world = Matrix(((0, 0, -1, PILLOW.x + 0.92), (1, 0, 0, -1.5), (0, -1, 0, 0.9), (0, 0, 0, 1)))
    d["head"].rotation_euler = (math.radians(-12), math.radians(-14), 0)
    return d


# --- Les sept tours de la semaine -----------------------------------------------------------

def week_towers(parent, spacing=3.0, scale=1.0, lit=1.0):
    """Les sept tours, du lundi (a gauche) au dimanche. Renvoie la liste de leurs pivots (base au sol)."""
    towers = []
    window = glow_mat("tower_window", "#ffd98a", 2.2 * lit)
    for i in range(7):
        pivot = empty("Tower%d" % i, (i * spacing, 0, 0), parent=parent)
        pivot.scale = (scale, scale, scale)
        towers.append(pivot)
        if i == 0:  # lundi : tour ronde lavande coiffee d'un oreiller
            body = mat("t_lundi", "#8d7fd6")
            cyl("Body", 0.75, 5.0, (0, 0, 2.5), body, parent=pivot)
            sphere("Dome", 1.25, (0, 0, 5.3), mat("t_lundi_dome", "#b9aef0"), scale=(1, 1, 0.62), parent=pivot)
            for z in (2.4, 3.6):
                sphere("Win", 0.22, (0, -0.72, z), window, scale=(1, 0.3, 1), parent=pivot)
        elif i == 1:  # mardi : beffroi a horloge
            body = mat("t_mardi", "#b07a3c")
            box("Body", (1.35, 1.35, 5.4), (0, 0, 2.7), body, parent=pivot)
            cyl("Roof", 1.25, 1.5, (0, 0, 6.15), mat("t_mardi_roof", "#7a4a26"), parent=pivot, radius_top=0.0, segments=4, rot=(0, 0, math.pi / 4))
            cyl("Dial", 0.45, 0.08, (0, -0.7, 4.6), mat("dial", "#f0e4c4"), rot=(math.pi / 2, 0, 0), parent=pivot)
            box("Hand", (0.04, 0.03, 0.3), (0, -0.76, 4.72), mat("eye", "#2a1c1c"), parent=pivot)
            box("Hand2", (0.2, 0.03, 0.04), (0.08, -0.76, 4.6), mat("eye", "#2a1c1c"), parent=pivot)
            for z in (2.0, 3.2):
                box("Win", (0.4, 0.06, 0.5), (0, -0.69, z), window, parent=pivot)
        elif i == 2:  # mercredi : fleche de verre bleu pale
            body = mat("t_mercredi", "#9fc0e6")
            cyl("Body", 0.62, 5.2, (0, 0, 2.6), body, parent=pivot, segments=6)
            cyl("Spire", 0.85, 2.6, (0, 0, 6.5), mat("t_mercredi_spire", "#b9d6f2"), parent=pivot, radius_top=0.0, segments=6)
            for z, m in ((2.0, window), (3.1, glow_mat("tower_window_cold", "#dff0ff", 2.0 * lit)), (4.2, window)):
                box("Win", (0.3, 0.06, 0.45), (0, -0.55, z), m, parent=pivot)
        elif i == 3:  # jeudi : usine grise a cheminee
            body = mat("t_jeudi", "#6a6d7c")
            box("Body", (1.9, 1.5, 4.4), (0, 0, 2.2), body, parent=pivot)
            box("Band", (1.94, 1.54, 0.22), (0, 0, 2.5), mat("t_jeudi_band", "#e88a2e"), parent=pivot)
            cyl("Chimney", 0.24, 2.4, (0.45, 0, 5.6), mat("t_jeudi_chimney", "#55586a"), parent=pivot)
            for z in (1.5, 3.4):
                for x in (-0.55, 0, 0.55):
                    box("Win", (0.3, 0.06, 0.45), (x, -0.77, z), window, parent=pivot)
            smoke = glow_mat("smoke", "#8a8ca0", 0.35 * lit)
            for k in range(3):
                sphere("Smoke", 0.3 + k * 0.1, (0.45 + k * 0.25, 0, 7.0 + k * 0.5), smoke, parent=pivot)
        elif i == 4:  # vendredi : cartons empiles de travers
            for k in range(5):
                box("Box%d" % k, (1.5 - k * 0.08, 1.3, 1.0), (0.12 * k * (1 if k % 2 else 0.4), 0, 0.5 + k * 1.02),
                    mat("t_vendredi%d" % (k % 2), "#c79a5e" if k % 2 else "#b88a50"), rot=(0, 0, 0.12 * (k - 2)), parent=pivot)
                box("Tape%d" % k, (0.16, 1.32, 1.01), (0.12 * k * (1 if k % 2 else 0.4), 0, 0.5 + k * 1.02), mat("tape", "#e2c488"), rot=(0, 0, 0.12 * (k - 2)), parent=pivot)
            box("Win", (0.24, 0.06, 0.24), (0.1, -0.67, 2.6), window, parent=pivot)
        elif i == 5:  # samedi : tour creme aux fenetres eteintes
            body = mat("t_samedi", "#e2dccb")
            cyl("Body", 0.7, 5.2, (0, 0, 2.6), body, parent=pivot)
            sphere("Top", 0.95, (0, 0, 5.5), mat("t_samedi_top", "#cfc8b6"), parent=pivot)
            cyl("Antenna", 0.03, 1.2, (0, 0, 6.9), mat("t_samedi_top", "#cfc8b6"), parent=pivot)
            for z in (1.6, 2.9, 4.2):
                sphere("Win", 0.24, (0, -0.66, z), mat("t_samedi_window", "#3a4078"), scale=(0.85, 0.3, 1.25), parent=pivot)
        else:  # dimanche : fleche noire a l'oeil rouge
            body = mat("t_dimanche", "#241628")
            cyl("Body", 0.72, 5.6, (0, 0, 2.8), body, parent=pivot, segments=7, radius_top=0.56)
            cyl("Spire", 0.95, 2.8, (0, 0, 7.0), mat("t_dimanche_spire", "#1a0f1e"), parent=pivot, radius_top=0.0, segments=7)
            sphere("Eye", 0.24, (0, -0.6, 3.6), glow_mat("tower_eye", "#ff2d4a", 5.0 * lit), scale=(0.8, 0.4, 1.15), parent=pivot)
    return towers


# --- Plan 1 : la veilleuse, puis la chambre se devoile -------------------------------------

def shot_chambre():
    duration = 13.5
    reset("intro_1_chambre", duration)
    c = chambre()
    lying_dreamer()
    cam, target = camera(35.0)
    # Camera : gros plan sur la veilleuse, recul qui devoile la chambre, puis lente avancee vers le lit.
    K(cam, "location", 0.0, (2.3, -1.25, 0.66))
    K(target, "location", 0.0, tuple(VEILLEUSE))
    K(cam, "location", 5.5, (2.22, -1.42, 0.68))
    K(target, "location", 5.5, tuple(VEILLEUSE))
    K(cam, "location", 7.9, (0.25, -8.1, 1.55))
    K(target, "location", 7.9, (0.0, 0.0, 1.3))
    K(cam, "location", duration, (-0.25, -7.2, 1.42))
    K(target, "location", duration, (-0.5, -0.6, 1.12))
    # Le noir, puis la veilleuse gresille et s'allume.
    for t, level in ((0.0, 0.0), (1.0, 0.0), (1.02, 1.0), (1.15, 0.15), (1.25, 1.0), (1.4, 0.4), (1.5, 0.85)):
        veilleuse_on(c, t, level)
    t = 1.5
    while t < duration:
        veilleuse_on(c, t, 0.9 + 0.1 * math.sin(t * 3.1))
        t += 0.5
    night_levels(c, 0.0, 0.0)
    night_levels(c, 5.5, 0.0)
    night_levels(c, 7.8, 1.0)
    breathing(c["quilt"], duration)
    blink_colon(c["colon"], duration)
    drift_clouds(c["clouds"], duration)
    pixel_look()
    return c


# --- Plan 2a : la porte s'entrouvre sur les voix, il se tourne vers le mur -----------------

def burst(name, radius, loc, color):
    """Bulle de cri : un eclat arrondi, barre de traits sombres."""
    root = empty(name, loc)
    star(name + "_shape", radius, radius * 0.7, 0.03, (0, 0, 0), glow_mat(name + "_mat", color, 1.5), parent=root, points=9)
    ink = mat("bubble_ink", "#3a2030")
    for k, (w, z) in enumerate(((0.95, 0.24), (0.6, 0.0), (0.8, -0.24))):
        box("%s_line%d" % (name, k), (radius * w, 0.012, radius * 0.11), (0, -0.035, radius * z), ink, parent=root)
    return root


def steady_veilleuse(c, duration):
    t = 0.0
    while t <= duration + 0.5:
        veilleuse_on(c, t, 0.9 + 0.1 * math.sin(t * 3.1))
        t += 0.5


def shot_voix():
    duration = 8.6
    reset("intro_2a_voix", duration)
    c = chambre()
    d = lying_dreamer()
    cam, target = camera(35.0)
    K(cam, "location", 0.0, (-1.9, -6.6, 1.55))
    K(target, "location", 0.0, (-2.1, 0.0, 1.2))
    K(cam, "location", 7.5, (-0.95, -5.5, 1.38))
    K(target, "location", 7.5, (-1.35, -1.3, 0.98))
    night_levels(c, 0.0, 1.0)
    steady_veilleuse(c, duration)
    # La porte s'entrouvre : la lumiere du couloir coupe la chambre, elle tremble un peu.
    dx0, dx1, dh = DOOR
    K(c["door"], "rotation_euler", 0.0, 0.0, index=2)
    K(c["door"], "rotation_euler", 1.0, 0.0, index=2)
    K(c["door"], "rotation_euler", 2.6, -math.radians(64), index=2)
    hall = c["hall_light"].data
    K(hall, "energy", 0.0, 0.0)
    K(hall, "energy", 1.0, 0.0)
    K(hall, "energy", 2.6, 520.0)
    t = 2.8
    while t <= duration:
        K(hall, "energy", t, 520.0 * (0.92 + 0.08 * math.sin(t * 5)))
        t += 0.2
    # Les voix : trois bulles de cri qui derivent de la porte vers le lit.
    start = Vector((dx0 + 0.75, -0.35, 1.45))
    for i, (t0, color, drift) in enumerate(((2.6, "#ffe9c8", (1.2, -0.9, 0.25)), (3.5, "#ffc9b0", (1.7, -1.3, -0.05)), (4.4, "#fff3d6", (0.9, -1.6, -0.35)))):
        bubble = burst("Bubble%d" % i, 0.34, tuple(start), color)
        bubble.rotation_euler = (0, math.sin(t0 * 3) * 0.12, 0)
        K(bubble, "scale", 0.0, (0, 0, 0))
        K(bubble, "scale", t0, (0, 0, 0))
        K(bubble, "scale", t0 + 0.35, (1, 1, 1))
        K(bubble, "scale", t0 + 2.6, (1.3, 1.3, 1.3))
        K(bubble, "scale", t0 + 3.2, (0, 0, 0))
        K(bubble, "location", t0, tuple(start))
        K(bubble, "location", t0 + 3.2, tuple(start + Vector(drift)))
    # Il se tourne vers le mur et remonte la couette.
    head = d["head"]
    K(head, "rotation_euler", 4.6, tuple(head.rotation_euler))
    K(head, "rotation_euler", 5.2, (math.radians(-4), math.radians(-6), math.radians(82)))
    K(c["quilt"], "location", 4.7, c["quilt"].location.x, index=0)
    K(c["quilt"], "location", 5.5, c["quilt"].location.x - 0.16, index=0)
    breathing(c["quilt"], duration)
    blink_colon(c["colon"], duration)
    drift_clouds(c["clouds"], duration)
    pixel_look()


# --- Plan 2b : dans le noir, ses sept soucis tournent autour de lui en se resserrant -------

def worry(kind):
    """Un souci : petit objet qui porte sa propre lueur. Renvoie son pivot et sa lumiere."""
    root = empty("Worry_" + kind)
    dark = mat("eye", "#2a1c1c")
    if kind == "reveil":
        color = "#ff5a5a"
        cyl("Body", 0.3, 0.2, (0, 0, 0), mat("w_reveil", "#d8443f"), rot=(math.pi / 2, 0, 0), parent=root)
        cyl("Dial", 0.24, 0.22, (0, 0, 0), mat("dial", "#f0e4c4"), rot=(math.pi / 2, 0, 0), parent=root)
        box("Hand", (0.03, 0.02, 0.17), (0, -0.115, 0.07), dark, parent=root)
        box("Hand2", (0.13, 0.02, 0.03), (0.05, -0.115, 0), dark, parent=root)
        for sx in (-1, 1):
            sphere("Bell", 0.11, (sx * 0.2, 0, 0.3), mat("w_bell", "#e8c35a"), parent=root)
            cyl("Foot", 0.03, 0.14, (sx * 0.17, 0, -0.32), dark, parent=root)
    elif kind == "devoirs":
        color = "#ffe9a8"
        for k in range(5):
            box("Sheet%d" % k, (0.5, 0.36, 0.07), (0.03 * (k % 2), 0, -0.2 + k * 0.085), mat("w_sheet%d" % (k % 2), "#f3efe2" if k % 2 else "#e2dccb"), rot=(0, 0, 0.14 * (k - 2)), parent=root)
        box("Mark", (0.2, 0.02, 0.03), (0, -0.1, 0.24), mat("w_red", "#d8443f"), rot=(0, 0.5, 0), parent=root)
        box("Mark2", (0.2, 0.02, 0.03), (0, -0.1, 0.24), mat("w_red", "#d8443f"), rot=(0, -0.5, 0), parent=root)
    elif kind == "miroir":
        color = "#a8d8ff"
        cyl("Frame", 0.3, 0.06, (0, 0, 0), mat("w_frame", "#b88a50"), rot=(math.pi / 2, 0, 0), scale=(1, 1, 1.35), parent=root)
        cyl("Glass", 0.25, 0.07, (0, 0, 0), glow_mat("w_glass", "#bfe4ff", 0.9), rot=(math.pi / 2, 0, 0), scale=(1, 1, 1.35), parent=root)
        for a, l in ((0.5, 0.4), (-0.7, 0.3), (2.2, 0.26)):
            box("Crack", (0.015, 0.02, l), (0.03, -0.04, 0.02), dark, rot=(0, a, 0), parent=root)
    elif kind == "cocotte":
        color = "#ffa04a"
        cyl("Pot", 0.3, 0.3, (0, 0, -0.05), mat("w_pot", "#8d92a8"), parent=root)
        cyl("Lid", 0.32, 0.07, (0, 0, 0.13), mat("w_lid", "#6a6d7c"), parent=root)
        sphere("Valve", 0.07, (0, 0, 0.22), glow_mat("w_valve", "#ff7a2e", 2.5), parent=root)
        for sx in (-1, 1):
            box("Handle", (0.14, 0.07, 0.05), (sx * 0.36, 0, 0.05), dark, parent=root)
        steam = glow_mat("w_steam", "#e8e4f4", 0.7)
        for k in range(3):
            sphere("Steam", 0.07 + 0.03 * k, (0.05 * k, 0, 0.36 + 0.14 * k), steam, parent=root)
    elif kind == "fardeau":
        color = "#d9a866"
        box("Box", (0.52, 0.44, 0.42), (0, 0, 0), mat("w_box", "#c79a5e"), rot=(0, 0, 0.3), bevel=0.02, parent=root)
        box("Tape", (0.1, 0.45, 0.43), (0, 0, 0), mat("tape", "#e2c488"), rot=(0, 0, 0.3), parent=root)
        box("Weight", (0.22, 0.2, 0.14), (0.05, 0, 0.28), mat("w_weight", "#4a4c5c"), rot=(0, 0, -0.2), bevel=0.02, parent=root)
    elif kind == "chaise":
        color = "#cfc8e8"
        wood = mat("w_chair", "#8a5e3f")
        tilt = empty("ChairTilt", parent=root)
        tilt.rotation_euler = (0.15, 0, 0.5)
        box("Seat", (0.36, 0.36, 0.05), (0, 0, 0), wood, parent=tilt)
        box("Back", (0.36, 0.05, 0.42), (0, 0.16, 0.24), wood, parent=tilt)
        for sx in (-1, 1):
            for sy in (-1, 1):
                cyl("Leg", 0.025, 0.34, (sx * 0.15, sy * 0.15, -0.19), wood, parent=tilt)
    else:  # compte : le compte a rebours
        color = "#ff3b5c"
        box("Case", (0.56, 0.2, 0.32), (0, 0, 0), mat("clock", "#16141c"), bevel=0.04, parent=root)
        digits = glow_mat("w_digits", "#ff3b3f", 6.0)
        for digit, px in (("0", -0.12), ("7", 0.12)):
            seven_segment("Count" + digit, digit, (px, -0.105, 0), (0.1, 0.18), digits, root)
    glow = light("WorryGlow_" + kind, "POINT", (0, -0.5, 0.25), color, 26.0, parent=root, shadow_soft_size=0.2)
    return root, glow


WORRIES = ["reveil", "devoirs", "miroir", "cocotte", "fardeau", "chaise", "compte"]
SOUCIS_START = 8.0  # temps du plan 2 auquel ce segment commence


def shot_soucis():
    duration = 8.1
    reset("intro_2b_soucis", duration)
    set_world((0.012, 0.008, 0.035), 1.0)
    cyl("Ground", 16.0, 0.1, (0, 0, -0.05), mat("void_ground", "#1b1436"), segments=64)
    d = dreamer("standing", "open")
    d["armL"].rotation_euler = (math.radians(-58), math.radians(-42), 0)  # il se serre dans ses bras
    d["armR"].rotation_euler = (math.radians(-58), math.radians(42), 0)
    cam, target = camera(35.0)
    K(cam, "location", 0.0, (0.0, -8.8, 2.7))
    K(target, "location", 0.0, (0.0, 0.0, 0.8))
    K(cam, "location", duration, (0.0, -6.7, 2.05))
    K(target, "location", duration, (0.0, 0.0, 0.72))
    key = light("Key", "SPOT", (0.0, -2.2, 5.0), "#b9a0ff", 0.0, spot_size=math.radians(42), spot_blend=0.6, shadow_soft_size=0.3, volume_factor=0.2)
    aim(key, (0, 0, 0.5))
    light("Rim", "POINT", (0.0, 2.2, 2.2), "#6a7cff", 60.0, shadow_soft_size=0.4)
    fog((22, 22, 9), (0, 0, 4.4), 0.014)
    rng = random.Random(3)
    dust = glow_mat("dust", "#cfc4ff", 2.0)
    for i in range(46):
        a, r = rng.uniform(0, TAU), rng.uniform(1.2, 7.0)
        sphere("Dust", 0.022, (r * math.cos(a), r * math.sin(a), rng.uniform(0.2, 4.2)), dust)
    items = [worry(kind) for kind in WORRIES]
    steps = int(duration * 12) + 1
    for step in range(steps):
        t = step / 12.0
        tt = t + SOUCIS_START
        t4 = max(0.0, tt - 8.4)
        tighten = ease(t4 / 7.0)
        radius = 3.0 + (1.75 - 3.0) * tighten
        beat = max(0.0, math.sin(tt * math.pi * (1.1 + tighten * 0.9))) ** 12
        K(key.data, "energy", t, (900.0 + 500.0 * tighten) * (1.0 + 0.4 * beat))
        if step % 3 == 0:
            for i, (root, glow) in enumerate(items):
                appear = max(0.0, min(1.0, (t4 - i * 0.45) / 0.35))
                angle = -math.pi / 2 + i * TAU / 7 + t4 * (0.5 + tighten * 0.45)
                K(root, "location", t, (radius * math.cos(angle), radius * 0.9 * math.sin(angle), 1.3 + 0.22 * math.sin(tt * 1.7 + i * 1.3)))
                pop = (0.4 + 0.75 * appear + 0.15 * math.sin(appear * math.pi)) if 0 < appear < 1 else appear
                size = 1.0 * pop
                K(root, "scale", t, (size, size, size))
                K(glow.data, "energy", t, 30.0 * appear * (1.0 + 0.5 * tighten))
    # Il se recroqueville peu a peu.
    K(d["head"], "rotation_euler", 0.6, (0, 0, 0))
    K(d["head"], "rotation_euler", duration, (math.radians(24), 0, 0))
    K(d["root"], "scale", 0.6, (1, 1, 1))
    K(d["root"], "scale", duration, (1, 1, 0.93))
    pixel_look()


# --- Plan 3 : les sept tours surgissent de la mer de nuages --------------------------------

GLOWS = ["#ffd68c", "#ffd68c", "#c8e2ff", "#ffaa5a", "#ffc882", "#8c96c8", "#ff4650"]
RISE_START, RISE_GAP, RISE_TIME = 0.9, 0.65, 0.55


def cloud_bank(name, y, z, x0, x1, step, size, material, seed):
    root = empty(name, (0, y, z))
    rng = random.Random(seed)
    x = x0
    while x < x1:
        r = size * rng.uniform(0.7, 1.3)
        sphere("Puff", r, (x, rng.uniform(-0.7, 0.7), rng.uniform(-0.25, 0.25) * size), material, scale=(1.7, 1.0, 0.62), parent=root)
        x += step * rng.uniform(0.6, 1.2)
    return root


def shot_horizon():
    duration = 17.5
    reset("intro_3_horizon", duration)
    set_world((0.05, 0.04, 0.12), 1.0)
    # Ciel : du crepuscule (lundi, a gauche) a la nuit noire (dimanche, a droite).
    box("Sky", (150, 0.1, 70), (10, 45, 14), sky_mat("sky", "#05040f", "#7a56ad", 1.0, axis_span=0.62, axis=0))
    rng = random.Random(11)
    stars = glow_mat("stars", "#e4e8ff", 3.0)
    for i in range(110):
        x = rng.uniform(-6, 62) if i % 3 else rng.uniform(-40, 62)
        sphere("Star", rng.uniform(0.05, 0.11), (x, 44, rng.uniform(4, 40)), stars)
    towers = week_towers(empty("Towers"), spacing=3.3)
    far = cloud_bank("CloudsFar", 7.0, 0.6, -45, 65, 2.4, 2.4, mat("cloud_far", "#6f66b4", emission=0.25), 1)
    mid = cloud_bank("CloudsMid", -2.6, 0.2, -40, 60, 1.5, 1.5, mat("cloud_mid", "#a59be0", emission=0.22), 2)
    near = cloud_bank("CloudsNear", -8.5, -1.3, -40, 60, 1.9, 2.0, mat("cloud_near", "#c9c0f2", emission=0.2), 3)
    for bank, speed in ((far, 0.25), (mid, 0.45), (near, 0.75)):
        K(bank, "location", 0.0, 0.0, index=0)
        K(bank, "location", duration, -speed * duration, index=0)
        interpolation(bank, "LINEAR")
    dusk = light("Dusk", "SUN", (-10, -10, 10), "#d0a8ff", 2.2)
    aim(dusk, (6, 0, 2))
    night = light("Night", "SUN", (30, -12, 12), "#5a6ad0", 0.9)
    aim(night, (14, 0, 2))
    fog((90, 30, 16), (10, 2, 7), 0.004)
    shake = empty("Shake")
    cam, target = camera(30.0)
    cam.parent = shake
    K(cam, "location", 0.0, (2.5, -24.0, 4.3))
    K(target, "location", 0.0, (5.0, 0.0, 3.5))
    K(cam, "location", 7.8, (12.5, -24.0, 4.7))
    K(target, "location", 7.8, (13.0, 0.0, 3.8))
    # Retour sur l'horizon : il regarde les sept tours, la camera s'en approche doucement.
    K(cam, "location", 12.6, (10.6, -24.0, 4.6))
    K(target, "location", 12.6, (10.4, 0.0, 3.9))
    K(cam, "location", duration, (10.0, -20.5, 4.3))
    K(target, "location", duration, (10.0, 0.0, 4.0))
    K(shake, "location", 0.0, 0.0, index=2)
    for i, pivot in enumerate(towers):
        t0 = RISE_START + i * RISE_GAP
        land = t0 + RISE_TIME
        K(pivot, "location", 0.0, -10.0, index=2)
        K(pivot, "location", t0, -10.0, index=2)
        K(pivot, "location", t0 + RISE_TIME * 0.72, 0.5, index=2)
        K(pivot, "location", land, 0.0, index=2)
        halo = light("Halo%d" % i, "POINT", (pivot.location.x, -2.2, 3.4), GLOWS[i], 0.0, shadow_soft_size=0.6)
        K(halo.data, "energy", land, 0.0)
        K(halo.data, "energy", land + 0.5, 900.0 * (0.35 if i == 5 else 1.0))
        # Petit tremblement a chaque tour qui surgit, plus fort vers le dimanche.
        amp = 0.05 + i * 0.022
        for k in range(7):
            K(shake, "location", land + k * 0.05, amp * (1 - k / 6.0) * (-1 if k % 2 else 1) if k < 6 else 0.0, index=2)
    pixel_look()


# --- Plan 3b : assis au bord du lit, il regarde les tours par la fenetre -------------------

FENETRE_START = 7.4


def shot_fenetre():
    duration = 6.1
    reset("intro_3b_fenetre", duration)
    c = chambre(towers_outside=True)
    quilt = c["quilt"]
    quilt.scale.z *= 0.5
    quilt.location.z = 0.74
    d = dreamer("sitting", "open")
    d["root"].location = (0.0, -1.02, 0.36)
    d["root"].rotation_euler = (0, 0, math.radians(180 - 12))  # dos a la camera, tourne vers la fenetre
    cam, target = camera(35.0)
    K(cam, "location", 0.0, (0.55, -3.5, 1.72))
    K(target, "location", 0.0, (1.25, 0.1, 1.82))
    K(cam, "location", 5.0, (-0.1, -6.9, 1.5))
    K(target, "location", 5.0, (0.6, 0.0, 1.38))
    K(cam, "location", duration, (-0.15, -7.0, 1.5))
    K(target, "location", duration, (0.58, 0.0, 1.37))
    night_levels(c, 0.0, 1.0)
    steady_veilleuse(c, duration)
    breathing(d["torso"], duration, period=2.8, amount=0.03)
    blink_colon(c["colon"], duration)
    drift_clouds(c["clouds"], duration)
    pixel_look()


# --- Plan 4 : la chute a travers les lieux des sept nuits ----------------------------------

SECTION = 11.0
PLACES = [  # couleur du fond, couleur de la lumiere
    ("#8d86d8", "#d8d0ff"), ("#b98a4a", "#ffd68c"), ("#8fb4dc", "#c8e2ff"), ("#a8452c", "#ff8a3a"),
    ("#b88a50", "#ffc882"), ("#bdb6a4", "#cfc8e8"), ("#2a1230", "#ff3b5c"),
]


def place_prop(k, parent, loc, rng):
    """Un decor du lieu de la nuit k, pose dans le puits de la chute."""
    root = empty("Prop", loc, parent=parent)
    root.rotation_euler = (rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), rng.uniform(0, TAU))
    if k == 0:  # lundi : coton et oreillers
        if rng.random() < 0.6:
            cotton = mat("p_cotton", "#e9e4ff", emission=0.3)
            for j in range(3):
                sphere("Cotton", rng.uniform(0.5, 0.8), (j * 0.6 - 0.6, 0, 0.15 * (j == 1)), cotton, scale=(1.3, 1, 0.7), parent=root)
        else:
            box("Pillow", (1.1, 0.75, 0.3), (0, 0, 0), mat("pillow", "#f3f1ff"), bevel=0.12, parent=root)
    elif k == 1:  # mardi : rouages et pendules
        brass = mat("p_brass", "#c79a4a")
        cyl("Gear", rng.uniform(0.6, 1.1), 0.2, (0, 0, 0), brass, segments=9, parent=root)
        cyl("Hub", 0.25, 0.3, (0, 0, 0), mat("p_brass_dark", "#8a6a2e"), parent=root)
    elif k == 2:  # mercredi : eclats de miroir
        box("Shard", (rng.uniform(0.5, 1.1), 0.04, rng.uniform(0.9, 1.8)), (0, 0, 0), glow_mat("p_shard", "#cfe8ff", 0.8), parent=root)
    elif k == 3:  # jeudi : briques rougies et tuyaux
        if rng.random() < 0.65:
            box("Brick", (0.9, 0.45, 0.4), (0, 0, 0), mat("p_brick", "#b8452c", emission=0.5, emit_color="#ff5a2a"), parent=root)
        else:
            cyl("Pipe", 0.16, 2.2, (0, 0, 0), mat("p_pipe", "#55586a"), parent=root)
    elif k == 4:  # vendredi : cartons
        box("Box", (0.9, 0.8, 0.7), (0, 0, 0), mat("w_box", "#c79a5e"), bevel=0.03, parent=root)
        box("Tape", (0.16, 0.82, 0.72), (0, 0, 0), mat("tape", "#e2c488"), parent=root)
    elif k == 5:  # samedi : chaises vides
        wood = mat("p_chair", "#e2dccb")
        box("Seat", (0.6, 0.6, 0.08), (0, 0, 0), wood, parent=root)
        box("Back", (0.6, 0.08, 0.7), (0, 0.27, 0.4), wood, parent=root)
        for sx in (-1, 1):
            for sy in (-1, 1):
                cyl("Leg", 0.04, 0.55, (sx * 0.25, sy * 0.25, -0.3), wood, parent=root)
    else:  # dimanche : epines noires et yeux rouges
        cyl("Spike", 0.35, 2.4, (0, 0, 0), mat("p_spike", "#1a0f1e"), radius_top=0.0, segments=7, parent=root)
        if rng.random() < 0.6:
            sphere("Eye", 0.2, (0, -0.25, -0.5), glow_mat("tower_eye", "#ff2d4a", 5.0), scale=(1, 0.5, 0.7), parent=root)


def shot_chute():
    duration = 4.8
    reset("intro_4_chute", duration)
    set_world((0.02, 0.012, 0.05), 1.0)
    spinner = empty("Spinner")
    d = dreamer("falling", "closed")
    d["root"].parent = spinner
    d["root"].location = (0, 0, -0.6)
    env = empty("Env")
    rng = random.Random(21)
    streak = glow_mat("streak", "#f4f0ff", 1.6)
    for k, (back, glow) in enumerate(PLACES):
        zc = -k * SECTION
        cyl("Wall%d" % k, 13.0, SECTION, (0, 0, zc), glow_mat("wall%d" % k, back, 0.22), parent=env, segments=28, caps=False)
        for j in range(2):
            a = rng.uniform(0, TAU)
            light("Place%d_%d" % (k, j), "POINT", (5.5 * math.cos(a), 5.5 * math.sin(a), zc + (j - 0.5) * 5.0), glow, 2600.0, parent=env, shadow_soft_size=1.0)
        for j in range(22):
            a = rng.uniform(0, TAU)
            near_camera = abs(((a + math.pi / 2 + math.pi) % TAU) - math.pi) < 0.7  # devant la camera : plus loin du centre
            r = rng.uniform(8.0, 10.5) if near_camera else rng.uniform(3.4, 9.5)
            place_prop(k, env, (r * math.cos(a), r * math.sin(a), zc + rng.uniform(-SECTION / 2, SECTION / 2)), rng)
        for j in range(26):
            a = rng.uniform(0, TAU)
            r = rng.uniform(2.2, 9.0)
            if abs(((a + math.pi / 2 + math.pi) % TAU) - math.pi) < 0.6:
                r = rng.uniform(7.5, 10.0)
            box("Streak", (0.035, 0.035, rng.uniform(1.2, 3.6)), (r * math.cos(a), r * math.sin(a), zc + rng.uniform(-SECTION / 2, SECTION / 2)), streak, parent=env)
    light("Key", "POINT", (-2.5, -4.5, 3.0), "#e8e0ff", 700.0, shadow_soft_size=0.6)
    fog((30, 30, 30), (0, 0, 0), 0.006)
    cam, target = camera(26.0)
    K(cam, "location", 0.0, (0.0, -6.4, 1.9))
    K(target, "location", 0.0, (0.0, 0.0, 0.0))
    K(cam, "location", duration, (0.0, -4.6, 1.2))
    K(target, "location", duration, (0.0, 0.0, 0.0))
    travel = 6 * SECTION + 4.0
    frames = int(duration * FPS)
    for f in range(frames + 1):
        t = f / FPS
        falling = min(1.0, t / 4.5) ** 3
        K(env, "location", t, -3.0 + falling * travel, index=2)
        if f % 3 == 0:
            K(spinner, "rotation_euler", t, (math.radians(math.sin(t * 2.3) * 18), math.radians(math.sin(t * 1.7) * 22 + t * 25), math.radians(t * 40)))
    interpolation(env, "LINEAR")
    pixel_look()


# --- Ecran-titre : le reveur endormi sur son nuage (deux images fixes) ---------------------

def shot_titre(background=True):
    reset("intro_titre_fond" if background else "intro_titre_reveur", 1.0 / FPS)
    scene = bpy.context.scene
    scene.frame_end = 1
    set_world((0.16, 0.13, 0.36), 1.0)
    cam, target = camera(35.0)
    cam.location = (0.0, -9.0, 0.6)
    target.location = (0.0, 0.0, 0.6)
    if background:
        box("Sky", (60, 0.1, 30), (0, 20, 2), sky_mat("sky", "#2e2468", "#9f8ae0", 1.0, axis_span=0.5))
        rng = random.Random(5)
        stars = glow_mat("stars", "#fff0c0", 2.5)
        for i in range(70):
            sphere("Star", rng.uniform(0.03, 0.07), (rng.uniform(-13, 13), 18, rng.uniform(1.5, 9)), stars)
        sphere("HaloOuter", 3.5, (0, 16.5, -0.6), glow_mat("halo_outer", "#a996ea", 0.68), scale=(1.5, 0.3, 1.5))
        sphere("Halo", 2.6, (0, 16, -0.6), glow_mat("halo", "#c9b6ff", 0.75), scale=(1.5, 0.3, 1.5))
        sphere("HaloCore", 1.6, (0, 15.5, -0.6), glow_mat("halo_core", "#e4d8ff", 0.95), scale=(1.5, 0.3, 1.5))
        cloud_bank("CloudsFar", 10.0, -4.2, -16, 16, 1.6, 1.7, mat("title_cloud_far", "#8a7ad0", emission=0.45), 4)
        cloud_bank("CloudsNear", 3.0, -3.6, -12, 12, 1.3, 1.3, mat("title_cloud_near", "#cdc2f6", emission=0.5), 5)
        for sx in (-1, 1):
            cloud_bank("CloudsSide", 6.0, 2.6 + sx * 0.3, sx * 7.5 - 2.5, sx * 7.5 + 2.5, 1.1, 0.9, mat("title_cloud_far", "#8a7ad0", emission=0.45), 6 + sx)
        light("Top", "SUN", (0, -4, 10), "#e8dcff", 2.0)
    else:
        scene.render.film_transparent = True
        scene.render.image_settings.color_mode = "RGBA"
        d = dreamer("standing", "closed")
        d["root"].rotation_euler = (math.radians(-78), 0, math.radians(90))  # allonge sur le nuage, visage vers nous
        d["root"].location = (0.52, 0.0, -0.3)
        d["root"].scale = (1.5, 1.5, 1.5)
        d["head"].rotation_euler = (math.radians(-10), math.radians(20), 0)
        d["armL"].rotation_euler = (math.radians(-40), math.radians(-30), 0)
        d["legL"].rotation_euler = (math.radians(-35), 0, 0)
        cloud = mat("title_cloud", "#f3efff", emission=0.55)
        for x, z, r in ((-0.9, -0.62, 0.42), (-0.35, -0.7, 0.52), (0.3, -0.72, 0.5), (0.85, -0.64, 0.4), (0.0, -0.5, 0.45), (-0.6, -0.48, 0.34), (0.6, -0.5, 0.33)):
            sphere("Puff", r, (x, 0.15, z), cloud, scale=(1.25, 1.0, 0.72))
        key = light("Key", "SUN", (-3, -5, 8), "#fff4e0", 3.0)
        aim(key, (0, 0, 0))
        light("Rim", "POINT", (1.5, 2.0, 1.5), "#b9a0ff", 300.0)
    pixel_look(bloom=background)


def shot_titre_reveur():
    shot_titre(background=False)


SHOTS = {"chambre": shot_chambre, "voix": shot_voix, "soucis": shot_soucis, "horizon": shot_horizon,
         "fenetre": shot_fenetre, "chute": shot_chute, "titre_fond": shot_titre, "titre_reveur": shot_titre_reveur}



def build(names):
    os.makedirs(SCENES_DIR, exist_ok=True)
    for name in names:
        SHOTS[name]()
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SCENES_DIR, "intro_%s.blend" % name))


# --- Montage : les images rendues deviennent une video par plan ----------------------------
# Chaque video : liste de segments (scene, debut dans le plan en secondes, cles d'opacite).
# Les fondus enchaines entre deux decors d'un meme plan se font ici.

VIDEOS = {
    "intro_1_chambre": (13.5, [("chambre", 0.0, [])]),
    "intro_2_voix": (16.0, [("voix", 0.0, [(7.4, 1.0), (8.4, 0.0)]), ("soucis", SOUCIS_START, [(8.0, 0.0), (8.9, 1.0)])]),
    "intro_3_semaine": (17.5, [("horizon", 0.0, []), ("fenetre", FENETRE_START, [(7.4, 0.0), (8.2, 1.0), (12.6, 1.0), (13.4, 0.0)])]),
    "intro_4_chute": (4.8, [("chute", 0.0, [])]),
}
VIDEO_SCALE = 2  # 640x360 agrandi sans lissage : la couleur garde un echantillon par pixel de dessin
VIDEO_BITRATE = 3500  # kb/s


def assemble(frames_dir, out_dir, names):
    """frames_dir/<scene>/0001.png... -> out_dir/<video>.ogv (Ogg Theora, le format lu par Godot)."""
    os.makedirs(out_dir, exist_ok=True)
    for name in names:
        duration, parts = VIDEOS[name]
        reset(name, duration)
        scene = bpy.context.scene
        r = scene.render
        r.resolution_x, r.resolution_y = RES[0] * VIDEO_SCALE, RES[1] * VIDEO_SCALE
        r.use_sequencer = True
        scene.compositing_node_group = None
        editor = scene.sequence_editor_create()
        for strip in list(editor.strips):
            editor.strips.remove(strip)
        for channel, (shot, start, fades) in enumerate(parts, start=1):
            folder = os.path.join(frames_dir, shot)
            files = sorted(f for f in os.listdir(folder) if f.endswith(".png"))
            first = int(round(F(start)))
            files = files[:scene.frame_end - first + 1]
            strip = editor.strips.new_image(shot, os.path.join(folder, files[0]), channel, first)
            for f in files[1:]:
                strip.elements.append(f)
            strip.transform.scale_x = strip.transform.scale_y = VIDEO_SCALE
            strip.transform.filter = "NEAREST"
            strip.blend_type = "ALPHA_OVER"
            for t, alpha in fades:
                strip.blend_alpha = alpha
                strip.keyframe_insert("blend_alpha", frame=F(t))
        r.image_settings.media_type = "VIDEO"
        r.image_settings.file_format = "FFMPEG"
        r.ffmpeg.format = "OGG"
        r.ffmpeg.codec = "THEORA"
        r.ffmpeg.video_bitrate = VIDEO_BITRATE
        r.ffmpeg.minrate = 0
        r.ffmpeg.maxrate = VIDEO_BITRATE * 2
        r.ffmpeg.gopsize = 12
        r.ffmpeg.audio_codec = "NONE"
        r.use_file_extension = False
        r.filepath = os.path.join(out_dir, name + ".ogv")
        bpy.ops.render.render(animation=True)
        print("VIDEO", r.filepath, os.path.getsize(r.filepath))


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argv and argv[0] == "build":
        build(list(SHOTS) if argv[1:] in ([], ["all"]) else argv[1:])
    elif argv and argv[0] == "assemble":
        assemble(argv[1], argv[2], list(VIDEOS) if argv[3:] in ([], ["all"]) else argv[3:])
