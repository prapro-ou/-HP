extends Node2D
## 最終ボススクリプト（【終焉の支配者】オーバーロード・オメガ / OVERLORD OMEGA）
## Stage 5 の真のラストボス
## - 2段階フェーズ構成（Phase 1: 全武装形態, Phase 2: オーバーロード覚醒形態）
## - 画面全体を覆う豪華な描画オーラ・幾何学的渦状弾幕
## - 突進、ハイパーレーザー、追尾クラスター、全方位パリィ弾幕

@export var max_hp: int = 12000
var laser_hp: int = 2500
var missile_hp: int = 2500
var core_hp: int = 7000

var laser_alive: bool = true
var missile_alive: bool = true
var core_alive: bool = true

# フェーズ管理 (1: 通常, 2: 覚醒オーバーロード)
var phase: int = 1
var is_entering: bool = true
var enter_progress: float = 0.0
var aura_time: float = 0.0

var bullet_pool: Node2D
var player: CharacterBody2D

var fire_timer: float = 0.0
var pattern_timer: float = 0.0
var spiral_angle: float = 0.0

# 移動・制御用
var move_target: Vector2 = Vector2.ZERO
var base_move_speed: float = 160.0
var current_move_speed: float = 160.0
var is_charging: bool = false
var charge_state: int = 0
var charge_timer: float = 0.0
var target_charge_x: float = 0.0

# パーティクル/エフェクト用
var laser_smoke_timer: float = 0.0
var missile_smoke_timer: float = 0.0

# ノード参照
@onready var laser_node: Area2D = $LaserCannon
@onready var missile_node: Area2D = $MissilePod
@onready var core_node: Area2D = $Core
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	max_hp = int(max_hp * Global.get_enemy_hp_multiplier())
	laser_hp = int(laser_hp * Global.get_enemy_hp_multiplier())
	missile_hp = int(missile_hp * Global.get_enemy_hp_multiplier())
	core_hp = int(core_hp * Global.get_enemy_hp_multiplier())
	
	bullet_pool = get_node_or_null("/root/Main/BulletPool")
	if not bullet_pool:
		bullet_pool = get_tree().get_first_node_in_group("bullet_pool")
		
	player = get_node_or_null("/root/Main/Player")
	if not player:
		player = get_tree().get_first_node_in_group("player")
		
	scale = Vector2(3.5, 3.5)
	modulate = Color(1.2, 0.9, 1.5, 1.0) # 深みのあるゴールド＆パープル輝き
	
	add_to_group("enemy")
	add_to_group("boss")
	add_to_group("final_boss")
	
	# 画面外上部からスタート
	position = Vector2(get_viewport_rect().size.x / 2.0, -250.0)
	choose_new_target()

func _process(delta: float) -> void:
	aura_time += delta
	queue_redraw()
	
	if is_entering:
		process_entrance(delta)
		return
		
	if not core_alive:
		return
		
	# 部位壊滅時の炎上エフェクト
	if not laser_alive and is_instance_valid(laser_node):
		laser_smoke_timer += delta
		if laser_smoke_timer >= 0.15:
			laser_smoke_timer = 0.0
			spawn_smoke_particles(laser_node.global_position, Color.GOLD)
			
	if not missile_alive and is_instance_valid(missile_node):
		missile_smoke_timer += delta
		if missile_smoke_timer >= 0.15:
			missile_smoke_timer = 0.0
			spawn_smoke_particles(missile_node.global_position, Color(1.0, 0.2, 0.6))

	# Phase 1 -> Phase 2 覚醒チェック
	if phase == 1 and not laser_alive and not missile_alive and core_hp <= 4000:
		trigger_phase_2_overload()
		
	# 移動制御
	if not is_charging:
		position = position.move_toward(move_target, current_move_speed * delta)
		if position.distance_to(move_target) < 15.0:
			choose_new_target()
	else:
		process_charge(delta)
		
	fire_timer += delta
	pattern_timer += delta
	spiral_angle += delta * (3.5 if phase == 2 else 2.0)
	
	process_proximity_counter_attack(delta)
	process_attacks()


var close_proximity_timer: float = 0.0
const CLOSE_PROXIMITY_COOLDOWN: float = 3.5
const CLOSE_PROXIMITY_DISTANCE: float = 240.0

func process_proximity_counter_attack(delta: float) -> void:
	if close_proximity_timer > 0.0:
		close_proximity_timer -= delta
		return
		
	if is_entering or not core_alive or not is_instance_valid(player) or not is_instance_valid(bullet_pool):
		return
		
	var dist = player.global_position.distance_to(global_position)
	if dist <= CLOSE_PROXIMITY_DISTANCE:
		close_proximity_timer = CLOSE_PROXIMITY_COOLDOWN
		# 全方位迎撃リング弾幕
		Global.play_laser(1.2)
		spawn_ring_bullets(16 if phase == 1 else 20, "boss_laser", 300.0)

func process_entrance(delta: float) -> void:
	var target_y = 150.0
	position.y = move_toward(position.y, target_y, 120.0 * delta)
	if abs(position.y - target_y) < 5.0:
		is_entering = false
		choose_new_target()

func trigger_phase_2_overload() -> void:
	phase = 2
	current_move_speed = 240.0
	# 全回復＆パワーアップ
	core_hp = int(8000 * Global.get_enemy_hp_multiplier())
	max_hp = core_hp
	
	# 演出: 画面上に衝撃波・オーラ変色
	scale = Vector2(4.0, 4.0)
	modulate = Color(2.0, 0.4, 0.4, 1.0) # 漆黒赤熱
	
	# 画面フラッシュ＆揺れ
	if get_parent() and get_parent().has_method("trigger_screen_shake"):
		get_parent().trigger_screen_shake(1.5, 25.0)

func choose_new_target() -> void:
	var viewport_rect = get_viewport_rect()
	if viewport_rect:
		var rx = randf_range(160.0, viewport_rect.size.x - 160.0)
		var ry = randf_range(90.0, 220.0)
		move_target = Vector2(rx, ry)

func process_charge(delta: float) -> void:
	match charge_state:
		1:
			charge_timer += delta
			sprite.modulate = Color(2.0, 0.2, 0.8) if int(charge_timer * 16.0) % 2 == 0 else Color.WHITE
			if charge_timer >= 0.5 * Global.get_enemy_attack_interval_multiplier():
				charge_state = 2
				charge_timer = 0.0
				if is_instance_valid(player):
					target_charge_x = player.global_position.x
				else:
					target_charge_x = position.x
		2:
			sprite.modulate = Color(2.0, 0.1, 0.1)
			var target_pos = Vector2(target_charge_x, 880.0)
			position = position.move_toward(target_pos, 1400.0 * delta)
			
			# 突進中に全方位環状弾を放出
			if int(Time.get_ticks_msec() / 30.0) % 2 == 0:
				spawn_ring_bullets(8, "boss_laser", 350.0)
				
			if position.distance_to(target_pos) < 25.0 or position.y >= 860.0:
				charge_state = 3
				sprite.modulate = Color.WHITE
		3:
			var home_pos = Vector2(get_viewport_rect().size.x / 2.0, 150.0)
			position = position.move_toward(home_pos, 450.0 * delta)
			if position.distance_to(home_pos) < 25.0:
				is_charging = false
				charge_state = 0
				choose_new_target()

func start_charge_attack() -> void:
	if not is_charging and core_alive:
		is_charging = true
		charge_state = 1
		charge_timer = 0.0

func process_attacks() -> void:
	var at_mult = Global.get_enemy_attack_interval_multiplier()
	# Phase 1 行動パターン
	if phase == 1:
		if fire_timer >= 0.6 * at_mult:
			fire_timer = 0.0
			spawn_spiral_barrage()
			
		if pattern_timer >= 4.5 * at_mult:
			pattern_timer = 0.0
			if randf() > 0.4:
				start_charge_attack()
			else:
				spawn_homing_cluster()
	# Phase 2 (OVERLOAD) 超劇的行動パターン
	else:
		if fire_timer >= 0.35 * at_mult:
			fire_timer = 0.0
			spawn_apocalypse_vortex()
			
		if pattern_timer >= 3.2 * at_mult:
			pattern_timer = 0.0
			if randf() > 0.3:
				spawn_ring_bullets(16, "boss_laser", 400.0)
				start_charge_attack()
			else:
				spawn_homing_cluster()

func spawn_spiral_barrage() -> void:
	# 渦巻き全方位弾
	var arms = 5 if phase == 1 else 8
	for i in range(arms):
		var angle = spiral_angle + (i * TAU / arms)
		var dir = Vector2.DOWN.rotated(angle)
		spawn_bullet(dir, "boss_laser", 300.0)

func spawn_apocalypse_vortex() -> void:
	# 二重反対回転スパイラル弾幕
	var arms = 6
	for i in range(arms):
		var angle1 = spiral_angle + (i * TAU / arms)
		var angle2 = -spiral_angle + (i * TAU / arms)
		spawn_bullet(Vector2.DOWN.rotated(angle1), "boss_laser", 320.0)
		spawn_bullet(Vector2.DOWN.rotated(angle2), "boss_missile", 280.0)

func spawn_ring_bullets(count: int, type: String, speed: float) -> void:
	for i in range(count):
		var angle = (i * TAU / count)
		var dir = Vector2.RIGHT.rotated(angle)
		spawn_bullet(dir, type, speed)

func spawn_homing_cluster() -> void:
	if not is_instance_valid(player):
		return
	var base_dir = (player.global_position - global_position).normalized()
	for i in range(-2, 3):
		var dir = base_dir.rotated(i * 0.18)
		spawn_bullet(dir, "boss_missile", 380.0)

func spawn_bullet(dir: Vector2, type: String, speed: float) -> void:
	if bullet_pool and bullet_pool.has_method("spawn_bullet"):
		bullet_pool.spawn_bullet(global_position, dir, type, speed)

func take_part_damage(part_name: String, amount: int) -> void:
	if not core_alive:
		return
		
	match part_name:
		"laser":
			if laser_alive:
				laser_hp -= amount
				if laser_hp <= 0:
					laser_hp = 0
					laser_alive = false
					if is_instance_valid(laser_node):
						laser_node.visible = false
						laser_node.process_mode = PROCESS_MODE_DISABLED
					spawn_part_explosion(laser_node.global_position)
		"missile":
			if missile_alive:
				missile_hp -= amount
				if missile_hp <= 0:
					missile_hp = 0
					missile_alive = false
					if is_instance_valid(missile_node):
						missile_node.visible = false
						missile_node.process_mode = PROCESS_MODE_DISABLED
					spawn_part_explosion(missile_node.global_position)
		"core":
			core_hp -= amount
			if core_hp <= 0:
				core_hp = 0
				core_alive = false
				trigger_final_boss_defeat()

func trigger_final_boss_defeat() -> void:
	# コア破壊・完全討伐
	process_mode = PROCESS_MODE_DISABLED
	hide()
	spawn_part_explosion(global_position)

func spawn_part_explosion(pos: Vector2) -> void:
	var particle_scene = load("res://game/bullets/parry_particle.tscn")
	if particle_scene:
		var p = particle_scene.instantiate()
		p.global_position = pos
		p.modulate = Color(2.0, 1.5, 0.2)
		p.scale = Vector2(3.0, 3.0)
		get_parent().add_child(p)

func spawn_smoke_particles(pos: Vector2, color: Color) -> void:
	var particle_scene = load("res://game/bullets/parry_particle.tscn")
	if particle_scene:
		var p = particle_scene.instantiate()
		p.global_position = pos + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		p.modulate = color
		p.scale = Vector2(1.2, 1.2)
		get_parent().add_child(p)

func _draw() -> void:
	# オーラ描画（脈動する円環）
	var pulse = (sin(aura_time * 6.0) + 1.0) * 0.5
	var aura_color = Color(1.0, 0.2, 0.8, 0.15 + pulse * 0.2) if phase == 2 else Color(0.8, 0.6, 1.0, 0.12 + pulse * 0.15)
	draw_circle(Vector2.ZERO, 90.0 + pulse * 15.0, aura_color)
	draw_arc(Vector2.ZERO, 105.0 + pulse * 10.0, 0, TAU, 32, aura_color * 2.0, 3.0)
