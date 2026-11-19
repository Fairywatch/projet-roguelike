extends Node2D

# Menu principal : ecran de depart, et retour apres une mort ou la fin d'une nuit.

const DREAMER_POS := Vector2(320, 156)
const Z_INTERVAL := 1.1

@onready var background: Node2D = $Background
@onready var dreamer: AnimatedSprite2D = $Dreamer
@onready var message_label: Label = $UI/Message
@onready var buttons: VBoxContainer = $UI/Buttons
@onready var coins_label: Label = $UI/Coins

var updater: Updater
var pending_update := false  # trouvee pendant qu'un autre panneau etait ouvert

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
	coins_label.text = _coins_text()
	if GameState.run_started:
		var mode := "  -  %s" % GameState.format_time(GameState.time_left) if GameState.speedrun else ""
		_add_button("Continuer  (%s, étage %d%s)" % [Towers.title(GameState.tower_index), GameState.floor_index, mode], _go)
	_add_button("Choisir une nuit", _open_hub)
	_add_button("Sauvegardes", _open_panel.bind(SlotsPanel))
	_add_button("Paramètres", _open_panel.bind(SettingsPanel))
	_add_button("Quitter", get_tree().quit)
	buttons.get_child(0).grab_focus()
	_refresh_hint()
	GameState.input_device_changed.connect(_refresh_hint)
	_add_version()
	if Updater.should_check():
		updater = Updater.new()
		add_child(updater)
		updater.found.connect(_on_update_found)
		updater.check()
	GameHud.pill(coins_label)
	var message_pill := GameHud.pill(message_label)
	message_pill.visible = message_label.text != ""
	_animate_entrance()

# Le titre se pose puis flotte doucement ; les boutons arrivent l'un apres l'autre.
func _animate_entrance() -> void:
	var title: Label = $UI/Title
	title.theme_type_variation = &"PixelTitle"
	title.pivot_offset = title.size / 2.0
	title.modulate.a = 0.0
	title.scale = Vector2(1.15, 1.15)
	var intro := title.create_tween().set_parallel()
	intro.tween_property(title, "modulate:a", 1.0, 0.5)
	intro.tween_property(title, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var rest := title.position.y
	var float_tween := title.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(title, "position:y", rest - 3.0, 1.8)
	float_tween.tween_property(title, "position:y", rest, 1.8)
	await get_tree().process_frame  # positions des boutons connues
	for i in buttons.get_child_count():
		var button: Button = buttons.get_child(i)
		button.modulate.a = 0.0
		var tween := button.create_tween().set_parallel()
		tween.tween_property(button, "modulate:a", 1.0, 0.25).set_delay(0.08 * i + 0.15)
		tween.tween_property(button, "position:x", button.position.x, 0.35).from(button.position.x - 14.0).set_delay(0.08 * i + 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# Version (Projet > Parametres > Application > Version), en bas a droite : les testeurs la citent
# dans leurs retours.
func _add_version() -> void:
	var version := Label.new()
	version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "?")
	version.add_theme_font_size_override("font_size", 9)
	version.modulate = Color(1, 1, 1, 0.45)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	$UI.add_child(version)

# Aide des touches : reecrite quand on passe du clavier a la manette.
func _refresh_hint() -> void:
	$UI/Hint.text = Controls.help(["move", "attack", "dash", "active", "interact", "inventory", "pause"])

func _add_button(label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(240, 22)
	button.add_theme_font_size_override("font_size", 13)
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
	$UI.add_child(panel)

func _coins_text() -> String:
	return "Sauvegarde %d  ·  Pièces : %d" % [GameState.slot + 1, GameState.coins]

func _close_panel() -> void:
	coins_label.text = _coins_text()
	buttons.visible = true
	buttons.get_child(0).grab_focus()
	if pending_update:
		_show_update.call_deferred()

# Nouvelle version publiee (Updater) : proposee des que le menu est libre.
func _on_update_found(_release: Dictionary) -> void:
	if buttons.visible:
		_show_update()
	else:
		pending_update = true

func _show_update() -> void:
	pending_update = false
	buttons.visible = false
	var panel := UpdatePanel.new()
	panel.updater = updater
	panel.closed.connect(_close_panel)
	$UI.add_child(panel)

# La toute premiere fois, l'intro raconte l'histoire avant d'arriver au hub.
func _open_hub() -> void:
	if GameState.intro_seen:
		SceneTransition.change_scene(GameState.HUB_PATH)
		return
	GameState.intro_seen = true
	GameState.save_meta()
	GameState.play_cutscene("intro", GameState.HUB_PATH)

func _go() -> void:
	for button in buttons.get_children():
		button.disabled = true
	SceneTransition.change_scene(GameState.return_map_path)
