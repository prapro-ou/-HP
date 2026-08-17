extends Area2D
class_name BossTurret
## ボス用サブ砲台スクリプト
## 3種類のいずれかとして動作：
## 1. ビームマシンガン (10秒毎に1秒チャージ後、すり抜け不可能な高速ビーム連射)
## 2. 減速追尾ミサイル (斜め2発ずつ ➔ 1秒で減速停止 ➔ 1.2倍速で追尾)
## 3. 隕石射出 (赤く発光後、10.pngの隕石を最大4個飛ばす)

enum TurretType {
	BEAM_MACHINEGUN,
	HOMING_MISSILE,
	METEOR_LAUNCHER
}

const METEOR_SCENE: PackedScene = preload("res://game/bullets/meteor_bullet.tscn")
const PARRY_PARTICLE_SCENE: PackedScene = preload("res://game/bullets/parry_particle.tscn")

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

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("boss_turrets")
	add_to_group("boss")
	add_to_group("enemy")
	
	current_hp = max_hp
	is_alive = true
	is_active = false
	hover_offset = randf_range(0.0, TAU)
	
	# スプライト調整 (キャラクターより少し小さい ~65px)
	if sprite:
		sprite.scale = Vector2(0.28, 0.28)
		
	update_type_visuals()


func update_type_visuals() -> void:
	match turret_type:
		TurretType.BEAM_MACHINEGUN:
			modulate = Color(0.3, 0.85, 1.0) # シアン
		TurretType.HOMING_MISSILE:
			modulate = Color(0.9, 0.45, 1.0) # パープル
		TurretType.METEOR_LAUNCHER:
			modulate = Color(1.0, 0.45, 0.2) # オレンジレッド


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


func get_attack_interval() -> float:
	match turret_type:
		TurretType.BEAM_MACHINEGUN:
			return 10.0
		TurretType.HOMING_MISSILE:
			return 4.0
		TurretType.METEOR_LAUNCHER:
			return 5.0
	return 5.0


func start_attack_sequence() -> void:
	match turret_type:
		TurretType.BEAM_MACHINEGUN:
			is_charging = true
			charge_timer = 1.3 # 1.3秒チャージ (ゆったり予兆)
			var player = get_node_or_null("/root/Main/Player")
			beam_warning_target_x = player.global_position.x if is_instance_valid(player) else global_position.x
			spawn_turret_warning("⚠️ LASER CHARGE!")
		TurretType.HOMING_MISSILE:
			# 即時発射
			execute_attack()
		TurretType.METEOR_LAUNCHER:
			is_charging = true
			charge_timer = 1.3 # 赤く光って1.3秒チャージ
			spawn_turret_warning("⚠️ METEOR LAUNCH!")


func execute_attack() -> void:
	var main = get_node_or_null("/root/Main")
	var pool = main.get_node_or_null("BulletPool") if main else null
	var player = main.get_node_or_null("Player") if main else null
	
	match turret_type:
		TurretType.BEAM_MACHINEGUN:
			# 8発連射（ゆったりパリィ可能）
			if pool:
				for i in range(8):
					get_tree().create_timer(i * 0.1).timeout.connect(func():
						if is_instance_valid(self) and is_alive and is_instance_valid(pool):
							var bullet = pool.get_bullet("boss_laser")
							if bullet:
								bullet.global_position = global_position + Vector2(randf_range(-12, 12), 25)
								bullet.damage = 10
								# プレイヤー方向へわずかに角度をブレさせながら直進
								var dir = Vector2.DOWN
								if is_instance_valid(player):
									var target_x = player.global_position.x + randf_range(-30, 30)
									dir = (Vector2(target_x, player.global_position.y) - global_position).normalized()
								bullet.set_direction(dir, 620.0)
					)
					
		TurretType.HOMING_MISSILE:
			# 砲台から合計4発発射 ➔ 減速停止 ➔ 追尾
			if pool:
				var spread_angles = [-40.0, -20.0, 20.0, 40.0]
				for angle_deg in spread_angles:
					var bullet = pool.get_bullet("decel_missile")
					if bullet:
						bullet.global_position = global_position + Vector2(0.0, 20.0)
						bullet.damage = 8
						var launch_dir = Vector2.DOWN.rotated(deg_to_rad(angle_deg))
						bullet.set_direction(launch_dir, 320.0)
						
		TurretType.METEOR_LAUNCHER:
			# 巨大隕石射出 (画面内に最大4個)
			var current_meteors = get_tree().get_nodes_in_group("enemy_projectiles")
			if current_meteors.size() < 4 and METEOR_SCENE:
				var meteor = METEOR_SCENE.instantiate()
				meteor.global_position = global_position + Vector2(0.0, 30.0)
				
				# プレイヤー方向を基準に拡散角度で射出
				var shoot_dir = Vector2.DOWN.rotated(randf_range(-0.6, 0.6))
				if is_instance_valid(player):
					shoot_dir = (player.global_position - global_position).normalized().rotated(randf_range(-0.4, 0.4))
				meteor.set_direction(shoot_dir, 320.0)
				get_parent().add_child(meteor)


func _draw() -> void:
	# レーザー照射予告線
	if beam_warning_line_alpha > 0.0:
		var line_color = Color(1.0, 0.1, 0.1, beam_warning_line_alpha)
		var local_target_x = beam_warning_target_x - global_position.x
		draw_line(Vector2(0, 15), Vector2(local_target_x, 800), line_color, 2.5)
		var glow_color = Color(1.0, 0.3, 0.3, beam_warning_line_alpha * 0.3)
		draw_line(Vector2(0, 15), Vector2(local_target_x, 800), glow_color, 8.0)


func spawn_turret_warning(text: String) -> void:
	var label = Label.new()
	label.text = text
	var set = LabelSettings.new()
	set.font_size = 16
	set.font_color = Color.RED
	set.outline_size = 4
	set.outline_color = Color.BLACK
	label.label_settings = set
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.global_position = global_position + Vector2(-100, -40)
	label.custom_minimum_size = Vector2(200, 20)
	get_parent().add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "global_position:y", label.global_position.y - 30.0, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.chain().tween_callback(label.queue_free)


func take_damage(amount: int) -> void:
	if not is_alive:
		return
		
	current_hp -= amount
	
	# 被弾フラッシュ
	sprite.modulate = Color(1.0, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	var main = get_node_or_null("/root/Main")
	if main:
		var ui_node = main.get_node_or_null("UI")
		if ui_node and ui_node.has_method("spawn_damage_popup"):
			ui_node.spawn_damage_popup(global_position, amount, false)
			
	if current_hp <= 0:
		current_hp = 0
		destroy_turret()


func destroy_turret() -> void:
	is_alive = false
	is_active = false
	remove_from_group("boss_turrets")
	
	# 爆発演出
	if PARRY_PARTICLE_SCENE and get_parent():
		for i in range(8):
			var p = PARRY_PARTICLE_SCENE.instantiate()
			p.global_position = global_position + Vector2(randf_range(-25, 25), randf_range(-25, 25))
			p.scale = Vector2(2.5, 2.5)
			p.modulate = Color(1.0, randf_range(0.3, 0.8), 0.1)
			get_parent().add_child(p)
			
	Global.tech_points += 5
	
	var main = get_node_or_null("/root/Main")
	if main:
		var player = main.get_node_or_null("Player")
		if player:
			if player.has_method("heal"):
				player.heal(50)
			if player.has_method("spawn_popup_message"):
				player.spawn_popup_message("サブ砲台撃破！ +5 TP / 機体修復 +50 HP")
			
	# フェードアウトして消滅
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(queue_free)
