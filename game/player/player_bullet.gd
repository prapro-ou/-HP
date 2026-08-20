extends Area2D
## プレイヤー弾スクリプト
## - 前方移動
## - 画面外判定で削除
## - 敵（BossDamageShape）との衝突検知

@export var speed: float = 800.0
@export var damage: int = 10

var velocity: Vector2 = Vector2.ZERO
var bullet_type: String = "analysis":
	set(val):
		bullet_type = val
		update_visual()

const MAX_PLAYER_BULLETS: int = 80
const MAX_LIFE_TIME: float = 3.5

# 強化属性・変異パラメータ
var pierce_limit: int = 0
var hits_done: int = 0
var homing_strength: float = 0.0
var wave_amp: float = 0.0
var explosion_radius: float = 0.0
var explosion_dmg: int = 0


func _ready() -> void:
	z_index = 50
	z_as_relative = false
	update_visual()
	area_entered.connect(_on_area_entered)
	
	# プレイヤー弾の最大同時存在数の制限（超過時は最古弾を自然消滅）
	var parent_node = get_parent()
	if is_instance_valid(parent_node) and parent_node.name.contains("Bullet"):
		var sibling_count = parent_node.get_child_count()
		if sibling_count > MAX_PLAYER_BULLETS:
			var oldest = parent_node.get_child(0)
			if is_instance_valid(oldest) and oldest != self:
				oldest.queue_free()


func update_visual() -> void:
	match bullet_type:
		"machine_gun":
			scale = Vector2(0.6, 1.2)
			modulate = Color(1.0, 0.85, 0.3) # 鮮烈な物理イエローゴールド
			damage = 14
			speed = 1200.0
		"burst_rifle":
			scale = Vector2(0.5, 2.0)
			modulate = Color(1.0, 0.5, 0.1) # 灼熱の徹甲オレンジ
			damage = 26
			speed = 1500.0
		"pulse":
			scale = Vector2(1.3, 0.8)
			modulate = Color(0.2, 1.0, 0.6) # エメラルドプラズマ波
			damage = 18
			speed = 950.0
		"plasma":
			scale = Vector2(1.8, 1.8)
			modulate = Color(0.3, 1.0, 0.4) # 高熱グリーンプラズマ球
			damage = 22
			speed = 600.0
		"tackle":
			scale = Vector2(2.8, 1.6)
			modulate = Color(0.3, 0.75, 1.0) # 強力キネティック衝撃波
			damage = 50
			speed = 850.0
		"analysis":
			scale = Vector2(0.6, 0.6)
			modulate = Color.GREEN
			damage = 10
			speed = 950.0
		"beam":
			scale = Vector2(0.5, 2.5)
			modulate = Color.CYAN
			damage = 18
			speed = 1600.0
		"giga_laser":
			scale = Vector2(1.6, 5.5)
			modulate = Color.GOLD
			damage = 32
			speed = 2200.0
		"missile":
			scale = Vector2(0.9, 0.9)
			modulate = Color(0.9, 0.4, 1.0) # 明るい紫
			damage = 24
			speed = 500.0
		"hyper_missile":
			scale = Vector2(1.4, 1.4)
			modulate = Color.ORANGE
			damage = 45
			speed = 650.0
		"charge_bolt":
			scale = Vector2(1.2, 2.8)
			modulate = Color(0.3, 0.8, 1.0)
			damage = 45
			speed = 1800.0
		"cyclone":
			scale = Vector2(1.2, 1.2)
			modulate = Color(1.0, 0.85, 0.2) # イエロー
			damage = 22
			speed = 800.0
		"photon_laser":
			scale = Vector2(1.8, 5.5)
			modulate = Color(0.4, 0.9, 1.0) # シアンレーザー
			damage = 30
			speed = 2400.0
		"player_meteor":
			scale = Vector2(2.0, 2.0)
			modulate = Color(1.0, 0.35, 0.2) # 隕石オレンジレッド
			damage = 55
			speed = 650.0
			
	if velocity == Vector2.ZERO:
		velocity = Vector2.UP * speed


var life_timer: float = 0.0

func _process(delta: float) -> void:
	life_timer += delta
	
	# 誘導補正 (ミサイルまたは変異誘導)
	if bullet_type == "missile" or bullet_type == "hyper_missile" or homing_strength > 0.0:
		var target = find_closest_target()
		var steer_rate = 6.5 if (bullet_type == "missile" or bullet_type == "hyper_missile") else homing_strength
		if is_instance_valid(target):
			var target_dir = (target.global_position - global_position).normalized()
			var target_velocity = target_dir * speed
			velocity = velocity.lerp(target_velocity, delta * steer_rate)
		else:
			if velocity == Vector2.ZERO:
				velocity = Vector2.UP * speed
			else:
				velocity = velocity.normalized() * speed
		rotation = velocity.angle() + PI/2
		
	# 螺旋波動補正
	if bullet_type == "cyclone" or wave_amp > 0.0:
		var amp = 280.0 if bullet_type == "cyclone" else wave_amp
		var side_wave = sin(life_timer * 14.0) * amp
		position.x += side_wave * delta
		if bullet_type == "cyclone":
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
	
	# 寿命切れまたは画面外で消去
	if life_timer >= MAX_LIFE_TIME:
		queue_free()
		return
		
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
		var hit_pos = global_position
		var damage_target = area
		if not area.has_method("take_damage") and not area.has_method("take_damage_on_part") and area.get_parent() and (area.get_parent().has_method("take_damage") or area.get_parent().has_method("take_damage_on_part")):
			damage_target = area.get_parent()
			
		if damage_target.has_method("take_damage"):
			damage_target.take_damage(damage, hit_pos)
		elif damage_target.has_method("take_damage_on_part"):
			damage_target.take_damage_on_part("core", damage, hit_pos)
		
		# 爆発・衝撃波エフェクト
		if explosion_radius > 0.0:
			trigger_explosion(explosion_radius, explosion_dmg, Color.ORANGE, 0.6)
		elif bullet_type == "hyper_missile" or bullet_type == "player_meteor":
			trigger_explosion(80.0, 14, Color.ORANGE, 0.8)
		elif bullet_type == "plasma":
			trigger_explosion(50.0, 10, Color(0.3, 1.0, 0.4), 0.6)
		elif bullet_type == "tackle":
			trigger_explosion(70.0, 18, Color(0.4, 0.8, 1.0), 0.8)
		elif bullet_type == "missile":
			spawn_bullet_impact_particles(Color(0.8, 0.4, 1.0), 0.4)
		else:
			spawn_bullet_impact_particles(modulate, 0.35)
			
		hits_done += 1
		# 貫通弾以外の弾丸は消去 (レーザー、チャージボルト、プラズマ、タックル、サイクロン、フォトンレーザー、隕石、またはpierce_limit残存時は貫通)
		var is_piercing = (bullet_type == "giga_laser" or bullet_type == "charge_bolt" or bullet_type == "plasma" or bullet_type == "tackle" or bullet_type == "photon_laser" or bullet_type == "cyclone" or bullet_type == "player_meteor")
		if not is_piercing:
			if hits_done > pierce_limit:
				queue_free()


func trigger_explosion(radius: float = 80.0, splash_dmg: int = 10, fx_color: Color = Color.ORANGE, fx_scale: float = 0.6) -> void:
	# 周囲へのスプラッシュダメージ
	var targets = get_tree().get_nodes_in_group("enemy")
	for t in targets:
		if is_instance_valid(t) and t != self:
			var dist = global_position.distance_to(t.global_position)
			if dist < radius:
				if t.has_method("take_damage"):
					t.take_damage(splash_dmg)
					
	# 控えめな爆発パーティクル
	spawn_bullet_impact_particles(fx_color, fx_scale)


func spawn_bullet_impact_particles(color: Color, scale_multiplier: float = 0.4) -> void:
	var ParryParticleScene = load("res://game/bullets/parry_particle.tscn")
	if ParryParticleScene:
		var particle = ParryParticleScene.instantiate()
		particle.global_position = global_position
		particle.modulate = color
		particle.scale = Vector2(scale_multiplier, scale_multiplier)
		get_parent().add_child(particle)

