extends Area2D
## 敵弾スクリプト
## - 移動
## - 所有権管理（敵 ← → 味方）
## - ジャストガード時の変換

@export var speed: float = 200.0
@export var damage: int = 10

var velocity: Vector2 = Vector2.ZERO
var is_friendly: bool = false  # true = プレイヤー所有、false = 敵所有

var ParryParticleScene = preload("res://game/scenes/parry_particle.tscn")



func _ready() -> void:
	# 初期状態設定
	is_friendly = false
	modulate = Color.WHITE
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _on_body_entered(body: Node2D) -> void:
	# 敵所有の弾で、プレイヤーにぶつかった場合
	if not is_friendly:
		if body.name == "Player" or body.has_method("take_damage"):
			body.take_damage(damage)
			recycle_bullet()


func _on_area_entered(area: Area2D) -> void:
	# 味方所有の弾で、ボスにぶつかった場合
	if is_friendly:
		if area.name == "BossDamageShape" or area.is_in_group("boss"):
			if area.has_method("take_damage"):
				area.take_damage(damage)
			elif area.get_parent().has_method("take_damage"):
				area.get_parent().take_damage(damage)
			recycle_bullet()



func _process(delta: float) -> void:
	# パリィ済みの味方弾である場合、動くボスに向かって誘導（ホーミング）する
	if is_friendly:
		var main = get_node_or_null("/root/Main")
		if main:
			var boss = main.get_node_or_null("Boss")
			if is_instance_valid(boss):
				# ボスへの方向と、現在の速度の強さを維持した目標速度を計算
				var target_dir = (boss.global_position - global_position).normalized()
				var target_velocity = target_dir * velocity.length()
				# 旋回（Lerp）処理でカーブを描きながら追尾させる（8.0 は旋回力）
				velocity = velocity.lerp(target_velocity, delta * 8.0)

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
	modulate = Color.CYAN  # 青で味方弾を示す

	
	# パリィエフェクト発生
	if ParryParticleScene:
		var particle = ParryParticleScene.instantiate()
		particle.global_position = global_position
		get_parent().add_child(particle)
	
	# GameManager経由でパリィ登録
	var main = get_node_or_null("/root/Main")
	if main:
		var manager = main.get_node_or_null("GameManager")
		if manager and manager.has_method("register_parry"):
			manager.register_parry()




func is_owned_by_player() -> bool:
	"""プレイヤー所有か判定"""
	return is_friendly
