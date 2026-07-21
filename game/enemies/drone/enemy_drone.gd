extends BaseEnemy
## 雑魚敵（ドローン）スクリプト - BaseEnemyを継承
## - 出現後、一定高度まで下降して左右にホバリング
## - タイプ（beam / missile）に応じた攻撃パターン
## - 撃破時に対応する解析度をアップ

@export var drone_type: String = "straight"  # "charge", "straight", "irregular", "laser", "wave", "beam", "missile"

var target_y: float = 200.0
var speed: float = 160.0
var shoot_interval: float = 1.5
var time_since_last_shot: float = 0.0
var move_direction: float = 1.0
var bullet_pool: Node2D
var player: CharacterBody2D
var is_charging: bool = false
var charge_timer: float = 0.0


func _ready_enemy() -> void:
	add_to_group("drones")
	
	# 個体強化：HPを90に引き上げてパリィと解析の歯ごたえをアップ
	max_hp = 90
	current_hp = max_hp
	
	# 射撃スタイルごとのビジュアルとパラメータ設定（弾速や間隔をマイルドにしパリィしやすく）
	match drone_type:
		"charge":
			modulate = Color(1.0, 0.3, 0.2)  # 鮮やかな赤
			shoot_interval = 2.8
		"straight":
			modulate = Color(0.4, 0.7, 1.0)  # 青
			shoot_interval = 2.0
		"irregular":
			modulate = Color(0.9, 0.3, 0.9)  # マゼンタ
			shoot_interval = 2.2
		"laser":
			modulate = Color(1.0, 0.8, 0.2)  # アンバーイエロー
			shoot_interval = 2.5
		"wave":
			modulate = Color(0.3, 1.0, 0.5)  # エメラルドグリーン
			shoot_interval = 2.2
		"beam":
			modulate = Color(1.0, 0.5, 0.5)  # 赤みのあるドローン
			shoot_interval = 2.0
		"missile", _:
			modulate = Color(0.8, 0.4, 1.0)  # 紫
			shoot_interval = 2.4
		
	bullet_pool = get_node_or_null("/root/Main/BulletPool")
	player = get_node_or_null("/root/Main/Player")
	
	target_y = randf_range(100.0, 260.0)
	time_since_last_shot = randf_range(0.0, 0.8)
	move_direction = 1.0 if randf() > 0.5 else -1.0


func _process(delta: float) -> void:
	# 登場・ホバリング処理
	if position.y < target_y:
		position.y += speed * delta
	else:
		position.x += speed * 0.4 * move_direction * delta
		var viewport_w = get_viewport_rect().size.x
		if position.x < 60:
			position.x = 60
			move_direction = 1.0
		elif position.x > viewport_w - 60:
			position.x = viewport_w - 60
			move_direction = -1.0
			
	# チャージ動作中の演出
	if is_charging:
		charge_timer -= delta
		modulate.a = 0.5 + 0.5 * sin(charge_timer * 30.0)
		if charge_timer <= 0.0:
			is_charging = false
			modulate.a = 1.0
			fire_charged_shot()
		return
		
	# 射撃タイマー
	time_since_last_shot += delta
	if time_since_last_shot >= shoot_interval:
		shoot()
		time_since_last_shot = 0.0


func shoot() -> void:
	if not is_instance_valid(bullet_pool):
		return
		
	match drone_type:
		"charge":
			# チャージ予告動作
			is_charging = true
			charge_timer = 0.6
		"straight", "beam":
			# まっすぐ（直進弾幕）
			var dir = Vector2.DOWN
			var bullet = bullet_pool.get_bullet("beam")
			if bullet:
				bullet.global_position = global_position + Vector2(0, 20)
				bullet.set_direction(dir, 220.0) # パリィしやすい速度に調整
		"irregular":
			# 不規則（角度を変える弾）
			var base_dir = (player.global_position - global_position).normalized() if is_instance_valid(player) else Vector2.DOWN
			var angle_offset = randf_range(-0.4, 0.4)
			var dir = base_dir.rotated(angle_offset)
			var bullet = bullet_pool.get_bullet("missile")
			if bullet:
				bullet.global_position = global_position + Vector2(0, 20)
				bullet.set_direction(dir, 180.0)
		"laser":
			# 3方向扇状展開
			var center_dir = Vector2.DOWN
			var angles = [-0.3, 0.0, 0.3]
			for a in angles:
				var bullet = bullet_pool.get_bullet("boss_laser")
				if bullet:
					bullet.global_position = global_position + Vector2(0, 20)
					bullet.set_direction(center_dir.rotated(a), 200.0)
		"wave":
			# 拡散・波状弾幕（幅広5方向）
			var angles = [-0.4, -0.2, 0.0, 0.2, 0.4]
			for a in angles:
				var bullet = bullet_pool.get_bullet("beam")
				if bullet:
					bullet.global_position = global_position + Vector2(0, 20)
					bullet.set_direction(Vector2.DOWN.rotated(a), 180.0)
		"missile", _:
			var dir = Vector2.DOWN
			if is_instance_valid(player):
				dir = (player.global_position - global_position).normalized()
			var bullet = bullet_pool.get_bullet("missile")
			if bullet:
				bullet.global_position = global_position + Vector2(0, 20)
				bullet.set_direction(dir, 160.0)


func fire_charged_shot() -> void:
	if not is_instance_valid(bullet_pool):
		return
	var dir = Vector2.DOWN
	if is_instance_valid(player):
		dir = (player.global_position - global_position).normalized()
	var bullet = bullet_pool.get_bullet("boss_laser")
	if bullet:
		bullet.global_position = global_position + Vector2(0, 25)
		bullet.damage = 25 # チャージ弾は高威量
		bullet.set_direction(dir, 550.0) # 超高速弾発射


## 被撃破時の拡張処理
func die() -> void:
	# プレイヤーの解析度を進める（撃破ボーナス: +15%）
	if is_instance_valid(player) and player.has_method("advance_analysis"):
		player.advance_analysis(drone_type, 15)
		
	# GameManager に撃破を通知
	var main = get_node_or_null("/root/Main")
	if main:
		var manager = main.get_node_or_null("GameManager")
		if manager and manager.has_method("on_drone_destroyed"):
			manager.on_drone_destroyed(self)
			
	# ベースクラスの共通処理（爆発・ノード削除）を呼ぶ
	super.die()
