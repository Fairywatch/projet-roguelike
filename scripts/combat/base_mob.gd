extends CharacterBody2D
class_name BaseMob

signal died
signal hp_changed(hp: int)

const HP_BAR_WIDTH := 30.0
const STUN_COLOR := Color(0.55, 0.6, 1.0, 1)
const ANIM_FRAMES := 2
const ANIM_FPS := 3.0
const HurtboxScript := preload("res://scripts/combat/hurtbox.gd")
# Variantes (docs/bestiaire.md) : cauchemar sur les etages cauchemar, elite rare.
const NIGHTMARE_HP := 1.3
const NIGHTMARE_TINT := Color(0.62, 0.5, 0.74)
const ELITE_HP := 1.6
const ELITE_SCALE := 1.35

var chase_speed := 70.0
var attack_range := 55.0
var telegraph_duration := 0.6
var attack_duration := 0.2
var cooldown_duration := 0.8

enum State { CHASE, TELEGRAPH, ATTACK, COOLDOWN, DEAD }

@onready var sprite: Sprite2D = $Sprite

var state := State.CHASE
var hp := 3
var max_hp := 3
var base_color: Color
var player: Node2D
var action_id := 0
var bob_time := randf() * TAU

# Bestiaire par nuit (scripts/combat/mobs/<nuit>/) : nom affiche, boss, variantes.
var display_name := ""
var is_boss := false
var nightmare := false  # variante cauchemar : plus de PV, un coup de plus dans son pattern
var elite := false      # variante elite : plus grosse, aura, plus de PV, meilleur butin
var alt := false        # variante de comportement : autre attaque (voir chaque creature)
var invulnerable := false
var auto_frames := true  # false : le script choisit lui-meme l'image (ex. paupiere ouverte/fermee)

# Les creatures du bestiaire n'ont pas de scene : on construit sprite, collision et hurtbox ici.
func _enter_tree() -> void:
	if has_node("Sprite"):
		return
	var texture: Texture2D = load(_texture_path())
	var sprite_node := Sprite2D.new()
	sprite_node.name = "Sprite"
	sprite_node.texture = texture
	sprite_node.scale = Vector2(2, 2)
	add_child(sprite_node)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(texture.get_width() / ANIM_FRAMES, texture.get_height()) * 2.0 * 0.8
	var body := CollisionShape2D.new()
	body.name = "CollisionShape2D"
	body.shape = shape
	add_child(body)
	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.monitoring = false
	hurtbox.set_script(HurtboxScript)
	var hurt_shape := CollisionShape2D.new()
	hurt_shape.name = "CollisionShape2D"
	hurt_shape.shape = shape
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)

func _texture_path() -> String:
	return ""

# Fait apparaitre un allie du bestiaire (ex. "mardi/trotteuse") ; ajout differe, sans danger
# pendant un _ready ou un signal.
func spawn_ally(path: String, pos: Vector2, props: Dictionary = {}) -> BaseMob:
	var ally: BaseMob = load("res://scripts/combat/mobs/" + path + ".gd").new()
	for key in props:
		ally.set(key, props[key])
	ally.position = pos.clamp(Vector2(60, 60), Vector2(840, 480))
	get_parent().add_child.call_deferred(ally)
	return ally

# Affiche le sprite a une autre echelle (gros boss) en gardant les collisions a la bonne taille.
func set_display_scale(factor: float) -> void:
	sprite.scale = Vector2.ONE * factor
	var shape := RectangleShape2D.new()
	shape.size = Vector2(sprite.texture.get_width() / ANIM_FRAMES, sprite.texture.get_height()) * factor * 0.8
	$CollisionShape2D.shape = shape
	$Hurtbox/CollisionShape2D.shape = shape

# Nombre d'ennemis vivants portant ce nom (pour limiter les invocations).
func alive_count(mob_name: String) -> int:
	return get_tree().get_nodes_in_group("mobs").filter(func(m): return m.display_name == mob_name and m.state != State.DEAD).size()

func _ready() -> void:
	add_to_group("mobs")
	base_color = sprite.modulate
	sprite.hframes = ANIM_FRAMES
	sprite.material = Fx.make_flash_material()
	player = get_tree().get_first_node_in_group("player")
	_on_ready()
	max_hp = hp

func _on_ready() -> void:
	pass

func empower_as_guardian() -> void:
	hp = 9
	max_hp = hp
	chase_speed *= 1.6
	attack_range *= 1.25
	telegraph_duration *= 0.7
	attack_duration *= 1.2
	cooldown_duration *= 0.65
	# Aura violette plutot qu'une teinte : le sprite reste lisible.
	add_child(DreamTheme.make_light(Color(0.75, 0.35, 1), 90.0, 1.5))
	sprite.scale = sprite.scale * 1.5
	var bigger_shape := RectangleShape2D.new()
	bigger_shape.size = Vector2(56, 56)
	$CollisionShape2D.shape = bigger_shape
	$Hurtbox/CollisionShape2D.shape = bigger_shape

# A appeler une fois dans l'arene, apres apply_difficulty.
func apply_variant() -> void:
	if nightmare:
		hp = ceili(hp * NIGHTMARE_HP)
		base_color = NIGHTMARE_TINT
		sprite.modulate = base_color
	if elite:
		hp = ceili(hp * ELITE_HP)
		sprite.scale *= ELITE_SCALE
		add_child(DreamTheme.make_light(Color(1, 0.85, 0.4), 70.0, 1.2))
	max_hp = hp

# Les telegraphes ne sont pas touches : la lisibilite reste la meme a tous les paliers.
func apply_difficulty(mult: float) -> void:
	hp = ceili(hp * mult)
	max_hp = hp
	var tempo := sqrt(mult)
	chase_speed *= tempo
	cooldown_duration /= tempo

func _sprite_half_height() -> float:
	return sprite.texture.get_height() * sprite.scale.y / 2.0

func _process(delta: float) -> void:
	bob_time += delta
	sprite.position.y = round(sin(bob_time * 5.0) * 1.5)
	if auto_frames:
		sprite.frame = int(bob_time * ANIM_FPS) % ANIM_FRAMES
	queue_redraw()

func _draw() -> void:
	var half := _sprite_half_height()
	Fx.draw_shadow(self, half, sprite.texture.get_width() / ANIM_FRAMES * sprite.scale.x * 0.8)
	if hp < max_hp and state != State.DEAD:
		var ratio := clampf(float(hp) / max_hp, 0.0, 1.0)
		var top := -half - 10.0
		draw_rect(Rect2(-HP_BAR_WIDTH / 2 - 1, top - 1, HP_BAR_WIDTH + 2, 5), Color(0.05, 0.03, 0.08))
		draw_rect(Rect2(-HP_BAR_WIDTH / 2, top, HP_BAR_WIDTH * ratio, 3), Color(0.95, 0.3, 0.35))

func _physics_process(_delta: float) -> void:
	if state == State.DEAD or player == null:
		return
	if state == State.CHASE:
		var to_player := player.global_position - global_position
		if to_player.length() <= attack_range:
			velocity = Vector2.ZERO
			_start_telegraph()
		else:
			velocity = _chase_velocity(to_player)
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func _chase_velocity(to_player: Vector2) -> Vector2:
	return to_player.normalized() * chase_speed

# Attend ; renvoie false si le mob est mort ou n'est plus dans l'arene entre-temps (fin du
# combat, changement de scene). A utiliser pour toute attente dans un pattern.
func pause(seconds: float) -> bool:
	if not is_inside_tree():
		return false
	await get_tree().create_timer(seconds).timeout
	return is_inside_tree() and state != State.DEAD

# Attend puis renvoie false si l'action a ete interrompue entre-temps (mort, etourdissement).
func _wait(duration: float) -> bool:
	action_id += 1
	var id := action_id
	return await pause(duration) and id == action_id

func _start_telegraph() -> void:
	state = State.TELEGRAPH
	sprite.modulate = Color(1, 0.85, 0.2, 1)
	_on_telegraph_begin()
	if await _wait(telegraph_duration):
		_start_attack()

func _on_telegraph_begin() -> void:
	pass

func _start_attack() -> void:
	state = State.ATTACK
	sprite.modulate = Color(0.9, 0.1, 0.1, 1)
	_on_attack_begin()
	if not await _wait(attack_duration):
		return
	_on_attack_end()
	_start_cooldown()

func _on_attack_begin() -> void:
	pass

func _on_attack_end() -> void:
	pass

func _start_cooldown() -> void:
	state = State.COOLDOWN
	sprite.modulate = base_color
	if await _wait(cooldown_duration):
		state = State.CHASE

func take_hit(damage: int = 1) -> void:
	if state == State.DEAD:
		return
	if invulnerable:
		Fx.flash(sprite, Color(0.6, 0.7, 1.0), 0.08)
		return
	hp -= damage
	hp_changed.emit(hp)
	if hp <= 0:
		_die()
		return
	Fx.flash(sprite)

func _die() -> void:
	Sound.play("mob_die")
	if state == State.ATTACK:
		_on_attack_end()
	state = State.DEAD
	_on_death()
	Fx.puff(get_parent(), global_position, base_color.lerp(Color.WHITE, 0.3), 20)
	died.emit()
	queue_free()

func _on_death() -> void:
	pass

func apply_slow(duration: float, factor: float) -> void:
	if state == State.DEAD:
		return
	chase_speed *= factor
	if await pause(duration):
		chase_speed /= factor

func stun(duration: float) -> void:
	if state == State.DEAD:
		return
	if state == State.ATTACK:
		_on_attack_end()
	state = State.COOLDOWN
	sprite.modulate = STUN_COLOR
	if await _wait(duration):
		sprite.modulate = base_color
		state = State.CHASE
