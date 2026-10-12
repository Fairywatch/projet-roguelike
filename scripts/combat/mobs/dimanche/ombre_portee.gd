extends BaseMob

# Ombre portee (dimanche, Angoisse) : l'ombre du joueur, detachee de lui. Elle suit le chemin du
# joueur avec du retard et frappe la ou il se trouvait : il faut bouger sans arret.
# Variante : trois ombres decalees dans le temps (1, 2 et 3 secondes). Cauchemar : frappe plus large.

const STRIKE_EVERY := 0.6
const SHADOW := Color(0.25, 0.15, 0.35)

var delay := 1.0
var history: Array = []  # [temps, position] du joueur
var strike_timer := STRIKE_EVERY

func _texture_path() -> String:
	return "res://assets/sprites/mobs/dimanche/ombre_portee.png"

func _on_ready() -> void:
	display_name = "Ombre portee"
	hp = 3
	attack_range = 0.0
	if alt and delay == 1.0:
		for later in [2.0, 3.0]:
			spawn_ally("dimanche/ombre_portee", position, {"delay": later, "nightmare": nightmare})

func _physics_process(delta: float) -> void:
	if state != State.CHASE:
		return
	var p := Hazards.player()
	if p == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	history.append([now, p.global_position])
	while history.size() > 1 and now - history[1][0] >= delay:
		history.pop_front()
	var past: Vector2 = history[0][1]
	global_position = global_position.move_toward(past, 400.0 * delta)
	strike_timer -= delta
	if strike_timer <= 0.0 and now - history[0][0] >= delay - 0.05:
		strike_timer = STRIKE_EVERY
		Hazards.zone(past, 44.0 if nightmare else 34.0, "damage", 0.35, 0.15, SHADOW)
