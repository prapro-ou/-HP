extends BaseStage
class_name Stage2

## ステージ2（防衛グリッド＆高難度スワームフェーズ）の設定クラス

func _ready_stage() -> void:
	stage_name = "OVERLOADED GUARDIAN"
	stage_number = 2
	_setup_waves()
	_setup_interlude()
	_setup_boss()
	_setup_rewards()

func _setup_waves() -> void:
	# Wave 1: Dual Extraction
	var w1 = WaveData.new()
	w1.wave_id = "wave1_dual"
	w1.display_title = "WAVE 1: DUAL EXTRACTION"
	w1.start_message = "WAVE 1: DUAL EXTRACTION\nPARRY BOTH TYPES TO UNLOCK WEAPONS"
	w1.clear_condition_type = "dual_analysis"
	w1.transition_delay = 2.5
	w1.completion_message = "WEAPONS ADAPTED!\nDATA EXTRACTION COMPLETE."
	w1.replenish_types = ["beam", "missile"]
	w1.min_active_drones = 2
	
	w1.initial_spawns = [
		WaveSpawnConfig.new("beam", 0.20, -50.0),
		WaveSpawnConfig.new("missile", 0.40, -50.0),
		WaveSpawnConfig.new("beam", 0.60, -50.0),
		WaveSpawnConfig.new("missile", 0.80, -50.0)
	]
	waves.append(w1)
	
	# Wave 2: Swarm Phase
	var w2 = WaveData.new()
	w2.wave_id = "wave2_swarm"
	w2.display_title = "WAVE 2: SWARM PHASE"
	w2.start_message = "WAVE 2: SWARM DETECTED\nELIMINATE 8 ENEMY DRONES"
	w2.clear_condition_type = "drone_count"
	w2.target_drone_count = 8
	w2.transition_delay = 4.0
	w2.replenish_types = ["beam", "missile"]
	w2.min_active_drones = 3
	w2.drone_speed_override = 220.0
	w2.drone_shoot_interval_beam = 1.0
	w2.drone_shoot_interval_missile = 1.5
	
	w2.initial_spawns = [
		WaveSpawnConfig.new("beam", 0.20, -50.0),
		WaveSpawnConfig.new("missile", 0.40, -50.0),
		WaveSpawnConfig.new("beam", 0.60, -50.0),
		WaveSpawnConfig.new("missile", 0.80, -50.0)
	]
	waves.append(w2)

func _setup_interlude() -> void:
	interlude.title = "CRITICAL WARNING: ANCIENT OVERLORD"
	interlude.subtitle = "MASSIVE ENERGY SPIKE DETECTED - 1500% ABOVE LIMIT"
	interlude.flash_color = Color(0.8, 0.0, 1.0, 0.5)
	interlude.secondary_flash_color = Color(1.0, 0.0, 0.0, 0.6)
	interlude.assist_message = "【AIアシスト】要塞級個体の接近を検知！高密度弾幕に注意してください。"
	interlude.duration = 4.0

func _setup_boss() -> void:
	boss_config.name = "古代防衛兵器・オーバーロード"
	boss_config.laser_hp = 700
	boss_config.missile_hp = 700
	boss_config.core_hp = 1800
	boss_config.max_hp = boss_config.laser_hp + boss_config.missile_hp + boss_config.core_hp
	boss_config.base_move_speed = 190.0
	boss_config.energy_laser = 45.0
	boss_config.energy_missile = 45.0
	boss_config.energy_core = 55.0
	boss_config.enable_support_drones = true
	boss_config.support_drone_interval = 20.0

func _setup_rewards() -> void:
	reward_config.counter_weapon_unlock = "boss_missile"
	reward_config.tech_points = 40
	reward_config.unlock_message = "【AIアシスト】ボス技術の回収成功！\n『ハイパーミサイル』がカウンター兵装で装備可能です。"
