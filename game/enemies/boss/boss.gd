extends Node2D
## ボススクリプト（古代防衛兵器）
## - 3部位（Core, LaserCannon, MissilePod）のHPと状態管理
## - 部位破壊によるエネルギー再配分と攻撃パターンの激化
## - 突進攻撃や薙ぎ払い攻撃などの行動制御

# --- 調整定数 ---
const BOSS_SCALE: Vector2 = Vector2(2.8, 2.8)
const CHARGE_RUSH_SPEED: float = 1100.0
const CHARGE_RETURN_SPEED: float = 350.0
const SMOKE_PARTICLE_INTERVAL: float = 0.22

# 部位定義定数
const PART_CORE = "core"
const PART_LASER = "laser"
const PART_MISSILE = "missile"

# 弾丸タイプ定数
const BULLET_TYPE_LASER = "boss_laser"
const BULLET_TYPE_MISSILE = "boss_missile"

# パラメータ（GameManager / StageConfig から注入可能）
@export var max_hp: int = 6000
var laser_hp: int = 1200
var missile_hp: int = 1200
var core_hp: int = 3600

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
var base_move_speed: float = 140.0
var current_move_speed: float = 140.0
var is_charging: bool = false
var charge_state: int = 0 # 0: 通常移動, 1: 狙い定め, 2: 突進急降下, 3: 上昇復帰
var charge_timer: float = 0.0
var target_charge_x: float = 0.0

# ビジュアルノード参照
@onready var laser_node: Area2D = $LaserCannon
@onready var missile_node: Area2D = $MissilePod
@onready var core_node: Area2D = $Core
@onready var sprite: Sprite2D = $Sprite2D

var stage_number: int = 1
var laser_smoke_timer: float = 0.0
var missile_smoke_timer: float = 0.0

const PARRY_PARTICLE_SCENE: PackedScene = preload("res://game/bullets/parry_particle.tscn")


func _ready() -> void:
	bullet_pool = get_node_or_null("/root/Main/BulletPool")
	player = get_node_or_null("/root/Main/Player")
	choose_new_target()
	
	scale = BOSS_SCALE
	
	var save_data = Global.load_game_data()
	stage_number = save_data.get("stage_num", 1)
	
	add_to_group("enemy")
	add_to_group("boss")


func _process(delta: float) -> void:
	if not core_alive:
		return
		
	if not laser_alive and is_instance_valid(laser_node):
		laser_smoke_timer += delta
		if laser_smoke_timer >= SMOKE_PARTICLE_INTERVAL:
			laser_smoke_timer = 0.0
			spawn_smoke_particles(laser_node.global_position, Color.CYAN)
			
	if not missile_alive and is_instance_valid(missile_node):
		missile_smoke_timer += delta
		if missile_smoke_timer >= SMOKE_PARTICLE_INTERVAL:
			missile_smoke_timer = 0.0
			spawn_smoke_particles(missile_node.global_position, Color(0.9, 0.4, 1.0))
		
	if not is_charging:
		position = position.move_toward(move_target, current_move_speed * delta)
		if position.distance_to(move_target) < 10.0:
			choose_new_target()
	else:
		process_charge(delta)
		
	fire_timer += delta
	pattern_timer += delta
	
	process_attacks()


func choose_new_target() -> void:
	var viewport_rect = get_viewport_rect()
	if viewport_rect:
		var rx = randf_range(150.0, viewport_rect.size.x - 150.0)
		var ry = randf_range(80.0, 180.0)
		move_target = Vector2(rx, ry)


func process_charge(delta: float) -> void:
	match charge_state:
		1: # 狙い定め
			charge_timer += delta
			sprite.modulate = Color(1.0, 0.2, 0.2) if int(charge_timer * 12.0) % 2 == 0 else Color.WHITE
			if charge_timer >= 0.7:
				charge_state = 2
				charge_timer = 0.0
				if is_instance_valid(player):
					target_charge_x = player.global_position.x
				else:
					target_charge_x = position.x
		2: # 突進急降下
			sprite.modulate = Color.RED
			var target_pos = Vector2(target_charge_x, 850.0)
			position = position.move_toward(target_pos, CHARGE_RUSH_SPEED * delta)
			
			if int(Time.get_ticks_msec() / 40.0) % 2 == 0:
				spawn_bullet(Vector2.UP.rotated(randf_range(-PI, PI)), BULLET_TYPE_MISSILE, 320.0)
				
			if position.distance_to(target_pos) < 20.0 or position.y >= 840.0:
				charge_state = 3
				sprite.modulate = Color.WHITE
		3: # 上昇復帰
			var home_pos = Vector2(get_viewport_rect().size.x / 2.0, 120.0)
			position = position.move_toward(home_pos, CHARGE_RETURN_SPEED * delta)
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
	var interval = 2.5
	if not laser_alive and not missile_alive:
		interval = 1.5
	elif not laser_alive or not missile_alive:
		interval = 2.0
		
	if fire_timer >= interval:
		fire_timer = 0.0
		execute_attack_pattern()


func execute_attack_pattern() -> void:
	if laser_alive and missile_alive:
		if stage_number == 2:
			var angles = [30, 45, 60, 70, 80, 90, 100, 110, 120, 135, 150]
			for angle in angles:
				var rad = deg_to_rad(angle)
				var dir = Vector2(cos(rad), sin(rad))
				spawn_bullet(dir, BULLET_TYPE_LASER, 340.0, laser_node.global_position)
				
			var dir_to_player = Vector2.DOWN
			if is_instance_valid(player):
				dir_to_player = (player.global_position - missile_node.global_position).normalized()
				
			var main_tree = get_tree()
			if main_tree:
				for i in range(8):
					main_tree.create_timer(i * 0.08).timeout.connect(func():
						if is_instance_valid(self) and missile_alive:
							var current_dir = dir_to_player
							if is_instance_valid(player):
								current_dir = (player.global_position - missile_node.global_position).normalized()
							current_dir = current_dir.rotated(randf_range(-0.2, 0.2))
							spawn_bullet(current_dir, BULLET_TYPE_MISSILE, 280.0, missile_node.global_position)
					)
		else:
			var angles = [50, 60, 70, 80, 90, 100, 110, 120, 130]
			for angle in angles:
				var rad = deg_to_rad(angle)
				var dir = Vector2(cos(rad), sin(rad))
				spawn_bullet(dir, BULLET_TYPE_LASER, 300.0, laser_node.global_position)
			
			var dir_to_player = Vector2.DOWN
			if is_instance_valid(player):
				dir_to_player = (player.global_position - missile_node.global_position).normalized()
			
			var main_tree = get_tree()
			if main_tree:
				for i in range(5):
					main_tree.create_timer(i * 0.10).timeout.connect(func():
						if is_instance_valid(self) and missile_alive:
							var current_dir = dir_to_player
							if is_instance_valid(player):
								current_dir = (player.global_position - missile_node.global_position).normalized()
							spawn_bullet(current_dir, BULLET_TYPE_MISSILE, 240.0, missile_node.global_position)
					)
					
	elif not laser_alive and missile_alive:
		var num_missiles = 16 if stage_number == 2 else 12
		var speed_mult = 320.0 if stage_number == 2 else 280.0
		for i in range(num_missiles):
			var angle = (360.0 / num_missiles) * i
			var rad = deg_to_rad(angle)
			var dir = Vector2(cos(rad), sin(rad))
			spawn_bullet(dir, BULLET_TYPE_MISSILE, speed_mult, missile_node.global_position)
			
		if randf() > 0.1:
			start_charge_attack()
			
	elif laser_alive and not missile_alive:
		var num_lasers = 24 if stage_number == 2 else 18
		var angle_start = 20.0 if stage_number == 2 else 30.0
		var angle_span = 140.0 if stage_number == 2 else 120.0
		for i in range(num_lasers):
			var angle = angle_start + (angle_span / (num_lasers - 1)) * i
			var rad = deg_to_rad(angle)
			var dir = Vector2(cos(rad), sin(rad))
			spawn_bullet(dir, BULLET_TYPE_LASER, 380.0, laser_node.global_position)
			
	else:
		var num_spiral = 32 if stage_number == 2 else 24
		var speed_spiral = 340.0 if stage_number == 2 else 300.0
		var base_angle = randf_range(0, 360)
		for i in range(num_spiral):
			var angle = base_angle + (360.0 / num_spiral) * i
			var rad = deg_to_rad(angle)
			var dir = Vector2(cos(rad), sin(rad))
			spawn_bullet(dir, BULLET_TYPE_LASER, speed_spiral, core_node.global_position)
			
		var charge_interval = 4.0 if stage_number == 2 else 5.0
		if pattern_timer >= charge_interval:
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
	var is_finish_phase = not core_alive
	
	var pop_pos = global_position
	if part_name == PART_LASER and is_instance_valid(laser_node):
		pop_pos = laser_node.global_position
	elif part_name == PART_MISSILE and is_instance_valid(missile_node):
		pop_pos = missile_node.global_position
	elif is_instance_valid(core_node):
		pop_pos = core_node.global_position
		
	var main = get_node_or_null("/root/Main")
	if main:
		var manager = main.get_node_or_null("GameManager")
		if manager and manager.has_method("add_damage_score"):
			var score_add = amount * 10 if is_finish_phase else amount
			manager.add_damage_score(score_add)
			
		var ui_node = main.get_node_or_null("UI")
		if ui_node and ui_node.has_method("spawn_damage_popup"):
			ui_node.spawn_damage_popup(pop_pos, amount * 10 if is_finish_phase else amount, is_finish_phase)

	if is_finish_phase:
		return
		
	match part_name:
		PART_LASER:
			if laser_alive:
				laser_hp -= amount
				if laser_hp <= 0:
					laser_hp = 0
					laser_alive = false
					destroy_part(PART_LASER)
		PART_MISSILE:
			if missile_alive:
				missile_hp -= amount
				if missile_hp <= 0:
					missile_hp = 0
					missile_alive = false
					destroy_part(PART_MISSILE)
		PART_CORE:
			var actual_amount = amount
			if laser_alive or missile_alive:
				actual_amount = int(amount * 0.05)
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
	label.text = "バリア発動中！部位を破壊せよ！"
	var settings = LabelSettings.new()
	settings.font_size = 22
	settings.font_color = Color.RED
	settings.outline_size = 6
	settings.outline_color = Color.BLACK
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.global_position = global_position + Vector2(-150.0, -60.0)
	label.custom_minimum_size = Vector2(300.0, 30.0)
	get_parent().add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "global_position", label.global_position + Vector2(0.0, -40.0), 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(label.queue_free)


func destroy_part(part_type: String) -> void:
	spawn_explosion_particles(part_type)
	
	if part_type == PART_LASER and is_instance_valid(laser_node):
		laser_node.modulate = Color(0.2, 0.2, 0.2, 0.5)
	elif part_type == PART_MISSILE and is_instance_valid(missile_node):
		missile_node.modulate = Color(0.2, 0.2, 0.2, 0.5)
		
	if is_instance_valid(player) and player.has_method("upgrade_weapon"):
		player.upgrade_weapon(part_type)
		
	var main = get_node_or_null("/root/Main")
	if main:
		var manager = main.get_node_or_null("GameManager")
		if manager and manager.has_method("add_tech_points"):
			manager.add_tech_points(12)
			if player and player.has_method("spawn_popup_message"):
				player.spawn_popup_message("部位破壊！ +12 TP")
		
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
	if part_type == PART_LASER and is_instance_valid(laser_node):
		pos = laser_node.global_position
		part_color = Color.CYAN
	elif part_type == PART_MISSILE and is_instance_valid(missile_node):
		pos = missile_node.global_position
		part_color = Color.VIOLET
		
	if PARRY_PARTICLE_SCENE:
		for i in range(3):
			var particle = PARRY_PARTICLE_SCENE.instantiate()
			particle.global_position = pos + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
			particle.scale = Vector2(2.5, 2.5)
			particle.modulate = part_color
			get_parent().add_child(particle)


func destroy_boss() -> void:
	is_charging = false
	charge_state = 0
	current_move_speed = 0.0
	
	var main_tree = get_tree()
	if PARRY_PARTICLE_SCENE and main_tree:
		for i in range(15):
			main_tree.create_timer(i * 0.12).timeout.connect(func():
				if is_instance_valid(self):
					var particle = PARRY_PARTICLE_SCENE.instantiate()
					particle.global_position = global_position + Vector2(randf_range(-80.0, 80.0), randf_range(-80.0, 80.0))
					particle.scale = Vector2(3.5, 3.5)
					particle.modulate = Color(1.0, randf_range(0.2, 0.7), 0.1)
					get_parent().add_child(particle)
					
					sprite.modulate = Color(1.0, 0.3, 0.3, 0.7)
					var flash_tween = create_tween()
					flash_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.7), 0.08)
			)
			
	main_tree.create_timer(2.2).timeout.connect(func():
		if PARRY_PARTICLE_SCENE and get_parent():
			for j in range(8):
				var p = PARRY_PARTICLE_SCENE.instantiate()
				p.global_position = global_position + Vector2(randf_range(-120.0, 120.0), randf_range(-120.0, 120.0))
				p.scale = Vector2(5.0, 5.0)
				p.modulate = Color.CYAN
				get_parent().add_child(p)
				
		var main = get_node_or_null("/root/Main")
		if main:
			var manager = main.get_node_or_null("GameManager")
			if manager and manager.has_method("on_boss_destroyed"):
				manager.on_boss_destroyed()
		
		queue_free()
	)


func get_current_hp() -> int:
	return laser_hp + missile_hp + core_hp


func spawn_smoke_particles(pos: Vector2, color: Color) -> void:
	if PARRY_PARTICLE_SCENE and get_parent():
		var particle = PARRY_PARTICLE_SCENE.instantiate()
		particle.global_position = pos + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
		particle.scale = Vector2(1.2, 1.2)
		particle.modulate = color
		get_parent().add_child(particle)
