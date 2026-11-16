class_name HazardArt
extends RefCounted

# Outils de dessin partages par les attaques ennemies (zones, rayons, ondes, bras, rocher...).
# Tout est dessine en code, dans l'esprit du pixel art du jeu : un contour sombre, une couleur
# franche, un rehaut clair. Regle commune a tous les dangers : l'annonce (telegraphe) est fine,
# en pointilles, et se "remplit" jusqu'a l'instant de la frappe ; la frappe est pleine et vive.

static func outline(color: Color, alpha: float = 0.9) -> Color:
	return Color(color.darkened(0.7), alpha)

static func light(color: Color, alpha: float = 1.0) -> Color:
	return Color(color.lightened(0.55), alpha)

# Cercle en pointilles qui tourne (phase en radians).
static func dashed_circle(canvas: CanvasItem, radius: float, color: Color, width: float, dashes: int, phase: float) -> void:
	var step := TAU / dashes
	for i in dashes:
		var a := phase + i * step
		canvas.draw_arc(Vector2.ZERO, radius, a, a + step * 0.55, 6, color, width)

# Trait en pointilles le long de +X, dont les tirets avancent vers la pointe.
static func dashed_line(canvas: CanvasItem, length: float, color: Color, width: float, dash: float, gap: float, phase: float) -> void:
	var x := fmod(phase, dash + gap) - (dash + gap)
	while x < length:
		var a := maxf(x, 0.0)
		var b := minf(x + dash, length)
		if b > a:
			canvas.draw_line(Vector2(a, 0), Vector2(b, 0), color, width)
		x += dash + gap

# Tache aux bords qui ondulent (flaque, brouillard, braise).
static func blob(canvas: CanvasItem, radius: float, color: Color, t: float, wobble: float, seed: float, points: int = 28) -> void:
	var poly := PackedVector2Array()
	for i in points:
		var a := TAU * i / points
		var r := radius * (1.0 + wobble * (sin(a * 3.0 + t * 1.7 + seed) * 0.6 + sin(a * 5.0 - t * 2.3 + seed * 2.0) * 0.4))
		poly.append(Vector2.from_angle(a) * r)
	canvas.draw_colored_polygon(poly, color)

# Lame effilee le long de +X (aiguille d'horloge, balancier) : large a la base, fine au bout.
static func blade(length: float, base_half: float, tip_half: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -base_half), Vector2(length * 0.82, -tip_half), Vector2(length, 0),
		Vector2(length * 0.82, tip_half), Vector2(0, base_half),
	])
