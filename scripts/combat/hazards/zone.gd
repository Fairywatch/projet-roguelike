extends Node2D

# Zone au sol. Pale pendant arm_delay (telegraphe), puis active pendant active_time :
#   "damage" : blesse le joueur qui s'y trouve (son invincibilite apres un coup evite l'acharnement) ;
#   "slow"   : ralentit le joueur tant qu'il est dedans ;
#   "push"   : pousse le joueur dans la direction push (tapis roulant...).
# Voir Hazards.zone().

var radius := 60.0
var kind := "damage"
var arm_delay := 0.8
var active_time := 0.2
var color := Color(1, 0.4, 0.4)
var push := Vector2.ZERO
var t := 0.0

func _physics_process(delta: float) -> void:
	t += delta
	if t > arm_delay + active_time:
		queue_free()
		return
	var p: Node2D = get_tree().get_first_node_in_group("player")
	if p and t >= arm_delay and p.global_position.distance_to(global_position) <= radius + 8.0:
		match kind:
			"damage":
				p.take_damage()
			"slow":
				p.apply_slow(0.2, 0.45)
			"push":
				p.add_external_velocity(push)
	queue_redraw()

func _draw() -> void:
	if t < arm_delay:
		var pulse := 0.12 + 0.1 * absf(sin(t * 10.0))
		draw_circle(Vector2.ZERO, radius, Color(color, pulse))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, 0.6), 2.0)
	else:
		draw_circle(Vector2.ZERO, radius, Color(color, 0.45 if kind == "damage" else 0.3))
