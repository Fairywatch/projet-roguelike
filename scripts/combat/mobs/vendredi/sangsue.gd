extends BaseMob

# Sangsue de sommeil (vendredi, Epuisement) : s'accroche au joueur ; tant qu'elle tient, il est
# ralenti et son dash ne se recharge pas. Un dash la decroche (elle est sonnee un instant).
# Variante : s'accroche aux autres ennemis et les soigne. Cauchemar : ralentit plus fort.

const GRAB_RANGE := 28.0
const HEAL_EVERY := 1.0

var host: Node2D  # ce a quoi elle est accrochee (joueur, ou ennemi pour la variante)
var heal_timer := HEAL_EVERY

func _texture_path() -> String:
	return "res://assets/sprites/mobs/vendredi/sangsue.png"

func _on_ready() -> void:
	display_name = "Sangsue de sommeil"
	hp = 3
	chase_speed = 95.0
	attack_range = 0.0  # pas d'attaque : elle s'accroche

func _target() -> Node2D:
	if not alt:
		return Hazards.player()
	var allies := get_tree().get_nodes_in_group("mobs").filter(func(m): return m != self and m.state != State.DEAD and m.display_name != display_name)
	if allies.is_empty():
		return null
	allies.sort_custom(func(a, b): return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
	return allies[0]

func _physics_process(delta: float) -> void:
	if state != State.CHASE:
		return
	if is_instance_valid(host) and host.is_inside_tree():
		global_position = host.global_position + Vector2(0, -26)
		if host == Hazards.player():
			if host.dashing:  # le dash la decroche
				host = null
				global_position += Vector2(randf_range(-60, 60), 60)
				stun(1.0)
				return
			host.apply_slow(0.15, 0.4 if nightmare else 0.55)
			host.dash_cooldown_timer = maxf(host.dash_cooldown_timer, 0.3)
		else:
			heal_timer -= delta
			if heal_timer <= 0.0:
				heal_timer = HEAL_EVERY
				host.hp = mini(host.max_hp, host.hp + 1)
				Fx.flash(host.sprite, Color(0.5, 1, 0.6), 0.15)
		return
	host = null
	var target := _target()
	if target == null:
		return
	velocity = (target.global_position - global_position).normalized() * chase_speed
	move_and_slide()
	if target.global_position.distance_to(global_position) < GRAB_RANGE + (30.0 if alt else 0.0):
		host = target
