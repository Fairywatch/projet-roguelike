extends BaseMob

# La Grande Couette (boss du lundi) : rampe lentement et recouvre des zones de l'arene, qui
# restent dangereuses un moment ; tous les trois coups, elle libere un Bailleur.
# Variante : les zones forment une ligne qui balaie l'arene. Cauchemar : une zone de plus.

const MINION := "lundi/bailleur"
const MAX_MINIONS := 2
const ZONE_COLOR := Color(0.62, 0.45, 0.95)

var cycle := 0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/lundi/grande_couette.png"

func _on_ready() -> void:
	display_name = "La Grande Couette"
	is_boss = true
	hp = 16
	chase_speed = 35.0
	attack_range = 2000.0  # attaque des que son temps de recharge est fini
	telegraph_duration = 0.6
	attack_duration = 0.3
	cooldown_duration = 1.6

func _physics_process(delta: float) -> void:
	super(delta)
	if state == State.COOLDOWN and player:  # rampe vers le joueur entre deux attaques
		velocity = (player.global_position - global_position).normalized() * chase_speed
		move_and_slide()

func _on_attack_begin() -> void:
	cycle += 1
	if cycle % 3 == 0 and _minion_count() < MAX_MINIONS:
		var minion := Bestiary.make(MINION)
		minion.position = Hazards.clamp_to_arena(position + Vector2(randf_range(-80, 80), 70))
		get_parent().add_child(minion)
		return
	var target := player.global_position
	if alt:
		for i in 7:
			var pos := Hazards.clamp_to_arena(Vector2(90 + i * 120, target.y))
			Hazards.zone(pos, 60.0, "damage", 0.8 + i * 0.12, 1.5, ZONE_COLOR)
	else:
		for i in 4 if nightmare else 3:
			var pos := Hazards.clamp_to_arena(target + Vector2.from_angle(randf() * TAU) * randf_range(0, 90))
			Hazards.zone(pos, 60.0, "damage", 1.0, 2.5, ZONE_COLOR)

func _minion_count() -> int:
	return get_tree().get_nodes_in_group("mobs").filter(func(m): return m.display_name == "Bailleur" and m.state != State.DEAD).size()
