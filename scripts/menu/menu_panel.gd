class_name MenuPanel
extends PanelContainer

# Cadre commun des panneaux du menu (Parametres, Nuits, Boutique) : titre, contenu, bouton
# Retour, Echap pour fermer. Les sous-classes remplissent `box` dans build().

signal closed

var box := VBoxContainer.new()

static func style_button(button: Button, font_size: int = 12) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		match state:
			"normal":
				style.bg_color = Color(0.1, 0.07, 0.2, 0.85)
			"disabled":
				style.bg_color = Color(0.08, 0.06, 0.12, 0.6)
			_:
				style.bg_color = Color(0.32, 0.22, 0.52, 0.95)
		style.border_color = Color(0.6, 0.5, 0.9, 0.9 if state != "disabled" else 0.3)
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		style.set_content_margin_all(4)
		button.add_theme_stylebox_override(state, style)
	button.focus_entered.connect(Sound.play.bind("ui_move", -6.0, 0.0))

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.12, 0.95)
	style.border_color = Color(0.6, 0.5, 0.9, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	box.add_theme_constant_override("separation", 5)
	add_child(box)
	rebuild()

func rebuild() -> void:
	for child in box.get_children():
		child.queue_free()
	build()
	var back := add_button("Retour", close)
	back.custom_minimum_size.y = 22
	await get_tree().process_frame
	reset_size()
	position = (get_viewport_rect().size - size) / 2.0
	for child in box.get_children():
		if child is BaseButton and not child.disabled and not child.is_queued_for_deletion():
			child.grab_focus()
			break

func build() -> void:
	pass

func add_title(text: String) -> void:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)

func add_note(text: String, color: Color = Color(1, 1, 1, 0.65)) -> void:
	var note := Label.new()
	note.text = text
	note.modulate = color
	note.add_theme_font_size_override("font_size", 10)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 360
	box.add_child(note)

func add_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	style_button(button)
	button.pressed.connect(func(): Sound.play("ui_select"); action.call())
	box.add_child(button)
	return button

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	closed.emit()
	queue_free()
