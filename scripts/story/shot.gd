class_name Shot
extends Node2D

# Un plan de cinematique (maquettes : animatiques Claude Design). Tout est place dans un repere
# 1280x720, le Stage de la scene est a l'echelle 1/2. update(t) place chaque calque d'apres le
# temps local du plan, sans tween : on peut sauter n'importe ou dans le temps.

const DIR := "res://assets/cinematics/"
const SIZE := Vector2(1280, 720)
const NIGHT := Color(0.016, 0.012, 0.035)

var duration := 10.0
var lines: Array = []  # [debut, fin, texte, caracteres par seconde]
var fade_in := 0.0  # fondu depuis le noir au debut du plan
var fade_out := 0.0  # fondu vers end_color a la fin du plan
var end_color := NIGHT
var hold_at_end := false  # reste sur la derniere image jusqu'a un appui (ecran titre)

static var _soft: GradientTexture2D
static var _disc: GradientTexture2D

func update(_t: float) -> void:
	pass

# --- Courbes ------------------------------------------------------------------------

static func ease01(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func back_out(t: float, s := 1.8) -> float:
	t = clampf(t, 0.0, 1.0) - 1.0
	return t * t * ((s + 1.0) * t + s) + 1.0

static func bell(t: float) -> float:
	return sin(PI * clampf(t, 0.0, 1.0))

# Assombrissement facon "multiply" : on teinte les calques au lieu de poser un calque dessus.
static func tint(color: Color, amount: float) -> Color:
	return Color.WHITE.lerp(color, amount)

# --- Calques ------------------------------------------------------------------------

func group(parent: Node = self) -> Node2D:
	var node := Node2D.new()
	parent.add_child(node)
	return node

# Image plein cadre (640x360 dessinee en 1280x720).
func layer(parent: Node, path: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(DIR + path + ".png")
	sprite.centered = false
	sprite.scale = Vector2(2, 2)
	parent.add_child(sprite)
	return sprite

# Image posee a une taille d'affichage donnee (coin haut gauche).
func image(parent: Node, path: String, pos: Vector2, size := Vector2.ZERO) -> Sprite2D:
	var sprite := layer(parent, path)
	place(sprite, pos, size if size != Vector2.ZERO else sprite.texture.get_size() * 2.0)
	return sprite

func place(sprite: Sprite2D, pos: Vector2, size: Vector2, flip := false) -> void:
	sprite.scale = size / sprite.texture.get_size() * Vector2(-1 if flip else 1, 1)
	sprite.position = pos + Vector2(size.x if flip else 0.0, 0)

func rect(parent: Node, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

# Halo additif (lumiere) ou tache douce (ombre), centre sur sa position.
func glow(parent: Node, color: Color, additive := true) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = soft_texture()
	sprite.modulate = color
	if additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = mat
	parent.add_child(sprite)
	return sprite

func set_glow(sprite: Sprite2D, center: Vector2, size: Vector2, alpha: float) -> void:
	sprite.position = center
	sprite.scale = size / 64.0
	sprite.modulate.a = alpha

# Particule ronde (poussiere, etincelle, etoile).
func dots(parent: Node, count: int, color: Color, additive := false) -> Array[Sprite2D]:
	var list: Array[Sprite2D] = []
	for i in count:
		var sprite := glow(parent, color, additive)
		sprite.texture = disc_texture()
		list.append(sprite)
	return list

func set_dot(sprite: Sprite2D, pos: Vector2, size: float, alpha: float) -> void:
	set_glow(sprite, pos + Vector2(size, size) / 2.0, Vector2(size, size), clampf(alpha, 0.0, 1.0))

# Voile sombre plein ecran perce d'un trou rond (scripts/story/veil.gdshader).
func veil(parent: Node, color: Color) -> ColorRect:
	var r := rect(parent, Vector2.ZERO, SIZE, Color.WHITE)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/story/veil.gdshader")
	mat.set_shader_parameter("tint", color)
	r.material = mat
	return r

func poly(parent: Node, points: PackedVector2Array, colors: PackedColorArray, additive := false) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	if colors.size() == 1:
		p.color = colors[0]  # une seule couleur : vertex_colors exige une couleur par point
	else:
		p.vertex_colors = colors
	if additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = mat
	parent.add_child(p)
	return p

func text(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

# Camera a parallaxe : (cx, cy) est le point du monde au centre de l'ecran, z le zoom ;
# un calque de facteur f suit la camera f fois (0 = fixe, 1 = monde, > 1 = premier plan).
static func follow(node: Node2D, cam: Vector3, f: float, extra := Vector2.ZERO) -> void:
	var z := 1.0 + (cam.z - 1.0) * f
	var c := Vector2(640, 360) + (Vector2(cam.x, cam.y) - Vector2(640, 360)) * f
	node.position = Vector2(640, 360) - c * z + extra
	node.scale = Vector2(z, z)

# Mise a l'echelle autour d'un point (transform-origin des maquettes).
static func scale_about(node: Node2D, origin: Vector2, s: Vector2, base_scale := Vector2(2, 2)) -> void:
	node.scale = base_scale * s
	node.position = origin - origin * s

static func soft_texture() -> GradientTexture2D:
	if _soft == null:
		_soft = _radial(PackedFloat32Array([0.0, 1.0]), PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)]))
	return _soft

static func disc_texture() -> GradientTexture2D:
	if _disc == null:
		_disc = _radial(PackedFloat32Array([0.0, 0.7, 1.0]), PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)]))
	return _disc

static func _radial(offsets: PackedFloat32Array, colors: PackedColorArray) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture

# Bande verticale degradee (vapeur, ciel) : couleurs du haut vers le bas.
static func vertical_texture(offsets: PackedFloat32Array, colors: PackedColorArray) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 8
	texture.height = 64
	return texture
