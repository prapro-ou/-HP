extends Node2D
class_name PlayerChainSweep

## プレイヤー専用 COUNTER SYSTEM 5連鎖スーパノヴァ（チェイン・エクスプロージョン）
## - プレイヤーの前方に右から左へ薙ぎ払うように5つの巨大爆発を連鎖的に発生
## - 各爆発は「ジャストガード（パリィ）」効果を持ち、範囲内の敵弾を3倍の威力で反射
## - ボスや敵機に対して極大の直接多段ダメージを与える

var damage_multiplier: float = 1.0
var duration: float = 4.0
var time_alive: float = 0.0
var explosion_index: int = 0
const TOTAL_EXPLOSIONS: int = 5
const EXPLOSION_INTERVAL: float = 0.22

var explosion_events: Array[Dictionary] = [] # { pos: Vector2, time: float, max_time: float, radius: float }
var player_ref: Node2D = null

const PARRY_PARTICLE_SCENE: PackedScene = preload("res://game/bullets/parry_particle.tscn")


func _ready() -> void:
	z_index = 50
	z_as_relative = false
	start_chain_sequence()


func setup_sweep(p_player: Node2D, p_dur: float, p_mult: float) -> void:
	player_ref = p_player
	duration = p_dur
	damage_multiplier = p_mult
	time_alive = 0.0
	explosion_index = 0
	
	Global.play_laser(0.8)
	if is_inside_tree():
		start_chain_sequence()


func start_chain_sequence() -> void:
	var tree = get_tree()
	if not tree:
		return
		
	var base_y = 480.0
	if is_instance_valid(player_ref):
		base_y = clamp(player_ref.global_position.y - 140.0, 220.0, 680.0)
		
	# 右から左へ5箇所の座標を定義 (x: 680 -> 120)
	var x_coords = [680.0, 540.0, 400.0, 260.0, 120.0]
	
	for i in range(TOTAL_EXPLOSIONS):
		var x_pos = x_coords[i]
		var spawn_pos = Vector2(x_pos, base_y + sin(i * 1.2) * 20.0)
		tree.create_timer(i * EXPLOSION_INTERVAL).timeout.connect(func():
			if is_instance_valid(self):
				trigger_single_chain_explosion(spawn_pos, i)
		)


func trigger_single_chain_explosion(pos: Vector2, _idx: int) -> void:
	var radius = 135.0
	explosion_events.append({
		"pos": pos,
		"time": 0.0,
		"max_time": 0.45,
		"radius": radius
	})
	
	Global.play_explosion(randf_range(1.1, 1.3))
	Global.play_heavy_hit(randf_range(1.1, 1.3))
	
	var parent_node = get_parent()
	if not parent_node:
		return
		
	# 1. 範囲内の敵弾を検知し、通常の3倍の威力でジャストガード反射！
	var bullets = get_tree().get_nodes_in_group("enemy_bullets")
	var reflected_count = 0
	for b in bullets:
		if is_instance_valid(b) and "is_friendly" in b and not b.is_friendly:
			if pos.distance_to(b.global_position) <= radius:
				b.is_friendly = true
				b.damage = int(b.damage * 3.0 * damage_multiplier)
				b.modulate = Color(1.0, 0.9, 0.25) # 3倍威力の黄金の反射弾
				
				# ボス方向へ超高速反射
				var target_dir = Vector2.UP
				var bosses = get_tree().get_nodes_in_group("boss")
				if bosses.size() > 0 and is_instance_valid(bosses[0]):
					target_dir = (bosses[0].global_position - b.global_position).normalized()
				b.velocity = target_dir * 950.0
				
				reflected_count += 1
				HitSpark.create_spark(parent_node, b.global_position, "heavy", Color(1.0, 0.85, 0.2))
				
	if reflected_count > 0:
		var main = get_node_or_null("/root/Main")
		if main:
			var manager = main.get_node_or_null("GameManager")
			if manager and manager.has_method("register_parry"):
				manager.register_parry()
				
	# 2. 範囲内のボス・砲台・敵機に450の直接大ダメージ
	var direct_dmg = int(450.0 * damage_multiplier)
	var targets = get_tree().get_nodes_in_group("boss") + get_tree().get_nodes_in_group("boss_turrets") + get_tree().get_nodes_in_group("enemy")
	for t in targets:
		if is_instance_valid(t) and "global_position" in t:
			if pos.distance_to(t.global_position) <= radius + 30.0:
				if t.has_method("take_damage"):
					t.take_damage(direct_dmg, pos, true)
				elif t.has_method("take_damage_on_part"):
					t.take_damage_on_part("core", direct_dmg, pos, true)
				HitSpark.create_spark(parent_node, t.global_position, "heavy", Color(1.0, 0.9, 0.3))
				
	# 3. 黄金＆シアンのパーティクル爆発
	if PARRY_PARTICLE_SCENE:
		for p_i in range(10):
			var p = PARRY_PARTICLE_SCENE.instantiate()
			p.global_position = pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			p.scale = Vector2(2.5, 2.5)
			p.modulate = Color(1.0, 0.85, 0.2) if p_i % 2 == 0 else Color(0.3, 1.0, 0.9)
			parent_node.add_child(p)
			
	queue_redraw()


func _process(delta: float) -> void:
	time_alive += delta
	
	# 爆発アニメーション更新
	var active_events: Array[Dictionary] = []
	for ev in explosion_events:
		ev["time"] += delta
		if ev["time"] < ev["max_time"]:
			active_events.append(ev)
	explosion_events = active_events
	
	if time_alive >= duration and explosion_events.size() == 0:
		queue_free()
		return
		
	queue_redraw()


func _draw() -> void:
	for ev in explosion_events:
		var t = clamp(ev["time"] / ev["max_time"], 0.0, 1.0)
		var cur_r = ev["radius"] * (0.3 + 0.7 * sqrt(t))
		var alpha = 1.0 - t
		var pos = ev["pos"] - global_position
		
		# 黄金の外郭衝撃波リング
		draw_arc(pos, cur_r, 0, TAU, 36, Color(1.0, 0.85, 0.2, alpha * 0.9), 4.0)
		# シアンの閃光核
		draw_circle(pos, cur_r * 0.6, Color(0.25, 0.95, 1.0, alpha * 0.45))
		draw_circle(pos, cur_r * 0.25, Color(1.0, 1.0, 1.0, alpha * 0.85))
