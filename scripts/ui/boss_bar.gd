class_name BossBar
extends Control

# Barre de vie du boss, facon carnet de reves : une bande de papier scotchee en haut de l'ecran,
# le nom du boss ecrit a l'encre entre deux etoiles, et la vie coloriee au crayon rouge dans un
# cadre trace a la main. La part tout juste perdue reste un instant, comme gommee ; chaque seuil de
# phase est une croix d'encre (rouge une fois passe). Un coup fait tressauter la barre.
# Tout tombe sur la grille des pixels d'art (2 pixels du jeu). Elle descend a son apparition.

const SIZE := Vector2(212, 10)  # la barre ; avec son papier, laisse la place aux panneaux du HUD
const HEIGHT := 34.0  # nom + barre
const P := 2.0  # un pixel d'art
const INK := Color(0.17, 0.13, 0.25)
const PAPER := Color(0.93, 0.89, 0.8)
const PAPER_SHADE := Color(0.86, 0.8, 0.68)
const PENCIL := Color(0.84, 0.29, 0.33)
const PENCIL_DEEP := Color(0.64, 0.15, 0.24)
const PENCIL_LIGHT := Color(0.96, 0.6, 0.58)
const ERASED := Color(0.96, 0.78, 0.76)
const CRUMB := Color(0.78, 0.66, 0.66)
const SHIELD := Color(0.5, 0.58, 0.76)
const SHIELD_DEEP := Color(0.34, 0.4, 0.58)
const TAPE := Color(0.95, 0.92, 0.78, 0.78)

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
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", INK)
	title.add_theme_constant_override("outline_size", 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(-40, -4)
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
	var shake := 0.0
	if hit_flash > 0.0:  # le coup fait tressauter la barre
		shake = (P if int(hit_flash * 60.0) % 2 == 0 else -P)
	draw_set_transform(Vector2(shake, 0))
	# La bande de papier, dechiree, et un morceau de scotch a chaque bout.
	draw_style_box(ThemeDB.get_project_theme().get_stylebox("panel", &"Toast"), Rect2(Vector2(-16, -10), Vector2(SIZE.x + 32, HEIGHT + 16)))
	draw_rect(Rect2(-22, -14, 16, 8), TAPE)
	draw_rect(Rect2(SIZE.x + 6, -14, 16, 8), TAPE)
	_draw_title_stars()
	var top := HEIGHT - SIZE.y - 2.0
	var fill_w := _snap(SIZE.x * ratio)
	var recent_w := _snap(SIZE.x * recent)
	var deep := SHIELD_DEEP if shielded else PENCIL_DEEP
	var base := SHIELD if shielded else PENCIL
	var x := 0.0
	while x < SIZE.x:
		var col := int(x / P)
		for row in int(SIZE.y / P):
			var at := Vector2(x, top + row * P)
			# Fin du coloriage irreguliere, comme un coup de crayon qui s'arrete.
			var edge := fill_w - P * float(_h(row * 7 + 3) % 3)
			var color := PAPER_SHADE if (col + row) % 7 else PAPER
			if x < edge:
				color = base
				if (col + row * 2 + int(_h(col) % 2)) % 5 == 0:
					color = deep  # traits en biais, appuyes
				elif row == 0 and _h(col * 3) % 3 == 0:
					color = PENCIL_LIGHT if not shielded else Color(0.75, 0.8, 0.92)
				if hit_flash > 0.0:
					color = color.lerp(Color.WHITE, hit_flash / 0.12 * 0.6)
			elif x < recent_w:
				color = CRUMB if _h(col * 5 + row) % 6 == 0 else ERASED  # gomme
			draw_rect(Rect2(at, Vector2(P, P)), color)
		x += P
	_draw_frame(top)
	for threshold in thresholds:
		_draw_cross(Vector2(_snap(SIZE.x * threshold), top + SIZE.y / 2.0), ratio < threshold)
	draw_set_transform(Vector2.ZERO)

# Cadre trace a la main : le trait d'encre saute d'un pixel de temps en temps ; les bouts sont
# des crochets un peu bombes.
func _draw_frame(top: float) -> void:
	var x := -P
	while x <= SIZE.x:
		var col := int(x / P) + 1
		var up := -P if _h(col) % 7 == 0 else 0.0
		var down := P if _h(col + 50) % 6 == 0 else 0.0
		draw_rect(Rect2(x, top - P + up, P, P), INK)
		draw_rect(Rect2(x, top + SIZE.y + down, P, P), INK)
		x += P
	for row in range(-1, int(SIZE.y / P) + 1):
		var bulge := P if row >= 1 and row <= int(SIZE.y / P) - 2 else 0.0
		draw_rect(Rect2(-P - bulge, top + row * P, P, P), INK)
		draw_rect(Rect2(SIZE.x + bulge, top + row * P, P, P), INK)

# Seuil de phase : une petite croix d'encre a cheval sur la barre (rouge une fois franchi).
func _draw_cross(center: Vector2, passed: bool) -> void:
	var color := PENCIL_DEEP if passed else INK
	for i in range(-3, 4):
		draw_rect(Rect2(center + Vector2(i * P - P / 2.0, i * P - P / 2.0), Vector2(P, P)), color)
		draw_rect(Rect2(center + Vector2(i * P - P / 2.0, -i * P - P / 2.0), Vector2(P, P)), color)

# Deux petites etoiles d'encre de part et d'autre du nom.
func _draw_title_stars() -> void:
	var font := title.get_theme_font("font")
	var width := font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size("font_size")).x
	var y := 6.0
	for side in [-1.0, 1.0]:
		var c := Vector2(_snap(SIZE.x / 2.0 + side * (width / 2.0 + 12.0)), y)
		for d in [Vector2.ZERO, Vector2(P, 0), Vector2(-P, 0), Vector2(0, P), Vector2(0, -P)]:
			draw_rect(Rect2(c + d - Vector2(P, P) / 2.0, Vector2(P, P)), INK if d != Vector2.ZERO else PENCIL)

static func _snap(value: float) -> float:
	return floorf(value / 2.0) * 2.0

# Petit hasard fixe (le cadre ne doit pas trembler d'une image a l'autre).
static func _h(i: int) -> int:
	return absi(int(sin(float(i) * 12.9898) * 43758.5453))
