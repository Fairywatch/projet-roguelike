class_name DreamTheme
extends RefCounted

# Habillage visuel d'un etage : tuiles (tools/gen_pixel_art.py), decors, lumiere, particules.
# Intensite (reve/cauchemar) = palette ; famille (paradoxal/profond) = ambiance et decors.

const TILE_DIR := "res://assets/sprites/tiles/"
const DECOR_DIR := "res://assets/sprites/decor/"
const FLOOR_VARIANTS := 4
# Les lumieres sont additives : sur un sol clair (paradoxal) elles doivent rester discretes.
const PARADOXAL_LIGHT_SCALE := 0.3
const DECOR := {
	FloorGenerator.Family.PARADOXAL: ["etoile", "lune", "nuage", "cube", "horloge", "bulle"],
	FloorGenerator.Family.PROFOND: ["bougie", "champignon", "cristal", "rocher", "arbre_mort"],
}
# Decors qui flottent (petit mouvement de haut en bas) ou qui eclairent.
const FLOATING := ["etoile", "lune", "nuage", "bulle", "horloge"]
const GLOWING := {
	"etoile": Color(1, 0.85, 0.4), "lune": Color(1, 0.95, 0.7), "bougie": Color(1, 0.6, 0.25),
	"champignon": Color(0.35, 0.95, 0.85), "cristal": Color(0.7, 0.45, 1),
}

static var _light_texture: GradientTexture2D
# Regle par la scene (carte, arene) selon la famille de l'etage, avant de creer ses lumieres.
static var light_scale := 1.0

static func set_family(family: int) -> void:
	light_scale = PARADOXAL_LIGHT_SCALE if family == FloorGenerator.Family.PARADOXAL else 1.0

static func theme_name(family: int, intensity: int) -> String:
	var mood := "reve" if intensity == FloorGenerator.Intensity.REVE else "cauchemar"
	var kind := "paradoxal" if family == FloorGenerator.Family.PARADOXAL else "profond"
	return "%s_%s" % [mood, kind]

static func floor_textures(theme: String) -> Array:
	var textures := []
	for i in FLOOR_VARIANTS:
		textures.append(load("%s%s_floor_%d.png" % [TILE_DIR, theme, i]))
	return textures

static func wall_texture(theme: String, part: String) -> Texture2D:
	return load("%s%s_wall_%s.png" % [TILE_DIR, theme, part])

static func decor_texture(family: int, decor_name: String) -> Texture2D:
	var folder := "paradoxal" if family == FloorGenerator.Family.PARADOXAL else "profond"
	return load("%s%s/%s.png" % [DECOR_DIR, folder, decor_name])

# Sommeil profond : penombre oppressante ; paradoxal : lumiere vive.
static func ambient_color(family: int, intensity: int) -> Color:
	var c := Color(0.95, 0.95, 1.0) if family == FloorGenerator.Family.PARADOXAL else Color(0.42, 0.42, 0.55)
	if intensity == FloorGenerator.Intensity.CAUCHEMAR:
		c = c * Color(1.0, 0.8, 0.85)
	return c

static func light_texture() -> GradientTexture2D:
	if _light_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		_light_texture = GradientTexture2D.new()
		_light_texture.gradient = gradient
		_light_texture.fill = GradientTexture2D.FILL_RADIAL
		_light_texture.fill_from = Vector2(0.5, 0.5)
		_light_texture.fill_to = Vector2(1.0, 0.5)
		_light_texture.width = 128
		_light_texture.height = 128
	return _light_texture

static func make_light(color: Color, radius: float, energy: float = 1.0) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = light_texture()
	light.color = color
	light.energy = energy * light_scale
	light.texture_scale = radius / 64.0
	return light

# Particules d'ambiance qui suivent le joueur : etincelles colorees (paradoxal) ou cendres lentes (profond).
static func make_ambient_particles(family: int) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = Settings.enabled("ambient_particles")
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(360, 220)
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 2.0
	p.scale_amount_max = 2.0
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	if family == FloorGenerator.Family.PARADOXAL:
		p.amount = 40
		p.lifetime = 4.0
		p.direction = Vector2.UP
		p.spread = 30.0
		p.initial_velocity_min = 8.0
		p.initial_velocity_max = 20.0
		var colors := Gradient.new()
		colors.colors = PackedColorArray([Color(1, 0.9, 0.5), Color(0.6, 0.9, 1), Color(1, 0.6, 0.9)])
		p.color_initial_ramp = colors
	else:
		p.amount = 30
		p.lifetime = 6.0
		p.direction = Vector2(1, 0.3)
		p.spread = 20.0
		p.initial_velocity_min = 4.0
		p.initial_velocity_max = 10.0
		p.color = Color(0.6, 0.6, 0.7, 0.6)
	return p
