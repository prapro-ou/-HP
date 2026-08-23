extends "res://game/enemies/boss/boss.gd"
class_name Stage4Boss

## ステージ4ボス「追撃自律ドレッドノート・ヘルハウンド」スクリプト
## stage4_boss1.png を使用した脱出阻止型追撃ドレッドノート
## - メイン攻撃: 拡散弾を廃止し、極太ハイパービーム・多連装収束レーザーを主軸に展開
## - 砲台1: 2段階加速5連並列弾砲台 (stage4_enemy1.png, 180度回転)
## - 砲台2: 1秒毎の超高速スナイパー速射砲台 (stage4_enemy2.png, 0度回転)
## - 砲台3: 10秒毎に画面中央・左右から巨大エネルギー弾を打ち下ろす重力オーブ砲台 (stage4_enemy3.png, 0度回転)

const TURRET1_TEXTURE: Texture2D = preload("res://game/assets/boss/stage4/stage4_enemy1.png")
const TURRET2_TEXTURE: Texture2D = preload("res://game/assets/boss/stage4/stage4_enemy2.png")
const TURRET3_TEXTURE: Texture2D = preload("res://game/assets/boss/stage4/stage4_enemy3.png")
const MEGA_BEAM_SCENE: PackedScene = preload("res://game/effects/mega_beam.tscn")


func _ready() -> void:
	max_hp = 12000
	current_hp = 12000
	super._ready()


func spawn_sub_turrets(duration: float = 5.0, is_wave2: bool = false) -> void:
	# ステージ4専用の3つの特殊砲台を配置
	# 砲台1: 2段階加速5連弾 (TurretType.ACCEL_LINE_SPREAD = 6)
	# 砲台2: 1秒毎の超高速スナイパー (TurretType.RAPID_SNIPER = 7)
	# 砲台3: 10秒毎の巨大エネルギー弾 (TurretType.GIGANTIC_ENERGY_ORB = 8)
	
	var configs = [
		{
			"type": 6, # ACCEL_LINE_SPREAD
			"start": Vector2(240.0, -120.0),
			"target": Vector2(240.0, 300.0),
			"texture": TURRET1_TEXTURE,
			"rotation_deg": 180.0,
			"scale": Vector2(0.40, 0.40)
		},
		{
			"type": 7, # RAPID_SNIPER
			"start": Vector2(560.0, -120.0),
			"target": Vector2(560.0, 300.0),
			"texture": TURRET2_TEXTURE,
			"rotation_deg": 0.0,
			"scale": Vector2(0.38, 0.38)
		},
		{
			"type": 8, # GIGANTIC_ENERGY_ORB
			"start": Vector2(400.0, -140.0),
			"target": Vector2(400.0, 190.0),
			"texture": TURRET3_TEXTURE,
			"rotation_deg": 0.0,
			"scale": Vector2(0.44, 0.44)
		}
	]
	
	for cfg in configs:
		if TURRET_SCENE:
			var turret = TURRET_SCENE.instantiate()
			turret.turret_type = cfg["type"]
			turret.max_hp = int(1400 * Global.get_enemy_hp_multiplier())
			turret.current_hp = turret.max_hp
			turret.setup_custom_visual(cfg["texture"], cfg["rotation_deg"], cfg["scale"])
			get_parent().add_child(turret)
			turret.spawn_intro(cfg["start"], cfg["target"], duration)
			turrets.append(turret)


func execute_fortress_attack() -> void:
	if not is_instance_valid(bullet_pool):
		return
		
	var mult = get_stage_difficulty_mult()
	var vp_w = get_viewport_rect().size.x
	var num_patterns = 4 if is_enraged else 3
	attack_pattern_index = (attack_pattern_index + 1) % num_patterns
	
	match attack_pattern_index:
		0:
			# パターン1: 【太めの2連高出力エネルギービーム】
			execute_twin_thick_beam_attack(mult)
		1:
			# パターン2: 【薙ぎ払い極太バスターレーザー】
			execute_sweeping_thick_beam_attack(mult)
		2:
			# パターン3: 【パリィ不可】真紅の要塞主砲・断絶ヴォイドレーザー斉射
			execute_unparryable_cannon_attack()
		3:
			# パターン4 (暴走時): 【3連極太フォトンバースト斉射】
			execute_triple_mega_beam_salvo(mult)


func execute_twin_thick_beam_attack(mult: float) -> void:
	# 左右の砲門から2本の太めのビームを照射
	var vp_w = get_viewport_rect().size.x
	var left_pos = Vector2(vp_w * 0.32, 170.0)
	var right_pos = Vector2(vp_w * 0.68, 170.0)
	
	spawn_shield_message("【WARNING】2連高出力ビーム照射！")
	Global.play_laser(0.9)
	
	var beam_positions = [left_pos, right_pos]
	for b_pos in beam_positions:
		var target_pos = b_pos + Vector2(0, 850.0)
		if is_instance_valid(player):
			var to_p = (player.global_position - b_pos).normalized()
			target_pos = b_pos + to_p * 900.0
			
		# 太いビームエフェクトの描画 (太さ 38px)
		if MEGA_BEAM_SCENE and get_parent():
			var beam_eff = MEGA_BEAM_SCENE.instantiate()
			beam_eff.setup_beam(b_pos, target_pos, Color(0.2, 0.9, 1.0), 38.0, 0.75)
			get_parent().add_child(beam_eff)
			
		# ビームラインに沿った高速衝突弾の連射
		var dir = (target_pos - b_pos).normalized()
		for i in range(8):
			get_tree().create_timer(i * 0.04).timeout.connect(func():
				if is_instance_valid(self) and is_alive and is_instance_valid(bullet_pool):
					var bullet = bullet_pool.get_bullet("laser")
					if bullet:
						bullet.global_position = b_pos + dir * (i * 35.0)
						bullet.damage = int(22 * mult)
						bullet.set_direction(dir, 750.0)
			)


func execute_sweeping_thick_beam_attack(mult: float) -> void:
	# 中央コアから太さ46pxの極太薙ぎ払いビーム
	var vp_w = get_viewport_rect().size.x
	var center_pos = Vector2(vp_w * 0.5, 180.0)
	
	spawn_shield_message("【WARNING】極太バスターレーザー薙ぎ払い！")
	Global.play_heavy_hit(1.1)
	
	var sweep_start_angle = -0.5
	var sweep_end_angle = 0.5
	if randf() > 0.5:
		sweep_start_angle = 0.5
		sweep_end_angle = -0.5
		
	var steps = 10
	for step in range(steps):
		var t = float(step) / float(steps - 1)
		var cur_angle = lerp(sweep_start_angle, sweep_end_angle, t)
		var dir = Vector2.DOWN.rotated(cur_angle)
		var end_p = center_pos + dir * 900.0
		
		get_tree().create_timer(step * 0.07).timeout.connect(func():
			if is_instance_valid(self) and is_alive:
				if MEGA_BEAM_SCENE and get_parent():
					var beam = MEGA_BEAM_SCENE.instantiate()
					beam.setup_beam(center_pos, end_p, Color(1.0, 0.45, 0.15), 44.0, 0.35)
					get_parent().add_child(beam)
				Global.play_laser(randf_range(1.2, 1.4))
				
				if is_instance_valid(bullet_pool):
					var bullet = bullet_pool.get_bullet("laser")
					if bullet:
						bullet.global_position = center_pos + dir * 30.0
						bullet.damage = int(24 * mult)
						bullet.set_direction(dir, 800.0)
		)


func execute_triple_mega_beam_salvo(mult: float) -> void:
	var vp_w = get_viewport_rect().size.x
	spawn_shield_message("【OVERDRIVE】3連極太フォトンバースト斉射！")
	Global.play_heavy_hit(0.7)
	
	var origins = [Vector2(vp_w * 0.25, 170.0), Vector2(vp_w * 0.5, 180.0), Vector2(vp_w * 0.75, 170.0)]
	for o_pos in origins:
		var target_p = o_pos + Vector2(0.0, 900.0)
		if MEGA_BEAM_SCENE and get_parent():
			var beam = MEGA_BEAM_SCENE.instantiate()
			beam.setup_beam(o_pos, target_p, Color(0.9, 0.2, 1.0), 42.0, 0.9)
			get_parent().add_child(beam)
			
		for i in range(10):
			get_tree().create_timer(i * 0.05).timeout.connect(func():
				if is_instance_valid(self) and is_alive and is_instance_valid(bullet_pool):
					var bullet = bullet_pool.get_bullet("laser")
					if bullet:
						bullet.global_position = o_pos + Vector2(randf_range(-10, 10), i * 30.0)
						bullet.damage = int(24 * mult)
						bullet.set_direction(Vector2.DOWN, 720.0)
			)
