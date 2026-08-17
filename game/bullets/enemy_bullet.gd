extends Area2D
## 敵弾スクリプト
## - 移動・弾道制御
## - 所有権管理（敵 ⇄ 味方）
## - ジャストガード（パリィ）成功時の反射・追尾変換

# 定数
const BULLET_TYPE_BEAM = "beam"
const BULLET_TYPE_MISSILE = "missile"
const BULLET_TYPE_BOSS_LASER = "boss_laser"
const BULLET_TYPE_BOSS_MISSILE = "boss_missile"
const BULLET_TYPE_DECEL_MISSILE = "decel_missile"

# カラー定数
const COLOR_FRIENDLY = Color(1.0, 0.25, 0.25) # パリィ反射時は赤色
const COLOR_BEAM = Color(1.0, 0.4, 0.4)
const COLOR_MISSILE = Color(0.8, 0.2, 1.0)
const COLOR_BOSS_LASER = Color(1.0, 0.1, 0.1)
const COLOR_BOSS_MISSILE = Color(0.9, 0.6, 0.1)
const COLOR_DECEL_MISSILE = Color(1.0, 0.4, 0.8)

# 速度・反射マルチプライヤー
const PARRY_SPEED_MULTIPLIER: float = 3.2
const MIN_SAFETY_SPEED: float = 80.0
const DEFAULT_SAFETY_SPEED: float = 200.0
const HOMING_LERP_SPEED: float = 14.0
const SCREEN_OFFSCREEN_MARGIN: float = 60.0

@export var speed: float = 200.0
@export var damage: int = 8

var velocity: Vector2 = Vector2.ZERO
var is_friendly: bool = false
var bullet_type: String = BULLET_TYPE_BEAM
var target_node: Node2D = null

# 減速追尾ミサイル用変数
var initial_speed: float = 350.0
var decel_timer: float = 0.0
var decel_phase: int = 0 # 0: 減速中 (0~1.0s), 1: 急加速追尾 (1.0s~)

const PARRY_PARTICLE_SCENE: PackedScene = preload("res://game/bullets/parry_particle.tscn")


func _ready() -> void:
	is_friendly = false
	decel_timer = 0.0
	decel_phase = 0
	target_node = null
	update_bullet_color()
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func update_bullet_color() -> void:
	if is_friendly:
		modulate = COLOR_FRIENDLY
		var sprite = get_node_or_null("Sprite2D")
		if sprite:
			sprite.scale = Vector2(1.2, 1.2) # 赤く巨大化
	else:
		var sprite = get_node_or_null("Sprite2D")
		if sprite:
			sprite.scale = Vector2(0.5, 0.5)
		match bullet_type:
			"straight":
				modulate = Color(0.3, 0.75, 1.0) # 直進シアン
				if sprite: sprite.scale = Vector2(0.45, 0.7)
			"charge":
				modulate = Color(1.0, 0.35, 0.15) # チャージ赤橙
				if sprite: sprite.scale = Vector2(0.8, 1.2)
			"wave":
				modulate = Color(0.2, 0.9, 0.5) # 拡散エメラルド
				if sprite: sprite.scale = Vector2(0.55, 0.55)
			"irregular":
				modulate = Color(1.0, 0.85, 0.2) # 不規則イエロー
				if sprite: sprite.scale = Vector2(0.5, 0.5)
			"laser", BULLET_TYPE_BOSS_LASER:
				modulate = Color(0.4, 0.8, 1.0) # レーザーシアン
				if sprite: sprite.scale = Vector2(0.4, 1.5)
			"missile", BULLET_TYPE_BOSS_MISSILE:
				modulate = Color(0.85, 0.4, 1.0) # 追尾パープル
				if sprite: sprite.scale = Vector2(0.6, 0.6)
			BULLET_TYPE_DECEL_MISSILE:
				modulate = Color(1.0, 0.3, 0.8) # 減速追尾ピンク
				if sprite: sprite.scale = Vector2(0.7, 0.7)
			_:
				modulate = COLOR_BEAM


func _on_body_entered(body: Node2D) -> void:
	if not is_friendly:
		if body.name == "Player" or body.has_method("take_damage"):
			body.take_damage(damage)
			recycle_bullet()


func _on_area_entered(area: Area2D) -> void:
	if is_friendly:
		if area.is_in_group("boss") or area.is_in_group("boss_turrets") or area.is_in_group("enemy") or area.is_in_group("drones") or area.name == "BossDamageShape" or area.name == "Core":
			var damage_target: Node = area
			if not area.has_method("take_damage") and area.get_parent() and area.get_parent().has_method("take_damage"):
				damage_target = area.get_parent()
				
			if damage_target.has_method("take_damage"):
				damage_target.take_damage(damage)
			elif damage_target.has_method("take_damage_on_part"):
				damage_target.take_damage_on_part("core", damage)
			recycle_bullet()


func _process(delta: float) -> void:
	if is_friendly:
		# パリィ後追尾処理
		if not is_instance_valid(target_node) or not target_node.visible:
			find_new_friendly_target()
			
		if is_instance_valid(target_node):
			var target_dir = (target_node.global_position - global_position).normalized()
			var target_velocity = target_dir * velocity.length()
			velocity = velocity.lerp(target_velocity, delta * HOMING_LERP_SPEED)
			
	else:
		# 減速 ➔ 急加速追尾ミサイル処理
		if bullet_type == BULLET_TYPE_DECEL_MISSILE:
			decel_timer += delta
			if decel_phase == 0:
				# 1秒かけて減速 (停止直前へ)
				var ratio = clamp(1.0 - (decel_timer / 1.0), 0.05, 1.0)
				velocity = velocity.normalized() * (initial_speed * ratio)
				
				if decel_timer >= 1.0:
					decel_phase = 1
					# 停止直前に初速の1.2倍でプレイヤーめがけて急加速
					var player = get_node_or_null("/root/Main/Player")
					var target_dir = Vector2.DOWN
					if is_instance_valid(player):
						target_dir = (player.global_position - global_position).normalized()
					velocity = target_dir * (initial_speed * 1.2)
					modulate = Color(1.0, 0.2, 0.2) # 急加速時に赤く点灯
			else:
				# 追尾フェーズ（緩やかにプレイヤーへ補正）
				var player = get_node_or_null("/root/Main/Player")
				if is_instance_valid(player):
					var target_dir = (player.global_position - global_position).normalized()
					velocity = velocity.lerp(target_dir * (initial_speed * 1.2), delta * 4.0)

	if velocity.length() < MIN_SAFETY_SPEED and decel_phase != 0:
		if velocity == Vector2.ZERO:
			velocity = Vector2.UP * speed
		else:
			velocity = velocity.normalized() * (speed if speed > MIN_SAFETY_SPEED else DEFAULT_SAFETY_SPEED)

	position += velocity * delta
	
	var viewport_rect = get_viewport_rect()
	if position.x < -SCREEN_OFFSCREEN_MARGIN or position.x > viewport_rect.size.x + SCREEN_OFFSCREEN_MARGIN or \
	   position.y < -SCREEN_OFFSCREEN_MARGIN or position.y > viewport_rect.size.y + SCREEN_OFFSCREEN_MARGIN:
		recycle_bullet()


func find_new_friendly_target() -> void:
	var turrets = get_tree().get_nodes_in_group("boss_turrets")
	var valid_turrets = []
	for t in turrets:
		if is_instance_valid(t) and t.visible:
			valid_turrets.append(t)
			
	# 8割砲台、2割ボス
	if valid_turrets.size() > 0 and randf() < 0.8:
		target_node = valid_turrets.pick_random()
	else:
		var main = get_node_or_null("/root/Main")
		if main:
			var boss = main.get_node_or_null("Boss")
			if is_instance_valid(boss) and boss.visible:
				target_node = boss
			else:
				var drones = get_tree().get_nodes_in_group("drones")
				if drones.size() > 0:
					target_node = drones.pick_random()


func recycle_bullet() -> void:
	var main = get_node_or_null("/root/Main")
	if main:
		var pool = main.get_node_or_null("BulletPool")
		if pool and pool.has_method("return_bullet"):
			pool.return_bullet(self)
			return
	queue_free()


func set_direction(direction: Vector2, speed_override: float = 0.0) -> void:
	speed = speed_override if speed_override > 0.0 else speed
	initial_speed = speed
	velocity = direction.normalized() * speed


func convert_to_friendly() -> void:
	if is_friendly:
		return
	is_friendly = true
	damage = int(damage * 3.5) # パリィ反射ボーナスダメージ
	
	# スピード上昇と方向反転
	velocity = -velocity * PARRY_SPEED_MULTIPLIER
	update_bullet_color()
	
	# ターゲット設定（8割 砲台, 2割 ボス）
	find_new_friendly_target()

	if PARRY_PARTICLE_SCENE and get_parent():
		var particle = PARRY_PARTICLE_SCENE.instantiate()
		particle.global_position = global_position
		particle.scale = Vector2(2.0, 2.0)
		particle.modulate = Color(1.0, 0.2, 0.2)
		get_parent().add_child(particle)
	
	var main = get_node_or_null("/root/Main")
	if main:
		var manager = main.get_node_or_null("GameManager")
		if manager and manager.has_method("register_parry"):
			manager.register_parry()


func is_owned_by_player() -> bool:
	return is_friendly
