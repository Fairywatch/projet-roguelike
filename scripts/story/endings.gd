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
# Nuit -> bruitages cales sur la video : [instant, nom (Sound.play)].
const SOUNDS := {
	"lundi": [[0.5, "encounter"], [1.4, "encounter"], [2.2, "encounter"], [3.0, "encounter"], [7.9, "heal"]],  # la dispute, puis le sommeil
	"mardi": [[6.6, "sparkle"], [6.8, "victory"]],  # l'etoile se pose
	"mercredi": [[6.7, "pop"], [7.5, "pop"], [8.3, "pop"], [9.1, "pop"], [9.9, "pop"], [10.7, "pop"], [11.5, "pop"]],  # les pierres s'allument
	"jeudi": [[1.4, "boss"], [2.9, "boss"], [4.3, "boss"], [6.4, "portal"]],  # le tonnerre, puis l'orage s'eloigne
	"vendredi": [[5.5, "chest"], [7.6, "pop"]],  # les cartons poses, le the
	"samedi": [[6.2, "sparkle"], [6.8, "sparkle"], [7.4, "sparkle"], [8.0, "sparkle"]],  # les silhouettes entrent
	"dimanche": [[9.0, "sparkle"], [9.8, "sparkle"], [10.6, "sparkle"], [11.4, "sparkle"], [12.6, "heal"], [13.6, "victory"]],  # les tours, le reveil
}

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
		sounds = Endings.SOUNDS[night]
		if night == "dimanche":
			end_color = Endings.DAWN
		film = video(self, "fins/fin_" + night)

	func update(t: float) -> void:
		sync_video(film, t, duration)
