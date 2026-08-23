extends Area2D
class_name BossTurret
## ボス用サブ砲台スクリプト
## 3種類のいずれかとして動作：
## 1. ビームマシンガン (10秒毎に1秒チャージ後、すり抜け不可能な高速ビーム連射)
## 2. 減速追尾ミサイル (斜め2発ずつ -> 1秒で減速停止 -> 1.2倍速で追尾)
## 3. 隕石射出 (赤く発光後、stage1_boss_meteor.pngの隕石を最大4個飛ばす)

enum TurretType {
	BEAM_MACHINEGUN,
	HOMING_MISSILE,
	METEOR_LAUNCHER,
	SHIELD_GENERATOR
}

const METEOR_SCENE: PackedScene = preload("res://game/bullets/meteor_bullet.tscn")
const PARRY_PARTICLE_SCENE: PackedScene = preload("res://game/bullets/parry_particle.tscn")
const BOSS_WIDE_SHIELD_SCENE: PackedScene = preload("res://game/effects/boss_wide_shield.tscn")
const HitSpark = preload("res://game/bullets/hit_spark.gd")

@export var turret_type: TurretType = TurretType.BEAM_MACHINEGUN
@export var max_hp: int = 800

var current_hp: int = 800
var is_alive: bool = true
var is_active: bool = false
var attack_timer: float = 0.0
var is_charging: bool = false
var charge_timer: float = 0.0
var target_pos: Vector2 = Vector2.ZERO
var hover_offset: float = 0.0

# ビームチャージ予告用
var beam_warning_line_alpha: float = 0.0
var beam_warning_target_x: float = 0.0

# シールド発生装置用 (7秒展開、5秒クールダウン)
var is_shield_active: bool = false
var shield_timer: float = 7.0
var shield_pulse: float = 0.0
var shield_effect_instance: BossWideShield = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func get_stage_difficulty_mult() -> float:
	var stage_num = 1
	var main = get_node_or_null("/root/Main")
	if main:
		var gm = main.get_node_or_null("GameManager")
		if gm and "current_stage_num" in gm:
			stage_num = gm.current_stage_num
	return Global.get_stage_difficulty_multiplier(stage_num)


func _ready() -> void:
	add_to_group("boss_turrets")
	add_to_group("boss")
	add_to_group("enemy")
	
	var mult = get_stage_difficulty_mult()
	max_hp = int(max_hp * mult)
	current_hp = max_hp
	is_alive = true
	is_active = false
	hover_offset = randf_range(0.0, TAU)
	
	# スプライト調整 (プレイヤーと同等の大型サイズ ~152x65px)
	if sprite:
		sprite.scale = Vector2(0.65, 0.65)
		
	if turret_type == TurretType.SHIELD_GENERATOR:
		is_shield_active = true
		shield_timer = 7.0
		if BOSS_WIDE_SHIELD_SCENE:
			shield_effect_instance = BOSS_WIDE_SHIELD_SCENE.instantiate()
			get_parent().call_deferred("add_child", shield_effect_instance)
		
	update_type_visuals()


func update_type_visuals() -> void:
	match turret_type:
		TurretType.BEAM_MACHINEGUN:
			modulate = Color(0.3, 0.85, 1.0) # シアン
		TurretType.HOMING_MISSILE:
			modulate = Color(0.9, 0.45, 1.0) # パープル
		TurretType.METEOR_LAUNCHER:
			modulate = Color(1.0, 0.45, 0.2) # オレンジレッド
		TurretType.SHIELD_GENERATOR:
			modulate = Color(0.3, 0.95, 1.0) # 水色・発光シアン


func spawn_intro(start_pos: Vector2, final_pos: Vector2, duration: float = 5.0) -> void:
	global_position = start_pos
	target_pos = final_pos
	modulate.a = 0.0
	scale = Vector2(0.3, 0.3)
	is_active = false
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", final_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, duration * 0.7)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func():
		is_active = true
		attack_timer = randf_range(0.5, 1.5)
	)


func _process(delta: float) -> void:
	if not is_alive:
		return
		
	# わずかな浮遊アニメーション
	if is_active:
		hover_offset += delta * 2.0
		position.y = target_pos.y + sin(hover_offset) * 8.0
		position.x = target_pos.x + cos(hover_offset * 0.7) * 5.0
		
	if not is_active:
		return
		
	# シールド発生装置の制御 (7秒間展開 -> 5秒間クールダウン)
	if turret_type == TurretType.SHIELD_GENERATOR:
		shield_pulse += delta * 3.5
		shield_timer -= delta
		if is_shield_active:
			if shield_timer <= 0.0:
				is_shield_active = false
				shield_timer = 5.0 # 5秒間クールダウン
				spawn_turret_warning("シールド一時解除！(5秒間隙発生)")
				queue_redraw()
		else:
			if shield_timer <= 0.0:
				is_shield_active = true
				shield_timer = 7.0 # 7秒間展開
				spawn_turret_warning("水色防護シールド展開 (7秒間)")
				queue_redraw()
				
		if is_instance_valid(shield_effect_instance):
			shield_effect_instance.is_active = is_shield_active and is_alive
			shield_effect_instance.generator_pos = global_position
			var boss_shield_pos = Vector2(400.0, 240.0)
			var main = get_node_or_null("/root/Main")
			if main:
				var boss = main.get_node_or_null("Boss")
				if is_instance_valid(boss):
					boss_shield_pos = boss.global_position + Vector2(0.0, 60.0)
			shield_effect_instance.shield_pos = boss_shield_pos
		
	if is_charging:
		charge_timer -= delta
		# チャージ中の点滅
		if turret_type == TurretType.BEAM_MACHINEGUN:
			beam_warning_line_alpha = clamp(1.0 - (charge_timer / 1.0), 0.2, 0.9)
			queue_redraw()
		elif turret_type == TurretType.METEOR_LAUNCHER:
			modulate = Color(1.0, 0.2, 0.2) if int(charge_timer * 16.0) % 2 == 0 else Color(1.0, 0.7, 0.5)
			
		if charge_timer <= 0.0:
			is_charging = false
			beam_warning_line_alpha = 0.0
			queue_redraw()
			update_type_visuals()
			execute_attack()
		return
		
	attack_timer += delta
	var interval = get_attack_interval()
	if attack_timer >= interval:
		attack_timer = 0.0
		start_attack_sequence()


func get_boss_phase_info() -> Dictionary:
	var boss = null
	var main = get_node_or_null("/root/Main")
	if main:
		boss = main.get_node_or_null("Boss")
	if not is_instance_valid(boss):
		var bosses = get_tree().get_nodes_in_group("boss")
		for b in bosses:
			if b != self and is_instance_valid(b) and "current_hp" in b and "max_hp" in b:
				boss = b
				break
				
	var hp_ratio = 1.0
	if is_instance_valid(boss) and boss.max_hp > 0:
		hp_ratio = clamp(float(boss.current_hp) / float(boss.max_hp), 0.0, 1.0)
		
	var phase = 1
	var interval_mult = 1.0
	var damage_mult = 1.0
	var speed_mult = 1.0
	
	if hp_ratio <= 0.35:
		phase = 3 # 臨界・第3段階 (ボスHP 35%以下: 超激化)
		interval_mult = 0.52 # 攻撃スパン約半分（超高頻度攻撃）
		damage_mult = 1.50 # ダメージ1.5倍
		speed_mult = 1.30 # 弾速1.3倍
	elif hp_ratio <= 0.70:
		phase = 2 # 激化・第2段階 (ボスHP 70%以下: 激化)
		interval_mult = 0.75 # 攻撃スパン0.75倍
		damage_mult = 1.25 # ダメージ1.25倍
		speed_mult = 1.15 # 弾速1.15倍
		
	return {
		"phase": phase,
		"hp_ratio": hp_ratio,
		"interval_mult": interval_mult,
		"damage_mult": damage_mult,
		"speed_mult": speed_mult
	}


func get_attack_interval() -> float:
	var p_info = get_boss_phase_info()
	var base_interval = 3.5
	match turret_type:
		TurretType.BEAM_MACHINEGUN:
			base_interval = 7.0
		TurretType.HOMING_MISSILE:
			base_interval = 2.8
		TurretType.METEOR_LAUNCHER:
			base_interval = 3.5
		TurretType.SHIELD_GENERATOR:
			base_interval = 2.2
	return base_interval * p_info["interval_mult"]


func start_attack_sequence() -> void:
	var p_info = get_boss_phase_info()
	var phase = p_info["phase"]
	var charge_dur = 1.0
	if phase == 2:
		charge_dur = 0.75
	elif phase == 3:
		charge_dur = 0.50

	match turret_type:
		TurretType.BEAM_MACHINEGUN:
			is_charging = true
			charge_timer = charge_dur
			var player = get_node_or_null("/root/Main/Player")
			beam_warning_target_x = player.global_position.x if is_instance_valid(player) else global_position.x
			var warn_msg = "LASER CHARGE!"
			if phase == 2:
				warn_msg = "RAPID LASER CHARGE!!"
			elif phase == 3:
				warn_msg = "OVERDRIVE LASER CHARGE!!!"
			spawn_turret_warning(warn_msg)
		TurretType.HOMING_MISSILE:
			execute_attack()
		TurretType.METEOR_LAUNCHER:
			is_charging = true
			charge_timer = charge_dur
			var warn_msg = "METEOR LAUNCH!" if phase == 1 else ("RAPID METEOR LAUNCH!!" if phase == 2 else "OVERDRIVE METEORS!!!")
			spawn_turret_warning(warn_msg)
		TurretType.SHIELD_GENERATOR:
			execute_attack()


func execute_attack() -> void:
	var main = get_node_or_null("/root/Main")
	var pool = main.get_node_or_null("BulletPool") if main else null
	var player = main.get_node_or_null("Player") if main else null
	var diff_mult = get_stage_difficulty_mult()
	var p_info = get_boss_phase_info()
	var final_dmg_mult = diff_mult * p_info["damage_mult"]
	var phase = p_info["phase"]
	var spd_mult = p_info["speed_mult"]
	
	match turret_type:
		TurretType.BEAM_MACHINEGUN:
			# 高速ビーム連射 (Phase 1: 8発, Phase 2: 12発, Phase 3: 16発)
			var beam_count = 8
			if phase == 2:
				beam_count = 12
			elif phase == 3:
				beam_count = 16
			if pool:
				var delay_step = 0.08 / spd_mult
				for i in range(beam_count):
					get_tree().create_timer(i * delay_step).timeout.connect(func():
						if is_instance_valid(self) and is_alive and is_instance_valid(pool):
							var bullet = pool.get_bullet("boss_laser")
							if bullet:
								bullet.global_position = global_position + Vector2(randf_range(-12, 12), 25)
								bullet.damage = int(20 * final_dmg_mult)
								var dir = Vector2.DOWN
								if is_instance_valid(player):
									var target_x = player.global_position.x + randf_range(-25, 25)
									dir = (Vector2(target_x, player.global_position.y) - global_position).normalized()
								bullet.set_direction(dir, 640.0 * spd_mult)
					)
					
		TurretType.HOMING_MISSILE:
			# 減速追尾ミサイル (Phase 1: 4発, Phase 2: 6発, Phase 3: 8発)
			if pool:
				var spread_angles = [-40.0, -20.0, 20.0, 40.0]
				if phase == 2:
					spread_angles = [-50.0, -30.0, -10.0, 10.0, 30.0, 50.0]
				elif phase == 3:
					spread_angles = [-60.0, -42.0, -25.0, -8.0, 8.0, 25.0, 42.0, 60.0]
				for angle_deg in spread_angles:
					var bullet = pool.get_bullet("decel_missile")
					if bullet:
						bullet.global_position = global_position + Vector2(0.0, 20.0)
						bullet.damage = int(16 * final_dmg_mult)
						var launch_dir = Vector2.DOWN.rotated(deg_to_rad(angle_deg))
						bullet.set_direction(launch_dir, 320.0 * spd_mult)
						
		TurretType.METEOR_LAUNCHER:
			# 巨大隕石射出 (Phase 3では最大6個まで許容、弾速向上)
			var max_meteors = 4 if phase <= 2 else 6
			var current_meteors = get_tree().get_nodes_in_group("enemy_projectiles")
			if current_meteors.size() < max_meteors and METEOR_SCENE:
				var meteor = METEOR_SCENE.instantiate()
				meteor.global_position = global_position + Vector2(0.0, 30.0)
				meteor.damage = int(60 * final_dmg_mult)
				var shoot_dir = Vector2.DOWN.rotated(randf_range(-0.6, 0.6))
				if is_instance_valid(player):
					shoot_dir = (player.global_position - global_position).normalized().rotated(randf_range(-0.4, 0.4))
				meteor.set_direction(shoot_dir, 320.0 * spd_mult)
				get_parent().add_child(meteor)
				
		TurretType.SHIELD_GENERATOR:
			# プラズマ拡散射撃 (Phase 1: 3方向, Phase 2/3: 5方向)
			if pool:
				var angles = [-18.0, 0.0, 18.0]
				if phase >= 2:
					angles = [-32.0, -16.0, 0.0, 16.0, 32.0]
				for angle_deg in angles:
					var bullet = pool.get_bullet("wave")
					if bullet:
						bullet.global_position = global_position + Vector2(0.0, 20.0)
						bullet.damage = int(18 * final_dmg_mult)
						var dir = Vector2.DOWN.rotated(deg_to_rad(angle_deg))
						bullet.set_direction(dir, 300.0 * spd_mult)


func _draw() -> void:
	# レーザー照射予告線
	if beam_warning_line_alpha > 0.0:
		var line_color = Color(1.0, 0.1, 0.1, beam_warning_line_alpha)
		var local_target_x = beam_warning_target_x - global_position.x
		draw_line(Vector2(0, 15), Vector2(local_target_x, 800), line_color, 2.5)
		var glow_color = Color(1.0, 0.3, 0.3, beam_warning_line_alpha * 0.3)
		draw_line(Vector2(0, 15), Vector2(local_target_x, 800), glow_color, 8.0)
		
	# 砲台自体の防護フィールドサークル
	if turret_type == TurretType.SHIELD_GENERATOR and is_shield_active:
		var turret_pulse_r = 55.0 + sin(shield_pulse) * 4.0
		var turret_alpha = 0.20 + sin(shield_pulse * 1.5) * 0.05
		draw_circle(Vector2.ZERO, turret_pulse_r, Color(0.18, 0.78, 1.0, turret_alpha))
		draw_arc(Vector2.ZERO, turret_pulse_r, 0, TAU, 28, Color(0.35, 0.92, 1.0, 0.85), 2.5)

	# 砲台専用ミニHPバー (頭上に表示: 視覚的な削りフィードバック)
	if is_alive and max_hp > 0:
		var bar_w = 70.0
		var bar_h = 5.0
		var bar_pos = Vector2(-bar_w / 2.0, -52.0)
		var hp_ratio = clamp(float(current_hp) / float(max_hp), 0.0, 1.0)
		
		# 黒背景枠
		draw_rect(Rect2(bar_pos - Vector2(1, 1), Vector2(bar_w + 2, bar_h + 2)), Color(0.05, 0.08, 0.12, 0.85))
		# HPバー本体 (割合に応じて緑->黄->赤)
		var hp_col = Color(0.2, 0.95, 0.4)
		if hp_ratio < 0.35:
			hp_col = Color(1.0, 0.25, 0.25)
		elif hp_ratio < 0.65:
			hp_col = Color(1.0, 0.85, 0.2)
		draw_rect(Rect2(bar_pos, Vector2(bar_w * hp_ratio, bar_h)), hp_col)


func spawn_turret_warning(text: String) -> void:
	var label = Label.new()
	label.text = text
	var label_settings = LabelSettings.new()
	label_settings.font_size = 16
	label_settings.font_color = Color(0.3, 0.9, 1.0) if turret_type == TurretType.SHIELD_GENERATOR else Color.RED
	label_settings.outline_size = 4
	label_settings.outline_color = Color.BLACK
	label.label_settings = label_settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.global_position = global_position + Vector2(-120, -45)
	label.custom_minimum_size = Vector2(240, 20)
	get_parent().add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "global_position:y", label.global_position.y - 30.0, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.chain().tween_callback(label.queue_free)


func take_damage(amount: int, hit_pos: Vector2 = Vector2.ZERO, is_critical: bool = false) -> void:
	if not is_alive:
		return
		
	var actual_hit_pos = hit_pos if hit_pos != Vector2.ZERO else global_position
	var is_shielded = (turret_type == TurretType.SHIELD_GENERATOR and is_shield_active)
	var final_damage = amount
	
	if is_shielded:
		# 水色防護シールド展開中はダメージ75%大幅軽減
		final_damage = max(1, int(amount * 0.25))
		Global.play_guard(randf_range(0.95, 1.05))
		HitSpark.create_spark(get_parent(), actual_hit_pos, "shield")
	else:
		Global.play_hit(randf_range(0.95, 1.1))
		var spark_type_str = "heavy" if is_critical else "normal"
		var spark_col = Color(1.0, 0.9, 0.2) if is_critical else Color(1.0, 0.85, 0.3)
		HitSpark.create_spark(get_parent(), actual_hit_pos, spark_type_str, spark_col)
		
	current_hp -= final_damage
	
	# 強烈な白熱被弾フラッシュ
	if sprite:
		sprite.modulate = Color(1.2, 2.5, 3.0) if is_shielded else Color(3.0, 3.0, 3.0)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.06)
		
		# 被弾シェイク（ノックバック振動）
		sprite.position = Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))
		var shake_t = create_tween()
		shake_t.tween_property(sprite, "position", Vector2.ZERO, 0.05)
		
	# HPバー再描画
	queue_redraw()
	
	var main = get_node_or_null("/root/Main")
	if main:
		var ui_node = main.get_node_or_null("UI")
		if ui_node and ui_node.has_method("spawn_damage_popup"):
			ui_node.spawn_damage_popup(actual_hit_pos, final_damage, false, is_critical)
			
	if current_hp <= 0:
		current_hp = 0
		destroy_turret()


func destroy_turret() -> void:
	is_alive = false
	is_active = false
	remove_from_group("boss_turrets")
	
	if is_instance_valid(shield_effect_instance):
		shield_effect_instance.is_active = false
		shield_effect_instance.queue_free()
		shield_effect_instance = null
		
	Global.play_explosion(1.1)
	
	# 爆発演出
	if PARRY_PARTICLE_SCENE and get_parent():
		for i in range(12):
			var p = PARRY_PARTICLE_SCENE.instantiate()
			p.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			p.scale = Vector2(3.0, 3.0)
			p.modulate = Color(1.0, randf_range(0.3, 0.9), 0.1)
			get_parent().add_child(p)
			
	Global.tech_points += 5
	
	var main = get_node_or_null("/root/Main")
	if main:
		var player = main.get_node_or_null("Player")
		if is_instance_valid(player):
			if player.has_method("heal"):
				player.heal(50)
			if player.has_method("spawn_popup_message"):
				player.spawn_popup_message("サブ砲台撃破！ +5 TP / 機体修復 +50 HP")

	# ボスへ撃破を通知して弱点露出（BREAK）を発動
	if main:
		var boss = main.get_node_or_null("Boss")
		if is_instance_valid(boss) and boss.has_method("on_turret_destroyed"):
			boss.on_turret_destroyed(self)
		else:
			var bosses = get_tree().get_nodes_in_group("boss")
			for b in bosses:
				if b != self and is_instance_valid(b) and b.has_method("on_turret_destroyed"):
					b.on_turret_destroyed(self)
					break

	# フェードアウトして消滅
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(queue_free)
