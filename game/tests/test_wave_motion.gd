extends "res://game/tests/wave_test_fixture.gd"

func run() -> void:
	await setup_fixture()
	for stage in range(1, 6):
		await prepare(stage, 0)
		var expected: int = gm.current_stage.get_wave(0).initial_spawns.size()
		gm.wave_elapsed = 8.0
		gm.spawn_due_wave_drones()
		# Bring each real stage's finite plan into the arena together for a motion check.
		# Entry delays are separately checked by test_finite_waves; no actor positions are set here.
		for wave in range(1, gm.current_stage.waves.size()):
			gm.start_wave(wave)
			gm.wave_elapsed = 8.0
			gm.spawn_due_wave_drones()
			expected += gm.current_stage.get_wave(wave).initial_spawns.size()
		assert(gm.spawned_drones.size() == expected)
		await create_timer(3.8, false).timeout
		for drone in gm.spawned_drones:
			assert(drone.wave_lane_enabled and drone.is_alive)
			assert(absf(drone.position.y - drone.wave_lane_origin.y) < 0.1)
			assert(absf(drone.position.x - drone.wave_lane_origin.x) <= drone.wave_lane_sway + 0.1)
			assert(drone.time_since_last_shot < drone.shoot_interval)
		assert(gm.bullet_pool.active_bullets.size() > 0, "The actual drones must fire while moving into their lanes")
		var fallback = gm.spawn_drone("straight", Vector2(100, 100))
		assert(not fallback.wave_lane_enabled, "Practice/boss-support spawns retain their default AI")
		print("WAVE_MOTION_CHECK stage=", stage, " real_moving_actors=", expected, " live_enemy_shots=", gm.bullet_pool.active_bullets.size())
	await finish_fixture()
	print("WAVE_MOTION_TEST_OK: all five finite plans, real entry/sway/shoot timers, default AI preserved, separated save unchanged")
	quit(0)
