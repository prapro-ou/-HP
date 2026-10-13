extends BaseStage
class_name Stage1

## ステージ1（チュートリアル＆基本波解析ステージ）の設定クラス

func _ready_stage() -> void:
	stage_name = "DEBRIS BELT INFILTRATION"
	stage_number = 1
	background_texture = preload("res://game/assets/backgrounds/backgrnd_stage1.png")
	_setup_waves()
	_setup_interlude()
	_setup_boss()
	_setup_rewards()

func _setup_waves() -> void:
	waves = [
		patrol_wave(["straight", "straight"]),
		column_wave(["straight", "wave", "straight"]),
		spread_cluster_wave(["wave", "straight", "wave"], ["charge", "wave", "charge"])
	]
func _setup_interlude() -> void:
	interlude.title = "WARNING"
	interlude.subtitle = "捕まえた弾でボスへ追撃せよ"
	interlude.flash_color = Color(0.2, 0.8, 1.0, 0.5)
	interlude.secondary_flash_color = Color(1.0, 0.2, 0.2, 0.6)
	interlude.assist_message = "選ばなかった兵装は、この出撃では使用できない"
	interlude.duration = 5.0

func _setup_boss() -> void:
	boss_config.name = "軌道防衛要塞ガーディアン"
	boss_config.laser_hp = 650
	boss_config.missile_hp = 650
	boss_config.core_hp = 4200
	boss_config.max_hp = 4200
	boss_config.base_move_speed = 0.0
	boss_config.enable_support_drones = true
	boss_config.support_drone_interval = 12.0

func _setup_rewards() -> void:
	reward_config.counter_weapon_unlock = "boss_beam"
	reward_config.tech_points = 15
	reward_config.unlock_message = "ギガレーザー解放\n装備画面で選択可能"