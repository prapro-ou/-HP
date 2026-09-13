extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var analysis := AnalysisSystem.new()
	analysis.weapons = [
		load("res://game/data/analysis/rapid.tres"),
		load("res://game/data/analysis/spread.tres"),
		load("res://game/data/analysis/pierce.tres"),
	]
	root.add_child(analysis)
	for streak in range(1, 5):
		analysis.register_parry("straight", streak)
	assert(analysis.completed.has(&"rapid"), "Four accurate parries should decode RAPID")
	assert(analysis.ensure_minimum_choices(2).size() >= 2, "Draft must always offer two choices")

	var counter := CounterSystem.new()
	root.add_child(counter)
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
	assert(main.get_node_or_null("GameManager/AnalysisSystem") != null)
	assert(main.get_node_or_null("GameManager/CounterSystem") != null)
	assert(main.get_node_or_null("LoadoutDraft") != null)
	var manager = main.get_node("GameManager")
	var player = main.get_node("Player")
	manager.current_state = manager.State.WAVE
	for streak in range(1, 5):
		manager._on_parry_succeeded("straight", Vector2.ZERO, streak)
	assert(player.analysis_patterns["rapid"]["analyzed"], "Wave parries must feed AnalysisSystem")
	var selected: Array[StringName] = [&"rapid", &"spread"]
	manager._on_loadout_confirmed(selected)
	assert(player.active_traits == ["rapid", "spread"], "Draft selection must lock exactly two traits")
	assert(manager.current_state == manager.State.BOSS, "Confirming the draft must start the boss phase")
	for streak in range(1, 5):
		manager._on_parry_succeeded("boss_laser", Vector2.ZERO, streak)
	assert(manager.counter_system.is_ready(), "Boss parries must feed CounterSystem")
	manager.request_counter_activation()
	assert(player.is_full_burst, "A full gauge must launch the equipped COUNTER")
	print("V3_CORE_TEST_OK")
	quit(0)
