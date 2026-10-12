extends BaseMob

# Mouton insomniaque (lundi, Fatigue) : saute en arc vers la position du joueur ; l'atterrissage
# fait une onde de choc (zone annoncee au sol pendant tout le saut).
# Variante : arrive en troupeau de 3 petits moutons. Cauchemar : onde plus large.

const JUMP_TIME := 0.5
const HERD_SIZE := 2  # petits moutons en plus du chef

var small := false
var target := Vector2.ZERO

func _texture_path() -> String:
	return "res://assets/sprites/mobs/lundi/mouton.png"

func _on_ready() -> void:
	display_name = "Mouton insomniaque"
	hp = 2 if small else 3
	chase_speed = 60.0
	attack_range = 190.0
	telegraph_duration = 0.6
	attack_duration = JUMP_TIME
	cooldown_duration = 1.3
	if small:
		sprite.scale *= 0.7
	if alt and not small:
		_spawn_herd.call_deferred()

func _spawn_herd() -> void:
	for i in HERD_SIZE:
		var lamb: BaseMob = get_script().new()
		lamb.small = true
		lamb.nightmare = nightmare
		lamb.position = position + Vector2.from_angle(TAU * i / HERD_SIZE) * 50.0
		get_parent().add_child(lamb)

func _on_telegraph_begin() -> void:
	target = Hazards.clamp_to_arena(player.global_position)
	var radius := 64.0 if nightmare else 50.0
	Hazards.zone(target, radius * (0.75 if small else 1.0), "damage", telegraph_duration + JUMP_TIME, 0.15, Color(1, 0.55, 0.45))

func _on_attack_begin() -> void:
	create_tween().tween_property(self, "global_position", target, JUMP_TIME)
	var arc := create_tween()
	arc.tween_property(sprite, "offset:y", -14.0, JUMP_TIME / 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	arc.tween_property(sprite, "offset:y", 0.0, JUMP_TIME / 2.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
