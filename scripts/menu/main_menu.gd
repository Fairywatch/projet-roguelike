extends Node2D

# Menu principal : ecran de depart, et retour apres une mort ou la fin d'une nuit.

const DREAMER_POS := Vector2(320, 160)
const Z_INTERVAL := 1.1

@onready var background: Node2D = $Background
@onready var dreamer: AnimatedSprite2D = $Dreamer
@onready var message_label: Label = $UI/Message
@onready var buttons: VBoxContainer = $UI/Buttons

func _ready() -> void:
	background.setup(FloorGenerator.Family.PARADOXAL, FloorGenerator.Intensity.REVE)
	DreamTheme.set_family(FloorGenerator.Family.PROFOND)
	var ambient := CanvasModulate.new()
	ambient.color = Color(0.42, 0.4, 0.6)
	add_child(ambient)
	var light := DreamTheme.make_light(Color(0.85, 0.8, 1), 170.0, 1.0)
	light.position = DREAMER_POS
	add_child(light)
	var particles := DreamTheme.make_ambient_particles(FloorGenerator.Family.PARADOXAL)
	particles.position = Vector2(320, 180)
	add_child(particles)

	dreamer.sprite_frames = PlayerFrames.make()
	dreamer.play("idle")
	dreamer.position = DREAMER_POS
	var float_tween := dreamer.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(dreamer, "position:y", DREAMER_POS.y - 8.0, 1.6)
	float_tween.tween_property(dreamer, "position:y", DREAMER_POS.y, 1.6)
	var z_timer := Timer.new()
	z_timer.wait_time = Z_INTERVAL
	z_timer.autostart = true
	z_timer.timeout.connect(_spawn_z)
	add_child(z_timer)

	Sound.music("reve")
	message_label.text = GameState.menu_message
	GameState.menu_message = ""
	GameState.save_run()
	if GameState.run_started:
		_add_button("Continuer  (etage %d)" % GameState.floor_index, _continue)
	_add_button("Nouvelle nuit", _new_run)
	_add_button("Parametres", _open_settings)
	_add_button("Quitter", get_tree().quit)
	buttons.get_child(0).grab_focus()

func _add_button(label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(220, 26)
	button.add_theme_font_size_override("font_size", 13)
	for state in ["normal", "hover", "focus", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.07, 0.2, 0.85) if state == "normal" else Color(0.32, 0.22, 0.52, 0.95)
		style.border_color = Color(0.6, 0.5, 0.9, 0.9)
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(func(): Sound.play("ui_select"); action.call())
	button.focus_entered.connect(Sound.play.bind("ui_move", -6.0, 0.0))
	buttons.add_child(button)

func _spawn_z() -> void:
	var z := Label.new()
	z.text = "z"
	z.add_theme_font_size_override("font_size", randi_range(10, 16))
	z.modulate = Color(0.9, 0.9, 1, 0.9)
	z.position = DREAMER_POS + Vector2(22, -40)
	add_child(z)
	var tween := z.create_tween().set_parallel()
	tween.tween_property(z, "position", z.position + Vector2(randf_range(10, 30), -60), 2.0)
	tween.tween_property(z, "modulate:a", 0.0, 2.0)
	tween.chain().tween_callback(z.queue_free)

func _open_settings() -> void:
	buttons.visible = false
	var panel := SettingsPanel.new()
	panel.closed.connect(_close_settings)
	$UI.add_child(panel)
	panel.reset_size()
	panel.position = (get_viewport_rect().size - panel.size) / 2.0

func _close_settings() -> void:
	buttons.visible = true
	buttons.get_child(0).grab_focus()

func _continue() -> void:
	_go()

func _new_run() -> void:
	GameState.new_run()
	_go()

func _go() -> void:
	for button in buttons.get_children():
		button.disabled = true
	SceneTransition.change_scene(GameState.return_map_path)
