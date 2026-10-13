extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var globals = root.get_node("Global")
	if globals.SAVE_PATH != "res://verification_save.cfg" or globals.SETTINGS_PATH != "res://verification_settings.cfg":
		push_error("Run combat tests in an isolated project copy with verification save/settings paths.")
		quit(1)
		return
	globals.is_first_launch = false
	globals.equipped_shield = "counter"
	globals.counter_only_mode_enabled = false
	globals.upgrade_levels = {"hp": 0, "parry_window": 0, "cooldown": 0}
	globals.counter_system_power_lvl = 0
	globals.counter_system_duration_lvl = 0
	for flag in globals.tutorial_flags:
		globals.tutorial_flags[flag] = true
	globals.save_game(1, 0, {})
	var main = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var manager = main.get_node("GameManager")
	var player = main.get_node("Player")
	manager.set_process(false)
	manager.clear_drones()
	manager.current_state = manager.State.BOSS
	manager.boss.show()
	manager.boss.process_mode = Node.PROCESS_MODE_INHERIT
	manager.boss.set_process(false)
	manager.boss.position = Vector2(300, 260)
	manager.boss.current_hp = 1000000
	manager.boss.max_hp = 1000000
	player.is_attack_unlocked = true
	player.global_position = Vector2(300, 650)
	for weapon in WeaponCatalog.PRIMARY:
		globals.equipped_weapon = weapon
		player.apply_equipped_weapon_settings()
		for definition in WeaponCatalog.ANALYSIS_RESOURCES:
			player.capture_volley.store(String(definition.bullet_types[0]), 16, player.global_position, definition.color)
		await create_timer(0.85, false).timeout
		assert(player.capture_volley.shots.is_empty(), "Every primary must automatically release its captured follow-up")
	for kind in WeaponCatalog.COUNTER:
		globals.equipped_counter_weapon = kind
		manager.counter_system.begin_battle()
		for index in range(4):
			manager.counter_system.register_parry(5)
		manager.request_counter_activation()
		await create_timer(0.4, false).timeout
		assert(player.is_full_burst)
		manager.counter_system.reset_run()
		await process_frame
		assert(not player.is_full_burst)
	assert(manager.boss.current_hp < 1000000, "Moving attacks must damage real boss collision areas")
	var core: Area2D = manager.boss.get_node("Core")
	assert(CombatTargets.in_radius(player, core.global_position, 20).has(manager.boss), "Area effects must hit the boss's actual collision areas")
	player.set_process(false)
	globals.aspect_ratio = 2
	globals.window_scale = 1.0
	globals.window_mode = 0
	globals.apply_display()
	globals.save_settings()
	await process_frame
	await process_frame
	player.capture_volley.clear()
	for definition in WeaponCatalog.ANALYSIS_RESOURCES:
		player.capture_volley.store(String(definition.bullet_types[0]), 16, player.global_position, definition.color)
	player.capture_volley.store("straight", 16, player.global_position, Color.BLUE)
	player.capture_volley.store("straight", 16, player.global_position, Color.BLUE)
	var ui = main.get_node("UI")
	ui.update_capture_hud(player.capture_volley.shots, 2.0)
	await process_frame
	assert(ui.get_node("CapturePanel").get_global_rect().end.x <= root.get_visible_rect().size.x, "Full capture HUD must fit the narrow viewport")
	player.global_position = Vector2(20, 20)
	for index in range(CaptureVolley.CAPACITY):
		var point: Vector2 = player.global_position + player.capture_volley.held_position(index)
		assert(point.x >= 12 and point.y >= 12, "Held bullets must remain visible at the screen edge")
	ui.toggle_pause_menu()
	await process_frame
	assert(paused and ui.has_node("PausePanel"), "Capture UI must preserve the integrated pause menu")
	ui.toggle_pause_menu()
	await process_frame
	assert(not paused)
	manager.clean_stage_entities()
	await process_frame
	main.queue_free()
	await process_frame

	# All previously unlocked equipment remains selectable and fits the narrowest viewport.
	globals.unlocked_weapons.assign(WeaponCatalog.PRIMARY.keys())
	globals.unlocked_counter_weapons.assign(WeaponCatalog.COUNTER.keys())
	globals.unlocked_shields.assign(WeaponCatalog.SHIELDS.keys())
	globals.save_game(1, 0, {})
	var loadout = load("res://game/core/loadout_selection.tscn").instantiate()
	root.add_child(loadout)
	await process_frame
	await process_frame
	assert(loadout.primary_weapons.size() == 5 and loadout.counter_weapons.size() == 6)
	for group in [loadout.primary_buttons, loadout.counter_buttons]:
		for button in group.values():
			assert(not button.disabled and button.get_global_rect().end.x <= root.get_visible_rect().size.x)
	assert(loadout.deploy_btn.get_global_rect().end.x <= root.get_visible_rect().size.x)
	loadout.queue_free()
	await process_frame
	print("COMBAT_RUNTIME_TEST_OK: automatic capture follow-ups, real boss hits, six active payloads, narrow capture/pause/loadout layout")
	quit(0)
