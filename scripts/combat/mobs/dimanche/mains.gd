extends BaseMob

# Mains du lundi (dimanche, Angoisse) : sous terre (invisible, invulnerable), elles annoncent un
# cercle sous le joueur puis en sortent pour l'agripper ; elles restent dehors un instant, la
# fenetre pour les frapper. Variante : une ligne de mains qui avance vers le joueur.
# Cauchemar : l'agrippement ralentit aussi.

const GRAB_RADIUS := 42.0
const HAND := Color(0.75, 0.7, 0.85)
const OUT_TIME := 1.3

func _texture_path() -> String:
	return "res://assets/sprites/mobs/dimanche/mains.png"

func _on_ready() -> void:
	display_name = "Mains du lundi"
	hp = 3
	chase_speed = 0.0
	attack_range = 2000.0
	telegraph_duration = 0.9
	attack_duration = 0.2
	cooldown_duration = 1.8
	_burrow()

func _burrow() -> void:
	sprite.self_modulate.a = 0.0
	invulnerable = true

func _on_telegraph_begin() -> void:
	var target := player.global_position
	if alt:
		var from := global_position
		for i in 5:
			var spot := from.lerp(target, (i + 1) / 5.0)
			Hazards.zone(spot, GRAB_RADIUS * 0.8, "damage", telegraph_duration + i * 0.15, 0.2, HAND)
		global_position = target
	else:
		Hazards.zone(target, GRAB_RADIUS, "damage", telegraph_duration, 0.2, HAND)
		global_position = target

func _on_attack_begin() -> void:
	sprite.self_modulate.a = 1.0
	invulnerable = false
	var p := Hazards.player()
	if nightmare and p and p.global_position.distance_to(global_position) < GRAB_RADIUS:
		p.apply_slow(1.0, 0.5)

func _on_attack_end() -> void:
	if await pause(OUT_TIME):
		_burrow()
