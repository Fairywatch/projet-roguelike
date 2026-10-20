class_name MenuPanel
extends PanelContainer

# Cadre commun des panneaux du menu (Parametres, Nuits, Boutique) : titre, contenu, bouton
# Retour, Echap pour fermer. Les sous-classes remplissent `box` dans build().

signal closed

var box := VBoxContainer.new()

# Apparence (cadre, boutons) : theme du projet, assets/ui/theme.tres.
func _ready() -> void:
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
	for child in box.find_children("*", "BaseButton", true, false):  # aussi dans les grilles
		if not child.disabled and not child.is_queued_for_deletion():
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
	button.pressed.connect(func(): Sound.play("ui_select"); action.call())
	box.add_child(button)
	return button

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	closed.emit()
	queue_free()
