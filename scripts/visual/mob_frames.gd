class_name MobFrames
extends RefCounted

# Nombre d'images des sprites des creatures (bande horizontale, dessinee par tools/mob_art.py et
# tools/mob_art_week.py) : 4 images d'animation. Les sprites "a etats" n'en ont que 2, choisies par
# leur script (Paupiere fermee / ouverte, Porte close / entrouverte, Examen oeil clos / ouvert...).

const DEFAULT := 4
const STATE_SPRITES := {
	"res://assets/sprites/mobs/lundi/paupiere.png": 2,
	"res://assets/sprites/mobs/lundi/porte_des_voix.png": 2,
	"res://assets/sprites/mobs/mardi/examen.png": 2,
	"res://assets/sprites/mobs/mercredi/masque.png": 2,
	"res://assets/sprites/mobs/mercredi/miroir_brise.png": 2,
	"res://assets/sprites/mobs/mercredi/pile_ou_face.png": 2,
	"res://assets/sprites/mobs/samedi/absence.png": 2,
}
const FPS := {2: 3.0, 4: 6.0}

static func count(texture_path: String) -> int:
	return STATE_SPRITES.get(texture_path, DEFAULT)

static func fps(frames: int) -> float:
	return FPS.get(frames, 3.0)
