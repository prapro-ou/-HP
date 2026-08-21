extends Node2D
## 全画面背景・要塞ボススクリプト (stage1_boss_main.png)
## - 最背面に画面全体を覆う超巨大要塞として配置
## - 画面上端からサブ砲台と一緒に5秒かけて降下出現
## - 砲台はボスの上に被るように配置
## - 4〜5分の骨太なバトル（耐久力・フェーズ再展開）

const TURRET_SCENE: PackedScene = preload("res://game/enemies/boss/boss_turret.tscn")
const PARRY_PARTICLE_SCENE: PackedScene = preload("res://game/bullets/parry_particle.tscn")
const HitSpark = preload("res://game/bullets/hit_spark.gd")

@export var max_hp: int = 7500
var current_hp: int = 7500
var is_alive: bool = true
var is_active: bool = false

var bullet_pool: Node2D
var player: CharacterBody2D
var fire_timer: float = 0.0
var attack_pattern_index: int = 0
var turrets: Array[Node2D] = []
var reinforcement_wave_spawned: bool = false
var turret_respawn_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var core_node: Area2D = $Core
@onready var core_glow: ColorRect = $Core/CoreGlow
@onready var body_area: Area2D = $BodyArea


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	
	current_hp = max_hp
	is_alive = true
	is_active = false
	reinforcement_wave_spawned = false
	turret_respawn_timer = 0.0
	
	bullet_pool = get_node_or_null("/root/Main/BulletPool")
	player = get_node_or_null("/root/Main/Player")
	
	# 初期位置：画面上端の見切れた位置
	var vp_w = get_viewport_rect().size.x
	position = Vector2(vp_w / 2.0, -700.0)


func start_intro_sequence(duration: float = 5.0) -> void:
	is_active = false
	var vp_w = get_viewport_rect().size.x
	var target_boss_pos = Vector2(vp_w / 2.0, 360.0)
	
	# ボスが画面上端から堂々と画面上部へ降下展開 (5秒)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", target_boss_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# サブ砲台を2つランダム生成し、ボスの上に被るよう画面上端から降下配置
	spawn_sub_turrets(duration, false)
	
	tween.chain().tween_callback(func():
		is_active = true
		fire_timer = 1.0
	)


func spawn_sub_turrets(duration: float = 5.0, is_wave2: bool = false) -> void:
	var types = [0, 1, 2]
	types.shuffle()
	
	var selected_types = [types[0], types[1]]
	if is_wave2:
		selected_types = [types[1], types[2]]
		
	# 配置：ボス背景の上に被る位置 (画面中央上部、左右)
	var left_x = randf_range(200.0, 320.0)
	var left_y = randf_range(240.0, 380.0)
	var right_x = randf_range(480.0, 600.0)
	var right_y = randf_range(240.0, 380.0)
	
	var configs = [
		{ "type": selected_types[0], "start": Vector2(left_x, -120.0), "target": Vector2(left_x, left_y) },
		{ "type": selected_types[1], "start": Vector2(right_x, -120.0), "target": Vector2(right_x, right_y) }
	]
	
	for cfg in configs:
		if TURRET_SCENE:
			var turret = TURRET_SCENE.instantiate()
			turret.turret_type = cfg["type"]
			turret.max_hp = 900
			turret.current_hp = 900
			get_parent().add_child(turret)
			turret.spawn_intro(cfg["start"], cfg["target"], duration)
			turrets.append(turret)


var is_enraged: bool = false
var enraged_notified: bool = false
const METEOR_BULLET_SCENE: PackedScene = preload("res://game/bullets/meteor_bullet.tscn")

func _process(delta: float) -> void:
	if not is_alive:
		return
		
	# サブ砲台の生存チェック
	var alive_turrets_count = 0
	for t in turrets:
		if is_instance_valid(t) and t.is_alive:
			alive_turrets_count += 1
			
	is_enraged = (alive_turrets_count == 0)
	
	# コアのパルス演出（砲台全滅後は高速パルスで暴走を表現）
	if is_instance_valid(core_glow):
		var pulse_speed = 120.0 if is_enraged else 300.0
		var pulse = 0.3 + 0.3 * sin(Time.get_ticks_msec() / pulse_speed)
		core_glow.color = Color(1.0, 0.1, 0.1, pulse) if is_enraged else Color(0.9, 0.2, 0.2, pulse)
		
	if not is_active:
		return
		
	# 砲台全滅時の暴走アナウンス
	if is_enraged and not enraged_notified:
		enraged_notified = true
		spawn_shield_message("⚠️ 砲台破壊！要塞コア暴走・攻撃頻度激化！")
		if is_instance_valid(player) and player.has_method("trigger_screen_flash"):
			player.trigger_screen_flash(Color(1.0, 0.2, 0.2, 0.3))
			
	# 増援デッキ展開タイマー
	if alive_turrets_count == 0 and not reinforcement_wave_spawned:
		turret_respawn_timer += delta
		if turret_respawn_timer >= 18.0:
			reinforcement_wave_spawned = true
			enraged_notified = false
			spawn_shield_message("⚠️ 警告: 予備砲台デッキ展開！")
			spawn_sub_turrets(4.0, true)
			
	# プレイヤーの接近感知による全方位迎撃パルス（円形弾）
	process_proximity_counter_attack(delta)
	
	fire_timer += delta
	# 砲台生存中は3.5秒、砲台撃破後は1.5秒に手数が倍増！
	var attack_interval = 1.5 if is_enraged else 3.5
	if fire_timer >= attack_interval:
		fire_timer = 0.0
		execute_fortress_attack()


var close_proximity_timer: float = 0.0
const CLOSE_PROXIMITY_COOLDOWN: float = 3.5
const CLOSE_PROXIMITY_DISTANCE: float = 250.0

func process_proximity_counter_attack(delta: float) -> void:
	if close_proximity_timer > 0.0:
		close_proximity_timer -= delta
		return
		
	if not is_active or not is_alive or not is_instance_valid(player) or not is_instance_valid(bullet_pool):
		return
		
	var core_pos = core_node.global_position if is_instance_valid(core_node) else global_position
	var dist = player.global_position.distance_to(core_pos)
	
	if dist <= CLOSE_PROXIMITY_DISTANCE:
		close_proximity_timer = CLOSE_PROXIMITY_COOLDOWN
		fire_proximity_ring_attack(core_pos)


func fire_proximity_ring_attack(center_pos: Vector2) -> void:
	# コアの白熱警告フラッシュ
	if is_instance_valid(core_glow):
		core_glow.color = Color(3.0, 3.0, 1.0, 1.0)
		var t = create_tween()
		t.tween_property(core_glow, "color", Color(1.0, 0.2, 0.2, 0.6), 0.25)
		
	Global.play_laser(randf_range(1.1, 1.3))
	spawn_shield_message("⚠️ 接近感知！全方位迎撃パルス起動！")
	
	var mult = get_stage_difficulty_mult()
	var bullet_count = 16
	for i in range(bullet_count):
		var angle = i * (TAU / float(bullet_count))
		var dir = Vector2.RIGHT.rotated(angle)
		var bullet = bullet_pool.get_bullet("wave")
		if bullet:
			bullet.global_position = center_pos
			bullet.damage = int(8 * mult)
			bullet.set_direction(dir, 280.0)


func get_stage_difficulty_mult() -> float:
	var stage_num = 1
	var main = get_node_or_null("/root/Main")
	if main:
		var gm = main.get_node_or_null("GameManager")
		if gm and "current_stage_num" in gm:
			stage_num = gm.current_stage_num
	return Global.get_stage_difficulty_multiplier(stage_num)


func execute_fortress_attack() -> void:
	if not is_instance_valid(bullet_pool):
		return
		
	var mult = get_stage_difficulty_mult()
	var vp_w = get_viewport_rect().size.x
	var num_patterns = 5 if is_enraged else 3
	attack_pattern_index = (attack_pattern_index + 1) % num_patterns
	
	match attack_pattern_index:
		0:
			# パターン1: 画面上端からの広域扇状フォトン弾幕
			var drop_count = 4 if is_enraged else 3
			var step_w = vp_w / float(drop_count + 1)
			for i in range(drop_count):
				var drop_x = step_w * (i + 1)
				var center_dir = Vector2.DOWN
				if is_instance_valid(player):
					center_dir = (player.global_position - Vector2(drop_x, 20.0)).normalized()
					
				var angles = [-24.0, -12.0, 0.0, 12.0, 24.0]
				for angle_deg in angles:
					var bullet = bullet_pool.get_bullet("laser")
					if bullet:
						bullet.global_position = Vector2(drop_x, 15.0)
						bullet.damage = int(10 * mult)
						var dir = center_dir.rotated(deg_to_rad(angle_deg))
						bullet.set_direction(dir, 320.0)
		1:
			# パターン2: 画面上端からのクラスター追尾ミサイル雨
			var missile_waves = 4 if is_enraged else 2
			for wave in range(missile_waves):
				get_tree().create_timer(wave * 0.22).timeout.connect(func():
					if is_instance_valid(self) and is_alive and is_instance_valid(bullet_pool):
						var spawn_x = randf_range(100.0, vp_w - 100.0)
						var bullet = bullet_pool.get_bullet("missile")
						if bullet:
							bullet.global_position = Vector2(spawn_x, 15.0)
							bullet.damage = int(10 * mult)
							var target_dir = Vector2.DOWN
							if is_instance_valid(player):
								target_dir = (player.global_position - bullet.global_position).normalized()
							bullet.set_direction(target_dir, 260.0)
				)
		2:
			# パターン3: 【パリィ不可】真紅の要塞主砲・断絶ヴォイドレーザー斉射
			execute_unparryable_cannon_attack()
			
		3:
			# パターン4 (暴走時): コア直撃チャージボルト＋左右サイクロン弾
			if is_instance_valid(core_node):
				var core_pos = core_node.global_position
				for c_i in range(2):
					get_tree().create_timer(c_i * 0.15).timeout.connect(func():
						if is_instance_valid(self) and is_alive and is_instance_valid(bullet_pool):
							var bullet = bullet_pool.get_bullet("charge")
							if bullet:
								bullet.global_position = core_pos + Vector2(0.0, 30.0)
								bullet.damage = int(16 * mult)
								var dir = Vector2.DOWN
								if is_instance_valid(player):
									dir = (player.global_position - bullet.global_position).normalized()
								bullet.set_direction(dir, 450.0)
					)
				# 左右サイクロン弾
				for side in [-1.0, 1.0]:
					var c_bullet = bullet_pool.get_bullet("irregular")
					if c_bullet:
						c_bullet.global_position = core_pos + Vector2(side * 80.0, 20.0)
						c_bullet.damage = int(8 * mult)
						c_bullet.set_direction(Vector2(side * 0.6, 1.0).normalized(), 300.0)
		4:
			# パターン5 (暴走時): 要塞緊急防衛ギガメテオ投下
			if METEOR_BULLET_SCENE:
				for m_i in range(2):
					get_tree().create_timer(m_i * 0.25).timeout.connect(func():
						if is_instance_valid(self) and is_alive:
							var meteor = METEOR_BULLET_SCENE.instantiate()
							meteor.global_position = Vector2(vp_w * (0.3 if m_i == 0 else 0.7), 20.0)
							var shoot_dir = Vector2.DOWN.rotated(randf_range(-0.4, 0.4))
							if is_instance_valid(player):
								shoot_dir = (player.global_position - meteor.global_position).normalized()
							meteor.damage = int(25 * mult)
							meteor.set_direction(shoot_dir, 300.0)
							get_parent().add_child(meteor)
					)


func execute_unparryable_cannon_attack() -> void:
	# 1. 画面上部をやんわり赤く点灯させる警告演出
	var main = get_node_or_null("/root/Main")
	if main:
		var ui_node = main.get_node_or_null("UI")
		if ui_node and ui_node.has_method("show_top_unparryable_warning"):
			ui_node.show_top_unparryable_warning(1.8, "⚠️ DANGER: パリィ不可・断絶真紅レーザー警告！ ⚠️")
			
	# コアが濃赤に激しく明滅
	if is_instance_valid(core_glow):
		core_glow.color = Color(1.0, 0.05, 0.05, 0.95)
		
	# 1.6秒のチャージ予兆後に真紅の断絶レーザーを射出
	var mult = get_stage_difficulty_mult()
	get_tree().create_timer(1.6).timeout.connect(func():
		if is_instance_valid(self) and is_alive and is_instance_valid(bullet_pool):
			var vp_w = get_viewport_rect().size.x
			var core_pos = core_node.global_position if is_instance_valid(core_node) else Vector2(vp_w / 2.0, 250.0)
			
			var angles = [-24.0, -12.0, 0.0, 12.0, 24.0] if is_enraged else [-18.0, 0.0, 18.0]
			for a_deg in angles:
				var bullet = bullet_pool.get_bullet("unparryable_laser")
				if bullet:
					bullet.is_unparryable = true
					bullet.damage = int(22 * mult)
					bullet.global_position = core_pos + Vector2(a_deg * 2.5, 30.0)
					var center_dir = Vector2.DOWN
					if is_instance_valid(player):
						center_dir = (player.global_position - bullet.global_position).normalized()
					var dir = center_dir.rotated(deg_to_rad(a_deg * 0.6))
					bullet.set_direction(dir, 460.0)
	)


func take_damage_on_part(part_name: String, amount: int, hit_pos: Vector2 = Vector2.ZERO, is_critical: bool = false) -> void:
	if not is_alive:
		return
		
	var actual_hit_pos = hit_pos
	if actual_hit_pos == Vector2.ZERO:
		actual_hit_pos = core_node.global_position if (is_instance_valid(core_node) and part_name == "core") else global_position
		
	var has_alive_turrets = false
	for t in turrets:
		if is_instance_valid(t) and t.is_alive:
			has_alive_turrets = true
			break
			
	var final_dmg = amount
	if has_alive_turrets:
		# 砲台生存中はバリアでダメージ80%カット
		final_dmg = max(1, int(amount * 0.2))
		if randf() < 0.2:
			spawn_shield_message("⚠️ サブ砲台が防壁を展開中！")
			
		# 防壁ヒット演出 (金属弾きSE & シールドスパーク & 青白フラッシュ)
		Global.play_guard(randf_range(0.95, 1.05))
		HitSpark.create_spark(get_parent(), actual_hit_pos, "shield")
		
		if is_instance_valid(sprite):
			sprite.modulate = Color(0.8, 1.5, 2.5, 1.0)
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(0.95, 0.98, 1.0, 1.0), 0.08)
	else:
		# 砲台破壊後: 弱点コア直撃 (重被弾SE & ヘビースパーク & 白熱フラッシュ & 被弾シェイク)
		Global.play_heavy_hit(randf_range(0.95, 1.08))
		HitSpark.create_spark(get_parent(), actual_hit_pos, "heavy" if (part_name == "core" or is_critical) else "normal")
		
		if is_instance_valid(core_glow):
			core_glow.color = Color(3.0, 1.8, 1.8, 0.95)
			var c_tween = create_tween()
			c_tween.tween_property(core_glow, "color", Color(1.0, 0.1, 0.1, 0.6), 0.08)
			
		if is_instance_valid(sprite):
			sprite.modulate = Color(2.4, 1.6, 1.6, 1.0)
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(0.95, 0.98, 1.0, 1.0), 0.08)
			
			# 被弾微小シェイク
			sprite.position = Vector2(randf_range(-3.5, 3.5), randf_range(-2.0, 2.0))
			var shake_t = create_tween()
			shake_t.tween_property(sprite, "position", Vector2.ZERO, 0.05)
			
	current_hp -= final_dmg
	
	var main = get_node_or_null("/root/Main")
	if main:
		var ui_node = main.get_node_or_null("UI")
		if ui_node and ui_node.has_method("spawn_damage_popup"):
			ui_node.spawn_damage_popup(actual_hit_pos, final_dmg, not has_alive_turrets, is_critical)
			
		var mgr = main.get_node_or_null("GameManager")
		if mgr and mgr.has_method("add_damage_score"):
			mgr.add_damage_score(final_dmg)
			
	if current_hp <= 0:
		current_hp = 0
		destroy_boss()


func spawn_shield_message(text: String) -> void:
	var label = Label.new()
	label.text = text
	var label_set = LabelSettings.new()
	var pixel_font = preload("res://game/assets/fonts/DotGothic16-Regular.ttf")
	if pixel_font:
		label_set.font = pixel_font
	label_set.font_size = 20
	label_set.font_color = Color(1.0, 0.3, 0.3)
	label_set.outline_size = 4
	label_set.outline_color = Color.BLACK
	label.label_settings = label_set
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.global_position = Vector2(get_viewport_rect().size.x / 2.0 - 200, 180)
	label.custom_minimum_size = Vector2(400, 30)
	get_parent().add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "global_position:y", label.global_position.y - 30.0, 1.4)
	tween.tween_property(label, "modulate:a", 0.0, 1.4)
	tween.chain().tween_callback(label.queue_free)


func destroy_boss() -> void:
	is_alive = false
	is_active = false
	
	Global.play_explosion(0.85)
	
	# ボス撃破ボーナス: +10 TP
	Global.tech_points += 10
	var player_node = get_node_or_null("/root/Main/Player")
	if player_node and player_node.has_method("spawn_popup_message"):
		player_node.spawn_popup_message("🏆 要塞ボス完全撃破！ +10 TP 獲得！")
		
	for t in turrets:
		if is_instance_valid(t) and t.is_alive:
			t.destroy_turret()
			
	var main_tree = get_tree()
	if PARRY_PARTICLE_SCENE and main_tree:
		for i in range(25):
			main_tree.create_timer(i * 0.1).timeout.connect(func():
				if is_instance_valid(self):
					var p = PARRY_PARTICLE_SCENE.instantiate()
					p.global_position = global_position + Vector2(randf_range(-400, 400), randf_range(-300, 300))
					p.scale = Vector2(4.0, 4.0)
					p.modulate = Color(1.0, randf_range(0.2, 0.9), 0.1)
					get_parent().add_child(p)
			)
			
	main_tree.create_timer(2.6).timeout.connect(func():
		var main = get_node_or_null("/root/Main")
		if main:
			var mgr = main.get_node_or_null("GameManager")
			if mgr and mgr.has_method("on_boss_destroyed"):
				mgr.on_boss_destroyed()
		queue_free()
	)


func get_current_hp() -> int:
	return current_hp
