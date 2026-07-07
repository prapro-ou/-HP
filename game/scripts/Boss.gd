extends Node2D
## ボススクリプト
## - フェーズ管理
## - 敵弾発射パターン

@export var max_hp: int = 300
@export var phase2_hp_threshold: int = 200
@export var phase3_hp_threshold: int = 100

var current_hp: int
var current_phase: int = 1
var bullet_pool: Node2D  # BulletPool への参照

var fire_timer: float = 0.0

# 移動用の変数
var move_timer: float = 0.0
var move_target: Vector2 = Vector2.ZERO
var base_move_speed: float = 110.0
var current_move_speed: float = 110.0


func _ready() -> void:
	current_hp = max_hp * 3  # 全3フェーズ
	bullet_pool = get_node_or_null("../BulletPool")
	move_target = position # 初期位置を最初の目標に
	choose_new_target()


func _process(delta: float) -> void:
	fire_timer += delta
	move_timer += delta
	
	# フェーズチェックと移動速度の更新
	update_phase()
	update_move_speed()
	
	# 3秒ごとに新しい移動目標を設定
	if move_timer >= 3.0:
		choose_new_target()
		move_timer = 0.0
		
	# 目標座標に向かって滑らかに移動
	position = position.move_toward(move_target, current_move_speed * delta)
	
	# 敵弾発射
	match current_phase:
		1:
			if fire_timer >= 2.0:  # 2秒周期
				fire_phase1()
				fire_timer = 0.0
		2:
			if fire_timer >= 1.5:  # 1.5秒周期
				fire_phase2()
				fire_timer = 0.0
		3:
			if fire_timer >= 1.0:  # 1秒周期
				fire_phase3()
				fire_timer = 0.0



func update_phase() -> void:
	"""HP に応じてフェーズ遷移"""
	if current_hp <= phase3_hp_threshold and current_phase < 3:
		current_phase = 3
		# TODO: フェーズ遷移演出（画面揺れなど）
	elif current_hp <= phase2_hp_threshold and current_phase < 2:
		current_phase = 2
		# TODO: フェーズ遷移演出


func fire_phase1() -> void:
	"""フェーズ1: 扇状発射（5発）"""
	var angles = [90, 72, 108, 54, 126]  # 前方中心に5方向
	for angle in angles:
		var rad = deg_to_rad(angle)
		var direction = Vector2(cos(rad), sin(rad))
		spawn_bullet(direction)


func fire_phase2() -> void:
	"""フェーズ2: 円形発射（15発）"""
	for i in range(15):
		var angle = (360.0 / 15) * i
		var rad = deg_to_rad(angle)
		var direction = Vector2(cos(rad), sin(rad))
		spawn_bullet(direction)


func fire_phase3() -> void:
	"""フェーズ3: 弾幕発射（50発）"""
	for i in range(50):
		var angle = (360.0 / 50) * i
		var rad = deg_to_rad(angle)
		var direction = Vector2(cos(rad), sin(rad))
		spawn_bullet(direction)


func spawn_bullet(direction: Vector2) -> void:
	"""敵弾をスポーン"""
	if bullet_pool and bullet_pool.has_method("get_bullet"):
		var bullet = bullet_pool.get_bullet()
		bullet.global_position = global_position
		bullet.set_direction(direction)


func take_damage(amount: int) -> void:
	"""ダメージ受け取り"""
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0


func update_move_speed() -> void:
	"""フェーズに応じて移動速度を更新"""
	match current_phase:
		1:
			current_move_speed = base_move_speed
		2:
			current_move_speed = base_move_speed * 1.5
		3:
			current_move_speed = base_move_speed * 2.2


func choose_new_target() -> void:
	"""画面上部のランダムな位置を目標座標に選ぶ"""
	var viewport_rect = get_viewport_rect()
	if viewport_rect:
		var rx = randf_range(150.0, viewport_rect.size.x - 150.0)
		var ry = randf_range(80.0, 220.0)
		move_target = Vector2(rx, ry)
