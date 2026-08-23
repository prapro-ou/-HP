extends "res://game/enemies/boss/boss.gd"
class_name Stage3Boss

## ステージ3ボス「中枢防衛プラント・コロッサスコア」スクリプト
## stage3_boss1.png を使用した中枢防衛要塞ボス
## - 砲台1: 8方向分裂弾砲台 (stage3_enemy2.png, 90度回転)
## - 砲台2: 5秒間毎秒30ダメージの電磁フィールド発生砲台 (stage3_enemy3.png, 180度回転)
## - ファンネル砲台: 15秒毎に画面上部から出現し、自機の側面/背後に回り込んでビーム斉射を行う (stage3_enemy4.png)

const TURRET1_TEXTURE: Texture2D = preload("res://game/assets/boss/stage3/stage3_enemy2.png")
const TURRET2_TEXTURE: Texture2D = preload("res://game/assets/boss/stage3/stage3_enemy3.png")
const FUNNEL_SCENE: PackedScene = preload("res://game/enemies/boss/boss_funnel_turret.tscn")

var funnel_timer: float = 12.0 # 開幕12秒後に初出現、以降15秒間隔
var active_funnels: Array = []


func _ready() -> void:
	max_hp = 10500
	current_hp = 10500
	funnel_timer = 12.0
	active_funnels.clear()
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)
	
	if not is_alive or not is_active:
		return
		
	# 15秒間隔のファンネル召喚処理
	funnel_timer -= delta
	if funnel_timer <= 0.0:
		funnel_timer = 15.0
		spawn_funnel_turret()


func spawn_funnel_turret() -> void:
	if not is_alive or not FUNNEL_SCENE:
		return
		
	# クリーンアップ（破棄済みファンネルの整理）
	var valid_funnels = []
	for f in active_funnels:
		if is_instance_valid(f) and f.is_alive:
			valid_funnels.append(f)
	active_funnels = valid_funnels
	
	# 同時存在数は最大2機まで
	if active_funnels.size() >= 2:
		return
		
	var funnel = FUNNEL_SCENE.instantiate()
	var spawn_x = randf_range(160.0, 640.0)
	funnel.global_position = Vector2(spawn_x, -80.0)
	get_parent().add_child(funnel)
	active_funnels.append(funnel)
	
	# ボス全体のturretsリストにも登録してバリア連携
	turrets.append(funnel)


func spawn_sub_turrets(duration: float = 5.0, is_wave2: bool = false) -> void:
	# ステージ3固有の2つの専用砲台を配置
	# 砲台1: 8方向分裂弾 (TurretType.CLUSTER_SPLITTER = 4)
	# 砲台2: 電磁フィールド発生器 (TurretType.ELECTROMAGNETIC_FIELD = 5)
	var type1 = 4 # CLUSTER_SPLITTER
	var type2 = 5 # ELECTROMAGNETIC_FIELD
	
	if is_wave2:
		# 第2波でも固有砲台を展開
		type1 = 4
		type2 = 5
		
	# 配置：画面中央上部、左右
	var left_x = randf_range(200.0, 300.0)
	var left_y = randf_range(240.0, 360.0)
	var right_x = randf_range(500.0, 600.0)
	var right_y = randf_range(240.0, 360.0)
	
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
			turret.max_hp = int(1200 * Global.get_enemy_hp_multiplier())
			turret.current_hp = turret.max_hp
			turret.setup_custom_visual(cfg["texture"], cfg["rotation_deg"], cfg["scale"])
			get_parent().add_child(turret)
			turret.spawn_intro(cfg["start"], cfg["target"], duration)
			turrets.append(turret)


func destroy_boss() -> void:
	# ボス撃破時に残存ファンネルも一斉消滅
	for f in active_funnels:
		if is_instance_valid(f) and f.has_method("destroy_funnel"):
			f.destroy_funnel()
	active_funnels.clear()
	super.destroy_boss()
