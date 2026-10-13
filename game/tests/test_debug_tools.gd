extends SceneTree
var globals: Node
var debug: Node
var save_before: PackedByteArray
var settings_before: PackedByteArray

func _init() -> void:
	call_deferred("run")

func unchanged() -> void:
	assert(FileAccess.get_file_as_bytes(globals.SAVE_PATH) == save_before)
	assert(FileAccess.get_file_as_bytes(globals.SETTINGS_PATH) == settings_before)

func show_scene(path: String) -> Node:
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	var scene = load(path).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	return scene

func run() -> void:
	globals = root.get_node("Global")
	debug = root.get_node("DebugTools")
	assert(globals.SAVE_PATH == "res://verification_save.cfg" and globals.SETTINGS_PATH == "res://verification_settings.cfg")
	var gates := [[true, true, false, true], [true, false, true, true], [true, false, false, false], [false, false, false, false], [false, false, true, false], [false, true, false, false]]
	for gate in gates: assert(debug.build_allowed(gate[0], gate[1], gate[2]) == gate[3])
	assert(debug.is_allowed() and not debug.is_active())
	globals.is_first_launch = false
	globals.tech_points = 90
	globals.upgrade_levels = {"hp": 0, "parry_window": 0, "cooldown": 0, "shot_power": 0, "capture_power": 0}
	globals.unlocked_stages = [1, 2]
	globals.cleared_stages = [1]
	globals.window_scale = 0.6
	globals.hard_mode_enabled = false
	globals.counter_only_mode_enabled = false
	for key in globals.tutorial_flags: globals.tutorial_flags[key] = true
	globals.save_game(2, 13)
	globals.save_settings()
	save_before = FileAccess.get_file_as_bytes(globals.SAVE_PATH)
	settings_before = FileAccess.get_file_as_bytes(globals.SETTINGS_PATH)
	assert(not debug.add_tp() and not debug.unlock_all() and not debug.fill_counter() and not debug.set_infinite_hp(true))
	globals.reset_upgrade_levels()
	assert(globals.tech_points == 90)
	var menu = await show_scene("res://game/core/main_menu.tscn")
	for aspect in [0, 1, 2]:
		globals.aspect_ratio = aspect
		menu.sync_settings_to_ui()
		assert(menu.scale_option.get_item_text(menu.scale_option.selected) == "60%")
	var pause = load("res://game/ui/components/pause_settings_panel.tscn").instantiate()
	root.add_child(pause)
	await process_frame
	assert(pause.window_scale.get_item_text(pause.window_scale.selected) == "60%")
	pause.queue_free()
	globals.aspect_ratio = 0
	menu.currently_rebinding_action = "shield"
	assert(not debug.open_panel())
	menu.currently_rebinding_action = ""
	var saved_key: int = globals.key_shield
	globals.key_shield = KEY_F10
	assert(not debug.open_panel())
	globals.key_shield = saved_key
	menu._on_reset_btn_pressed()
	assert(menu.confirm_dialog.visible and not debug.open_panel())
	menu.confirm_dialog.hide()
	assert(debug.open_panel() and paused and not debug.is_active())
	assert(debug.begin_session() and menu.reset_btn.disabled)
	assert(debug.add_tp() and debug.unlock_all())
	assert(globals.tech_points == 190 and globals.unlocked_stages == [1, 2, 3, 4, 5])
	globals.upgrade_levels.shot_power = 3
	globals.shield_radius_upgrades.counter = 4
	globals.just_guard_focus_mode = 2
	globals.counter_system_duration_lvl = 3
	globals.counter_system_power_lvl = 4
	assert(debug.reset_temporary_data("upgrades"))
	assert(globals.upgrade_levels.shot_power == 0 and globals.shield_radius_upgrades.counter == 0)
	assert(globals.just_guard_focus_mode == 0 and globals.counter_system_duration_lvl == 0 and globals.counter_system_power_lvl == 0)
	assert(debug.notice.text.contains("主兵装/捕獲威力") and debug.notice.text.contains("COUNTER持続/威力"))
	globals.save_game(4, 25)
	globals.save_settings()
	assert(globals.load_game_data().stage_num == 4 and globals.tech_points == 190)
	unchanged()
	debug.close_panel()
	assert(not paused)
	var main = await show_scene("res://game/main.tscn")
	var gm = main.get_node("GameManager")
	var player = main.get_node("Player")
	gm.set_process(false)
	player.set_process(false)
	player.capture_volley.set_process(false)
	assert(gm.current_stage_num == 4 and not debug.fill_counter())
	assert(not debug.reset_temporary_data("upgrades"))
	assert(debug.set_infinite_hp(true))
	player.take_damage(20, true)
	assert(player.current_hp == player.max_hp and player.is_overheated and player.is_invincible)
	debug.set_infinite_hp(false)
	player.is_invincible = false
	player.take_damage(20)
	assert(player.current_hp < player.max_hp)
	player.reset_state()
	gm.start_wave(0) # Exercise the debug jump from the road, after the intro.
	player.capture_volley.store("straight", 20, player.global_position, Color.CYAN)
	var bullet = gm.bullet_pool.get_bullet("straight")
	bullet.global_position = player.global_position + Vector2(100, 0)
	player.activate_counter_system(2.0)
	var generation: int = gm.stage_generation
	gm.schedule_stage(0.03, func(): gm.spawn_drone("straight", Vector2(80, 80)))
	assert(debug.jump_to_boss())
	assert(gm.current_state == gm.State.BOSS and gm.stage_generation > generation)
	assert(player.capture_volley.shots.is_empty() and not player.is_full_burst)
	assert(gm.bullet_pool.active_bullets.is_empty() and player.counter_system_turrets.is_empty())
	await create_timer(0.06, false).timeout
	assert(gm.spawned_drones.is_empty())
	assert(debug.fill_counter() and gm.counter_system.is_ready())
	gm.request_counter_activation()
	assert(gm.counter_system.phase == CounterSystem.Phase.ACTIVE and not debug.fill_counter())
	gm.counter_system._process(99.0)
	assert(gm.counter_system.phase == CounterSystem.Phase.SPENT and not debug.fill_counter())
	assert(not debug.jump_to_boss())
	player.is_invincible = false
	player.take_damage(100000)
	gm.check_win_lose()
	assert(gm.current_state == gm.State.DEFEAT and not debug.open_panel())
	gm.restart()
	await process_frame
	await process_frame
	await process_frame
	main = current_scene
	gm = main.get_node("GameManager")
	gm.set_process(false)
	assert(debug.is_active() and gm.current_stage_num == 4)
	gm.clean_stage_entities()
	assert(globals.begin_practice({"kind": "boss", "stage": 1, "infinite_hp": true}))
	main = await show_scene("res://game/main.tscn")
	gm = main.get_node("GameManager")
	gm.set_process(false)
	assert(globals.practice_active and debug.is_active())
	debug.end_session()
	await process_frame
	await process_frame
	await process_frame
	assert(not debug.is_active() and not globals.practice_active and not paused)
	assert(current_scene.has_method("sync_settings_to_ui") and globals.tech_points == 90 and globals.unlocked_stages == [1, 2])
	unchanged()
	# Reverse nesting: debug starts while practice owns the campaign snapshot.
	assert(globals.begin_practice({"kind": "drone", "drone": "wave", "infinite_hp": true}))
	main = await show_scene("res://game/main.tscn")
	gm = main.get_node("GameManager")
	gm.set_process(false)
	assert(debug.begin_session() and debug.add_tp())
	gm.exit_practice(true)
	await process_frame
	await process_frame
	await process_frame
	assert(debug.is_active() and not globals.practice_active and globals.tech_points == 90)
	debug.end_session()
	await process_frame
	await process_frame
	await process_frame
	unchanged()
	var lab = await show_scene("res://game/core/tech_lab.tscn")
	var original_tp: int = globals.tech_points
	lab._on_demo_pressed()
	assert(not lab.demo_btn.visible and globals.tech_points == original_tp)
	globals.counter_system_duration_lvl = 0
	globals.counter_only_mode_unlocked = true
	globals.counter_only_mode_enabled = true
	lab.update_lab_hud()
	assert(lab.cs_dur_lvl_lbl.text.contains("×1.0") and lab.counter_only_status_lbl.text.contains("選択したCOUNTER兵装"))
	globals.counter_system_duration_lvl = 5
	lab.update_lab_hud()
	assert(lab.cs_dur_lvl_lbl.text == "MAX (×2.0)")
	assert(debug.begin_session())
	lab._on_demo_pressed()
	assert(lab.demo_btn.visible and globals.tech_points == original_tp + 50)
	globals.unlocked_tips.append("tip_guard_basic")
	globals.unread_tips.append("tip_guard_basic")
	var temporary_data: Dictionary = globals.load_game_data()
	assert(temporary_data.unlocked_tips == globals.unlocked_tips and temporary_data.unread_tips == globals.unread_tips)
	unchanged()
	debug.end_session()
	await process_frame
	await process_frame
	assert(globals.tech_points == original_tp and not debug.is_active())
	unchanged()
	print("DEBUG_TOOLS_TEST_OK: build gate, OFF defaults, input conflicts, temporary reset scope, HP feedback, no saved writes, boss cleanup, legal counter fill, defeat/retry, practice nesting, scale labels, duration/ONLY wording")
	quit(0)
