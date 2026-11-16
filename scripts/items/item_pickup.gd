class_name ItemPickup
extends Area2D

# Objet pose au sol. E a proximite : on le prend. Un passif s'ajoute aux autres ; un actif
# remplace l'actif tenu, qui reste au sol a sa place.

signal taken(pickup: ItemPickup, taken_id: String, old_id: String)

const RADIUS := 36.0

var item_id := ""
var charges := -1  # actif deja entame (repose au sol) ; -1 = neuf
var mystery := false  # objet mystere : on ne sait ce que c'est (objet ou malediction) qu'en le prenant
var player_near := false
var icon := Sprite2D.new()
var label := Label.new()
var glow: PointLight2D

func _ready() -> void:
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = RADIUS
	add_child(shape)
	icon.scale = Vector2(2, 2)
	add_child(icon)
	glow = DreamTheme.make_light(Color.WHITE, 60.0, 0.9)
	add_child(glow)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(200, 30)
	label.position = Vector2(-100, -48)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(label)
	var tween := icon.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween.tween_property(icon, "position:y", -6.0, 0.8)
	tween.tween_property(icon, "position:y", 0.0, 0.8)
	body_entered.connect(func(body): _set_near(body, true))
	body_exited.connect(func(body): _set_near(body, false))
	_refresh()

func _set_near(body: Node2D, near: bool) -> void:
	if body.is_in_group("player"):
		player_near = near
		_refresh()

func _refresh() -> void:
	var shown: String = Items.MYSTERY["id"] if mystery else item_id
	var item := Items.find(shown)
	icon.texture = Items.icon(shown)
	# Couleur du nom et de la lueur selon la rarete (commun, rare, legendaire).
	label.add_theme_color_override("font_color", Items.rarity_color(shown))
	glow.color = Items.rarity_color(shown)
	if player_near and mystery:
		label.text = "%s : prendre %s\n%s" % [Controls.name_of("interact"), item["name"], item["desc"]]
	elif player_near:
		var rarity_name: String = Items.RARITY_NAMES[item["rarity"]]
		label.text = "%s : prendre %s  [%s]  (%s)\n%s" % [Controls.name_of("interact"), item["name"], Items.tier(shown), rarity_name, item["desc"]]
	else:
		label.text = item["name"]

func _unhandled_input(event: InputEvent) -> void:
	if not player_near or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	var taken_id := item_id
	var old_charges := GameState.active_charges
	var old := GameState.take_item(item_id, charges)
	charges = old_charges
	Fx.puff(get_parent(), global_position, Color(0.8, 0.85, 1), 12)
	taken.emit(self, taken_id, old)
	if old == "":
		queue_free()
	else:
		item_id = old
		mystery = false  # l ancien actif, lui, on le connait
		_refresh()
