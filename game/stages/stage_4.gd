extends BaseStage
class_name Stage4

## ステージ4（惑星内部からの脱出・崩壊地底ルート）の設定クラス

func _ready_stage() -> void:
	stage_name = "ESCAPE FROM THE CORE"
	stage_number = 4
	background_texture = preload("res://game/assets/backgrounds/backgrnd_stage4.png")
	boss_background_texture = preload("res://game/assets/backgrounds/backgrnd_stage4_boss.png")
	_setup_waves()
	_setup_interlude()
	_setup_boss()
	_setup_rewards()

func _setup_waves() -> void:
	# Wave 1: 崩壊地底ルート・緊急脱出
	var w1 = WaveData.new()
	w1.wave_id = "wave1_escape"
	w1.display_title = "PHASE 1: 崩壊地底・緊急脱出ルート"
	w1.start_message = "【MISSION 04: 崩壊地底脱出サバイバル】\n制限時間（90秒）まで追撃部隊を振り切れ！\n高速ミサイルと破砕弾をパリィで突破せよ！"
	w1.replenish_types = ["missile", "irregular", "laser", "charge"]
	w1.min_active_drones = 5
	w1.drone_speed_override = 220.0
	
	w1.initial_spawns = [
		WaveSpawnConfig.new("missile", 0.15, -60.0),
		WaveSpawnConfig.new("irregular", 0.35, -80.0),
		WaveSpawnConfig.new("missile", 0.65, -60.0),
		WaveSpawnConfig.new("irregular", 0.85, -80.0)
	]
	waves.append(w1)
	
	# Wave 2: 追撃自律殲滅包囲網
	var w2 = WaveData.new()
	w2.wave_id = "wave2_pursuit"
	w2.display_title = "PHASE 2: 地底脱出中間点・自律殲滅包囲網"
	w2.start_message = "[ASSIST AI]: 追撃自律部隊の挟撃を検知！\n全方位からの重弾幕をパリィして地表へ脱出せよ！"
	w2.replenish_types = ["charge", "missile", "laser", "wave", "irregular"]
	w2.min_active_drones = 5
	w2.drone_speed_override = 240.0
	
	w2.initial_spawns = [
		WaveSpawnConfig.new("charge", 0.12, -70.0),
		WaveSpawnConfig.new("missile", 0.32, -90.0),
		WaveSpawnConfig.new("laser", 0.52, -60.0),
		WaveSpawnConfig.new("missile", 0.72, -90.0),
		WaveSpawnConfig.new("charge", 0.90, -70.0)
	]
	waves.append(w2)

	# Wave 3: 地表出口直前・超重追撃大編隊
	var w3 = WaveData.new()
	w3.wave_id = "wave3_dread_escort"
	w3.display_title = "PHASE 3: 脱出ルート出口・最終追撃大編隊"
	w3.start_message = "[ASSIST AI]: ドレッドノート直属の追撃大隊が襲来！\n全兵装の最大火力を解放し、地表へ抜け出せ！"
	w3.replenish_types = ["missile", "charge", "laser", "irregular", "wave"]
	w3.min_active_drones = 6
	w3.drone_speed_override = 260.0
	
	w3.initial_spawns = [
		WaveSpawnConfig.new("missile", 0.10, -60.0),
		WaveSpawnConfig.new("charge", 0.30, -90.0),
		WaveSpawnConfig.new("laser", 0.50, -60.0),
		WaveSpawnConfig.new("missile", 0.70, -90.0),
		WaveSpawnConfig.new("charge", 0.90, -60.0)
	]
	waves.append(w3)

func _setup_interlude() -> void:
	interlude.title = "CRITICAL WARNING"
	interlude.subtitle = "追撃自律ドレッドノート・ヘルハウンド出現！"
	interlude.flash_color = Color(0.9, 0.3, 1.0, 0.5)
	interlude.secondary_flash_color = Color(1.0, 0.1, 0.2, 0.6)
	interlude.assist_message = "【逃走阻止型要塞接近】猛烈な追撃弾幕をパリィで粉砕せよ！"
	interlude.duration = 4.0

func _setup_boss() -> void:
	boss_config.name = "追撃自律ドレッドノート・ヘルハウンド"
	boss_config.max_hp = 12000
	boss_config.laser_hp = 1500
	boss_config.missile_hp = 1500
	boss_config.core_hp = 12000
	boss_config.base_move_speed = 210.0

func _setup_rewards() -> void:
	reward_config.tech_points = 30
	reward_config.unlocked_stage = 5
	reward_config.unlock_message = "【作戦完了】FINAL STAGE: 惑星そのものの破壊が解放されました！"
