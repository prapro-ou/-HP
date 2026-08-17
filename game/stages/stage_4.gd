extends BaseStage
class_name Stage4

## ステージ4（惑星内部からの脱出・崩壊地底ルート）の設定クラス

func _ready_stage() -> void:
	stage_name = "ESCAPE FROM THE CORE"
	stage_number = 4
	_setup_waves()
	_setup_interlude()
	_setup_boss()
	_setup_rewards()

func _setup_waves() -> void:
	# Wave 1: 崩壊地底ルート・緊急脱出
	var w1 = WaveData.new()
	w1.wave_id = "wave1_escape"
	w1.display_title = "第4エリア: 崩壊地底・脱出ルート"
	w1.start_message = "【MISSION 04: 惑星内部脱出】\n中枢コア崩壊！地底崩落と追撃部隊を振り切れ！\n高速ミサイルと破砕弾をパリィで突破せよ！"
	w1.clear_condition_type = "analysis_or_parry"
	w1.target_analysis_count = 3
	w1.target_parry_count = 42
	w1.transition_delay = 2.5
	w1.completion_message = "【脱出加速】地底第1隔壁突破！"
	w1.replenish_types = ["missile", "irregular", "laser", "charge"]
	w1.min_active_drones = 4
	
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
	w2.display_title = "脱出ルート出口: 追撃殲滅包囲網"
	w2.start_message = "[ASSIST AI]: 追撃自律部隊の挟撃を検知！\n全方位からの重弾幕をパリィして地表へ脱出せよ！"
	w2.clear_condition_type = "analysis_or_parry"
	w2.target_analysis_count = 4
	w2.target_parry_count = 52
	w2.transition_delay = 3.0
	w2.replenish_types = ["charge", "missile", "laser", "wave", "irregular"]
	w2.min_active_drones = 5
	w2.drone_speed_override = 260.0
	
	w2.initial_spawns = [
		WaveSpawnConfig.new("charge", 0.12, -70.0),
		WaveSpawnConfig.new("missile", 0.32, -90.0),
		WaveSpawnConfig.new("laser", 0.52, -60.0),
		WaveSpawnConfig.new("missile", 0.72, -90.0),
		WaveSpawnConfig.new("charge", 0.90, -70.0)
	]
	waves.append(w2)

func _setup_interlude() -> void:
	interlude.title = "⚠️ CRITICAL WARNING ⚠️"
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
	reward_config.tech_points = 55
	reward_config.unlocked_stage = 5
	reward_config.unlock_message = "【作戦完了】FINAL STAGE: 惑星そのものの破壊が解放されました！"
