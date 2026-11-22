class_name GuardSheep
extends Area2D

# Mouton gardien (objet Moutons gardiens) : tourne autour du joueur. Il mord les ennemis qu'il
# touche (BITE_DAMAGE, au plus une fois par BITE_COOLDOWN pour chacun) et arrete un tir ennemi ;
# il reste alors etourdi DIZZY_TIME secondes (translucide, sans effet). Les moutons se repartissent
# le cercle (index / count).

const ORBIT_RADIUS := 50.0
const ORBIT_SPEED := 2.6  # radians par seconde
const BITE_DAMAGE := 1
const BITE_COOLDOWN := 0.8
const DIZZY_TIME := 3.5
const SheepTexture := preload("res://assets/sprites/mobs/lundi/mouton.png")

var index := 0
var count := 1
var angle := 0.0
var dizzy := 0.0
var bitten := {}  # instance_id -> temps restant avant de pouvoir remordre
var sprite := Sprite2D.new()

func _ready() -> void:
	add_to_group("guard_sheep")
	monitorable = false
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 11.0
	add_child(shape)
	sprite.texture = SheepTexture
	sprite.hframes = MobFrames.count(SheepTexture.resource_path)
	sprite.scale = Vector2(1.1, 1.1)
	sprite.modulate = Color(1, 0.98, 0.9)
	add_child(sprite)
	z_index = 1

func _physics_process(delta: float) -> void:
	angle += ORBIT_SPEED * delta
	position = Vector2.from_angle(angle + TAU * index / maxf(count, 1)) * ORBIT_RADIUS
	sprite.flip_h = cos(angle + TAU * index / maxf(count, 1)) > 0.0
	for id in bitten.keys():
		bitten[id] -= delta
		if bitten[id] <= 0.0:
			bitten.erase(id)
	if dizzy > 0.0:
		dizzy -= delta
		sprite.modulate.a = 0.35
		sprite.rotation += 8.0 * delta
		if dizzy <= 0.0:
			sprite.rotation = 0.0
			sprite.modulate.a = 1.0
		return
	for area in get_overlapping_areas():
		if _is_enemy_shot(area):
			Fx.puff(get_parent().get_parent(), area.global_position, Color(1, 1, 0.9), 8)
			area.queue_free()
			Sound.play("shield", -4.0)
			dizzy = DIZZY_TIME
			return
		var target := area.get_parent()
		if target is BaseMob and area.has_method("register_hit") and not bitten.has(target.get_instance_id()):
			bitten[target.get_instance_id()] = BITE_COOLDOWN
			area.register_hit(BITE_DAMAGE)
			Sound.play("hit", -8.0)

func _process(_delta: float) -> void:
	if dizzy <= 0.0:
		sprite.frame = int(Time.get_ticks_msec() / 160) % sprite.hframes

# Tir ennemi (projectile qui peut blesser) ; pas les plumes ni les oreillers du joueur.
static func _is_enemy_shot(area: Area2D) -> bool:
	return area.get("harmless") == false and not area.is_queued_for_deletion()
