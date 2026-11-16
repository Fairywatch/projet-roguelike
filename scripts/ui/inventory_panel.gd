class_name InventoryPanel
extends Control

# Inventaire (touche des passifs, Tab / Select) : met le jeu en pause. A gauche l'objet actif, les
# maledictions en cours et les passifs (chacun avec sa fiche : icone, tier, nom, effet) ; a droite
# la fiche de stats du joueur. Haut / bas, la molette ou le stick font defiler la liste ; la meme
# touche, Echap ou B referme. Pose dans la couche d'interface de la carte et de l'arene.

const SCROLL_STEP := 30
const LIST_HEIGHT := 190
const LIST_WIDTH := 300
const STATS_WIDTH := 190

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
	# La souris va a l'interface (molette sur la liste) : avaler ses evenements ici l'empechait
	# d'arriver jusqu'a la liste, qui ne defilait plus qu'au clavier.
	if event is InputEventMouse:
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
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var panel := PanelContainer.new()
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	panel.add_child(columns)
	columns.add_child(_items_column())
	columns.add_child(VSeparator.new())
	columns.add_child(_stats_column())
	add_child(panel)

	visible = true
	get_tree().paused = true
	await get_tree().process_frame
	panel.reset_size()
	panel.position = ((get_viewport_rect().size - panel.size) / 2.0).max(Vector2.ZERO)

func _items_column() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.add_child(_title("Inventaire", 16))

	# Tout ce qui peut s'allonger est dans la liste qui defile.
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(_title("Objet actif", 11, 0.7))
	if GameState.has_active_item():
		var charges := "  (%d/%d charges)" % [GameState.active_charges, GameState.ACTIVE_MAX_CHARGES]
		list.add_child(ItemCard.make(GameState.active_item_id, false, charges))
	else:
		list.add_child(_title("Aucun", 10, 0.6))
	if not GameState.curses.is_empty():
		list.add_child(_title("Malédictions", 11, 0.7))
		for curse in GameState.curses:
			var left: int = curse["floors"]
			list.add_child(ItemCard.make(curse["id"], false, "  (encore %d étage%s)" % [left, "s" if left > 1 else ""]))
	list.add_child(_title("Objets passifs (%d)" % GameState.passive_count(), 11, 0.7))
	for id in GameState.passive_items:
		var count: int = GameState.passive_items[id]
		list.add_child(ItemCard.make(id, false, "  x%d" % count if count > 1 else ""))
	if GameState.passive_items.is_empty():
		list.add_child(_title("Aucun objet passif.", 10, 0.6))

	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(LIST_WIDTH, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.add_child(list)
	box.add_child(scroll)
	box.add_child(_title("%s : fermer   ·   haut / bas : défiler" % Controls.name_of("inventory"), 9, 0.55))
	return box

func _stats_column() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.add_child(_title("Statistiques", 16))
	# Avec beaucoup d'effets, la fiche defile a la molette au lieu de sortir de l'ecran.
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 1)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for line in PlayerStats.lines():
		var row := HBoxContainer.new()
		var name_label := _title(line[0], 9, 0.75)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var value := _title(line[1], 9)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		rows.add_child(row)
	var stats_scroll := ScrollContainer.new()
	stats_scroll.custom_minimum_size = Vector2(STATS_WIDTH, LIST_HEIGHT + 20)
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()  # les valeurs ne touchent pas la barre de defilement
	margin.add_theme_constant_override("margin_right", 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(rows)
	stats_scroll.add_child(margin)
	box.add_child(stats_scroll)
	return box

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
