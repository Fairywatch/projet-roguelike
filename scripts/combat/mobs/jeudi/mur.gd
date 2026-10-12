extends BaseMob

# Le Mur (boss du jeudi) : un pan de briques qui avance lentement d'un bord a l'autre de l'arene ;
# le toucher blesse. S'il atteint l'autre bord, il ecrase tout sur sa route (grande zone annoncee)
# et repart du debut. Il lance des briques. Variante : avance de haut en bas. Cauchemar : plus vite.

const ADVANCE := 26.0
const BRICK := Color(0.8, 0.45, 0.35)
const HIT_RANGE := 44.0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/jeudi/mur.png"

func _on_ready() -> void:
	display_name = "Le Mur"
	is_boss = true
	hp = 24
	chase_speed = 0.0
	attack_range = 2000.0
	telegraph_duration = 0.5
	attack_duration = 0.2
	cooldown_duration = 1.6
	set_display_scale(2.4)
	_restart.call_deferred()

func _restart() -> void:
	global_position = Vector2(450, 70) if alt else Vector2(70, 270)

func _physics_process(delta: float) -> void:
	super(delta)
	if state == State.DEAD:
		return
	var step := ADVANCE * delta * (1.4 if nightmare else 1.0)
	global_position += Vector2(0, step) if alt else Vector2(step, 0)
	var p := Hazards.player()
	if p and p.global_position.distance_to(global_position) < HIT_RANGE:
		p.take_damage()
	var reached := global_position.y > 470.0 if alt else global_position.x > 830.0
	if reached:
		# Arrive au bout : il ecrase tout sur la ligne qu'il vient de parcourir, puis repart.
		for i in 8:  # la ligne parcourue : la rangee (horizontal) ou la colonne (vertical)
			var spot := Vector2(450, 70 + i * 60) if alt else Vector2(70 + i * 110, 270)
			Hazards.zone(spot, 70.0, "damage", 0.8, 0.2, BRICK)
		_restart()

func _on_attack_begin() -> void:
	Hazards.fan(self, player.global_position - global_position, 3, 30.0, 160.0, BRICK)
