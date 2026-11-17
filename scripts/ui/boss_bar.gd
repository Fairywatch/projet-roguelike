class_name BossBar
extends Control

# Barre de vie du boss, en haut de l'ecran : son nom au-dessus, un cadre arrondi, la vie en rouge,
# un trait a chaque seuil de phase (boss de fin), une trainee claire qui montre les degats du
# dernier coup, et un eclair blanc a chaque coup. Elle descend en douceur a son apparition.

const SIZE := Vector2(250, 9)
const HEIGHT := 26.0  # nom + barre
const FRAME := Color(0.08, 0.03, 0.08)
const EMPTY := Color(0.22, 0.14, 0.24, 0.9)
const FULL := Color(0.93, 0.22, 0.32)
const DEEP := Color(0.62, 0.1, 0.22)
const SHINE := Color(1, 0.6, 0.62)
const RECENT := Color(1, 0.9, 0.75)
const INVULNERABLE := Color(0.55, 0.6, 0.75)

var ratio := 1.0
var recent := 1.0  # ratio affiche avec retard : la part perdue reste claire un instant
var thresholds: Array = []
var shielded := false
var hit_flash := 0.0
var title := Label.new()
var shown := false

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE.x, HEIGHT)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.theme_type_variation = &"PixelTitle"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_constant_override("outline_size", 5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(-40, -6)
	title.size = Vector2(SIZE.x + 80, 16)
	add_child(title)
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if not visible or shown:
		return
	shown = true
	modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	var rest := position.y
	position.y -= 12.0
	tween.tween_property(self, "position:y", rest, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func show_boss(boss: BaseMob) -> void:
	var new_ratio := clampf(float(boss.hp) / maxf(boss.max_hp, 1), 0.0, 1.0)
	if new_ratio < ratio - 0.0001:
		hit_flash = 0.12
	ratio = new_ratio
	recent = maxf(recent, ratio)
	thresholds = boss.get("PHASE_THRESHOLDS") if boss.get("PHASE_THRESHOLDS") != null else []
	shielded = boss.invulnerable
	title.text = boss.display_name if boss.display_name != "" else "Gardien du portail"
	queue_redraw()

func _process(delta: float) -> void:
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)
		queue_redraw()
	if recent > ratio:
		recent = maxf(ratio, recent - delta * 0.35)
		queue_redraw()

func _draw() -> void:
	var bar := Rect2(Vector2(0, HEIGHT - SIZE.y - 2), SIZE)
	var frame := StyleBoxFlat.new()
	frame.bg_color = EMPTY
	frame.border_color = FRAME
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(4)
	frame.set_expand_margin_all(2)
	draw_style_box(frame, bar)
	draw_rect(Rect2(bar.position, Vector2(SIZE.x * recent, SIZE.y)), RECENT)
	var fill := Rect2(bar.position, Vector2(SIZE.x * ratio, SIZE.y))
	var color := INVULNERABLE if shielded else FULL
	draw_rect(fill, color)
	draw_rect(Rect2(fill.position + Vector2(0, SIZE.y - 3), Vector2(fill.size.x, 3)), Color(DEEP, 0.0 if shielded else 0.8))
	draw_rect(Rect2(fill.position, Vector2(fill.size.x, 2)), Color(SHINE, 0.2) if shielded else SHINE)
	if hit_flash > 0.0:
		draw_rect(fill, Color(1, 1, 1, hit_flash / 0.12 * 0.7))
	for threshold in thresholds:
		draw_rect(Rect2(bar.position + Vector2(SIZE.x * threshold - 1, -2), Vector2(2, SIZE.y + 4)), FRAME)
