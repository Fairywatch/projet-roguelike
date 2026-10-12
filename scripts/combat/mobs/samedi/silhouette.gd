extends BaseMob

# Silhouette (samedi, Solitude) : l'ombre de quelqu'un qu'on a connu. Elle fuit quand on
# s'approche et lance des souvenirs de loin. Variante : disparait puis reapparait derriere le
# joueur avant de tirer. Cauchemar : plus de souvenirs.

const KEEP_AWAY := 200.0
const FLEE_SPEED := 85.0
const MEMORY := Color(0.8, 0.82, 1.0, 0.9)

func _texture_path() -> String:
	return "res://assets/sprites/mobs/samedi/silhouette.png"

func _on_ready() -> void:
	display_name = "Silhouette"
	hp = 3
	attack_range = 330.0
	telegraph_duration = 0.7
	attack_duration = 0.2
	cooldown_duration = 1.6

func _physics_process(delta: float) -> void:
	if state == State.CHASE and player and global_position.distance_to(player.global_position) < KEEP_AWAY:
		velocity = (global_position - player.global_position).normalized() * FLEE_SPEED
		move_and_slide()
		global_position = Hazards.clamp_to_arena(global_position)
		return
	super(delta)

func _on_telegraph_begin() -> void:
	if not alt:
		return
	# Disparait, puis reapparait dans le dos du joueur.
	var fade := create_tween()
	fade.tween_property(sprite, "self_modulate:a", 0.0, 0.25)
	fade.tween_callback(func():
		var p := Hazards.player()
		if p and state != State.DEAD:
			global_position = Hazards.clamp_to_arena(p.global_position - p.facing * 120.0))
	fade.tween_property(sprite, "self_modulate:a", 1.0, 0.25)

func _on_attack_begin() -> void:
	Hazards.fan(self, player.global_position - global_position, 3 if nightmare else 2, 20.0, 120.0, MEMORY)
