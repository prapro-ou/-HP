extends SceneTree
var globals: Node
var main: Node
var gm: Node
var player: Node

func _init() -> void:
	call_deferred("run")

func prepare(stage: int) -> void:
	gm.load_stage("res://game/stages/stage_%d.tscn" % stage, stage)
	await process_frame
	await process_frame
	gm.stage_generation += 1 # Invalidate the real intro while stepping the runner manually.
	gm.set_process(false)
	player.set_process(false)
	player.capture_volley.set_process(false)
	player.current_hp = 100
	globals.tech_points = 90
	for key in globals.tutorial_flags: globals.tutorial_flags[key] = true
	assert(gm.current_state == gm.State.START and not gm.wave_clock_started)
	gm._process(3.0)
	assert(gm.wave_phase_timer == 60.0)
	gm.start_wave(0)
	freeze_drones()

func freeze_drones() -> void:
	for drone in gm.spawned_drones:
		if is_instance_valid(drone): drone.set_process(false)

func mark_dead() -> void:
	for drone in gm.spawned_drones:
		if is_instance_valid(drone): drone.is_alive = false

func arm_old_shots() -> void:
	gm.spawned_drones[0].shoot()
	player.capture_volley.store("straight", 10, player.position, Color.CYAN)
	gm.schedule_stage(0.02, func(): gm.spawn_drone("straight", Vector2(120, 120)))

func run() -> void:
	globals = root.get_node("Global")
	assert(globals.SAVE_PATH == "res://verification_save.cfg" and globals.SETTINGS_PATH == "res://verification_settings.cfg")
	globals.end_practice()
	globals.is_first_launch = false
	globals.hard_mode_enabled = false
	globals.counter_only_mode_enabled = false
	globals.upgrade_levels = {"hp": 0, "parry_window": 0, "cooldown": 0, "shot_power": 0, "capture_power": 0}
	for key in globals.tutorial_flags: globals.tutorial_flags[key] = true
	globals.save_game(1, 0)
	main = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	gm = main.get_node("GameManager")
	player = main.get_node("Player")
	assert(player.max_hp == 500 and player.invincible_duration == 0.8)
	for stage in range(1, 6):
		await prepare(stage)
		var wave_count: int = gm.current_stage.waves.size()
		var expected_count := 0
		var actual_count := 0
		for wave in gm.current_stage.waves: expected_count += wave.initial_spawns.size()
		for index in wave_count:
			assert(gm.current_state == gm.State.WAVE and gm.current_wave_index == index)
			actual_count += gm.alive_wave_drones()
			mark_dead()
			gm._process(0.01)
			assert(gm.current_state == gm.State.WAVE, "Pending entries must prevent premature completion")
			gm._process(8.0) # Finish the finite scheduled entries, never replenish.
			freeze_drones()
			actual_count += gm.alive_wave_drones()
			assert(gm.pending_wave_spawns.is_empty())
			mark_dead()
			assert(is_instance_valid(gm.spawned_drones.back()), "A death-animation reference may still exist")
			gm._process(0.01)
			var earned: int = mini(index + 1, wave_count - 1)
			assert(globals.tech_points == 90 + earned * 10)
			assert(player.current_hp == 100 + earned * 30)
			if index < wave_count - 1:
				assert(gm.current_state == gm.State.WAVE_TRANSITION)
				gm.update_ui()
				assert(gm.ui.wave_level_label.text == "WAVE %d/%d  次へ" % [index + 2, wave_count])
				var clock: float = gm.wave_phase_timer
				gm._process(0.2)
				assert(is_equal_approx(gm.wave_phase_timer, clock - 0.2))
				assert(globals.tech_points == 90 + earned * 10)
				gm._process(0.46)
				freeze_drones()
		assert(actual_count == expected_count and gm.current_state == gm.State.INTERLUDE)
		assert(gm.wave_phase_timer > 0 and gm.pending_wave_spawns.is_empty())
		var stopped_clock: float = gm.wave_phase_timer
		gm._process(2.01)
		assert(gm.current_state == gm.State.BOSS and gm.wave_phase_timer == stopped_clock)
		gm.counter_system.register_parry(1)
		var gauge: float = gm.counter_system.gauge
		gm.start_boss_battle()
		assert(gm.counter_system.gauge == gauge, "Duplicate boss entry must not reset the fight")
		print("FINITE_EARLY_CHECK ", JSON.stringify({"stage": stage, "waves": wave_count, "spawns": actual_count, "bonuses": gm.rewarded_wave_indices.size(), "stepped_seconds": 60.0 - stopped_clock}))
		for only in [false, true]:
			globals.counter_only_mode_enabled = only
			await prepare(stage)
			gm._process(59.99)
			freeze_drones()
			assert(gm.current_state == gm.State.WAVE and gm.alive_wave_drones() > 0)
			assert(gm.counter_system.phase == CounterSystem.Phase.DISABLED)
			gm._process(0.02)
			assert(gm.current_state == gm.State.INTERLUDE and gm.wave_phase_timer == 0)
			assert(globals.tech_points == 90 and gm.pending_wave_spawns.is_empty() and gm.spawned_drones.is_empty())
			gm._process(2.01)
			assert(gm.current_state == gm.State.BOSS)
			print("FINITE_TIMEOUT_CHECK stage=", stage, " only=", only)
		globals.counter_only_mode_enabled = false
		await prepare(stage)
		paused = true
		var pending: int = gm.pending_wave_spawns.size()
		gm._process(5.0)
		await create_timer(0.03, true).timeout
		assert(gm.wave_phase_timer == 60.0 and gm.pending_wave_spawns.size() == pending)
		paused = false
		gm.ui.show_tutorial_guide_modal("time_limit")
		assert(paused)
		gm._process(5.0)
		assert(gm.wave_phase_timer == 60.0)
		paused = false
		if gm.ui.has_node("TutorialGuideModal"): gm.ui.get_node("TutorialGuideModal").queue_free()
		gm.pending_wave_spawns.clear()
		mark_dead()
		gm.wave_phase_timer = 0.01
		gm._process(0.01)
		gm._process(0.0)
		assert(gm.current_state == gm.State.INTERLUDE and globals.tech_points == 90)
		await prepare(stage)
		gm.pending_wave_spawns.clear()
		mark_dead()
		gm._process(0.01)
		assert(globals.tech_points == 100)
		gm.wave_phase_timer = 0.01
		gm._process(0.02)
		assert(gm.current_state == gm.State.INTERLUDE and globals.tech_points == 100 and gm.spawned_drones.is_empty())
	# Clear reservations and attack timers on defeat, cleanup, jump and retry.
	for action in ["defeat", "cleanup", "debug_jump"]:
		await prepare(1)
		arm_old_shots()
		if action == "defeat":
			player.current_hp = 0
			gm._process(0.01)
		elif action == "cleanup":
			gm.clean_stage_entities()
		else:
			assert(root.get_node("DebugTools").begin_session())
			assert(gm.debug_jump_to_boss())
		paused = false # Advance queued attack timers after the defeat screen has paused.
		await create_timer(0.24, false).timeout
		assert(gm.pending_wave_spawns.is_empty() and gm.spawned_drones.is_empty())
		assert(player.capture_volley.shots.is_empty() and main.get_node("BulletPool").active_bullets.is_empty())
		if action == "debug_jump":
			root.get_node("DebugTools").end_session()
			await process_frame
			await process_frame
			main = load("res://game/main.tscn").instantiate()
			root.add_child(main)
			current_scene = main
			await process_frame
			await process_frame
			gm = main.get_node("GameManager")
			player = main.get_node("Player")
	await prepare(2)
	arm_old_shots()
	gm.restart()
	await process_frame
	await process_frame
	await process_frame
	gm = current_scene.get_node("GameManager")
	assert(gm.current_stage_num == 2 and gm.wave_phase_timer == 60.0 and gm.pending_wave_spawns.is_empty())
	gm.clean_stage_entities()
	current_scene.get_node("UI").leave_campaign_to_stage_selection()
	await process_frame
	await process_frame
	await create_timer(0.25, false).timeout
	assert(current_scene.has_method("update_stage_selection"))
	assert(get_nodes_in_group("drones").is_empty() and get_nodes_in_group("enemy_projectiles").is_empty())
	# Real intro timer must also stop during the initial explanation, even after 3.8 wall seconds.
	globals.tutorial_flags.controls = false
	globals.save_game(1, 0)
	change_scene_to_packed(load("res://game/main.tscn"))
	await process_frame
	await process_frame
	main = current_scene
	gm = main.get_node("GameManager")
	player = main.get_node("Player")
	await create_timer(0.75, true).timeout
	assert(paused and gm.current_state == gm.State.START and gm.wave_phase_timer == 60.0)
	await create_timer(4.0, true).timeout
	assert(not gm.wave_clock_started and gm.pending_wave_spawns.is_empty())
	var resume_button = gm.ui.get_node("TutorialGuideModal").find_children("*", "Button", true, false)[0]
	resume_button.pressed.emit()
	await create_timer(3.3, false).timeout
	assert(gm.current_state == gm.State.WAVE and gm.wave_clock_started)
	assert(gm.wave_phase_timer > 59.0 and gm.wave_phase_timer < 60.0)
	gm.set_process(false)
	player.set_process(false)
	arm_old_shots()
	gm.ui.leave_campaign_to_main_menu()
	await process_frame
	await process_frame
	await create_timer(0.25, false).timeout
	assert(current_scene.has_method("sync_settings_to_ui"))
	assert(get_nodes_in_group("drones").is_empty() and get_nodes_in_group("enemy_projectiles").is_empty())
	print("FINITE_INTRO_EXIT_CHECK real_intro_pause_and_main_menu_cleanup")
	print("FINITE_WAVES_TEST_OK: five stages, finite entries, early clear, time cap, gap clock, paused/tutorial clock, single bonuses/entry, ONLY, defeat/cleanup/jump/retry reservations")
	quit(0)
