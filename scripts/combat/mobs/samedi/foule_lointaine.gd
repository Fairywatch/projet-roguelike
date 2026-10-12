extends BaseMob

# La Foule Lointaine (boss du samedi) : une foule de silhouettes qui s'ecarte quand on approche.
# Le vrai boss se cache parmi elles : c'est la seule qui tire, et la seule qu'on peut blesser.
# Toutes les trois attaques, la foule se melange. Variante : la foule tire aussi (faux souvenirs
# inoffensifs). Cauchemar : foule plus nombreuse.

const SCATTER_RANGE := 130.0
const SCATTER_SPEED := 90.0
const MEMORY := Color(0.8, 0.82, 1.0, 0.9)
const MEMORY_FAKE := Color(0.8, 0.82, 1.0, 0.55)

var crowd: Array = []
var cycle := 0

func _texture_path() -> String:
	return "res://assets/sprites/mobs/samedi/silhouette.png"  # meme apparence que la foule

func _on_ready() -> void:
	display_name = "La Foule Lointaine"
	is_boss = true
	hp = 20
	chase_speed = 0.0
	attack_range = 2000.0
	telegraph_duration = 0.6
	attack_duration = 0.2
	cooldown_duration = 1.4
	for i in 10 if nightmare else 7:
		var someone := Sprite2D.new()
		someone.texture = sprite.texture
		someone.hframes = ANIM_FRAMES
		someone.scale = sprite.scale
		crowd.append(someone)
		get_parent().add_child.call_deferred(someone)
	_mingle.call_deferred()

# Ni ombre ni barre de vie : rien ne doit le distinguer de la foule (ses PV restent affiches en haut).
func _draw() -> void:
	pass

func _mingle() -> void:
	var everyone: Array = [self] + crowd.filter(func(c): return is_instance_valid(c))
	everyone.shuffle()
	for i in everyone.size():
		everyone[i].global_position = Vector2(140 + (i % 4) * 200, 130 + (i / 4) * 140) + Vector2(randf_range(-30, 30), randf_range(-20, 20))

func _process(delta: float) -> void:
	super(delta)
	var p := Hazards.player()
	if p == null or state == State.DEAD:
		return
	for someone in [self] + crowd:  # tout le monde s'ecarte du joueur, le vrai compris
		if is_instance_valid(someone) and someone.global_position.distance_to(p.global_position) < SCATTER_RANGE:
			someone.global_position = Hazards.clamp_to_arena(someone.global_position + (someone.global_position - p.global_position).normalized() * SCATTER_SPEED * delta)

func _on_attack_begin() -> void:
	cycle += 1
	Hazards.fan(self, player.global_position - global_position, 3, 24.0, 140.0, MEMORY)
	if alt:
		for someone in crowd:
			if is_instance_valid(someone) and randf() < 0.4:
				var fake := Hazards.shoot(self, player.global_position - someone.global_position, 140.0, MEMORY_FAKE)
				fake.global_position = someone.global_position
				fake.harmless = true
	if cycle % 3 == 0:
		_mingle()

func _on_death() -> void:
	for someone in crowd:
		if is_instance_valid(someone):
			var fade: Tween = someone.create_tween()
			fade.tween_property(someone, "modulate:a", 0.0, 0.6)
			fade.tween_callback(someone.queue_free)
