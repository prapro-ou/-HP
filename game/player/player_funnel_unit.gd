extends Node2D
class_name PlayerFunnelUnit

## プレイヤー専用 サイバーファンネル端末 (COUNTER SYSTEM)
## - 自機の周囲をダイナミックにオールレンジ旋回
## - 最寄りの敵・ボスをロックオンし、赤/シアンの照準レーザーと共に高速ビーム・パルス連射を叩き込む
## - 機体カラーに応じたネオンカラーで発光

@export var funnel_index: int = 0
@export var total_funnels: int = 4

var player: Node2D = null
var duration: float = 10.0
var damage_multiplier: float = 1.0
var active_timer: float = 0.0
var fire_timer: float = 0.0

var orbit_radius: float = 90.0
var orbit_speed: float = 3.2
var current_angle: float = 0.0
var target_node: Node2D = null
var is_locked_on: bool = false
var lock_line_alpha: float = 0.0

var sprite: Sprite2D = null

const PLAYER_BULLET_SCENE: PackedScene = preload("res://game/player/player_bullet.tscn")
const FUNNEL_TEXTURE: Texture2D = preload("res://game/assets/boss/stage3/stage3_enemy4.png")


func setup_funnel(p_player: Node2D, p_index: int, p_total: int, p_duration: float, p_dmg_mult: float) -> void:
	player = p_player
	funnel_index = p_index
	total_funnels = p_total
	duration = p_duration
	damage_multiplier = p_dmg_mult
	active_timer = 0.0
	fire_timer = 0.15 + p_index * 0.12
	current_angle = (TAU / float(max(1, p_total))) * p_index
	orbit_radius = 80.0 + (p_index % 2) * 30.0
	orbit_speed = 3.0 + (p_index % 3) * 0.5


func _ready() -> void:
	z_index = 25
	
	sprite = Sprite2D.new()
	if FUNNEL_TEXTURE:
		sprite.texture = FUNNEL_TEXTURE
	sprite.scale = Vector2(0.24, 0.24)
	
	# プレイヤーカラーの適用
	var p_color_key = Global.player_color
	var p_col_data = Global.available_player_colors.get(p_color_key, {})
	var accent_col: Color = p_col_data.get("accent_color", Color(0.3, 0.9, 1.0))
	sprite.modulate = accent_col.lerp(Color.WHITE, 0.2)
	add_child(sprite)
	
	# 出現ポップアニメーション
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	active_timer += delta
	if active_timer >= duration:
		deactivate_and_free()
		return
		
	if not is_instance_valid(player):
		deactivate_and_free()
		return
		
	# 自機中心のオールレンジ公転運動
	current_angle += orbit_speed * delta
	var target_offset = Vector2(cos(current_angle) * orbit_radius, sin(current_angle) * (orbit_radius * 0.6) - 10.0)
	var target_global = player.global_position + target_offset
	global_position = global_position.lerp(target_global, delta * 15.0)
	
	# ターゲット索敵と銃口回転
	target_node = find_target()
	if is_instance_valid(target_node):
		var dir = (target_node.global_position - global_position).normalized()
		rotation = lerp_angle(rotation, dir.angle() + PI/2, delta * 16.0)
		is_locked_on = true
		lock_line_alpha = clamp(lock_line_alpha + delta * 4.0, 0.0, 0.7)
	else:
		rotation = lerp_angle(rotation, 0.0, delta * 8.0)
		is_locked_on = false
		lock_line_alpha = max(0.0, lock_line_alpha - delta * 4.0)
		
	queue_redraw()
	
	# 射撃サイクル
	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_funnel_beam()
		fire_timer = randf_range(0.18, 0.28)


func find_target() -> Node2D:
	var turrets = get_tree().get_nodes_in_group("boss_turrets")
	var valid_turrets = []
	for t in turrets:
		if is_instance_valid(t) and t.visible and ("is_alive" not in t or t.is_alive):
			valid_turrets.append(t)
	if valid_turrets.size() > 0:
		return valid_turrets.pick_random()
		
	var main = get_node_or_null("/root/Main")
	if main:
		var boss = main.get_node_or_null("Boss")
		if is_instance_valid(boss) and boss.visible:
			return boss
			
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest: Node2D = null
	var min_dist = 99999.0
	for e in enemies:
		if is_instance_valid(e) and e.visible and not e.is_in_group("boss_turrets"):
			var dist = global_position.distance_to(e.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = e
	return closest


func fire_funnel_beam() -> void:
	if not PLAYER_BULLET_SCENE:
		return
		
	var parent_node = get_node_or_null("/root/Main/PlayerBullets")
	if not parent_node:
		parent_node = get_parent()
		
	var shoot_dir = Vector2.UP
	if is_instance_valid(target_node):
		shoot_dir = (target_node.global_position - global_position).normalized()
	else:
		shoot_dir = Vector2.UP.rotated(randf_range(-0.2, 0.2))
		
	# 高速貫通ファンネルレーザー
	var b = PLAYER_BULLET_SCENE.instantiate()
	b.bullet_type = "beam"
	b.global_position = global_position + shoot_dir * 12.0
	b.speed = 2000.0
	b.velocity = shoot_dir * b.speed
	b.damage = int(28 * damage_multiplier)
	b.pierce_limit = 2
	b.modulate = sprite.modulate if sprite else Color(0.3, 0.9, 1.0)
	parent_node.add_child(b)
	
	Global.play_laser(randf_range(1.3, 1.6))
	
	# 発射時の微小パルス
	if sprite:
		sprite.scale = Vector2(0.32, 0.32)
		var t = create_tween()
		t.tween_property(sprite, "scale", Vector2(0.24, 0.24), 0.12)


func _draw() -> void:
	# ロックオン照準線
	if is_locked_on and is_instance_valid(target_node) and lock_line_alpha > 0.0:
		var line_col = Color(sprite.modulate.r, sprite.modulate.g, sprite.modulate.b, lock_line_alpha * 0.45) if sprite else Color(0.3, 0.9, 1.0, lock_line_alpha * 0.45)
		var local_target = target_node.global_position - global_position
		draw_line(Vector2.ZERO, local_target, line_col, 1.5)


func deactivate_and_free() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
