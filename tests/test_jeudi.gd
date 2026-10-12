# Lancer : godot --headless --path . --script res://tests/test_jeudi.gd
# Bestiaire du jeudi (Frustration) : verification commune + mecaniques propres.
extends "res://tests/bestiary_check.gd"

func _init() -> void:
	night = "jeudi"

func check_specific(a: Node) -> void:
	# Grogne : s'enerve a chaque coup ; achevee avant la fin de la meche, pas d'explosion.
	var grumble = spawn(a, "jeudi/grogne")
	await process_frame
	var speed: float = grumble.chase_speed
	for i in 3:
		grumble.take_hit(1)
	assert(grumble.chase_speed > speed and grumble.fuse > 0.0)
	var blast = grumble.blast_zone
	grumble.take_hit(10)
	await process_frame
	assert(not is_instance_valid(blast) or blast.is_queued_for_deletion())
	await clear_mobs()

	# Porte Close : un coup de face rebondit, un coup de dos porte.
	var door = spawn(a, "jeudi/porte_close")
	await process_frame
	var hp: int = door.hp
	door.facing = (a.player.global_position - door.global_position).normalized()
	door.take_hit(1)
	assert(door.hp == hp)
	door.facing = -door.facing
	door.take_hit(1)
	assert(door.hp == hp - 1)
	await clear_mobs()

	# Cocotte-minute : chaque coup fait baisser la pression.
	var pot = spawn(a, "jeudi/cocotte")
	await process_frame
	pot.pressure = 0.8
	pot.take_hit(1)
	assert(pot.pressure < 0.8)
	await clear_mobs()

	# La Colere, phase 3 : frapper pendant une bourrasque la soigne.
	var storm = spawn(a, "jeudi/colere")
	await process_frame
	storm.take_hit(int(storm.max_hp * 0.7))
	assert(storm.phase == 3)
	storm.gust = true
	hp = storm.hp
	storm.take_hit(1)
	assert(storm.hp > hp)
