extends Area2D
class_name BossFunnelTurret

## ステージ3ボス専用 自律遠隔ファンネル砲台
## - 15秒毎に画面上部から出現
## - プレイヤーの側面または背後に回り込み、ロックオン予告線の後にビーム連射を放つ
## - 体力はジャストガード3回分程度で素早く撃破可能

enum FunnelState {
	INGRESS,       # 画面上部から飛来・接近
	FLANKING,      # プレイヤーの横・背後へ回り込み移動
	LOCKON_CHARGE, # レーザー照準・チャージ予告 (1.0秒)
	BEAM_FIRE,     # ビーム斉射
	REPOSITION     # 次の位置へ離脱・再配置
}

const PARRY_PARTICLE_SCENE: PackedScene = preload("res://game/bullets/parry_particle.tscn")
const FUNNEL_TEXTURE: Texture2D = preload("res://game/assets/boss/stage3/stage3_enemy4.png")

@export var max_hp: int = 240
var current_hp: int = 240
var is_alive: bool = true

var state: FunnelState = FunnelState.INGRESS
var state_timer: float = 0.0
var flank_side: int = 1 # 1: 右側, -1: 左側, 0: 背後
var target_offset: Vector2 = Vector2.ZERO
var hover_angle: float = 0.0

# ビーム予告線
var warning_alpha: float = 0.0
var aim_dir: Vector2 = Vector2.DOWN

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("boss_turrets")
	add_to_group("boss")
	add_to_group("enemy")
	
	max_hp = int(240 * Global.get_enemy_hp_multiplier())
	current_hp = max_hp
	is_alive = true
	
	if sprite:
		if FUNNEL_TEXTURE:
			sprite.texture = FUNNEL_TEXTURE
		sprite.scale = Vector2(0.32, 0.32)
		sprite.modulate = Color(1.2, 0.8, 1.4)
		
	# ランダムな回り込み位置の選定
	var rand_choice = randi() % 3
	match rand_choice:
		0: flank_side = -1 # 左側面
		1: flank_side = 1  # 右側面
		2: flank_side = 0  # 背後 (下側)
		
	pick_new_flank_offset()
	state = FunnelState.INGRESS
	state_timer = 0.0
	hover_angle = randf_range(0.0, TAU)
	
	spawn_warning_text("⚠️ FUNNEL DEPLOYED ⚠️")


func pick_new_flank_offset() -> void:
	if flank_side == 0:
		# 背後回り込み (プレイヤーの下側+100px)
		target_offset = Vector2(randf_range(-120.0, 120.0), 120.0)
	elif flank_side == 1:
		# 右側面
		target_offset = Vector2(randf_range(160.0, 220.0), randf_range(-60.0, 60.0))
	else:
		# 左側面
		target_offset = Vector2(randf_range(-220.0, -160.0), randf_range(-60.0, 60.0))


func _process(delta: float) -> void:
	if not is_alive:
		return
		
	state_timer += delta
	hover_angle += delta * 4.0
	
	var player = get_node_or_null("/root/Main/Player")
	var target_player_pos = player.global_position if is_instance_valid(player) else Vector2(400, 800)
	
	match state:
		FunnelState.INGRESS:
			# 画面上部から急速接近
			var dest = target_player_pos + target_offset
			global_position = global_position.lerp(dest, delta * 3.5)
			
			# プレイヤーの方へ機首を向ける
			var to_player = (target_player_pos - global_position).normalized()
			rotation = lerp_angle(rotation, to_player.angle() + PI/2, delta * 8.0)
			
			if state_timer >= 1.6 or global_position.distance_to(dest) < 60.0:
				state = FunnelState.FLANKING
				state_timer = 0.0
				
		FunnelState.FLANKING:
			# プレイヤーの周囲を滑らかに旋回・維持
			var dest = target_player_pos + target_offset + Vector2(cos(hover_angle) * 15.0, sin(hover_angle * 1.5) * 10.0)
			global_position = global_position.lerp(dest, delta * 5.0)
			
			var to_player = (target_player_pos - global_position).normalized()
			rotation = lerp_angle(rotation, to_player.angle() + PI/2, delta * 10.0)
			
			if state_timer >= 1.2:
				state = FunnelState.LOCKON_CHARGE
				state_timer = 0.0
				Global.play_laser(1.4)
				
		FunnelState.LOCKON_CHARGE:
			# 照準固定 & 赤色レーザー予告線の表示 (1.0秒)
			var dest = target_player_pos + target_offset
			global_position = global_position.lerp(dest, delta * 3.0)
			
			aim_dir = (target_player_pos - global_position).normalized()
			rotation = lerp_angle(rotation, aim_dir.angle() + PI/2, delta * 12.0)
			
			warning_alpha = clamp(state_timer / 1.0, 0.2, 1.0)
			queue_redraw()
			
			if state_timer >= 1.0:
				warning_alpha = 0.0
				queue_redraw()
				state = FunnelState.BEAM_FIRE
				state_timer = 0.0
				execute_beam_burst(aim_dir)
				
		FunnelState.BEAM_FIRE:
			if state_timer >= 0.8:
				# 射撃完了後、次の位置へ離脱・再配置
				flank_side = -flank_side if flank_side != 0 else (1 if randf() < 0.5 else -1)
				pick_new_flank_offset()
				state = FunnelState.REPOSITION
				state_timer = 0.0
				
		FunnelState.REPOSITION:
			var dest = target_player_pos + target_offset
			global_position = global_position.lerp(dest, delta * 4.0)
			var to_player = (target_player_pos - global_position).normalized()
			rotation = lerp_angle(rotation, to_player.angle() + PI/2, delta * 8.0)
			
			if state_timer >= 1.8:
				state = FunnelState.FLANKING
				state_timer = 0.0


func execute_beam_burst(dir: Vector2) -> void:
	var main = get_node_or_null("/root/Main")
	var pool = main.get_node_or_null("BulletPool") if main else null
	if not pool:
		return
		
	# 4連速射ビーム攻撃
	var count = 4
	for i in range(count):
		get_tree().create_timer(i * 0.09).timeout.connect(func():
			if is_instance_valid(self) and is_alive and is_instance_valid(pool):
				var bullet = pool.get_bullet("boss_laser")
				if bullet:
					bullet.global_position = global_position + dir * 18.0
					bullet.damage = 18
					bullet.set_direction(dir, 680.0)
					Global.play_laser(randf_range(1.2, 1.4))
		)


func _draw() -> void:
	# レーザー予告照準線
	if warning_alpha > 0.0:
		var line_color = Color(1.0, 0.15, 0.15, warning_alpha * 0.9)
		var glow_color = Color(1.0, 0.4, 0.4, warning_alpha * 0.3)
		var end_pos = aim_dir.rotated(-rotation) * 900.0
		draw_line(Vector2.ZERO, end_pos, line_color, 2.5)
		draw_line(Vector2.ZERO, end_pos, glow_color, 7.0)
		
	# ミニHPバー
	if is_alive and max_hp > 0:
		var bar_w = 48.0
		var bar_h = 4.0
		var bar_pos = Vector2(-bar_w / 2.0, -32.0)
		var hp_ratio = clamp(float(current_hp) / float(max_hp), 0.0, 1.0)
		draw_rect(Rect2(bar_pos - Vector2(1, 1), Vector2(bar_w + 2, bar_h + 2)), Color(0.05, 0.08, 0.12, 0.85))
		draw_rect(Rect2(bar_pos, Vector2(bar_w * hp_ratio, bar_h)), Color(0.9, 0.3, 1.0))


func take_damage(amount: int, hit_pos: Vector2 = Vector2.ZERO, is_critical: bool = false) -> void:
	if not is_alive:
		return
		
	var actual_hit_pos = hit_pos if hit_pos != Vector2.ZERO else global_position
	var final_damage = amount
	
	if is_critical:
		# ジャストガード反射弾は特効大ダメージ（3回分の反射で素早く撃破可能）
		final_damage = int(amount * 2.8)
		Global.play_heavy_hit(randf_range(1.1, 1.3))
		HitSpark.create_spark(get_parent(), actual_hit_pos, "heavy", Color(1.0, 0.9, 0.2))
	else:
		final_damage = max(1, int(amount * 0.8))
		Global.play_hit(randf_range(1.0, 1.2))
		HitSpark.create_spark(get_parent(), actual_hit_pos, "normal", Color(1.0, 0.85, 0.3))
		
	current_hp -= final_damage
	
	if sprite:
		sprite.modulate = Color(3.0, 3.0, 3.0)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1.2, 0.8, 1.4), 0.06)
		
	queue_redraw()
	
	var main = get_node_or_null("/root/Main")
	if main:
		var ui_node = main.get_node_or_null("UI")
		if ui_node and ui_node.has_method("spawn_damage_popup"):
			ui_node.spawn_damage_popup(actual_hit_pos, final_damage, false, is_critical)
			
	if current_hp <= 0:
		current_hp = 0
		destroy_funnel()


func destroy_funnel() -> void:
	is_alive = false
	remove_from_group("boss_turrets")
	
	Global.play_explosion(1.2)
	
	if PARRY_PARTICLE_SCENE and get_parent():
		for i in range(8):
			var p = PARRY_PARTICLE_SCENE.instantiate()
			p.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
			p.scale = Vector2(2.2, 2.2)
			p.modulate = Color(0.9, 0.4, 1.0)
			get_parent().add_child(p)
			
	Global.tech_points += 2
	
	var main = get_node_or_null("/root/Main")
	if main:
		var player = main.get_node_or_null("Player")
		if is_instance_valid(player):
			if player.has_method("heal"):
				player.heal(40)
			if player.has_method("spawn_popup_message"):
				player.spawn_popup_message("ファンネル撃破！ +2 TP / +40 HP修復")
				
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


func spawn_warning_text(text: String) -> void:
	var label = Label.new()
	label.text = text
	var label_settings = LabelSettings.new()
	label_settings.font_size = 15
	label_settings.font_color = Color(1.0, 0.4, 0.9)
	label_settings.outline_size = 4
	label_settings.outline_color = Color.BLACK
	label.label_settings = label_settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.global_position = global_position + Vector2(-100, -35)
	label.custom_minimum_size = Vector2(200, 20)
	get_parent().add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "global_position:y", label.global_position.y - 25.0, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(label.queue_free)
