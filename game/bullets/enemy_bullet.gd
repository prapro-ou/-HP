extends Area2D
## 敵弾スクリプト
## - 移動
## - 所有権管理（敵 ← → 味方）
## - ジャストガード時の変換

@export var speed: float = 200.0
@export var damage: int = 10

var velocity: Vector2 = Vector2.ZERO
var is_friendly: bool = false  # true = プレイヤー所有、false = 敵所有
var bullet_type: String = "beam"  # "beam", "missile", "boss_laser", "boss_missile"

var ParryParticleScene = preload("res://game/bullets/parry_particle.tscn")



func _ready() -> void:
	# 初期状態設定
	is_friendly = false
	update_bullet_color()
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func update_bullet_color() -> void:
	if is_friendly:
		modulate = Color.CYAN
	else:
		match bullet_type:
			"beam":
				modulate = Color(1.0, 0.4, 0.4) # 薄赤 (Beam)
			"missile":
				modulate = Color(0.8, 0.2, 1.0) # 紫 (Missile)
			"boss_laser":
				modulate = Color(1.0, 0.1, 0.1) # 赤 (Boss Laser)
			"boss_missile":
				modulate = Color(0.9, 0.6, 0.1) # オレンジ (Boss Missile)


func _on_body_entered(body: Node2D) -> void:
	# 敵所有の弾で、プレイヤーにぶつかった場合
	if not is_friendly:
		if body.name == "Player" or body.has_method("take_damage"):
			body.take_damage(damage)
			recycle_bullet()


func _on_area_entered(area: Area2D) -> void:
	# 味方所有の弾で、敵にぶつかった場合
	if is_friendly:
		# ボス本体や部位、あるいはドローンなどの敵グループにぶつかった場合
		if area.is_in_group("boss") or area.is_in_group("enemy") or area.is_in_group("drones") or area.name == "BossDamageShape":
			var damage_target = area
			if not area.has_method("take_damage") and area.get_parent().has_method("take_damage"):
				damage_target = area.get_parent()
				
			if damage_target.has_method("take_damage"):
				damage_target.take_damage(damage)
			recycle_bullet()



func _process(delta: float) -> void:
	# パリィ済みの味方弾である場合、動くボスに向かって誘導（ホーミング）する
	if is_friendly:
		var main = get_node_or_null("/root/Main")
		if main:
			var boss = main.get_node_or_null("Boss")
			# ボスが有効で、かつ画面に表示されている（＝ボス戦中）場合のみボスを追尾
			if is_instance_valid(boss) and boss.visible:
				var target_dir = (boss.global_position - global_position).normalized()
				var target_velocity = target_dir * velocity.length()
				# 旋回（Lerp）処理で追尾させる
				velocity = velocity.lerp(target_velocity, delta * 10.0)
			else:
				# ボスが非アクティブ、または存在しない場合はドローンを追尾
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
						velocity = velocity.lerp(target_velocity, delta * 10.0)

	# 速度低下・停止の防止策 (ターゲットロスト時の停滞対策)
	if velocity.length() < 100.0:
		if velocity == Vector2.ZERO:
			velocity = Vector2.UP * speed
		else:
			velocity = velocity.normalized() * (speed if speed > 100.0 else 200.0)

	position += velocity * delta
	
	# 画面外チェック
	var viewport_rect = get_viewport_rect()
	if position.x < -50 or position.x > viewport_rect.size.x + 50 or \
	   position.y < -50 or position.y > viewport_rect.size.y + 50:
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
	"""方向と速度を設定"""
	velocity = direction.normalized() * (speed_override if speed_override > 0 else speed)


func convert_to_friendly() -> void:
	"""敵弾を味方弾に変換（ジャストガード成功時）"""
	if is_friendly:
		return
	is_friendly = true
	
	# 速度を反転させつつ、3.0倍に強化して敵に撃ち返す
	velocity = -velocity * 3.0
	
	# 見た目を変更（敵弾 → 味方弾の色）
	update_bullet_color()

	# パリィエフェクト発生
	if ParryParticleScene:
		var particle = ParryParticleScene.instantiate()
		particle.global_position = global_position
		get_parent().add_child(particle)
	
	# プレイヤーにパリィ成功を通知
	var main = get_node_or_null("/root/Main")
	if main:
		var manager = main.get_node_or_null("GameManager")
		if manager and manager.has_method("register_parry"):
			manager.register_parry()


func is_owned_by_player() -> bool:
	"""プレイヤー所有か判定"""
	return is_friendly
