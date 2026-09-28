extends Area2D

signal message(text: String)
# entry : {"id", "pos"} ajoute a current_floor()["ground_items"], a faire apparaitre par la carte.
signal item_dropped(entry: Dictionary)

const DROP_OFFSET := Vector2(0, 56)

const SEAL_WINS_REQUIRED := 2
const TEX_CLOSED := preload("res://assets/sprites/props/chest_closed.png")
const TEX_SEALED := preload("res://assets/sprites/props/chest_sealed.png")
const TEX_OPENED := preload("res://assets/sprites/props/chest_open.png")

@onready var visual: Sprite2D = $Visual
@onready var glow: PointLight2D = DreamTheme.make_light(Color(1, 0.8, 0.4), 70.0, 0.7)

var chest_id := 0
var sealed := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_child(glow)
	_refresh_visual()

func _is_opened() -> bool:
	return chest_id in GameState.current_floor()["opened_chests"]

func _refresh_visual() -> void:
	glow.visible = not _is_opened()
	if _is_opened():
		visual.texture = TEX_OPENED
	elif sealed:
		visual.texture = TEX_SEALED
		glow.color = Color(0.7, 0.4, 1)
	else:
		visual.texture = TEX_CLOSED

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or _is_opened():
		return
	var missing: int = SEAL_WINS_REQUIRED - GameState.current_floor()["wins"]
	if sealed and missing > 0:
		message.emit("Coffre scelle : gagne encore %d combat(s) sur cet etage." % missing)
		return
	var entry := {"id": GameState.roll_item_id(), "pos": position + DROP_OFFSET}
	GameState.current_floor()["opened_chests"].append(chest_id)
	GameState.current_floor()["ground_items"].append(entry)
	_refresh_visual()
	Fx.puff(get_parent(), global_position, Color(1, 0.85, 0.4), 16)
	item_dropped.emit(entry)
	message.emit("Coffre ouvert : %s ! (E pour le prendre)" % Items.find(entry["id"])["name"])
