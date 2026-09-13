extends BaseStage
class_name Stage1

## ステージ1（チュートリアル＆基本波解析ステージ）の設定クラス

func _ready_stage() -> void:
	stage_name = "DEBRIS BELT INFILTRATION"
	stage_number = 1
	background_texture = preload("res://game/assets/backgrounds/backgrnd_stage1.png")
	_setup_waves()
	_setup_interlude()
	_setup_boss()
	_setup_rewards()

func _setup_waves() -> void:
	var w1 = WaveData.new()
	w1.wave_id = "wave1"
	w1.display_title = "SCAN 1: BLUE / RAPID"
	w1.start_message = "青い直進弾を狙ってパリィ\n4回で連射兵装を解析"
	w1.replenish_types = ["straight"]
	w1.min_active_drones = 3
	
	w1.initial_spawns = [
		WaveSpawnConfig.new("straight", 0.22, -50.0, true),
		WaveSpawnConfig.new("straight", 0.50, -80.0, false),
		WaveSpawnConfig.new("straight", 0.78, -50.0, true)
	]
	waves.append(w1)
	
	var w2 = WaveData.new()
	w2.wave_id = "wave2"
	w2.display_title = "SCAN 2: GREEN / SPREAD"
	w2.start_message = "緑の波状弾は軌道を読む\n近づけてからパリィ"
	w2.replenish_types = ["wave", "straight"]
	w2.min_active_drones = 4
	w2.drone_speed_override = 145.0
	
	w2.initial_spawns = [
		WaveSpawnConfig.new("wave", 0.18, -60.0, true),
		WaveSpawnConfig.new("straight", 0.40, -90.0, false),
		WaveSpawnConfig.new("wave", 0.62, -60.0, false),
		WaveSpawnConfig.new("wave", 0.84, -90.0, true)
	]
	waves.append(w2)

	var w3 = WaveData.new()
	w3.wave_id = "wave3"
	w3.display_title = "SCAN 3: RED / PIERCE"
	w3.start_message = "赤い突進弾は高リスク\n引きつけるほど反撃が映える"
	w3.replenish_types = ["charge", "wave", "straight"]
	w3.min_active_drones = 4
	w3.drone_speed_override = 160.0
	
	w3.initial_spawns = [
		WaveSpawnConfig.new("charge", 0.15, -60.0, true),
		WaveSpawnConfig.new("wave", 0.38, -90.0, false),
		WaveSpawnConfig.new("straight", 0.62, -60.0, false),
		WaveSpawnConfig.new("charge", 0.85, -90.0, true)
	]
	waves.append(w3)

func _setup_interlude() -> void:
	interlude.title = "WARNING"
	interlude.subtitle = "解析兵装を2つ選択せよ"
	interlude.flash_color = Color(0.2, 0.8, 1.0, 0.5)
	interlude.secondary_flash_color = Color(1.0, 0.2, 0.2, 0.6)
	interlude.assist_message = "選ばなかった兵装は、この出撃では使用できない"
	interlude.duration = 5.0

func _setup_boss() -> void:
	boss_config.name = "軌道防衛要塞ガーディアン"
	boss_config.laser_hp = 650
	boss_config.missile_hp = 650
	boss_config.core_hp = 4200
	boss_config.max_hp = 4200
	boss_config.base_move_speed = 0.0
	boss_config.enable_support_drones = true
	boss_config.support_drone_interval = 12.0

func _setup_rewards() -> void:
	reward_config.counter_weapon_unlock = "boss_beam"
	reward_config.tech_points = 15
	reward_config.unlock_message = "ギガレーザー解放\n装備画面で選択可能"
