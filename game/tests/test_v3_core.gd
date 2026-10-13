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
	globals.counter_only_mode_enabled = false
	for flag in globals.tutorial_flags:
		globals.tutorial_flags[flag] = true
	var counter := CounterSystem.new()
	root.add_child(counter)
	counter.begin_battle()
	for streak in range(1, 5):
		counter.register_parry(streak)
	assert(counter.is_ready(), "Four boss parries should ready COUNTER")
	assert(counter.try_activate(), "A ready COUNTER must activate")
	assert(not counter.is_ready(), "COUNTER activation must consume the gauge")

	var main_scene := load("res://game/main.tscn") as PackedScene
	assert(main_scene != null, "Vertical-slice scene must load")
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	assert(main.get_node_or_null("GameManager/CounterSystem") != null)
	assert(main.get_node_or_null("LoadoutDraft") == null)
	var manager = main.get_node("GameManager")
	var player = main.get_node("Player")
	assert(player.is_attack_unlocked and player.capture_volley != null)
	manager.start_boss_battle()
	for streak in range(1, 5):
		manager._on_parry_succeeded("boss_laser", Vector2.ZERO, streak)
	assert(manager.counter_system.is_ready(), "Boss parries must feed CounterSystem")
	manager.request_counter_activation()
	assert(player.is_full_burst, "A full gauge must launch the equipped COUNTER")
	print("V3_CORE_TEST_OK")
	quit(0)
