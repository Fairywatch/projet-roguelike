extends BaseMob

# Cocotte-minute (jeudi, Frustration) : la pression monte ; arrivee au maximum, elle explose en
# grande zone (annoncee). Chaque coup recu fait baisser la pression mais libere un jet de vapeur.
# Variante : deux cocottes reliees qui partagent leur pression. Cauchemar : monte plus vite.

const FILL_TIME := 6.0
const RELIEF := 0.25
const BLAST_RADIUS := 120.0
const STEAM := Color(0.85, 0.9, 1.0)
const BLAST := Color(1, 0.45, 0.3)

var pressure := 0.0
var leader: BaseMob  # cocotte reliee : partage la pression de son chef
var exploding := false

func _texture_path() -> String:
	return "res://assets/sprites/mobs/jeudi/cocotte.png"

func _on_ready() -> void:
	display_name = "Cocotte-minute"
	hp = 5
	chase_speed = 30.0
	attack_range = 0.0  # n'attaque pas : elle monte en pression
	if alt and leader == null:
		var twin := spawn_ally("jeudi/cocotte", position + Vector2(120, 0), {"nightmare": nightmare})
		twin.leader = self

func _owner_pressure() -> BaseMob:
	return leader if is_instance_valid(leader) and leader.state != State.DEAD else self

func _process(delta: float) -> void:
	super(delta)
	if state == State.DEAD:
		return
	var holder := _owner_pressure()
	if holder == self:
		pressure += delta / (FILL_TIME * (0.75 if nightmare else 1.0))
	sprite.offset.x = randf_range(-1.0, 1.0) * holder.pressure * 1.5  # tremble de plus en plus
	if holder.pressure >= 1.0 and not holder.exploding:
		holder.exploding = true
		_explode(holder)

func _explode(holder: BaseMob) -> void:
	Hazards.zone(global_position, BLAST_RADIUS, "damage", 0.8, 0.2, BLAST)
	if await pause(0.8):
		holder.pressure = 0.0
		holder.exploding = false

func take_hit(damage: int = 1) -> void:
	super(damage)
	if state == State.DEAD:
		return
	var holder := _owner_pressure()
	holder.pressure = maxf(0.0, holder.pressure - RELIEF)
	Hazards.beam(global_position, Vector2.from_angle(randf() * TAU), 18.0, 0.3, 0.25, STEAM)
