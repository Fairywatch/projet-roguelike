class_name PixelFx
extends RefCounted

# Dangers ennemis en pixel art (zones, anneaux, rayons, balayages) : des shaders qui arrondissent
# tout a la grille des pixels d'art (2 pixels du jeu, comme les sprites), avec une palette de 4 tons
# tiree de la couleur du danger, et le motif de la nuit en cours (PATTERNS). Voir
# assets/shaders/pixel_*.gdshader.

const ZONE := preload("res://assets/shaders/pixel_zone.gdshader")
const RING := preload("res://assets/shaders/pixel_ring.gdshader")
const BEAM := preload("res://assets/shaders/pixel_beam.gdshader")
const PX := 2.0
# Motif de chaque nuit (0 : neutre). Lundi : tissu, coutures, drap plisse.
const PATTERNS := {"lundi": 1}
# Motifs semes dans les dangers de chaque nuit (tools/gen_projectiles.py) : bande de 8x8.
const MOTIFS := {
	"lundi": preload("res://assets/sprites/fx/motifs_lundi.png"),
	"mardi": preload("res://assets/sprites/fx/motifs_mardi.png"),
	"mercredi": preload("res://assets/sprites/fx/motifs_mercredi.png"),
	"jeudi": preload("res://assets/sprites/fx/motifs_jeudi.png"),
	"vendredi": preload("res://assets/sprites/fx/motifs_vendredi.png"),
	"samedi": preload("res://assets/sprites/fx/motifs_samedi.png"),
	"dimanche": preload("res://assets/sprites/fx/motifs_dimanche.png"),
}
const MOTIF_SIZE := 8

# Nuit en cours ("" hors d'une nuit). GameState est cherche a l'execution : cette classe sert aux
# dangers, que les tests compilent avant que les autoloads n'existent.
static func night() -> String:
	var state: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameState")
	if state == null or not state.run_started:
		return ""
	return str(state.night())

static func pattern() -> int:
	return PATTERNS.get(night(), 0)

# Cerne, sombre, moyen, clair : quatre tons tires de la couleur du danger.
static func palette(color: Color) -> Array:
	var base := Color(color, 1.0)
	return [base.darkened(0.72), base.darkened(0.32), base, base.lightened(0.5)]

static func material(shader: Shader, color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var tones := palette(color)
	mat.set_shader_parameter("outline_color", tones[0])
	mat.set_shader_parameter("dark_color", tones[1])
	mat.set_shader_parameter("mid_color", tones[2])
	mat.set_shader_parameter("light_color", tones[3])
	mat.set_shader_parameter("pattern", pattern())
	mat.set_shader_parameter("px", PX)
	mat.set_shader_parameter("alpha", color.a)
	mat.set_shader_parameter("seed", randf() * 100.0)  # deux dangers voisins ne se ressemblent pas
	var motifs: Texture2D = MOTIFS.get(night())
	if motifs:
		mat.set_shader_parameter("motifs", motifs)
		mat.set_shader_parameter("motif_count", motifs.get_width() / MOTIF_SIZE)
	return mat
