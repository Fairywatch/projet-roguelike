extends BaseMob

# Bougie fondue (vendredi, Epuisement) : laisse des flaques de cire qui ralentissent, et
# rapetisse en perdant de la vie ; elle crache de petites flammes.
# Variante : rallume une fois chaque ennemi vaincu pres d'elle. Cauchemar : flaques plus grandes.

const WAX_EVERY := 0.6
const WAX := Color(0.95, 0.9, 0.75)
const FLAME := Color(1, 0.6, 0.25)
const REKINDLE_RANGE := 300.0

var wax_timer := WAX_EVERY
var watched := {}

func _texture_path() -> String:
	return "res://assets/sprites/mobs/vendredi/bougie_fondue.png"

func _on_ready() -> void:
	display_name = "Bougie fondue"
	hp = 4
	chase_speed = 32.0
	attack_range = 230.0
	telegraph_duration = 0.6
	attack_duration = 0.2
	cooldown_duration = 1.6

func _process(delta: float) -> void:
	super(delta)
	if state == State.DEAD:
		return
	sprite.scale.y = sprite.scale.x * lerpf(0.6, 1.0, float(hp) / max_hp)  # elle fond
	wax_timer -= delta
	if wax_timer <= 0.0:
		wax_timer = WAX_EVERY
		Hazards.zone(global_position + Vector2(0, 14), 36.0 if nightmare else 26.0, "slow", 0.1, 4.0, WAX)
	if alt:  # surveille les autres ennemis pour les rallumer a leur mort
		for m in get_tree().get_nodes_in_group("mobs"):
			if m != self and not watched.has(m) and not m.has_meta("rekindled"):
				watched[m] = true
				m.died.connect(_rekindle.bind(m))

func _rekindle(fallen: Node2D) -> void:
	if state == State.DEAD or fallen.has_meta("rekindle_done") or fallen.global_position.distance_to(global_position) > REKINDLE_RANGE:
		return
	fallen.set_meta("rekindle_done", true)  # une seule bougie le rallume, une seule fois
	var again: BaseMob = fallen.get_script().new()
	again.set_meta("rekindled", true)
	again.position = fallen.position
	get_parent().add_child.call_deferred(again)
	Fx.puff(get_parent(), fallen.global_position, FLAME, 16)

func _on_attack_begin() -> void:
	Hazards.fan(self, player.global_position - global_position, 2, 20.0, 150.0, FLAME)
