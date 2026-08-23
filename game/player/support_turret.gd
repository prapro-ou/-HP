extends Node2D
class_name PlayerSupportTurret
## プレイヤー支援用ボスタレットポッド (COUNTER SYSTEM)
## - プレイヤーカラーで発光
## - 自機に滑らかに追従
## - 敵・ボスを自動索敵して高火力サポート射撃（ビーム・ミサイル・プラズマ）

@export var turret_slot_index: int = 0
@export var total_turrets: int = 2

var player: Node2D = null
var duration: float = 10.0
var damage_multiplier: float = 1.0
var active_timer: float = 0.0
var fire_timer: float = 0.0
var sprite: Sprite2D = null

const PLAYER_BULLET_SCENE: PackedScene = preload("res://game/player/player_bullet.tscn")
const TURRET_TEXTURE: Texture2D = preload("res://game/assets/boss/stage1/stage1_boss_turret.png")

func setup_turret(p_player: Node2D, p_index: int, p_total: int, p_duration: float, p_dmg_mult: float) -> void:
	player = p_player
	turret_slot_index = p_index
	total_turrets = p_total
	duration = p_duration
	damage_multiplier = p_dmg_mult
	active_timer = 0.0
	fire_timer = 0.2 + p_index * 0.15

func _ready() -> void:
	z_index = 20
	
	# スプライト生成
	sprite = Sprite2D.new()
	sprite.texture = TURRET_TEXTURE
	sprite.scale = Vector2(0.5, 0.5)
	
	# プレイヤーカラーの適用
	var p_color_key = Global.player_color
	var p_col_data = Global.available_player_colors.get(p_color_key, {})
	var accent_col: Color = p_col_data.get("accent_color", Color(0.2, 0.7, 1.0))
	sprite.modulate = accent_col.lerp(Color.WHITE, 0.3)
	add_child(sprite)
	
	# 展開時アニメーション（縮小から拡大ポップ）
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	active_timer += delta
	if active_timer >= duration:
		deactivate_and_free()
		return
		
	# 自機追従位置の計算
	if is_instance_valid(player):
		var target_offset = get_formation_offset()
		var target_global = player.global_position + target_offset
		global_position = global_position.lerp(target_global, 14.0 * delta)
		
		# ターゲット索敵と銃口回転
		var target = find_target()
		if is_instance_valid(target):
			var dir = (target.global_position - global_position).normalized()
			rotation = lerp_angle(rotation, dir.angle() + PI/2, 12.0 * delta)
		else:
			rotation = lerp_angle(rotation, 0.0, 8.0 * delta)
	else:
		deactivate_and_free()
		return

	# 射撃サイクル
	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_support_attack()
		fire_timer = randf_range(0.22, 0.32)

func get_formation_offset() -> Vector2:
	# 左右または周囲に配置
	var spacing = 60.0
	var offset_x = -spacing if turret_slot_index % 2 == 0 else spacing
	var offset_y = 10.0 + int(turret_slot_index / 2) * 35.0
	var hover = sin(active_timer * 6.0 + turret_slot_index * 1.5) * 6.0
	return Vector2(offset_x, offset_y + hover)

func find_target() -> Node2D:
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

func fire_support_attack() -> void:
	if not PLAYER_BULLET_SCENE:
		return
		
	var parent_node = get_node_or_null("/root/Main/PlayerBullets")
	if not parent_node:
		parent_node = get_parent()
		
	var target = find_target()
	var shoot_dir = Vector2.UP
	if is_instance_valid(target):
		shoot_dir = (target.global_position - global_position).normalized()
		
	var bullet_kind = turret_slot_index % 3
	match bullet_kind:
		0:
			# 高速ビーム斉射 (BEAM)
			for i in range(2):
				var b = PLAYER_BULLET_SCENE.instantiate()
				b.bullet_type = "beam"
				b.global_position = global_position + Vector2((i - 0.5) * 12.0, -10.0)
				b.speed = 1800.0
				b.velocity = shoot_dir * b.speed
				b.damage = int(32 * damage_multiplier)
				b.pierce_limit = 2
				b.modulate = sprite.modulate
				parent_node.add_child(b)
		1:
			# 追尾ハイパーミサイル (HOMING)
			var b = PLAYER_BULLET_SCENE.instantiate()
			b.bullet_type = "hyper_missile"
			b.global_position = global_position + Vector2(0, -12.0)
			b.speed = 750.0
			b.velocity = shoot_dir * b.speed
			b.damage = int(55 * damage_multiplier)
			b.homing_strength = 4.5
			b.explosion_radius = 65.0
			b.explosion_dmg = int(25 * damage_multiplier)
			b.modulate = sprite.modulate
			parent_node.add_child(b)
		2:
			# 巨大プラズマ球 (PLASMA)
			var b = PLAYER_BULLET_SCENE.instantiate()
			b.bullet_type = "plasma"
			b.global_position = global_position + Vector2(0, -15.0)
			b.speed = 800.0
			b.velocity = shoot_dir * b.speed
			b.damage = int(45 * damage_multiplier)
			b.explosion_radius = 80.0
			b.explosion_dmg = int(35 * damage_multiplier)
			b.modulate = sprite.modulate
			parent_node.add_child(b)
			
	# 発射時の微小パルス
	if sprite:
		sprite.scale = Vector2(0.60, 0.60)
		var t = create_tween()
		t.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.15)

func deactivate_and_free() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
