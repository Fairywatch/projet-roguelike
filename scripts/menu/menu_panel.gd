class_name MenuPanel
extends PanelContainer

# Cadre commun des panneaux du menu (Parametres, Nuits, Boutique) : titre, contenu, bouton
# Retour, Echap pour fermer. Les sous-classes remplissent `box` dans build().

signal closed

var box := VBoxContainer.new()
var appeared := false

# Apparence (cadre, boutons) : theme du projet, assets/ui/theme.tres.
func _ready() -> void:
	Paper.apply(self)
	box.add_theme_constant_override("separation", 5)
	add_child(box)
	# Un texte a la ligne se mesure d'abord sans sa largeur, puis rapetisse : on suit le contenu.
	box.minimum_size_changed.connect(_fit, CONNECT_DEFERRED)
	rebuild()

func rebuild() -> void:
	# Retires tout de suite : sinon, reconstruit depuis _input (touche changee), l'ancien contenu est
	# encore mesure avec le nouveau et le panneau, deux fois trop haut, deborde de l'ecran.
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	build()
	var back := add_button("Retour", close)
	back.custom_minimum_size.y = 22
	await get_tree().process_frame
	_fit()
	if not appeared:
		appeared = true
		pop_in(self)
	for child in box.find_children("*", "BaseButton", true, false):  # aussi dans les grilles
		if not child.disabled and not child.is_queued_for_deletion():
			child.grab_focus()
			break

func build() -> void:
	pass

# Apparition d'un panneau : fondu et petit rebond depuis son centre.
static func pop_in(panel: Control) -> void:
	panel.pivot_offset = panel.size / 2.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.94, 0.94)
	var tween := panel.create_tween().set_parallel()
	tween.tween_property(panel, "modulate:a", 1.0, 0.14)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Taille du contenu, centre a l'ecran.
func _fit() -> void:
	reset_size()
	position = ((get_viewport_rect().size - size) / 2.0).max(Vector2.ZERO)

func add_title(text: String) -> void:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = &"PixelTitle"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)

func add_note(text: String, color: Color = Color(1, 1, 1, 0.65)) -> void:
	var note := Label.new()
	note.text = text
	note.modulate = color
	note.add_theme_font_size_override("font_size", 15)
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
