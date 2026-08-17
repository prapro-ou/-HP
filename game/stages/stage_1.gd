extends BaseStage
class_name Stage1

## ステージ1（チュートリアル＆基本波解析ステージ）の設定クラス

func _ready_stage() -> void:
	stage_name = "DEBRIS BELT INFILTRATION"
	stage_number = 1
	_setup_waves()
	_setup_interlude()
	_setup_boss()
	_setup_rewards()

func _setup_waves() -> void:
	# Wave 1 (惑星到達前デブリ帯・前哨解析)
	var w1 = WaveData.new()
	w1.wave_id = "wave1"
	w1.display_title = "第1エリア: 惑星到達前・デブリ帯"
	w1.start_message = "【MISSION 01: デブリ帯突破】\n惑星軌道上に広がる残骸宙域を突破せよ！\nパリィを実行して敵弾データを解析・吸収してください！"
	w1.clear_condition_type = "analysis_or_parry"
	w1.target_analysis_count = 3
	w1.target_parry_count = 36
	w1.transition_delay = 2.5
	w1.completion_message = "【前哨突破】デブリ帯迎撃網の解析完了！"
	w1.replenish_types = ["straight", "irregular", "laser", "wave", "charge", "missile"]
	w1.min_active_drones = 4
	
	w1.initial_spawns = [
		WaveSpawnConfig.new("straight", 0.12, -50.0),
		WaveSpawnConfig.new("irregular", 0.28, -80.0),
		WaveSpawnConfig.new("wave", 0.44, -50.0),
		WaveSpawnConfig.new("laser", 0.60, -80.0),
		WaveSpawnConfig.new("charge", 0.76, -50.0),
		WaveSpawnConfig.new("missile", 0.90, -80.0)
	]
	waves.append(w1)
	
	# Wave 2 (重装哨戒部隊)
	var w2 = WaveData.new()
	w2.wave_id = "wave2"
	w2.display_title = "デブリ帯深部: 重装哨戒編隊"
	w2.start_message = "[ASSIST AI]: 軌道哨戒編隊が接近！\nチャージ射撃・追尾弾をパリィして自機兵装を覚醒させよ！"
	w2.clear_condition_type = "analysis_or_parry"
	w2.target_analysis_count = 4
	w2.target_parry_count = 48
	w2.transition_delay = 3.0
	w2.replenish_types = ["charge", "missile", "irregular", "laser", "wave", "straight"]
	w2.min_active_drones = 4
	
	w2.initial_spawns = [
		WaveSpawnConfig.new("charge", 0.15, -60.0),
		WaveSpawnConfig.new("missile", 0.30, -90.0),
		WaveSpawnConfig.new("laser", 0.48, -50.0),
		WaveSpawnConfig.new("wave", 0.65, -90.0),
		WaveSpawnConfig.new("irregular", 0.82, -60.0),
		WaveSpawnConfig.new("charge", 0.95, -90.0)
	]
	waves.append(w2)

func _setup_interlude() -> void:
	interlude.title = "⚠️ WARNING ⚠️"
	interlude.subtitle = "軌道防衛要塞ガーディアン接近！"
	interlude.flash_color = Color(0.2, 0.8, 1.0, 0.5)
	interlude.secondary_flash_color = Color(1.0, 0.2, 0.2, 0.6)
	interlude.assist_message = "【要塞コア接近】サブ砲台を破壊し、コアの暴走弾幕を跳ね返せ！"
	interlude.duration = 5.0

func _setup_boss() -> void:
	boss_config.name = "軌道防衛要塞ガーディアン"
	boss_config.laser_hp = 900
	boss_config.missile_hp = 900
	boss_config.core_hp = 7500
	boss_config.max_hp = 7500
	boss_config.base_move_speed = 0.0
	boss_config.enable_support_drones = true
	boss_config.support_drone_interval = 8.0

func _setup_rewards() -> void:
	reward_config.counter_weapon_unlock = "boss_beam"
	reward_config.tech_points = 30
	reward_config.unlock_message = "【AIアシスト】要塞解析データの回収成功！\n『ギガレーザー』がカウンター兵装で装備可能です。"
