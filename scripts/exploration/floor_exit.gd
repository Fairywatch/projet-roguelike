extends Area2D

@onready var visual: Polygon2D = $Visual

var time := 0.0
var force_descend := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if force_descend:
		visual.color = Color(0.6, 0.1, 0.15, 1)

func _process(delta: float) -> void:
	time += delta
	visual.scale = Vector2.ONE * (1.0 + sin(time * 3.0) * 0.15)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var going_down := force_descend or GameState.floor_index < 0
	if going_down and GameState.floor_index == 0:
		GameState.guardian_fight = true
		SceneTransition.change_scene("res://scenes/combat/CombatArena.tscn")
		return
	if going_down and GameState.floor_index == GameState.MIN_FLOOR_INDEX:
		GameState.complete_negative_run()
	elif going_down:
		GameState.descend_floor()
	else:
		GameState.advance_floor()
	SceneTransition.change_scene(GameState.return_map_path)
