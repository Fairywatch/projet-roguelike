class_name SettingsPanel
extends PanelContainer

# Onglet Parametres du menu : une case a cocher par option de Settings.LABELS.

signal closed

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.12, 0.95)
	style.border_color = Color(0.6, 0.5, 0.9, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var title := Label.new()
	title.text = "Parametres"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)

	for option in Settings.LABELS:
		var check := CheckButton.new()
		check.text = Settings.LABELS[option]
		check.button_pressed = Settings.enabled(option)
		check.add_theme_font_size_override("font_size", 12)
		check.toggled.connect(func(on): Settings.set_option(option, on))
		box.add_child(check)

	var back := Button.new()
	back.text = "Retour"
	back.add_theme_font_size_override("font_size", 12)
	back.pressed.connect(_close)
	box.add_child(back)

	box.get_child(1).grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	closed.emit()
	queue_free()
