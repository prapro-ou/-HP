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
var is_break_vulnerable: bool = false
var break_vulnerable_timer: float = 0.0
const BREAK_VULNERABLE_DURATION: float = 14.0 # 全砲台撃破時の弱点コア露出時間（14秒）
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
	
	# コアのパルス演出（弱点露出中は黄金高速パルス、暴走時は真紅パルス）
	if is_instance_valid(core_glow):
		if is_break_vulnerable:
			var pulse_speed = 80.0
			var pulse = 0.4 + 0.6 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / pulse_speed))
			core_glow.color = Color(1.0, 0.85, 0.15, pulse)
		else:
			var pulse_speed = 120.0 if is_enraged else 300.0
			var pulse = 0.3 + 0.3 * sin(Time.get_ticks_msec() / pulse_speed)
			core_glow.color = Color(1.0, 0.1, 0.1, pulse) if is_enraged else Color(0.9, 0.2, 0.2, pulse)
		
	if not is_active:
		return
		
	# 弱点コア露出（BREAK）状態のタイマー進行
	if is_break_vulnerable:
		break_vulnerable_timer -= delta
		if break_vulnerable_timer <= 3.0 and break_vulnerable_timer + delta > 3.0:
			spawn_shield_message("防壁再起動まで あと 3秒...", Color(1.0, 0.4, 0.2), 1.5)
		if break_vulnerable_timer <= 0.0:
			is_break_vulnerable = false
			break_vulnerable_timer = 0.0
			spawn_shield_message("防壁システム再起動！予備砲台デッキ展開！", Color(0.2, 0.8, 1.0), 2.5)
			spawn_sub_turrets(4.0, true)
	elif alive_turrets_count == 0 and not reinforcement_wave_spawned:
		# 弱点露出終了後、予備砲台デッキ展開タイマー
		turret_respawn_timer += delta
		if turret_respawn_timer >= 4.0:
			reinforcement_wave_spawned = true
			enraged_notified = false
			spawn_shield_message("警告: 予備砲台デッキ展開！", Color(0.2, 0.8, 1.0), 2.5)
			spawn_sub_turrets(4.0, true)
			
	# プレイヤーの接近感知による全方位迎撃パルス（円形弾）
	process_proximity_counter_attack(delta)
	
	fire_timer += delta
	# 弱点露出中はボスが隙を見せるため攻撃頻度が少し緩和、砲台撃破後は手数が倍増
	var attack_interval = 1.6 if is_break_vulnerable else (1.0 if is_enraged else 2.4)
	if fire_timer >= attack_interval:
		fire_timer = 0.0
		execute_fortress_attack()


func on_turret_destroyed(destroyed_turret: Node2D) -> void:
	# 残存砲台数のチェック
	var remaining = 0
	for t in turrets:
		if is_instance_valid(t) and t != destroyed_turret and t.is_alive:
			remaining += 1
			
	if remaining == 0:
		trigger_full_break_state()
	else:
		trigger_partial_break_state(remaining)


func trigger_full_break_state() -> void:
	is_break_vulnerable = true
	break_vulnerable_timer = BREAK_VULNERABLE_DURATION
	turret_respawn_timer = 0.0
	
	# ボス白熱スタン演出 ＆ 画面フラッシュ
	Global.play_heavy_hit(0.6)
	if is_instance_valid(player) and player.has_method("trigger_screen_flash"):
		player.trigger_screen_flash(Color(1.0, 0.9, 0.2, 0.45))
		
	# アナウンス
	spawn_shield_message("【BREAK!!】防壁完全崩壊！弱点コア露出中 (被ダメージ 200% !)", Color(1.0, 0.88, 0.1), 3.0)
	
	# コアの激発光（ゴールド＆白熱オレンジ）
	if is_instance_valid(core_glow):
		core_glow.color = Color(3.5, 3.0, 0.8, 1.0)
		var t = create_tween()
		t.tween_property(core_glow, "color", Color(1.0, 0.85, 0.15, 0.85), 0.4)
		
	if is_instance_valid(sprite):
		sprite.modulate = Color(2.5, 2.3, 1.4, 1.0)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0.95, 0.98, 1.0, 1.0), 0.3)


func trigger_partial_break_state(remaining: int) -> void:
	spawn_shield_message("サブ砲台破壊！要塞装甲に亀裂発生！(残 %d基)" % remaining, Color(0.4, 0.9, 1.0), 2.0)


var close_proximity_timer: float = 0.0
const CLOSE_PROXIMITY_COOLDOWN: float = 2.5
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
	spawn_shield_message("接近感知！全方位迎撃パルス起動！")
	
	var mult = get_stage_difficulty_mult()
	var bullet_count = 16
	for i in range(bullet_count):
		var angle = i * (TAU / float(bullet_count))
		var dir = Vector2.RIGHT.rotated(angle)
		var bullet = bullet_pool.get_bullet("wave")
		if bullet:
			bullet.global_position = center_pos
			bullet.damage = int(16 * mult)
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
						bullet.damage = int(20 * mult)
						var dir = center_dir.rotated(deg_to_rad(angle_deg))
						bullet.set_direction(dir, 320.0)
		1:
			# パターン2: 画面上端からのクラスター追尾ミサイル雨
			var missile_waves = 4 if is_enraged else 2
			for wave in range(missile_waves):
				get_tree().create_timer(wave * 0.18).timeout.connect(func():
					if is_instance_valid(self) and is_alive and is_instance_valid(bullet_pool):
						var spawn_x = randf_range(100.0, vp_w - 100.0)
						var bullet = bullet_pool.get_bullet("missile")
						if bullet:
							bullet.global_position = Vector2(spawn_x, 15.0)
							bullet.damage = int(20 * mult)
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
				for c_i in range(3):
					get_tree().create_timer(c_i * 0.15).timeout.connect(func():
						if is_instance_valid(self) and is_alive and is_instance_valid(bullet_pool):
							var bullet = bullet_pool.get_bullet("charge")
							if bullet:
								bullet.global_position = core_pos + Vector2(0.0, 30.0)
								bullet.damage = int(24 * mult)
								var dir = Vector2.DOWN
								if is_instance_valid(player):
									dir = (player.global_position - core_pos).normalized()
								bullet.set_direction(dir, 380.0)
					)
			# 左右旋回サイクロン弾
			for angle_deg in [-45.0, -25.0, -5.0, 5.0, 25.0, 45.0]:
				var bullet = bullet_pool.get_bullet("wave")
				if bullet:
					bullet.global_position = Vector2(vp_w / 2.0, 200.0)
					bullet.damage = int(18 * mult)
					var dir = Vector2.DOWN.rotated(deg_to_rad(angle_deg))
					bullet.set_direction(dir, 240.0)
		4:
			# パターン5 (暴走時): 超広角扇状フォトン乱射
			var drop_x = vp_w / 2.0
			for angle_deg in range(-60, 65, 12):
				var bullet = bullet_pool.get_bullet("laser")
				if bullet:
					bullet.global_position = Vector2(drop_x, 100.0)
					bullet.damage = int(18 * mult)
					var dir = Vector2.DOWN.rotated(deg_to_rad(angle_deg))
					bullet.set_direction(dir, 300.0)


func execute_unparryable_cannon_attack() -> void:
	var main = get_node_or_null("/root/Main")
	var ui_node = main.get_node_or_null("UI") if main else null
	if ui_node and ui_node.has_method("show_top_unparryable_warning"):
		ui_node.show_top_unparryable_warning(2.2, "DANGER: 要塞主砲断絶レーザー斉射！\n【UNPARRYABLE VOID BEAM - EVADE!】")
		
	# アナウンス
	spawn_shield_message("【WARNING】主砲断絶ヴォイドレーザー充填！")
	
	# コアと全身の真紅チャージ発光
	if is_instance_valid(core_glow):
		core_glow.color = Color(3.5, 0.2, 0.2, 1.0)
		var ct = create_tween()
		ct.tween_property(core_glow, "color", Color(1.0, 0.1, 0.1, 0.8), 1.8)
		
	if is_instance_valid(sprite):
		sprite.modulate = Color(2.5, 0.5, 0.5, 1.0)
		var st = create_tween()
		st.tween_property(sprite, "modulate", Color.WHITE, 1.8)
		
	# 1.5秒のチャージ予告後、画面を覆う3本の極太ヴォイドレーザー弾幕
	get_tree().create_timer(1.5).timeout.connect(func():
		if not is_instance_valid(self) or not is_alive or not is_instance_valid(bullet_pool):
			return
			
		var mult = get_stage_difficulty_mult()
		var vp_w = get_viewport_rect().size.x
		Global.play_laser(0.7)
		
		# 3箇所の砲門から射出 (左、中央、右)
		var cannon_x_positions = [vp_w * 0.25, vp_w * 0.5, vp_w * 0.75]
		for c_x in cannon_x_positions:
			for i in range(10): # 10発連続高速直進
				get_tree().create_timer(i * 0.05).timeout.connect(func():
					if is_instance_valid(self) and is_alive and is_instance_valid(bullet_pool):
						var bullet = bullet_pool.get_bullet("unparryable_laser")
						if bullet:
							bullet.global_position = Vector2(c_x + randf_range(-8, 8), 180.0)
							bullet.damage = int(32 * mult)
							bullet.set_direction(Vector2.DOWN, 520.0)
				)
				
		# プレイヤー狙い撃ちの拡散牽制弾
		for a_deg in [-20.0, 0.0, 20.0]:
			var bullet = bullet_pool.get_bullet("charge")
			if bullet:
				bullet.global_position = Vector2(vp_w * 0.5, 180.0)
				bullet.damage = int(22 * mult)
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
	var is_break_hit = false
	
	if has_alive_turrets:
		# 砲台生存中はバリアでダメージ80%カット (0.2倍)
		final_dmg = max(1, int(amount * 0.2))
		if randf() < 0.2:
			spawn_shield_message("サブ砲台が防壁を展開中！(砲台を破壊せよ！)")
			
		# 防壁ヒット演出 (金属弾きSE & シールドスパーク & 青白フラッシュ)
		Global.play_guard(randf_range(0.95, 1.05))
		HitSpark.create_spark(get_parent(), actual_hit_pos, "shield")
		
		if is_instance_valid(sprite):
			sprite.modulate = Color(0.8, 1.5, 2.5, 1.0)
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(0.95, 0.98, 1.0, 1.0), 0.08)
	elif is_break_vulnerable:
		# 【BREAK中】弱点コア露出: ダメージ 2.0倍 (200%)！
		final_dmg = int(amount * 2.0)
		is_break_hit = true
		
		# クリティカル・ヘビーヒット音 & 黄金スパーク
		Global.play_heavy_hit(randf_range(1.05, 1.25))
		HitSpark.create_spark(get_parent(), actual_hit_pos, "heavy", Color(1.0, 0.9, 0.2))
		
		if is_instance_valid(core_glow):
			core_glow.color = Color(3.5, 3.0, 1.0, 1.0)
			var c_tween = create_tween()
			c_tween.tween_property(core_glow, "color", Color(1.0, 0.85, 0.2, 0.8), 0.08)
			
		if is_instance_valid(sprite):
			sprite.modulate = Color(2.5, 2.3, 1.5, 1.0)
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(0.95, 0.98, 1.0, 1.0), 0.08)
			
			# 被弾シェイク
			sprite.position = Vector2(randf_range(-5.0, 5.0), randf_range(-3.0, 3.0))
			var shake_t = create_tween()
			shake_t.tween_property(sprite, "position", Vector2.ZERO, 0.05)
	else:
		# 通常時 (砲台全滅・露出終了後など): 等倍 (1.0倍)
		final_dmg = amount
		Global.play_heavy_hit(randf_range(0.95, 1.08))
		HitSpark.create_spark(get_parent(), actual_hit_pos, "heavy" if (part_name == "core" or is_critical) else "normal")
		
		if is_instance_valid(core_glow):
			core_glow.color = Color(3.0, 1.8, 1.8, 0.95)
			
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
			ui_node.spawn_damage_popup(actual_hit_pos, final_dmg, not has_alive_turrets, is_critical or is_break_hit)
			
		var mgr = main.get_node_or_null("GameManager")
		if mgr and mgr.has_method("add_damage_score"):
			mgr.add_damage_score(final_dmg)
			
	if current_hp <= 0:
		current_hp = 0
		call_deferred("destroy_boss")


func spawn_shield_message(text: String, text_color: Color = Color(1.0, 0.3, 0.3), duration: float = 1.4) -> void:
	var label = Label.new()
	label.text = text
	var label_set = LabelSettings.new()
	var pixel_font = preload("res://game/assets/fonts/DotGothic16-Regular.ttf")
	if pixel_font:
		label_set.font = pixel_font
	label_set.font_size = 20
	label_set.font_color = text_color
	label_set.outline_size = 4
	label_set.outline_color = Color.BLACK
	label.label_settings = label_set
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.global_position = Vector2(get_viewport_rect().size.x / 2.0 - 250, 180)
	label.custom_minimum_size = Vector2(500, 30)
	get_parent().add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "global_position:y", label.global_position.y - 30.0, duration)
	tween.tween_property(label, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(label.queue_free)


const DATA_ORB_SCENE: PackedScene = preload("res://game/core/data_orb.tscn")
const EXPLOSION_EFFECT_SCENE: GDScript = preload("res://game/bullets/explosion_effect.gd")

func destroy_boss() -> void:
	if not is_alive:
		return
	is_alive = false
	is_active = false
	
	var main_tree = get_tree()
	var player_node = get_node_or_null("/root/Main/Player")
	var main_node = get_node_or_null("/root/Main")
	
	# プレイヤーの操作を即時ロック（移動・射撃・ガード無効化＆無敵化）
	if is_instance_valid(player_node) and player_node.has_method("lock_controls"):
		player_node.lock_controls()
	
	# 1. 撃破インパクト音 ＆ 画面フラッシュ ＆ 撃破テロップ
	Global.play_heavy_hit(0.7)
	if is_instance_valid(player_node) and player_node.has_method("trigger_screen_flash"):
		player_node.trigger_screen_flash(Color(1.0, 0.95, 0.5, 0.7))
		
	# 2. 画面上の全敵弾をデータオーブに変換 ＆ プレイヤーへ磁力吸引
	call_deferred("convert_all_bullets_to_data_orbs", player_node)
	
	# ボス撃破ボーナス: +10 TP
	Global.tech_points += 10
	if player_node and player_node.has_method("spawn_popup_message"):
		player_node.spawn_popup_message("[MISSION COMPLETE] 要塞ボス撃破！ +10 TP 獲得")
		
	# サブ砲台の破壊
	for t in turrets:
		if is_instance_valid(t) and t.is_alive:
			t.destroy_turret()
			
	# 3. ボス各部の28連続重誘爆（外郭から徐々に内側コアへ迫る大連鎖爆発）
	var explosion_offsets = [
		Vector2(-320, -90), Vector2(320, -90), Vector2(-260, 60), Vector2(260, 60),
		Vector2(-180, -130), Vector2(180, -130), Vector2(-360, 10), Vector2(360, 10),
		Vector2(-120, -70), Vector2(120, -70), Vector2(-200, 90), Vector2(200, 90),
		Vector2(-80, 20), Vector2(80, 20), Vector2(-290, -40), Vector2(290, -40),
		Vector2(-140, 110), Vector2(140, 110), Vector2(-60, -110), Vector2(60, -110),
		Vector2(-220, -10), Vector2(220, -10), Vector2(-100, 40), Vector2(100, 40),
		Vector2(-40, -40), Vector2(40, -40), Vector2(0, 60), Vector2(0, -20)
	]
	
	for i in range(explosion_offsets.size()):
		main_tree.create_timer(i * 0.095).timeout.connect(func():
			if is_instance_valid(self):
				var exp_pos = global_position + explosion_offsets[i]
				var progress = float(i) / float(explosion_offsets.size()) # 0.0 -> 1.0
				var exp_rad = randf_range(55.0 + progress * 40.0, 95.0 + progress * 60.0)
				var exp_col = Color(1.0, randf_range(0.3, 0.9), 0.1) if progress < 0.7 else Color(1.0, randf_range(0.7, 1.0), 0.5)
				ExplosionEffect.create(get_parent(), exp_pos, exp_rad, exp_col, 0.38)
				Global.play_explosion(randf_range(1.0, 1.35) - progress * 0.2)
				
				# 被弾激震シェイク
				if is_instance_valid(sprite):
					var shake_amp = 6.0 + progress * 8.0
					sprite.position = Vector2(randf_range(-shake_amp, shake_amp), randf_range(-shake_amp * 0.7, shake_amp * 0.7))
		)
		
	# 4. ボス本体の白熱明滅 ＆ スムーズなフェードアウト（2.8秒）
	if is_instance_valid(sprite):
		var fade_tween = create_tween().set_parallel(true)
		fade_tween.tween_property(sprite, "modulate:a", 0.0, 2.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fade_tween.tween_property(sprite, "position", Vector2(0.0, 50.0), 2.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	if is_instance_valid(core_glow):
		var core_tween = create_tween()
		core_tween.tween_property(core_glow, "modulate:a", 0.0, 2.5)
		
	# 5. フィニッシュ超巨大白熱大爆散 ＆ フライバイ発動 (2.8秒後)
	main_tree.create_timer(2.8).timeout.connect(func():
		if is_instance_valid(self):
			# 超巨大超新星大爆散（半径 440px）
			ExplosionEffect.create(get_parent(), global_position, 440.0, Color.WHITE, 0.8)
			ExplosionEffect.create(get_parent(), global_position + Vector2(-180, 0), 280.0, Color(0.4, 0.9, 1.0), 0.7)
			ExplosionEffect.create(get_parent(), global_position + Vector2(180, 0), 280.0, Color(1.0, 0.6, 0.1), 0.7)
			
			Global.play_explosion(0.6) # 重低音特大爆発
			
			if is_instance_valid(player_node) and player_node.has_method("trigger_screen_flash"):
				player_node.trigger_screen_flash(Color(1.0, 1.0, 1.0, 1.0))
	)
	
	# 6. 自機の勝利フライバイ演出開始 (3.2秒後)
	main_tree.create_timer(3.2).timeout.connect(func():
		if is_instance_valid(player_node) and player_node.has_method("play_victory_flyby"):
			player_node.play_victory_flyby()
	)
	
	# 7. 自機が上空の彼方へ突き抜けた後、作戦完了リザルトへ移行 (5.2秒後)
	main_tree.create_timer(5.2).timeout.connect(func():
		if is_instance_valid(main_node):
			var mgr = main_node.get_node_or_null("GameManager")
			if mgr and mgr.has_method("on_boss_destroyed"):
				mgr.on_boss_destroyed()
		queue_free()
	)


func convert_all_bullets_to_data_orbs(player_node: CharacterBody2D) -> void:
	if not DATA_ORB_SCENE:
		return
		
	var parent_node = get_parent()
	if not parent_node:
		return
		
	var all_bullets = []
	var pool = get_node_or_null("/root/Main/BulletPool")
	if pool and "active_bullets" in pool:
		all_bullets.append_array(pool.active_bullets.duplicate())
		
	for p in get_tree().get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(p) and not all_bullets.has(p):
			all_bullets.append(p)
			
	for b in all_bullets:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			var b_pos = b.global_position
			var b_type = b.bullet_type if "bullet_type" in b else "straight"
			
			# 弾を消去
			if pool and pool.has_method("return_bullet") and pool.active_bullets.has(b):
				pool.return_bullet(b)
			else:
				b.queue_free()
				
			# データオーブを生成して自機へ吸引（物理クエリ外で安全に追加）
			var orb = DATA_ORB_SCENE.instantiate()
			orb.setup_orb(b_type, b_pos, player_node)
			parent_node.call_deferred("add_child", orb)


func get_current_hp() -> int:
	return current_hp

