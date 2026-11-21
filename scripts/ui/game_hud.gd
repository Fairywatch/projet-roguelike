class_name GameHud
extends Control

# HUD commun a la carte et a l'arene.
#   En haut a gauche : les coeurs, la jauge de dash (combat) et le lieu (carte).
#   En haut a droite : l'objet actif (icone, touche, charges), les objets passifs et les pieces.
#   En bas (en haut en combat) : les messages, dans une bulle (Toast).
# Tout se lit dans GameState ; la scene appelle refresh() quand quelque chose change.

const ACTIVE_ICON := 22.0
# Un ennemi (ou le joueur) qui passe sous un panneau du haut le rend presque transparent : rien
# ne se cache sous le HUD, meme dans les coins de l'arene.
const SEE_THROUGH := 0.25
const SEE_THROUGH_MARGIN := 22.0  # demi-taille d'un sprite, environ
const SEE_THROUGH_SPEED := 6.0
const SEE_THROUGH_GROUPS := ["mobs", "wanderers", "player"]

var hearts := Hearts.new()
var dash_gauge: DashGauge  # seulement en combat
var special_gauge: DashGauge  # rafale de plumes, seulement en combat
var toast := Toast.new()
var place_label := Label.new()
var hurt_overlay := ColorRect.new()

var left_panel := PanelContainer.new()
var right_panel := PanelContainer.new()
var active_frame := PanelContainer.new()
var active_style := StyleBoxFlat.new()
var active_icon := TextureRect.new()
var active_name := Label.new()
var key_badge := PanelContainer.new()
var key_label := Label.new()
var pips := HudIcon.make("pips")
var passives_label := Label.new()
var coins_label := Label.new()
var coins_shown := -1
var shown_state := ""
var see_through: Array[Control] = []  # panneaux qui s'effacent quand quelqu'un passe dessous (voir _process)

static func make(with_dash: bool) -> GameHud:
	var hud := GameHud.new()
	if with_dash:
		hud.dash_gauge = DashGauge.new()
		hud.special_gauge = DashGauge.new()
		hud.special_gauge.fill = Color(0.58, 0.42, 0.8)  # crayon violet : la rafale
		hud.special_gauge.charging = Color(0.7, 0.64, 0.8)
	return hud

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Voile rouge quand on est touche (sous le reste du HUD).
	hurt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_overlay.color = Color(0.9, 0.1, 0.2, 0.0)
	hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hurt_overlay)

	# Gauche : coeurs, jauge de dash, lieu.
	Paper.apply(left_panel)
	left_panel.theme_type_variation = &"HudPanel"
	left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_panel.position = Vector2(6, 5)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	left.add_child(hearts)
	if dash_gauge:
		left.add_child(dash_gauge)
		left.add_child(special_gauge)
	place_label.add_theme_font_size_override("font_size", 15)
	place_label.add_theme_constant_override("line_spacing", -2)
	place_label.modulate = Color(1, 1, 1, 0.85)
	place_label.visible = false
	left.add_child(place_label)
	left_panel.add_child(left)
	add_child(left_panel)

	# Droite : objet actif | passifs et pieces.
	Paper.apply(right_panel)
	right_panel.theme_type_variation = &"HudPanel"
	right_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_panel.offset_left = -6
	right_panel.offset_right = -6
	right_panel.offset_top = 5
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.add_child(_active_block())
	var line := VSeparator.new()
	line.modulate.a = 0.5
	row.add_child(line)
	var counters := VBoxContainer.new()
	counters.add_theme_constant_override("separation", 1)
	counters.add_child(_counter("gem", passives_label))
	counters.add_child(_counter("coin", coins_label))
	row.add_child(counters)
	right_panel.add_child(row)
	add_child(right_panel)

	toast.top_y = 62.0
	add_child(toast)
	see_through.append_array([left_panel, right_panel])
	refresh()

func _process(delta: float) -> void:
	var bodies: Array[Rect2] = []
	for group in SEE_THROUGH_GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			if node is CanvasItem and node.is_visible_in_tree():
				bodies.append(_screen_rect(node))
	for panel in see_through:
		if not is_instance_valid(panel) or not panel.visible:
			continue
		var rect := panel.get_global_rect()
		var covered := bodies.any(func(body: Rect2): return rect.intersects(body))
		panel.modulate.a = move_toward(panel.modulate.a, SEE_THROUGH if covered else 1.0, delta * SEE_THROUGH_SPEED)

# Place occupee a l'ecran : le sprite entier (les boss sont grands), sinon un carre autour du centre.
func _screen_rect(node: CanvasItem) -> Rect2:
	var sprite: Variant = node.get("sprite")
	if sprite is Sprite2D and is_instance_valid(sprite):
		return sprite.get_global_transform_with_canvas() * sprite.get_rect()
	var origin := node.get_global_transform_with_canvas().origin
	return Rect2(origin - Vector2.ONE * SEE_THROUGH_MARGIN, Vector2.ONE * SEE_THROUGH_MARGIN * 2.0)

func _active_block() -> HBoxContainer:
	var block := HBoxContainer.new()
	block.add_theme_constant_override("separation", 5)
	# Case de l'objet actif : un cadre d'encre sur le papier, coins nets.
	active_style.bg_color = Color(0.86, 0.8, 0.68)
	active_style.set_border_width_all(2)
	active_style.set_corner_radius_all(0)
	active_style.set_content_margin_all(2)
	active_frame.add_theme_stylebox_override("panel", active_style)
	active_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	active_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	active_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	active_icon.custom_minimum_size = Vector2.ONE * ACTIVE_ICON
	active_frame.add_child(active_icon)
	block.add_child(active_frame)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	active_name.add_theme_font_size_override("font_size", 15)
	text.add_child(active_name)
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 4)
	key_badge.theme_type_variation = &"KeyBadge"
	key_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	key_label.add_theme_font_size_override("font_size", 15)
	key_label.add_theme_color_override("font_color", Paper.INK)
	key_label.add_theme_constant_override("outline_size", 0)
	key_badge.add_child(key_label)
	keys.add_child(key_badge)
	keys.add_child(pips)
	text.add_child(keys)
	block.add_child(text)
	return block

func _counter(icon_kind: String, label: Label) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(HudIcon.make(icon_kind))
	label.add_theme_font_size_override("font_size", 15)
	label.custom_minimum_size.x = 18
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(label)
	return row

# Lieu affiche sous les coeurs (carte) : "Mardi - Étage 2 / 6" et la famille de sommeil.
func set_place(text: String) -> void:
	place_label.text = text
	place_label.visible = text != ""

func refresh() -> void:
	var has_active := GameState.has_active_item()
	if has_active:
		var id: String = GameState.active_item_id
		var charged: bool = GameState.active_charges > 0
		active_icon.texture = Items.icon(id)
		active_icon.modulate = Color.WHITE if charged else Color(1, 1, 1, 0.35)
		active_name.text = Items.find_active(id)["name"]
		active_name.add_theme_color_override("font_color", Items.rarity_ink(id))
		active_style.border_color = Paper.INK if charged else Paper.INK_SOFT
		pips.max_value = GameState.ACTIVE_MAX_CHARGES
		pips.value = GameState.active_charges
	else:
		active_icon.texture = null
		active_name.text = "Aucun objet actif"
		active_name.add_theme_color_override("font_color", Paper.INK_SOFT)
		active_style.border_color = Paper.INK_SOFT
		pips.max_value = 0
	key_label.text = Controls.name_of("active")
	key_badge.visible = has_active
	passives_label.text = "%d" % GameState.passive_count()
	coins_label.text = "%d" % GameState.coins
	if coins_shown >= 0 and GameState.coins > coins_shown:
		_pop(coins_label)
	coins_shown = GameState.coins

# A appeler a chaque image : ne rafraichit que si l'objet actif, ses charges, les passifs, les
# pieces ou la touche ont change.
func sync() -> void:
	var state := "%s|%d|%d|%d|%s" % [GameState.active_item_id, GameState.active_charges, GameState.passive_count(), GameState.coins, Controls.name_of("active")]
	if state != shown_state:
		shown_state = state
		refresh()

func set_health(hp: int, max_hp: int) -> void:
	hearts.max_hp = max_hp
	hearts.hp = hp

func set_dash(ratio: float) -> void:
	if dash_gauge:
		dash_gauge.ratio = ratio

func set_special(ratio: float) -> void:
	if special_gauge:
		special_gauge.ratio = ratio

func say(text: String, duration: float = 4.0) -> void:
	toast.say(text, duration)

# Voile rouge bref quand le joueur perd un coeur (adouci si les flashs sont desactives).
func flash_hurt() -> void:
	hurt_overlay.color.a = 0.22 if Settings.enabled("flashes") else 0.08
	var tween := hurt_overlay.create_tween()
	tween.tween_property(hurt_overlay, "color:a", 0.0, 0.35).set_ease(Tween.EASE_OUT)

func _pop(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2(1.35, 1.35)
	control.create_tween().tween_property(control, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Met une etiquette d'une scene dans une bulle du HUD, au meme endroit (menu, hub).
static func pill(label: Label) -> PanelContainer:
	var panel := PanelContainer.new()
	Paper.apply(panel)
	panel.theme_type_variation = &"HudPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width := label.offset_right - label.offset_left
	var top := label.offset_top
	var where := label.anchor_left
	var parent := label.get_parent()
	parent.add_child(panel)
	parent.move_child(panel, label.get_index())
	label.reparent(panel, false)
	# Sur le papier : a l'encre (les couleurs prevues pour le fond sombre ne se liraient pas).
	label.remove_theme_color_override("font_color")
	label.remove_theme_color_override("font_outline_color")
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		label.custom_minimum_size.x = width
	if where >= 1.0:
		panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		panel.offset_left = -6
		panel.offset_right = -6
	elif where >= 0.5:
		panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		panel.offset_left = 0
		panel.offset_right = 0
	else:
		panel.offset_left = 6
		panel.offset_right = 6
	panel.offset_top = top
	panel.offset_bottom = top
	return panel
