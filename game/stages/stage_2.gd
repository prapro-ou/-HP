extends BaseStage
class_name Stage2

## ステージ2（防衛グリッド＆高難度スワームフェーズ）の設定クラス

func _ready_stage() -> void:
	stage_name = "PLANETARY STRATOSPHERE"
	stage_number = 2
	_setup_waves()
	_setup_interlude()
	_setup_boss()
	_setup_rewards()

func _setup_waves() -> void:
	# Wave 1: 大気圏突入・雲海迎撃戦
	var w1 = WaveData.new()
	w1.wave_id = "wave1_sky"
	w1.display_title = "第2エリア: 惑星地上上空・成層圏"
	w1.start_message = "【MISSION 02: 大気圏降下戦】\n雲海を切り裂く高速迎撃編隊を検知！\nパリィで高速プラズマ弾を跳ね返せ！"
	w1.clear_condition_type = "analysis_or_parry"
	w1.target_analysis_count = 3
	w1.target_parry_count = 38
	w1.transition_delay = 2.5
	w1.completion_message = "【成層圏突破】大気圏迎撃第1ライン突破！"
	w1.replenish_types = ["wave", "irregular", "laser", "charge"]
	w1.min_active_drones = 4
	
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
	w2.display_title = "地上上空: 局地迎撃エース編隊"
	w2.start_message = "[ASSIST AI]: 地上防衛アレイからの高速ミサイル群接近！\nパリィ反射で敵部隊を殲滅せよ！"
	w2.clear_condition_type = "analysis_or_parry"
	w2.target_analysis_count = 4
	w2.target_parry_count = 48
	w2.transition_delay = 3.0
	w2.replenish_types = ["missile", "charge", "laser", "irregular"]
	w2.min_active_drones = 4
	w2.drone_speed_override = 240.0
	
	w2.initial_spawns = [
		WaveSpawnConfig.new("missile", 0.15, -60.0),
		WaveSpawnConfig.new("charge", 0.38, -90.0),
		WaveSpawnConfig.new("laser", 0.62, -60.0),
		WaveSpawnConfig.new("missile", 0.85, -90.0)
	]
	waves.append(w2)

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
