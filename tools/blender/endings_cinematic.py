# Cinematiques de fin de nuit en 3D, rendues en pixel art comme l'intro (memes outils :
# tools/blender/intro_cinematic.py). Une video par nuit dans assets/cinematics/fins/, sur le texte
# de Story.ENDINGS ; durees et instants des phrases : scripts/story/endings.gd.
#
#   1. blender -b -P tools/blender/endings_cinematic.py -- build all
#   2. blender -b tools/blender/scenes/fin_lundi.blend -o IMAGES/lundi/#### -a     (une par scene)
#   3. blender -b -P tools/blender/endings_cinematic.py -- assemble IMAGES assets/cinematics/fins all
#   Essai d'une image : ... -- still <scene> <secondes> <fichier.png>
#
# Scenes : lundi, mardi, mercredi, jeudi, vendredi, samedi, puis aube et reveil pour le dimanche.
# Si un rendu en arriere-plan reste bloque (cache Vulkan), ajouter --gpu-backend opengl apres -b.
# Pas plus de quatre rendus a la fois : au-dela, la carte graphique sature et Blender plante.

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from intro_cinematic import *  # noqa: F401,F403  (outils, reveur, chambre, tours)
import intro_cinematic as base


# --- Outils propres aux fins ----------------------------------------------------------------

def text3d(name, body, size, loc, material, rot=(math.pi / 2, 0, 0), parent=None, extrude=0.008):
    """Texte en volume ; par defaut debout, face a la camera (-Y)."""
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = body
    curve.size = size
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.extrude = extrude
    ob = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = rot
    curve.materials.append(material)
    if parent:
        ob.parent = parent
    return ob


def sky_colors(material, t, top, bottom):
    node = material.node_tree.nodes["Gradient"]
    KS(node.inputs["A"], t, (*hexc(bottom), 1))
    KS(node.inputs["B"], t, (*hexc(top), 1))


def world_color(t, color, strength=1.0):
    bg = world_background()
    KS(bg.inputs["Color"], t, (*color, 1))
    KS(bg.inputs["Strength"], t, strength)


def pop(ob, t0, size=1.0, rise=0.3, overshoot=1.25):
    """Apparition avec un petit rebond."""
    K(ob, "scale", 0.0, (0, 0, 0))
    K(ob, "scale", t0, (0, 0, 0))
    K(ob, "scale", t0 + rise * 0.6, (size * overshoot,) * 3)
    K(ob, "scale", t0 + rise, (size,) * 3)


def walk(d, t0, t1, steps_per_second=2.0, arms=True, base_z=0.0):
    """Marche : jambes (et bras) qui balancent, petit rebond a chaque pas."""
    t = t0
    while t <= t1 + 1e-6:
        swing = math.sin((t - t0) * steps_per_second * math.pi)
        K(d["legL"], "rotation_euler", t, math.radians(28) * swing, index=0)
        K(d["legR"], "rotation_euler", t, -math.radians(28) * swing, index=0)
        if arms:
            K(d["armL"], "rotation_euler", t, -math.radians(22) * swing, index=0)
            K(d["armR"], "rotation_euler", t, math.radians(22) * swing, index=0)
        K(d["root"], "location", t, base_z + 0.035 * abs(swing), index=2)
        t += 1.0 / 12.0
    for part in ("legL", "legR") + (("armL", "armR") if arms else ()):
        K(d[part], "rotation_euler", t1 + 0.2, 0.0, index=0)
    K(d["root"], "location", t1 + 0.2, base_z, index=2)


def segment(name, p0, p1, thickness, material, parent=None):
    """Barre fine entre deux points (eclair)."""
    p0, p1 = Vector(p0), Vector(p1)
    ob = box(name, (thickness, thickness, (p1 - p0).length), tuple((p0 + p1) / 2), material, parent=parent)
    ob.rotation_euler = (p1 - p0).to_track_quat("Z", "Y").to_euler()
    return ob


def checker_mat(name, color_a, color_b, scale):
    """Damier au sol (X, Y du monde)."""
    m = mat(name, color_a)
    nt = m.node_tree
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    comb.inputs["Z"].default_value = 0.25 / scale
    checker = nt.nodes.new("ShaderNodeTexChecker")
    checker.inputs["Scale"].default_value = scale
    checker.inputs["Color1"].default_value = (*hexc(color_a), 1)
    checker.inputs["Color2"].default_value = (*hexc(color_b), 1)
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    nt.links.new(sep.outputs[0], comb.inputs["X"])
    nt.links.new(sep.outputs[1], comb.inputs["Y"])
    nt.links.new(comb.outputs[0], checker.inputs["Vector"])
    nt.links.new(checker.outputs["Color"], bsdf(m).inputs["Base Color"])
    return m


def close_eyes(d, t0, t1):
    """Les yeux ouverts s'aplatissent en paupieres closes."""
    for eye in d["eyes"]:
        K(eye, "scale", t0, tuple(eye.scale))
        K(eye, "scale", t1, (1.3, 0.45, 0.3))


# --- Lundi : les disputes derriere la porte se taisent, il s'endort enfin ---------------------

def fin_lundi():
    duration = 13.5
    reset("fin_lundi", duration)
    c = chambre()
    d = lying_dreamer("open")
    d["head"].rotation_euler = (math.radians(-8), math.radians(-10), math.radians(-50))  # visage vers nous
    cam, target = camera(35.0)
    K(cam, "location", 0.0, (0.25, -8.1, 1.55))
    K(target, "location", 0.0, (0.0, 0.0, 1.3))
    K(cam, "location", 12.5, (-1.1, -4.7, 1.32))
    K(target, "location", 12.5, (-1.5, -1.5, 0.98))
    night_levels(c, 0.0, 1.0)
    steady_veilleuse(c, duration)
    dx0, dx1, dh = DOOR
    c["door"].rotation_euler.z = -math.radians(13)  # porte entrebaillee sur la dispute
    quarrel = light("Quarrel", "POINT", (dx0 + 0.7, -0.7, 1.2), "#ff6e45", 0.0, shadow_soft_size=0.4)
    hall = c["hall_light"].data
    t = 0.0
    while t <= 7.2:  # la dispute gronde, puis se tait ; la lumiere du couloir s'eteint
        calm = ease((t - 4.6) / 2.2)
        anger = (1 - calm) * (0.55 + 0.45 * math.sin(t * 7.3) * math.sin(t * 2.1))
        K(hall, "energy", t, 460.0 * (1 - calm) * (0.7 + 0.3 * math.sin(t * 11)))
        K(quarrel.data, "energy", t, 130.0 * max(0.0, anger))
        t += 0.1
    # Les eclats de voix : des bulles de cri qui claquent a la porte, de plus en plus faibles.
    for i, (t0, size) in enumerate(((0.5, 1.0), (1.4, 1.0), (2.2, 0.9), (3.0, 0.8), (3.7, 0.6), (4.4, 0.4))):
        bubble = burst("Quarrel%d" % i, 0.3, (dx0 + 0.55 + 0.3 * (i % 3), -0.45 - 0.15 * (i % 2), 1.25 + 0.22 * ((i * 2) % 3)),
                       "#ffc9b0" if i % 2 else "#ffe9c8")
        bubble.rotation_euler = (0, 0.25 * (-1) ** i, 0)
        K(bubble, "scale", 0.0, (0, 0, 0))
        K(bubble, "scale", t0, (0, 0, 0))
        K(bubble, "scale", t0 + 0.15, (size,) * 3)
        K(bubble, "scale", t0 + 0.55, (size * 0.9,) * 3)
        K(bubble, "scale", t0 + 0.75, (0, 0, 0))
    close_eyes(d, 7.8, 8.7)
    # La respiration ralentit quand il s'endort.
    quilt = c["quilt"]
    base_scale = quilt.scale.z
    t, up = 0.0, False
    while t <= duration + 3.0:
        K(quilt, "scale", t, base_scale * (1.04 if up else 1.0), index=2)
        up = not up
        t += 1.5 if t < 7.8 else 2.5
    # Zzz.
    z_mat = glow_mat("zzz", "#e8e4ff", 1.6)
    head = Vector((PILLOW.x + 0.05, -1.75, 1.2))
    for k in range(3):
        z = text3d("Z%d" % k, "z", 0.2 + 0.07 * k, tuple(head), z_mat)
        t0 = 9.2 + k * 0.8
        K(z, "scale", 0.0, (0, 0, 0))
        K(z, "scale", t0, (0, 0, 0))
        K(z, "scale", t0 + 0.8, (1, 1, 1))
        K(z, "scale", t0 + 2.6, (0, 0, 0))
        K(z, "location", t0, tuple(head))
        K(z, "location", t0 + 2.6, tuple(head + Vector((0.55, 0, 0.8))))
    blink_colon(c["colon"], duration)
    drift_clouds(c["clouds"], duration)
    pixel_look()


# --- Mardi : une main pose une etoile doree sur la copie ratee -------------------------------

def fin_mardi():
    duration = 12.5
    reset("fin_mardi", duration)
    world_color(0.0, (0.02, 0.015, 0.04))
    world_color(6.7, (0.02, 0.015, 0.04))
    world_color(8.6, (0.09, 0.065, 0.045))
    box("Desk", (9, 7, 0.2), (0, 0.5, -0.1), mat("desk", "#6b4630"))
    for i in range(5):  # veines du bois
        box("Grain%d" % i, (9, 0.03, 0.2), (0, -1.9 + i * 1.25, -0.099), mat("desk_grain", "#5a3a28"))
    tilt = math.radians(-3)
    sheet = empty("Sheet", (0, 0.1, 0))
    sheet.rotation_euler = (0, 0, tilt)
    box("Paper", (1.5, 2.0, 0.012), (0, 0, 0.006), mat("paper", "#f3efe2"), parent=sheet)
    ink = mat("ink", "#8d8a9c")
    red = mat("red_pen", "#d8443f")
    rng = random.Random(4)
    for row in range(9):
        y = 0.52 - row * 0.15
        width = rng.uniform(0.7, 1.2)
        box("Line%d" % row, (width, 0.035, 0.004), (-0.62 + width / 2, y, 0.014), ink, parent=sheet)
        if row in (1, 3, 4, 6, 8):  # ratures rouges
            for a in (0.7, -0.7):
                box("Cross%d" % row, (0.16, 0.03, 0.004), (0.58, y, 0.016), red, rot=(0, 0, a), parent=sheet)
        if row in (2, 5):
            box("Strike%d" % row, (width * 0.8, 0.02, 0.004), (-0.62 + width / 2, y, 0.017), red, rot=(0, 0, 0.04), parent=sheet)
    text3d("Grade", "3/20", 0.3, (-0.36, 0.8, 0.014), red, rot=(0, 0, 0.12), parent=sheet, extrude=0.003)
    box("GradeLine", (0.6, 0.03, 0.004), (-0.36, 0.63, 0.015), red, rot=(0, 0, 0.1), parent=sheet)
    cyl("Pencil", 0.035, 1.0, (-1.25, -0.25, 0.035), mat("pencil", "#e8c35a"), rot=(math.pi / 2, 0, 0.35), segments=6)
    box("Eraser", (0.3, 0.15, 0.09), (1.2, -0.7, 0.045), mat("eraser", "#e89aa8"), rot=(0, 0, 0.5), bevel=0.02)
    spot = light("Spot", "SPOT", (0, -0.3, 4.2), "#cfd8ff", 900.0, spot_size=math.radians(32), spot_blend=0.6, shadow_soft_size=0.2)
    aim(spot, (0, 0.1, 0))
    for t, size, energy in ((0.0, 32, 900.0), (6.7, 32, 900.0), (8.6, 50, 760.0)):
        K(spot.data, "spot_size", t, math.radians(size))
        K(spot.data, "energy", t, energy)
    K(spot.data, "color", 6.7, hexc("#cfd8ff"))
    K(spot.data, "color", 8.6, hexc("#fff2de"))
    place = Vector((0.47, 0.9, 0.04))  # la ou l'etoile se pose
    # La main : paume, doigts, manche bleue qui sort du cadre a droite.
    hand = empty("Hand")
    skin = mat("skin", SKIN)
    sphere("Palm", 0.2, (0, 0, 0), skin, scale=(1.1, 0.85, 0.45), parent=hand)
    for k, y in enumerate((-0.1, 0.0, 0.1)):
        sphere("Finger%d" % k, 0.065, (-0.24, y, -0.03), skin, scale=(1.5, 1, 0.8), parent=hand)
    sphere("Thumb", 0.07, (-0.12, -0.19, -0.04), skin, scale=(1.3, 1, 0.8), parent=hand)
    cyl("Sleeve", 0.21, 3.6, (2.0, 0, 0.02), mat("sleeve", "#5a78c8"), rot=(0, math.pi / 2, 0), parent=hand)
    cyl("Cuff", 0.23, 0.14, (0.24, 0, 0.02), mat("cuff", "#eef0fa"), rot=(0, math.pi / 2, 0), parent=hand)
    away = Vector((4.6, 1.3, 0.5))
    grip = Vector((0.36, 0.0, 0.16))
    K(hand, "location", 0.0, tuple(away))
    K(hand, "location", 5.4, tuple(away))
    K(hand, "location", 6.6, tuple(place + grip))
    K(hand, "location", 7.0, tuple(place + grip + Vector((0, 0, 0.05))))
    K(hand, "location", 8.0, tuple(away + Vector((0.4, 0.1, 0))))
    gold = glow_mat("gold_star", "#ffb81e", 2.0)
    gold_star = star("GoldStar", 0.2, 0.1, 0.05, tuple(away - grip), gold, rot=(-math.pi / 2, 0, 0))
    K(gold_star, "location", 0.0, tuple(away - grip))
    K(gold_star, "location", 5.4, tuple(away - grip))
    K(gold_star, "location", 6.6, tuple(place))
    K(gold_star, "scale", 6.6, (0.85, 0.85, 0.85))
    K(gold_star, "scale", 6.8, (1.3, 1.3, 1.3))
    K(gold_star, "scale", 7.1, (1, 1, 1))
    t, big = 7.6, True
    while t <= duration:
        K(gold_star, "scale", t, (1.05,) * 3 if big else (1.0,) * 3)
        big = not big
        t += 1.0
    spark = glow_mat("spark", "#ffe7a0", 3.0)
    for i in range(10):
        a = i * math.pi / 5
        s = sphere("Spark%d" % i, 0.035, tuple(place), spark)
        K(s, "scale", 0.0, (0, 0, 0))
        K(s, "scale", 6.6, (0, 0, 0))
        K(s, "scale", 6.65, (1, 1, 1))
        K(s, "location", 6.6, tuple(place + Vector((0, 0, 0.05))))
        K(s, "location", 7.7, tuple(place + Vector((math.cos(a), math.sin(a), 0.1)) * 1.0))
        K(s, "scale", 7.7, (0, 0, 0))
    warm = light("Warm", "POINT", (0.47, 0.75, 1.0), "#ffd078", 0.0, shadow_soft_size=0.4)
    K(warm.data, "energy", 6.6, 0.0)
    K(warm.data, "energy", 8.4, 70.0)
    cam, target = camera(40.0)
    K(cam, "location", 0.0, (0.0, -3.2, 3.4))
    K(target, "location", 0.0, (0.0, 0.1, 0.0))
    K(cam, "location", 12.0, (0.12, -2.55, 2.75))
    K(target, "location", 12.0, (0.15, 0.28, 0.0))
    pixel_look()


# --- Mercredi : au carrefour, il hesite, puis choisit ; le chemin s'allume sous ses pas -------

def fin_mercredi():
    duration = 12.5
    reset("fin_mercredi", duration)
    set_world((0.04, 0.05, 0.085), 1.0)
    box("Ground", (80, 80, 0.2), (0, 10, -0.1), mat("crossroad_ground", "#232733"))
    moon = light("Moon", "SUN", (-6, -4, 10), "#8fa0e0", 1.3, volume_factor=0.25)
    aim(moon, (0, 2, 0))
    mist = fog((60, 60, 8), (0, 12, 4), 0.05)
    density = mist.data.materials[0].node_tree.nodes["Scatter"].inputs["Density"]
    KS(density, 0.0, 0.05)
    KS(density, 5.8, 0.05)
    KS(density, 8.6, 0.018)
    start = Vector((0.2, 0.0, 0.0))
    chosen = Vector((0.8, 0.6, 0.0)).normalized()
    speed = 0.95
    rng = random.Random(8)
    for name, direction in (("left", Vector((-0.8, 0.6, 0)).normalized()), ("middle", Vector((0, 1, 0))), ("right", chosen)):
        for i in range(13):
            dist = 0.9 + i * 0.75
            pos = start + direction * dist + Vector((rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), 0))
            if name == "right":  # le chemin choisi s'allume sous ses pas
                stone_mat = mat("stone_lit%d" % i, "#3a4050", emission=0.001, emit_color="#ffd98a")
                reach = 6.6 + max(0.0, dist - 0.35) / speed
                KS(emission_socket(stone_mat), 0.0, 0.0)
                KS(emission_socket(stone_mat), reach, 0.0)
                KS(emission_socket(stone_mat), reach + 0.35, 2.6)
            else:
                stone_mat = mat("stone", "#343a48")
            cyl("Stone_%s%d" % (name, i), rng.uniform(0.24, 0.32), 0.06, (pos.x, pos.y, 0.03), stone_mat, segments=7, rot=(0, 0, rng.uniform(0, 1)))
    # Le poteau du carrefour : trois pancartes, trois "?".
    wood = mat("sign_wood", "#6b4630")
    cyl("SignPole", 0.05, 1.7, (-0.75, 0.75, 0.85), wood)
    question = glow_mat("question", "#cfd4ff", 0.9)
    for k, (angle, z) in enumerate(((0.65, 1.55), (0.0, 1.3), (-0.65, 1.05))):
        board = empty("Board%d" % k, (-0.75, 0.75, z))
        board.rotation_euler = (0, 0, angle)
        box("Plank%d" % k, (0.7, 0.05, 0.2), (0, 0, 0), wood, parent=board)
        text3d("Q%d" % k, "?", 0.17, (0, -0.035, 0), question, parent=board)
    goal = light("Goal", "POINT", tuple(start + chosen * 10.5 + Vector((0, 0, 1.4))), "#ffc878", 0.0, shadow_soft_size=1.5, volume_factor=0.45)
    K(goal.data, "energy", 5.8, 0.0)
    K(goal.data, "energy", 8.6, 3200.0)
    d = dreamer("standing", "open")
    root = d["root"]
    root.location = tuple(start)
    facing_path = math.radians(126.87)  # face au chemin de droite
    K(root, "rotation_euler", 0.0, math.pi, index=2)  # dos a nous, face au carrefour
    K(root, "rotation_euler", 5.8, math.pi, index=2)
    K(root, "rotation_euler", 6.5, facing_path, index=2)
    side = 1
    K(d["head"], "rotation_euler", 0.0, 0.0, index=2)
    for t in (0.8, 2.1, 3.4, 4.7):  # il regarde a gauche, a droite
        K(d["head"], "rotation_euler", t, 0.95 * side, index=2)
        K(d["head"], "rotation_euler", t + 0.7, 0.95 * side, index=2)
        side = -side
    K(d["head"], "rotation_euler", 5.9, 0.0, index=2)
    end = start + chosen * speed * (duration - 6.6)
    for index in (0, 1):
        K(root, "location", 6.6, start[index], index=index)
        K(root, "location", duration, end[index], index=index)
    walk(d, 6.6, duration)
    interpolation(root, "LINEAR")
    cam, target = camera(35.0)
    K(cam, "location", 0.0, (-2.4, -6.2, 2.5))
    K(target, "location", 0.0, (0.5, 1.2, 0.8))
    K(cam, "location", 6.0, (-2.3, -6.0, 2.45))
    K(target, "location", 6.0, (0.6, 1.3, 0.8))
    K(cam, "location", duration, (-1.5, -5.4, 2.3))
    K(target, "location", duration, (2.3, 2.6, 0.8))
    pixel_look()


# --- Jeudi : l'orage de colere gronde sur la fournaise, puis passe ---------------------------

BOLTS = (1.4, 2.9, 4.3)


def fin_jeudi():
    duration = 12.5
    reset("fin_jeudi", duration)
    world_color(0.0, (0.09, 0.025, 0.02))
    world_color(5.8, (0.09, 0.025, 0.02))
    world_color(8.8, (0.2, 0.2, 0.3))
    sky_material = sky_mat("sky", "#1a0a14", "#7a2418", 1.0, axis_span=0.5)
    box("Sky", (140, 0.1, 70), (0, 40, 12), sky_material)
    sky_colors(sky_material, 0.0, "#1a0a14", "#7a2418")
    sky_colors(sky_material, 5.8, "#1a0a14", "#7a2418")
    sky_colors(sky_material, 8.8, "#4a66b0", "#f6c4a4")
    box("Ground", (80, 60, 0.2), (0, 10, -0.1), mat("ash_ground", "#4a3838"))
    rng = random.Random(12)
    for i in range(7):  # collines au loin
        sphere("Hill%d" % i, rng.uniform(5, 9), (-30 + i * 10 + rng.uniform(-2, 2), rng.uniform(22, 30), -2.5), mat("hill", "#5d5470"), scale=(1.6, 1, 0.55))
    # La fournaise : briques, gueule rougeoyante, cheminee.
    brick = mat("furnace_brick", "#7a3a30")
    box("Furnace", (2.4, 1.8, 2.5), (1.9, 1.2, 1.25), brick, bevel=0.04)
    box("FurnaceTop", (2.7, 2.1, 0.25), (1.9, 1.2, 2.6), mat("furnace_dark", "#4a2420"))
    cyl("Chimney", 0.34, 2.2, (2.5, 1.4, 3.8), mat("furnace_dark", "#4a2420"))
    for k in range(4):
        box("BrickLine%d" % k, (2.42, 0.02, 0.03), (1.9, 0.29, 0.5 + k * 0.5), mat("furnace_dark", "#4a2420"))
    fire = glow_mat("fire", "#ff7a2e", 4.0)
    box("Mouth", (1.2, 0.1, 0.9), (1.9, 0.28, 0.75), fire, bevel=0.2)
    box("MouthFrame", (1.5, 0.08, 1.15), (1.9, 0.31, 0.82), mat("furnace_dark", "#4a2420"), bevel=0.22)
    fire_light = light("FireLight", "POINT", (1.9, -0.6, 0.9), "#ff6a2a", 900.0, shadow_soft_size=0.5)
    for t, glow_level, energy in ((0.0, 4.0, 900.0), (5.8, 4.0, 900.0), (9.0, 0.5, 70.0)):
        KS(glow_strength(fire), t, glow_level)
        K(fire_light.data, "energy", t, energy)
    t = 0.0
    while t < 5.8:  # le feu ronfle
        K(fire_light.data, "energy", t, 900.0 * (0.8 + 0.2 * math.sin(t * 5)))
        t += 0.2
    # L'orage : un nuage noir, trois eclairs, puis il s'eloigne.
    storm = empty("Storm", (0.6, 2.0, 5.2))
    cloud = mat("storm_cloud", "#2c2436")
    for i in range(11):
        sphere("StormPuff%d" % i, rng.uniform(1.0, 1.7), (rng.uniform(-3.4, 3.4), rng.uniform(-0.8, 0.8), rng.uniform(-0.4, 0.5)), cloud, scale=(1.5, 1, 0.75), parent=storm)
    K(storm, "location", 5.8, (0.6, 2.0, 5.2))
    K(storm, "location", 9.6, (16.0, 6.0, 9.0))
    K(storm, "scale", 5.8, (1, 1, 1))
    K(storm, "scale", 9.6, (0.5, 0.5, 0.5))
    flash = light("Flash", "SUN", (0, -6, 10), "#fff6d8", 0.0)
    aim(flash, (0.5, 0, 0))
    K(flash.data, "energy", 0.0, 0.0)
    bolt_mat = glow_mat("bolt", "#fff6c8", 9.0)
    for b, t0 in enumerate(BOLTS):
        root = empty("Bolt%d" % b)
        x = (-3.6, 0.3, 4.3)[b]
        points = [(x, 1.6, 4.6), (x + 0.5, 1.5, 3.5), (x - 0.2, 1.4, 2.5), (x + 0.4, 1.3, 1.4), (x, 1.2, 0.0)]
        for k in range(4):
            segment("Bolt%d_%d" % (b, k), points[k], points[k + 1], 0.09, bolt_mat, parent=root)
        K(root, "scale", 0.0, (0, 0, 0))
        K(root, "scale", t0, (1, 1, 1))
        K(root, "scale", t0 + 0.2, (0, 0, 0))
        interpolation(root, "CONSTANT")
        K(flash.data, "energy", t0 - 0.02, 0.0)
        K(flash.data, "energy", t0, 7.0)
        K(flash.data, "energy", t0 + 0.22, 0.0)
    # La vapeur se leve sur un ciel lave.
    steam = glow_mat("steam", "#f0f0ff", 0.85)
    for i in range(9):
        puff = sphere("Steam%d" % i, rng.uniform(0.45, 0.8), (0, 0, 0), steam)
        t0 = 5.0 + i * 0.4
        x0 = 1.9 + rng.uniform(-1.0, 1.0)
        K(puff, "scale", 0.0, (0, 0, 0))
        K(puff, "scale", t0, (0, 0, 0))
        K(puff, "scale", t0 + 1.2, (1.2, 1.0, 1.0))
        K(puff, "scale", t0 + 4.2, (0, 0, 0))
        K(puff, "location", t0, (x0, 0.6, 2.6))
        K(puff, "location", t0 + 4.2, (x0 + rng.uniform(-1.5, 1.5), 0.8, 8.0))
    dawn = light("Dawn", "SUN", (-8, -6, 8), "#ffe2c8", 0.0)
    aim(dawn, (0.5, 0, 1))
    K(dawn.data, "energy", 5.8, 0.0)
    K(dawn.data, "energy", 9.0, 2.6)
    # Lui : les poings serres face a la fournaise, puis il lache prise et leve la tete.
    d = dreamer("standing", "open")
    d["root"].location = (-1.2, -0.3, 0.0)
    d["root"].rotation_euler = (0, 0, math.radians(70))  # tourne vers la fournaise
    tense = {"armL": (math.radians(-18), math.radians(32), 0), "armR": (math.radians(-18), math.radians(-32), 0)}
    loose = {"armL": (0, math.radians(10), 0), "armR": (0, math.radians(-10), 0)}
    for part in ("armL", "armR"):
        K(d[part], "rotation_euler", 0.0, tense[part])
        K(d[part], "rotation_euler", 6.3, tense[part])
        K(d[part], "rotation_euler", 8.4, loose[part])
    K(d["head"], "rotation_euler", 0.0, (math.radians(14), 0, 0))
    K(d["head"], "rotation_euler", 6.6, (math.radians(14), 0, 0))
    K(d["head"], "rotation_euler", 9.0, (math.radians(-16), 0, 0))
    shake = empty("Shake")
    cam, target = camera(32.0)
    cam.parent = shake
    K(cam, "location", 0.0, (-0.6, -7.8, 1.9))
    K(target, "location", 0.0, (0.5, 0.0, 1.7))
    K(cam, "location", duration, (-0.3, -7.0, 1.8))
    K(target, "location", duration, (0.4, 0.0, 1.75))
    t = 0.0
    while t < 8.8:  # la colere fait trembler l'image
        anger = 1.0 - ease((t - 5.8) / 2.8)
        K(shake, "location", t, (math.sin(t * 37) * 0.035 * anger, 0, math.cos(t * 29) * 0.035 * anger))
        t += 1.0 / 12.0
    K(shake, "location", 8.9, (0, 0, 0))
    pixel_look()


# --- Vendredi : charge de cartons, il les pose et s'assoit enfin -----------------------------

def fin_vendredi():
    duration = 13.5
    reset("fin_vendredi", duration)
    set_world((0.3, 0.2, 0.18), 1.0)
    box("Sky", (140, 0.1, 70), (0, 40, 12), sky_mat("sky", "#4a3a86", "#ffac6a", 1.0, axis_span=0.45))
    sun_mat = glow_mat("sunset_sun", "#ffd9a0", 1.3)
    sphere("Sun", 5.0, (-4, 38, 3.2), sun_mat)
    KS(glow_strength(sun_mat), 6.0, 1.3)
    KS(glow_strength(sun_mat), 12.0, 2.0)
    box("Ground", (90, 70, 0.2), (0, 14, -0.1), mat("dusk_ground", "#6e4c4e"))
    rng = random.Random(15)
    card_a, card_b = mat("mountain_a", "#a87d4a"), mat("mountain_b", "#96703f")
    for i in range(46):  # la montagne de cartons, au loin
        x = rng.uniform(-16, 16)
        y = rng.uniform(13, 24)
        height = max(0.5, 3.6 - abs(x - 7) * 0.32 + rng.uniform(-0.8, 0.8)) if x > -1 else rng.uniform(0.4, 1.1)
        size = rng.uniform(1.4, 2.8)
        box("Mountain%d" % i, (size, size * 0.9, height), (x, y, height / 2), card_a if i % 2 else card_b, rot=(0, 0, rng.uniform(-0.3, 0.3)))
    sunset = light("Sunset", "SUN", (-6, 12, 5), "#ffb070", 2.2)
    aim(sunset, (0, 0, 0.5))
    K(sunset.data, "energy", 6.0, 2.2)
    K(sunset.data, "energy", 12.0, 3.4)
    front = light("Front", "SUN", (2, -8, 5), "#ffd9c0", 1.1)
    aim(front, (0, 0, 0.8))
    # Le banc.
    wood = mat("bench_wood", "#7a5236")
    box("BenchSeat", (1.8, 0.5, 0.08), (0.2, 0.1, 0.42), wood)
    box("BenchBack", (1.8, 0.07, 0.42), (0.2, 0.36, 0.78), wood)
    for sx in (-0.7, 1.1):
        box("BenchLeg", (0.08, 0.5, 0.42), (sx, 0.1, 0.21), mat("bench_iron", "#3a3440"))
        box("BenchPost", (0.08, 0.07, 0.6), (sx, 0.36, 0.7), mat("bench_iron", "#3a3440"))
    card = mat("w_box", "#c79a5e")
    tape = mat("tape", "#e2c488")

    def carton(name, size, loc, parent, rot=0.0):
        box(name, size, loc, card, rot=(0, 0, rot), parent=parent, bevel=0.015)
        box(name + "_tape", (size[0] * 0.14, size[1] + 0.01, size[2] + 0.01), loc, tape, rot=(0, 0, rot), parent=parent)

    d = dreamer("standing", "closed")
    root = d["root"]
    carried = empty("Carried", (0, -0.36, 0), parent=root)
    for k, z in enumerate((0.5, 0.8, 1.08)):
        carton("Carry%d" % k, (0.42, 0.36, 0.27), (0.02 * k, 0, z), carried, rot=0.12 * (k - 1))
    stack = empty("Stack", (-1.55, 0.05, 0))
    for k, z in enumerate((0.14, 0.42, 0.7)):
        carton("Stacked%d" % k, (0.42, 0.36, 0.27), (0.03 * (k % 2), 0, z), stack, rot=0.2 * (k - 1))
    for part in ("armL", "armR"):
        K(d[part], "rotation_euler", 0.0, (math.radians(-75), 0, 0))
        K(d[part], "rotation_euler", 5.4, (math.radians(-75), 0, 0))
        K(d[part], "rotation_euler", 6.3, (math.radians(-14), 0, 0))
    # Il arrive de la gauche, pose ses cartons, s'assoit face a nous.
    K(root, "rotation_euler", 0.0, math.radians(90), index=2)
    K(root, "rotation_euler", 5.5, math.radians(90), index=2)
    K(root, "rotation_euler", 6.2, 0.0, index=2)
    K(root, "location", 0.0, (-7.2, -0.35, 0.0))
    walk(d, 0.0, 5.2, arms=False)
    K(root, "location", 5.2, -0.9, index=0)
    K(root, "location", 5.5, -0.9, index=0)
    K(root, "location", 6.3, -0.1, index=0)
    K(root, "location", 5.5, -0.35, index=1)
    K(root, "location", 6.3, 0.05, index=1)
    K(root, "location", 5.6, 0.0, index=2)
    K(root, "location", 6.3, 0.14, index=2)
    for part in ("legL", "legR"):
        K(d[part], "rotation_euler", 5.6, 0.0, index=0)
        K(d[part], "rotation_euler", 6.3, math.radians(-80), index=0)
    K(carried, "scale", 5.35, (1, 1, 1))
    K(carried, "scale", 5.5, (0, 0, 0))
    K(stack, "scale", 0.0, (0, 0, 0))
    K(stack, "scale", 5.35, (0, 0, 0))
    K(stack, "scale", 5.5, (1, 1, 1))
    # Il souffle : la tete se releve vers le ciel.
    K(d["head"], "rotation_euler", 0.0, (math.radians(10), 0, 0))
    K(d["head"], "rotation_euler", 6.4, (math.radians(10), 0, 0))
    K(d["head"], "rotation_euler", 9.0, (math.radians(-10), 0, 0))
    breathing(d["torso"], duration, period=3.2, amount=0.03)
    # Un the fumant a cote de lui.
    tea = empty("Tea", (0.7, 0.08, 0.46))
    cyl("Cup", 0.1, 0.16, (0, 0, 0.08), mat("cup", "#f3efe2"), parent=tea, radius_top=0.115)
    cyl("TeaSurface", 0.1, 0.01, (0, 0, 0.158), mat("tea", "#b8703a"), parent=tea)
    sphere("CupHandle", 0.05, (0.13, 0, 0.08), mat("cup", "#f3efe2"), scale=(1, 0.5, 1.2), parent=tea)
    pop(tea, 7.6, rise=0.5)
    steam = glow_mat("tea_steam", "#ffffff", 0.9)
    for k in range(3):
        puff = sphere("TeaSteam%d" % k, 0.045, (0, 0, 0), steam, parent=tea)
        K(puff, "scale", 0.0, (0, 0, 0))
        t0 = 8.2 + k * 0.7
        while t0 < duration:
            K(puff, "scale", t0, (0, 0, 0))
            K(puff, "location", t0, (0.02 * (k - 1), 0, 0.2))
            K(puff, "scale", t0 + 1.0, (1, 1, 1.6))
            K(puff, "location", t0 + 2.0, (0.05 * (k - 1), 0, 0.75))
            K(puff, "scale", t0 + 2.0, (0, 0, 0))
            t0 += 2.1
    cam, target = camera(35.0)
    K(cam, "location", 0.0, (-0.6, -8.8, 1.6))
    K(target, "location", 0.0, (-1.0, 0.0, 1.0))
    K(cam, "location", 6.0, (-0.3, -8.2, 1.5))
    K(target, "location", 6.0, (-0.3, 0.0, 0.95))
    K(cam, "location", 12.5, (0.2, -5.6, 1.3))
    K(target, "location", 12.5, (0.1, 0.0, 0.95))
    pixel_look()


# --- Samedi : la salle de bal vide se remplit de silhouettes lumineuses ----------------------

def dancer(name, material):
    """Silhouette lumineuse : une robe, un buste, une tete, deux bras leves."""
    root = empty(name)
    cyl("Dress", 0.36, 0.9, (0, 0, 0.45), material, radius_top=0.1, parent=root)
    sphere("Chest", 0.14, (0, 0, 0.98), material, scale=(1, 0.8, 1.2), parent=root)
    sphere("Head", 0.13, (0, 0, 1.3), material, parent=root)
    for sx in (-1, 1):
        cyl("Arm", 0.035, 0.5, (sx * 0.28, 0, 1.2), material, rot=(0, sx * math.radians(-50), 0), parent=root)
    return root


def fin_samedi():
    duration = 13.5
    reset("fin_samedi", duration)
    world_color(0.0, (0.03, 0.035, 0.08))
    world_color(6.0, (0.03, 0.035, 0.08))
    world_color(8.6, (0.16, 0.12, 0.09))
    box("Floor", (30, 26, 0.2), (0, 2, -0.1), checker_mat("ballroom_floor", "#3a3458", "#57507a", 1.1))
    wall = mat("ballroom_wall", "#2c2646")
    box("BackWall", (30, 0.3, 9), (0, 8, 4.5), wall)
    for sx in (-1, 1):
        box("SideWall", (0.3, 26, 9), (sx * 12, 2, 4.5), wall)
    pane = glow_mat("pane", "#8fa8e8", 1.1)
    for x in (-6.5, 0.0, 6.5):  # hautes fenetres sur la nuit
        box("Window", (1.7, 0.1, 4.2), (x, 7.8, 3.2), pane)
        sphere("WindowArch", 0.85, (x, 7.8, 5.3), pane, scale=(1, 0.06, 1))
        box("WindowBarV", (0.07, 0.14, 5.0), (x, 7.75, 3.5), wall)
        for z in (2.2, 3.6, 5.0):
            box("WindowBarH", (1.7, 0.14, 0.07), (x, 7.75, z), wall)
    column = mat("column", "#4a4468")
    for x in (-9.6, -3.25, 3.25, 9.6):
        cyl("Column", 0.34, 8.0, (x, 7.0, 4.0), column)
        box("ColumnBase", (0.9, 0.9, 0.3), (x, 7.0, 0.15), column)
    moons = []
    for x in (-6.5, 6.5):
        moon = light("MoonBeam", "SPOT", (x, 7.4, 6.5), "#8fa8ff", 9000.0, spot_size=math.radians(40), spot_blend=0.5, volume_factor=0.5, shadow_soft_size=0.4)
        aim(moon, (x * 0.35, 0.5, 0))
        moons.append(moon)
        K(moon.data, "energy", 6.0, 9000.0)
        K(moon.data, "energy", 8.6, 3200.0)
    fog((24, 22, 8), (0, 2, 4), 0.012)
    # Le lustre s'allume.
    gold = mat("lustre_gold", "#b8904a")
    cyl("Chain", 0.03, 3.0, (0, 1.0, 7.0), gold)
    cyl("LustreRing", 1.0, 0.1, (0, 1.0, 5.4), gold, segments=24)
    cyl("LustreRingSmall", 0.55, 0.1, (0, 1.0, 5.75), gold, segments=20)
    bulb = glow_mat("bulb", "#ffe2a0", 0.06)
    for k in range(8):
        a = TAU * k / 8
        sphere("Bulb%d" % k, 0.12, (math.cos(a) * 1.0, 1.0 + math.sin(a) * 1.0, 5.55), bulb)
    lustre = light("Lustre", "POINT", (0, 1.0, 4.9), "#ffdc96", 0.0, shadow_soft_size=0.8, volume_factor=0.25)
    for t, level, energy in ((0.0, 0.06, 0.0), (6.0, 0.06, 0.0), (8.6, 3.2, 4200.0)):
        KS(glow_strength(bulb), t, level)
        K(lustre.data, "energy", t, energy)
    # Lui, seul au milieu ; puis il releve la tete et se laisse bercer.
    d = dreamer("standing", "open")
    hug = {"armL": (math.radians(-58), math.radians(-42), 0), "armR": (math.radians(-58), math.radians(42), 0)}
    free = {"armL": (0, math.radians(26), 0), "armR": (0, math.radians(-26), 0)}
    for part in ("armL", "armR"):
        K(d[part], "rotation_euler", 0.0, hug[part])
        K(d[part], "rotation_euler", 7.0, hug[part])
        K(d[part], "rotation_euler", 9.0, free[part])
    K(d["head"], "rotation_euler", 0.0, (math.radians(24), 0, 0))
    K(d["head"], "rotation_euler", 6.4, (math.radians(24), 0, 0))
    K(d["head"], "rotation_euler", 8.4, (math.radians(-8), 0, 0))
    t, side = 8.0, 1
    K(d["root"], "rotation_euler", 8.0, 0.0, index=1)
    while t < duration:
        t += 1.57
        K(d["root"], "rotation_euler", t, math.radians(4) * side, index=1)
        side = -side
    # Les silhouettes : une a une, elles entrent dans la danse autour de lui.
    for k in range(4):
        shine = glow_mat("dancer%d" % k, "#ffe6b0", 0.0)
        figure = dancer("Dancer%d" % k, shine)
        glow_light = light("DancerGlow%d" % k, "POINT", (0, -0.3, 1.0), "#ffdca0", 0.0, parent=figure, shadow_soft_size=0.4)
        t0 = 6.2 + k * 0.6
        KS(glow_strength(shine), 0.0, 0.0)
        KS(glow_strength(shine), t0, 0.0)
        KS(glow_strength(shine), t0 + 1.4, 1.7)
        K(glow_light.data, "energy", t0, 0.0)
        K(glow_light.data, "energy", t0 + 1.4, 90.0)
        K(figure, "scale", 0.0, (0, 0, 0))
        K(figure, "scale", t0, (0, 0, 0))
        K(figure, "scale", t0 + 0.9, (1, 1, 1))
        step = 0
        while step / 6.0 <= duration:
            t = step / 6.0
            a = t * 0.55 + k * math.pi / 2
            K(figure, "location", t, (math.cos(a) * 2.5, math.sin(a) * 2.1, 0.0))
            K(figure, "rotation_euler", t, (0, math.sin(t * 2 + k) * 0.1, t * 1.4 + k))
            step += 1
    mote = glow_mat("mote", "#ffe6b0", 0.0)
    KS(glow_strength(mote), 6.0, 0.0)
    KS(glow_strength(mote), 8.5, 2.2)
    rng = random.Random(19)
    for i in range(16):
        speck = sphere("Mote%d" % i, 0.03, (0, 0, 0), mote)
        x, y, z = rng.uniform(-5, 5), rng.uniform(-3, 4), rng.uniform(0.2, 3.5)
        K(speck, "location", 0.0, (x, y, z))
        K(speck, "location", duration, (x + rng.uniform(-0.4, 0.4), y, z + 2.2))
        interpolation(speck, "LINEAR")
    cam, target = camera(30.0)
    K(cam, "location", 0.0, (-1.8, -9.6, 2.9))
    K(target, "location", 0.0, (0.0, 0.6, 1.3))
    K(cam, "location", duration, (1.6, -7.4, 2.1))
    K(target, "location", duration, (0.0, 0.3, 1.1))
    pixel_look()


# --- Dimanche : l'aube se leve, les sept tours se dissolvent, il se reveille ------------------

REVEIL_START = 12.0


def fin_aube():
    duration = 13.4
    reset("fin_aube", duration)
    world_color(0.0, (0.05, 0.04, 0.12))
    world_color(6.0, (0.05, 0.04, 0.12))
    world_color(11.0, (0.42, 0.34, 0.33))
    sky_material = sky_mat("sky", "#05040f", "#2a1c4a", 1.0, axis_span=0.5)
    box("Sky", (150, 0.1, 70), (10, 45, 14), sky_material)
    sky_colors(sky_material, 0.0, "#05040f", "#2a1c4a")
    sky_colors(sky_material, 6.0, "#05040f", "#2a1c4a")
    sky_colors(sky_material, 11.5, "#86aee6", "#ffdcaa")
    rng = random.Random(11)
    stars = glow_mat("stars", "#e4e8ff", 3.0)
    KS(glow_strength(stars), 6.0, 3.0)
    KS(glow_strength(stars), 9.0, 0.0)
    for i in range(90):
        speck = sphere("Star%d" % i, rng.uniform(0.05, 0.11), (rng.uniform(-30, 50), 44, rng.uniform(6, 40)), stars)
        K(speck, "scale", 8.8, (1, 1, 1))
        K(speck, "scale", 9.2, (0, 0, 0))
    sun_mat = glow_mat("dawn_sun", "#fff0c0", 2.4)
    sun = sphere("Sun", 4.5, (5, 42, -7), sun_mat)
    K(sun, "location", 6.0, -7.0, index=2)
    K(sun, "location", 13.0, 8.5, index=2)
    towers = week_towers(empty("Towers"), spacing=3.3)
    far = cloud_bank("CloudsFar", 7.0, 0.6, -45, 65, 2.4, 2.4, mat("cloud_far", "#6f66b4", emission=0.25), 1)
    mid = cloud_bank("CloudsMid", -2.6, 0.2, -40, 60, 1.5, 1.5, mat("cloud_mid", "#a59be0", emission=0.22), 2)
    near = cloud_bank("CloudsNear", -8.5, -1.3, -40, 60, 1.9, 2.0, mat("cloud_near", "#c9c0f2", emission=0.2), 3)
    for bank, speed in ((far, 0.25), (mid, 0.45), (near, 0.75)):
        K(bank, "location", 0.0, 0.0, index=0)
        K(bank, "location", duration, -speed * duration, index=0)
        interpolation(bank, "LINEAR")
    night = light("Night", "SUN", (30, -12, 12), "#5a6ad0", 1.1)
    aim(night, (10, 0, 2))
    dawn = light("Dawn", "SUN", (2, 30, 5), "#ffd9a0", 0.0)  # contre-jour dore
    aim(dawn, (10, 0, 3))
    front = light("Front", "SUN", (10, -20, 10), "#ffe6d8", 0.0)
    aim(front, (10, 0, 3))
    for lamp, energy in ((dawn, 3.4), (front, 1.5)):
        K(lamp.data, "energy", 6.0, 0.0)
        K(lamp.data, "energy", 11.0, energy)
    # Une a une, les tours se dissolvent dans la lumiere.
    mote = glow_mat("dawn_mote", "#fff0c8", 3.0)
    for k, pivot in enumerate(towers):
        t0 = 9.0 + k * 0.4
        x = pivot.location.x
        K(pivot, "scale", t0, (1, 1, 1))
        K(pivot, "scale", t0 + 1.6, (0.0, 0.0, 1.5))
        K(pivot, "location", t0, 0.0, index=2)
        K(pivot, "location", t0 + 1.6, 1.4, index=2)
        halo = light("Dissolve%d" % k, "POINT", (x, -2.4, 3.6), "#fff0c8", 0.0, shadow_soft_size=0.8)
        K(halo.data, "energy", t0, 0.0)
        K(halo.data, "energy", t0 + 0.8, 2600.0)
        K(halo.data, "energy", t0 + 1.8, 0.0)
        for j in range(4):
            speck = sphere("Mote%d_%d" % (k, j), 0.13, (0, 0, 0), mote)
            start = t0 + 0.2 + j * 0.3
            x0 = x + math.sin(k * 1.7 + j * 2.1) * 0.6
            K(speck, "scale", 0.0, (0, 0, 0))
            K(speck, "scale", start, (0, 0, 0))
            K(speck, "scale", start + 0.5, (1, 1, 1))
            K(speck, "scale", start + 2.8, (0, 0, 0))
            K(speck, "location", start, (x0, -1.0, 1.6 + j * 1.3))
            K(speck, "location", start + 2.8, (x0 + math.sin(j + k) * 0.8, -1.0, 7.5 + j))
    cam, target = camera(30.0)
    K(cam, "location", 0.0, (9.9, -25.5, 4.4))
    K(target, "location", 0.0, (9.9, 0.0, 4.2))
    K(cam, "location", duration, (9.9, -22.5, 4.7))
    K(target, "location", duration, (9.9, 0.0, 4.6))
    pixel_look()


def fin_reveil():
    duration = 6.1
    reset("fin_reveil", duration)
    c = chambre(clock="0700")
    # Le matin : ciel clair, soleil par la fenetre, plus de lune ni d'etoiles, veilleuse eteinte.
    for ob in bpy.data.objects:
        if ob.name.startswith(("Star", "Moon")) and ob.type == "MESH":
            ob.hide_render = True
    gradient = c["sky"].data.materials[0].node_tree.nodes["Gradient"]
    gradient.inputs["A"].default_value = (*hexc("#ffe9c4"), 1)
    gradient.inputs["B"].default_value = (*hexc("#8fc4f0"), 1)
    cloud_emission = c["cloud_mat"].node_tree.nodes["Emission"]
    cloud_emission.inputs["Color"].default_value = (*hexc("#ffffff"), 1)
    cloud_emission.inputs["Strength"].default_value = 1.05
    set_world((0.55, 0.5, 0.45), 1.0)
    sun = c["moon_light"].data
    sun.color = hexc("#ffdca8")
    sun.energy = 17000.0
    c["fill"].data.color = hexc("#fff0dc")
    c["fill"].data.energy = 1500.0
    glow_strength(c["digits_mat"]).default_value = 4.0
    c["clock_light"].data.energy = 0.3
    glow_strength(c["veilleuse_mat"]).default_value = 0.0
    c["veilleuse"].data.materials[0] = mat("veilleuse_off", "#f3e6cc")
    c["quilt"].location.x += 0.25
    # Il se redresse dans son lit, s'etire, et regarde le jour par la fenetre.
    d = dreamer("standing", "open")
    d["root"].location = (PILLOW.x + 0.5, -1.5, 0.52)
    for part in ("legL", "legR"):
        d[part].rotation_euler = (0, math.radians(-90), 0)  # jambes allongees sous la couette
    sphere("Smile", 0.022, (0, -0.183, -0.005), mat("eye", "#2a1c1c"), scale=(1.9, 0.5, 0.55), parent=d["head"])
    rest = {"armL": (0, math.radians(14), 0), "armR": (0, math.radians(-14), 0)}
    high = {"armL": (0, math.radians(152), 0), "armR": (0, math.radians(-152), 0)}
    for part in ("armL", "armR"):
        K(d[part], "rotation_euler", 0.2, rest[part])
        K(d[part], "rotation_euler", 1.5, high[part])
        K(d[part], "rotation_euler", 2.7, high[part])
        K(d[part], "rotation_euler", 3.7, rest[part])
    K(d["head"], "rotation_euler", 0.2, (0, 0, 0))
    K(d["head"], "rotation_euler", 1.6, (math.radians(-18), 0, 0))
    K(d["head"], "rotation_euler", 2.7, (math.radians(-18), 0, 0))
    K(d["head"], "rotation_euler", 3.8, (0, 0, 0))
    K(d["head"], "rotation_euler", 5.0, (0, 0, math.radians(38)))  # vers la fenetre
    blink_colon(c["colon"], duration)
    drift_clouds(c["clouds"], duration)
    cam, target = camera(35.0)
    K(cam, "location", 0.0, (-0.4, -6.8, 1.6))
    K(target, "location", 0.0, (-0.7, -1.2, 1.25))
    K(cam, "location", duration, (-0.7, -5.5, 1.5))
    K(target, "location", duration, (-0.9, -1.3, 1.25))
    pixel_look()


SHOTS = {"lundi": fin_lundi, "mardi": fin_mardi, "mercredi": fin_mercredi, "jeudi": fin_jeudi,
         "vendredi": fin_vendredi, "samedi": fin_samedi, "aube": fin_aube, "reveil": fin_reveil}
VIDEOS = {
    "fin_lundi": (13.5, [("lundi", 0.0, [])]),
    "fin_mardi": (12.5, [("mardi", 0.0, [])]),
    "fin_mercredi": (12.5, [("mercredi", 0.0, [])]),
    "fin_jeudi": (12.5, [("jeudi", 0.0, [])]),
    "fin_vendredi": (13.5, [("vendredi", 0.0, [])]),
    "fin_samedi": (13.5, [("samedi", 0.0, [])]),
    "fin_dimanche": (18.0, [("aube", 0.0, []), ("reveil", REVEIL_START, [(12.0, 0.0), (13.2, 1.0)])]),
}
BITRATE = 2600  # kb/s : sept videos, on reste raisonnable en poids


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argv and argv[0] == "build":
        base.build(list(SHOTS) if argv[1:] in ([], ["all"]) else argv[1:], SHOTS, "fin_")
    elif argv and argv[0] == "assemble":
        base.assemble(argv[1], argv[2], list(VIDEOS) if argv[3:] in ([], ["all"]) else argv[3:], VIDEOS, BITRATE)
    elif argv and argv[0] == "still":  # still <scene> <secondes> <fichier.png> [<secondes> <fichier.png> ...]
        SHOTS[argv[1]]()
        scene = bpy.context.scene
        for i in range(2, len(argv) - 1, 2):
            scene.frame_set(int(round(F(float(argv[i])))))
            scene.render.filepath = argv[i + 1]
            bpy.ops.render.render(write_still=True)
