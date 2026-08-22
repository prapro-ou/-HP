extends BaseStage
class_name Stage5

## ステージ5（惑星そのものの破壊・最終決戦）の設定クラス

func _ready_stage() -> void:
	stage_name = "PLANETARY EXTINCTION"
	stage_number = 5
	var bg_path = "res://game/assets/backgrounds/backgrnd_stage5.png"
	if ResourceLoader.exists(bg_path):
		background_texture = load(bg_path)

	_setup_waves()
	_setup_interlude()
	_setup_boss()
	_setup_rewards()

func _setup_waves() -> void:
	# Wave 1: 覚醒惑星外縁・超高密度前哨戦
	var w1 = WaveData.new()
	w1.wave_id = "wave1_gaia"
	w1.display_title = "FINAL PHASE 1: 覚醒惑星外縁・超生体弾幕群"
	w1.start_message = "【FINAL MISSION: 惑星覚醒・決戦前哨】\n制限時間（90秒）まで星を覆う超生体弾幕群を撃ち返せ！\nフルバーストビルドを完成させて惑星コアを粉砕せよ！"
	w1.replenish_types = ["straight", "laser", "charge", "missile", "wave", "irregular"]
	w1.min_active_drones = 5
	w1.drone_speed_override = 230.0
	
	w1.initial_spawns = [
		WaveSpawnConfig.new("laser", 0.10, -60.0),
		WaveSpawnConfig.new("charge", 0.28, -80.0),
		WaveSpawnConfig.new("missile", 0.46, -60.0),
		WaveSpawnConfig.new("wave", 0.64, -80.0),
		WaveSpawnConfig.new("irregular", 0.82, -60.0),
		WaveSpawnConfig.new("straight", 0.95, -80.0)
	]
	waves.append(w1)
	
	# Wave 2: 惑星生体中枢・直衛エリート軍団
	var w2 = WaveData.new()
	w2.wave_id = "wave2_gaia_elite"
	w2.display_title = "FINAL PHASE 2: 惑星生体中枢・終焉のエリート軍団"
	w2.start_message = "[ASSIST AI]: 惑星全エネルギーが集中！\n限界突破パリィで全属性Lv.2を完全解放せよ！"
	w2.replenish_types = ["charge", "missile", "laser", "irregular", "wave"]
	w2.min_active_drones = 6
	w2.drone_speed_override = 250.0
	
	w2.initial_spawns = [
		WaveSpawnConfig.new("charge", 0.12, -70.0),
		WaveSpawnConfig.new("missile", 0.30, -90.0),
		WaveSpawnConfig.new("laser", 0.50, -70.0),
		WaveSpawnConfig.new("wave", 0.70, -90.0),
		WaveSpawnConfig.new("charge", 0.88, -70.0)
	]
	waves.append(w2)

	# Wave 3: 惑星コア直轄・怒涛の最終防衛ライン
	var w3 = WaveData.new()
	w3.wave_id = "wave3_gaia_core_guard"
	w3.display_title = "FINAL PHASE 3: 惑星コア直結・怒涛の最終防衛網"
	w3.start_message = "[ASSIST AI]: 惑星防衛システムが全開稼働！\n完成したフルバーストビルドで大群を殲滅せよ！"
	w3.replenish_types = ["laser", "missile", "charge", "wave", "irregular"]
	w3.min_active_drones = 6
	w3.drone_speed_override = 260.0
	
	w3.initial_spawns = [
		WaveSpawnConfig.new("laser", 0.10, -70.0),
		WaveSpawnConfig.new("charge", 0.28, -90.0),
		WaveSpawnConfig.new("missile", 0.46, -70.0),
		WaveSpawnConfig.new("wave", 0.64, -90.0),
		WaveSpawnConfig.new("laser", 0.82, -70.0),
		WaveSpawnConfig.new("irregular", 0.95, -90.0)
	]
	waves.append(w3)

	# Wave 4: 惑星覚醒クライマックス・終焉の超弾幕ラッシュ
	var w4 = WaveData.new()
	w4.wave_id = "wave4_gaia_awakening"
	w4.display_title = "FINAL PHASE 4: 惑星完全覚醒・終焉の超弾幕ラッシュ"
	w4.start_message = "[ASSIST AI]: 惑星超生体が臨界点に到達！\nすべての弾丸をパリィで撃ち返し、本体を顕現させよ！"
	w4.replenish_types = ["charge", "missile", "laser", "irregular", "wave", "straight"]
	w4.min_active_drones = 7
	w4.drone_speed_override = 280.0
	
	w4.initial_spawns = [
		WaveSpawnConfig.new("charge", 0.10, -70.0),
		WaveSpawnConfig.new("missile", 0.25, -90.0),
		WaveSpawnConfig.new("laser", 0.45, -70.0),
		WaveSpawnConfig.new("wave", 0.65, -90.0),
		WaveSpawnConfig.new("missile", 0.80, -70.0),
		WaveSpawnConfig.new("charge", 0.92, -90.0)
	]
	waves.append(w4)

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
