extends Area2D
## 雑魚敵（ドローン）スクリプト
## - 出現後、一定高度まで下降して左右にホバリング
## - タイプ（beam / missile）に応じた攻撃パターン
## - 撃破時に対応する解析度をアップ

@export var drone_type: String = "beam"  # "beam" または "missile"
@export var max_hp: int = 12

var current_hp: int
var target_y: float = 200.0
var speed: float = 150.0
var shoot_interval: float = 2.0
var time_since_last_shot: float = 0.0
var move_direction: float = 1.0
var bullet_pool: Node2D
var player: CharacterBody2D


func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemy")
	add_to_group("drones")
	
	# タイプごとにカラーリングを変更
	if drone_type == "beam":
		modulate = Color(1.0, 0.5, 0.5)  # 赤みのあるドローン
		shoot_interval = 1.8
	else:
		modulate = Color(0.8, 0.4, 1.0)  # 紫みのあるドローン
		shoot_interval = 2.4
		
	bullet_pool = get_node_or_null("/root/Main/BulletPool")
	player = get_node_or_null("/root/Main/Player")
	
	# 出現位置と高さをランダム化
	target_y = randf_range(100.0, 250.0)
	time_since_last_shot = randf_range(0.0, 1.2)  # 最初の一発をばらけさせる
	move_direction = 1.0 if randf() > 0.5 else -1.0


func _process(delta: float) -> void:
	# 登場時は上から下へ
	if position.y < target_y:
		position.y += speed * delta
	else:
		# 目標高度に達したら、画面端で折り返しながら左右移動
		position.x += speed * 0.4 * move_direction * delta
		var viewport_w = get_viewport_rect().size.x
		if position.x < 60:
			position.x = 60
			move_direction = 1.0
		elif position.x > viewport_w - 60:
			position.x = viewport_w - 60
			move_direction = -1.0
			
	# 射撃
	time_since_last_shot += delta
	if time_since_last_shot >= shoot_interval:
		shoot()
		time_since_last_shot = 0.0


func shoot() -> void:
	if not is_instance_valid(bullet_pool):
		return
		
	if drone_type == "beam":
		# Beam Drone: 直線弾
		var dir = Vector2.DOWN
		var bullet = bullet_pool.get_bullet("beam")
		if bullet:
			bullet.global_position = global_position + Vector2(0, 20)
			bullet.set_direction(dir, 320.0)
	elif drone_type == "missile":
		# Missile Drone: プレイヤー方向への誘導弾
		var dir = Vector2.DOWN
		if is_instance_valid(player):
			dir = (player.global_position - global_position).normalized()
		var bullet = bullet_pool.get_bullet("missile")
		if bullet:
			bullet.global_position = global_position + Vector2(0, 20)
			bullet.set_direction(dir, 160.0)


func take_damage(amount: int) -> void:
	current_hp -= amount
	
	# スコア加算とダメージポップアップ
	var main = get_node_or_null("/root/Main")
	if main:
		var manager = main.get_node_or_null("GameManager")
		if manager and manager.has_method("add_damage_score"):
			manager.add_damage_score(amount)
		var ui_node = main.get_node_or_null("UI")
		if ui_node and ui_node.has_method("spawn_damage_popup"):
			ui_node.spawn_damage_popup(global_position, amount)
			
	if current_hp <= 0:
		explode()


func explode() -> void:
	# プレイヤーの解析度を進める（撃破ボーナス: +15%）
	if is_instance_valid(player) and player.has_method("advance_analysis"):
		player.advance_analysis(drone_type, 15)
		
	# 爆破エフェクト発生
	var ParryParticleScene = load("res://game/scenes/parry_particle.tscn")
	if ParryParticleScene:
		var particle = ParryParticleScene.instantiate()
		particle.global_position = global_position
		particle.modulate = modulate
		get_parent().add_child(particle)
		
	# GameManager に撃破を通知
	var main = get_node_or_null("/root/Main")
	if main:
		var manager = main.get_node_or_null("GameManager")
		if manager and manager.has_method("on_drone_destroyed"):
			manager.on_drone_destroyed(self)
			
	queue_free()
