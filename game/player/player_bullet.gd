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
		"cyclone":
			scale = Vector2(1.1, 1.1)
			modulate = Color(1.0, 0.85, 0.2) # イエロー
			damage = 14
			speed = 750.0
		"photon_laser":
			scale = Vector2(1.6, 5.0)
			modulate = Color(0.4, 0.9, 1.0) # シアンレーザー
			damage = 22
			speed = 2200.0
		"player_meteor":
			scale = Vector2(1.8, 1.8)
			modulate = Color(1.0, 0.35, 0.2) # 隕石オレンジレッド
			damage = 35
			speed = 600.0
			
	if velocity == Vector2.ZERO:
		velocity = Vector2.UP * speed


var life_timer: float = 0.0

func _process(delta: float) -> void:
	life_timer += delta
	# ミサイルの追尾処理
	if bullet_type == "missile" or bullet_type == "hyper_missile":
		var target = find_closest_target()
		if is_instance_valid(target):
			var target_dir = (target.global_position - global_position).normalized()
			var target_velocity = target_dir * speed
			velocity = velocity.lerp(target_velocity, delta * 6.5)
		else:
			if velocity == Vector2.ZERO:
				velocity = Vector2.UP * speed
			else:
				velocity = velocity.normalized() * speed
		rotation = velocity.angle() + PI/2
		
	elif bullet_type == "cyclone":
		# 螺旋スピン軌道
		var side_wave = sin(life_timer * 14.0) * 280.0
		position.x += side_wave * delta
		rotation += delta * 12.0
		
	elif bullet_type == "player_meteor":
		rotation += delta * 4.0
		var vp_rect = get_viewport_rect()
		if position.x < 30.0:
			position.x = 30.0
			velocity.x = abs(velocity.x)
		elif position.x > vp_rect.size.x - 30.0:
			position.x = vp_rect.size.x - 30.0
			velocity.x = -abs(velocity.x)

	position += velocity * delta
	
	# 画面外で消去
	var viewport_rect = get_viewport_rect()
	if position.y < -120 or position.y > viewport_rect.size.y + 120 or \
	   position.x < -120 or position.x > viewport_rect.size.x + 120:
		queue_free()


func find_closest_target() -> Node2D:
	var targets = get_tree().get_nodes_in_group("enemy")
	var closest: Node2D = null
	var min_dist = 999999.0
	for t in targets:
		if is_instance_valid(t) and t.visible:
			var dist = global_position.distance_to(t.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = t
	return closest


func _on_area_entered(area: Area2D) -> void:
	"""他のArea2Dに入った時の処理"""
	var is_boss_part = area.is_in_group("boss") or area.is_in_group("boss_turrets") or area.name == "BossDamageShape" or area.name.contains("Cannon") or area.name.contains("Pod") or area.name == "Core"
	var is_enemy = area.is_in_group("enemy") or area.is_in_group("drones")
	
	if is_boss_part or is_enemy:
		var damage_target = area
		if not area.has_method("take_damage") and area.get_parent() and area.get_parent().has_method("take_damage"):
			damage_target = area.get_parent()
			
		if damage_target.has_method("take_damage"):
			damage_target.take_damage(damage)
		elif damage_target.has_method("take_damage_on_part"):
			damage_target.take_damage_on_part("core", damage)
		
		# 爆発エフェクト
		if bullet_type == "hyper_missile" or bullet_type == "player_meteor":
			trigger_explosion()
		elif bullet_type == "missile":
			spawn_bullet_impact_particles(Color(0.8, 0.4, 1.0))
			
		# 貫通弾以外の弾丸は消去 (レーザー、チャージボルト、プラズマ、タクル、サイクロン、フォトンレーザー、隕石は貫通)
		var is_piercing = (bullet_type == "giga_laser" or bullet_type == "charge_bolt" or bullet_type == "plasma" or bullet_type == "tackle" or bullet_type == "photon_laser" or bullet_type == "cyclone" or bullet_type == "player_meteor")
		if not is_piercing:
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

