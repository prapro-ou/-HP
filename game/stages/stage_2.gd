extends BaseStage
class_name Stage2

## ステージ2（防衛グリッド＆高難度スワームフェーズ）の設定クラス

func _ready_stage() -> void:
	stage_name = "PLANETARY STRATOSPHERE"
	stage_number = 2
	background_texture = preload("res://game/assets/backgrounds/backgrnd_stage2.png")
	_setup_waves()
	_setup_interlude()
	_setup_boss()
	_setup_rewards()

func _setup_waves() -> void:
	# Wave 1: 大気圏突入・雲海迎撃戦
	var w1 = WaveData.new()
	w1.wave_id = "wave1_sky"
	w1.display_title = "PHASE 1: 惑星地上上空・成層圏突入"
	w1.start_message = "【MISSION 02: 成層圏防衛突破戦】\n制限時間（90秒）まで高速迎撃部隊を撃破＆パリィせよ！\n変異スロットを強化してボス戦に備えてください！"
	w1.replenish_types = ["wave", "irregular", "laser", "charge"]
	w1.min_active_drones = 5
	w1.drone_speed_override = 180.0
	
	w1.initial_spawns = [
		WaveSpawnConfig.new("wave", 0.15, -50.0),
		WaveSpawnConfig.new("irregular", 0.35, -70.0),
		WaveSpawnConfig.new("laser", 0.65, -50.0),
		WaveSpawnConfig.new("charge", 0.85, -70.0)
	]
	waves.append(w1)
	
	# Wave 2: 地上迎撃エース編隊
	var w2 = WaveData.new()
	w2.wave_id = "wave2_sky_ace"
	w2.display_title = "PHASE 2: 成層圏中部・局地迎撃エース編隊"
	w2.start_message = "[ASSIST AI]: 地上防衛アレイからの高速ミサイル群接近！\nパリィ反射で敵部隊を殲滅せよ！"
	w2.replenish_types = ["missile", "charge", "laser", "irregular"]
	w2.min_active_drones = 5
	w2.drone_speed_override = 210.0
	
	w2.initial_spawns = [
		WaveSpawnConfig.new("missile", 0.12, -60.0),
		WaveSpawnConfig.new("charge", 0.35, -90.0),
		WaveSpawnConfig.new("laser", 0.65, -60.0),
		WaveSpawnConfig.new("missile", 0.88, -90.0)
	]
	waves.append(w2)

	# Wave 3: 成層圏制空重爆大隊
	var w3 = WaveData.new()
	w3.wave_id = "wave3_sky_carrier"
	w3.display_title = "PHASE 3: 雲海深部・制空重爆撃大隊"
	w3.start_message = "[ASSIST AI]: 敵重爆撃護衛大隊が集結！\n全方位波状攻撃をパリィで制圧し、要塞キャリアを引きずり出せ！"
	w3.replenish_types = ["charge", "missile", "laser", "wave", "irregular"]
	w3.min_active_drones = 6
	w3.drone_speed_override = 230.0
	
	w3.initial_spawns = [
		WaveSpawnConfig.new("charge", 0.10, -60.0),
		WaveSpawnConfig.new("missile", 0.28, -90.0),
		WaveSpawnConfig.new("laser", 0.50, -60.0),
		WaveSpawnConfig.new("wave", 0.72, -90.0),
		WaveSpawnConfig.new("missile", 0.90, -60.0)
	]
	waves.append(w3)

func _setup_interlude() -> void:
	interlude.title = "⚠️ CRITICAL WARNING ⚠️"
	interlude.subtitle = "成層圏重爆撃キャリア・ストーム出現！"
	interlude.flash_color = Color(0.2, 1.0, 0.4, 0.5)
	interlude.secondary_flash_color = Color(1.0, 0.5, 0.0, 0.6)
	interlude.assist_message = "【空中要塞接近】拡散爆撃と追尾ミサイルをパリィで反撃せよ！"
	interlude.duration = 4.0

func _setup_boss() -> void:
	boss_config.name = "成層圏重爆撃キャリア・ストーム"
	boss_config.max_hp = 8800
	boss_config.laser_hp = 1100
	boss_config.missile_hp = 1100
	boss_config.core_hp = 8800
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
