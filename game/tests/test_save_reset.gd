extends SceneTree
const PROGRESS_KEYS := ["is_continue", "has_save", "is_first_launch", "tech_points", "equipped_weapon", "equipped_shield", "equipped_counter_weapon", "unlocked_shields", "unlocked_weapons", "unlocked_counter_weapons", "unlocked_stages", "cleared_stages", "discovered_analysis_weapons", "upgrade_levels", "shield_radius_upgrades", "just_guard_focus_mode", "counter_system_duration_lvl", "counter_system_power_lvl", "stage5_clears_count", "counter_only_mode_unlocked", "counter_only_mode_enabled", "hard_mode_enabled", "unlocked_tips", "unread_tips", "tutorial_flags"]
var globals: Node
var defaults: Dictionary
var menu: Node
var settings_before: PackedByteArray
const UNRELATED := "res://reset_unrelated.txt"
const LEGACY := "res://savegame.cfg"

func _init() -> void:
	call_deferred("run")

func snapshot(node: Node) -> Dictionary:
	var result: Dictionary = {}
	for key in PROGRESS_KEYS: result[key] = node.get(key)
	return result.duplicate(true)

func initial() -> void:
	assert(snapshot(globals) == defaults, "Every persisted progression field must match a fresh game")
	var data: Dictionary = globals.load_game_data()
	assert(data.stage_num == 1 and data.score == 0 and data.weapons.is_empty())
	assert(snapshot(globals) == defaults)

func seed_progress(write: bool = true) -> void:
	globals.is_continue = true
	globals.has_save = true
	globals.is_first_launch = false
	globals.tech_points = 900
	globals.equipped_weapon = "plasma_emitter"
	globals.equipped_shield = "power"
	globals.equipped_counter_weapon = "boss_beam"
	globals.unlocked_weapons = ["machine_gun", "burst_rifle", "pulse_gun", "plasma_emitter", "kinetic_tackle"]
	globals.unlocked_shields = ["counter", "gauge", "power"]
	globals.unlocked_counter_weapons = ["turret", "funnel", "boss_beam"]
	globals.unlocked_stages = [1, 2, 3, 4, 5]
	globals.cleared_stages = [1, 2, 3, 4, 5]
	globals.discovered_analysis_weapons = ["straight", "laser", "meteor"]
	for key in globals.upgrade_levels: globals.upgrade_levels[key] = 5
	for key in globals.shield_radius_upgrades: globals.shield_radius_upgrades[key] = 5
	globals.just_guard_focus_mode = 2
	globals.counter_system_duration_lvl = 5
	globals.counter_system_power_lvl = 5
	globals.stage5_clears_count = 9
	globals.counter_only_mode_unlocked = true
	globals.counter_only_mode_enabled = true
	globals.hard_mode_enabled = true
	globals.unlocked_tips = ["tip_move", "tip_shoot", "tip_wave_route"]
	globals.unread_tips = ["tip_wave_route"]
	for key in globals.tutorial_flags: globals.tutorial_flags[key] = true
	if write: globals.save_game(5, 12345, {"legacy_payload": {"level": 4}})

func side_files_unchanged() -> void:
	assert(FileAccess.get_file_as_bytes(globals.SETTINGS_PATH) == settings_before)
	assert(FileAccess.get_file_as_string(UNRELATED) == "unrelated sentinel")
	assert(FileAccess.get_file_as_string(LEGACY) == "legacy filename is not the current save")

func run() -> void:
	globals = root.get_node("Global")
	assert(globals.SAVE_PATH == "res://verification_save.cfg" and globals.SETTINGS_PATH == "res://verification_settings.cfg")
	var fresh = globals.get_script().new()
	defaults = snapshot(fresh)
	fresh.free()
	globals.window_scale = 0.6
	globals.key_shield = KEY_SHIFT
	globals.save_settings()
	settings_before = FileAccess.get_file_as_bytes(globals.SETTINGS_PATH)
	var unrelated = FileAccess.open(UNRELATED, FileAccess.WRITE)
	unrelated.store_string("unrelated sentinel")
	unrelated.close()
	var legacy = FileAccess.open(LEGACY, FileAccess.WRITE)
	legacy.store_string("legacy filename is not the current save")
	legacy.close()
	seed_progress()
	menu = load("res://game/core/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	var before := snapshot(globals)
	var disk_before := FileAccess.get_file_as_bytes(globals.SAVE_PATH)
	menu._on_reset_btn_pressed()
	assert(menu.confirm_dialog.visible)
	menu.confirm_dialog.find_children("*", "Button", true, false)[1].pressed.emit()
	assert(not menu.confirm_dialog.visible and snapshot(globals) == before)
	assert(FileAccess.get_file_as_bytes(globals.SAVE_PATH) == disk_before)
	menu._on_reset_btn_pressed()
	menu._on_delete_confirm_pressed()
	assert(not menu.confirm_dialog.visible and not FileAccess.file_exists(globals.SAVE_PATH))
	initial()
	assert(globals.window_scale == 0.6 and globals.key_shield == KEY_SHIFT)
	side_files_unchanged()
	# An actual open Windows file blocks deletion: preserve disk/memory and show failure.
	seed_progress()
	before = snapshot(globals)
	disk_before = FileAccess.get_file_as_bytes(globals.SAVE_PATH)
	var held_save = FileAccess.open(globals.SAVE_PATH, FileAccess.READ)
	assert(held_save != null)
	menu._on_reset_btn_pressed()
	menu._on_delete_confirm_pressed()
	assert(menu.confirm_dialog.visible and menu.reset_notice.visible and menu.reset_notice.text.contains("保持"))
	assert(snapshot(globals) == before and FileAccess.get_file_as_bytes(globals.SAVE_PATH) == disk_before)
	held_save.close()
	menu._on_delete_confirm_pressed()
	assert(not FileAccess.file_exists(globals.SAVE_PATH))
	initial()
	print("SAVE_RESET_FAILURE_CHECK real_open_file_preserves_progress_and_notice")
	# Missing save is a successful reset; a directory at SAVE_PATH is refused untouched.
	seed_progress(false)
	assert(globals.delete_save_game())
	initial()
	assert(DirAccess.make_dir_absolute(globals.SAVE_PATH) == OK)
	seed_progress(false)
	before = snapshot(globals)
	assert(not globals.delete_save_game() and snapshot(globals) == before)
	assert(DirAccess.dir_exists_absolute(globals.SAVE_PATH))
	assert(DirAccess.remove_absolute(globals.SAVE_PATH) == OK)
	seed_progress()
	disk_before = FileAccess.get_file_as_bytes(globals.SAVE_PATH)
	var debug = root.get_node("DebugTools")
	assert(debug.begin_session())
	before = snapshot(globals)
	assert(not globals.delete_save_game() and snapshot(globals) == before)
	assert(FileAccess.get_file_as_bytes(globals.SAVE_PATH) == disk_before)
	debug.end_session()
	await process_frame
	await process_frame
	assert(globals.begin_practice({"kind": "drone", "drone": "straight", "infinite_hp": true}))
	before = snapshot(globals)
	assert(not globals.delete_save_game() and snapshot(globals) == before)
	assert(FileAccess.get_file_as_bytes(globals.SAVE_PATH) == disk_before)
	globals.end_practice()
	assert(globals.delete_save_game())
	initial()
	menu = current_scene
	menu._on_play_start_pressed()
	assert(menu.tutorial_dialog.visible and not globals.has_save)
	assert(menu.play_start_btn.text == "出撃開始") # The current menu has no separate CONTINUE button.
	change_scene_to_packed(load("res://game/main.tscn"))
	await process_frame
	await process_frame
	var gm = current_scene.get_node("GameManager")
	var player = current_scene.get_node("Player")
	assert(gm.current_stage_num == 1 and gm.wave_phase_timer == 60.0)
	assert(player.max_hp == 500 and player.invincible_duration == 0.8)
	assert(globals.tech_points == 0 and globals.equipped_counter_weapon == "turret")
	assert(globals.unlocked_counter_weapons == ["turret", "funnel"] and globals.cleared_stages.is_empty())
	gm.clean_stage_entities()
	assert(globals.delete_save_game()) # Leave the next, fresh process with no progression save.
	initial()
	side_files_unchanged()
	print("SAVE_RESET_TEST_OK: cancel, current file only, full fresh defaults/reload/new sortie, actual delete failure, no file, directory refusal, debug/practice refusal, settings/unrelated/legacy retained")
	quit(0)
