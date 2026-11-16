class_name Endings
extends RefCounted

# Les fins de nuit : une scene par nuit, sur le texte de Story.ENDINGS. Comme l'intro, ce sont des
# scenes 3D rendues en pixel art dans Blender (tools/blender/endings_cinematic.py) et jouees en
# video (assets/cinematics/fins/fin_<nuit>.ogv) ; Godot ecrit le texte par-dessus. Chaque fin
# s'ouvre depuis le noir et s'y referme (l'aube du dimanche, en blanc dore).
#   lundi : les disputes derriere la porte se taisent, il s'endort enfin.
#   mardi : une main pose une etoile doree sur la copie ratee.
#   mercredi : au carrefour, il hesite, puis choisit ; le chemin s'allume sous ses pas.
#   jeudi : l'orage de colere gronde sur la fournaise, puis passe.
#   vendredi : charge de cartons, il les pose et s'assoit sur un banc, un the a cote de lui.
#   samedi : la salle de bal vide se remplit de silhouettes lumineuses qui dansent autour de lui.
#   dimanche : l'aube se leve, les sept tours se dissolvent dans la lumiere, il se reveille.

# Nuit -> [duree de la video, instant ou commence chaque phrase].
const NIGHTS := {
	"lundi": [13.5, [0.8, 7.0]],
	"mardi": [12.5, [0.8, 6.4]],
	"mercredi": [12.5, [0.8, 6.4]],
	"jeudi": [12.5, [0.8, 6.4]],
	"vendredi": [13.5, [0.8, 6.6]],
	"samedi": [13.5, [0.8, 6.6]],
	"dimanche": [18.0, [0.8, 6.2, 11.8]],
}
const DAWN := Color("FFF4DE")  # le dimanche se referme sur la lumiere du jour

static func shots(night: String) -> Array[Shot]:
	return [NightEnding.new(night if NIGHTS.has(night) else "dimanche")]

# Les phrases de la fin, chacune a partir de son instant de depart.
static func story_lines(night: String, starts: Array, duration: float) -> Array:
	var texts: Array = Story.ENDINGS[night]
	var out := []
	for i in starts.size():
		var end: float = starts[i + 1] - 0.4 if i + 1 < starts.size() else duration - 1.1
		out.append([starts[i], end, texts[i], 34.0])
	return out

static func setup(shot: Shot, night: String, duration: float, starts: Array) -> void:
	shot.duration = duration
	shot.fade_in = 0.8
	shot.fade_out = 1.0
	shot.lines = story_lines(night, starts, duration)


class NightEnding extends Shot:
	var film: VideoStreamPlayer

	func _init(night: String) -> void:
		var data: Array = Endings.NIGHTS[night]
		Endings.setup(self, night, data[0], data[1])
		if night == "dimanche":
			end_color = Endings.DAWN
		film = video(self, "fins/fin_" + night)

	func update(t: float) -> void:
		sync_video(film, t, duration)
