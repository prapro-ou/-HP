extends "res://game/enemies/boss/boss.gd"
class_name Stage5Boss

## ステージ5ボス「惑星融合型超兵器・ガイア」スクリプト
## stage5_boss1.png を使用した惑星融合型超巨大ボス
## - 5秒に1回、フィールドのランダム位置に時限/接触トラップマインを投下（ジャスガで反撃可能）
## - 砲台1: 上端から下端へ突進しつつ斜め下左右へ弾をまき散らす突進砲台 (stage5_enemy1.png)
## - 砲台2: 1秒ごとにプレイヤー方向へ突進と停止・狙撃を繰り返すステップ追尾砲台 (stage5_enemy2.png)
## - 砲台3: ボス上を右から左へ薙ぎ払いながら5連鎖爆発を起こす爆撃砲台 (stage5_enemy3.png)

const TURRET1_TEXTURE: Texture2D = preload("res://game/assets/boss/stage5/stage5_enemy1.png")
const TURRET2_TEXTURE: Texture2D = preload("res://game/assets/boss/stage5/stage5_enemy2.png")
const TURRET3_TEXTURE: Texture2D = preload("res://game/assets/boss/stage5/stage5_enemy3.png")
const BOSS_TRAP_MINE_SCRIPT: GDScript = preload("res://game/enemies/boss/boss_trap_mine.gd")

var trap_timer: float = 0.0
const TRAP_INTERVAL: float = 5.0


func _ready() -> void:
	max_hp = 15000
	current_hp = 15000
	super._ready()
	
	# ボス初期位置：大型ボスに合わせて画面上部深くに待機
	var vp_w = get_viewport_rect().size.x
	position = Vector2(vp_w / 2.0, -900.0)
	trap_timer = 2.0 # 開幕2秒後に最初のトラップを投下


func _process(delta: float) -> void:
	super._process(delta)
	
	if is_alive and not is_invincible:
		trap_timer += delta
		if trap_timer >= TRAP_INTERVAL:
			trap_timer = 0.0
			spawn_field_trap()


func spawn_field_trap() -> void:
	if not is_alive:
		return
	var vp_size = get_viewport_rect().size
	var spawn_pos = Vector2(
		randf_range(120.0, vp_size.x - 120.0),
		randf_range(300.0, vp_size.y - 120.0)
	)
	
	var trap = BOSS_TRAP_MINE_SCRIPT.new()
	trap.setup_trap(spawn_pos)
	
	var parent_node = get_parent()
	if parent_node:
		parent_node.add_child(trap)
		spawn_shield_message("【ALERT】重力トラップマイン投下！(ジャスガで反撃可能)", Color(1.0, 0.4, 0.4), 1.0)


func spawn_sub_turrets(duration: float = 5.0, is_wave2: bool = false) -> void:
	# ステージ5専用の3つの特殊砲台を配置
	# 砲台1: 突進拡散砲台 (TurretType.DIVE_SCATTER = 9)
	# 砲台2: 1秒追尾停止砲台 (TurretType.STEP_PURSUIT = 10)
	# 砲台3: 5連鎖爆撃砲台 (TurretType.CHAIN_SWEEP_BOMBER = 11)
	
	var configs = [
		{
			"type": 9, # DIVE_SCATTER
			"start": Vector2(220.0, -120.0),
			"target": Vector2(220.0, 280.0),
			"texture": TURRET1_TEXTURE,
			"rotation_deg": 180.0,
			"scale": Vector2(0.42, 0.42)
		},
		{
			"type": 10, # STEP_PURSUIT
			"start": Vector2(580.0, -120.0),
			"target": Vector2(580.0, 280.0),
			"texture": TURRET2_TEXTURE,
			"rotation_deg": 0.0,
			"scale": Vector2(0.42, 0.42)
		},
		{
			"type": 11, # CHAIN_SWEEP_BOMBER
			"start": Vector2(400.0, -140.0),
			"target": Vector2(400.0, 180.0),
			"texture": TURRET3_TEXTURE,
			"rotation_deg": 0.0,
			"scale": Vector2(0.46, 0.46)
		}
	]
	
	for cfg in configs:
		if TURRET_SCENE:
			var turret = TURRET_SCENE.instantiate()
			turret.turret_type = cfg["type"]
			turret.max_hp = int(1600 * Global.get_enemy_hp_multiplier())
			turret.current_hp = turret.max_hp
			turret.setup_custom_visual(cfg["texture"], cfg["rotation_deg"], cfg["scale"])
			get_parent().add_child(turret)
			turret.spawn_intro(cfg["start"], cfg["target"], duration)
			turrets.append(turret)


func destroy_boss() -> void:
	# フィールド上のトラップマインを全消去
	var traps = get_tree().get_nodes_in_group("boss_traps")
	for t in traps:
		if is_instance_valid(t):
			t.queue_free()
	super.destroy_boss()
