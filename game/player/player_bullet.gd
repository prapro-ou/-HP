extends Area2D
## プレイヤー弾スクリプト
## - 前方移動
## - 画面外判定で削除
## - 敵（BossDamageShape）との衝突検知

@export var speed: float = 800.0
@export var damage: int = 10

var velocity: Vector2 = Vector2.ZERO
var bullet_type: String = "analysis"  # "analysis", "beam", "giga_laser", "missile", "hyper_missile"


func _ready() -> void:
	update_visual()
	area_entered.connect(_on_area_entered)


func update_visual() -> void:
	match bullet_type:
		"analysis":
			scale = Vector2(0.5, 0.5)
			modulate = Color.GREEN
			damage = 1
			speed = 900.0
		"beam":
			scale = Vector2(0.4, 2.2)
			modulate = Color.CYAN
			damage = 7
			speed = 1500.0
		"giga_laser":
			scale = Vector2(1.2, 4.5)
			modulate = Color.GOLD
			damage = 18
			speed = 2000.0
		"missile":
			scale = Vector2(0.8, 0.8)
			modulate = Color(0.9, 0.4, 1.0) # 明るい紫
			damage = 12
			speed = 450.0
		"hyper_missile":
			scale = Vector2(1.3, 1.3)
			modulate = Color.ORANGE
			damage = 25
			speed = 550.0
		"machine_gun":
			scale = Vector2(0.5, 0.9)
			modulate = Color(1.0, 0.8, 0.3)
			damage = 4
			speed = 1100.0
		"burst_rifle":
			scale = Vector2(0.35, 1.4)
			modulate = Color(1.0, 0.45, 0.1)
			damage = 8
			speed = 1300.0
		"charge_bolt":
			scale = Vector2(1.1, 2.5)
			modulate = Color(0.3, 0.8, 1.0)
			damage = 38
			speed = 1800.0
		"pulse":
			scale = Vector2(0.8, 0.6)
			modulate = Color(0.2, 1.0, 0.6)
			damage = 7
			speed = 950.0
		"plasma":
			scale = Vector2(1.5, 1.5)
			modulate = Color(0.6, 0.9, 0.2) # Yellow-Green
			damage = 6
			speed = 500.0
		"tackle":
			scale = Vector2(2.5, 0.6)
			modulate = Color(1.0, 0.4, 0.0) # Intense Orange
			damage = 18
			speed = 750.0
			
	if velocity == Vector2.ZERO:
		velocity = Vector2.UP * speed


func _process(delta: float) -> void:
	# ミサイルの追尾処理
	if bullet_type == "missile" or bullet_type == "hyper_missile":
		var target = find_closest_target()
		var target_velocity: Vector2
		if is_instance_valid(target):
			var target_dir = (target.global_position - global_position).normalized()
			target_velocity = target_dir * speed
		else:
			target_velocity = Vector2.UP * speed
			
		# 急激すぎない旋回
		velocity = velocity.lerp(target_velocity, delta * 6.5)
		rotation = velocity.angle() + PI/2

	position += velocity * delta
	
	# 画面外で消去
	var viewport_rect = get_viewport_rect()
	if position.y < -100 or position.y > viewport_rect.size.y + 100 or \
	   position.x < -100 or position.x > viewport_rect.size.x + 100:
		queue_free()


func find_closest_target() -> Node2D:
	var targets = get_tree().get_nodes_in_group("enemy")
	var closest: Node2D = null
	var min_dist = 999999.0
	for t in targets:
		if is_instance_valid(t):
			var dist = global_position.distance_to(t.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = t
	return closest


func _on_area_entered(area: Area2D) -> void:
	"""他のArea2Dに入った時の処理"""
	var is_boss_part = area.is_in_group("boss") or area.name == "BossDamageShape" or area.name.contains("Cannon") or area.name.contains("Pod")
	var is_enemy = area.is_in_group("enemy")
	
	if is_boss_part or is_enemy:
		# ダメージ適用先の決定
		var damage_target = area
		if not area.has_method("take_damage") and area.get_parent().has_method("take_damage"):
			damage_target = area.get_parent()
			
		if damage_target.has_method("take_damage"):
			var actual_damage = damage
			# 「解析ショット」はボス部位には1ダメージしか与えられない
			if bullet_type == "analysis" and (is_boss_part or damage_target.is_in_group("boss")):
				actual_damage = 1
			damage_target.take_damage(actual_damage)
		
		# ミサイル爆発エフェクト＆スプラッシュダメージ
		if bullet_type == "hyper_missile":
			trigger_explosion()
		elif bullet_type == "missile":
			spawn_bullet_impact_particles(Color(0.8, 0.4, 1.0))
			
		# Giga Laser, Charge Bolt, Plasma, and Tackle pierce all targets
		if bullet_type != "giga_laser" and bullet_type != "charge_bolt" and bullet_type != "plasma" and bullet_type != "tackle":
			queue_free()


func trigger_explosion() -> void:
	# 周囲へのスプラッシュダメージ
	var targets = get_tree().get_nodes_in_group("enemy")
	for t in targets:
		if is_instance_valid(t) and t != self:
			var dist = global_position.distance_to(t.global_position)
			if dist < 120.0:
				if t.has_method("take_damage"):
					t.take_damage(12)
					
	# 爆発パーティクル
	spawn_bullet_impact_particles(Color.ORANGE, 2.0)


func spawn_bullet_impact_particles(color: Color, scale_multiplier: float = 1.0) -> void:
	var ParryParticleScene = load("res://game/bullets/parry_particle.tscn")
	if ParryParticleScene:
		var particle = ParryParticleScene.instantiate()
		particle.global_position = global_position
		particle.modulate = color
		particle.scale = Vector2(scale_multiplier, scale_multiplier)
		get_parent().add_child(particle)

