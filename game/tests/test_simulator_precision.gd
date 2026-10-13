extends SceneTree

var globals: Node
var main: Node
var manager: Node
var player: Node
var pool: Node
var ui: Node
var save_before: PackedByteArray
var settings_before: PackedByteArray

func _init() -> void:
	call_deferred("run")

func mount(config: Dictionary) -> void:
	assert(globals.begin_practice(config))
	main = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	manager = main.get_node("GameManager")
	player = main.get_node("Player")
	pool = main.get_node("BulletPool")
	ui = main.get_node("UI")
	manager.set_process(false)
	player.set_process(false)
	player.capture_volley.set_process(false)
	for enemy in get_nodes_in_group("enemy"):
		enemy.set_process(false)

func unmount() -> void:
	manager.clean_stage_entities()
	player.stop_counter_system()
	main.queue_free()
	await process_frame
	await process_frame
	globals.end_practice()
	assert_saved()

func assert_saved() -> void:
	assert(FileAccess.get_file_as_bytes(globals.SAVE_PATH) == save_before, "Practice changed the campaign save")
	assert(FileAccess.get_file_as_bytes(globals.SETTINGS_PATH) == settings_before, "Practice changed saved settings")
	assert(globals.tech_points == 123 and globals.discovered_analysis_weapons.is_empty())
	assert(globals.cleared_stages == [1, 2, 3, 4, 5] and globals.stage5_clears_count == 3)
	assert(globals.is_first_launch and not globals.tutorial_flags["controls"])

func bullet_at(distance: float, damage: int = 20) -> Node2D:
	var bullet = pool.get_bullet("straight")
	bullet.global_position = player.global_position + Vector2(0, -distance)
	bullet.damage = damage
	bullet.set_process(false)
	return bullet

func guard() -> void:
	player.is_guarding = true
	player.parry_succeeded_in_guard = false
	player.precision_feedback_in_guard = false
	player.active_timer = 0.28
	player.is_invincible = false
	player.check_parry()
	Engine.time_scale = 1.0

func run() -> void:
	globals = root.get_node("Global")
	assert(globals.SAVE_PATH == "res://verification_save.cfg" and globals.SETTINGS_PATH == "res://verification_settings.cfg", "Use an isolated verification copy")
	globals.unlocked_stages = [1, 2]
	globals.cleared_stages = []
	assert(not globals.begin_practice({"kind": "boss", "stage": 2}))
	assert(globals.begin_practice({"kind": "boss", "stage": 1}), "Old save with next stage unlocked must allow the previous boss")
	globals.end_practice()
	assert(not globals.begin_practice({"kind": "drone", "drone": "invalid"}))
	globals.cleared_stages = [1, 2, 3, 4, 5]
	globals.tech_points = 123
	globals.stage5_clears_count = 3
	globals.discovered_analysis_weapons = []
	globals.is_first_launch = true
	globals.hard_mode_enabled = false
	globals.counter_only_mode_enabled = false
	globals.equipped_weapon = "machine_gun"
	globals.equipped_shield = "counter"
	globals.upgrade_levels = {"hp": 0, "parry_window": 0, "cooldown": 0, "shot_power": 0, "capture_power": 0}
	globals.shield_radius_upgrades = {"counter": 0, "gauge": 0, "power": 0}
	globals.tutorial_flags = {"controls": false, "weapon_analysis": false, "time_limit": false, "boss_info": false}
	globals.save_game(4, 77)
	globals.save_settings()
	save_before = FileAccess.get_file_as_bytes(globals.SAVE_PATH)
	settings_before = FileAccess.get_file_as_bytes(globals.SETTINGS_PATH)

	for kind in load("res://game/core/practice_setup.gd").DRONES:
		await mount({"kind": "drone", "drone": kind, "stage": 1, "repeat": false, "infinite_hp": false})
		assert(manager.spawned_drones.size() == 1)
		assert(manager.spawned_drones[0].drone_type == kind)
		manager.spawned_drones[0].take_damage(100000)
		await process_frame
		manager.process_practice(10.0)
		assert(manager.spawned_drones.is_empty(), "Single spawn must not replenish")
		assert_saved()
		await unmount()

	await mount({"kind": "drone", "drone": "wave", "stage": 1, "repeat": true, "infinite_hp": true})
	for i in range(8): manager.process_practice(2.1)
	assert(manager.spawned_drones.size() == 3, "Infinite replenishment must remain bounded")
	var hp_before: int = player.current_hp
	player.take_damage(100000, true)
	assert(player.current_hp == hp_before and player.is_invincible and player.is_overheated, "Infinite HP must retain damage/guard-break feedback")
	ui.update_player_hp(player.current_hp, player.max_hp)
	assert(ui.player_hp_label.text == "HP ∞")
	globals.save_game(5, 999999)
	globals.save_settings()
	manager.add_tech_points(50)
	manager.add_damage_score(500)
	manager.on_boss_destroyed()
	ui.show_tutorial_guide_modal("controls")
	assert(manager.total_damage_score == 0 and not globals.tutorial_flags["controls"])
	assert(not globals.mark_stage_cleared(3) and not globals.unlock_stage(5))
	assert(globals.unlock_next_tip() == "")
	assert_saved()
	await unmount()

	await mount({"kind": "boss", "stage": 2, "intense": true, "infinite_hp": false})
	assert(manager.current_state == manager.State.BOSS and manager.counter_system.phase == CounterSystem.Phase.CHARGING)
	assert(absf(float(manager.boss.current_hp) - manager.boss.max_hp * 0.3) <= 1.0)
	var boss_hp: int = manager.boss.current_hp
	manager.boss.take_damage_on_part("core", 100000)
	assert(manager.boss.current_hp == boss_hp and manager.boss.is_alive)
	# End descent before checking pause-safe legacy attack reservations.
	await create_timer(0.7, false).timeout
	manager.clear_all_bullets()
	manager.boss.attack_pattern_index = 1
	manager.boss.execute_fortress_attack()
	paused = true
	await create_timer(0.65, true).timeout
	assert(pool.active_bullets.is_empty(), "Legacy boss shots appeared while paused")
	paused = false
	manager.clean_stage_entities()
	await create_timer(0.7, false).timeout
	assert(pool.active_bullets.is_empty(), "Old boss reservations survived cleanup")
	await unmount()

	for stage_number in [1, 3, 4, 5]:
		await mount({"kind": "boss", "stage": stage_number, "intense": false, "infinite_hp": true})
		await create_timer(0.65, false).timeout
		assert(manager.boss.current_hp == manager.boss.max_hp)
		manager.boss.take_damage_on_part("core", 100000)
		assert(manager.boss.current_hp == manager.boss.max_hp)
		var parts: Array = manager.boss.turrets.duplicate()
		assert(not parts.is_empty())
		for part in parts:
			if is_instance_valid(part): part.take_damage(100000)
		await process_frame
		assert(globals.tech_points == 123, "Turret death granted practice TP")
		assert(manager.boss.is_break_vulnerable, "Turret destruction must still trigger BREAK")
		if stage_number == 4:
			manager.clear_all_bullets()
			manager.boss.execute_twin_thick_beam_attack(1.0)
			paused = true
			await create_timer(0.6, true).timeout
			assert(pool.active_bullets.is_empty())
			paused = false
		if stage_number == 5:
			var funnel = load("res://game/enemies/boss/boss_funnel_turret.tscn").instantiate()
			main.add_child(funnel)
			funnel.take_damage(100000)
			await process_frame
			assert(globals.tech_points == 123)
		await unmount()

	await mount({"kind": "boss", "stage": 1, "intense": false, "infinite_hp": false})
	manager.clear_drones()
	for shield in ["counter", "gauge", "power"]:
		globals.equipped_shield = shield
		for focus in range(3):
			globals.just_guard_focus_mode = focus
			player.reset_state()
			player.capture_volley.set_process(false)
			manager.counter_system.begin_battle()
			var radius: float = globals.get_just_guard_radius()
			assert(radius * player.PRECISION_RADIUS_RATIO >= 25.0)
			bullet_at(radius * 0.9)
			bullet_at(radius * 0.5)
			player.shield_heat = 50.0
			guard()
			assert(player.capture_volley.shots.size() == 2)
			var normal: Dictionary = player.capture_volley.shots.filter(func(shot): return not shot["precision"])[0]
			var precise: Dictionary = player.capture_volley.shots.filter(func(shot): return shot["precision"])[0]
			assert(not normal["precision"] and precise["precision"])
			var multiplier: float = globals.get_just_guard_damage_multiplier() * (1.4 if shield == "counter" else 1.0)
			assert(normal["damage"] == int(20 * 2.2 * multiplier))
			assert(precise["damage"] == int(20 * 2.2 * multiplier * 1.25))
			assert(player.parry_heal_counter == 1)
			assert(manager.counter_system.gauge == (33.0 if shield == "gauge" else 22.0))
			if shield == "counter": assert(player.shield_heat == 42.0)
			player.check_parry()
			assert(not normal["precision"] and player.parry_heal_counter == 1, "No later promotion or repeat reward")
			bullet_at(radius * 0.4)
			player.check_parry()
			Engine.time_scale = 1.0
			assert(player.parry_heal_counter == 1)
			player.capture_volley._process(0.27)
			var released: Array = player.capture_volley.take_ready()
			assert(released.size() == 3 and player.capture_volley.take_ready().is_empty())
			assert(released.any(func(shot): return shot["precision"] and shot["damage"] == precise["damage"]), "Precision multiplied again on release")
			manager.clear_all_bullets()
	# Contact callback uses the capture path even before the next process tick.
	globals.equipped_shield = "counter"
	globals.just_guard_focus_mode = 2
	globals.upgrade_levels["capture_power"] = 5
	player.reset_state()
	bullet_at(10.0)
	guard()
	assert(player.capture_volley.shots[0]["damage"] == 172, "Capture/focus/shield/precision must each multiply once")
	globals.upgrade_levels["capture_power"] = 0
	globals.equipped_shield = "power"
	globals.just_guard_focus_mode = 2
	player.reset_state()
	player.is_guarding = true
	var contact := bullet_at(18.0)
	contact._on_body_entered(player)
	Engine.time_scale = 1.0
	assert(player.current_hp == player.max_hp and player.capture_volley.shots[0]["precision"])
	# A large projectile can physically touch before its center reaches the outer ring.
	player.capture_volley.clear()
	var large_contact := bullet_at(globals.get_just_guard_radius() + 5.0)
	large_contact._on_body_entered(player)
	assert(player.capture_volley.shots.size() == 1 and not player.capture_volley.shots[0]["precision"])
	# Unparryable attacks still break the guard.
	var unsafe := bullet_at(18.0)
	unsafe.is_unparryable = true
	unsafe._on_body_entered(player)
	assert(player.current_hp < player.max_hp and not player.is_guarding)
	# Finite death cancels held shots, delayed fire and COUNTER, offers retry.
	player.is_invincible = false
	player.take_damage(100000)
	manager.process_practice(0.01)
	assert(manager.current_state == manager.State.DEFEAT)
	assert(player.capture_volley.shots.is_empty() and not player.is_full_burst and player.shield_heat == 0)
	assert(ui.has_node("PracticeEnd"))
	assert_saved()
	manager.restart()
	await process_frame
	await process_frame
	await process_frame
	main = current_scene
	manager = main.get_node("GameManager")
	player = main.get_node("Player")
	assert(globals.practice_active and player.current_hp == player.max_hp and not player.is_control_locked)
	assert(player.capture_volley.shots.is_empty() and manager.counter_system.gauge == 0)
	manager.exit_practice()
	await process_frame
	await process_frame
	assert(not globals.practice_active and current_scene.name == "PracticeSetup")
	assert_saved()
	print("SIMULATOR_PRECISION_TEST_OK: eleven drones, bounded repeats, no progress/save writes, cleared-only bosses, infinite phase, HP feedback, nine focus/shield pairs, mixed snapshots, one reward, collision, pause, cleanup, retry, exit")
	quit(0)
