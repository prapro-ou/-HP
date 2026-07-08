extends Node2D
## ボススクリプト（古代防衛兵器）
## - 3部位（Core, LaserCannon, MissilePod）のHPと状態管理
## - 部位破壊によるエネルギー再配分と攻撃パターンの劇的な激化
## - 突進攻撃や薙ぎ払い攻撃などの行動制御

@export var max_hp: int = 2800 # UI用の見かけの合計HP
var laser_hp: int = 500
var missile_hp: int = 500
var core_hp: int = 1800

var laser_alive: bool = true
var missile_alive: bool = true
var core_alive: bool = true

# エネルギー配分
var energy_laser: float = 30.0
var energy_missile: float = 30.0
var energy_core: float = 40.0

var bullet_pool: Node2D
var player: CharacterBody2D

var fire_timer: float = 0.0
var pattern_timer: float = 0.0

# 移動・突進制御用
var move_target: Vector2 = Vector2.ZERO
var base_move_speed: float = 120.0
var current_move_speed: float = 120.0
var is_charging: bool = false
var charge_state: int = 0 # 0: 通常移動, 1: 狙い定め, 2: 突進急降下, 3: 上昇復帰
var charge_timer: float = 0.0
var target_charge_x: float = 0.0

# ビジュアルノード参照
@onready var laser_node: Area2D = $LaserCannon
@onready var missile_node: Area2D = $MissilePod
@onready var core_node: Area2D = $Core
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	bullet_pool = get_node_or_null("../BulletPool")
	player = get_node_or_null("../Player")
	choose_new_target()
	
	# ボスを enemy グループに入れて、プレイヤーのミサイルが追尾するようにする
	add_to_group("enemy")
	add_to_group("boss")


func _process(delta: float) -> void:
	if not core_alive:
		return
		
	# 突進攻撃中でなければ通常移動
	if not is_charging:
		# 目標座標へ移動
		position = position.move_toward(move_target, current_move_speed * delta)
		if position.distance_to(move_target) < 10.0:
			choose_new_target()
	else:
		process_charge(delta)
		
	# 射撃タイマー
	fire_timer += delta
	pattern_timer += delta
	
	# 攻撃パターンの実行
	process_attacks()


func choose_new_target() -> void:
	var viewport_rect = get_viewport_rect()
	if viewport_rect:
		var rx = randf_range(150.0, viewport_rect.size.x - 150.0)
		var ry = randf_range(80.0, 180.0)
		move_target = Vector2(rx, ry)


func process_charge(delta: float) -> void:
	match charge_state:
		1: # 狙い定め（赤く点滅、一時停止）
			charge_timer += delta
			sprite.modulate = Color(1.0, 0.2, 0.2) if int(charge_timer * 10.0) % 2 == 0 else Color.WHITE
			if charge_timer >= 1.0:
				charge_state = 2
				charge_timer = 0.0
				if is_instance_valid(player):
					target_charge_x = player.global_position.x
				else:
					target_charge_x = position.x
		2: # 突進急降下（超高速で画面下部へ）
			sprite.modulate = Color.RED
			var target_pos = Vector2(target_charge_x, 850.0)
			position = position.move_toward(target_pos, 900.0 * delta)
			# 周囲に弾をまき散らしながら突進
			if int(Time.get_ticks_msec() / 50.0) % 2 == 0:
				spawn_bullet(Vector2.UP.rotated(randf_range(-PI, PI)), "boss_missile", 250.0)
				
			if position.distance_to(target_pos) < 20.0 or position.y >= 840.0:
				charge_state = 3
				sprite.modulate = Color.WHITE
		3: # 上昇復帰（ゆっくり元の位置に戻る）
			var home_pos = Vector2(get_viewport_rect().size.x / 2.0, 120.0)
			position = position.move_toward(home_pos, 250.0 * delta)
			if position.distance_to(home_pos) < 20.0:
				is_charging = false
				charge_state = 0
				choose_new_target()


func start_charge_attack() -> void:
	if is_charging:
		return
	is_charging = true
	charge_state = 1
	charge_timer = 0.0


func process_attacks() -> void:
	var interval = 2.0
	# ボスの状態によって攻撃頻度を変化させる
	if not laser_alive and not missile_alive:
		interval = 0.8 # 最終形態は超連射
	elif not laser_alive or not missile_alive:
		interval = 1.3 # 片方破壊時はやや早くなる
		
	if fire_timer >= interval:
		fire_timer = 0.0
		execute_attack_pattern()


func execute_attack_pattern() -> void:
	if laser_alive and missile_alive:
		# 両方健在：標準攻撃
		# 1. レーザーキャノンから5方向扇状レーザー弾
		var angles = [70, 80, 90, 100, 110]
		for angle in angles:
			var rad = deg_to_rad(angle)
			var dir = Vector2(cos(rad), sin(rad))
			spawn_bullet(dir, "boss_laser", 220.0, laser_node.global_position)
		
		# 2. ミサイルポッドからプレイヤー狙い3連射
		var dir_to_player = Vector2.DOWN
		if is_instance_valid(player):
			dir_to_player = (player.global_position - missile_node.global_position).normalized()
		
		var main_tree = get_tree()
		if main_tree:
			# 少しディレイをかけて3発発射
			for i in range(3):
				main_tree.create_timer(i * 0.15).timeout.connect(func():
					if is_instance_valid(self) and missile_alive:
						var current_dir = dir_to_player
						if is_instance_valid(player):
							current_dir = (player.global_position - missile_node.global_position).normalized()
						spawn_bullet(current_dir, "boss_missile", 180.0, missile_node.global_position)
				)
				
	elif not laser_alive and missile_alive:
		# レーザー破壊、ミサイル生存：ミサイル超強化 + 突進
		# 1. ミサイルポッドからプレイヤーを追尾するマルチミサイル（6発全方位）
		for i in range(6):
			var angle = (360.0 / 6) * i
			var rad = deg_to_rad(angle)
			var dir = Vector2(cos(rad), sin(rad))
			spawn_bullet(dir, "boss_missile", 220.0, missile_node.global_position)
			
		# 2. 確率で突進攻撃開始
		if randf() > 0.4:
			start_charge_attack()
			
	elif laser_alive and not missile_alive:
		# ミサイル破壊、レーザー生存：レーザー超強化 (極太薙ぎ払い)
		for i in range(12):
			var angle = 50.0 + (80.0 / 11) * i
			var rad = deg_to_rad(angle)
			var dir = Vector2(cos(rad), sin(rad))
			spawn_bullet(dir, "boss_laser", 300.0, laser_node.global_position)
			
	else:
		# 両方破壊（Coreのみ）：最終怒り状態
		# 1. 全方位にスパイラル螺旋弾幕 (Coreから発射)
		var base_angle = randf_range(0, 360)
		for i in range(16):
			var angle = base_angle + (360.0 / 16) * i
			var rad = deg_to_rad(angle)
			var dir = Vector2(cos(rad), sin(rad))
			spawn_bullet(dir, "boss_laser", 250.0, core_node.global_position)
			
		# 2. 常に激しい突進も行う（交互に突進）
		if pattern_timer >= 3.5:
			pattern_timer = 0.0
			start_charge_attack()


func spawn_bullet(direction: Vector2, type: String, speed_override: float = 0.0, spawn_pos: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(bullet_pool):
		return
	if spawn_pos == Vector2.ZERO:
		spawn_pos = global_position
		
	var bullet = bullet_pool.get_bullet(type)
	if bullet:
		bullet.global_position = spawn_pos
		bullet.set_direction(direction, speed_override)


func take_damage_on_part(part_name: String, amount: int) -> void:
	# コアが既に破壊されていても、撃破演出中ならダメージポップアップとスコア加算だけは処理する
	var is_finish_phase = not core_alive
	
	# ダメージ適用位置
	var pop_pos = global_position
	if part_name == "laser" and is_instance_valid(laser_node):
		pop_pos = laser_node.global_position
	elif part_name == "missile" and is_instance_valid(missile_node):
		pop_pos = missile_node.global_position
	elif is_instance_valid(core_node):
		pop_pos = core_node.global_position
		
	# スコアとポップアップの処理
	var main = get_node_or_null("/root/Main")
	if main:
		var manager = main.get_node_or_null("GameManager")
		if manager and manager.has_method("add_damage_score"):
			# トドメ演出中はダメージスコアを10倍にして爽快感を出す！
			var score_add = amount * 10 if is_finish_phase else amount
			manager.add_damage_score(score_add)
			
		var ui_node = main.get_node_or_null("UI")
		if ui_node and ui_node.has_method("spawn_damage_popup"):
			ui_node.spawn_damage_popup(pop_pos, amount * 10 if is_finish_phase else amount, is_finish_phase)

	if is_finish_phase:
		return # コア死亡後はHP減少や部位破壊処理は行わない
		
	# --- 通常時のダメージ処理 ---
	match part_name:
		"laser":
			if laser_alive:
				laser_hp -= amount
				if laser_hp <= 0:
					laser_hp = 0
					laser_alive = false
					destroy_part("laser")
		"missile":
			if missile_alive:
				missile_hp -= amount
				if missile_hp <= 0:
					missile_hp = 0
					missile_alive = false
					destroy_part("missile")
		"core":
			# 他の部位が健在な間は本体シールドが有効で、ダメージを90%カットする！
			var actual_amount = amount
			if laser_alive or missile_alive:
				actual_amount = int(amount * 0.1)
				if actual_amount < 1:
					actual_amount = 1
				if randf() > 0.7:
					spawn_shield_popup()
					
			core_hp -= actual_amount
			if core_hp <= 0:
				core_hp = 0
				core_alive = false
				destroy_boss()


func spawn_shield_popup() -> void:
	var label = Label.new()
	label.text = "SHIELD ACTIVE: DESTROY PARTS FIRST!"
	var settings = LabelSettings.new()
	settings.font_size = 14
	settings.font_color = Color.RED
	settings.outline_size = 3
	settings.outline_color = Color.BLACK
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.global_position = global_position + Vector2(-150, -60)
	label.custom_minimum_size = Vector2(300, 30)
	get_parent().add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "global_position", label.global_position + Vector2(0, -40), 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(label.queue_free)


func destroy_part(part_type: String) -> void:
	spawn_explosion_particles(part_type)
	
	# 部位の見た目をグレーにする
	if part_type == "laser" and is_instance_valid(laser_node):
		laser_node.modulate = Color(0.2, 0.2, 0.2, 0.5)
	elif part_type == "missile" and is_instance_valid(missile_node):
		missile_node.modulate = Color(0.2, 0.2, 0.2, 0.5)
		
	# プレイヤーの武器をアップグレード！
	if is_instance_valid(player) and player.has_method("upgrade_weapon"):
		player.upgrade_weapon(part_type)
		
	# エネルギーの再配分
	reallocate_energy()


func reallocate_energy() -> void:
	if laser_alive and missile_alive:
		energy_laser = 30.0
		energy_missile = 30.0
		energy_core = 40.0
	elif not laser_alive and missile_alive:
		energy_laser = 0.0
		energy_missile = 45.0
		energy_core = 55.0
		base_move_speed = 180.0
		current_move_speed = 180.0
	elif laser_alive and not missile_alive:
		energy_laser = 45.0
		energy_missile = 0.0
		energy_core = 55.0
		base_move_speed = 180.0
		current_move_speed = 180.0
	else:
		# 両方破壊
		energy_laser = 0.0
		energy_missile = 0.0
		energy_core = 100.0
		base_move_speed = 280.0
		current_move_speed = 280.0
		var tween = create_tween().set_loops()
		tween.tween_property(sprite, "modulate", Color(1.0, 0.4, 0.4), 0.3)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)


func spawn_explosion_particles(part_type: String) -> void:
	var pos = global_position
	var part_color = Color.WHITE
	if part_type == "laser" and is_instance_valid(laser_node):
		pos = laser_node.global_position
		part_color = Color.CYAN
	elif part_type == "missile" and is_instance_valid(missile_node):
		pos = missile_node.global_position
		part_color = Color.VIOLET
		
	var ParryParticleScene = load("res://game/scenes/parry_particle.tscn")
	if ParryParticleScene:
		for i in range(3):
			var particle = ParryParticleScene.instantiate()
			particle.global_position = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
			particle.scale = Vector2(2.5, 2.5)
			particle.modulate = part_color
			get_parent().add_child(particle)


func destroy_boss() -> void:
	# 移動を完全に停止
	is_charging = false
	charge_state = 0
	current_move_speed = 0.0
	
	var ParryParticleScene = load("res://game/scenes/parry_particle.tscn")
	var main_tree = get_tree()
	if ParryParticleScene and main_tree:
		# 撃破中の連続爆発演出
		for i in range(15): # 爆発数を増やして派手に
			main_tree.create_timer(i * 0.12).timeout.connect(func():
				if is_instance_valid(self):
					var particle = ParryParticleScene.instantiate()
					particle.global_position = global_position + Vector2(randf_range(-80, 80), randf_range(-80, 80))
					particle.scale = Vector2(3.5, 3.5)
					particle.modulate = Color(1.0, randf_range(0.2, 0.7), 0.1)
					get_parent().add_child(particle)
					
					# 被弾したような赤点滅
					sprite.modulate = Color(1.0, 0.3, 0.3, 0.7)
					var flash_tween = create_tween()
					flash_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.7), 0.08)
			)
			
	# 2.2秒間プレイヤーのフルバーストを受け止めさせた後、大爆発とともに消滅
	main_tree.create_timer(2.2).timeout.connect(func():
		# 最後のトドメ大爆発
		if ParryParticleScene and get_parent():
			for j in range(8):
				var p = ParryParticleScene.instantiate()
				p.global_position = global_position + Vector2(randf_range(-120, 120), randf_range(-120, 120))
				p.scale = Vector2(5.0, 5.0)
				p.modulate = Color.CYAN
				get_parent().add_child(p)
				
		var main = get_node_or_null("/root/Main")
		if main:
			var manager = main.get_node_or_null("GameManager")
			if manager and manager.has_method("on_boss_destroyed"):
				manager.on_boss_destroyed()
		
		# ここで初めてノードを削除
		queue_free()
	)


func get_current_hp() -> int:
	return laser_hp + missile_hp + core_hp

