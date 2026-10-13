extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var globals = root.get_node("Global")
	assert(globals.SAVE_PATH == "res://verification_save.cfg" and globals.SETTINGS_PATH == "res://verification_settings.cfg")
	assert(not FileAccess.file_exists(globals.SAVE_PATH))
	globals.check_save_game()
	var data: Dictionary = globals.load_game_data()
	assert(not globals.has_save and not globals.is_continue and globals.is_first_launch)
	assert(data.stage_num == 1 and data.score == 0 and data.tech_points == 0 and data.weapons.is_empty())
	assert(globals.unlocked_stages == [1] and globals.cleared_stages.is_empty())
	assert(globals.unlocked_counter_weapons == ["turret", "funnel"] and globals.equipped_counter_weapon == "turret")
	assert(not globals.counter_only_mode_unlocked and not globals.counter_only_mode_enabled and not globals.hard_mode_enabled)
	assert(globals.discovered_analysis_weapons.is_empty() and globals.unlocked_tips == ["tip_move", "tip_shoot"])
	assert(globals.window_scale == 0.6 and globals.key_shield == KEY_SHIFT)
	assert(FileAccess.get_file_as_string("res://reset_unrelated.txt") == "unrelated sentinel")
	assert(FileAccess.get_file_as_string("res://savegame.cfg") == "legacy filename is not the current save")
	var menu = load("res://game/core/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	menu._on_play_start_pressed()
	assert(menu.tutorial_dialog.visible and menu.play_start_btn.text == "出撃開始")
	print("SAVE_RESET_RESTART_TEST_OK: fresh process cannot resurrect progression; settings/side files and first-launch menu preserved")
	quit(0)
