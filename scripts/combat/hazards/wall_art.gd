extends Node2D

# Dessin d'un mur temporaire (labyrinthe...) : un muret de pierres, contour sombre, dessus clair,
# joints. Centre sur le noeud ; la collision est posee par Hazards.wall().

var size := Vector2(100, 20)
var color := Color(0.4, 0.45, 0.42)

func _draw() -> void:
	var rect := Rect2(-size / 2.0, size)
	draw_rect(Rect2(rect.position + Vector2(3, 5), size), Color(0, 0, 0, 0.3))  # ombre portee
	draw_rect(rect.grow(2.0), HazardArt.outline(color))
	draw_rect(rect, color)
	draw_rect(Rect2(rect.position, Vector2(size.x, minf(4.0, size.y * 0.3))), HazardArt.light(color, 0.7))
	draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - minf(4.0, size.y * 0.3)), Vector2(size.x, minf(4.0, size.y * 0.3))), color.darkened(0.3))
	# Joints : des pierres d'environ 26 px le long du grand cote, decalees d'un rang sur l'autre.
	var joint := color.darkened(0.45)
	var horizontal := size.x >= size.y
	var along := size.x if horizontal else size.y
	var across := size.y if horizontal else size.x
	var rows := maxi(1, int(across / 14.0))
	for row in rows:
		var offset := 13.0 if row % 2 else 0.0
		var d := 26.0 - offset
		while d < along - 4.0:
			var a := float(row) / rows * across
			var b := float(row + 1) / rows * across
			if horizontal:
				draw_line(rect.position + Vector2(d, a), rect.position + Vector2(d, b), joint, 2.0)
			else:
				draw_line(rect.position + Vector2(a, d), rect.position + Vector2(b, d), joint, 2.0)
			d += 26.0
		if row > 0:
			var line := float(row) / rows * across
			if horizontal:
				draw_line(rect.position + Vector2(0, line), rect.position + Vector2(size.x, line), joint, 2.0)
			else:
				draw_line(rect.position + Vector2(line, 0), rect.position + Vector2(line, size.y), joint, 2.0)
