extends BaseStage
class_name Stage1

## ステージ1（チュートリアル＆基本波解析ステージ）の設定クラス

func _ready_stage() -> void:
	stage_name = "DEBRIS BELT INFILTRATION"
	stage_number = 1
	var bg_path = "res://game/assets/backgrounds/backgrnd_stage1.png"
	if ResourceLoader.exists(bg_path):
		background_texture = load(bg_path)

	_setup_waves()
	_setup_interlude()
	_setup_boss()
	_setup_rewards()

func _setup_waves() -> void:
	# Wave 1 (惑星到達前デブリ帯・前哨解析フェーズ)
	var w1 = WaveData.new()
	w1.wave_id = "wave1"
	w1.display_title = "PHASE 1: 惑星外縁・デブリ帯前哨"
	w1.start_message = "【MISSION 01: デブリ帯防衛・解析戦】\n制限時間（90秒）まで敵部隊を撃破＆パリィせよ！\n敵弾データを解析・反射して自機兵装を覚醒させてください！"
	w1.replenish_types = ["straight", "wave", "irregular"]
	w1.min_active_drones = 4
	
	w1.initial_spawns = [
		WaveSpawnConfig.new("straight", 0.15, -50.0),
		WaveSpawnConfig.new("wave", 0.35, -80.0),
		WaveSpawnConfig.new("straight", 0.65, -50.0),
		WaveSpawnConfig.new("irregular", 0.85, -80.0)
	]
	waves.append(w1)
	
	# Wave 2 (重装哨戒部隊・攻撃パターンの多様化)
	var w2 = WaveData.new()
	w2.wave_id = "wave2"
	w2.display_title = "PHASE 2: デブリ帯深部・重装哨戒編隊"
	w2.start_message = "[ASSIST AI]: 軌道哨戒編隊が接近！\nチャージ射撃・レーザーをパリィして変異兵装を解放せよ！"
	w2.replenish_types = ["charge", "laser", "irregular", "straight", "wave"]
	w2.min_active_drones = 5
	w2.drone_speed_override = 160.0
	
	w2.initial_spawns = [
		WaveSpawnConfig.new("charge", 0.12, -60.0),
		WaveSpawnConfig.new("laser", 0.32, -90.0),
		WaveSpawnConfig.new("irregular", 0.50, -60.0),
		WaveSpawnConfig.new("charge", 0.68, -90.0),
		WaveSpawnConfig.new("wave", 0.88, -60.0)
	]
	waves.append(w2)

	# Wave 3 (要塞直衛エリート編隊・フルパワー激突)
	var w3 = WaveData.new()
	w3.wave_id = "wave3"
	w3.display_title = "PHASE 3: 要塞警戒宙域・直衛エリート部隊"
	w3.start_message = "[ASSIST AI]: 要塞直衛部隊が全方位展開！\n誘導ミサイルと集中弾幕をパリィし、最大変異Lv.2を覚醒せよ！"
	w3.replenish_types = ["missile", "charge", "laser", "irregular", "wave", "straight"]
	w3.min_active_drones = 6
	w3.drone_speed_override = 180.0
	
	w3.initial_spawns = [
		WaveSpawnConfig.new("missile", 0.10, -60.0),
		WaveSpawnConfig.new("charge", 0.28, -90.0),
		WaveSpawnConfig.new("laser", 0.46, -60.0),
		WaveSpawnConfig.new("wave", 0.64, -90.0),
		WaveSpawnConfig.new("irregular", 0.80, -60.0),
		WaveSpawnConfig.new("missile", 0.92, -90.0)
	]
	waves.append(w3)

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
