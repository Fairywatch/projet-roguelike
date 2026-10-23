class_name Intro
extends RefCounted

# L'intro, en quatre plans (animatiques 01 a 04) : la veilleuse et la chambre, les voix et les
# soucis, la semaine et les paupieres, la plongee et le titre. Texte : Story.INTRO.

static func shots() -> Array[Shot]:
	return [Bedroom.new(), Voices.new(), Week.new(), Dive.new()]

const BEAM := [Vector2(760, 108), Vector2(1112, 108), Vector2(922, 720), Vector2(486, 720)]  # clair de lune
const NIGHT_TINT := Color(0.275, 0.275, 0.549)

static func beam_colors(top: float, bottom: float) -> PackedColorArray:
	var c := Color(0.627, 0.706, 1.000)
	return PackedColorArray([Color(c, top), Color(c, top), Color(c, bottom), Color(c, bottom)])


# Plans 01-02 : le noir, la veilleuse qui gresille, puis la chambre se devoile.
class Bedroom extends Shot:
	const VEILLEUSE := Vector2(1134, 480)
	var sky: Node2D
	var clouds: Node2D
	var world: Node2D
	var fg: Node2D
	var colon: Sprite2D
	var quilt: Sprite2D
	var beam: Polygon2D
	var motes: Array[Sprite2D]
	var halo: Sprite2D
	var dark: ColorRect

	func _init() -> void:
		duration = 13.5
		lines = [[1.7, 5.6, Story.INTRO[0], 30.0]]
		sky = group()
		layer(sky, "chambre/sky")
		clouds = group()
		layer(clouds, "chambre/clouds")
		world = group()
		for part in ["room", "door", "clock"]:
			layer(world, "chambre/" + part)
		colon = layer(world, "chambre/colon")
		layer(world, "chambre/bed")
		layer(world, "chambre/dreamer")
		quilt = layer(world, "chambre/quilt")
		layer(world, "chambre/veilleuse")
		beam = poly(world, PackedVector2Array(Intro.BEAM), Intro.beam_colors(0.24, 0.06), true)
		motes = dots(world, 12, Color("E8ECFF"))
		set_glow(glow(world, Color(1, 0.27, 0.31)), Vector2(1022, 416), Vector2(120, 72), 0.35)
		halo = glow(self, Color(1, 0.78, 0.43))
		fg = group()
		layer(fg, "chambre/foreground")
		dark = veil(self, Color(0.016, 0.012, 0.039, 0.97))

	static func camera(t: float) -> Vector3:
		if t < 5.5:
			return Vector3(VEILLEUSE.x, VEILLEUSE.y, 2.4 + 0.08 * t / 5.5)
		if t < 7.8:
			var e := ease01((t - 5.5) / 2.3)
			return Vector3(lerpf(VEILLEUSE.x, 640, e), lerpf(VEILLEUSE.y, 360, e), lerpf(2.48, 1.0, e))
		var p := ease01((t - 7.8) / 5.7)
		return Vector3(lerpf(640, 560, p), lerpf(360, 410, p), lerpf(1.0, 1.1, p))

	static func flicker(t: float) -> float:
		if t < 1.0: return 0.0
		if t < 1.15: return 1.0
		if t < 1.25: return 0.15
		if t < 1.4: return 1.0
		if t < 1.5: return 0.4
		return 0.85 + 0.12 * sin(t * 3.1)

	func update(t: float) -> void:
		var cam := camera(t)
		follow(sky, cam, 0.35)
		follow(clouds, cam, 0.45, Vector2(-t * 9, 0))
		follow(world, cam, 1.0)
		follow(fg, cam, 1.35)
		var reveal := ease01((t - 5.5) / 2.3)
		var shade := tint(Intro.NIGHT_TINT, 0.55 * reveal)
		for node in [sky, clouds, world]:
			node.modulate = shade
		# Obscurite : seul le halo de la veilleuse eclaire, puis la chambre se devoile.
		var screen := VEILLEUSE * cam.z + Vector2(640 - cam.x * cam.z, 360 - cam.y * cam.z)
		var light := flicker(t)
		var radius := 0.0 if t < 1.0 else 95.0 * ease01(t - 1.0) * (1.0 if light > 0.5 else 0.7) + reveal * 1500.0
		dark.material.set_shader_parameter("center", screen)
		dark.material.set_shader_parameter("radius", radius)
		var size := 300.0 * minf(cam.z, 1.8)
		set_glow(halo, screen, Vector2(size, size), 0.55 * light)
		colon.modulate.a = 1.0 if int(t * 2) % 2 == 0 else 0.1
		scale_about(quilt, Vector2(640, 516), Vector2(1, 1 + 0.03 * sin(t * TAU / 3.4)))
		beam.modulate.a = reveal
		for i in motes.size():
			var x := 760.0 + (i * 53) % 330 + sin(t * 0.7 + i) * 14 - t * 5
			var y := 700.0 - fmod(t * 14 + i * 41, 300.0)
			set_dot(motes[i], Vector2(x, y), 4, 0.55 * reveal * (0.5 + 0.5 * sin(t * 2 + i)))


# Plans 03-04 : la porte s'entrouvre sur les voix, il se tourne vers le mur ; puis le noir,
# ou ses sept soucis tournent autour de lui en se resserrant.
class Voices extends Shot:
	const BUBBLES := [[2.6, 150.0, 40.0], [3.5, 200.0, -20.0], [4.4, 120.0, -70.0]]  # depart, derive x, y
	const WORRIES := ["reveil", "devoirs", "miroir", "cocotte", "fardeau", "chaise", "compte"]
	var room: Node2D
	var sky: Node2D
	var clouds: Node2D
	var world: Node2D
	var fg: Node2D
	var hall: Polygon2D
	var door: Sprite2D
	var colon: Sprite2D
	var dreamer: Sprite2D
	var turned: Sprite2D
	var bubbles: Array[Sprite2D] = []
	var cover: ColorRect
	var void_group: Node2D
	var stand: Sprite2D
	var worries: Array[Sprite2D] = []

	func _init() -> void:
		duration = 16.0
		fade_in = 0.6
		lines = [[1.2, 15.8, Story.INTRO[1], 32.0]]
		room = group()
		sky = group(room)
		layer(sky, "chambre/sky")
		clouds = group(room)
		layer(clouds, "chambre/clouds")
		world = group(room)
		layer(world, "chambre/room")
		# Lumiere du couloir, plus forte pres de la porte.
		var points := PackedVector2Array([Vector2(56, 200), Vector2(228, 200), Vector2(228, 560), Vector2(704, 720), Vector2(26, 720), Vector2(56, 560)])
		var colors := PackedColorArray()
		for p in points:
			var a := lerpf(0.55, 0.12, p.x / 422.0) if p.x < 422 else 0.12 * (1.0 - (p.x - 422) / 282.0)
			colors.append(Color(1, 0.8, 0.53, a))
		hall = poly(world, points, colors, true)
		door = layer(world, "chambre/door")
		layer(world, "chambre/clock")
		colon = layer(world, "chambre/colon")
		layer(world, "chambre/bed")
		dreamer = layer(world, "chambre/dreamer")
		turned = layer(world, "chambre/dreamer_turned")
		layer(world, "chambre/quilt")
		layer(world, "chambre/veilleuse")
		for i in BUBBLES.size():
			var bubble := layer(world, "chambre/bubble%d" % i)
			bubble.centered = true
			bubbles.append(bubble)
		fg = group(room)
		layer(fg, "chambre/foreground")
		cover = rect(room, Vector2.ZERO, SIZE, NIGHT)
		void_group = group()
		layer(void_group, "soucis/background")
		stand = layer(void_group, "soucis/dreamer")
		for worry in WORRIES:
			var sprite := layer(void_group, "soucis/worry_" + worry)
			sprite.centered = true
			worries.append(sprite)

	func update(t: float) -> void:
		# Plan 03 : la camera glisse de la porte vers le lit.
		var p := ease01(t / 7.5)
		var cam := Vector3(lerpf(470, 560, p), lerpf(390, 410, p), lerpf(1.12, 1.2, p))
		follow(sky, cam, 0.35)
		follow(clouds, cam, 0.45, Vector2(-t * 9, 0))
		follow(world, cam, 1.0)
		follow(fg, cam, 1.35)
		var shade := tint(Intro.NIGHT_TINT, 0.55)
		for node in [sky, clouds, world]:
			node.modulate = shade
		var open := ease01((t - 1.0) / 1.6)
		scale_about(door, Vector2(56, 0), Vector2(1 - 0.8 * open, 1))
		hall.modulate.a = open * (0.9 + 0.1 * sin(t * 5))
		colon.modulate.a = 1.0 if int(t * 2) % 2 == 0 else 0.1
		var turn := ease01((t - 4.6) / 0.6)
		dreamer.modulate.a = 1.0 - turn
		turned.modulate.a = turn
		for i in bubbles.size():
			var b: Array = BUBBLES[i]
			var k := clampf((t - b[0]) / 3.2, 0.0, 1.0)
			var size := bubbles[i].texture.get_size() * 2.0
			bubbles[i].position = Vector2(150 + b[1] * k + sin(t * 2 + b[0]) * 6, 330 + b[2] * k - k * 30) + size / 2.0
			bubbles[i].scale = Vector2(2, 2) * (1 + k * 0.25)
			bubbles[i].rotation_degrees = sin(b[0] * 3) * 5
			bubbles[i].modulate.a = 0.0 if k <= 0 else (k / 0.15 if k < 0.15 else ((1 - k) / 0.2 if k > 0.8 else 1.0))
		# Transition vers le noir du plan 04.
		cover.color.a = ease01((t - 7.4) / 1.0)
		room.visible = t < 8.6
		void_group.modulate.a = ease01((t - 8.0) / 0.9)
		# Plan 04 : les soucis apparaissent puis tournent, l'orbite se resserre.
		var t4 := maxf(0.0, t - 8.4)
		var tighten := ease01(t4 / 7.0)
		var rx := lerpf(430, 290, tighten)
		var ry := lerpf(240, 165, tighten)
		var beat := pow(maxf(0.0, sin(t * PI * (1.1 + tighten * 0.9))), 12)
		scale_about(void_group, Vector2(640, 360), Vector2.ONE * (1 + 0.012 * beat), Vector2.ONE)
		for i in worries.size():
			var appear := clampf((t4 - i * 0.45) / 0.35, 0.0, 1.0)
			var a := -PI / 2 + i * TAU / 7 + t4 * (0.35 + tighten * 0.25)
			var pop := 0.4 + 0.75 * appear + 0.15 * sin(appear * PI) if appear < 1 else 1.0
			worries[i].position = Vector2(640 + rx * cos(a), 360 + ry * sin(a))
			worries[i].scale = Vector2(2, 2) * pop * (1 + 0.06 * beat)
			worries[i].modulate.a = appear
		var curl := 1.0 - 0.08 * tighten
		place(stand, Vector2(540, 240 + 280 * (1 - curl)), Vector2(200, 280 * curl))


# Plans 05-07 : les sept tours surgissent sur l'horizon, il les regarde depuis son lit,
# puis ses paupieres se ferment.
class Week extends Shot:
	const GLOWS := [Color(1.000, 0.839, 0.549), Color(1.000, 0.839, 0.549), Color(0.784, 0.886, 1.000), Color(1.000, 0.667, 0.353),
		Color(1.000, 0.784, 0.510), Color(0.549, 0.588, 0.784), Color(1.000, 0.275, 0.314)]
	const RISE_START := 0.9
	const RISE_GAP := 0.65
	const RISE_TIME := 0.55
	var horizon: Node2D
	var h_sky: Node2D
	var h_far: Node2D
	var h_towers: Node2D
	var h_mid: Node2D
	var h_near: Node2D
	var towers: Array[Sprite2D] = []
	var halos: Array[Sprite2D] = []
	var room: Node2D
	var sky: Node2D
	var world: Node2D
	var fg: Node2D
	var sitting: Sprite2D
	var lid_top: Node2D
	var lid_bottom: Node2D

	func _init() -> void:
		duration = 17.5
		lines = [[1.0, 7.3, Story.INTRO[2], 30.0], [8.3, 12.6, Story.INTRO[3], 30.0], [13.0, 17.6, Story.INTRO[4], 22.0]]
		horizon = group()
		h_sky = group(horizon)
		layer(h_sky, "horizon/sky")
		h_far = group(horizon)
		layer(h_far, "horizon/clouds0")
		h_towers = group(horizon)
		for i in 7:
			halos.append(glow(h_towers, GLOWS[i]))
			towers.append(layer(h_towers, "horizon/tower%d" % i))
		h_mid = group(horizon)
		layer(h_mid, "horizon/clouds1")
		h_near = group(horizon)
		layer(h_near, "horizon/clouds2")
		room = group()
		sky = group(room)
		layer(sky, "chambre/sky_towers")
		world = group(room)
		for part in ["room", "door", "clock", "bed", "quilt"]:
			layer(world, "chambre/" + part)
		sitting = layer(world, "chambre/dreamer_sitting")
		layer(world, "chambre/veilleuse")
		poly(world, PackedVector2Array(Intro.BEAM), Intro.beam_colors(0.22, 0.04), true)
		fg = group(room)
		layer(fg, "chambre/foreground")
		lid_top = _lid(false)
		lid_bottom = _lid(true)

	# Paupiere : une demi-ellipse noire liseree de violet.
	func _lid(bottom: bool) -> Node2D:
		var node := group()
		var points := PackedVector2Array([Vector2(-300, 0), Vector2(1580, 0)])  # assez large pour fermer aussi les coins
		for i in 33:
			var a := PI * i / 32.0
			points.append(Vector2(640 + 940 * cos(a), 235 + 235 * sin(a)))
		if bottom:
			for i in points.size():
				points[i].y = 470 - points[i].y
		var edge := poly(node, points, PackedColorArray([Color("2A2450")]))
		edge.position.y = -6 if bottom else 6
		poly(node, points, PackedColorArray([NIGHT]))
		return node

	# Paupieres : 0 = ouvertes, 1 = fermees. Trois clignements de plus en plus lourds.
	static func lids(t: float) -> float:
		if t < 14.6:
			return blink(t, 13.2, 0.22, 0.12, 0.3)
		if t < 15.9:
			return blink(t, 14.6, 0.32, 0.3, 0.45)
		return ease01((t - 15.9) / 0.6)

	static func blink(t: float, t0: float, close: float, hold: float, open: float) -> float:
		if t < t0: return 0.0
		if t < t0 + close: return ease01((t - t0) / close)
		if t < t0 + close + hold: return 1.0
		return 1.0 - ease01((t - t0 - close - hold) / open)

	func update(t: float) -> void:
		var in_room := ease01((t - 7.4) / 0.8) * (1.0 - ease01((t - 12.6) / 0.8))
		var hcam: Vector3
		if t < 7.8:
			hcam = Vector3(lerpf(470, 800, ease01(t / 7.8)), 330, 1.12)
		else:
			var q := ease01((t - 12.6) / 2.5)
			hcam = Vector3(lerpf(800, 640, q), lerpf(330, 300, q), lerpf(1.12, 1.04, q))
		# Petit tremblement a chaque tour qui surgit, plus fort vers le dimanche.
		var shake := 0.0
		for i in 7:
			var land := RISE_START + i * RISE_GAP + RISE_TIME
			if t > land and t < land + 0.35:
				shake += (1 - (t - land) / 0.35) * (2 + i * 1.2) * sin((t - land) * 70)
		follow(h_sky, hcam, 0.3)
		follow(h_far, hcam, 0.5, Vector2(-t * 4, 0))
		follow(h_towers, hcam, 0.75, Vector2(0, shake * 0.6))
		follow(h_mid, hcam, 0.9, Vector2(-t * 7, shake * 0.8))
		follow(h_near, hcam, 1.15, Vector2(-t * 11, shake))
		for i in 7:
			var k := (t - RISE_START - i * RISE_GAP) / RISE_TIME
			var lit := ease01((t - RISE_START - i * RISE_GAP - RISE_TIME) / 0.5) * (0.35 if i == 5 else 1.0)
			var pos := Vector2(2 * (30 + i * 85), 2 * (94 - i * 4) + (1 - back_out(k, 1.6)) * 420)
			towers[i].position = pos
			towers[i].visible = k > 0
			set_glow(halos[i], pos + Vector2(90, 220), Vector2(260, 320), lit * 0.8 * 0.35)
		horizon.modulate.a = 1.0 - in_room
		horizon.visible = in_room < 1.0
		var e := ease01((t - 7.6) / 4.6)
		var rcam := Vector3(lerpf(940, 700, e), lerpf(250, 330, e), lerpf(1.7, 1.15, e))
		follow(sky, rcam, 0.35)
		follow(world, rcam, 1.0)
		follow(fg, rcam, 1.35)
		var shade := tint(Intro.NIGHT_TINT, 0.55)
		sky.modulate = shade
		world.modulate = shade
		room.modulate.a = in_room
		room.visible = in_room > 0.0
		scale_about(sitting, Vector2(600, 472), Vector2(1, 1 + 0.012 * sin(t * 2.2)))
		var lid := lids(t)
		lid_top.position.y = -470 + lid * 430
		lid_bottom.position.y = 720 - lid * 430


# Plans 08-09 : la chute a travers les lieux des sept nuits, l'eclair blanc, puis le titre.
class Dive extends Shot:
	const TITLE := "Dream Dive"
	var fall: Node2D
	var strip: Sprite2D
	var streaks: Array[ColorRect] = []
	var faller: Sprite2D
	var title: Node2D
	var sparkles: Array[Sprite2D]
	var sleeper: Sprite2D
	var letters: Array[Label] = []
	var subtitle: Label
	var prompt: Label
	var flash: ColorRect

	func _init() -> void:
		duration = 12.5
		hold_at_end = true
		lines = [[0.3, 4.4, Story.INTRO[5], 30.0]]
		fall = group()
		strip = layer(fall, "plongee/strip")
		rect(fall, Vector2.ZERO, SIZE, Color(0.04, 0.024, 0.12, 0.35))
		for i in 14:
			streaks.append(rect(fall, Vector2.ZERO, Vector2(3, 10), Color.WHITE))
		faller = layer(fall, "plongee/dreamer")
		faller.centered = true
		faller.position = Vector2(640, 360)
		title = group()
		layer(title, "plongee/title_bg")
		sparkles = dots(title, 16, Color("FFF0C0"))
		sleeper = layer(title, "plongee/dreamer_sleep")
		var font := FontVariation.new()
		font.base_font = preload("res://assets/fonts/Nunito.ttf")
		font.variation_embolden = 1.2
		for ch in TITLE:
			var letter := text(title, ch, 112, Color("F6F2FF"))
			letter.add_theme_font_override("font", font)
			letter.add_theme_color_override("font_shadow_color", Color("2A2460"))
			letter.add_theme_constant_override("shadow_offset_x", 0)
			letter.add_theme_constant_override("shadow_offset_y", 5)
			letters.append(letter)
		subtitle = _centered(text(title, "Plonge dans ton propre sommeil", 26, Color("E4DEFA")), 262)
		prompt = _centered(text(title, "Appuie sur une touche", 20, Color("FFF3C8")), 720 - 48 - 28)
		flash = rect(self, Vector2.ZERO, SIZE, Color.WHITE)

	func _centered(label: Label, y: float) -> Label:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(0, y)
		label.size = Vector2(1280, 40)
		return label

	func _ready() -> void:
		# Les lettres du titre, centrees, chacune a sa place (elles tombent une a une).
		var widths: Array[float] = []
		var total := 0.0
		for letter in letters:
			widths.append(letter.get_minimum_size().x)
			total += widths.back()
		var x := 640.0 - total / 2.0
		for i in letters.size():
			letters[i].position.x = x
			x += widths[i]

	func update(t: float) -> void:
		# Plan 08 : la chute, de plus en plus vite, a travers les sept nuits.
		var falling := pow(clampf(t / 4.5, 0.0, 1.0), 3)
		strip.position.y = -falling * (2800 - 720)
		var speed := 0.3 + 2.6 * falling
		for i in streaks.size():
			var length := 60 + speed * 120
			streaks[i].position = Vector2(60 + (i * 89) % 1160, 720 - fmod(t * (500 + i * 37) * speed + i * 113, 720 + length))
			streaks[i].size = Vector2(3, length)
			streaks[i].color.a = 0.15 + 0.35 * falling
		faller.rotation_degrees = sin(t * 1.7) * 22 + t * 25
		var white := 0.0 if t < 4.2 else (ease01((t - 4.2) / 0.4) if t < 4.6 else 1.0 - ease01((t - 4.9) / 1.2))
		flash.color.a = clampf(white, 0.0, 1.0)
		fall.visible = t < 4.6
		title.visible = not fall.visible
		# Plan 09 : le titre.
		var t9 := t - 4.8
		for k in sparkles.size():
			var pos := Vector2(80 + (k * 71) % 1120 + sin(t * 0.8 + k) * 12, 700 - fmod(maxf(t9, 0.0) * 30 + k * 47, 700.0))
			set_dot(sparkles[k], pos, 4, (0.4 + 0.4 * sin(t * 3 + k)) if t9 > 0 else 0.0)
		place(sleeper, Vector2(540, 300 + sin(t * 1.6) * 8), Vector2(200, 280))
		sleeper.modulate.a = ease01((t9 - 0.3) / 1.0)
		for i in letters.size():
			var k := (t9 - 1.0 - i * 0.09) / 0.45
			letters[i].position.y = 120 - (1 - back_out(k)) * 40
			letters[i].modulate.a = clampf(k * 2, 0.0, 1.0)
		subtitle.modulate.a = ease01((t9 - 2.4) / 0.8)
		prompt.modulate.a = 0.0 if t9 < 3.4 else 0.55 + 0.45 * sin(t * 3.2)
