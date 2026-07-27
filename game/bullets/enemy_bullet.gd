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

# カラー定数
const COLOR_FRIENDLY = Color.CYAN
const COLOR_BEAM = Color(1.0, 0.4, 0.4)
const COLOR_MISSILE = Color(0.8, 0.2, 1.0)
const COLOR_BOSS_LASER = Color(1.0, 0.1, 0.1)
const COLOR_BOSS_MISSILE = Color(0.9, 0.6, 0.1)

# 速度・反射マルチプライヤー
const PARRY_SPEED_MULTIPLIER: float = 3.0
const MIN_SAFETY_SPEED: float = 100.0
const DEFAULT_SAFETY_SPEED: float = 200.0
const HOMING_LERP_SPEED: float = 10.0
const SCREEN_OFFSCREEN_MARGIN: float = 50.0

@export var speed: float = 200.0
@export var damage: int = 10

var velocity: Vector2 = Vector2.ZERO
var is_friendly: bool = false
var bullet_type: String = BULLET_TYPE_BEAM

const PARRY_PARTICLE_SCENE: PackedScene = preload("res://game/bullets/parry_particle.tscn")


func _ready() -> void:
	is_friendly = false
	update_bullet_color()
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func update_bullet_color() -> void:
	if is_friendly:
		modulate = COLOR_FRIENDLY
	else:
		match bullet_type:
			BULLET_TYPE_BEAM:
				modulate = COLOR_BEAM
			BULLET_TYPE_MISSILE:
				modulate = COLOR_MISSILE
			BULLET_TYPE_BOSS_LASER:
				modulate = COLOR_BOSS_LASER
			BULLET_TYPE_BOSS_MISSILE:
				modulate = COLOR_BOSS_MISSILE
			_:
				modulate = COLOR_BEAM


func _on_body_entered(body: Node2D) -> void:
	if not is_friendly:
		if body.name == "Player" or body.has_method("take_damage"):
			body.take_damage(damage)
			recycle_bullet()


func _on_area_entered(area: Area2D) -> void:
	if is_friendly:
		if area.is_in_group("boss") or area.is_in_group("enemy") or area.is_in_group("drones") or area.name == "BossDamageShape":
			var damage_target: Node = area
			if not area.has_method("take_damage") and area.get_parent().has_method("take_damage"):
				damage_target = area.get_parent()
				
			if damage_target.has_method("take_damage"):
				damage_target.take_damage(damage)
			recycle_bullet()


func _process(delta: float) -> void:
	if is_friendly:
		var main = get_node_or_null("/root/Main")
		if main:
			var boss = main.get_node_or_null("Boss")
			if is_instance_valid(boss) and boss.visible:
				var target_dir = (boss.global_position - global_position).normalized()
				var target_velocity = target_dir * velocity.length()
				velocity = velocity.lerp(target_velocity, delta * HOMING_LERP_SPEED)
			else:
				var drones = get_tree().get_nodes_in_group("drones")
				if drones.size() > 0:
					var closest_drone = drones[0]
					var min_dist = global_position.distance_to(closest_drone.global_position)
					for drone in drones:
						var d = global_position.distance_to(drone.global_position)
						if d < min_dist:
							min_dist = d
							closest_drone = drone
					if is_instance_valid(closest_drone):
						var target_dir = (closest_drone.global_position - global_position).normalized()
						var target_velocity = target_dir * velocity.length()
						velocity = velocity.lerp(target_velocity, delta * HOMING_LERP_SPEED)

	if velocity.length() < MIN_SAFETY_SPEED:
		if velocity == Vector2.ZERO:
			velocity = Vector2.UP * speed
		else:
			velocity = velocity.normalized() * (speed if speed > MIN_SAFETY_SPEED else DEFAULT_SAFETY_SPEED)

	position += velocity * delta
	
	var viewport_rect = get_viewport_rect()
	if position.x < -SCREEN_OFFSCREEN_MARGIN or position.x > viewport_rect.size.x + SCREEN_OFFSCREEN_MARGIN or \
	   position.y < -SCREEN_OFFSCREEN_MARGIN or position.y > viewport_rect.size.y + SCREEN_OFFSCREEN_MARGIN:
		recycle_bullet()


func recycle_bullet() -> void:
	"""弾をプールに戻す。プールがない場合は消去する。"""
	var main = get_node_or_null("/root/Main")
	if main:
		var pool = main.get_node_or_null("BulletPool")
		if pool and pool.has_method("return_bullet"):
			pool.return_bullet(self)
			return
	queue_free()


func set_direction(direction: Vector2, speed_override: float = 0.0) -> void:
	velocity = direction.normalized() * (speed_override if speed_override > 0.0 else speed)


func convert_to_friendly() -> void:
	if is_friendly:
		return
	is_friendly = true
	velocity = -velocity * PARRY_SPEED_MULTIPLIER
	update_bullet_color()

	if PARRY_PARTICLE_SCENE and get_parent():
		var particle = PARRY_PARTICLE_SCENE.instantiate()
		particle.global_position = global_position
		get_parent().add_child(particle)
	
	var main = get_node_or_null("/root/Main")
	if main:
		var manager = main.get_node_or_null("GameManager")
		if manager and manager.has_method("register_parry"):
			manager.register_parry()


func is_owned_by_player() -> bool:
	return is_friendly
