extends BaseMob

# Les Deux Voies (boss du mercredi) : deux silhouettes jumelles. Une seule est la "bonne voie" :
# la frapper la blesse ; frapper l'autre SOIGNE la bonne. Indice : la bonne voie porte une petite
# lueur. Les roles s'echangent regulierement ; une fois l'une tombee, l'autre est la bonne.
# Variante : les roles s'echangent deux fois plus vite. Cauchemar : soins plus forts.

const SWAP_EVERY := 6.0
const HEAL := 2
const SHOT := Color(0.85, 0.7, 1, 0.95)

var partner: BaseMob
var is_true := true
var twin := false
var swap_timer := SWAP_EVERY
var glow: PointLight2D

func _texture_path() -> String:
	return "res://assets/sprites/mobs/mercredi/deux_voies.png"

func _on_ready() -> void:
	display_name = "Les Deux Voies"
	is_boss = true
	hp = 12
	chase_speed = 30.0
	attack_range = 2000.0
	telegraph_duration = 0.6
	attack_duration = 0.2
	cooldown_duration = 1.6
	if twin and partner:  # meme resistance que la voie principale (difficulte et variantes comprises)
		hp = partner.max_hp
	glow = DreamTheme.make_light(Color(1, 0.95, 0.7), 40.0, 1.0)
	add_child(glow)
	if not twin:
		partner = spawn_ally("mercredi/deux_voies", position + Vector2(220, 0), {"twin": true, "is_true": false, "nightmare": nightmare, "alt": alt})
		partner.partner = self
	glow.visible = is_true

func _partner_alive() -> bool:
	return is_instance_valid(partner) and partner.state != State.DEAD

func _process(delta: float) -> void:
	super(delta)
	if twin or state == State.DEAD or not _partner_alive():
		return
	swap_timer -= delta * (2.0 if alt else 1.0)
	if swap_timer <= 0.0:
		swap_timer = SWAP_EVERY
		_set_true(not is_true)
		partner._set_true(not is_true)

func _set_true(value: bool) -> void:
	is_true = value
	glow.visible = value

func take_hit(damage: int = 1) -> void:
	if state == State.DEAD:
		return
	if not is_true and _partner_alive():
		# Mauvaise voie : le coup soigne l'autre.
		partner.hp = mini(partner.max_hp, partner.hp + HEAL * (2 if nightmare else 1))
		Fx.flash(partner.sprite, Color(0.5, 1, 0.6), 0.2)
		Fx.flash(sprite, Color(0.6, 0.6, 0.7), 0.1)
		return
	super(damage)

func _on_death() -> void:
	if _partner_alive():
		partner._set_true(true)

func _on_attack_begin() -> void:
	Hazards.fan(self, player.global_position - global_position, 3, 30.0, 150.0, SHOT)
