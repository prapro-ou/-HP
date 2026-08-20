extends BaseStage
class_name Stage3

## ステージ3（惑星内部施設・軍事工廠プラント）の設定クラス

func _ready_stage() -> void:
	stage_name = "CORE FACILITY DEPTHS"
	stage_number = 3
	var bg_path = "res://game/assets/backgrounds/backgrnd_stage3.png"
	if ResourceLoader.exists(bg_path):
		background_texture = load(bg_path)

	_setup_waves()
	_setup_interlude()
	_setup_boss()
	_setup_rewards()

func _setup_waves() -> void:
	# Wave 1: 地底プラント防衛ライン
	var w1 = WaveData.new()
	w1.wave_id = "wave1_facility"
	w1.display_title = "PHASE 1: 惑星内部・軍事工廠前衛"
	w1.start_message = "【MISSION 03: 惑星内部工廠・制圧戦】\n制限時間（90秒）まで工廠警備部隊を殲滅せよ！\n電磁プラズマと高出力ビームをパリィで制圧せよ！"
	w1.clear_condition_type = "analysis_or_parry"
	w1.target_drone_count = 15
	w1.target_parry_count = 25
	w1.transition_delay = 2.2
	w1.completion_message = "【PHASE 1 突破】第1工廠ライン制圧！"
	w1.replenish_types = ["laser", "charge", "wave", "irregular"]
	w1.min_active_drones = 5
	w1.drone_speed_override = 200.0
	
	w1.initial_spawns = [
		WaveSpawnConfig.new("laser", 0.15, -50.0),
		WaveSpawnConfig.new("charge", 0.35, -80.0),
		WaveSpawnConfig.new("laser", 0.65, -50.0),
		WaveSpawnConfig.new("charge", 0.85, -80.0)
	]
	waves.append(w1)
	
	# Wave 2: プラズマ工廠警備部隊
	var w2 = WaveData.new()
	w2.wave_id = "wave2_facility_core"
	w2.display_title = "PHASE 2: 高度軍事プラント・警備大隊"
	w2.start_message = "[ASSIST AI]: 惑星中枢防衛セキュリティが最大稼働！\nチャージボルトと誘導弾の嵐をパリィで制圧せよ！"
	w2.clear_condition_type = "analysis_or_parry"
	w2.target_drone_count = 20
	w2.target_parry_count = 35
	w2.transition_delay = 2.5
	w2.completion_message = "【PHASE 2 制圧】工廠警備大隊を完全壊滅！"
	w2.replenish_types = ["charge", "missile", "laser", "irregular", "wave"]
	w2.min_active_drones = 5
	w2.drone_speed_override = 220.0
	
	w2.initial_spawns = [
		WaveSpawnConfig.new("charge", 0.15, -60.0),
		WaveSpawnConfig.new("missile", 0.35, -90.0),
		WaveSpawnConfig.new("laser", 0.60, -60.0),
		WaveSpawnConfig.new("charge", 0.85, -90.0)
	]
	waves.append(w2)

	# Wave 3: 中枢ヘビーセキュリティ総動員
	var w3 = WaveData.new()
	w3.wave_id = "wave3_facility_overdrive"
	w3.display_title = "PHASE 3: コア直轄・ヘビーセキュリティ総動員"
	w3.start_message = "[ASSIST AI]: 最終迎撃セキュリティが限界突破！\n全方位から迫る重弾幕をパリィ反射し、コロッサスコアを解放せよ！"
	w3.clear_condition_type = "analysis_or_parry"
	w3.target_drone_count = 25
	w3.target_parry_count = 45
	w3.transition_delay = 3.0
	w3.completion_message = "【PHASE 3 突破】工廠中枢を完全制圧！巨大コア起動！"
	w3.replenish_types = ["laser", "charge", "missile", "wave", "irregular"]
	w3.min_active_drones = 6
	w3.drone_speed_override = 240.0
	
	w3.initial_spawns = [
		WaveSpawnConfig.new("laser", 0.10, -60.0),
		WaveSpawnConfig.new("missile", 0.30, -90.0),
		WaveSpawnConfig.new("charge", 0.50, -60.0),
		WaveSpawnConfig.new("wave", 0.70, -90.0),
		WaveSpawnConfig.new("laser", 0.90, -60.0)
	]
	waves.append(w3)

func _setup_interlude() -> void:
	interlude.title = "⚠️ CRITICAL WARNING ⚠️"
	interlude.subtitle = "中枢防衛プラント・コロッサスコア起動！"
	interlude.flash_color = Color(1.0, 0.7, 0.2, 0.5)
	interlude.secondary_flash_color = Color(1.0, 0.1, 0.1, 0.6)
	interlude.assist_message = "【中枢要塞接近】超高出力電磁砲門をパリィで破砕せよ！"
	interlude.duration = 4.0

func _setup_boss() -> void:
	boss_config.name = "中枢防衛プラント・コロッサスコア"
	boss_config.max_hp = 10500
	boss_config.laser_hp = 1300
	boss_config.missile_hp = 1300
	boss_config.core_hp = 10500
	boss_config.base_move_speed = 180.0

func _setup_rewards() -> void:
	reward_config.tech_points = 45
	reward_config.unlocked_stage = 4
	reward_config.unlock_message = "【作戦完了】STAGE 4: 惑星内部からの脱出が解放されました！"
