extends "res://game/enemies/boss/boss.gd"
class_name Stage3Boss

## ステージ3ボス「中枢防衛プラント・コロッサスコア」スクリプト
## stage3_boss1.png を使用した中枢防衛要塞ボス
## - 挙動と仕様はステージ1をベースに展開
## - 砲台1: stage3_enemy2.png (90度右回転)
## - 砲台2: stage3_enemy3.png (180度回転)

const TURRET1_TEXTURE: Texture2D = preload("res://game/assets/boss/stage3/stage3_enemy2.png")
const TURRET2_TEXTURE: Texture2D = preload("res://game/assets/boss/stage3/stage3_enemy3.png")


func _ready() -> void:
	max_hp = 10500
	current_hp = 10500
	super._ready()


func spawn_sub_turrets(duration: float = 5.0, is_wave2: bool = false) -> void:
	var types = [0, 1, 2]
	types.shuffle()
	
	var type1 = types[0]
	var type2 = types[1]
	if is_wave2:
		type1 = types[1]
		type2 = types[2]
		
	# 配置：ボス背景の上に被る位置 (画面中央上部、左右)
	var left_x = randf_range(200.0, 320.0)
	var left_y = randf_range(240.0, 380.0)
	var right_x = randf_range(480.0, 600.0)
	var right_y = randf_range(240.0, 380.0)
	
	var configs = [
		{
			"type": type1,
			"start": Vector2(left_x, -120.0),
			"target": Vector2(left_x, left_y),
			"texture": TURRET1_TEXTURE,
			"rotation_deg": 90.0,
			"scale": Vector2(0.28, 0.28)
		},
		{
			"type": type2,
			"start": Vector2(right_x, -120.0),
			"target": Vector2(right_x, right_y),
			"texture": TURRET2_TEXTURE,
			"rotation_deg": 180.0,
			"scale": Vector2(0.35, 0.35)
		}
	]
	
	for cfg in configs:
		if TURRET_SCENE:
			var turret = TURRET_SCENE.instantiate()
			turret.turret_type = cfg["type"]
			turret.max_hp = 1300
			turret.current_hp = 1300
			turret.setup_custom_visual(cfg["texture"], cfg["rotation_deg"], cfg["scale"])
			get_parent().add_child(turret)
			turret.spawn_intro(cfg["start"], cfg["target"], duration)
			turrets.append(turret)
