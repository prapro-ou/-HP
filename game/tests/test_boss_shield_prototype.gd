extends SceneTree

class Target extends Node2D:
	var current_hp: int = 1000
	var hit_count: int = 0
	var is_alive: bool = true
	func take_damage(amount: int, _point: Vector2 = Vector2.ZERO, _critical: bool = false) -> void:
		current_hp -= amount
		hit_count += 1

func _init() -> void:
	call_deferred("run")

func clear_pool(pool: Node) -> void:
	for bullet in pool.active_bullets.duplicate():
		pool.return_bullet(bullet)

func capture_source(pool: Node, player: Node2D, offset: Vector2 = Vector2(0, -25)) -> void:
	var source = pool.get_bullet("straight")
	source.global_position = player.global_position + offset
	player.check_parry()
	Engine.time_scale = 1.0

func run() -> void:
	var globals = root.get_node("Global")
	if globals.SAVE_PATH != "res://verification_save.cfg" or globals.SETTINGS_PATH != "res://verification_settings.cfg":
		push_error("Run this test in an isolated project copy with verification save/settings paths.")
		quit(1)
		return
	globals.is_first_launch = false
	globals.hard_mode_enabled = false
	globals.counter_only_mode_enabled = false
	globals.just_guard_focus_mode = 0
	globals.shield_radius_upgrades = {"counter": 0, "gauge": 0, "power": 0}
	globals.upgrade_levels = {"hp": 0, "parry_window": 0, "cooldown": 0, "shot_power": 0, "capture_power": 0}
	for flag in globals.tutorial_flags:
		globals.tutorial_flags[flag] = true
	globals.save_game(1, 0, {})
	var main = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var manager = main.get_node("GameManager")
	var player = main.get_node("Player")
	var pool = main.get_node("BulletPool")
	manager.set_process(false)
	player.set_process(false)
	player.capture_volley.set_process(false)
	manager.clear_drones()
	manager.current_state = manager.State.BOSS
	player.global_position = Vector2(400, 950)
	player.is_guarding = true
	player.is_invincible = true
	player.is_control_locked = false
	globals.equipped_shield = "counter"
	player.shield_heat = 60.0
	player.parry_succeeded_in_guard = false
	capture_source(pool, player)
	assert(player.shield_heat == 52.0, "Counter success must refund heat")
	capture_source(pool, player)
	assert(player.shield_heat == 52.0, "More bullets in one guard must not multiply heat refunds")
	player.parry_succeeded_in_guard = false
	player.shield_heat = 4.0
	capture_source(pool, player)
	assert(player.shield_heat == 0.0, "Heat refund must clamp at zero")
	player.capture_volley.clear()
	player.parry_succeeded_in_guard = false
	capture_source(pool, player, Vector2(130, 0))
	assert(player.capture_volley.shots.is_empty(), "Standard shield must retain its smaller capture area")
	globals.equipped_shield = "gauge"
	player.check_parry()
	Engine.time_scale = 1.0
	assert(player.capture_volley.shots.size() == 1, "Wide absorption must catch a bullet outside the standard shield")
	assert(globals.get_just_guard_radius() == 140.0)
	player.capture_volley.clear()
	var near = Target.new()
	near.position = player.global_position + Vector2(0, -95)
	main.add_child(near)
	near.add_to_group("enemy")
	near.add_to_group("boss_turrets")
	var far = Target.new()
	far.position = player.global_position + Vector2(0, -170)
	main.add_child(far)
	far.add_to_group("enemy")
	globals.equipped_shield = "power"
	player.parry_succeeded_in_guard = false
	capture_source(pool, player)
	assert(near.hit_count == 1 and near.current_hp == 968, "Shockwave must damage each nearby target once, even across groups")
	assert(far.hit_count == 0, "Shockwave must stay short range")
	capture_source(pool, player)
	assert(near.hit_count == 1 and player.power_boost_remaining == 2.0, "One guard has one pulse, while later captures refresh the boost")
	main.get_node("UI").update_guard_heat(0, 100, false, 0, false, "power")
	assert(main.get_node("UI").boost_label.visible and main.get_node("UI").boost_label.text.begins_with("BOOST"))
	assert(not main.get_node("UI").guard_status_label.text.begins_with("BOOST"), "BOOST must not replace shield availability")
	player.parry_succeeded_in_guard = false
	globals.counter_only_mode_enabled = true
	capture_source(pool, player)
	assert(near.hit_count == 1, "COUNTER ONLY must not gain a new primary shockwave")
	globals.counter_only_mode_enabled = false
	player.lock_controls()
	assert(player.power_pulse_remaining == 0 and player.power_boost_remaining == 0)
	player.reset_state()
	player.set_process(false)
	player.capture_volley.set_process(false)
	player.is_invincible = true
	near.queue_free()
	far.queue_free()
	await process_frame
	clear_pool(pool)

	# Every live stage connects two new attacks, including the overriding stage 2/4 scripts.
	var signatures := ["gap_wall", "crossfire", "sweep", "aimed_burst", "crossfire"]
	var alternates := ["aimed_burst", "gap_wall", "gap_wall", "sweep", "gap_wall"]
	for stage in range(1, 6):
		manager.load_stage("res://game/stages/stage_%d.tscn" % stage, stage)
		await process_frame
		await process_frame
		manager.clear_drones()
		var boss = manager.boss
		boss.show()
		boss.is_active = true
		boss.is_alive = true
		boss.position = Vector2(400, 360)
		boss.set_process(false)
		player.set_process(false)
		player.capture_volley.set_process(false)
		player.is_control_locked = false
		player.is_invincible = true
		player.global_position = Vector2(400, 950)
		clear_pool(pool)
		var signature_count: int = 0
		for slot in [3, 5]:
			boss.expanded_attack_turn = slot
			boss.execute_fortress_attack()
			var sequence = boss.active_attack_sequence
			assert(is_instance_valid(sequence))
			sequence.set_process(false)
			assert(sequence.pattern == (signatures[stage - 1] if slot == 3 else alternates[stage - 1]))
			assert(sequence.warning_label.get_global_rect().end.x <= sequence.viewport_size.x, "Warning text must fit the viewport")
			if slot == 3:
				signature_count = sequence.events.size()
			assert(pool.active_bullets.is_empty(), "Telegraph must precede live bullets")
			sequence._process(0.3)
			paused = true
			sequence.set_process(true)
			await create_timer(0.04, true).timeout
			assert(is_equal_approx(sequence.elapsed, 0.3), "New attack must freeze during pause")
			paused = false
			sequence.set_process(false)
			var first_event: Dictionary = sequence.events[0]
			player.global_position.x = 100
			sequence._process(0.46)
			assert(not pool.active_bullets.is_empty())
			assert(pool.active_bullets[0].velocity.normalized().is_equal_approx(first_event["direction"]), "Aimed salvos must honor their previewed direction")
			for bullet in pool.active_bullets:
				assert(CombatTargets.can_parry(bullet), "All new patterns must provide capture opportunities")
			if sequence.pattern == "gap_wall":
				for event in sequence.events:
					assert(not sequence.gap_rect.has_point(event["origin"] + Vector2(0, 1)), "Every wave must preserve the telegraphed gap")
			sequence._process(sequence.end_time)
			await process_frame
			clear_pool(pool)
		# Low HP adds rounds; no delayed attack survives boss death.
		boss.current_hp = int(boss.max_hp * 0.3)
		boss.expanded_attack_turn = 3
		boss.execute_fortress_attack()
		var intense_sequence = boss.active_attack_sequence
		intense_sequence.set_process(false)
		assert(intense_sequence.events.size() > signature_count, "Low HP must visibly add shots to the same pattern")
		boss.is_alive = false
		intense_sequence._process(1.0)
		assert(pool.active_bullets.is_empty(), "Boss death must cancel all pending shots")
		await process_frame
		assert(get_nodes_in_group("boss_attack_sequences").is_empty())
		boss.is_alive = true
		boss.is_break_vulnerable = true
		boss.expanded_attack_turn = 3
		boss.execute_fortress_attack()
		assert(boss.active_attack_sequence.events.size() == signature_count, "BREAK must retain a milder counterattack opportunity")
		boss.active_attack_sequence.set_process(false)
		manager.clean_stage_entities()
		await process_frame
		assert(get_nodes_in_group("boss_attack_sequences").is_empty(), "Stage cleanup must free the pending sequence with its boss")
	main.queue_free()
	await process_frame
	print("BOSS_SHIELD_PROTOTYPE_TEST_OK: five-stage repertoire, telegraphs, fixed aim, captureable salvos, pause/death/cleanup, heat refund, wide capture, one short-range pulse, COUNTER ONLY, boost HUD")
	quit(0)
