extends Node2D

const ENCOUNTER_CHANCE := 0.05
const FloorExitScene := preload("res://scenes/exploration/FloorExit.tscn")

@onready var player: CharacterBody2D = $Player
@onready var flash: ColorRect = $UI/ScreenFlash
@onready var background: Node2D = $Background
@onready var generated_root: Node2D = $Generated
@onready var encounter_timer: Timer = $EncounterTimer
@onready var floor_label: Label = $UI/FloorLabel
@onready var message_label: Label = $UI/MessageLabel

func _ready() -> void:
	var floor_meta := GameState.get_or_create_floor_data(GameState.floor_index)

	var rng := RandomNumberGenerator.new()
	rng.seed = floor_meta["seed"]
	var floor_data := FloorGenerator.generate(floor_meta["family"], floor_meta["intensity"], rng)

	_build_walls(floor_data)
	background.setup(floor_data.floor_cells, FloorGenerator.GRID_WIDTH, FloorGenerator.GRID_HEIGHT, floor_meta["intensity"])
	_spawn_floor_exit(floor_data)
	floor_label.text = "Etage: %d" % GameState.floor_index

	if GameState.return_position != Vector2.ZERO:
		player.global_position = GameState.return_position
	else:
		player.global_position = _cell_to_world(floor_data.spawn_cell)

	encounter_timer.timeout.connect(_on_encounter_timer_timeout)

	if GameState.pending_message != "":
		message_label.text = GameState.pending_message
		message_label.visible = true
		GameState.pending_message = ""
		await get_tree().create_timer(4.0).timeout
		message_label.visible = false

func _build_walls(floor_data) -> void:
	var shared_shape := RectangleShape2D.new()
	shared_shape.size = Vector2(FloorGenerator.CELL_SIZE, FloorGenerator.CELL_SIZE)
	for y in FloorGenerator.GRID_HEIGHT:
		for x in FloorGenerator.GRID_WIDTH:
			var cell := Vector2i(x, y)
			if not floor_data.floor_cells.has(cell):
				var wall := StaticBody2D.new()
				var shape := CollisionShape2D.new()
				shape.shape = shared_shape
				wall.add_child(shape)
				wall.position = _cell_to_world(cell)
				generated_root.add_child(wall)

func _spawn_floor_exit(floor_data) -> void:
	var exit: Area2D = FloorExitScene.instantiate()
	exit.position = _cell_to_world(floor_data.exit_cell)
	generated_root.add_child(exit)

	if GameState.floor_index == 0 and GameState.negative_dive_available:
		var descent: Area2D = FloorExitScene.instantiate()
		descent.force_descend = true
		descent.position = _cell_to_world(floor_data.secondary_cell)
		generated_root.add_child(descent)

func _cell_to_world(cell: Vector2i) -> Vector2:
	var half := FloorGenerator.CELL_SIZE / 2.0
	return Vector2(cell.x * FloorGenerator.CELL_SIZE + half, cell.y * FloorGenerator.CELL_SIZE + half)

func _on_encounter_timer_timeout() -> void:
	if player.frozen or player.velocity.length() < 10.0:
		return
	if randf() < ENCOUNTER_CHANCE:
		_trigger_encounter()

func _trigger_encounter() -> void:
	player.frozen = true
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 1.0, 0.08)
	tween.tween_property(flash, "modulate:a", 0.0, 0.4)
	await tween.finished
	GameState.return_position = player.global_position
	SceneTransition.change_scene("res://scenes/combat/CombatArena.tscn")
