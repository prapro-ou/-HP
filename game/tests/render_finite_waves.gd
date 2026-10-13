extends SceneTree
const OUTPUT := "res://rendered_finite_waves"
var globals: Node
var debug: Node
var main: Node
var gm: Node
var player: Node
var ui: Node

func _init() -> void:
	call_deferred("run")

func set_size(width: int) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(width, 1200)
	root.size = Vector2i(width, 1200)
	await process_frame
	await process_frame

func capture(label: String, width: int) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT + "/%s_%d.png" % [label, width]) == OK)
	print("FINITE_RENDER_CHECK ", label, " ", width)

func spawn_plan(index: int, duration: float) -> void:
	gm.clear_drones()
	gm.clear_all_bullets()
	await process_frame
	gm.start_wave(index)
	gm.wave_elapsed = 8.0
	gm.spawn_due_wave_drones()
	await create_timer(duration, false).timeout
	for drone in gm.spawned_drones: drone.set_process(false)
	for bullet in gm.bullet_pool.active_bullets: bullet.set_process(false)
	gm.update_ui()

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
	assert(debug.begin_session() and debug.set_infinite_hp(true) and debug.unlock_all())
	globals.is_first_launch = false
	globals.hard_mode_enabled = false
	globals.counter_only_mode_enabled = false
	globals.equipped_weapon = "machine_gun"
	globals.equipped_shield = "counter"
	globals.upgrade_levels = {"hp": 0, "parry_window": 0, "cooldown": 0, "shot_power": 0, "capture_power": 0}
	for key in globals.tutorial_flags: globals.tutorial_flags[key] = true
	globals.save_game(1, 0)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for width in [675, 800, 900]:
		await set_size(width)
		main = await show_scene("res://game/main.tscn")
		await set_size(width)
		gm = main.get_node("GameManager")
		player = main.get_node("Player")
		ui = main.get_node("UI")
		gm.set_process(false)
		player.set_process(false)
		player.position = Vector2(width * 0.5, 850)
		await create_timer(0.4, false).timeout
		assert(gm.wave_phase_timer == 60.0 and not gm.wave_clock_started)
		await capture("intro", width)
		gm.stage_generation += 1
		if is_instance_valid(ui.stage_intro_banner): ui.stage_intro_banner.queue_free()
		await spawn_plan(0, 2.5)
		await capture("patrol_hud", width)
		var settings: LabelSettings = ui.wave_level_label.label_settings
		var text_width: float = settings.font.get_string_size(ui.wave_level_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, settings.font_size).x
		assert(text_width + 8.0 <= ui.wave_timer_panel.size.x)
		await spawn_plan(1, 2.7)
		await capture("column", width)
		await spawn_plan(2, 3.5)
		await capture("spread_cluster", width)
		gm.current_wave_index = 1
		gm.current_state = gm.State.WAVE_TRANSITION
		gm.wave_phase_timer = 35.8
		gm.update_ui()
		assert(ui.wave_level_label.text == "WAVE 2/3  次へ")
		await capture("transition", width)
		gm.trigger_interlude()
		await create_timer(0.3, false).timeout
		await capture("warning", width)
		for topic in ["controls", "time_limit"]:
			ui.show_tutorial_guide_modal(topic)
			await capture(topic, width)
			paused = false
			ui.get_node("TutorialGuideModal").queue_free()
			await process_frame
		gm.clean_stage_entities()
		var loadout = await show_scene("res://game/core/loadout_selection.tscn")
		await set_size(width)
		loadout.show_details("primary", "plasma_emitter")
		await capture("loadout", width)
		assert(loadout.desc_panel.get_global_rect().end.y < loadout.deploy_btn.get_global_rect().position.y)
		var selection = await show_scene("res://game/core/stage_selection.tscn")
		await set_size(width)
		globals.unlocked_tips.append("tip_wave_route")
		selection.selected_tip_id = "tip_wave_route"
		selection._on_tips_pressed()
		await create_timer(0.25, false).timeout
		await capture("tips", width)
	debug.end_session()
	await process_frame
	print("FINITE_WAVES_RENDER_TEST_OK: three aspect ratios, intro/HUD/gap/warning/guides/loadout/TIPS; frozen preview states, not human play")
	quit(0)
