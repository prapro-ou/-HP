extends Node2D
## 巨大要塞ボススクリプト (5.png)
## - 画面最下部を埋め尽くすように配置
## - 警告演出とともに5秒かけて2つのサブ砲台を伴って登場
## - 画面上端から3〜4秒間隔で拡散弾や追尾弾を投下
## - パリィ反射弾の8割が砲台、2割がボス本体へ飛翔

const TURRET_SCENE: PackedScene = preload("res://game/enemies/boss/boss_turret.tscn")
const PARRY_PARTICLE_SCENE: PackedScene = preload("res://game/bullets/parry_particle.tscn")

@export var max_hp: int = 5000
var current_hp: int = 5000
var is_alive: bool = true
var is_active: bool = false
var intro_timer: float = 0.0

var bullet_pool: Node2D
var player: CharacterBody2D
var fire_timer: float = 0.0
var attack_pattern_index: int = 0
var turrets: Array[Node2D] = []

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
	
	bullet_pool = get_node_or_null("/root/Main/BulletPool")
	player = get_node_or_null("/root/Main/Player")
	
	# 初期位置：画面下の見切れた位置
	var vp_w = get_viewport_rect().size.x
	position = Vector2(vp_w / 2.0, 1320.0)


func start_intro_sequence(duration: float = 5.0) -> void:
	is_active = false
	var vp_w = get_viewport_rect().size.x
	var target_boss_pos = Vector2(vp_w / 2.0, 1080.0)
	
	# ボスせり上がり (5秒)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", target_boss_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# サブ砲台を2つランダム生成 (3種の中から2種を選択)
	spawn_sub_turrets(duration)
	
	tween.chain().tween_callback(func():
		is_active = true
		fire_timer = 1.0 # 登場後1秒で初回攻撃
	)


func spawn_sub_turrets(duration: float = 5.0) -> void:
	# 3種類 (0: BEAM, 1: MISSILE, 2: METEOR) から重複なしで2種選定
	var types = [0, 1, 2]
	types.shuffle()
	var selected_types = [types[0], types[1]]
	
	# 配置：画面中央より上、左右に分散 (最低200px離す)
	var left_x = randf_range(160.0, 320.0)
	var left_y = randf_range(180.0, 360.0)
	var right_x = randf_range(480.0, 640.0)
	var right_y = randf_range(180.0, 360.0)
	
	var configs = [
		{ "type": selected_types[0], "start": Vector2(left_x, -100.0), "target": Vector2(left_x, left_y) },
		{ "type": selected_types[1], "start": Vector2(right_x, -100.0), "target": Vector2(right_x, right_y) }
	]
	
	for cfg in configs:
		if TURRET_SCENE:
			var turret = TURRET_SCENE.instantiate()
			turret.turret_type = cfg["type"]
			get_parent().add_child(turret)
			turret.spawn_intro(cfg["start"], cfg["target"], duration)
			turrets.append(turret)


func _process(delta: float) -> void:
	if not is_alive:
		return
		
	# コアの鼓動パルス演出
	if is_instance_valid(core_glow):
		var pulse = 0.3 + 0.25 * sin(Time.get_ticks_msec() / 250.0)
		core_glow.color = Color(1.0, 0.2, 0.2, pulse)
		
	if not is_active:
		return
		
	fire_timer += delta
	# 3〜4秒間隔で画面上端から攻撃
	if fire_timer >= 3.5:
		fire_timer = 0.0
		execute_orbital_attack()


func execute_orbital_attack() -> void:
	if not is_instance_valid(bullet_pool):
		return
		
	attack_pattern_index = (attack_pattern_index + 1) % 2
	var vp_w = get_viewport_rect().size.x
	
	if attack_pattern_index == 0:
		# パターン1: 画面上端からの広域扇状拡散弾（レイン弾幕）
		var drop_x_positions = [vp_w * 0.25, vp_w * 0.5, vp_w * 0.75]
		for drop_x in drop_x_positions:
			var center_dir = Vector2.DOWN
			if is_instance_valid(player):
				center_dir = (player.global_position - Vector2(drop_x, 20.0)).normalized()
				
			var angles = [-30.0, -15.0, 0.0, 15.0, 30.0]
			for angle_deg in angles:
				var bullet = bullet_pool.get_bullet("boss_laser")
				if bullet:
					bullet.global_position = Vector2(drop_x, 15.0)
					bullet.damage = 12
					var dir = center_dir.rotated(deg_to_rad(angle_deg))
					bullet.set_direction(dir, 320.0)
	else:
		# パターン2: 画面上端からのクラスター追尾弾（3連波）
		for wave in range(3):
			get_tree().create_timer(wave * 0.25).timeout.connect(func():
				if is_instance_valid(self) and is_alive and is_instance_valid(bullet_pool):
					var spawn_x = randf_range(100.0, vp_w - 100.0)
					var bullet = bullet_pool.get_bullet("boss_missile")
					if bullet:
						bullet.global_position = Vector2(spawn_x, 15.0)
						bullet.damage = 14
						var target_dir = Vector2.DOWN
						if is_instance_valid(player):
							target_dir = (player.global_position - bullet.global_position).normalized()
						bullet.set_direction(target_dir, 260.0)
			)


func take_damage_on_part(part_name: String, amount: int) -> void:
	if not is_alive:
		return
		
	# サブ砲台の生存確認
	var has_alive_turrets = false
	for t in turrets:
		if is_instance_valid(t) and t.is_alive:
			has_alive_turrets = true
			break
			
	var final_dmg = amount
	if has_alive_turrets:
		# 砲台生存中はバリアでダメージ80%カット
		final_dmg = max(1, int(amount * 0.2))
		if randf() < 0.3:
			spawn_shield_message("⚠️ サブ砲台が防壁を展開中！")
			
	current_hp -= final_dmg
	
	# 被弾演出
	if is_instance_valid(sprite):
		sprite.modulate = Color(1.0, 0.5, 0.5)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		
	var main = get_node_or_null("/root/Main")
	if main:
		var ui_node = main.get_node_or_null("UI")
		if ui_node and ui_node.has_method("spawn_damage_popup"):
			var pop_pos = core_node.global_position if is_instance_valid(core_node) else global_position
			ui_node.spawn_damage_popup(pop_pos, final_dmg, not has_alive_turrets)
			
		var mgr = main.get_node_or_null("GameManager")
		if mgr and mgr.has_method("add_damage_score"):
			mgr.add_damage_score(final_dmg)
			
	if current_hp <= 0:
		current_hp = 0
		destroy_boss()


func spawn_shield_message(text: String) -> void:
	var label = Label.new()
	label.text = text
	var set = LabelSettings.new()
	set.font_size = 20
	set.font_color = Color(1.0, 0.3, 0.3)
	set.outline_size = 6
	set.outline_color = Color.BLACK
	label.label_settings = set
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.global_position = global_position + Vector2(-200, -180)
	label.custom_minimum_size = Vector2(400, 30)
	get_parent().add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "global_position:y", label.global_position.y - 40.0, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.chain().tween_callback(label.queue_free)


func destroy_boss() -> void:
	is_alive = false
	is_active = false
	
	# サブ砲台も一斉爆散
	for t in turrets:
		if is_instance_valid(t) and t.is_alive:
			t.destroy_turret()
			
	# 大爆発シーケンス
	var main_tree = get_tree()
	if PARRY_PARTICLE_SCENE and main_tree:
		for i in range(20):
			main_tree.create_timer(i * 0.1).timeout.connect(func():
				if is_instance_valid(self):
					var p = PARRY_PARTICLE_SCENE.instantiate()
					p.global_position = global_position + Vector2(randf_range(-350, 350), randf_range(-100, 100))
					p.scale = Vector2(4.0, 4.0)
					p.modulate = Color(1.0, randf_range(0.2, 0.9), 0.1)
					get_parent().add_child(p)
			)
			
	main_tree.create_timer(2.2).timeout.connect(func():
		var main = get_node_or_null("/root/Main")
		if main:
			var mgr = main.get_node_or_null("GameManager")
			if mgr and mgr.has_method("on_boss_destroyed"):
				mgr.on_boss_destroyed()
		queue_free()
	)


func get_current_hp() -> int:
	return current_hp
