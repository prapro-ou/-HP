extends SceneTree
## Campaign fixtures use a separated save and unchanged initial weapon/enemy stats.
var globals: Node
var debug: Node
var main: Node
var gm: Node
var player: Node
var save_before: PackedByteArray

func _init() -> void:
	call_deferred("run")

func setup_fixture() -> void:
	globals = root.get_node("Global")
	debug = root.get_node("DebugTools")
	assert(globals.SAVE_PATH == "res://verification_save.cfg")
	globals.is_first_launch = false
	globals.hard_mode_enabled = false
	globals.counter_only_mode_enabled = false
	globals.equipped_weapon = "machine_gun"
	globals.equipped_shield = "counter"
	globals.upgrade_levels = {"hp": 0, "parry_window": 0, "cooldown": 0, "shot_power": 0, "capture_power": 0}
	globals.shield_radius_upgrades = {"counter": 0, "gauge": 0, "power": 0}
	globals.just_guard_focus_mode = 0
	for key in globals.tutorial_flags: globals.tutorial_flags[key] = true
	globals.save_game(1, 0)
	save_before = FileAccess.get_file_as_bytes(globals.SAVE_PATH)
	assert(debug.begin_session() and debug.set_infinite_hp(true))
	root.content_scale_size = Vector2i(800, 1200)
	main = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	gm = main.get_node("GameManager")
	player = main.get_node("Player")
	assert(player.max_hp == 500)

func prepare(stage: int, wave: int, weapon: String = "machine_gun", spawn_all: bool = false) -> void:
	globals.equipped_weapon = weapon
	gm.load_stage("res://game/stages/stage_%d.tscn" % stage, stage)
	await process_frame
	await process_frame
	gm.stage_generation += 1 # Skip only the intro, not drone motion/shot timers/physics.
	gm.set_process(false)
	player.set_process(false)
	player.global_position = Vector2(400, 780)
	gm.start_wave(wave)
	if spawn_all:
		gm.wave_elapsed = 8.0
		gm.spawn_due_wave_drones()

func finish_fixture() -> void:
	gm.clean_stage_entities()
	assert(FileAccess.get_file_as_bytes(globals.SAVE_PATH) == save_before)
	debug.end_session()
	await process_frame
	await process_frame
	assert(FileAccess.get_file_as_bytes(globals.SAVE_PATH) == save_before)

func run() -> void:
	assert(false, "Use a concrete wave test")
