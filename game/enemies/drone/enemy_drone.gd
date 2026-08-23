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
const TYPE_THUNDER = "thunder"
const TYPE_VORTEX = "vortex"
const TYPE_BLADE = "blade"

# タイプ別表示色
const COLOR_CHARGE = Color(1.0, 0.3, 0.2)
const COLOR_STRAIGHT = Color(0.4, 0.7, 1.0)
const COLOR_IRREGULAR = Color(0.9, 0.3, 0.9)
const COLOR_LASER = Color(1.0, 0.8, 0.2)
const COLOR_WAVE = Color(0.3, 1.0, 0.5)
const COLOR_BEAM = Color(1.0, 0.5, 0.5)
const COLOR_MISSILE = Color(0.8, 0.4, 1.0)
const COLOR_THUNDER = Color(1.0, 0.95, 0.2)
const COLOR_VORTEX = Color(0.75, 0.3, 1.0)
const COLOR_BLADE = Color(0.2, 1.0, 0.85)

# デフォルト数値定数
const DEFAULT_DRONE_HP: int = 75
const DEFAULT_DRONE_SPEED: float = 140.0
const SCREEN_MARGIN_X: float = 45.0
const MIN_ACTIVE_Y: float = 120.0
const MAX_ACTIVE_Y: float = 720.0

@export var drone_type: String = TYPE_STRAIGHT
@export var is_slow: bool = false

var force_slow_mode: Variant = null
var speed_multiplier: float = 1.0

var target_y: float = 250.0
var base_y: float = 250.0
var speed: float = DEFAULT_DRONE_SPEED
var shoot_interval: float = 1.5
var time_since_last_shot: float = 0.0
var move_direction: Vector2 = Vector2.RIGHT
var flight_time: float = 0.0
var wave_offset: float = 0.0
var y_amplitude: float = 80.0
var y_frequency: float = 1.5
var diagonal_velocity: Vector2 = Vector2.ZERO

var bullet_pool: Node2D
var player: CharacterBody2D
var is_charging: bool = false
var charge_timer: float = 0.0

var contact_damage_timer: float = 0.0
const CONTACT_DAMAGE_INTERVAL: float = 1.0
const CONTACT_DAMAGE_AMOUNT: int = 12
var is_touching_player: bool = false


func _ready_enemy() -> void:
	add_to_group("drones")
	
	player = get_node_or_null("/root/Main/Player")
	bullet_pool = get_node_or_null("/root/Main/BulletPool")
	flight_time = randf_range(0.0, 10.0)
	wave_offset = randf_range(0.0, TAU)
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
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
				base_hp += (gm.current_wave_level - 1) * 20
				
	# 2. プレイヤーの強化内容に応じた耐久力スケーリング
	if is_instance_valid(player):
		var player_analysis_lvls = 0
		if "analysis_patterns" in player:
			for p_data in player.analysis_patterns.values():
				player_analysis_lvls += p_data.get("level", 0)
		base_hp += player_analysis_lvls * 15
		
	if Global and "upgrade_levels" in Global:
		var total_tech_lvls = Global.upgrade_levels.get("hp", 0) + Global.upgrade_levels.get("parry_window", 0) + Global.upgrade_levels.get("cooldown", 0)
		base_hp += total_tech_lvls * 10
		
	# ステージ進行による1.2倍指数スケーリング (Stage 1: 1.0x, Stage 2: 1.2x, Stage 3: 1.44x...)
	var stage_mult = Global.get_stage_difficulty_multiplier(stage_num)
	max_hp = int(base_hp * stage_mult)
	current_hp = max_hp
	
	# タイプ別に攻撃スパンと行動範囲・高度・飛行パターンを設定
	var dir_x = 1.0 if randf() > 0.5 else -1.0
	match drone_type:
		TYPE_CHARGE:
			shoot_interval = randf_range(2.4, 2.8)
			modulate = Color(1.0, 0.35, 0.25) # チャージ赤橙
			base_y = randf_range(350.0, 580.0) # 深く前進・中下段まで接近
			y_amplitude = 50.0
			y_frequency = 1.0
			speed = 120.0
			move_direction = Vector2(dir_x, 0.0)
		TYPE_STRAIGHT:
			shoot_interval = randf_range(1.7, 2.2)
			modulate = Color(0.3, 0.75, 1.0)  # 直進シアン
			base_y = randf_range(160.0, 480.0)
			# 斜め広域バウンド移動（画面全体を高速で駆け巡る）
			var angle = randf_range(0.5, 0.9) * (1.0 if randf() > 0.5 else -1.0)
			diagonal_velocity = Vector2(dir_x * 140.0, angle * 110.0)
			speed = 160.0
		TYPE_IRREGULAR:
			shoot_interval = randf_range(1.9, 2.4)
			modulate = Color(1.0, 0.85, 0.2)  # 不規則イエロー
			base_y = randf_range(250.0, 520.0)
			# 8の字旋回（広範囲リサージュ曲線）
			y_amplitude = randf_range(100.0, 160.0)
			y_frequency = randf_range(1.4, 2.0)
			speed = 150.0
			move_direction = Vector2(dir_x, 0.0)
		TYPE_LASER, TYPE_BEAM:
			shoot_interval = randf_range(2.0, 2.5)
			modulate = Color(1.0, 0.55, 0.1) if drone_type == TYPE_LASER else Color(1.0, 0.3, 0.6)
			base_y = randf_range(180.0, 450.0)
			y_amplitude = 70.0
			y_frequency = 1.3
			speed = 130.0
			move_direction = Vector2(dir_x, 0.0)
		TYPE_WAVE:
			shoot_interval = randf_range(2.0, 2.5)
			modulate = Color(0.2, 0.9, 0.5)   # 拡散エメラルド
			base_y = randf_range(220.0, 540.0)
			# S字大蛇行ウェーブ
			y_amplitude = randf_range(90.0, 150.0)
			y_frequency = randf_range(1.6, 2.4)
			speed = 140.0
			move_direction = Vector2(dir_x, 0.0)
		TYPE_THUNDER:
			shoot_interval = randf_range(1.8, 2.3)
			modulate = COLOR_THUNDER # 放電イエロー
			base_y = randf_range(200.0, 480.0)
			y_amplitude = 60.0
			y_frequency = 1.8
			speed = 170.0
			move_direction = Vector2(dir_x, 0.0)
		TYPE_VORTEX:
			shoot_interval = randf_range(2.4, 2.9)
			modulate = COLOR_VORTEX # 深紫特異点
			base_y = randf_range(240.0, 450.0)
			y_amplitude = 40.0
			y_frequency = 1.0
			speed = 110.0
			move_direction = Vector2(dir_x, 0.0)
		TYPE_BLADE:
			shoot_interval = randf_range(1.9, 2.4)
			modulate = COLOR_BLADE # 青緑真空波
			base_y = randf_range(180.0, 520.0)
			y_amplitude = 90.0
			y_frequency = 1.4
			speed = 160.0
			move_direction = Vector2(dir_x, 0.0)
		TYPE_MISSILE, _:
			shoot_interval = randf_range(2.2, 2.7)
			modulate = Color(0.8, 0.4, 1.0)   # 追尾パープル
			base_y = randf_range(200.0, 560.0)
			y_amplitude = 80.0
			y_frequency = 1.2
			speed = 135.0
			move_direction = Vector2(dir_x, 0.0)
		
	target_y = base_y
	time_since_last_shot = randf_range(0.0, shoot_interval * 0.75)
	
	# 移動速度の低速化判定（約半数の敵を通常の半分の移動速度にする）
	if force_slow_mode != null:
		is_slow = bool(force_slow_mode)
	elif not is_slow:
		is_slow = (randf() < 0.5)
		
	if is_slow:
		speed_multiplier = 0.5
		speed *= speed_multiplier
		diagonal_velocity *= speed_multiplier
		y_frequency *= 0.75


## 外部（Wave設定など）からの速度上書き
func set_override_speed(base_spd: float) -> void:
	speed = base_spd * speed_multiplier
	if drone_type == TYPE_STRAIGHT and diagonal_velocity != Vector2.ZERO:
		diagonal_velocity = diagonal_velocity.normalized() * (base_spd * speed_multiplier)


func _process(delta: float) -> void:
	flight_time += delta
	var viewport_w = get_viewport_rect().size.x
	
	# 出現時の初期降下
	if position.y < target_y and flight_time < 1.5:
		position.y += speed * 1.6 * delta
	else:
		# タイプ別の広域・ダイナミック移動処理
		match drone_type:
			TYPE_STRAIGHT:
				# 斜め広域バウンド（画面全体を斜めに跳ね返りながら移動）
				position += diagonal_velocity * delta
				if position.x < SCREEN_MARGIN_X:
					position.x = SCREEN_MARGIN_X
					diagonal_velocity.x = abs(diagonal_velocity.x)
				elif position.x > viewport_w - SCREEN_MARGIN_X:
					position.x = viewport_w - SCREEN_MARGIN_X
					diagonal_velocity.x = -abs(diagonal_velocity.x)
					
				if position.y < MIN_ACTIVE_Y:
					position.y = MIN_ACTIVE_Y
					diagonal_velocity.y = abs(diagonal_velocity.y)
				elif position.y > MAX_ACTIVE_Y:
					position.y = MAX_ACTIVE_Y
					diagonal_velocity.y = -abs(diagonal_velocity.y)
					
			TYPE_IRREGULAR:
				# 8の字旋回（リサージュ曲線＋左右スライド）
				position.x += speed * 0.8 * move_direction.x * delta
				var wave_y = sin(flight_time * y_frequency + wave_offset) * y_amplitude
				var wave_x = cos(flight_time * (y_frequency * 0.5) + wave_offset) * 40.0
				position.y = clamp(base_y + wave_y, MIN_ACTIVE_Y, MAX_ACTIVE_Y)
				position.x += wave_x * delta * 2.0
				
				if position.x < SCREEN_MARGIN_X:
					position.x = SCREEN_MARGIN_X
					move_direction.x = 1.0
				elif position.x > viewport_w - SCREEN_MARGIN_X:
					position.x = viewport_w - SCREEN_MARGIN_X
					move_direction.x = -1.0
					
			TYPE_WAVE:
				# S字大蛇行ウェーブ
				position.x += speed * 0.9 * move_direction.x * delta
				var wave_y = sin(flight_time * y_frequency + wave_offset) * y_amplitude
				position.y = clamp(base_y + wave_y, MIN_ACTIVE_Y, MAX_ACTIVE_Y)
				
				if position.x < SCREEN_MARGIN_X:
					position.x = SCREEN_MARGIN_X
					move_direction.x = 1.0
				elif position.x > viewport_w - SCREEN_MARGIN_X:
					position.x = viewport_w - SCREEN_MARGIN_X
					move_direction.x = -1.0
					
			TYPE_CHARGE:
				# 前進接近 -> チャージ -> 緩やかな上下左右スライド
				position.x += speed * 0.6 * move_direction.x * delta
				var subtle_y = sin(flight_time * y_frequency) * y_amplitude
				position.y = clamp(base_y + subtle_y, MIN_ACTIVE_Y, MAX_ACTIVE_Y)
				
				if position.x < SCREEN_MARGIN_X:
					position.x = SCREEN_MARGIN_X
					move_direction.x = 1.0
				elif position.x > viewport_w - SCREEN_MARGIN_X:
					position.x = viewport_w - SCREEN_MARGIN_X
					move_direction.x = -1.0
					
			TYPE_LASER, TYPE_BEAM:
				# プレイヤーのX座標を緩やかに追従・捕捉しつつ上下に浮遊
				if is_instance_valid(player):
					var target_x = player.global_position.x
					var diff_x = target_x - position.x
					position.x += clamp(diff_x * 1.5, -speed * 0.85, speed * 0.85) * delta
				else:
					position.x += speed * 0.7 * move_direction.x * delta
					
				var wave_y = sin(flight_time * y_frequency + wave_offset) * y_amplitude
				position.y = clamp(base_y + wave_y, MIN_ACTIVE_Y, MAX_ACTIVE_Y)
				position.x = clamp(position.x, SCREEN_MARGIN_X, viewport_w - SCREEN_MARGIN_X)
				
			TYPE_MISSILE, _:
				# 左右往復 ＋ 大きな上下サイン波
				position.x += speed * 0.75 * move_direction.x * delta
				var wave_y = sin(flight_time * y_frequency + wave_offset) * y_amplitude
				position.y = clamp(base_y + wave_y, MIN_ACTIVE_Y, MAX_ACTIVE_Y)
				
				if position.x < SCREEN_MARGIN_X:
					position.x = SCREEN_MARGIN_X
					move_direction.x = 1.0
				elif position.x > viewport_w - SCREEN_MARGIN_X:
					position.x = viewport_w - SCREEN_MARGIN_X
					move_direction.x = -1.0
			
	# プレイヤーとの接触ダメージ処理 (1秒ごとに30ダメージ)
	if is_alive and is_instance_valid(player):
		var is_touching = is_touching_player or (global_position.distance_to(player.global_position) < 38.0)
		if is_touching:
			contact_damage_timer -= delta
			if contact_damage_timer <= 0.0:
				contact_damage_timer = CONTACT_DAMAGE_INTERVAL
				if player.has_method("take_damage"):
					player.take_damage(CONTACT_DAMAGE_AMOUNT)
					HitSpark.create_spark(get_parent(), (global_position + player.global_position) * 0.5, "heavy", Color(1.0, 0.4, 0.2))
					Global.play_heavy_hit(1.1)
		else:
			contact_damage_timer = 0.0
			
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


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		is_touching_player = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		is_touching_player = false


func get_stage_mult() -> float:
	var stage_num = 1
	var main = get_node_or_null("/root/Main")
	if main:
		var gm = main.get_node_or_null("GameManager")
		if gm and "current_stage_num" in gm:
			stage_num = gm.current_stage_num
	return Global.get_stage_difficulty_multiplier(stage_num)


func shoot() -> void:
	if not is_instance_valid(bullet_pool):
		return
		
	var mult = get_stage_mult()
	match drone_type:
		TYPE_CHARGE:
			is_charging = true
			charge_timer = 0.40
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
							bullet.damage = int(10 * mult)
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
					bullet.damage = int(12 * mult)
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
							bullet.damage = int(10 * mult)
							bullet.set_direction(dir, 280.0)
				)
		TYPE_WAVE:
			var angles = [-0.5, -0.25, 0.0, 0.25, 0.5]
			for a in angles:
				var bullet = bullet_pool.get_bullet("wave")
				if bullet:
					bullet.global_position = global_position + Vector2(0.0, 20.0)
					bullet.damage = int(10 * mult)
					bullet.set_direction(Vector2.DOWN.rotated(a), 260.0)
		TYPE_THUNDER:
			var base_dir = (player.global_position - global_position).normalized() if is_instance_valid(player) else Vector2.DOWN
			for i in range(3):
				get_tree().create_timer(i * 0.12).timeout.connect(func():
					if is_instance_valid(self) and current_hp > 0 and is_alive and is_instance_valid(bullet_pool):
						var bullet = bullet_pool.get_bullet("thunder")
						if bullet:
							bullet.global_position = global_position + Vector2(randf_range(-15, 15), 20.0)
							bullet.damage = int(14 * mult)
							bullet.set_direction(base_dir.rotated(randf_range(-0.25, 0.25)), 350.0)
				)
		TYPE_VORTEX:
			var dir = (player.global_position - global_position).normalized() if is_instance_valid(player) else Vector2.DOWN
			var bullet = bullet_pool.get_bullet("vortex")
			if bullet:
				bullet.global_position = global_position + Vector2(0.0, 20.0)
				bullet.damage = int(15 * mult)
				bullet.set_direction(dir, 260.0)
		TYPE_BLADE:
			var dir = (player.global_position - global_position).normalized() if is_instance_valid(player) else Vector2.DOWN
			for a in [-0.22, 0.22]:
				var bullet = bullet_pool.get_bullet("blade")
				if bullet:
					bullet.global_position = global_position + Vector2(0.0, 20.0)
					bullet.damage = int(14 * mult)
					bullet.set_direction(dir.rotated(a), 320.0)
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
							bullet.damage = int(12 * mult)
							var shoot_dir = dir.rotated(randf_range(-0.1, 0.1))
							bullet.set_direction(shoot_dir, 240.0)
				)


func fire_charged_shot() -> void:
	if not is_instance_valid(bullet_pool):
		return
	var dir = Vector2.DOWN
	if is_instance_valid(player):
		dir = (player.global_position - global_position).normalized()
	var mult = get_stage_mult()
	for i in range(2):
		get_tree().create_timer(i * 0.15).timeout.connect(func():
			if is_instance_valid(self) and current_hp > 0 and is_alive and is_instance_valid(bullet_pool):
				var bullet = bullet_pool.get_bullet("charge")
				if bullet:
					bullet.global_position = global_position + Vector2(0.0, 25.0)
					bullet.damage = int(18 * mult)
					bullet.set_direction(dir, 480.0)
		)


const DATA_ORB_SCENE: PackedScene = preload("res://game/core/data_orb.tscn")

func die() -> void:
	# 技研ポイント獲得: 雑魚敵撃破で確率ドロップ (15%の確率で +1 TP)
	if randf() <= 0.15:
		Global.tech_points += 1
	
	# 吸収マトリクス（GAUGE SHIELD）装備時のみ解析データオーブを放出して高速吸引！
	var parent_node = get_parent()
	if Global.equipped_shield == "gauge" and DATA_ORB_SCENE and parent_node:
		var num_orbs = randi_range(1, 2)
		for _i in range(num_orbs):
			var orb = DATA_ORB_SCENE.instantiate()
			orb.setup_orb(drone_type, global_position, player)
			parent_node.call_deferred("add_child", orb)
		
	var main = get_node_or_null("/root/Main")
	if main:
		var manager = main.get_node_or_null("GameManager")
		if manager and manager.has_method("on_drone_destroyed"):
			manager.on_drone_destroyed(self)
			
	super.die()
