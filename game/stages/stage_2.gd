extends BaseStage
class_name Stage2

## ステージ2（防衛グリッド＆高難度スワームフェーズ）の設定クラス

func _ready_stage() -> void:
	stage_name = "PLANETARY STRATOSPHERE"
	stage_number = 2
	background_texture = preload("res://game/assets/backgrounds/backgrnd_stage2.png")
	_setup_waves()
	_setup_interlude()
	_setup_boss()
	_setup_rewards()

func _setup_waves() -> void:
	waves = [
		patrol_wave(["wave", "irregular"]),
		column_wave(["laser", "straight", "missile"]),
		spread_cluster_wave(["wave", "laser", "wave"], ["charge", "missile", "charge"])
	]
func _setup_interlude() -> void:
	interlude.title = "CRITICAL WARNING"
	interlude.subtitle = "成層圏重爆撃キャリア・ストーム出現！"
	interlude.flash_color = Color(0.2, 1.0, 0.4, 0.5)
	interlude.secondary_flash_color = Color(1.0, 0.5, 0.0, 0.6)
	interlude.assist_message = "爆撃と追尾弾をパリィせよ"
	interlude.duration = 4.0

func _setup_boss() -> void:
	boss_config.name = "成層圏重爆撃キャリア・ストーム"
	boss_config.max_hp = 8800
	boss_config.laser_hp = 1100
	boss_config.missile_hp = 1100
	boss_config.core_hp = 8800
	boss_config.base_move_speed = 190.0
	boss_config.energy_laser = 45.0
	boss_config.energy_missile = 45.0
	boss_config.energy_core = 55.0
	boss_config.enable_support_drones = true
	boss_config.support_drone_interval = 20.0

func _setup_rewards() -> void:
	reward_config.counter_weapon_unlock = "boss_missile"
	reward_config.tech_points = 20
	reward_config.unlock_message = "ハイパーミサイル解放\n装備画面で選択可能"
