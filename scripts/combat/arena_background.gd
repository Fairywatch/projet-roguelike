extends Node2D

const ARENA_WIDTH := 900
const ARENA_HEIGHT := 540
const CELL_SIZE := 100
const EDGE_SHADE := 40

var floor_textures: Array = []
var cell_seed := 0
# Surface a couvrir (l'arene par defaut ; le hub et le menu en demandent une autre).
var area := Vector2(ARENA_WIDTH, ARENA_HEIGHT)

func setup(family: int, intensity: int, night: String = "") -> void:
	floor_textures = DreamTheme.floor_textures(DreamTheme.theme_name(family, intensity, night))
	cell_seed = randi()
	queue_redraw()

func _draw() -> void:
	if floor_textures.is_empty():
		return
	for y in ceili(area.y / CELL_SIZE):
		for x in ceili(area.x / CELL_SIZE):
			var tex: Texture2D = floor_textures[hash(Vector3i(x, y, cell_seed)) % floor_textures.size()]
			var rect := Rect2(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			var clipped := rect.intersection(Rect2(Vector2.ZERO, area))
			var src := Rect2(Vector2.ZERO, clipped.size / 2.0)
			draw_texture_rect_region(tex, clipped, src)
	# Bords assombris : l'arene semble posee au milieu du reve.
	for i in EDGE_SHADE / 4:
		var a := 0.5 * (1.0 - float(i) / (EDGE_SHADE / 4))
		var r := Rect2(i * 4, i * 4, area.x - i * 8, area.y - i * 8)
		draw_rect(r, Color(0, 0, 0, a * 0.35), false, 4.0)
