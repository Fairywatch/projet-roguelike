extends Node

# Dimanche (Angoisse) - La nuit se referme : l'obscurite gagne depuis les bords de l'ecran avec le
# temps passe sur l'etage, autour du reveur. Les lumieres (soin, guide, lumiere) la repoussent un
# moment. Premier etage : lente et loin ; dernier : rapide, jusqu'a un cercle autour du reveur.
# En combat, les bords de l'arene sont plus sombres. Le Coeur de la nuit (profond) bat doucement.

const INTRO := "La lumière s'en va... Garde-la près de toi."
const OPEN := 1.3  # rayon sans obscurite (1 = coin de l'ecran)
const MIN_RADIUS := Vector2(0.8, 0.28)  # rayon le plus serre : premier etage, dernier
const CLOSE_TIME := Vector2(90.0, 40.0)  # secondes pour se refermer
const PUSH_BACK := 0.45  # ce que rend une lumiere
const COMBAT_RADIUS := Vector2(1.1, 0.85)
const HEARTBEAT := 0.08  # amplitude du battement de lumiere (profond)
const SHADER := """
shader_type canvas_item;
uniform vec2 center = vec2(0.5);
uniform float radius = 1.3;
uniform float aspect = 1.7778;
void fragment() {
	vec2 d = (UV - center) * vec2(aspect, 1.0);
	float dist = length(d) / (0.5 * length(vec2(aspect, 1.0)));
	COLOR = vec4(0.02, 0.0, 0.04, smoothstep(radius - 0.3, radius, dist) * 0.97);
}
"""

var strength := 0.0
var map: Node
var floor_data
var radius := OPEN
var veil: ColorRect
var ambient: CanvasModulate
var base_color := Color.WHITE

static func make_veil(layer: CanvasLayer) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	rect.material = ShaderMaterial.new()
	rect.material.shader = shader
	layer.add_child(rect)
	layer.move_child(rect, 0)  # sous l'interface
	return rect

static func apply_combat(arena: Node, force: float) -> void:
	var rect := make_veil(arena.get_node("UI"))
	rect.material.set_shader_parameter("radius", lerpf(COMBAT_RADIUS.x, COMBAT_RADIUS.y, force))

func _ready() -> void:
	veil = make_veil(map.get_node("UI"))

func _process(delta: float) -> void:
	if not map.player.frozen:
		var floor_radius := lerpf(MIN_RADIUS.x, MIN_RADIUS.y, strength)
		radius = maxf(floor_radius, radius - (OPEN - floor_radius) * delta / lerpf(CLOSE_TIME.x, CLOSE_TIME.y, strength))
	var size := map.get_viewport().get_visible_rect().size
	var screen_pos: Vector2 = map.player.get_global_transform_with_canvas().origin
	veil.material.set_shader_parameter("center", screen_pos / size)
	veil.material.set_shader_parameter("aspect", size.x / size.y)
	veil.material.set_shader_parameter("radius", radius)
	_heartbeat()

func on_decor(decor_name: String) -> void:
	if decor_name in ["etoile", "lune", "bougie"]:
		radius = minf(OPEN, radius + PUSH_BACK)

# Dans le Coeur de la nuit, la lumiere ambiante bat comme un coeur (deux battements, une pause).
func _heartbeat() -> void:
	if map.family != FloorGenerator.Family.PROFOND:
		return
	if ambient == null:
		for child in map.get_children():
			if child is CanvasModulate:
				ambient = child
				base_color = child.color
		if ambient == null:
			return
	var t := fmod(Time.get_ticks_msec() / 1000.0, 1.2)
	var beat := exp(-pow((t - 0.1) * 12.0, 2)) + 0.7 * exp(-pow((t - 0.35) * 12.0, 2))
	ambient.color = base_color * (1.0 + HEARTBEAT * beat)
