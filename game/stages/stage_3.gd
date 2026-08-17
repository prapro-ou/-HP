extends BaseStage
class_name Stage3

## ステージ3（惑星内部施設・軍事工廠プラント）の設定クラス

func _ready_stage() -> void:
	stage_name = "CORE FACILITY DEPTHS"
	stage_number = 3
	_setup_waves()
	_setup_interlude()
	_setup_boss()
	_setup_rewards()

func _setup_waves() -> void:
	# Wave 1: 地底プラント防衛ライン
	var w1 = WaveData.new()
	w1.wave_id = "wave1_facility"
	w1.display_title = "第3エリア: 惑星内部・軍事工廠"
	w1.start_message = "【MISSION 03: 惑星内部施設侵入】\n惑星地底深くの中枢工廠へ突入！\n電磁プラズマと高出力ビームをパリィせよ！"
	w1.clear_condition_type = "analysis_or_parry"
	w1.target_analysis_count = 3
	w1.target_parry_count = 40
	w1.transition_delay = 2.5
	w1.completion_message = "【防壁突破】第1工廠ライン制圧！"
	w1.replenish_types = ["laser", "charge", "wave", "irregular"]
	w1.min_active_drones = 4
	
	w1.initial_spawns = [
		WaveSpawnConfig.new("laser", 0.15, -50.0),
		WaveSpawnConfig.new("charge", 0.35, -80.0),
		WaveSpawnConfig.new("laser", 0.65, -50.0),
		WaveSpawnConfig.new("charge", 0.85, -80.0)
	]
	waves.append(w1)
	
	# Wave 2: 中枢防衛ヘビーセキュリティ
	var w2 = WaveData.new()
	w2.wave_id = "wave2_facility_core"
	w2.display_title = "内部中枢: ヘビーセキュリティ部隊"
	w2.start_message = "[ASSIST AI]: 惑星中枢防衛セキュリティが最大稼働！\nチャージボルトと誘導弾の嵐をパリィで制圧せよ！"
	w2.clear_condition_type = "analysis_or_parry"
	w2.target_analysis_count = 4
	w2.target_parry_count = 50
	w2.transition_delay = 3.0
	w2.replenish_types = ["charge", "missile", "laser", "irregular", "wave"]
	w2.min_active_drones = 4
	w2.drone_speed_override = 250.0
	
	w2.initial_spawns = [
		WaveSpawnConfig.new("charge", 0.15, -60.0),
		WaveSpawnConfig.new("missile", 0.35, -90.0),
		WaveSpawnConfig.new("laser", 0.60, -60.0),
		WaveSpawnConfig.new("charge", 0.85, -90.0)
	]
	waves.append(w2)

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
