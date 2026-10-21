extends Node

# Lundi (Fatigue) - Paupieres lourdes : pendant l'exploration, l'ecran se ferme de temps en temps
# comme des paupieres, puis se rouvre. Rare et court au premier etage, frequent et plus long au
# dernier (docs/nuits.md). L'interface (coeurs, objets) reste visible.

const INTRO := "Tes paupières s'alourdissent..."
const PERIOD := Vector2(30.0, 10.0)  # secondes entre deux clignements : premier etage, dernier
const CLOSED := Vector2(0.3, 0.8)  # duree des yeux fermes
const CLOSE_TIME := 0.15
const OPEN_TIME := 0.3
const LID_COLOR := Color(0.03, 0.02, 0.06)

var strength := 0.0  # 0 au premier etage, 1 au dernier
var map: Node
var upper := ColorRect.new()
var lower := ColorRect.new()
var timer := 0.0

func _ready() -> void:
	var ui: CanvasLayer = map.get_node("UI")
	for lid in [upper, lower]:
		lid.color = LID_COLOR
		lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(lid)
		ui.move_child(lid, 0)  # sous l'interface
	_open_now()
	timer = _interval() * 0.5

func _interval() -> float:
	return lerpf(PERIOD.x, PERIOD.y, strength) * randf_range(0.8, 1.2)

func _size() -> Vector2:
	return map.get_viewport().get_visible_rect().size

func _open_now() -> void:
	var size := _size()
	upper.size = Vector2(size.x, size.y / 2.0)
	lower.size = upper.size
	upper.position.y = -upper.size.y
	lower.position.y = size.y

func _process(delta: float) -> void:
	if map.player.frozen:
		return
	timer -= delta
	if timer <= 0.0:
		timer = _interval()
		blink()

func blink() -> void:
	var half := _size().y / 2.0
	var tween := create_tween()
	tween.tween_property(upper, "position:y", 0.0, CLOSE_TIME).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(lower, "position:y", half, CLOSE_TIME).set_ease(Tween.EASE_IN)
	tween.tween_interval(lerpf(CLOSED.x, CLOSED.y, strength))
	tween.tween_property(upper, "position:y", -half, OPEN_TIME).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lower, "position:y", half * 2.0, OPEN_TIME).set_ease(Tween.EASE_OUT)
