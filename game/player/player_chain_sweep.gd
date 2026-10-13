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
	add_to_group("counter_effects")
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


var sweep_positions: Array[Vector2] = []

func start_chain_sequence() -> void:
	sweep_positions.clear()
	var size := get_viewport_rect().size
	var base_y := clampf(player_ref.global_position.y - 140.0, 160.0, size.y - 160.0)
	for index in range(TOTAL_EXPLOSIONS):
		sweep_positions.append(Vector2(size.x * (0.85 - index * 0.175), base_y + sin(index * 1.2) * 20.0))

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
	for bullet in CombatTargets.projectiles(get_tree()):
		if pos.distance_to(bullet.global_position) <= radius and CombatTargets.can_parry(bullet) and bullet.has_method("convert_to_friendly"):
			bullet.convert_to_friendly()
			bullet.damage = int(bullet.damage * 3.0 * damage_multiplier)
			bullet.modulate = Color(1.0, 0.9, 0.25)
			# Counter reflections do not count as player parries or recharge COUNTER.
			bullet.add_to_group("counter_projectiles")

	# 2. 範囲内のボス・砲台・敵機に450の直接大ダメージ
	var direct_dmg = int(450.0 * damage_multiplier)
	var targets = CombatTargets.in_radius(self, pos, radius)
	for t in targets:
		if is_instance_valid(t) and "global_position" in t:
			if not t.is_queued_for_deletion():
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
	var interval := maxf((duration - 0.45) / 4.0, 0.1)
	while explosion_index < TOTAL_EXPLOSIONS and time_alive >= explosion_index * interval:
		trigger_single_chain_explosion(sweep_positions[explosion_index], explosion_index)
		explosion_index += 1
	
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
