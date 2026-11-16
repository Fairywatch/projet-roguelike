class_name BossBar
extends Control

# Barre de vie du boss, en haut de l'ecran sous son nom : cadre sombre, vie rouge, un trait a chaque
# seuil de phase (boss de fin), et une trainee claire qui montre les degats du dernier coup.

const SIZE := Vector2(240, 10)
const FRAME := Color(0.08, 0.03, 0.08)
const EMPTY := Color(0.22, 0.14, 0.24, 0.9)
const FULL := Color(0.93, 0.22, 0.32)
const SHINE := Color(1, 0.6, 0.62)
const RECENT := Color(1, 0.9, 0.75)
const INVULNERABLE := Color(0.55, 0.6, 0.75)

var ratio := 1.0
var recent := 1.0  # ratio affiche avec retard : la part perdue reste claire un instant
var thresholds: Array = []
var shielded := false

func _ready() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_boss(boss: BaseMob) -> void:
	ratio = clampf(float(boss.hp) / maxf(boss.max_hp, 1), 0.0, 1.0)
	recent = maxf(recent, ratio)
	thresholds = boss.get("PHASE_THRESHOLDS") if boss.get("PHASE_THRESHOLDS") != null else []
	shielded = boss.invulnerable
	queue_redraw()

func _process(delta: float) -> void:
	if recent > ratio:
		recent = maxf(ratio, recent - delta * 0.35)
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-2, -2, SIZE.x + 4, SIZE.y + 4), FRAME)
	draw_rect(Rect2(Vector2.ZERO, SIZE), EMPTY)
	draw_rect(Rect2(0, 0, SIZE.x * recent, SIZE.y), RECENT)
	draw_rect(Rect2(0, 0, SIZE.x * ratio, SIZE.y), INVULNERABLE if shielded else FULL)
	draw_rect(Rect2(0, 0, SIZE.x * ratio, 3), Color(SHINE, 0.2) if shielded else SHINE)
	for threshold in thresholds:
		draw_rect(Rect2(SIZE.x * threshold - 1, -2, 2, SIZE.y + 4), FRAME)
