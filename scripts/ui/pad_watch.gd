class_name PadWatch
extends CanvasLayer

# Manette branchee : un petit message en haut de l'ecran. Manette debranchee pendant qu'on joue
# avec : le jeu se met en pause jusqu'a ce qu'on appuie sur une touche ou un bouton (sinon le
# combat continuerait sans nous). Enfant de GameState, au-dessus de tout.

const NOTICE_TIME := 2.5
const STARTUP_QUIET_MS := 2000  # manette deja branchee au lancement : pas de message

var notice := PanelContainer.new()
var notice_label := Label.new()
var pause_panel := PanelContainer.new()
var dim := ColorRect.new()  # assombrit le jeu derriere le message de pause
var paused_by_us := false
var waiting := false

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	notice.theme_type_variation = &"Toast"
	notice.visible = false
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_label.add_theme_font_size_override("font_size", 11)
	notice.add_child(notice_label)
	add_child(notice)

	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	add_child(dim)
	pause_panel.theme_type_variation = &"Toast"
	pause_panel.visible = false
	var label := Label.new()
	label.text = "Manette déconnectée\nRebranche-la, puis appuie sur un bouton (ou une touche) pour reprendre."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	pause_panel.add_child(label)
	add_child(pause_panel)

func connected(joy_name: String) -> void:
	if Time.get_ticks_msec() < STARTUP_QUIET_MS:
		return
	notice_label.text = "Manette connectée" + (" : %s" % joy_name if joy_name != "" else "")
	notice.reset_size()
	notice.position = Vector2((_screen().x - notice.size.x) / 2.0, 6.0)
	notice.visible = true
	notice.modulate.a = 1.0
	var tween := notice.create_tween()
	tween.tween_interval(NOTICE_TIME)
	tween.tween_property(notice, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): notice.visible = false)

func disconnected() -> void:
	if waiting:
		return
	waiting = true
	paused_by_us = not get_tree().paused
	get_tree().paused = true
	pause_panel.reset_size()
	pause_panel.position = (_screen() - pause_panel.size) / 2.0
	pause_panel.visible = true
	dim.visible = true

func _input(event: InputEvent) -> void:
	if not waiting:
		return
	var pressed := (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed() and not event.is_echo()
	if not pressed:
		return
	get_viewport().set_input_as_handled()  # ce bouton ne sert qu'a reprendre
	waiting = false
	pause_panel.visible = false
	dim.visible = false
	if paused_by_us:
		get_tree().paused = false

func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size
