extends BaseMob

# Echo (samedi, Solitude) : une forme floue qui repete la derniere attaque du joueur une seconde
# plus tard, la ou il a frappe (zone annoncee). Rester a l'endroit de son propre coup est donc
# dangereux. Variante : double echo, encore decale. Cauchemar : echo plus large.

const DELAY := 1.0
const COLOR := Color(0.65, 0.7, 1.0)

func _texture_path() -> String:
	return "res://assets/sprites/mobs/samedi/echo.png"

func _on_ready() -> void:
	display_name = "Écho"
	hp = 3
	chase_speed = 40.0
	attack_range = 0.0  # n'attaque qu'en repetant le joueur
	var p := Hazards.player()
	if p:
		p.attacked.connect(_repeat)

func _repeat(at: Vector2) -> void:
	if state == State.DEAD or not is_inside_tree():
		return
	var radius := 52.0 if nightmare else 40.0
	Hazards.zone(at, radius, "damage", DELAY, 0.2, COLOR)
	if alt:
		Hazards.zone(at, radius, "damage", DELAY * 2.0, 0.2, COLOR)
