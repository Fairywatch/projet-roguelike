extends Node2D

# Cinematique (intro, fins de nuit) : une suite de plans animes (scripts/story/intro.gd,
# scripts/story/endings.gd) et le texte de scripts/story.gd qui s'ecrit en dessous.
# Une touche : affiche toute la phrase, puis saute a la suivante ; menu : passer.

@onready var stage: Node2D = $Stage
@onready var text_label: Label = $UI/Text
@onready var fade: ColorRect = $UI/Fade

var shots: Array[Shot] = []
var starts: Array[float] = []
var lines: Array = []  # [debut, fin, texte, caracteres par seconde], en temps de la cinematique
var total := 0.0
var time := 0.0
var finishing := false

func _ready() -> void:
	DreamTheme.set_family(FloorGenerator.Family.PROFOND)
	$UI/Hint.text = "%s : continuer   |   %s : passer" % [Controls.name_of("interact"), Controls.name_of("pause")]
	# Coupure des lignes calculee sur le texte entier : il ne se reorganise pas en s'ecrivant.
	text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	if GameState.cutscene_id == "intro":
		shots = Intro.shots()
	else:
		shots = Endings.shots(GameState.cutscene_id.trim_prefix("ending_"))
	for shot in shots:
		starts.append(total)
		for line in shot.lines:
			lines.append([line[0] + total, line[1] + total, line[2], line[3]])
		total += shot.duration
		stage.add_child(shot)
	Sound.music("reve")
	_show()

func _process(delta: float) -> void:
	if finishing:
		return
	time += delta
	if time >= total:
		if not shots.back().hold_at_end:
			finish()
			return
		time = total
	_show()

func _show() -> void:
	var index := starts.size() - 1
	while index > 0 and time < starts[index]:
		index -= 1
	for i in shots.size():
		shots[i].visible = i == index
	var shot := shots[index]
	var local := minf(time - starts[index], shot.duration)
	shot.update(local)
	# Fondus d'entree (depuis le noir) et de sortie (vers la couleur de fin du plan).
	var black := 1.0 - Shot.ease01(local / shot.fade_in) if shot.fade_in > 0 else 0.0
	var out := Shot.ease01((local - shot.duration + shot.fade_out + 0.1) / shot.fade_out) if shot.fade_out > 0 else 0.0
	fade.color = shot.end_color if out > black else Shot.NIGHT
	fade.color.a = maxf(black, out)
	var line: Variant = _line_at(time)
	text_label.visible = line != null
	if line != null:
		if text_label.text != line[2]:
			text_label.text = line[2]
		text_label.visible_characters = int((time - line[0]) * line[3])
		text_label.modulate.a = minf(Shot.ease01((time - line[0]) / 0.3), 1.0 - Shot.ease01((time - line[1] + 0.5) / 0.5))

func _line_at(t: float):
	for line in lines:
		if t >= line[0] and t < line[1]:
			return line
	return null

func _unhandled_input(event: InputEvent) -> void:
	if finishing:
		return
	if event.is_action_pressed("pause"):
		finish()
		return
	var pressed := (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed() and not event.is_echo()
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	var line: Variant = _line_at(time)
	if line != null:
		var typed_until: float = line[0] + line[2].length() / line[3]
		if time < typed_until:
			time = typed_until  # premier appui : toute la phrase
			return
	for next in lines:  # appui suivant : phrase suivante
		if next[0] > time:
			time = next[0]
			return
	finish()

func finish() -> void:
	if finishing:
		return
	finishing = true
	GameState.cutscene_id = ""
	SceneTransition.change_scene(GameState.cutscene_next)
