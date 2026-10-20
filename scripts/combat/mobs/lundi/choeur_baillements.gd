extends BaseMob

# Le Choeur des Baillements (boss du lundi) : trois tetes qui aspirent le joueur chacune a son
# tour ; la tete active s'illumine pendant le telegraphe, et sa bouche mord pendant l'aspiration.
# Variante : deux tetes aspirent en meme temps. Cauchemar : aspiration plus forte.

# Position des bouches par rapport au centre (le sprite fait 3 tetes cote a cote, affiche x2).
const MOUTHS := [Vector2(-28, 12), Vector2(0, 0), Vector2(28, 12)]
const PULL_RANGE := 300.0
const PULL_SPEED := 130.0
const BITE_RANGE := 30.0

var active: Array = []

func _texture_path() -> String:
	return "res://assets/sprites/mobs/lundi/choeur_baillements.png"

func _on_ready() -> void:
	display_name = "Le Chœur des Bâillements"
	is_boss = true
	hp = 18
	chase_speed = 0.0
	attack_range = 2000.0
	telegraph_duration = 0.7
	attack_duration = 1.4
	cooldown_duration = 0.9

func _on_telegraph_begin() -> void:
	var heads := [0, 1, 2]
	heads.shuffle()
	active = heads.slice(0, 2 if alt else 1)

func _physics_process(delta: float) -> void:
	super(delta)
	var p := Hazards.player()
	if state != State.ATTACK or p == null:
		return
	for head in active:
		var to_mouth: Vector2 = global_position + MOUTHS[head] - p.global_position
		if to_mouth.length() < PULL_RANGE:
			p.add_external_velocity(to_mouth.normalized() * PULL_SPEED * (1.35 if nightmare else 1.0))
		if to_mouth.length() < BITE_RANGE:
			p.take_damage()

func _draw() -> void:
	super()
	if state == State.TELEGRAPH or state == State.ATTACK:
		for head in active:
			draw_circle(MOUTHS[head], 22.0, Color(1, 0.85, 0.3, 0.25 if state == State.TELEGRAPH else 0.45))
