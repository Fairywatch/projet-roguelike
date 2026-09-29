extends Node2D

# Menu principal : ecran de depart, et retour apres une mort ou la fin d'une nuit.

const DREAMER_POS := Vector2(320, 156)
const Z_INTERVAL := 1.1

@onready var background: Node2D = $Background
@onready var dreamer: AnimatedSprite2D = $Dreamer
@onready var message_label: Label = $UI/Message
@onready var buttons: VBoxContainer = $UI/Buttons
@onready var coins_label: Label = $UI/Coins

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
	coins_label.text = "Pieces : %d" % GameState.coins
	if GameState.run_started:
		_add_button("Continuer  (%s, etage %d)" % [GameState.tower()["name"], GameState.floor_index], _go)
	_add_button("Nouvelle nuit", _open_panel.bind(TowerPanel))
	_add_button("Boutique", _open_panel.bind(ShopPanel))
	_add_button("Parametres", _open_panel.bind(SettingsPanel))
	_add_button("Quitter", get_tree().quit)
	buttons.get_child(0).grab_focus()

func _add_button(label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(240, 24)
	MenuPanel.style_button(button, 13)
	button.pressed.connect(func(): Sound.play("ui_select"); action.call())
	buttons.add_child(button)

func _spawn_z() -> void:
	var z := Label.new()
	z.text = "z"
	z.add_theme_font_size_override("font_size", randi_range(10, 16))
	z.modulate = Color(0.9, 0.9, 1, 0.9)
	z.position = DREAMER_POS + Vector2(14, -30)
	add_child(z)
	var tween := z.create_tween().set_parallel()
	tween.tween_property(z, "position", z.position + Vector2(randf_range(10, 30), -60), 2.0)
	tween.tween_property(z, "modulate:a", 0.0, 2.0)
	tween.chain().tween_callback(z.queue_free)

func _open_panel(panel_script: GDScript) -> void:
	buttons.visible = false
	var panel: MenuPanel = panel_script.new()
	panel.closed.connect(_close_panel)
	if panel is TowerPanel:
		panel.tower_chosen.connect(_start_tower)
	$UI.add_child(panel)

func _close_panel() -> void:
	coins_label.text = "Pieces : %d" % GameState.coins
	buttons.visible = true
	buttons.get_child(0).grab_focus()

func _start_tower(index: int) -> void:
	GameState.new_run(index)
	_go()

func _go() -> void:
	for button in buttons.get_children():
		button.disabled = true
	SceneTransition.change_scene(GameState.return_map_path)
