extends BaseMob

# Bailleur (lundi, Fatigue) : ouvre grand la bouche puis aspire le joueur vers lui ; tout
# contact avec sa bouche pendant l'aspiration blesse.
# Variante : expire un nuage de sommeil qui ralentit. Cauchemar : aspiration plus forte.

const PULL_RANGE := 240.0
const PULL_SPEED := 140.0
const BITE_RANGE := 36.0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/lundi/bailleur.png"

func _on_ready() -> void:
	display_name = "Bailleur"
	hp = 4
	chase_speed = 45.0
	attack_range = 170.0
	telegraph_duration = 0.8
	attack_duration = 1.2
	cooldown_duration = 1.2

func _on_attack_begin() -> void:
	if alt:
		var direction := (player.global_position - global_position).normalized()
		Hazards.zone(global_position + direction * 90.0, 80.0 if nightmare else 64.0, "slow", 0.4, 3.0, Color(0.7, 0.72, 1.0))

func _physics_process(delta: float) -> void:
	super(delta)
	var p := Hazards.player()
	if state != State.ATTACK or alt or p == null:
		return
	var to_mouth := global_position - p.global_position
	if to_mouth.length() < PULL_RANGE:
		p.add_external_velocity(to_mouth.normalized() * PULL_SPEED * (1.35 if nightmare else 1.0))
	if to_mouth.length() < BITE_RANGE:
		p.take_damage()
