class_name InventoryPanel
extends Control

# Inventaire (touche des passifs, Tab / Select) : met le jeu en pause et montre l'objet actif puis
# les passifs, chacun avec sa fiche (icone, tier, nom, effet). Haut / bas fait defiler ; la meme
# touche, Echap ou B referme. Pose dans la couche d'interface de la carte et de l'arene.

const SCROLL_STEP := 30

var scroll: ScrollContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # reste actif pendant la pause qu'il declenche
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("inventory") and not get_tree().paused:
			get_viewport().set_input_as_handled()
			open()
		return
	get_viewport().set_input_as_handled()  # le jeu en pause ne doit rien recevoir
	if event.is_action_pressed("inventory") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("move_down", true):
		scroll.scroll_vertical += SCROLL_STEP
	elif event.is_action_pressed("ui_up", true) or event.is_action_pressed("move_up", true):
		scroll.scroll_vertical -= SCROLL_STEP

func open() -> void:
	for banner in get_tree().get_nodes_in_group("item_banner"):
		banner.queue_free()  # sinon elle passerait au-dessus de l'inventaire
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.05, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(_title("Inventaire", 18))

	box.add_child(_title("Objet actif", 11, 0.7))
	if GameState.has_active_item():
		var charges := "  (%d/%d charges)" % [GameState.active_charges, GameState.ACTIVE_MAX_CHARGES]
		box.add_child(ItemCard.make(GameState.active_item_id, false, charges))
	else:
		box.add_child(_title("Aucun", 10, 0.6))

	box.add_child(_title("Objets passifs (%d)" % GameState.passive_count(), 11, 0.7))
	scroll = ScrollContainer.new()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in GameState.passive_items:
		var count: int = GameState.passive_items[id]
		list.add_child(ItemCard.make(id, false, "  x%d" % count if count > 1 else ""))
	if GameState.passive_items.is_empty():
		list.add_child(_title("Aucun objet passif.", 10, 0.6))
	scroll.custom_minimum_size = Vector2(440, mini(160, 32 * maxi(1, GameState.passive_items.size())))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(list)
	box.add_child(scroll)
	box.add_child(_title("%s : fermer" % Controls.name_of("inventory"), 9, 0.55))
	add_child(panel)

	visible = true
	get_tree().paused = true
	await get_tree().process_frame
	panel.reset_size()
	panel.position = (get_viewport_rect().size - panel.size) / 2.0

func close() -> void:
	visible = false
	get_tree().paused = false
	for child in get_children():
		child.queue_free()

func _title(text: String, font_size: int, alpha: float = 1.0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate.a = alpha
	return label

func _exit_tree() -> void:
	if visible:
		get_tree().paused = false
