extends "res://game/tests/wave_test_fixture.gd"

func shield_key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = globals.key_shield
	event.physical_keycode = globals.key_shield
	event.pressed = pressed
	Input.parse_input_event(event)

func check_capture(precise: bool, stage: int = 1) -> void:
	await prepare(stage, 0)
	player.global_position = Vector2(400, 1000)
	player.set_process(true) # Initial MG is always firing; the off-axis patrol is not kept invulnerable.
	gm.set_process(true)
	var target_distance := 40.0 if precise else 76.0
	var pressed := false
	var snapshot: Dictionary = {}
	var emitted := false
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline and not emitted:
		if not pressed:
			for bullet in gm.bullet_pool.active_bullets:
				if is_instance_valid(bullet) and bullet.visible and not bullet.is_friendly:
					var distance: float = bullet.global_position.distance_to(player.global_position)
					if distance <= target_distance and distance > 30.0:
						shield_key(true)
						pressed = true
						break
		if snapshot.is_empty() and not player.capture_volley.shots.is_empty():
			# A real rapid volley can put both outer and inner shots in one guard.
			for shot in player.capture_volley.shots:
				if shot.precision == precise:
					snapshot = shot.duplicate()
					assert(snapshot.source_type in ["straight", "wave", "irregular", "laser", "thunder", "blade", "missile", "vortex", "charge", "meteor"])
					break
			shield_key(false)
		for bullet in main.get_node("PlayerBullets").get_children():
			if bullet.has_meta("captured_kind") and bullet.get_meta("precision_capture") == precise:
				assert(not snapshot.is_empty())
				assert(bullet.damage == snapshot.damage and bullet.get_meta("precision_capture") == snapshot.precision)
				emitted = true
		await process_frame
	shield_key(false)
	assert(pressed and not snapshot.is_empty() and emitted, "Real patrol shots must be captured and auto-released with the initial MG")
	assert(gm.current_state == gm.State.WAVE and gm.counter_system.phase == CounterSystem.Phase.DISABLED)
	print("WAVE_CAPTURE_CHECK stage=", stage, " precise=", precise, " source=", snapshot.source_type, " snapshot_damage=", snapshot.damage, " elapsed=", 60.0 - gm.wave_phase_timer)
	player.set_process(false)
	gm.set_process(false)

func hp_values(actors: Array) -> Array:
	var values: Array = []
	for actor in actors: values.append(actor.current_hp if is_instance_valid(actor) else 0)
	return values

func run() -> void:
	await setup_fixture()
	for stage in range(1, 6): await check_capture(false, stage)
	await check_capture(true)
	# MG: horizontal alignment with a genuinely moving patrol rewards repeated shots.
	await prepare(1, 0)
	await create_timer(2.5, false).timeout
	var single = gm.spawned_drones[0]
	var initial_hp: int = single.current_hp
	player.position.x = single.position.x
	player.set_process(true)
	await create_timer(1.4, false).timeout
	assert(not is_instance_valid(single) or not single.is_alive or single.current_hp < initial_hp)
	player.set_process(false)
	print("WAVE_WEAPON_CHECK moving_single MG hit")
	# Burst: three real projectiles each pierce, reaching the second row of the actual column.
	await prepare(1, 1, "burst_rifle", true)
	await create_timer(2.7, false).timeout
	var column: Array = gm.spawned_drones.duplicate()
	var column_before := hp_values(column)
	player.fire()
	await create_timer(0.7, false).timeout
	var column_after := hp_values(column)
	assert(column_after[0] < column_before[0] and column_after[1] < column_before[1])
	print("WAVE_WEAPON_CHECK column burst before=", column_before, " after=", column_after)
	# Pulse: the first three scheduled spread actors; the later cluster stays pending.
	await prepare(1, 2, "pulse_gun")
	gm.wave_elapsed = 0.6
	gm.spawn_due_wave_drones()
	assert(gm.spawned_drones.size() == 3 and gm.pending_wave_spawns.size() == 3)
	await create_timer(2.3, false).timeout
	var spread: Array = gm.spawned_drones.duplicate()
	var spread_before := hp_values(spread)
	player.fire()
	await create_timer(0.8, false).timeout
	var spread_after := hp_values(spread)
	for index in 3: assert(spread_after[index] < spread_before[index])
	print("WAVE_WEAPON_CHECK spread pulse before=", spread_before, " after=", spread_after)
	# Plasma: one impact creates a real field, damaging neighboring cluster actors over time.
	await prepare(1, 2, "plasma_emitter", true)
	await create_timer(3.5, false).timeout
	var cluster: Array = gm.spawned_drones.slice(3)
	var cluster_before := hp_values(cluster)
	player.fire()
	var seen_field := false
	var deadline := Time.get_ticks_msec() + 1100
	while Time.get_ticks_msec() < deadline:
		if not get_nodes_in_group("plasma_heat_fields").is_empty(): seen_field = true
		await process_frame
	var cluster_after := hp_values(cluster)
	assert(seen_field)
	for index in 3: assert(cluster_after[index] < cluster_before[index])
	print("WAVE_WEAPON_CHECK cluster plasma before=", cluster_before, " after=", cluster_after)
	await finish_fixture()
	print("WAVE_WEAPONS_TEST_OK: real initial-MG patrol capture/precision/auto-release; actual MG, piercing burst, spread pulse and cluster heat collisions; unchanged save")
	quit(0)
