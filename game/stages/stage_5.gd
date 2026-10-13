extends BaseStage
class_name Stage5

## ステージ5（惑星そのものの破壊・最終決戦）の設定クラス

func _ready_stage() -> void:
	stage_name = "PLANETARY EXTINCTION"
	stage_number = 5
	background_texture = preload("res://game/assets/backgrounds/backgrnd_stage5.png")
	_setup_waves()
	_setup_interlude()
	_setup_boss()
	_setup_rewards()

func _setup_waves() -> void:
	waves = [
		patrol_wave(["laser", "thunder", "blade"]),
		column_wave(["charge", "laser", "missile", "straight"]),
		spread_cluster_wave(["wave", "irregular", "wave"], ["meteor", "vortex", "charge"]),
		patrol_wave(["charge", "missile", "thunder", "meteor"], "final_patrol")
	]
func _setup_interlude() -> void:
	interlude.title = "FINAL WARNING: PLANETARY AWAKENING"
	interlude.subtitle = "惑星融合型超兵器・ガイア・カタストロフ覚醒！"
	interlude.flash_color = Color(1.0, 0.1, 0.2, 0.7)
	interlude.secondary_flash_color = Color(1.0, 0.8, 0.0, 0.8)
	interlude.assist_message = "全弾をパリィし、コアを破壊せよ"
	interlude.duration = 5.0

func _setup_boss() -> void:
	boss_config.name = "惑星融合型超兵器・ガイア"
	boss_config.max_hp = 15000
	boss_config.laser_hp = 1800
	boss_config.missile_hp = 1800
	boss_config.core_hp = 15000
	boss_config.base_move_speed = 220.0

func _setup_rewards() -> void:
	reward_config.tech_points = 50
	reward_config.counter_weapon_unlock = "chain_explosions"
	reward_config.unlock_message = "全作戦完了\n5連鎖スーパーノヴァ 解放"