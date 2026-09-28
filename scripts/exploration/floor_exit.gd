extends Area2D

# Portail de changement d'etage : toujours garde par un boss (voir GameState.start_guardian_fight).

const UP_COLOR := Color(1, 0.85, 0.45)
const DOWN_COLOR := Color(0.9, 0.2, 0.3)

@onready var visual: Sprite2D = $Visual

var time := 0.0
var force_descend := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var color := DOWN_COLOR if force_descend else UP_COLOR
	visual.modulate = color
	add_child(DreamTheme.make_light(color, 120.0, 1.2))

func _process(delta: float) -> void:
	time += delta
	visual.scale = Vector2.ONE * 2.0 * (1.0 + sin(time * 3.0) * 0.08)
	visual.rotation = time * 1.5

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or body.frozen:
		return
	body.frozen = true
	GameState.start_guardian_fight(force_descend or GameState.floor_index < 0)
	# Fuite du combat (debug) : retour au debut de l'etage plutot que sur le portail.
	GameState.return_position = Vector2.ZERO
	SceneTransition.change_scene("res://scenes/combat/CombatArena.tscn")
