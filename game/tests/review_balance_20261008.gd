extends SceneTree
## Review fixture: real projectiles and collision shapes, no player-save access.
## Artificial capture inputs and a stationary, non-attacking boss are explicit.

var results: Dictionary = {"conditions": {"stage": 1, "mode": "NORMAL", "upgrade_level": 0,
	"trial_seconds": 6.0, "captures_at_seconds": [0.0, 3.0], "capture_source_damage": 16,
	"boss_ai": false, "boss_barrier": false, "boss_break": false, "counter_activated": false,
	"player_movement": false, "human_boss_clear_time_measured": false},
	"shooting_trials": [], "range_probes": [], "charge_probes": [], "heat_probes": [],
	"pause_probes": [], "gap_probes": [], "counter_damage_states": []}
var main: Node
var manager: Node
var player: CharacterBody2D
var boss: Node2D
var pool: Node
var globals: Node

func _init() -> void:
	call_deferred("run")

func set_shield_key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = globals.key_shield
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	assert(Input.is_key_pressed(globals.key_shield) == pressed, "Synthetic shield input must reach the actual key state")

func clear_pool() -> void:
	for bullet in pool.active_bullets.duplicate(): pool.return_bullet(bullet)

func clean_attacks() -> void:
	clear_pool()
	player.capture_volley.clear()
	for child in main.get_node("PlayerBullets").get_children(): child.queue_free()
	await process_frame

func step_player(delta: float) -> void:
	# Use the production input/heat/boost path, but schedule firing by simulation time.
	player.is_attack_unlocked = false
	player._process(delta)
	player.is_attack_unlocked = true
	player.capture_volley._process(delta)
	Engine.time_scale = 1.0

func source_at_player() -> void:
	var source = pool.get_bullet("straight")
	source.damage = 16
	source.global_position = player.global_position + Vector2(0, -35)

func reset_fixture(weapon: String, shield: String, core_distance: float) -> void:
	set_shield_key(false)
	globals.equipped_weapon = weapon
	globals.equipped_shield = shield
	player.reset_state()
	player.set_process(false)
	player.capture_volley.set_process(false)
	player.is_invincible = true
	player.invincibility_timer = 9999.0
	player.global_position = boss.core_node.global_position + Vector2(0, core_distance)
	manager.counter_system.begin_battle()
	boss.current_hp = 100000
	boss.max_hp = 100000
	boss.is_break_vulnerable = false
	boss.turrets.clear()

func shooting_trial(weapon: String, shield: String, distance: float) -> void:
	await clean_attacks()
	reset_fixture(weapon, shield, distance)
	var elapsed := 0.0
	var next_fire := 0.0
	var next_capture := 0.0
	var successes_before: int = manager.parry_count
	while elapsed < 6.0:
		var delta := root.get_process_delta_time()
		if elapsed >= next_capture and next_capture < 6.0:
			source_at_player()
			set_shield_key(true)
			next_capture += 3.0
		step_player(delta)
		set_shield_key(false)
		if elapsed >= next_fire:
			player.fire()
			next_fire += player.fire_rate
		await process_frame
		elapsed += delta
	# Account for the final volley's flight and the burst rifle's delayed shots.
	await create_timer(0.4, false).timeout
	var damage: int = 100000 - boss.current_hp
	assert(manager.parry_count - successes_before == 2, "A comparison trial must include both scheduled captures")
	var record := {"weapon": weapon, "shield": shield, "core_distance": distance,
		"damage": damage, "damage_per_6_seconds": damage / 6.0,
		"capture_successes": manager.parry_count - successes_before,
		"counter_gauge": manager.counter_system.gauge, "player_damage": null, "player_damage_measured": false,
		"damage_measurement_scope": "stationary boss, no attacks, forced capture inputs; not a gameplay clear"}
	results["shooting_trials"].append(record)
	print("BALANCE_TRIAL ", JSON.stringify(record))

func range_probe(distance: float) -> void:
	await clean_attacks()
	reset_fixture("kinetic_tackle", "counter", distance)
	player.fire()
	await create_timer(0.4, false).timeout
	results["range_probes"].append({"core_distance": distance, "damage": 100000 - boss.current_hp,
		"inside_proximity_trigger": distance <= boss.CLOSE_PROXIMITY_DISTANCE})

func charge_probe(shield: String, cooldown_level: int = 0) -> void:
	await clean_attacks()
	globals.upgrade_levels["cooldown"] = cooldown_level
	reset_fixture("machine_gun", shield, 500.0)
	var interval: float = player.gauge_shield_cooldown if shield == "gauge" else 0.5
	var elapsed := 0.0
	var attempts := 0
	var values: Array = []
	while not manager.counter_system.is_ready() and attempts < 8:
		source_at_player()
		set_shield_key(true)
		step_player(0.0)
		set_shield_key(false)
		step_player(0.0)
		attempts += 1
		values.append(manager.counter_system.gauge)
		player.capture_volley.clear()
		if not manager.counter_system.is_ready():
			step_player(interval)
			elapsed += interval
	results["charge_probes"].append({"shield": shield, "cooldown_level": cooldown_level,
		"attempt_interval": interval, "successes_to_ready": attempts, "seconds_from_first_success": elapsed,
		"gauges": values, "scope": "manual-step perfect inputs; actual enemy availability not measured"})
	assert(manager.counter_system.is_ready(), "The charge fixture must actually activate guards and capture sources")
	globals.upgrade_levels["cooldown"] = 0

func heat_probe(start_heat: float) -> void:
	await clean_attacks()
	reset_fixture("machine_gun", "counter", 500.0)
	player.shield_heat = start_heat
	source_at_player()
	set_shield_key(true)
	step_player(0.0)
	set_shield_key(false)
	results["heat_probes"].append({"start_heat": start_heat, "end_heat": player.shield_heat,
		"is_guarding": player.is_guarding, "overheated": player.is_overheated,
		"held_shots": player.capture_volley.shots.size(), "enemy_shots_remaining": pool.active_bullets.size()})
	step_player(0.0)

func pause_probe(stage_number: int, pattern: String) -> void:
	await clean_attacks()
	manager.load_stage("res://game/stages/stage_%d.tscn" % stage_number, stage_number)
	await process_frame
	await process_frame
	manager.stage_generation += 1
	manager.clear_drones()
	manager.current_state = manager.State.BOSS
	boss = manager.boss
	boss.show()
	boss.process_mode = Node.PROCESS_MODE_INHERIT
	boss.set_process(false)
	boss.is_active = true
	boss.is_alive = true
	boss.position = Vector2(root.get_visible_rect().size.x * 0.5, 360)
	player.set_process(false)
	player.capture_volley.set_process(false)
	player.is_invincible = true
	clear_pool()
	if stage_number == 2:
		boss.attack_pattern_index = 0
		boss.expanded_attack_turn = 0
		boss.execute_fortress_attack()
	elif pattern == "twin": boss.execute_twin_thick_beam_attack(1.0)
	else: boss.execute_sweeping_thick_beam_attack(1.0)
	var count_before: int = pool.active_bullets.size()
	paused = true
	await create_timer(0.8, true, false, true).timeout
	results["pause_probes"].append({"stage": stage_number, "pattern": pattern,
		"shots_before_pause": count_before, "shots_created_while_paused": pool.active_bullets.size() - count_before,
		"paused_seconds": 0.8})
	paused = false
	await process_frame
	await clean_attacks()

func run() -> void:
	globals = root.get_node("Global")
	if globals.SAVE_PATH != "res://verification_save.cfg" or globals.SETTINGS_PATH != "res://verification_settings.cfg":
		push_error("Isolate the review save/settings paths before running.")
		quit(1)
		return
	seed(20261008)
	globals.is_first_launch = false
	globals.hard_mode_enabled = false
	globals.counter_only_mode_enabled = false
	globals.just_guard_focus_mode = 0
	globals.aspect_ratio = 0
	globals.shield_radius_upgrades = {"counter": 0, "gauge": 0, "power": 0}
	globals.upgrade_levels = {"hp": 0, "parry_window": 0, "cooldown": 0, "shot_power": 0, "capture_power": 0}
	globals.counter_system_power_lvl = 0
	globals.counter_system_duration_lvl = 0
	for flag in globals.tutorial_flags: globals.tutorial_flags[flag] = true
	globals.save_game(1, 0, {})
	main = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	manager = main.get_node("GameManager")
	player = main.get_node("Player")
	pool = main.get_node("BulletPool")
	manager.set_process(false)
	manager.stage_generation += 1
	manager.clear_drones()
	manager.current_state = manager.State.BOSS
	boss = manager.boss
	boss.show()
	boss.process_mode = Node.PROCESS_MODE_INHERIT
	boss.set_process(false)
	boss.is_active = true
	boss.position = Vector2(root.get_visible_rect().size.x * 0.5, 360)
	results["conditions"]["viewport"] = str(root.get_visible_rect().size)
	if OS.get_cmdline_user_args().has("--probe-only"):
		for heat in [77.0, 78.0, 80.0]: await heat_probe(heat)
		print("BALANCE_PROBE_OK ", JSON.stringify(results["heat_probes"]))
		main.queue_free()
		await process_frame
		quit(0)
		return
	var configs := [["machine_gun", "counter"], ["burst_rifle", "counter"],
		["kinetic_tackle", "counter"], ["machine_gun", "gauge"], ["machine_gun", "power"]]
	var edges_only := OS.get_cmdline_user_args().has("--edges-only")
	results["conditions"]["player_invincible"] = true
	if not edges_only:
		for distance in [300.0, 170.0]:
			for config in configs: await shooting_trial(config[0], config[1], distance)
		for distance in [170.0, 250.0, 300.0, 330.0, 500.0]: await range_probe(distance)
	for shield in ["counter", "gauge", "power"]: await charge_probe(shield)
	await charge_probe("gauge", 5)
	for heat in [77.0, 78.0, 80.0]: await heat_probe(heat)
	await clean_attacks()
	reset_fixture("machine_gun", "counter", 500.0)
	# Equal incoming damage, evaluated by the actual boss defense/BREAK method.
	var dummy_turret := Node2D.new()
	dummy_turret.set_script(load("res://game/tests/review_dummy_turret.gd"))
	main.add_child(dummy_turret)
	for state in ["barrier", "unshielded", "BREAK"]:
		boss.turrets.clear()
		if state == "barrier": boss.turrets.append(dummy_turret)
		boss.is_break_vulnerable = state == "BREAK"
		boss.current_hp = 100000
		boss.take_damage_on_part("core", 1000, boss.core_node.global_position)
		var direct_removed: int = 100000 - boss.current_hp
		boss.current_hp = 100000
		var beam = load("res://game/player/player_counter_beam.gd").new()
		beam.setup(player, 1.0)
		main.add_child(beam)
		beam.set_process(false)
		beam._process(0.31)
		results["counter_damage_states"].append({"state": state, "incoming_damage": 1000,
			"hp_removed": direct_removed, "actual_beam_tick_hp_removed": 100000 - boss.current_hp})
		beam.queue_free()
	boss.turrets.clear()
	dummy_turret.queue_free()
	# Forced overlap: neither the turret nor the proximity pulse respects the new gap.
	boss.expanded_attack_turn = 3
	boss.is_break_vulnerable = false
	boss.current_hp = 100000
	boss.execute_fortress_attack()
	var sequence = boss.active_attack_sequence
	sequence.set_process(false)
	player.global_position = Vector2(sequence.gap_rect.get_center().x, boss.core_node.global_position.y + 150)
	boss.close_proximity_timer = 0.0
	boss.process_proximity_counter_attack(0.0)
	await create_timer(0.5, false).timeout
	var inside := 0
	for shot in pool.active_bullets:
		if sequence.gap_rect.has_point(shot.global_position): inside += 1
	results["gap_probes"].append({"source": "proximity", "shots": pool.active_bullets.size(),
		"shots_inside_gap_after_half_second": inside, "new_sequence_shots_fired": sequence.next_event,
		"scope": "forced overlap, not a measured gameplay frequency"})
	clear_pool()
	player.global_position = Vector2(sequence.gap_rect.get_center().x, 950)
	var turret = load("res://game/enemies/boss/boss_turret.tscn").instantiate()
	main.add_child(turret)
	turret.set_process(false)
	turret.global_position = Vector2(sequence.gap_rect.get_center().x, 240)
	turret.execute_attack()
	await create_timer(0.65, false).timeout
	inside = 0
	for shot in pool.active_bullets:
		if sequence.gap_rect.has_point(shot.global_position): inside += 1
	results["gap_probes"].append({"source": "turret", "shots": pool.active_bullets.size(),
		"shots_inside_gap_after_065_seconds": inside, "new_sequence_shots_fired": sequence.next_event,
		"scope": "forced turret placement in the gap; normal random placement frequency unmeasured"})
	turret.queue_free()
	sequence.queue_free()
	await process_frame
	await pause_probe(2, "missile")
	await pause_probe(4, "twin")
	await pause_probe(4, "sweep")
	# Current save compatibility is checked; a future HARD-only policy is not implemented here.
	globals.counter_system_power_lvl = 4
	globals.counter_system_duration_lvl = 3
	globals.equipped_counter_weapon = "funnel"
	globals.hard_mode_enabled = false
	globals.save_game()
	globals.hard_mode_enabled = true
	globals.save_game()
	var saved: Dictionary = globals.load_game_data(false)
	assert(saved["counter_system_power_lvl"] == 4 and saved["counter_system_duration_lvl"] == 3)
	assert(saved["equipped_counter_weapon"] == "funnel")
	results["current_save_probe"] = {"power_level": saved["counter_system_power_lvl"],
		"duration_level": saved["counter_system_duration_lvl"], "equipped": saved["equipped_counter_weapon"],
		"scope": "current NORMAL/HARD toggle preserves fields; future gate policy not implemented"}
	var file := FileAccess.open("res://balance_edges.json" if edges_only else "res://balance_review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	print("BALANCE_REVIEW_OK ", JSON.stringify(results))
	set_shield_key(false)
	manager.clean_stage_entities()
	main.queue_free()
	await process_frame
	quit(0)
