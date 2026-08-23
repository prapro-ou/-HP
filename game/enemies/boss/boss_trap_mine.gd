extends Area2D
class_name BossTrapMine

## ボス5用 フィールドトラップマイン
## - フィールドのランダムな位置に設置される
## - 踏む（接近）か10秒経過で爆発
## - ジャストガード（パリィ）で起爆・反撃可能（敵弾消滅＋大ダメージ特効ボルト射出）

var lifetime: float = 0.0
const MAX_LIFETIME: float = 10.0
var is_active: bool = true
var is_parried: bool = false
var trigger_radius: float = 38.0
var explosion_radius: float = 140.0

const PARRY_PARTICLE_SCENE: PackedScene = preload("res://game/bullets/parry_particle.tscn")


func _ready() -> void:
	z_index = 45
	z_as_relative = false
	add_to_group("boss_traps")
	add_to_group("enemy_projectiles")
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = trigger_radius
	col.shape = shape
	add_child(col)
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup_trap(pos: Vector2) -> void:
	global_position = pos
	lifetime = 0.0
	is_active = true
	is_parried = false
	Global.play_laser(1.5)


func _process(delta: float) -> void:
	if not is_active:
		return
		
	lifetime += delta
	
	# 自機との距離チェック (踏んだ時の近接起爆)
	var main = get_node_or_null("/root/Main")
	var player = main.get_node_or_null("Player") if main else null
	if is_instance_valid(player) and player.current_hp > 0:
		var dist = global_position.distance_to(player.global_position)
		if dist <= trigger_radius:
			if player.is_guarding:
				# プレイヤーがシールド展開中ならジャストガード成功
				trigger_just_guard_parry(player)
			else:
				# 踏んでしまった場合は被弾爆発
				trigger_enemy_explosion()
			return
			
	# 10秒経過による自爆
	if lifetime >= MAX_LIFETIME:
		trigger_enemy_explosion()
		return
		
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	if body.name == "Player" or body.is_in_group("player"):
		if "is_guarding" in body and body.is_guarding:
			trigger_just_guard_parry(body)
		else:
			trigger_enemy_explosion()


func _on_area_entered(area: Area2D) -> void:
	if not is_active:
		return
	if area.is_in_group("friendly_projectiles") or area.is_in_group("player_bullets"):
		trigger_just_guard_parry(null)


func trigger_just_guard_parry(player_ref: Node2D = null) -> void:
	"""ジャストガード成功時の強力なカウンター起爆"""
	if not is_active or is_parried:
		return
	is_active = false
	is_parried = true
	
	Global.play_heavy_hit(1.2)
	Global.play_explosion(1.4)
	
	var parent_node = get_parent()
	if not parent_node:
		return
		
	# 1. 周囲の敵弾を消滅
	var bullets = get_tree().get_nodes_in_group("enemy_bullets")
	for b in bullets:
		if is_instance_valid(b) and "is_friendly" in b and not b.is_friendly:
			if global_position.distance_to(b.global_position) <= explosion_radius + 40.0:
				HitSpark.create_spark(parent_node, b.global_position, "normal", Color(0.3, 1.0, 0.9))
				if b.has_method("recycle_bullet"):
					b.recycle_bullet()
				elif b.has_method("queue_free"):
					b.queue_free()
					
	# 2. ボス及び砲台へ1200の特効ダメージ
	var targets = get_tree().get_nodes_in_group("boss") + get_tree().get_nodes_in_group("boss_turrets")
	for t in targets:
		if is_instance_valid(t) and t.has_method("take_damage"):
			t.take_damage(1200, global_position, true)
		elif is_instance_valid(t) and t.has_method("take_damage_on_part"):
			t.take_damage_on_part("core", 1200, global_position, true)
			
	# 3. 8方向へ反射追尾カウンターボルトを射出
	var pool = get_node_or_null("/root/Main/BulletPool")
	if pool:
		for i in range(8):
			var bullet = pool.get_bullet("boss_laser")
			if bullet:
				bullet.global_position = global_position
				bullet.damage = 120
				bullet.is_friendly = true
				bullet.modulate = Color(0.2, 1.0, 0.9)
				var dir = Vector2.UP.rotated(i * (TAU / 8.0))
				bullet.set_direction(dir, 850.0)
				
	# 4. パリィスパーク＆爆発エフェクト
	if PARRY_PARTICLE_SCENE:
		for i in range(12):
			var p = PARRY_PARTICLE_SCENE.instantiate()
			p.global_position = global_position + Vector2(randf_range(-25, 25), randf_range(-25, 25))
			p.scale = Vector2(2.4, 2.4)
			p.modulate = Color(0.25, 0.95, 1.0)
			parent_node.add_child(p)
			
	# HUDフィードバック
	var main = get_node_or_null("/root/Main")
	if main:
		var manager = main.get_node_or_null("GameManager")
		if manager and manager.has_method("register_parry"):
			manager.register_parry()
			
	if is_instance_valid(player_ref) and player_ref.has_method("spawn_popup_message"):
		player_ref.spawn_popup_message("⚡ トラップ パリィ成功！ (1200 DMG) ⚡")
		
	queue_free()


func trigger_enemy_explosion() -> void:
	"""タイムアウトまたはプレイヤー接触時の敵性爆発"""
	if not is_active:
		return
	is_active = false
	
	Global.play_explosion(1.0)
	var parent_node = get_parent()
	
	# プレイヤーへのダメージ判定
	var main = get_node_or_null("/root/Main")
	var player = main.get_node_or_null("Player") if main else null
	if is_instance_valid(player) and player.current_hp > 0:
		if global_position.distance_to(player.global_position) <= trigger_radius + 20.0:
			if player.has_method("take_damage"):
				player.take_damage(28)
				HitSpark.create_spark(parent_node, player.global_position, "heavy", Color(1.0, 0.2, 0.2))
				
	# 8方向への破片弾放射
	var pool = get_node_or_null("/root/Main/BulletPool")
	if pool:
		for i in range(8):
			var bullet = pool.get_bullet("straight")
			if bullet:
				bullet.global_position = global_position
				bullet.damage = 18
				var dir = Vector2.DOWN.rotated(i * (TAU / 8.0))
				bullet.set_direction(dir, 260.0)
				
	if PARRY_PARTICLE_SCENE and parent_node:
		var p = PARRY_PARTICLE_SCENE.instantiate()
		p.global_position = global_position
		p.scale = Vector2(2.0, 2.0)
		p.modulate = Color(1.0, 0.35, 0.2)
		parent_node.add_child(p)
		
	queue_free()


func _draw() -> void:
	if not is_active:
		return
		
	var time_ratio = clamp(lifetime / MAX_LIFETIME, 0.0, 1.0)
	var pulse = 0.5 + 0.5 * sin(lifetime * 12.0)
	
	# トラップの危険リング＆エネルギーコア描画
	var beacon_col = Color(1.0, 0.25, 0.35, 0.85)
	var glow_col = Color(1.0, 0.1, 0.2, 0.25 + pulse * 0.15)
	
	# 1. 範囲オーラ
	draw_circle(Vector2.ZERO, trigger_radius * (1.0 + pulse * 0.15), glow_col)
	# 2. 制限時間ゲージ外周リング
	var arc_end = (1.0 - time_ratio) * TAU
	draw_arc(Vector2.ZERO, trigger_radius, 0, arc_end, 32, beacon_col, 2.5)
	# 3. 中心マインコア
	draw_circle(Vector2.ZERO, 10.0 + pulse * 2.0, Color(1.0, 0.9, 0.2))
	draw_circle(Vector2.ZERO, 5.0, Color.WHITE)
	# 4. 十字ハザードマーク
	draw_line(Vector2(-14, 0), Vector2(14, 0), Color(1.0, 0.1, 0.1, 0.9), 2.0)
	draw_line(Vector2(0, -14), Vector2(0, 14), Color(1.0, 0.1, 0.1, 0.9), 2.0)
