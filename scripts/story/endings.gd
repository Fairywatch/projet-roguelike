class_name Endings
extends RefCounted

# Les fins de nuit : une scene unique par nuit (animatiques "Fin du ..."), sur le texte de
# Story.ENDINGS. Chaque fin s'ouvre depuis le noir et s'y referme (l'aube du dimanche, en blanc dore).

static func shots(night: String) -> Array[Shot]:
	var shot: Shot
	match night:
		"lundi": shot = Lundi.new()
		"mardi": shot = Mardi.new()
		"mercredi": shot = Mercredi.new()
		"jeudi": shot = Jeudi.new()
		"vendredi": shot = Vendredi.new()
		"samedi": shot = Samedi.new()
		_: shot = Dimanche.new()
	return [shot]

# Les phrases de la fin, chacune a partir de son instant de depart.
static func story_lines(night: String, starts: Array, duration: float) -> Array:
	var texts: Array = Story.ENDINGS[night]
	var out := []
	for i in starts.size():
		var end: float = starts[i + 1] - 0.4 if i + 1 < starts.size() else duration - 1.1
		out.append([starts[i], end, texts[i], 34.0])
	return out

static func setup(shot: Shot, night: String, duration: float, starts: Array) -> void:
	shot.duration = duration
	shot.fade_in = 0.8
	shot.fade_out = 1.0
	shot.lines = story_lines(night, starts, duration)


# Lundi : les disputes derriere la porte se taisent, il s'endort enfin.
class Lundi extends Shot:
	const HEAD := Vector2(304, 432)
	var sky: Node2D
	var clouds: Node2D
	var world: Node2D
	var fg: Node2D
	var door_light: Sprite2D
	var quarrel: Sprite2D
	var colon: Sprite2D
	var awake: Sprite2D
	var asleep: Sprite2D
	var quilt: Sprite2D
	var halo: Sprite2D
	var zs: Array[Label] = []

	func _init() -> void:
		Endings.setup(self, "lundi", 13.5, [0.8, 7.0])
		sky = group()
		layer(sky, "chambre/sky")
		clouds = group()
		layer(clouds, "chambre/clouds")
		world = group()
		layer(world, "chambre/room")
		layer(world, "chambre/door")
		door_light = glow(world, Color(1, 0.75, 0.43))
		quarrel = glow(world, Color(1, 0.43, 0.27))
		layer(world, "chambre/clock")
		colon = layer(world, "chambre/colon")
		layer(world, "chambre/bed")
		awake = layer(world, "chambre/dreamer")
		asleep = layer(world, "fins/lundi_dreamer")
		quilt = layer(world, "chambre/quilt")
		layer(world, "chambre/veilleuse")
		halo = glow(world, Color(1, 0.78, 0.43))
		for k in 3:
			zs.append(text(world, "z", 16 + k * 5, Color("E8E4FF")))
		fg = group()
		layer(fg, "chambre/foreground")

	func update(t: float) -> void:
		var e := ease01(t / 12.5)
		var cam := Vector3(lerpf(640, 470, e), lerpf(360, 420, e), lerpf(1.0, 1.75, e))
		follow(sky, cam, 0.35)
		follow(clouds, cam, 0.45, Vector2(-t * 9, 0))
		follow(world, cam, 1.0)
		follow(fg, cam, 1.35)
		var calm := ease01((t - 4.6) / 2.2)  # la dispute se tait, la lumiere du couloir s'eteint
		var sleep := ease01((t - 7.8) / 0.9)  # les paupieres se ferment
		var shade := tint(Color(0.235, 0.235, 0.51), 0.5 + 0.12 * calm)
		for node in [sky, clouds, world]:
			node.modulate = shade
		var anger := (1 - calm) * (0.55 + 0.45 * sin(t * 7.3) * sin(t * 2.1))
		set_glow(door_light, Vector2(145, 555), Vector2(230, 70), 0.15 + 0.7 * (1 - calm) * (0.7 + 0.3 * sin(t * 11)))
		set_glow(quarrel, Vector2(142, 400), Vector2(1086, 1086), 0.4 * anger)
		set_glow(halo, Vector2(1134, 480), Vector2(300, 300), 0.4 + 0.15 * calm)
		colon.modulate.a = 1.0 if int(t * 2) % 2 == 0 else 0.1
		awake.modulate.a = 1.0 - sleep
		asleep.modulate.a = sleep
		# La respiration ralentit quand il s'endort.
		var phase := t * TAU / 3.0 if t < 7.8 else 7.8 * TAU / 3.0 + (t - 7.8) * TAU / 5.0
		scale_about(quilt, Vector2(640, 516), Vector2(1, 1 + 0.03 * sin(phase)))
		for k in zs.size():
			var p := (t - 9.2 - k * 0.8) / 2.6
			zs[k].position = Vector2(HEAD.x + 30 + p * 60 + sin(p * 6) * 6, HEAD.y - 50 - p * 90)
			zs[k].modulate.a = bell(p)


# Mardi : une main pose une etoile doree sur la copie ratee.
class Mardi extends Shot:
	const STAR := Vector2(742, 232)
	var bg: Sprite2D
	var spot: ColorRect
	var copy: Sprite2D
	var sleeve: ColorRect
	var hand: Sprite2D
	var star: Sprite2D
	var sparks: Array[Sprite2D]
	var warmth: Sprite2D

	func _init() -> void:
		Endings.setup(self, "mardi", 12.5, [0.8, 6.4])
		bg = layer(self, "fins/mardi_bg")
		spot = veil(self, Color(0.02, 0.012, 0.04, 0.8))
		copy = layer(self, "fins/mardi_copy")
		copy.centered = true
		copy.rotation_degrees = -3
		sleeve = rect(self, Vector2.ZERO, Vector2(900, 56), Color("5A78C8"))
		hand = layer(self, "fins/mardi_hand")
		star = layer(self, "fins/star")
		star.centered = true
		sparks = dots(self, 10, Color("FFE7A0"))
		warmth = glow(self, Color(1, 0.82, 0.47))

	func update(t: float) -> void:
		var bob := sin(t * 1.3) * 6
		var hand_in := ease01((t - 5.4) / 1.2)
		var hand_out := ease01((t - 7.0) / 1.0)
		var tip := Vector2(lerpf(1340, STAR.x + 14, hand_in) + hand_out * 760, STAR.y + bob + (1 - hand_in) * 50 + hand_out * 30)
		var placed := t >= 6.6
		var at := Vector2(STAR.x, STAR.y + bob) if placed else tip - Vector2(14, 0)
		var s := (0.8 + 0.4 * back_out((t - 6.6) / 0.5)) * (1 + 0.04 * sin(t * 3)) if placed else 0.8
		var warm := ease01((t - 6.7) / 1.6)
		scale_about(bg, Vector2(640, 360), Vector2.ONE * (1.04 + 0.06 * ease01(t / 12.0)))
		bg.modulate = Color(1, 1, 1) * (0.7 + 0.35 * warm)
		bg.modulate.a = 1.0
		spot.material.set_shader_parameter("center", Vector2(640, 350))
		spot.material.set_shader_parameter("radius", 200 + warm * 400)
		spot.material.set_shader_parameter("feather", 280 + warm * 100)
		copy.position = Vector2(640, 346 + bob)
		var holding := t > 5.3 and t < 8.1
		place(hand, tip - Vector2(16, 80), Vector2(280, 160), true)
		hand.visible = holding
		sleeve.position = tip + Vector2(250, -28)
		sleeve.visible = holding
		star.position = at
		star.scale = Vector2.ONE * 110 * s / 40.0
		star.visible = t > 5.3
		for i in sparks.size():
			var p := (t - 6.6) / 1.1
			var a := i * PI / 5
			set_dot(sparks[i], at + Vector2(cos(a), sin(a)) * (30 + p * 130) - Vector2(4, 4), 8, 1 - p if p > 0 and p < 1 else 0.0)
		set_glow(warmth, STAR, Vector2(1100, 1100), 0.45 * warm)


# Mercredi : au carrefour, il hesite, puis choisit ; le chemin s'allume sous ses pas.
class Mercredi extends Shot:
	var world: Node2D
	var path: Sprite2D
	var dreamer: Sprite2D
	var fog: Array[Sprite2D] = []
	var warmth: Sprite2D

	func _init() -> void:
		Endings.setup(self, "mercredi", 12.5, [0.8, 6.4])
		world = group()
		layer(world, "fins/mercredi_bg")
		path = layer(world, "fins/mercredi_path")
		path.region_enabled = true
		dreamer = layer(world, "fins/dreamer_stand")
		for i in 3:
			fog.append(glow(world, Color(0.67, 0.73, 0.75), false))
		warmth = glow(self, Color(1, 0.78, 0.47))

	func update(t: float) -> void:
		var reveal := ease01((t - 5.8) / 2.6)
		var walk := maxf(0.0, t - 6.6)
		var dx := walk * 72
		var facing := 1 if t >= 5.8 or int(t / 1.3) % 2 == 0 else -1  # il regarde a gauche, a droite
		var step := absf(sin(walk * 6)) * 6 if walk > 0 else 0.0
		var cam_x := minf(dx * 0.3, 60)
		world.scale = Vector2(1.1, 1.1)
		world.position = Vector2(640, 360) * -0.1 - Vector2(cam_x, 0)
		path.region_rect = Rect2(0, 0, 640 * (0.42 + 0.58 * reveal), 360)
		place(dreamer, Vector2(528 + dx, 332 - step), Vector2(200, 280), facing < 0)
		for i in fog.size():
			var x := fmod(t * (26 + i * 9) + i * 520, 1900.0) - 700
			set_glow(fog[i], Vector2(x + 380, 430 + i * 70), Vector2(1000, 280), 0.28 * (1 - 0.7 * reveal))
		set_glow(warmth, Vector2(900, 600), Vector2(1400, 900), 0.35 * reveal)


# Jeudi : l'orage de colere gronde sur la fournaise, puis passe ; la vapeur se leve sur le ciel.
class Jeudi extends Shot:
	const BOLTS := [1.4, 2.9, 4.3]
	var scene: Node2D
	var land: Sprite2D
	var furnace: Sprite2D
	var heat: ColorRect
	var dreamer: Sprite2D
	var storm: Sprite2D
	var steam: Sprite2D
	var flash: ColorRect

	func _init() -> void:
		Endings.setup(self, "jeudi", 12.5, [0.8, 6.4])
		scene = group()
		layer(scene, "fins/jeudi_sky")
		land = layer(scene, "fins/dimanche_land")
		furnace = layer(scene, "fins/jeudi_bg")
		heat = rect(scene, Vector2.ZERO, SIZE, Color(1, 0.35, 0.16))
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		heat.material = add
		dreamer = image(scene, "fins/dreamer_stand", Vector2(528, 316), Vector2(200, 280))
		storm = layer(scene, "fins/jeudi_storm")
		steam = Sprite2D.new()
		steam.centered = false
		var white := Color(0.94, 0.94, 1)
		steam.texture = vertical_texture(PackedFloat32Array([0.0, 0.4, 0.6, 1.0]), PackedColorArray([Color(white, 0), Color(white, 0.85), Color(white, 0.85), Color(white, 0)]))
		steam.scale = Vector2(1480, 1000) / steam.texture.get_size()
		scene.add_child(steam)
		flash = rect(self, Vector2.ZERO, SIZE, Color("FFF6D8"))

	static func bolt(t: float) -> float:
		for b in BOLTS:
			if t >= b and t < b + 0.2:
				return 1.0 - (t - b) / 0.2
		return 0.0

	func update(t: float) -> void:
		var calm := ease01((t - 5.8) / 2.8)
		var anger := 1.0 - calm
		var shake := Vector2(sin(t * 37), cos(t * 29)) * anger * 4
		scene.position = shake
		furnace.modulate.a = 1.0 - ease01((t - 6.2) / 2.2)
		land.modulate.a = calm
		heat.color.a = 0.22 * anger * (0.6 + 0.4 * sin(t * 5))
		dreamer.position.x = 528 + shake.x * 0.5
		place(storm, Vector2(320 + calm * 760, -40 - calm * 90), Vector2(640, 400))
		storm.modulate = Color(1, 1, 1, anger) * Color(1 + 1.5 * bolt(t), 1 + 1.5 * bolt(t), 1 + 1.5 * bolt(t), 1)
		var s := (t - 5.0) / 4.6
		steam.position = Vector2(-100, 760 - 1100 * ease01(s))
		steam.modulate.a = bell(s)
		flash.color.a = 0.6 * bolt(t)


# Vendredi : il arrive charge de cartons, les pose et s'assoit sur un banc, un the a cote de lui.
class Vendredi extends Shot:
	const BOX := Color("C4985F")
	const TAPE := Color("E2C488")
	var world: Node2D
	var sun: Sprite2D
	var boxes: Node2D
	var carrier: Node2D
	var sitting: Sprite2D
	var tea: Sprite2D
	var steam: Array[Sprite2D] = []

	func _init() -> void:
		Endings.setup(self, "vendredi", 13.5, [0.8, 6.6])
		world = group()
		layer(world, "fins/vendredi_bg")
		sun = glow(world, Color(1, 0.82, 0.59))
		set_glow(glow(world, Color(0.24, 0.12, 0.08), false), Vector2(530, 620), Vector2(700, 40), 0.35)  # ombre au sol
		image(world, "fins/vendredi_bench", Vector2(520, 514), Vector2(240, 108))
		boxes = group(world)
		_box(Rect2(300, 568, 120, 52))
		_box(Rect2(312, 518, 100, 50))
		carrier = group(world)  # pivote au niveau des pieds
		image(carrier, "fins/vendredi_carry", Vector2(-100, -360), Vector2(200, 360))
		sitting = image(world, "fins/vendredi_sit", Vector2(540, 342), Vector2(200, 280))
		tea = image(world, "fins/vendredi_tea", Vector2(720, 458), Vector2(100, 100))
		for k in 3:
			steam.append(glow(world, Color.WHITE, false))

	func _box(r: Rect2) -> void:
		rect(boxes, r.position, r.size, BOX)
		rect(boxes, r.position + Vector2(r.size.x * 0.46, 0), Vector2(r.size.x * 0.08, r.size.y), TAPE)

	func update(t: float) -> void:
		var walking := 1.0 if t < 5.2 else 0.0
		var sit := ease01((t - 5.6) / 0.7)
		var rest := ease01((t - 6.0) / 6.0)
		scale_about(world, Vector2(640, 460), Vector2.ONE * (1 + 0.12 * rest), Vector2.ONE)
		set_glow(sun, Vector2(640, 120), Vector2(1500, 1500), 0.15 + 0.3 * rest)
		carrier.position = Vector2(lerpf(-220, 528, ease01(t / 5.2)) + 100, 632 - absf(sin(t * 4.2)) * 5 * walking)
		carrier.rotation_degrees = sin(t * 4.2) * 2.5 * walking
		carrier.modulate.a = 1.0 - sit
		sitting.modulate.a = sit
		boxes.modulate.a = sit
		tea.modulate.a = ease01((t - 7.6) / 0.8)
		for k in steam.size():
			var p := fmod(t - 8.2 + k * 0.7 + 21.0, 2.1) / 2.1
			set_glow(steam[k], Vector2(768 + k * 8 + sin(p * 6 + k) * 6, 463 - p * 60), Vector2(12, 26), 0.6 * bell(p) if t > 8.2 else 0.0)


# Samedi : la salle de bal vide se remplit de silhouettes lumineuses qui dansent autour de lui.
class Samedi extends Shot:
	var bg: Sprite2D
	var lustre: Sprite2D
	var back: Array[Sprite2D] = []
	var front: Array[Sprite2D] = []
	var dreamer: Node2D
	var motes: Array[Sprite2D]

	func _init() -> void:
		Endings.setup(self, "samedi", 13.5, [0.8, 6.6])
		bg = layer(self, "fins/samedi_bg")
		lustre = glow(self, Color(1, 0.86, 0.59))
		back = _dancers()
		dreamer = group()  # pivote au niveau des pieds
		image(dreamer, "fins/dreamer_stand", Vector2(-100, -280), Vector2(200, 280))
		dreamer.position = Vector2(628, 632)
		front = _dancers()
		motes = dots(self, 14, Color("FFE6B0"))

	func _dancers() -> Array[Sprite2D]:
		var list: Array[Sprite2D] = []
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		for k in 4:
			var sprite := layer(self, "fins/samedi_dancer")
			sprite.centered = true
			sprite.offset = Vector2(0, -42)  # pivot a 80 % de la hauteur, comme dans la maquette
			sprite.material = add
			list.append(sprite)
		return list

	func update(t: float) -> void:
		var warm := ease01((t - 6.0) / 2.5)
		bg.modulate = tint(Color(0.2, 0.2, 0.4), 0.55 * (1 - warm) + 0.1)
		set_glow(lustre, Vector2(640, 56), Vector2(800, 600), 0.55 * warm)
		for k in 4:
			var a := t * 0.55 + k * PI / 2
			var depth := sin(a)
			var s := 0.9 + 0.12 * depth
			var alpha := ease01((t - 6.2 - k * 0.6) / 1.4) * (0.75 + 0.25 * sin(t * 3 + k))
			for sprite in [back[k], front[k]]:
				sprite.position = Vector2(640 + cos(a) * 380, 604 + depth * 30)
				sprite.scale = Vector2(-2 if k % 2 else 2, 2) * s
				sprite.rotation_degrees = sin(t * 2 + k) * 6
			back[k].modulate.a = alpha if depth < 0 else 0.0
			front[k].modulate.a = alpha if depth >= 0 else 0.0
		dreamer.rotation_degrees = sin(t * 2) * 3 * warm
		for i in motes.size():
			var pos := Vector2(80 + (i * 89) % 1120 + sin(t + i) * 10, 700 - fmod(t * 22 + i * 53, 660.0))
			set_dot(motes[i], pos, 5, warm * (0.4 + 0.4 * sin(t * 3 + i)))


# Dimanche : l'aube se leve, les sept tours se dissolvent dans la lumiere, il se reveille.
class Dimanche extends Shot:
	var dawn: Sprite2D
	var sun: Sprite2D
	var towers: Array[Sprite2D] = []
	var land: Sprite2D
	var motes: Array[Sprite2D]
	var dreamer: Sprite2D

	func _init() -> void:
		Endings.setup(self, "dimanche", 18.0, [0.8, 6.2, 11.8])
		end_color = Color("FFF4DE")
		layer(self, "fins/dimanche_night")
		dawn = layer(self, "fins/dimanche_dawn")
		sun = layer(self, "fins/dimanche_sun")
		for k in 7:
			towers.append(layer(self, "horizon/tower%d" % k))
		land = layer(self, "fins/dimanche_land")
		motes = dots(self, 21, Color("FFF0C8"), true)
		dreamer = image(self, "fins/dreamer_stand", Vector2(528, 292), Vector2(200, 280))

	static func tower_x(k: int) -> float:
		return 640.0 + (k - 3) * 150

	func update(t: float) -> void:
		var light := ease01((t - 6.0) / 5.0)
		dawn.modulate.a = light
		place(sun, Vector2(460, lerpf(620, 190, ease01((t - 6.0) / 7.0))), Vector2(360, 360))
		var b := 0.6 + 0.8 * light
		land.modulate = Color(b, b, b)
		for k in 7:
			var d := ease01((t - 9.0 - k * 0.4) / 1.6)
			var pulse := 0.15 * sin(t * 2) if k == 6 else 0.0  # la derniere tour palpite encore
			var v := 0.55 + 0.45 * light + d * 1.5 + pulse
			place(towers[k], Vector2(tower_x(k) - 63, 264 - d * 30), Vector2(126, 280))
			towers[k].modulate = Color(v, v, v, 1.0 - d)
		for i in motes.size():
			var j := i % 7
			var p := (t - 9.0 - j * 0.4) / 3.0 - floorf(i / 7.0) * 0.15
			set_dot(motes[i], Vector2(tower_x(j) + sin(i * 1.7 + p * 4) * 30, 440 - p * 320), 6, bell(p) if p > 0 and p < 1 else 0.0)
		var w := 0.5 + 0.5 * light
		dreamer.modulate = Color(w, w, w, ease01((t - 12.0) / 1.2))
