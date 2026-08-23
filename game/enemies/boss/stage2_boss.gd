extends "res://game/enemies/boss/boss.gd"
class_name Stage2Boss

## ステージ2ボス「成層圏重爆撃キャリア・ストーム」スクリプト
## stage2_boss1.png を使用した巨大空中要塞キャリア
## - 砲台の1基は「水色・半透明の攻撃軽減シールド」(7秒展開 / 5秒クールダウン)を搭載
## - メテオ攻撃は廃止され、成層圏超放電ストームに差し替え

func _ready() -> void:
	max_hp = 8800
	current_hp = 8800
	super._ready()


func spawn_sub_turrets(duration: float = 5.0, is_wave2: bool = false) -> void:
	# ステージ2仕様：必ず片方が水色半透明シールド砲台（SHIELD_GENERATOR = 3）、もう片方が追尾ミサイルまたはビーム
	var other_type = 1 if is_wave2 else 0 # 0: BEAM, 1: MISSILE
	var shield_type = 3 # 3: SHIELD_GENERATOR
	
	# 配置：ボス背景の上に被る位置 (画面中央上部、左右)
	var left_x = randf_range(190.0, 300.0)
	var left_y = randf_range(240.0, 370.0)
	var right_x = randf_range(500.0, 610.0)
	var right_y = randf_range(240.0, 370.0)
	
	var configs = [
		{ "type": other_type, "start": Vector2(left_x, -120.0), "target": Vector2(left_x, left_y) },
		{ "type": shield_type, "start": Vector2(right_x, -120.0), "target": Vector2(right_x, right_y) }
	]
	
	for cfg in configs:
		if TURRET_SCENE:
			var turret = TURRET_SCENE.instantiate()
			turret.turret_type = cfg["type"]
			turret.max_hp = int(1100 * Global.get_enemy_hp_multiplier())
			turret.current_hp = turret.max_hp
			get_parent().add_child(turret)
			turret.spawn_intro(cfg["start"], cfg["target"], duration)
			turrets.append(turret)


func execute_fortress_attack() -> void:
	if not is_instance_valid(bullet_pool):
		return
		
	var mult = get_stage_difficulty_mult()
	var vp_w = get_viewport_rect().size.x
	var num_patterns = 5 if is_enraged else 3
	attack_pattern_index = (attack_pattern_index + 1) % num_patterns
	
	match attack_pattern_index:
		0:
			# パターン1: 成層圏プラズマウェイブ＋扇状フォトン射撃
			var drop_count = 5 if is_enraged else 3
			var step_w = vp_w / float(drop_count + 1)
			for i in range(drop_count):
				var drop_x = step_w * (i + 1)
				var center_dir = Vector2.DOWN
				if is_instance_valid(player):
					center_dir = (player.global_position - Vector2(drop_x, 20.0)).normalized()
					
				var angles = [-30.0, -15.0, 0.0, 15.0, 30.0]
				for angle_deg in angles:
					var bullet = bullet_pool.get_bullet("wave" if i % 2 == 0 else "laser")
					if bullet:
						bullet.global_position = Vector2(drop_x, 15.0)
						bullet.damage = int(12 * mult)
						var dir = center_dir.rotated(deg_to_rad(angle_deg))
						bullet.set_direction(dir, 340.0)
		1:
			# パターン2: クラスター追尾ミサイル斉射（成層圏爆撃）
			var missile_waves = 5 if is_enraged else 3
			for wave in range(missile_waves):
				get_tree().create_timer(wave * 0.20).timeout.connect(func():
					if is_instance_valid(self) and is_alive and is_instance_valid(bullet_pool):
						var spawn_x = randf_range(80.0, vp_w - 80.0)
						var bullet = bullet_pool.get_bullet("missile")
						if bullet:
							bullet.global_position = Vector2(spawn_x, 15.0)
							bullet.damage = int(12 * mult)
							var target_dir = Vector2.DOWN
							if is_instance_valid(player):
								target_dir = (player.global_position - bullet.global_position).normalized()
							bullet.set_direction(target_dir, 280.0)
				)
		2:
			# パターン3: 【パリィ不可】真紅の断絶レーザー爆撃
			execute_unparryable_cannon_attack()
			
		3:
			# パターン4 (暴走時): 高速プラズマチャージ弾幕
			if is_instance_valid(core_node):
				var core_pos = core_node.global_position
				for c_i in range(3):
					get_tree().create_timer(c_i * 0.12).timeout.connect(func():
						if is_instance_valid(self) and is_alive and is_instance_valid(bullet_pool):
							var bullet = bullet_pool.get_bullet("charge")
							if bullet:
								bullet.global_position = core_pos + Vector2(0.0, 30.0)
								bullet.damage = int(18 * mult)
								var dir = Vector2.DOWN
								if is_instance_valid(player):
									dir = (player.global_position - bullet.global_position).normalized()
								bullet.set_direction(dir, 480.0)
					)
		4:
			# パターン5 (暴走時・メテオ廃止): 成層圏超放電エレクトリックストーム
			var storm_count = 6
			var step_w = vp_w / float(storm_count + 1)
			for s_i in range(storm_count):
				get_tree().create_timer(s_i * 0.14).timeout.connect(func():
					if is_instance_valid(self) and is_alive and is_instance_valid(bullet_pool):
						var strike_x = step_w * (s_i + 1)
						for side in [-12.0, 0.0, 12.0]:
							var bullet = bullet_pool.get_bullet("thunder")
							if bullet:
								bullet.global_position = Vector2(strike_x, 20.0)
								bullet.damage = int(14 * mult)
								var dir = Vector2.DOWN.rotated(deg_to_rad(side))
								if is_instance_valid(player):
									dir = (player.global_position - bullet.global_position).normalized().rotated(deg_to_rad(side * 0.5))
								bullet.set_direction(dir, 360.0)
				)
