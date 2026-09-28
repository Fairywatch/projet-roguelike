extends Area2D

signal message(text: String)

const SEAL_WINS_REQUIRED := 2
const COLOR_CLOSED := Color(0.85, 0.6, 0.2, 1)
const COLOR_SEALED := Color(0.55, 0.3, 0.85, 1)
const COLOR_OPENED := Color(0.3, 0.3, 0.35, 1)

@onready var visual: Polygon2D = $Visual

var chest_id := 0
var sealed := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_refresh_visual()

func _is_opened() -> bool:
	return chest_id in GameState.current_floor()["opened_chests"]

func _refresh_visual() -> void:
	if _is_opened():
		visual.color = COLOR_OPENED
	elif sealed:
		visual.color = COLOR_SEALED
	else:
		visual.color = COLOR_CLOSED

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or _is_opened():
		return
	var missing: int = SEAL_WINS_REQUIRED - GameState.current_floor()["wins"]
	if sealed and missing > 0:
		message.emit("Coffre scelle : gagne encore %d combat(s) sur cet etage." % missing)
		return
	var id := GameState.roll_item_id()
	GameState.grant_item(id)
	GameState.current_floor()["opened_chests"].append(chest_id)
	_refresh_visual()
	message.emit("Coffre ouvert : %s !" % Items.find(id)["name"])
