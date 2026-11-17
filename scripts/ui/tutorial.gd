class_name Tutorial
extends Control

# Tutoriel du tout premier combat (lundi, etage 0) : un ennemi d'entrainement qui ne bouge pas,
# et les gestes du jeu demandes un par un. Chaque etape se valide en la faisant. A la fin,
# l'ennemi se reveille : c'est un vrai combat, et le tutoriel ne revient plus (GameState.tutorial_done).

const TRAINING_HP := 99
const MOVE_DISTANCE := 90.0

var player: CharacterBody2D
var dummy: BaseMob
var step := -1
var moved := 0.0
var last_position := Vector2.ZERO
var hits := 0
var finisher_done := false
var dashed := false
var volleyed := false
var panel := PanelContainer.new()
var label := Label.new()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(380, 0)
	panel.theme_type_variation = &"Toast"
	panel.add_child(label)
	add_child(panel)
	# L'ennemi d'entrainement : immobile, et bien trop solide pour tomber pendant la lecon.
	dummy.set_physics_process(false)
	dummy.hp = TRAINING_HP
	dummy.max_hp = TRAINING_HP
	last_position = player.global_position
	player.attacked.connect(_on_attack)
	player.special_used.connect(func(): volleyed = true)
	_next()

func _on_attack(_at: Vector2) -> void:
	hits += 1
	if player.strike_kind == "finisher":
		finisher_done = true

func _process(_delta: float) -> void:
	if not is_instance_valid(dummy) or step > 4:
		return
	moved += player.global_position.distance_to(last_position)
	last_position = player.global_position
	dashed = dashed or player.dashing
	dummy.hp = TRAINING_HP  # il encaisse tout
	var done: bool = [moved >= MOVE_DISTANCE, hits >= 2, finisher_done, dashed, volleyed][step]
	if done:
		Sound.play("sparkle")
		_next()

func _next() -> void:
	step += 1
	hits = 0
	dashed = false
	volleyed = false
	match step:
		0:
			_say("Déplace-toi : %s" % Controls.name_of("move"))
		1:
			_say("Approche de l'ennemi et frappe-le : %s" % Controls.name_of("attack"))
		2:
			_say("Enchaîne trois coups sans attendre : le troisième frappe deux fois plus fort.")
		3:
			_say("Dash : %s. Tu es intouchable pendant le dash. De temps en temps, frapper juste après fait plus mal." % Controls.name_of("dash"))
		4:
			_say("Rafale de plumes : %s. Elle touche de loin, puis se recharge (jauge violette sous les cœurs)." % Controls.name_of("special"))
		_:
			_finish()

func _finish() -> void:
	_say("Un « ! » et un anneau aux pieds d'un ennemi annoncent sa frappe : esquive-la. À toi !")
	GameState.tutorial_done = true
	GameState.save_meta()
	if is_instance_valid(dummy):  # l'ennemi se reveille : un vrai combat, court
		dummy.hp = 3
		dummy.max_hp = 3
		dummy.set_physics_process(true)
	await get_tree().create_timer(5.0, false).timeout
	queue_free()

func _say(text: String) -> void:
	label.text = text
	await get_tree().process_frame
	panel.reset_size()
	panel.position = Vector2((get_viewport_rect().size.x - panel.size.x) / 2.0, get_viewport_rect().size.y - panel.size.y - 34.0)
