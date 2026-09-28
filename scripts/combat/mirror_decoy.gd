extends Node2D

# Leurre de "Sept Ans de Malheur" : les mobs le prennent pour cible tant qu'il existe.
const DURATION := 1.5

var time := 0.0

func _ready() -> void:
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.player = self

func _exit_tree() -> void:
	var real_player := get_tree().get_first_node_in_group("player")
	for mob in get_tree().get_nodes_in_group("mobs"):
		if mob.player == self:
			mob.player = real_player

func _process(delta: float) -> void:
	time += delta
	modulate.a = 1.0 - (time / DURATION)
	scale = Vector2.ONE * (1.0 + sin(time * 10.0) * 0.1)
	if time >= DURATION:
		queue_free()
