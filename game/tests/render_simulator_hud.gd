extends SceneTree

const OUTPUT: String = "res://rendered_simulator"
var globals: Node
var main: Node
var manager: Node
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

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	assert(picture.save_png(OUTPUT + "/" + name + ".png") == OK)
	print("RENDER_CHECK ", name, " ", picture.get_size())

func open_practice() -> void:
	globals.cleared_stages = [1, 2, 3, 4, 5]
	globals.equipped_shield = "power"
	globals.counter_only_mode_enabled = false
	globals.just_guard_focus_mode = 0
	assert(globals.begin_practice({"kind": "boss", "stage": 1, "infinite_hp": true, "intense": false}))
	main = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	manager = main.get_node("GameManager")
	player = main.get_node("Player")
	ui = main.get_node("UI")
	manager.set_process(false)
	player.set_process(false)
	player.capture_volley.set_process(false)
	manager.boss.set_process(false)
	manager.boss.hide()
	for enemy in get_nodes_in_group("enemy"):
		enemy.set_process(false)
		if enemy != manager.boss: enemy.hide()
	if ui.has_node("PracticeHint"): ui.get_node("PracticeHint").queue_free()
	await create_timer(0.65, false).timeout

func run() -> void:
	globals = root.get_node("Global")
	assert(globals.SAVE_PATH == "res://verification_save.cfg")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	globals.cleared_stages = [1, 2, 3, 4, 5]
	globals.counter_only_mode_enabled = false
	globals.just_guard_focus_mode = 0
	globals.equipped_shield = "power"
	globals.equipped_counter_weapon = "turret"
	for width in [675, 800, 900]:
		await set_size(width)
		var setup = load("res://game/core/practice_setup.tscn").instantiate()
		root.add_child(setup)
		current_scene = setup
		await capture("setup_%d" % width)
		setup.queue_free()
		await process_frame
		var menu = load("res://game/core/main_menu.tscn").instantiate()
		root.add_child(menu)
		current_scene = menu
		menu._on_settings_pressed()
		await set_size(width)
		await create_timer(0.3, false).timeout
		await capture("options_%d" % width)
		menu.queue_free()
		await process_frame
		await open_practice()
		await set_size(width)
		ui.layout_combat_hud()
		player.global_position = Vector2(width * 0.5, 770)
		# Actual new textures and unchanged hit circles, on a real stage background.
		for i in range(3):
			var kind: String = ["straight", "wave", "charge"][i]
			var drone = manager.spawn_drone(kind, Vector2(width * (0.25 + i * 0.25), 340))
			drone.set_process(false)
			if kind == "charge":
				drone.is_charging = true
				drone.charge_timer = 0.04
				drone.queue_redraw()
			var label := Label.new()
			label.text = kind.to_upper()
			label.add_theme_font_override("font", globals.get_readable_font())
			label.add_theme_font_size_override("font_size", 18)
			label.position = Vector2(-40, -64)
			drone.add_child(label)
		manager.current_state = manager.State.WAVE
		manager.update_ui()
		assert(ui.capture_label.text == "CAPTURE  0 / 12" and not ui.capture_detail.visible)
		assert(not ui.v3_counter_panel.visible or manager.counter_system.phase != CounterSystem.Phase.DISABLED)
		ui.update_v3_counter_status(CounterSystem.Phase.DISABLED, 0)
		await capture("wave_%d" % width)
		manager.current_state = manager.State.BOSS
		player.is_guarding = true
		player.power_boost_remaining = 1.8
		player.precision_flash_remaining = 0.35
		player.queue_redraw()
		player.capture_volley.store("straight", 20, player.global_position, Color.CYAN, 1.0, false)
		player.capture_volley.store("wave", 20, player.global_position, Color.CYAN, 1.25, true)
		player.capture_volley._process(0.27)
		manager.update_ui()
		globals.key_counter_system = KEY_BACKSPACE
		globals.key_shield = KEY_BACKSPACE
		ui.update_v3_counter_status(CounterSystem.Phase.READY, 100)
		ui.update_guard_heat(40, 100, false, 0, true, "power")
		var font: Font = ui.v3_counter_label.label_settings.font
		var text_width: float = font.get_string_size(ui.v3_counter_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		assert(text_width + 4.0 <= 196.0, "Ready text is wider than its card")
		assert(ui.guard_status_label.text == "SHIELD 展開中" and ui.boost_label.visible)
		await capture("ready_precision_boost_%d" % width)
		manager.counter_system.remaining = 8.2
		ui.update_v3_counter_status(CounterSystem.Phase.ACTIVE, 0)
		ui.show_top_unparryable_warning(1.0)
		await create_timer(0.3, false).timeout
		await capture("active_warning_%d" % width)
		ui.update_guard_heat(0, 100, false, 0, false, "counter")
		await capture("key_ready_%d" % width)
		root.size = Vector2i(int(width * 0.6), 720)
		await capture("combat_60pct_%d" % width)
		root.size = Vector2i(width, 1200)
		await process_frame
		ui.toggle_pause_menu()
		await capture("pause_%d" % width)
		paused = false
		manager.clean_stage_entities()
		main.queue_free()
		await process_frame
		globals.end_practice()
	print("SIMULATOR_HUD_RENDER_TEST_OK")
	quit(0)
