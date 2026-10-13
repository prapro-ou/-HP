extends BaseStage
class_name Stage3

## ステージ3（惑星内部施設・軍事工廠プラント）の設定クラス

func _ready_stage() -> void:
	stage_name = "CORE FACILITY DEPTHS"
	stage_number = 3
	background_texture = preload("res://game/assets/backgrounds/backgrnd_stage3.png")
	_setup_waves()
	_setup_interlude()
	_setup_boss()
	_setup_rewards()

func _setup_waves() -> void:
	waves = [
		patrol_wave(["laser", "thunder", "blade"]),
		column_wave(["charge", "laser", "blade", "straight"]),
		spread_cluster_wave(["wave", "thunder", "wave"], ["charge", "laser", "blade"])
	]
func _setup_interlude() -> void:
	interlude.title = "CRITICAL WARNING"
	interlude.subtitle = "中枢防衛プラント・コロッサスコア起動！"
	interlude.flash_color = Color(1.0, 0.7, 0.2, 0.5)
	interlude.secondary_flash_color = Color(1.0, 0.1, 0.1, 0.6)
	interlude.assist_message = "電磁砲をパリィせよ"
	interlude.duration = 4.0

func _setup_boss() -> void:
	boss_config.name = "中枢防衛プラント・コロッサスコア"
	boss_config.max_hp = 10500
	boss_config.laser_hp = 1300
	boss_config.missile_hp = 1300
	boss_config.core_hp = 10500
	boss_config.base_move_speed = 180.0

func _setup_rewards() -> void:
	reward_config.tech_points = 25
	reward_config.unlocked_stage = 4
	reward_config.unlock_message = "STAGE 4 解放\n脱出作戦へ"
