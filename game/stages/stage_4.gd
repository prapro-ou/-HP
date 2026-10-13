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
	waves = [
		patrol_wave(["missile", "irregular", "vortex"]),
		column_wave(["charge", "missile", "meteor", "straight"]),
		spread_cluster_wave(["missile", "wave", "missile"], ["meteor", "charge", "vortex"])
	]
func _setup_interlude() -> void:
	interlude.title = "CRITICAL WARNING"
	interlude.subtitle = "追撃自律ドレッドノート・ヘルハウンド出現！"
	interlude.flash_color = Color(0.9, 0.3, 1.0, 0.5)
	interlude.secondary_flash_color = Color(1.0, 0.1, 0.2, 0.6)
	interlude.assist_message = "追撃弾幕をパリィせよ"
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
	reward_config.counter_weapon_unlock = "gigantic_orb"
	reward_config.unlocked_stage = 5
	reward_config.unlock_message = "ギガエネルギー弾 解放\n装備画面で選択可能"