extends Area2D
## 隕石ギミック弾スクリプト (stage1_boss_meteor.png)
## - 画面端で反射しながら3秒間縦横無尽に飛翔
## - パリィ成功時に赤く巨大化して8割砲台/2割ボスへ超高速反射！

const METEOR_LIFETIME: float = 3.0
const PARRY_SPEED: float = 1100.0

@export var damage: int = 24
@export var speed: float = 280.0

var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 0.0
var is_friendly: bool = false
var bullet_type: String = "meteor"
var target_node: Node2D = null
var rotation_speed: float = 2.0
var bounce_count: int = 0

const PARRY_PARTICLE_SCENE: PackedScene = preload("res://game/bullets/parry_particle.tscn")


func _ready() -> void:
	z_index = 50
	z_as_relative = false
	add_to_group("enemy_projectiles")
	is_friendly = false
	rotation_speed = randf_range(-3.0, 3.0)
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# 初期スケール (プレイヤーと同等サイズ ~75px)
	scale = Vector2(0.42, 0.42)
	modulate = Color(1.0, 0.7, 0.6)


func _process(delta: float) -> void:
	rotation += rotation_speed * delta
	lifetime += delta
	
	if not is_friendly:
		# 画面端での跳ね返り（バウンド）
		var vp_rect = get_viewport_rect()
		var margin = 30.0
		
		if position.x < margin and velocity.x < 0:
			velocity.x = -velocity.x
			bounce_count += 1
		elif position.x > vp_rect.size.x - margin and velocity.x > 0:
			velocity.x = -velocity.x
			bounce_count += 1
			
		if position.y < margin and velocity.y < 0:
			velocity.y = -velocity.y
			bounce_count += 1
		elif position.y > vp_rect.size.y - margin - 80.0 and velocity.y > 0:
			# ボスエリア手前でバウンド
			velocity.y = -velocity.y
			bounce_count += 1
			
		# 3秒経過で自然爆散消滅
		if lifetime >= METEOR_LIFETIME:
			explode_and_free()
			return
	else:
		# パリィ後：ターゲットへ追尾
		if is_instance_valid(target_node):
			var target_pos = target_node.global_position
			var dir = (target_pos - global_position).normalized()
			velocity = velocity.lerp(dir * PARRY_SPEED, delta * 12.0)
		
		# パリィ後は画面外または5秒で消滅
		if lifetime >= 6.0:
			queue_free()
			return
			
	position += velocity * delta


func _on_body_entered(body: Node2D) -> void:
	if not is_friendly:
		if body.name == "Player" or body.has_method("take_damage"):
			body.take_damage(damage)
			explode_and_free()


func _on_area_entered(area: Area2D) -> void:
	if is_friendly:
		if area.is_in_group("boss") or area.is_in_group("boss_turrets") or area.is_in_group("enemy"):
			var damage_target: Node = area
			if not area.has_method("take_damage") and area.get_parent() and area.get_parent().has_method("take_damage"):
				damage_target = area.get_parent()
				
			if damage_target.has_method("take_damage"):
				damage_target.take_damage(damage * 5) # パリィ反射時は大ダメージ
			elif damage_target.has_method("take_damage_on_part"):
				damage_target.take_damage_on_part("core", damage * 5)
				
			explode_and_free()


func convert_to_friendly() -> void:
	if is_friendly:
		return
	is_friendly = true
	
	# 赤っぽく巨大化
	scale = Vector2(0.65, 0.65)
	modulate = Color(1.0, 0.2, 0.2)
	damage = 120
	
	# 反射パーティクル
	if PARRY_PARTICLE_SCENE and get_parent():
		var particle = PARRY_PARTICLE_SCENE.instantiate()
		particle.global_position = global_position
		particle.scale = Vector2(3.0, 3.0)
		particle.modulate = Color.RED
		get_parent().add_child(particle)
		
	# ターゲット振り分け：80% 砲台, 20% ボス
	var turrets = get_tree().get_nodes_in_group("boss_turrets")
	var valid_turrets = []
	for t in turrets:
		if is_instance_valid(t) and t.visible:
			valid_turrets.append(t)
			
	if valid_turrets.size() > 0 and randf() < 0.8:
		# 砲台をターゲット
		target_node = valid_turrets.pick_random()
	else:
		# ボス本体をターゲット
		var main = get_node_or_null("/root/Main")
		if main:
			target_node = main.get_node_or_null("Boss")
			
	var shoot_dir = Vector2.UP
	if is_instance_valid(target_node):
		shoot_dir = (target_node.global_position - global_position).normalized()
	velocity = shoot_dir * PARRY_SPEED


func explode_and_free() -> void:
	if PARRY_PARTICLE_SCENE and get_parent():
		for i in range(4):
			var p = PARRY_PARTICLE_SCENE.instantiate()
			p.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
			p.scale = Vector2(2.0, 2.0)
			p.modulate = Color(1.0, 0.4, 0.1) if not is_friendly else Color.RED
			get_parent().add_child(p)
	queue_free()


func set_direction(dir: Vector2, spd: float = 0.0) -> void:
	velocity = dir.normalized() * (spd if spd > 0.0 else speed)
