extends "res://game/enemies/boss/boss.gd"
class_name Stage5Boss

## ステージ5ボス「惑星融合型超兵器・ガイア」スクリプト
## stage5_boss1.png を使用した惑星融合型超巨大ボス
## - 挙動と仕様はステージ1をベースに展開
## - ステージ5ボス本体は他ステージよりも一回り大きく巨大化（砲台サイズは標準維持）
## - 砲台1: stage5_enemy4.png (0度回転 / そのまま)
## - 砲台2: stage5_enemy5.png (180度回転)

const TURRET1_TEXTURE: Texture2D = preload("res://game/assets/boss/stage5/stage5_enemy4.png")
const TURRET2_TEXTURE: Texture2D = preload("res://game/assets/boss/stage5/stage5_enemy5.png")


func _ready() -> void:
	max_hp = 15000
	current_hp = 15000
	super._ready()
	
	# ボス初期位置：大型ボスに合わせて画面上部深くに待機
	var vp_w = get_viewport_rect().size.x
	position = Vector2(vp_w / 2.0, -900.0)


func spawn_sub_turrets(duration: float = 5.0, is_wave2: bool = false) -> void:
	var types = [0, 1, 2]
	types.shuffle()
	
	var type1 = types[0]
	var type2 = types[1]
	if is_wave2:
		type1 = types[1]
		type2 = types[2]
		
	# 配置：巨大ボス背景の上に被る位置 (画面中央上部、左右)
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
			"rotation_deg": 0.0,
			"scale": Vector2(0.45, 0.45)
		},
		{
			"type": type2,
			"start": Vector2(right_x, -120.0),
			"target": Vector2(right_x, right_y),
			"texture": TURRET2_TEXTURE,
			"rotation_deg": 180.0,
			"scale": Vector2(0.50, 0.50)
		}
	]
	
	for cfg in configs:
		if TURRET_SCENE:
			var turret = TURRET_SCENE.instantiate()
			turret.turret_type = cfg["type"]
			turret.max_hp = int(1800 * Global.get_enemy_hp_multiplier())
			turret.current_hp = turret.max_hp
			turret.setup_custom_visual(cfg["texture"], cfg["rotation_deg"], cfg["scale"])
			get_parent().add_child(turret)
			turret.spawn_intro(cfg["start"], cfg["target"], duration)
			turrets.append(turret)
