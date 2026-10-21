extends Node

# Vendredi (Epuisement) - Fardeau : le reveur ralentit peu a peu pendant l'exploration d'un etage.
# Le the (soin) et le banc (pause) le remettent d'aplomb. En combat, le dash se recharge plus
# lentement. Premier etage : a peine sensible ; dernier : jusqu'a -30 % et un dash 25 % plus lent.

const INTRO := "Tout pèse... Un thé ou un banc te soulagera."
const LOAD_TIME := 60.0  # secondes pour porter tout le poids
const SLOW := Vector2(0.08, 0.3)  # ralentissement maximal : premier etage, dernier
const DASH_SLOW := Vector2(0.0, 0.25)

var strength := 0.0
var map: Node
var floor_data
var load_ratio := 0.0

static func apply_combat(arena: Node, force: float) -> void:
	arena.player.dash_cooldown_effective *= 1.0 + lerpf(DASH_SLOW.x, DASH_SLOW.y, force)

func _process(delta: float) -> void:
	if map.player.frozen:
		return
	load_ratio = minf(1.0, load_ratio + delta / LOAD_TIME)
	map.player.speed_factor = 1.0 - lerpf(SLOW.x, SLOW.y, strength) * load_ratio

func on_decor(decor_name: String) -> void:
	if decor_name in ["etoile", "horloge"]:  # le the chaud, le banc
		load_ratio = 0.0
