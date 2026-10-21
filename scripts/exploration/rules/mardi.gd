extends Node

# Mardi (Stress) - Tic-tac : plus on reste sur un etage, plus les rencontres deviennent frequentes.
# La pression repart a zero a chaque arrivee sur la carte (nouvel etage, retour de combat) et quand
# on retourne le sablier. Elle monte lentement au premier etage, vite au dernier (docs/nuits.md).
# Une petite horloge dans l'interface montre ou on en est.

const INTRO := "Tic-tac... Le temps presse : ne traîne pas."
const FILL_TIME := Vector2(90.0, 30.0)  # secondes pour atteindre la pression maximale : premier etage, dernier
const MAX_BOOST := 2.5  # rencontres jusqu'a 3,5 fois plus frequentes

var strength := 0.0
var map: Node
var floor_data
var pressure := 0.0
var base_chance := 0.0
var clock := PressureClock.new()

func _ready() -> void:
	base_chance = map.encounter_chance
	clock.rule = self
	clock.position = Vector2(20, 76)
	map.get_node("UI").add_child(clock)

func _process(delta: float) -> void:
	if map.player.frozen:
		return
	pressure = minf(1.0, pressure + delta / lerpf(FILL_TIME.x, FILL_TIME.y, strength))
	map.encounter_chance = base_chance * (1.0 + MAX_BOOST * pressure)
	clock.queue_redraw()

func on_decor(decor_name: String) -> void:
	if decor_name == "horloge":  # le sablier retourne : on souffle
		pressure = 0.0

# Cadran qui se remplit de rouge avec la pression.
class PressureClock extends Control:
	const RADIUS := 9.0
	var rule: Node

	func _draw() -> void:
		draw_circle(Vector2.ZERO, RADIUS + 1.5, Color(0.1, 0.06, 0.08))
		draw_circle(Vector2.ZERO, RADIUS, Color(0.95, 0.92, 0.85))
		var p: float = rule.pressure
		if p > 0.0:
			var points := PackedVector2Array([Vector2.ZERO])
			for i in 25:
				var a := -PI / 2 + TAU * p * i / 24.0
				points.append(Vector2(cos(a), sin(a)) * RADIUS)
			draw_colored_polygon(points, Color(0.9, 0.25, 0.25, 0.85))
		var hand := -PI / 2 + TAU * p
		draw_line(Vector2.ZERO, Vector2(cos(hand), sin(hand)) * (RADIUS - 2), Color(0.15, 0.1, 0.1), 1.5)
