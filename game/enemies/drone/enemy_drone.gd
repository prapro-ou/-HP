extends BaseEnemy
## 雑魚敵（ドローン）スクリプト - BaseEnemyを継承
## 出現後、一定高度まで下降して左右にホバリングし、タイプに応じた固有パターン攻撃を行います。

# ドローンタイプ定数
const TYPE_CHARGE = "charge"
const TYPE_STRAIGHT = "straight"
const TYPE_IRREGULAR = "irregular"
const TYPE_LASER = "laser"
const TYPE_WAVE = "wave"
const TYPE_BEAM = "beam"
const TYPE_MISSILE = "missile"

# タイプ別表示色
const COLOR_CHARGE = Color(1.0, 0.3, 0.2)
const COLOR_STRAIGHT = Color(0.4, 0.7, 1.0)
const COLOR_IRREGULAR = Color(0.9, 0.3, 0.9)
const COLOR_LASER = Color(1.0, 0.8, 0.2)
const COLOR_WAVE = Color(0.3, 1.0, 0.5)
const COLOR_BEAM = Color(1.0, 0.5, 0.5)
const COLOR_MISSILE = Color(0.8, 0.4, 1.0)

# デフォルト数値定数
const DEFAULT_DRONE_HP: int = 75
const DEFAULT_DRONE_SPEED: float = 140.0
const SCREEN_MARGIN_X: float = 60.0

@export var drone_type: String = TYPE_STRAIGHT

var target_y: float = 200.0
var speed: float = DEFAULT_DRONE_SPEED
var shoot_interval: float = 1.5
var time_since_last_shot: float = 0.0
var move_direction: float = 1.0
var bullet_pool: Node2D
var player: CharacterBody2D
var is_charging: bool = false
var charge_timer: float = 0.0


func _ready_enemy() -> void:
	add_to_group("drones")
	
	player = get_node_or_null("/root/Main/Player")
	bullet_pool = get_node_or_null("/root/Main/BulletPool")
	
	# 基礎耐久力 (120 HP)
	var base_hp = 120
	
	# 1. ステージ・ウェーブ進行に応じた耐久力補正
	var stage_num = 1
	var main = get_node_or_null("/root/Main")
	if main:
		var gm = main.get_node_or_null("GameManager")
		if gm and "current_stage_num" in gm:
			stage_num = gm.current_stage_num
			if "current_wave_level" in gm:
				base_hp += (gm.current_wave_level - 1) * 25
				
	base_hp += (stage_num - 1) * 50
	
	# 2. プレイヤーの強化内容に応じた耐久力スケーリング
	if is_instance_valid(player):
		var player_analysis_lvls = 0
		if "analysis_patterns" in player:
			for p_data in player.analysis_patterns.values():
				player_analysis_lvls += p_data.get("level", 0)
		base_hp += player_analysis_lvls * 20
		
	if Global and "upgrade_levels" in Global:
		var total_tech_lvls = Global.upgrade_levels.get("hp", 0) + Global.upgrade_levels.get("parry_window", 0) + Global.upgrade_levels.get("cooldown", 0)
		base_hp += total_tech_lvls * 15
		
	max_hp = base_hp
	current_hp = max_hp
	
	# タイプ別に攻撃スパンをゆったり長く設定（2.8〜3.8秒）
	match drone_type:
		TYPE_CHARGE:
			shoot_interval = randf_range(3.4, 4.0)
			modulate = Color(1.0, 0.35, 0.25) # チャージ赤橙
		TYPE_STRAIGHT:
			shoot_interval = randf_range(2.6, 3.2)
			modulate = Color(0.3, 0.75, 1.0)  # 直進シアン
		TYPE_IRREGULAR:
			shoot_interval = randf_range(2.8, 3.5)
			modulate = Color(1.0, 0.85, 0.2)  # 不規則イエロー
		TYPE_LASER:
			shoot_interval = randf_range(3.2, 3.8)
			modulate = Color(1.0, 0.55, 0.1)  # レーザーオレンジ
		TYPE_WAVE:
			shoot_interval = randf_range(3.0, 3.6)
			modulate = Color(0.2, 0.9, 0.5)   # 拡散エメラルド
		TYPE_BEAM:
			shoot_interval = randf_range(2.8, 3.4)
			modulate = Color(1.0, 0.3, 0.6)   # ビームマゼンタ
		TYPE_MISSILE, _:
			shoot_interval = randf_range(3.2, 3.8)
			modulate = Color(0.8, 0.4, 1.0)   # 追尾パープル
		
	bullet_pool = get_node_or_null("/root/Main/BulletPool")
	player = get_node_or_null("/root/Main/Player")
	
	target_y = randf_range(100.0, 260.0)
	# 攻撃タイミングを敵ごとに大きくばらけさせる (0.0 〜 スパンの80%の間でランダム開始)
	time_since_last_shot = randf_range(0.0, shoot_interval * 0.75)
	move_direction = 1.0 if randf() > 0.5 else -1.0


func _process(delta: float) -> void:
	if position.y < target_y:
		position.y += speed * 1.3 * delta
	else:
		position.x += speed * 0.7 * move_direction * delta
		var viewport_w = get_viewport_rect().size.x
		if position.x < SCREEN_MARGIN_X:
			position.x = SCREEN_MARGIN_X
			move_direction = 1.0
		elif position.x > viewport_w - SCREEN_MARGIN_X:
			position.x = viewport_w - SCREEN_MARGIN_X
			move_direction = -1.0
			
	if is_charging:
		charge_timer -= delta
		modulate.a = 0.4 + 0.6 * sin(charge_timer * 40.0)
		if charge_timer <= 0.0:
			is_charging = false
			modulate.a = 1.0
			fire_charged_shot()
		return
		
	time_since_last_shot += delta
	if time_since_last_shot >= shoot_interval:
		shoot()
		time_since_last_shot = 0.0


func shoot() -> void:
	if not is_instance_valid(bullet_pool):
		return
		
	match drone_type:
		TYPE_CHARGE:
			is_charging = true
			charge_timer = 0.45
		TYPE_STRAIGHT:
			var dir = Vector2.DOWN
			if is_instance_valid(player):
				dir = (player.global_position - global_position).normalized()
			for i in range(3):
				get_tree().create_timer(i * 0.1).timeout.connect(func():
					if is_instance_valid(self) and current_hp > 0 and is_alive and is_instance_valid(bullet_pool):
						var bullet = bullet_pool.get_bullet("straight")
						if bullet:
							bullet.global_position = global_position + Vector2(0.0, 20.0)
							bullet.set_direction(dir, 320.0)
				)
		TYPE_BEAM, TYPE_LASER:
			var center_dir = Vector2.DOWN
			if is_instance_valid(player):
				center_dir = (player.global_position - global_position).normalized()
			var angles = [-0.3, 0.0, 0.3]
			for a in angles:
				var bullet = bullet_pool.get_bullet("laser")
				if bullet:
					bullet.global_position = global_position + Vector2(0.0, 20.0)
					bullet.set_direction(center_dir.rotated(a), 340.0)
		TYPE_IRREGULAR:
			var base_dir = (player.global_position - global_position).normalized() if is_instance_valid(player) else Vector2.DOWN
			for i in range(4):
				get_tree().create_timer(i * 0.08).timeout.connect(func():
					if is_instance_valid(self) and current_hp > 0 and is_alive and is_instance_valid(bullet_pool):
						var angle_offset = randf_range(-0.35, 0.35)
						var dir = base_dir.rotated(angle_offset)
						var bullet = bullet_pool.get_bullet("irregular")
						if bullet:
							bullet.global_position = global_position + Vector2(0.0, 20.0)
							bullet.set_direction(dir, 280.0)
				)
		TYPE_WAVE:
			var angles = [-0.5, -0.25, 0.0, 0.25, 0.5]
			for a in angles:
				var bullet = bullet_pool.get_bullet("wave")
				if bullet:
					bullet.global_position = global_position + Vector2(0.0, 20.0)
					bullet.set_direction(Vector2.DOWN.rotated(a), 260.0)
		TYPE_MISSILE, _:
			var dir = Vector2.DOWN
			if is_instance_valid(player):
				dir = (player.global_position - global_position).normalized()
			for i in range(2):
				get_tree().create_timer(i * 0.15).timeout.connect(func():
					if is_instance_valid(self) and current_hp > 0 and is_alive and is_instance_valid(bullet_pool):
						var bullet = bullet_pool.get_bullet("missile")
						if bullet:
							var offset_x = -15.0 if i == 0 else 15.0
							bullet.global_position = global_position + Vector2(offset_x, 20.0)
							var shoot_dir = dir.rotated(randf_range(-0.1, 0.1))
							bullet.set_direction(shoot_dir, 240.0)
				)


func fire_charged_shot() -> void:
	if not is_instance_valid(bullet_pool):
		return
	var dir = Vector2.DOWN
	if is_instance_valid(player):
		dir = (player.global_position - global_position).normalized()
	for i in range(2):
		get_tree().create_timer(i * 0.15).timeout.connect(func():
			if is_instance_valid(self) and current_hp > 0 and is_alive and is_instance_valid(bullet_pool):
				var bullet = bullet_pool.get_bullet("charge")
				if bullet:
					bullet.global_position = global_position + Vector2(0.0, 25.0)
					bullet.damage = 16
					bullet.set_direction(dir, 480.0)
		)


const DATA_ORB_SCENE: PackedScene = preload("res://game/core/data_orb.tscn")

func die() -> void:
	# 技研ポイント獲得: 雑魚敵撃破で +3 TP
	Global.tech_points += 3
	
	# 吸収マトリクス（GAUGE SHIELD）装備時のみ解析データオーブを放出して高速吸引！
	if Global.equipped_shield == "gauge" and DATA_ORB_SCENE and get_parent():
		var num_orbs = randi_range(1, 2)
		for _i in range(num_orbs):
			var orb = DATA_ORB_SCENE.instantiate()
			orb.setup_orb(drone_type, global_position, player)
			get_parent().add_child(orb)
		
	var main = get_node_or_null("/root/Main")
	if main:
		var manager = main.get_node_or_null("GameManager")
		if manager and manager.has_method("on_drone_destroyed"):
			manager.on_drone_destroyed(self)
			
	super.die()
