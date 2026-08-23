extends Area2D
class_name PlayerGiganticOrb

## プレイヤー専用 COUNTER SYSTEM 超巨大重力プラズマ弾
## - プレイヤーよりも巨大な低速前進エネルギー弾（直径約120px）
## - 前方の全敵弾を消滅・吸収
## - ボスや敵機を貫通しながら超多段ヒット大ダメージ

var speed: float = 220.0
var damage_multiplier: float = 1.0
var duration: float = 6.0
var is_active: bool = true
var time_alive: float = 0.0

var tick_timer: float = 0.0
const DAMAGE_TICK_INTERVAL: float = 0.08
const PARRY_PARTICLE_SCENE: PackedScene = preload("res://game/bullets/parry_particle.tscn")

var hit_radius: float = 64.0


func _ready() -> void:
	z_index = 60
	z_as_relative = false
	add_to_group("player_bullets")
	add_to_group("friendly_projectiles")
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = hit_radius
	col.shape = shape
	add_child(col)
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func setup_orb(p_pos: Vector2, p_dur: float, p_mult: float) -> void:
	global_position = p_pos
	duration = p_dur
	damage_multiplier = p_mult
	is_active = true
	time_alive = 0.0
	Global.play_heavy_hit(0.7)


func _process(delta: float) -> void:
	if not is_active:
		return
		
	time_alive += delta
	position.y -= speed * delta
	
	# 周囲の敵弾を消滅・吸収
	absorb_nearby_enemy_bullets()
	
	# 多段ヒットダメージ処理
	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer = DAMAGE_TICK_INTERVAL
		deal_tick_damage()
		
	# 寿命または画面外判定
	if time_alive >= duration or global_position.y < -120.0:
		detonate_orb()
		
	queue_redraw()


func absorb_nearby_enemy_bullets() -> void:
	var main = get_node_or_null("/root/Main")
	if not main:
		return
		
	var bullets = get_tree().get_nodes_in_group("enemy_bullets")
	for b in bullets:
		if is_instance_valid(b) and "is_friendly" in b and not b.is_friendly:
			if global_position.distance_to(b.global_position) <= hit_radius + 20.0:
				HitSpark.create_spark(get_parent(), b.global_position, "normal", Color(0.3, 0.9, 1.0))
				if b.has_method("recycle_bullet"):
					b.recycle_bullet()
				elif b.has_method("queue_free"):
					b.queue_free()


func deal_tick_damage() -> void:
	var parent_node = get_parent()
	if not parent_node:
		return
		
	var base_dmg = int(95.0 * damage_multiplier)
	var targets = get_tree().get_nodes_in_group("boss") + get_tree().get_nodes_in_group("boss_turrets") + get_tree().get_nodes_in_group("enemy")
	
	var hit_count = 0
	for t in targets:
		if is_instance_valid(t) and t != self and "global_position" in t:
			if global_position.distance_to(t.global_position) <= hit_radius + 35.0:
				hit_count += 1
				var dmg = base_dmg
				if t.is_in_group("boss_turrets"):
					dmg = int(dmg * 1.5)
					
				if t.has_method("take_damage"):
					t.take_damage(dmg, global_position, true)
				elif t.has_method("take_damage_on_part"):
					t.take_damage_on_part("core", dmg, global_position, true)
					
				HitSpark.create_spark(parent_node, t.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20)), "heavy", Color(1.0, 0.85, 0.2))
				
	if hit_count > 0:
		Global.play_hit(randf_range(1.2, 1.4))


func _on_area_entered(area: Area2D) -> void:
	if not is_active:
		return
	if area.is_in_group("enemy_bullets") and "is_friendly" in area and not area.is_friendly:
		if area.has_method("recycle_bullet"):
			area.recycle_bullet()


func _on_body_entered(body: Node2D) -> void:
	pass


func detonate_orb() -> void:
	if not is_active:
		return
	is_active = false
	
	Global.play_explosion(1.3)
	if PARRY_PARTICLE_SCENE and get_parent():
		for i in range(16):
			var p = PARRY_PARTICLE_SCENE.instantiate()
			p.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			p.scale = Vector2(2.8, 2.8)
			p.modulate = Color(0.3, 0.9, 1.0)
			get_parent().add_child(p)
			
	queue_free()


func _draw() -> void:
	if not is_active:
		return
		
	var pulse = 0.5 + 0.5 * sin(time_alive * 18.0)
	var main_col = Color(0.2, 0.85, 1.0)
	var core_col = Color(1.0, 0.95, 0.6)
	
	# 1. 最外層プラズマオーラ
	draw_circle(Vector2.ZERO, hit_radius * (1.15 + pulse * 0.12), Color(main_col.r, main_col.g, main_col.b, 0.2))
	# 2. 中間高密度フレア層
	draw_circle(Vector2.ZERO, hit_radius * (0.85 + pulse * 0.08), Color(main_col.r, main_col.g, main_col.b, 0.55))
	# 3. 白熱中心コア
	draw_circle(Vector2.ZERO, hit_radius * 0.45, Color(core_col.r, core_col.g, core_col.b, 0.95))
	draw_circle(Vector2.ZERO, hit_radius * 0.25, Color(1.0, 1.0, 1.0, 1.0))
	
	# 4. 外周の回転エネルギー光輪
	draw_arc(Vector2.ZERO, hit_radius * 1.2, 0, TAU, 36, Color(1.0, 0.9, 0.3, 0.85), 3.5)
	draw_arc(Vector2.ZERO, hit_radius * 0.7, 0, TAU, 28, Color(1.0, 1.0, 1.0, 0.9), 2.0)
