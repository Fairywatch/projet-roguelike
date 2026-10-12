extends Node2D

# Scene de recit (intro, fins de nuit) : une suite de tableaux animes avec un texte qui
# s'ecrit, facon intro de The Binding of Isaac. Les textes viennent de scripts/story.gd.
# E / Espace / Entree : texte suivant ; Echap : passer.

const TYPE_SPEED := 40.0  # caracteres par seconde
const CENTER := Vector2(320, 150)
const DECOR_DIR := "res://assets/sprites/decor/"
const BG_NIGHT := Color(0.04, 0.04, 0.1)

@onready var stage: Node2D = $Stage
@onready var text_label: Label = $UI/Text

var panels: Array = []
var index := -1
var shown := 0.0
var vignette := ""
var finishing := false

func _ready() -> void:
	DreamTheme.set_family(FloorGenerator.Family.PROFOND)
	# Coupure des lignes calculee sur le texte entier : il ne se reorganise pas en s'ecrivant.
	text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	if GameState.cutscene_id == "intro":
		panels = Story.INTRO
	else:
		panels = Story.ENDINGS.get(GameState.cutscene_id.trim_prefix("ending_"), [])
	Sound.music("reve")
	next_panel()

func _process(delta: float) -> void:
	shown += delta * TYPE_SPEED
	text_label.visible_characters = int(shown)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE:
		finish()
	elif event.physical_keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		if shown < text_label.text.length():
			shown = text_label.text.length()  # premier appui : affiche tout le texte
		else:
			next_panel()

func next_panel() -> void:
	index += 1
	if index >= panels.size():
		finish()
		return
	var panel: Dictionary = panels[index]
	text_label.text = panel["text"]
	shown = 0.0
	if panel["vignette"] != vignette:
		vignette = panel["vignette"]
		_build(vignette)

func finish() -> void:
	if finishing:
		return
	finishing = true
	GameState.cutscene_id = ""
	SceneTransition.change_scene(GameState.cutscene_next)

# --- Tableaux -----------------------------------------------------------------------

func _build(kind: String) -> void:
	for child in stage.get_children():
		child.queue_free()
	_rect(Vector2.ZERO, Vector2(640, 360), BG_NIGHT)
	match kind:
		"bed": _bed()
		"thoughts": _thoughts()
		"towers": _towers()
		"dive": _dive()
		"tower": _tower()
		"dawn": _dawn()
	stage.modulate.a = 0.0
	create_tween().tween_property(stage, "modulate:a", 1.0, 0.6)

func _rect(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	stage.add_child(rect)
	return rect

func _sprite(texture: Texture2D, pos: Vector2, scale_value: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = pos
	sprite.scale = Vector2.ONE * scale_value
	stage.add_child(sprite)
	return sprite

func _dreamer(pos: Vector2, scale_value: float) -> AnimatedSprite2D:
	var dreamer := AnimatedSprite2D.new()
	dreamer.sprite_frames = PlayerFrames.make()
	dreamer.play("idle")
	dreamer.position = pos
	dreamer.scale = Vector2.ONE * scale_value
	stage.add_child(dreamer)
	return dreamer

func _float(node: Node2D, height: float, period: float) -> void:
	var tween := node.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "position:y", node.position.y - height, period)
	tween.tween_property(node, "position:y", node.position.y, period)

func _particles() -> void:
	var p := DreamTheme.make_ambient_particles(FloorGenerator.Family.PARADOXAL)
	p.position = Vector2(320, 180)
	stage.add_child(p)

func _bed() -> void:
	_rect(Vector2(400, 40), Vector2(130, 110), Color(0.13, 0.16, 0.32))  # fenetre
	_rect(Vector2(462, 40), Vector2(6, 110), Color(0.06, 0.05, 0.1))
	_rect(Vector2(400, 92), Vector2(130, 6), Color(0.06, 0.05, 0.1))
	_float(_sprite(load(DECOR_DIR + "paradoxal/lune.png"), Vector2(434, 70), 3.0), 4.0, 2.0)
	_rect(Vector2(120, 200), Vector2(260, 16), Color(0.42, 0.26, 0.16))  # lit
	_rect(Vector2(120, 170), Vector2(14, 60), Color(0.36, 0.22, 0.14))
	_rect(Vector2(132, 178), Vector2(54, 24), Color(0.88, 0.86, 0.94))  # oreiller
	var dreamer := _dreamer(Vector2(190, 186), 2.0)
	dreamer.rotation_degrees = -90
	_rect(Vector2(206, 182), Vector2(170, 22), Color(0.36, 0.28, 0.6))  # couverture
	_particles()

func _thoughts() -> void:
	_dreamer(CENTER + Vector2(0, 30), 3.0)
	var ring := Node2D.new()
	ring.position = CENTER
	stage.add_child(ring)
	var worries := ["paradoxal/horloge", "profond/bougie", "paradoxal/cube", "profond/cristal", "paradoxal/nuage", "profond/arbre_mort"]
	for i in worries.size():
		var angle := TAU * i / worries.size()
		var sprite := Sprite2D.new()
		sprite.texture = load(DECOR_DIR + worries[i] + ".png")
		sprite.scale = Vector2(2, 2)
		sprite.position = Vector2(cos(angle), sin(angle) * 0.55) * 140.0
		ring.add_child(sprite)
	ring.create_tween().set_loops().tween_property(ring, "rotation", TAU, 24.0).from(0.0)
	_particles()

func _towers() -> void:
	for i in Towers.LIST.size():
		var tower: Dictionary = Towers.LIST[i]
		var texture: Texture2D = load("res://assets/sprites/hub/tower_%s.png" % tower["id"])
		var sprite := _sprite(texture, Vector2(80 + i * 80, 0), 1.6)
		sprite.offset = Vector2(0, -texture.get_height() / 2.0)
		sprite.position.y = 240
		sprite.modulate.a = 0.0
		var tween := sprite.create_tween()
		tween.tween_interval(0.35 * i)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.5)

func _dive() -> void:
	_particles()
	var dreamer := _dreamer(Vector2(320, -40), 3.0)
	var tween := dreamer.create_tween().set_parallel()
	tween.tween_property(dreamer, "position:y", 220.0, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(dreamer, "rotation", TAU * 1.5, 3.0)
	var veil := _rect(Vector2.ZERO, Vector2(640, 360), Color(0.85, 0.82, 1.0, 0.0))
	var fade := veil.create_tween()
	fade.tween_interval(2.4)
	fade.tween_property(veil, "color:a", 1.0, 0.8)

func _tower() -> void:
	var tower: Dictionary = Towers.get_tower(GameState.cutscene_tower)
	var texture: Texture2D = load("res://assets/sprites/hub/tower_%s.png" % tower["id"])
	var sprite := _sprite(texture, Vector2(270, 250), 2.4)
	sprite.offset = Vector2(0, -texture.get_height() / 2.0)
	_dreamer(Vector2(380, 222), 2.0)
	_particles()

func _dawn() -> void:
	var sky := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.16, 0.18, 0.42))
	gradient.set_color(1, Color(1.0, 0.68, 0.45))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	sky.texture = texture
	sky.size = Vector2(640, 360)
	stage.add_child(sky)
	var sun := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 24:
		points.append(Vector2(cos(TAU * i / 24), sin(TAU * i / 24)) * 34)
	sun.polygon = points
	sun.color = Color(1, 0.92, 0.7)
	sun.position = Vector2(320, 300)
	stage.add_child(sun)
	sun.create_tween().tween_property(sun, "position:y", 190.0, 5.0).set_trans(Tween.TRANS_SINE)
	_rect(Vector2(0, 250), Vector2(640, 110), Color(0.2, 0.16, 0.24))  # horizon
	var dreamer := _dreamer(Vector2(320, 226), 2.5)
	dreamer.modulate = Color(0.35, 0.3, 0.42)  # silhouette a contre-jour
