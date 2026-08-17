extends BaseStage
class_name Stage1

## ステージ1（チュートリアル＆基本波解析ステージ）の設定クラス

func _ready_stage() -> void:
	stage_name = "WAVE ANALYSIS STAGE"
	stage_number = 1
	_setup_waves()
	_setup_interlude()
	_setup_boss()
	_setup_rewards()

func _setup_waves() -> void:
	# Wave 1
	var w1 = WaveData.new()
	w1.wave_id = "wave1"
	w1.display_title = "第一波: 複合攻撃パターンの解析"
	w1.start_message = "【AIアシスト】装備システムオンライン。\nパリィを実行して敵弾データを解析・吸収してください！"
	w1.clear_condition_type = "analysis_or_parry"
	w1.target_analysis_count = 2
	w1.target_parry_count = 25
	w1.transition_delay = 2.5
	w1.completion_message = "【第一波 攻略完了】\n第一波の全攻撃パターンの解析に成功！"
	w1.replenish_types = ["straight", "irregular", "laser", "wave"]
	w1.min_active_drones = 3
	
	w1.initial_spawns = [
		WaveSpawnConfig.new("straight", 0.15, -50.0),
		WaveSpawnConfig.new("irregular", 0.32, -80.0),
		WaveSpawnConfig.new("wave", 0.50, -50.0),
		WaveSpawnConfig.new("laser", 0.68, -80.0),
		WaveSpawnConfig.new("straight", 0.85, -50.0)
	]
	waves.append(w1)
	
	# Wave 2
	var w2 = WaveData.new()
	w2.wave_id = "wave2"
	w2.display_title = "第二波: 重攻撃型編成"
	w2.start_message = "[ASSIST AI]: 第二波・重攻撃型編成を検知！\nチャージ射撃および追尾弾のデータをパリィで解析・吸収してください。"
	w2.clear_condition_type = "analysis_or_parry"
	w2.target_analysis_count = 3
	w2.target_parry_count = 35
	w2.transition_delay = 3.0
	w2.replenish_types = ["charge", "missile", "irregular", "laser"]
	w2.min_active_drones = 3
	
	w2.initial_spawns = [
		WaveSpawnConfig.new("charge", 0.18, -60.0),
		WaveSpawnConfig.new("missile", 0.38, -90.0),
		WaveSpawnConfig.new("laser", 0.62, -50.0),
		WaveSpawnConfig.new("charge", 0.82, -90.0)
	]
	waves.append(w2)

func _setup_interlude() -> void:
	interlude.title = "⚠️ WARNING ⚠️"
	interlude.subtitle = "超巨大要塞接近！最深部防壁を感知！"
	interlude.flash_color = Color(1.0, 0.0, 0.0, 0.5)
	interlude.assist_message = "【AIアシスト】\n超巨大要塞が出現！\nパリィ反射弾（8割）でサブ砲台デッキを集中撃破してください！"
	interlude.duration = 5.0

func _setup_boss() -> void:
	boss_config.name = "古代防衛要塞"
	boss_config.laser_hp = 900
	boss_config.missile_hp = 900
	boss_config.core_hp = 7500
	boss_config.max_hp = 7500
	boss_config.base_move_speed = 0.0
	boss_config.enable_support_drones = false

func _setup_rewards() -> void:
	reward_config.counter_weapon_unlock = "boss_beam"
	reward_config.tech_points = 30
	reward_config.unlock_message = "【AIアシスト】要塞解析データの回収成功！\n『ギガレーザー』がカウンター兵装で装備可能です。"
