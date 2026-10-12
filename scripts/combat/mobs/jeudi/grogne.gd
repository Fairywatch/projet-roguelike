extends BaseMob

# Grogne (jeudi, Frustration) : une boule de poils qui s'enerve a chaque coup recu (grossit,
# accelere). Trop enervee, elle s'allume et explose si on ne l'acheve pas a temps.
# Variante : une chaine de 3 Grognes. Cauchemar : s'enerve plus vite.

const RAGE_LIMIT := 3
const FUSE_TIME := 2.4
const BLAST_RADIUS := 90.0
const BLAST := Color(1, 0.35, 0.25)

var rage := 0
var fuse := -1.0
var blast_zone: Node2D
var link := false

func _texture_path() -> String:
	return "res://assets/sprites/mobs/jeudi/grogne.png"

func _on_ready() -> void:
	display_name = "Grogne"
	hp = 5
	chase_speed = 65.0
	attack_range = 50.0
	telegraph_duration = 0.45
	attack_duration = 0.2
	cooldown_duration = 0.8
	if alt and not link:
		for side in [-1, 1]:
			spawn_ally("jeudi/grogne", position + Vector2(side * 45, 30), {"link": true, "nightmare": nightmare})

func take_hit(damage: int = 1) -> void:
	super(damage)
	if state == State.DEAD:
		return
	rage += 2 if nightmare else 1
	sprite.scale *= 1.12
	chase_speed *= 1.25
	if rage >= RAGE_LIMIT and fuse < 0.0:
		fuse = FUSE_TIME
		blast_zone = Hazards.zone(global_position, BLAST_RADIUS, "damage", FUSE_TIME, 0.2, BLAST)

func _process(delta: float) -> void:
	super(delta)
	if fuse < 0.0 or state == State.DEAD:
		return
	fuse -= delta
	sprite.self_modulate = Color(1, 0.4, 0.3) if int(fuse * 10.0) % 2 == 0 else Color.WHITE
	if fuse <= 0.0:
		_die()  # la zone d'explosion annoncee au sol frappe a cet instant

func _physics_process(delta: float) -> void:
	super(delta)
	if is_instance_valid(blast_zone):  # la zone d'explosion suit la Grogne pendant la meche
		blast_zone.global_position = global_position

# Achevee avant la fin de la meche : pas d'explosion. Sinon la zone frappe a la fin de la meche.
func _on_death() -> void:
	if is_instance_valid(blast_zone) and fuse > 0.0:
		blast_zone.queue_free()

func _on_attack_begin() -> void:
	Hazards.zone(global_position + (player.global_position - global_position).normalized() * 30.0, 36.0, "damage", 0.05, 0.15, BLAST)
