extends SceneTree

class Target:
	extends Area2D
	var current_hp: int = 10000
	var hit_count: int = 0
	func take_damage(amount: int, _point: Vector2 = Vector2.ZERO, _critical: bool = false) -> void:
		current_hp -= amount
		hit_count += 1

func _init() -> void:
	call_deferred("run")

func clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()
	await process_frame

func run() -> void:
	var globals = root.get_node("Global")
	if globals.SAVE_PATH != "res://verification_save.cfg" or globals.SETTINGS_PATH != "res://verification_settings.cfg":
		push_error("Run combat tests in an isolated project copy with verification save/settings paths.")
		quit(1)
		return
	globals.is_first_launch = false
	globals.hard_mode_enabled = false
	globals.counter_only_mode_enabled = false
	globals.equipped_shield = "counter"
	globals.equipped_weapon = "machine_gun"
	globals.equipped_counter_weapon = "turret"
	globals.just_guard_focus_mode = 0
	globals.shield_radius_upgrades = {"counter": 0, "gauge": 0, "power": 0}
	globals.counter_system_power_lvl = 0
	globals.counter_system_duration_lvl = 0
	globals.upgrade_levels = {"hp": 0, "parry_window": 0, "cooldown": 0}
	for flag in globals.tutorial_flags:
		globals.tutorial_flags[flag] = true
	globals.save_game(3, 0, {})
	var main = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var manager = main.get_node("GameManager")
	var player = main.get_node("Player")
	var pool = main.get_node("BulletPool")
	var ui = main.get_node("UI")
	manager.set_process(false)
	player.set_process(false)
	player.capture_volley.set_process(false)
	manager.clear_drones()
	assert(manager.current_stage_num == 3 and player.is_attack_unlocked)
	assert(main.get_node_or_null("LoadoutDraft") == null and manager.get_node_or_null("AnalysisSystem") == null)
	for stage_number in range(1, 6):
		manager.load_stage("res://game/stages/stage_%d.tscn" % stage_number, stage_number)
		await process_frame
		await process_frame
		manager.clear_drones()
		assert(manager.current_stage.stage_number == stage_number)
		assert(manager.boss != null and manager.current_stage.get_node_or_null("FinalBoss") == null)
		player.capture_volley.set_process(false)

	var bullets = main.get_node("PlayerBullets")
	for weapon_id in WeaponCatalog.PRIMARY:
		await clear_children(bullets)
		globals.equipped_weapon = weapon_id
		player.apply_equipped_weapon_settings()
		player.fire()
		if weapon_id == "burst_rifle":
			await create_timer(0.11, false).timeout
		var expected_count = 2 if weapon_id == "machine_gun" else (3 if weapon_id == "pulse_gun" or weapon_id == "burst_rifle" else 1)
		assert(bullets.get_child_count() == expected_count, "Primary firing patterns must remain distinct")
		for shot in bullets.get_children():
			assert(shot.get_meta("primary_weapon") == weapon_id)
			assert(shot.damage == WeaponCatalog.PRIMARY[weapon_id]["damage"])
			if weapon_id == "plasma_emitter": assert(shot.heat_radius > 0)
			if weapon_id == "kinetic_tackle": assert(shot.max_distance == 180.0 and shot.pierce_limit > 0)
	globals.equipped_weapon = "machine_gun"
	player.apply_equipped_weapon_settings()
	await clear_children(bullets)
	player.global_position = Vector2(300, 650)
	manager.current_state = manager.State.BOSS
	manager.counter_system.begin_battle()
	var start_parries: int = manager.parry_count
	for index in range(5):
		var source = pool.get_bullet("missile")
		source.global_position = player.global_position + Vector2(index * 4, -35)
	player.is_guarding = true
	player.parry_succeeded_in_guard = false
	player.consecutive_parries = 0
	player.check_parry()
	Engine.time_scale = 1.0
	assert(player.capture_volley.shots.size() == 5)
	assert(manager.parry_count == start_parries + 1 and manager.counter_system.gauge == 22.0)
	var later = pool.get_bullet("wave")
	later.global_position = player.global_position + Vector2(0, -25)
	player.check_parry()
	assert(manager.counter_system.gauge == 22.0, "One guard activation must reward once even across frames")
	player.fire()
	assert(player.capture_volley.shots.size() == 6, "Capture must stay visible for its minimum display time")
	await clear_children(bullets)
	player.capture_volley._process(CaptureVolley.DISPLAY_TIME + 0.01)
	player.fire()
	assert(player.capture_volley.shots.is_empty())
	var followups := 0
	for shot in bullets.get_children():
		if shot.has_meta("captured_kind"): followups += 1
	assert(followups == 8, "Five missiles plus a captured three-way wave must be emitted once")
	player.fire()
	var second_count := 0
	for shot in bullets.get_children():
		if shot.has_meta("captured_kind"): second_count += 1
	assert(second_count == followups, "Released snapshots must not fire twice")
	await clear_children(bullets)

	for definition in WeaponCatalog.ANALYSIS_RESOURCES:
		var source = pool.get_bullet(String(definition.bullet_types[0]))
		source.global_position = player.global_position + Vector2(0, -20)
		assert(player.capture_volley.capture(source))
		assert(not source.visible and not source.is_processing())
		var replacement = pool.get_bullet("straight")
		assert(replacement == source)
		replacement.global_position = Vector2(600, 1100)
		player.capture_volley._process(CaptureVolley.DISPLAY_TIME + 0.01)
		player.fire()
		var captured: Array = []
		for shot in bullets.get_children():
			if shot.has_meta("captured_kind"): captured.append(shot)
		assert(captured.size() == (3 if definition.id == &"spread" else 1))
		var shot = captured[0]
		assert(shot.get_meta("captured_kind") == String(definition.id), "Pool reuse must not change held bullet identity")
		match definition.id:
			&"homing": assert(shot.bullet_type == "missile")
			&"pierce", &"laser", &"blade": assert(shot.pierce_limit > 0)
			&"meteor": assert(shot.explosion_radius > 0)
			&"thunder": assert(shot.chain_count > 0)
			&"vortex": assert(shot.vortex_radius > 0)
			&"cyclone": assert(shot.bullet_type == "cyclone")
		pool.return_bullet(replacement)
		await clear_children(bullets)
	var uncapturable = pool.get_bullet("unparryable_laser")
	uncapturable.global_position = player.global_position
	assert(not player.capture_volley.capture(uncapturable) and uncapturable.visible)
	pool.return_bullet(uncapturable)
	for index in range(CaptureVolley.CAPACITY + 4):
		var source = pool.get_bullet("straight")
		source.global_position = player.global_position
		assert(player.capture_volley.capture(source))
	assert(player.capture_volley.shots.size() == CaptureVolley.CAPACITY)
	assert(pool.active_bullets.is_empty(), "Overflow must still defend the player without extra held shots")
	player.capture_volley.clear()
	var pause_source = pool.get_bullet("straight")
	pause_source.global_position = player.global_position
	player.capture_volley.capture(pause_source)
	player.capture_volley.set_process(true)
	paused = true
	await create_timer(0.08, true).timeout
	assert(player.capture_volley.shots[0]["age"] == 0.0)
	paused = false
	player.capture_volley.set_process(false)
	player.capture_volley.clear()

	# The three shields retain different rewards without extra input or permanent stacking.
	for shield in ["counter", "power", "gauge"]:
		globals.equipped_shield = shield
		manager.counter_system.begin_battle()
		player.parry_succeeded_in_guard = false
		player.consecutive_parries = 0
		var source = pool.get_bullet("straight")
		source.damage = 20
		source.global_position = player.global_position + Vector2(100 if shield == "gauge" else 20, 0)
		player.check_parry()
		Engine.time_scale = 1.0
		assert(player.capture_volley.shots.size() == 1)
		assert(player.capture_volley.shots[0]["damage"] == int(20 * 2.2 * (1.4 if shield == "counter" else 1.0) * (1.25 if shield != "gauge" else 1.0)))
		assert(manager.counter_system.gauge == (33.0 if shield == "gauge" else 22.0))
		if shield == "power":
			player.fire()
			for shot in bullets.get_children(): assert(shot.damage == int(14 * 1.25))
			await clear_children(bullets)
			var another = pool.get_bullet("straight")
			another.global_position = player.global_position
			player.check_parry()
			assert(player.power_boost_remaining == 2.0, "Power capture refreshes a two-second boost without stacking")
			player.is_guarding = false
			player.active_timer = 0.0
			player.is_attack_unlocked = false
			player._process(2.01)
			player.is_attack_unlocked = true
			player.capture_volley.clear()
			player.fire()
			for shot in bullets.get_children(): assert(shot.damage == 14, "Expired boost restores the original primary damage")
			await clear_children(bullets)
		player.capture_volley.clear()
	assert(globals.get_just_guard_radius("gauge") > globals.get_just_guard_radius("power"))
	globals.counter_only_mode_enabled = true
	manager.counter_system.begin_battle(true)
	player.parry_succeeded_in_guard = false
	player.consecutive_parries = 0
	var counter_only_source = pool.get_bullet("missile")
	counter_only_source.global_position = player.global_position
	player.check_parry()
	Engine.time_scale = 1.0
	player.fire()
	assert(player.capture_volley.shots.is_empty() and bullets.get_child_count() == 0)
	assert(not counter_only_source.visible and manager.counter_system.gauge == 33.0)
	globals.counter_only_mode_enabled = false
	globals.equipped_shield = "counter"
	manager.counter_system.begin_battle()
	player.is_guarding = true
	player.parry_succeeded_in_guard = false
	player.consecutive_parries = 0
	var trap = load("res://game/enemies/boss/boss_trap_mine.gd").new()
	main.add_child(trap)
	trap.set_process(false)
	trap.global_position = player.global_position + Vector2(0, -20)
	trap._on_body_entered(player)
	Engine.time_scale = 1.0
	assert(not trap.is_active and player.capture_volley.shots[0]["kind"] == "meteor")
	assert(manager.counter_system.gauge == 22.0, "Mine contact parry uses the same one-guard reward path")
	player.capture_volley.clear()
	await process_frame
	var shot_trap = load("res://game/enemies/boss/boss_trap_mine.gd").new()
	main.add_child(shot_trap)
	shot_trap.set_process(false)
	var friendly := Area2D.new()
	main.add_child(friendly)
	friendly.add_to_group("player_bullets")
	shot_trap._on_area_entered(friendly)
	assert(not shot_trap.is_active and player.capture_volley.shots.is_empty())
	assert(manager.counter_system.gauge == 22.0, "Shooting a mine must not grant a parry or free captured attack")
	friendly.queue_free()
	await process_frame
	globals.upgrade_levels["cooldown"] = 5
	player.reset_state()
	assert(is_equal_approx(player.heat_recovery_rate, 60.0))
	assert(is_equal_approx(player.overheat_cooldown, 1.32) and is_equal_approx(player.gauge_shield_cooldown, 1.8))
	globals.upgrade_levels["cooldown"] = 0
	player.reset_state()
	player.capture_volley.set_process(false)

	# Legacy saves keep their values; new upgrades begin at zero and persist.
	assert(globals.get_primary_power_multiplier() == 1.0 and globals.get_capture_power_multiplier() == 1.0)
	var lab = load("res://game/core/tech_lab.tscn").instantiate()
	root.add_child(lab)
	globals.tech_points = 100
	var saved_stage: int = globals.load_game_data(false)["stage_num"]
	lab.perform_upgrade("shot_power")
	lab.perform_upgrade("capture_power")
	assert(globals.upgrade_levels["shot_power"] == 1 and globals.upgrade_levels["capture_power"] == 1)
	var saved = globals.load_game_data(false)
	assert(saved["stage_num"] == saved_stage and saved["upgrade_levels"]["capture_power"] == 1)
	assert(is_equal_approx(globals.get_primary_power_multiplier(), 1.08))
	player.fire()
	for shot in bullets.get_children(): assert(shot.damage == int(14 * 1.08))
	await clear_children(bullets)
	var upgraded_source = pool.get_bullet("straight")
	upgraded_source.damage = 20
	upgraded_source.global_position = player.global_position
	player.parry_succeeded_in_guard = false
	player.check_parry()
	Engine.time_scale = 1.0
	assert(player.capture_volley.shots[0]["damage"] == int(20 * 2.2 * 1.4 * 1.12 * 1.25))
	player.capture_volley.clear()
	globals.upgrade_levels["shot_power"] = 99
	globals.upgrade_levels["capture_power"] = 99
	assert(is_equal_approx(globals.get_primary_power_multiplier(), 1.4) and is_equal_approx(globals.get_capture_power_multiplier(), 1.6))
	lab.queue_free()
	globals.upgrade_levels = {"hp": 0, "parry_window": 0, "cooldown": 0}
	await process_frame
	manager.current_state = manager.State.WAVE
	manager.trigger_interlude()
	assert(manager.current_state == manager.State.INTERLUDE and player.is_control_locked)
	manager._process(2.01)
	assert(manager.current_state == manager.State.BOSS and not player.is_control_locked)
	manager.boss.hide()
	manager.boss.process_mode = Node.PROCESS_MODE_DISABLED
	player.set_process(false)
	var target := Target.new()
	target.global_position = Vector2(300, 450)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	target.add_child(shape)
	main.add_child(target)
	for group in ["enemy", "drones", "boss_turrets"]: target.add_to_group(group)
	await physics_frame
	var before: int
	player.global_position = Vector2(300, 650)
	var bullet_container = main.get_node("PlayerBullets")
	for kind in WeaponCatalog.COUNTER:
		await clear_children(bullet_container)
		manager.current_state = manager.State.BOSS
		manager.counter_system.begin_battle()
		globals.equipped_counter_weapon = kind
		for streak in range(1, 5):
			manager._on_parry_succeeded("boss_laser", Vector2.ZERO, streak)
		manager.request_counter_activation()
		assert(player.is_full_burst)
		var entities = player.counter_system_turrets.duplicate()
		for entity in entities:
			entity.set_process(false)
		if kind == "turret":
			var remaining_before_pause: float = manager.counter_system.remaining
			paused = true
			await create_timer(0.08, true).timeout
			assert(manager.counter_system.remaining == remaining_before_pause, "Pause must freeze the COUNTER effect clock")
			paused = false
		match kind:
			"turret":
				assert(entities.size() == 2 and entities[0].get_script().resource_path.ends_with("support_turret.gd"))
				entities[0].fire_support_attack()
				assert(bullet_container.get_child_count() == 2)
			"funnel":
				assert(entities.size() == 4 and entities[0].get_script().resource_path.ends_with("player_funnel_unit.gd"))
				assert(entities[0].find_target() == target, "Funnels must prioritize live boss turrets")
			"boss_missile":
				assert(entities.size() == 2 and entities[0].weapon_mode == "boss_missile")
				for entity in entities:
					entity.fire_support_attack()
				assert(bullet_container.get_child_count() == 6, "Missile COUNTER must launch a six-missile salvo")
				for missile in bullet_container.get_children():
					assert(missile.bullet_type == "hyper_missile" and missile.explosion_dmg > 0)
			"boss_beam":
				assert(entities.size() == 1 and entities[0].get_script().resource_path.ends_with("player_counter_beam.gd"))
				before = target.current_hp
				entities[0]._process(0.31)
				assert(target.current_hp == before - 44, "Beam must damage targets in its actual corridor once per tick")
			"gigantic_orb":
				assert(entities.size() == 1 and entities[0].get_script().resource_path.ends_with("player_gigantic_orb.gd"))
				entities[0].global_position = target.global_position
				before = target.hit_count
				entities[0].deal_tick_damage()
				assert(target.hit_count == before + 1, "Orb must not triple-hit the same target via groups")
			"chain_explosions":
				assert(entities.size() == 1 and entities[0].get_script().resource_path.ends_with("player_chain_sweep.gd"))
				for point in entities[0].sweep_positions:
					assert(point.x >= 0 and point.x <= root.get_visible_rect().size.x, "Sweep must fit the selected aspect ratio")
				before = target.hit_count
				var danger = pool.get_bullet("unparryable_laser")
				danger.global_position = target.global_position
				var normal = pool.get_bullet("straight")
				normal.global_position = target.global_position
				entities[0].trigger_single_chain_explosion(target.global_position, 0)
				assert(target.hit_count == before + 1)
				assert(not danger.is_friendly and normal.is_friendly, "Sweep may only reflect parryable projectiles")
				pool.return_bullet(danger)
		manager.counter_system._process(manager.counter_system.remaining + 1.0)
		await process_frame
		assert(not player.is_full_burst and not ui.counter_system_active)
		assert(get_nodes_in_group("counter_projectiles").is_empty(), "No COUNTER projectile may survive its effect")
		assert(manager.counter_system.phase == CounterSystem.Phase.SPENT)
		manager.counter_system.register_parry(5)
		assert(not manager.counter_system.try_activate(), "Normal COUNTER remains limited to one use per boss")
		assert(ui.v3_counter_label.text.contains("使用済み"))

	var repeatable_counter := CounterSystem.new()
	main.add_child(repeatable_counter)
	repeatable_counter.set_process(false)
	repeatable_counter.begin_battle(true)
	for index in range(4): repeatable_counter.register_parry(5)
	assert(repeatable_counter.try_activate(0.01))
	repeatable_counter._process(0.02)
	assert(repeatable_counter.phase == CounterSystem.Phase.CHARGING and not repeatable_counter.try_activate())
	for index in range(4): repeatable_counter.register_parry(5)
	assert(repeatable_counter.try_activate(0.01), "COUNTER ONLY needs fresh parries and manual activation for every use")
	repeatable_counter.queue_free()

	assert(ui.get_node("CapturePanel").position.x + ui.get_node("CapturePanel").size.x <= root.get_visible_rect().size.x)
	var held_at_death = pool.get_bullet("straight")
	held_at_death.global_position = player.global_position
	player.capture_volley.capture(held_at_death)
	# A timer belonging to an old pooled spawn cannot detonate its replacement.
	var enemy_turret = load("res://game/enemies/boss/boss_turret.tscn").instantiate()
	main.add_child(enemy_turret)
	enemy_turret.set_process(false)
	enemy_turret.drop_chain_fuse_bullet(Vector2(300, 600))
	var fuse = pool.active_bullets.back()
	pool.return_bullet(fuse)
	var replacement = pool.get_bullet("straight")
	replacement.global_position = Vector2(600, 1100)
	await create_timer(0.8, false).timeout
	assert(replacement.visible and replacement.bullet_type == "straight", "A recycled bullet must outlive the timer of its previous spawn")
	pool.return_bullet(replacement)
	enemy_turret.queue_free()
	await process_frame

	manager.counter_system.begin_battle()
	for index in range(4):
		manager.counter_system.register_parry(5)
	manager.request_counter_activation()
	player.current_hp = 0
	manager.check_win_lose()
	assert(manager.current_state == manager.State.DEFEAT)
	assert(player.capture_volley.shots.is_empty(), "Defeat must clear held captures")
	assert(manager.counter_system.phase == CounterSystem.Phase.DISABLED and not player.is_full_burst)
	manager.on_boss_destroyed()
	assert(manager.current_state == manager.State.DEFEAT, "A delayed boss death callback must not turn defeat into victory")
	manager.restart()
	await process_frame
	await process_frame
	await process_frame
	assert(current_scene.get_node("GameManager").current_stage_num == 5, "Retry must stay on the same stage")
	print("CAMPAIGN_COMBAT_TEST_OK: capture/release, ten payloads, five stages, five primaries, three shields, six counters, upgrades, pause/defeat/retry")
	current_scene.queue_free()
	await process_frame
	quit(0)
