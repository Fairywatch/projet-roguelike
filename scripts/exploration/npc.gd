class_name DreamNpc
extends Area2D

# Habitant du reve qui propose une petite quete (interagir pour lui parler). L'etat de la quete vit
# dans current_floor()["quest"] : il survit aux combats et a la sauvegarde.
#   chasse      : gagner N combats sur l'etage apres avoir accepte ;
#   objet_perdu : rapporter l'objet pose a l'autre bout de l'etage.

signal said(text: String)
signal rewarded(entry: Dictionary)

const NPCS := [
	# my_object : dans la bouche du PNJ ; object : dans les messages du jeu.
	{"id": "hibou", "name": "Hibou insomniaque", "my_object": "ma plume d'argent", "object": "la plume d'argent"},
	{"id": "lapin", "name": "Lapin horloger", "my_object": "ma clé de remontoir", "object": "la clé de remontoir"},
	{"id": "marchande", "name": "Marchande de lune", "my_object": "ma poussière de lune", "object": "la poussière de lune"},
]
const KINDS := ["chasse", "objet_perdu"]
const REWARD_OFFSET := Vector2(0, 60)
const RADIUS := 44.0

var npc: Dictionary
var quest: Dictionary
var player_near := false
var sprite := Sprite2D.new()
var marker := Label.new()

# Quete tiree a partir de la graine de l'etage, pour rester la meme apres un combat.
static func make_quest(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"npc": rng.randi() % NPCS.size(),
		"kind": KINDS[rng.randi() % KINDS.size()],
		"target": rng.randi_range(2, 3),
		"state": "offered",
		"start_wins": 0,
		"carried": false,
	}

func _ready() -> void:
	npc = NPCS[quest["npc"]]
	sprite.texture = load("res://assets/sprites/npcs/%s.png" % npc["id"])
	sprite.scale = Vector2(2, 2)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = RADIUS
	add_child(shape)
	marker.add_theme_font_size_override("font_size", 16)
	marker.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	marker.add_theme_constant_override("outline_size", 4)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.size = Vector2(40, 20)
	marker.position = Vector2(-20, -52)
	add_child(marker)
	var tween := sprite.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", -3.0, 1.1)
	tween.tween_property(sprite, "position:y", 0.0, 1.1)
	body_entered.connect(func(body): if body.is_in_group("player"): player_near = true)
	body_exited.connect(func(body): if body.is_in_group("player"): player_near = false)
	refresh()

func is_complete() -> bool:
	if quest["kind"] == "chasse":
		return GameState.current_floor()["wins"] - quest["start_wins"] >= quest["target"]
	return quest["carried"]

# "!" : quete a prendre ; "?" dore : a rendre ; "..." : en cours.
func refresh() -> void:
	match quest["state"]:
		"offered":
			marker.text = "!"
			marker.modulate = Color(1, 1, 1)
		"active":
			marker.text = "?" if is_complete() else "..."
			marker.modulate = Color(1, 0.85, 0.3) if is_complete() else Color(0.8, 0.8, 0.9)
		_:
			marker.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if not player_near or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	talk()

func talk() -> void:
	match quest["state"]:
		"offered":
			# Premier echange : l'habitant parle du reveur (scripts/story.gd), puis propose la quete.
			if not quest.get("told", false):
				quest["told"] = true
				_say(story_line())
				refresh()
				return
			quest["state"] = "active"
			quest["start_wins"] = GameState.current_floor()["wins"]
			Sound.play("quest")
			if quest["kind"] == "chasse":
				_say("Des cauchemars rôdent par ici... Gagne %d combats sur cet étage et je te récompenserai." % quest["target"])
			else:
				_say("J'ai perdu %s à l'autre bout de l'étage. Tu pourrais me la rapporter ?" % npc["my_object"])
		"active":
			if is_complete():
				quest["state"] = "done"
				GameState.coins += GameState.COINS_PER_QUEST
				Sound.play("victory")
				var entry := {"id": GameState.roll_item_id(GameState.QUEST_LOOT_BONUS), "pos": position + REWARD_OFFSET}
				GameState.current_floor()["ground_items"].append(entry)
				rewarded.emit(entry)
				_say("Merci, voyageur ! Prends ceci : %s. (+%d pièces)" % [Items.find(entry["id"])["name"], GameState.COINS_PER_QUEST])
			elif quest["kind"] == "chasse":
				var left: int = quest["target"] - (GameState.current_floor()["wins"] - quest["start_wins"])
				_say("Encore %d combat(s) à gagner." % left)
			else:
				_say("Tu n'as pas encore retrouve %s ? Cherche loin d'ici." % npc["my_object"])
		_:
			_say("Bonne nuit, voyageur.")
	refresh()

func story_line() -> String:
	var lines: Array = Story.NPC_LINES.get(GameState.tower()["id"], [])
	return lines[quest["npc"] % lines.size()] if not lines.is_empty() else "Bonne nuit, voyageur."

func _say(text: String) -> void:
	said.emit("%s : %s" % [npc["name"], text])
