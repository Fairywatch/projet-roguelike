class_name Intro
extends RefCounted

# L'intro, en quatre plans : la veilleuse et la chambre, les voix et les soucis, la semaine et
# les paupieres, la plongee et le titre. Texte : Story.INTRO.
# Les plans sont des scenes 3D rendues en pixel art dans Blender (tools/blender/intro_cinematic.py),
# jouees en video (assets/cinematics/intro/). Par-dessus, Godot garde ce qui doit rester net ou
# reagir : le texte, les paupieres, l'eclair blanc et l'ecran-titre.

static func shots() -> Array[Shot]:
	return [Bedroom.new(), Voices.new(), Week.new(), Dive.new()]


# Plans 01-02 : le noir, la veilleuse qui gresille, puis la chambre se devoile.
class Bedroom extends Shot:
	var film: VideoStreamPlayer

	func _init() -> void:
		duration = 13.5
		lines = [[1.7, 5.6, Story.INTRO[0], 30.0]]
		film = video(self, "intro/intro_1_chambre")

	func update(t: float) -> void:
		sync_video(film, t, duration)


# Plans 03-04 : la porte s'entrouvre sur les voix, il se tourne vers le mur ; puis le noir,
# ou ses sept soucis tournent autour de lui en se resserrant.
class Voices extends Shot:
	var film: VideoStreamPlayer

	func _init() -> void:
		duration = 16.0
		fade_in = 0.6
		lines = [[1.2, 15.8, Story.INTRO[1], 32.0]]
		film = video(self, "intro/intro_2_voix")

	func update(t: float) -> void:
		sync_video(film, t, duration)


# Plans 05-07 : les sept tours surgissent sur l'horizon, il les regarde depuis son lit,
# puis ses paupieres se ferment.
class Week extends Shot:
	var film: VideoStreamPlayer
	var lid_top: Node2D
	var lid_bottom: Node2D

	func _init() -> void:
		duration = 17.5
		lines = [[1.0, 7.3, Story.INTRO[2], 30.0], [8.3, 12.6, Story.INTRO[3], 30.0], [13.0, 17.6, Story.INTRO[4], 22.0]]
		film = video(self, "intro/intro_3_semaine")
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
		sync_video(film, t, duration)
		var lid := lids(t)
		lid_top.position.y = -470 + lid * 430
		lid_bottom.position.y = 720 - lid * 430


# Plans 08-09 : la chute a travers les lieux des sept nuits, l'eclair blanc, puis le titre.
class Dive extends Shot:
	const TITLE := "Dream Dive"
	const FALL_LENGTH := 4.8  # duree de la video de la chute
	var fall: VideoStreamPlayer
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
		fall = video(self, "intro/intro_4_chute")
		title = group()
		layer(title, "intro/titre_fond")
		sparkles = dots(title, 16, Color("FFF0C0"))
		sleeper = layer(title, "intro/titre_reveur")
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
		var white := 0.0 if t < 4.2 else (ease01((t - 4.2) / 0.4) if t < 4.6 else 1.0 - ease01((t - 4.9) / 1.2))
		flash.color.a = clampf(white, 0.0, 1.0)
		fall.visible = t < 4.6
		title.visible = not fall.visible
		if fall.visible:
			sync_video(fall, t, FALL_LENGTH)
		# Plan 09 : le titre, le reveur endormi sur son nuage.
		var t9 := t - 4.8
		for k in sparkles.size():
			var pos := Vector2(80 + (k * 71) % 1120 + sin(t * 0.8 + k) * 12, 700 - fmod(maxf(t9, 0.0) * 30 + k * 47, 700.0))
			set_dot(sparkles[k], pos, 4, (0.4 + 0.4 * sin(t * 3 + k)) if t9 > 0 else 0.0)
		sleeper.position.y = sin(t * 1.6) * 8
		sleeper.modulate.a = ease01((t9 - 0.3) / 1.0)
		for i in letters.size():
			var k := (t9 - 1.0 - i * 0.09) / 0.45
			letters[i].position.y = 120 - (1 - back_out(k)) * 40
			letters[i].modulate.a = clampf(k * 2, 0.0, 1.0)
		subtitle.modulate.a = ease01((t9 - 2.4) / 0.8)
		prompt.modulate.a = 0.0 if t9 < 3.4 else 0.55 + 0.45 * sin(t * 3.2)
