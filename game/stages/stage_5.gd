extends BaseStage
class_name Stage5

## ステージ5（惑星そのものの破壊・最終決戦）の設定クラス

func _ready_stage() -> void:
	stage_name = "PLANETARY EXTINCTION"
	stage_number = 5
	_setup_waves()
	_setup_interlude()
	_setup_boss()
	_setup_rewards()

func _setup_waves() -> void:
	# Wave 1: 覚醒惑星外縁・超高密度前哨戦
	var w1 = WaveData.new()
	w1.wave_id = "wave1_gaia"
	w1.display_title = "最終エリア: 覚醒惑星・終焉の宙域"
	w1.start_message = "【FINAL MISSION: 惑星破壊】\n惑星そのものが超生体覚醒！\n星を覆う超高密度弾幕をパリィで撃ち返せ！"
	w1.clear_condition_type = "analysis_or_parry"
	w1.target_analysis_count = 4
	w1.target_parry_count = 45
	w1.transition_delay = 2.5
	w1.completion_message = "【最終防壁破砕】惑星コア本体との直結を確認！"
	w1.replenish_types = ["straight", "laser", "charge", "missile", "wave", "irregular"]
	w1.min_active_drones = 5
	
	w1.initial_spawns = [
		WaveSpawnConfig.new("laser", 0.10, -60.0),
		WaveSpawnConfig.new("charge", 0.28, -80.0),
		WaveSpawnConfig.new("missile", 0.46, -60.0),
		WaveSpawnConfig.new("wave", 0.64, -80.0),
		WaveSpawnConfig.new("irregular", 0.82, -60.0),
		WaveSpawnConfig.new("straight", 0.95, -80.0)
	]
	waves.append(w1)
	
	# Wave 2: 惑星中枢直衛エリート軍団
	var w2 = WaveData.new()
	w2.wave_id = "wave2_gaia_elite"
	w2.display_title = "惑星直衛: 終焉のエリート軍団"
	w2.start_message = "[ASSIST AI]: 惑星全エネルギーが集中！\n限界突破パリィで全属性Lv.2を完全解放せよ！"
	w2.clear_condition_type = "analysis_or_parry"
	w2.target_analysis_count = 4
	w2.target_parry_count = 55
	w2.transition_delay = 3.0
	w2.replenish_types = ["charge", "missile", "laser", "irregular", "wave"]
	w2.min_active_drones = 5
	w2.drone_speed_override = 270.0
	
	w2.initial_spawns = [
		WaveSpawnConfig.new("charge", 0.12, -70.0),
		WaveSpawnConfig.new("missile", 0.30, -90.0),
		WaveSpawnConfig.new("laser", 0.50, -70.0),
		WaveSpawnConfig.new("wave", 0.70, -90.0),
		WaveSpawnConfig.new("charge", 0.88, -70.0)
	]
	waves.append(w2)

func _setup_interlude() -> void:
	interlude.title = "💥 FINAL WARNING: PLANETARY AWAKENING 💥"
	interlude.subtitle = "惑星融合型超兵器・ガイア・カタストロフ覚醒！"
	interlude.flash_color = Color(1.0, 0.1, 0.2, 0.7)
	interlude.secondary_flash_color = Color(1.0, 0.8, 0.0, 0.8)
	interlude.assist_message = "【惑星級決戦】全弾丸をパリィで反射し、惑星そのものを完全粉砕せよ！"
	interlude.duration = 5.0

func _setup_boss() -> void:
	boss_config.name = "惑星融合型超兵器・ガイア"
	boss_config.max_hp = 15000
	boss_config.laser_hp = 1800
	boss_config.missile_hp = 1800
	boss_config.core_hp = 15000
	boss_config.base_move_speed = 220.0

func _setup_rewards() -> void:
	reward_config.tech_points = 100
	reward_config.unlock_message = "🎉 全作戦完了！惑星の粉砕に成功し、銀河の平和は守られた！"
