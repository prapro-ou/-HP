extends CharacterBody2D
## プレイヤー機体スクリプト
## - 移動・ガード・攻撃・各種解析変異およびフルバースト制御

# --- 基本パラメータ ---
@export var max_hp: int = 100
@export var move_speed: float = 300.0
@export var parry_window_radius: float = 65.0  # パリィ判定範囲
@export var fire_rate: float = 0.2            # 射撃間隔
@export var parry_active_time: float = 0.25  # ガード持続時間
@export var parry_cooldown: float = 2.0      # クールダウン時間

# 定数：武器タイプ定義
const WEAPON_MACHINE_GUN = "machine_gun"
const WEAPON_BURST_RIFLE = "burst_rifle"
const WEAPON_CHARGE_RIFLE = "charge_rifle"
const WEAPON_PULSE_GUN = "pulse_gun"
const WEAPON_PLASMA_EMITTER = "plasma_emitter"
const WEAPON_KINETIC_TACKLE = "kinetic_tackle"

# 定数：シールドタイプ
const SHIELD_COUNTER = "counter"
const SHIELD_GAUGE = "gauge"
const SHIELD_POWER = "power"

# 定数：解析パターンキー
const PATTERN_RAPID = "rapid"
const PATTERN_SPREAD = "spread"
const PATTERN_PIERCE = "pierce"
const PATTERN_HOMING = "homing"

# 定数：カラー定義
const COLOR_SHIELD_COUNTER = Color(0.8, 0.3, 1.0)
const COLOR_SHIELD_GAUGE = Color(0.1, 0.9, 0.5)
const COLOR_SHIELD_POWER = Color(1.0, 0.5, 0.0)
const COLOR_OVERHEAT = Color(1.0, 0.3, 0.3, 1.0)

# 定数：弾速・ダメージ
const ANALYSIS_BULLET_SPEED_NORMAL: float = 900.0
const ANALYSIS_BULLET_SPEED_RAPID: float = 1400.0
const SUB_MISSILE_SPEED: float = 450.0
const GIGA_LASER_SPEED: float = 2500.0
const HYPER_MISSILE_SPEED: float = 800.0

var current_hp: int = 100
var last_fire_time: float = 0.0
var enemy_bullets: Array = []

var active_timer: float = 0.0
var cooldown_timer: float = 0.0
var is_guarding: bool = false
var space_was_pressed: bool = false

var is_attack_unlocked: bool = false
var power_shield_damage_buff: float = 0.0

var parry_ring_radius: float = 0.0
var parry_ring_alpha: float = 0.0
var parried_in_current_frame: bool = false
var is_full_burst: bool = false

# --- シールド・オーバーヒートシステム ---
@export var max_shield_heat: float = 100.0
@export var heat_per_use: float = 34.0
@export var heat_recovery_rate: float = 28.0
@export var overheat_cooldown: float = 3.5

var shield_heat: float = 0.0
var overheat_timer: float = 0.0
var is_overheated: bool = false

# --- 攻撃パターン解析＆自機兵装反映システム ---
var analysis_patterns: Dictionary = {
	PATTERN_RAPID:  { "progress": 0.0, "analyzed": false, "name": "連射強化", "desc": "発射速度UP＆弾速1.5倍" },
	PATTERN_SPREAD: { "progress": 0.0, "analyzed": false, "name": "拡散射撃", "desc": "3-WAY 扇状拡散発射" },
	PATTERN_PIERCE: { "progress": 0.0, "analyzed": false, "name": "貫通重弾", "desc": "敵貫通＆威力+50%" },
	PATTERN_HOMING: { "progress": 0.0, "analyzed": false, "name": "追尾ミサイル", "desc": "誘導サブミサイル自動追射" }
}

var trait_rapid_unlocked: bool = false
var trait_spread_unlocked: bool = false
var trait_pierce_unlocked: bool = false
var trait_homing_unlocked: bool = false

# 旧互換変数
var weapons: Dictionary = {
	"beam": { "analyzed": false, "progress": 0, "level": 1 },
	"missile": { "analyzed": false, "progress": 0, "level": 1 }
}
var current_weapon: String = "none"
var toggle_key_pressed: bool = false

const PLAYER_BULLET_SCENE: PackedScene = preload("res://game/player/player_bullet.tscn")


func _ready() -> void:
	apply_appearance()
	reset_state()


func apply_appearance() -> void:
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		var tex_path = Global.get_player_texture_path()
		if ResourceLoader.exists(tex_path):
			sprite.texture = load(tex_path)
		sprite.scale = Vector2(1.5, 1.5)


func reset_state() -> void:
	apply_appearance()
	var hp_lvl = Global.upgrade_levels.get("hp", 0)
	max_hp = 100 + 10 * hp_lvl
	current_hp = max_hp
	
	var parry_lvl = Global.upgrade_levels.get("parry_window", 0)
	parry_window_radius = 65.0 + 5.0 * parry_lvl
	
	is_attack_unlocked = false
	power_shield_damage_buff = 0.0
	is_full_burst = false
	is_guarding = false
	active_timer = 0.0
	cooldown_timer = 0.0
	parry_ring_radius = 0.0
	parry_ring_alpha = 0.0
	
	shield_heat = 0.0
	overheat_timer = 0.0
	is_overheated = false
	
	trait_rapid_unlocked = false
	trait_spread_unlocked = false
	trait_pierce_unlocked = false
	trait_homing_unlocked = false
	
	for key in analysis_patterns.keys():
		analysis_patterns[key]["progress"] = 0.0
		analysis_patterns[key]["analyzed"] = false
	
	current_weapon = "none"
	if "beam" in weapons:
		weapons["beam"]["analyzed"] = false
		weapons["beam"]["progress"] = 0
	if "missile" in weapons:
		weapons["missile"]["analyzed"] = false
		weapons["missile"]["progress"] = 0
	
	apply_equipped_weapon_settings()


func apply_equipped_weapon_settings() -> void:
	var eq_w = Global.equipped_weapon
	match eq_w:
		WEAPON_MACHINE_GUN:
			fire_rate = 0.28
		WEAPON_BURST_RIFLE:
			fire_rate = 0.55
		WEAPON_CHARGE_RIFLE:
			fire_rate = 1.35
		WEAPON_PULSE_GUN:
			fire_rate = 0.35
		WEAPON_PLASMA_EMITTER:
			fire_rate = 0.45
		WEAPON_KINETIC_TACKLE:
			fire_rate = 0.85
		_:
			fire_rate = 0.35
			
	if trait_rapid_unlocked:
		fire_rate *= 0.55


func _process(delta: float) -> void:
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_axis("ui_left", "ui_right")
	input_vector.y = Input.get_axis("ui_up", "ui_down")
	
	velocity = input_vector.normalized() * move_speed
	move_and_slide()
	
	var viewport_size = get_viewport_rect().size
	position.x = clamp(position.x, 20.0, viewport_size.x - 20.0)
	position.y = clamp(position.y, 20.0, viewport_size.y - 20.0)
	
	var is_toggle_pressed = Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_C)
	if is_toggle_pressed:
		if not toggle_key_pressed:
			toggle_key_pressed = true
			toggle_weapon()
	else:
		toggle_key_pressed = false
	
	if is_attack_unlocked:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_fire_time > fire_rate:
			fire()
			last_fire_time = current_time
	
	if active_timer > 0.0:
		active_timer -= delta
		if active_timer <= 0.0:
			is_guarding = false
			
	if is_overheated:
		overheat_timer -= delta
		shield_heat = (overheat_timer / overheat_cooldown) * max_shield_heat
		if overheat_timer <= 0.0:
			overheat_timer = 0.0
			shield_heat = 0.0
			is_overheated = false
			spawn_popup_message("⚡ シールド完全冷却完了！")
			trigger_screen_flash(Color.CYAN)
	else:
		if not is_guarding and shield_heat > 0.0:
			shield_heat = max(0.0, shield_heat - heat_recovery_rate * delta)
	
	var space_pressed = Input.is_key_pressed(KEY_SPACE)
	var space_just_pressed = space_pressed and not space_was_pressed
	space_was_pressed = space_pressed
	
	if space_just_pressed:
		if is_overheated:
			spawn_popup_message("⚠️ シールドオーバーヒート中！冷却待機")
		elif shield_heat < max_shield_heat:
			is_guarding = true
			active_timer = parry_active_time
			shield_heat += heat_per_use
			parried_in_current_frame = false
			
			if shield_heat >= max_shield_heat:
				shield_heat = max_shield_heat
				is_overheated = true
				overheat_timer = overheat_cooldown
				trigger_screen_flash(Color(1.0, 0.2, 0.2, 0.5))
				spawn_popup_message("⚠️ シールドオーバーヒート！")
	
	if is_guarding:
		check_parry()
	
	update_visual_state()
	
	if parry_ring_alpha > 0.0:
		queue_redraw()
		
	if is_full_burst:
		if not has_meta("last_burst_time"):
			set_meta("last_burst_time", 0.0)
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - float(get_meta("last_burst_time")) > 0.06:
			fire_full_burst()
			set_meta("last_burst_time", current_time)

	if Global.is_first_launch and not is_attack_unlocked:
		var near_bullet_found = false
		for bullet in enemy_bullets:
			if is_instance_valid(bullet) and not bullet.is_friendly:
				var dist = global_position.distance_to(bullet.global_position)
				if dist <= parry_window_radius * 2.2 and dist > parry_window_radius * 0.4:
					near_bullet_found = true
					break
		
		if near_bullet_found and not is_guarding and not is_overheated:
			Engine.time_scale = 0.15
			if not has_meta("slow_alert_shown"):
				set_meta("slow_alert_shown", true)
				spawn_popup_message("⚠️ 危険: SPACEでパリィを実行！")
		else:
			if Engine.time_scale < 0.5 and not is_guarding:
				Engine.time_scale = 1.0

	if not is_full_burst and not get_meta("is_counter_system_used", false):
		var main = get_node_or_null("/root/Main")
		if main:
			var manager = main.get_node_or_null("GameManager")
			if manager and manager.get("state") == "boss":
				if Input.is_key_pressed(KEY_X):
					set_meta("is_counter_system_used", true)
					is_full_burst = true
					spawn_popup_message("⚠️ COUNTER SYSTEM ACTIVE: FULL BURST!")
					
					get_tree().create_timer(3.0).timeout.connect(func():
						is_full_burst = false
						spawn_popup_message("COUNTER SYSTEM: DEPLETED")
					)


func toggle_weapon() -> void:
	if not weapons["beam"]["analyzed"] and not weapons["missile"]["analyzed"]:
		return
		
	if weapons["beam"]["analyzed"] and not weapons["missile"]["analyzed"]:
		if current_weapon != "beam":
			current_weapon = "beam"
			spawn_popup_message("WEAPON ENGAGED: BEAM")
		return
	if weapons["missile"]["analyzed"] and not weapons["beam"]["analyzed"]:
		if current_weapon != "missile":
			current_weapon = "missile"
			spawn_popup_message("WEAPON ENGAGED: MISSILE")
		return
		
	if current_weapon == "beam":
		current_weapon = "missile"
	else:
		current_weapon = "beam"
	spawn_popup_message("WEAPON ENGAGED: " + current_weapon.to_upper())


func fire() -> void:
	if not PLAYER_BULLET_SCENE:
		return
		
	var player_bullets_container = get_node_or_null("/root/Main/PlayerBullets")
	var target_parent = player_bullets_container if player_bullets_container else get_parent()
	
	var angles = [0.0]
	if trait_spread_unlocked:
		angles = [-15.0, 0.0, 15.0]
		
	for deg in angles:
		var analysis_shot = PLAYER_BULLET_SCENE.instantiate()
		analysis_shot.bullet_type = "charge_bolt" if trait_pierce_unlocked else "analysis"
		analysis_shot.global_position = global_position + Vector2(deg * 0.4, -20.0)
		var spd = ANALYSIS_BULLET_SPEED_RAPID if trait_rapid_unlocked else ANALYSIS_BULLET_SPEED_NORMAL
		var dir = Vector2.UP.rotated(deg_to_rad(deg))
		analysis_shot.velocity = dir * spd
		analysis_shot.damage += int(power_shield_damage_buff)
		target_parent.add_child(analysis_shot)
		
	if trait_homing_unlocked:
		var offsets = [Vector2(-22.0, 5.0), Vector2(22.0, 5.0)]
		for off in offsets:
			var m_bullet = PLAYER_BULLET_SCENE.instantiate()
			m_bullet.bullet_type = "missile"
			m_bullet.global_position = global_position + off
			var launch_dir = Vector2(off.x, -40.0).normalized()
			m_bullet.velocity = launch_dir * SUB_MISSILE_SPEED
			m_bullet.damage += int(power_shield_damage_buff)
			target_parent.add_child(m_bullet)
			
	fire_equipped_physics_weapon(target_parent)
	
	if current_weapon == "beam" and weapons["beam"]["analyzed"]:
		if weapons["beam"]["level"] == 1:
			var bullet = PLAYER_BULLET_SCENE.instantiate()
			bullet.bullet_type = "beam"
			bullet.global_position = global_position
			bullet.velocity = Vector2.UP * 1500.0
			bullet.damage += int(power_shield_damage_buff)
			target_parent.add_child(bullet)
		else:
			var bullet = PLAYER_BULLET_SCENE.instantiate()
			bullet.bullet_type = "giga_laser"
			bullet.global_position = global_position
			bullet.velocity = Vector2.UP * 2000.0
			bullet.damage += int(power_shield_damage_buff)
			target_parent.add_child(bullet)
			
	elif current_weapon == "missile" and weapons["missile"]["analyzed"]:
		var is_hyper = weapons["missile"]["level"] > 1
		var missile_type = "hyper_missile" if is_hyper else "missile"
		var offsets = [Vector2(-20.0, 0.0), Vector2(20.0, 0.0)]
		if is_hyper:
			offsets.append(Vector2(-35.0, 10.0))
			offsets.append(Vector2(35.0, 10.0))
			
		for offset in offsets:
			var bullet = PLAYER_BULLET_SCENE.instantiate()
			bullet.bullet_type = missile_type
			bullet.global_position = global_position + offset
			bullet.damage += int(power_shield_damage_buff)
			var launch_dir = Vector2(offset.x, -50.0).normalized()
			bullet.velocity = launch_dir * (550.0 if is_hyper else 450.0)
			target_parent.add_child(bullet)


func fire_equipped_physics_weapon(target_parent: Node) -> void:
	var eq_w = Global.equipped_weapon
	match eq_w:
		WEAPON_MACHINE_GUN:
			var offsets = [Vector2(-12.0, -10.0), Vector2(12.0, -10.0)]
			for offset in offsets:
				var bullet = PLAYER_BULLET_SCENE.instantiate()
				bullet.bullet_type = "machine_gun"
				bullet.global_position = global_position + offset
				bullet.velocity = Vector2.UP * 1100.0
				bullet.damage += int(power_shield_damage_buff)
				target_parent.add_child(bullet)
				
		WEAPON_BURST_RIFLE:
			for i in range(3):
				get_tree().create_timer(i * 0.07).timeout.connect(func():
					if is_instance_valid(self) and is_instance_valid(target_parent):
						var bullet = PLAYER_BULLET_SCENE.instantiate()
						bullet.bullet_type = "burst_rifle"
						bullet.global_position = global_position + Vector2(0, -20.0)
						bullet.velocity = Vector2.UP * 1300.0
						bullet.damage += int(power_shield_damage_buff)
						target_parent.add_child(bullet)
				)
				
		WEAPON_CHARGE_RIFLE:
			var bullet = PLAYER_BULLET_SCENE.instantiate()
			bullet.bullet_type = "charge_bolt"
			bullet.global_position = global_position + Vector2(0, -25.0)
			bullet.velocity = Vector2.UP * 1800.0
			bullet.damage += int(power_shield_damage_buff)
			target_parent.add_child(bullet)
			trigger_screen_flash(Color(0.8, 0.9, 1.0, 0.15))
			
		WEAPON_PULSE_GUN:
			var angles = [-12.0, 12.0]
			for angle in angles:
				var bullet = PLAYER_BULLET_SCENE.instantiate()
				bullet.bullet_type = "pulse"
				bullet.global_position = global_position + Vector2(angle * 0.8, -15.0)
				var dir = Vector2.UP.rotated(deg_to_rad(angle))
				bullet.velocity = dir * 950.0
				bullet.damage += int(power_shield_damage_buff)
				target_parent.add_child(bullet)
				
		WEAPON_PLASMA_EMITTER:
			var angles = [-20.0, 0.0, 20.0]
			for angle in angles:
				var bullet = PLAYER_BULLET_SCENE.instantiate()
				bullet.bullet_type = "plasma"
				bullet.global_position = global_position + Vector2(angle * 0.5, -20.0)
				var dir = Vector2.UP.rotated(deg_to_rad(angle))
				bullet.velocity = dir * 500.0
				bullet.damage += int(power_shield_damage_buff)
				target_parent.add_child(bullet)
				
		WEAPON_KINETIC_TACKLE:
			var bullet = PLAYER_BULLET_SCENE.instantiate()
			bullet.bullet_type = "tackle"
			bullet.global_position = global_position + Vector2(0, -30.0)
			bullet.velocity = Vector2.UP * 750.0
			bullet.damage += int(power_shield_damage_buff)
			target_parent.add_child(bullet)


func update_visual_state() -> void:
	if is_guarding:
		match Global.equipped_shield:
			SHIELD_COUNTER:
				modulate = Color(0.9, 0.4, 1.0)
			SHIELD_GAUGE:
				modulate = Color(0.3, 1.0, 0.6)
			SHIELD_POWER:
				modulate = Color(1.0, 0.6, 0.2)
			_:
				modulate = Color.CYAN
	elif is_overheated:
		modulate = COLOR_OVERHEAT
	else:
		match current_weapon:
			"beam":
				modulate = Color(0.7, 1.0, 1.0)
			"missile":
				modulate = Color(0.9, 0.7, 1.0)
			_:
				modulate = Color.WHITE


func check_parry() -> void:
	var parry_triggered_now = false
	var shield_type = Global.equipped_shield
	
	for bullet in enemy_bullets:
		if is_instance_valid(bullet) and not bullet.is_friendly:
			var dist = global_position.distance_to(bullet.global_position)
			if dist <= parry_window_radius:
				if not is_attack_unlocked:
					is_attack_unlocked = true
					if Global.is_first_launch:
						Global.is_first_launch = false
						Engine.time_scale = 1.0
						spawn_popup_message("パリィ成功！武装システムオンライン！")
						
						var current_stage = 1
						var main = get_node_or_null("/root/Main")
						if main:
							var manager = main.get_node_or_null("GameManager")
							if manager and "current_stage_num" in manager:
								current_stage = manager.current_stage_num
						Global.save_game(current_stage, 0, {})
				
				advance_analysis(bullet.bullet_type, 3.5)
				
				if shield_type == SHIELD_POWER:
					bullet.recycle_bullet()
					power_shield_damage_buff = min(power_shield_damage_buff + 4.0, 20.0)
					
					var main = get_node_or_null("/root/Main")
					if main:
						var manager = main.get_node_or_null("GameManager")
						if manager and manager.has_method("register_parry"):
							manager.register_parry()
				else:
					bullet.convert_to_friendly()
					if shield_type == SHIELD_COUNTER:
						bullet.damage = int(bullet.damage * 1.5)
						
				parry_triggered_now = true
				
	if parry_triggered_now and not parried_in_current_frame:
		parried_in_current_frame = true
		trigger_parry_feedback()


func take_damage(amount: int) -> void:
	if is_guarding:
		return
		
	if Global.is_first_launch and Engine.time_scale < 0.5:
		Engine.time_scale = 1.0
		
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0
		
	trigger_screen_flash(Color(1.0, 0.0, 0.0, 0.4))


func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)


func advance_analysis(bullet_type: String, amount: float = 3.5) -> void:
	var pattern_key = PATTERN_RAPID
	if bullet_type.contains("wave") or bullet_type.contains("pulse") or bullet_type.contains("spread"):
		pattern_key = PATTERN_SPREAD
	elif bullet_type.contains("charge") or bullet_type.contains("laser"):
		pattern_key = PATTERN_PIERCE
	elif bullet_type.contains("missile") or bullet_type.contains("irregular"):
		pattern_key = PATTERN_HOMING
	else:
		pattern_key = PATTERN_RAPID
		
	var actual_amount = amount
	if Global.equipped_shield == SHIELD_GAUGE:
		actual_amount *= 1.5
		
	add_pattern_analysis(pattern_key, actual_amount)
	
	if bullet_type.contains("beam") and "beam" in weapons and not weapons["beam"]["analyzed"]:
		weapons["beam"]["progress"] = min(100, weapons["beam"]["progress"] + int(actual_amount))
		if weapons["beam"]["progress"] >= 100:
			weapons["beam"]["analyzed"] = true
	elif bullet_type.contains("missile") and "missile" in weapons and not weapons["missile"]["analyzed"]:
		weapons["missile"]["progress"] = min(100, weapons["missile"]["progress"] + int(actual_amount))
		if weapons["missile"]["progress"] >= 100:
			weapons["missile"]["analyzed"] = true


func add_pattern_analysis(pattern_key: String, amount: float) -> void:
	if not pattern_key in analysis_patterns:
		return
		
	var data = analysis_patterns[pattern_key]
	if data["analyzed"]:
		return
		
	data["progress"] = min(100.0, data["progress"] + amount)
	
	var pop_text = "【%s解析】%d%%" % [data["name"], int(data["progress"])]
	spawn_popup_message(pop_text)
	
	if data["progress"] >= 100.0:
		data["analyzed"] = true
		apply_pattern_trait(pattern_key)


func apply_pattern_trait(pattern_key: String) -> void:
	match pattern_key:
		PATTERN_RAPID:
			trait_rapid_unlocked = true
			apply_equipped_weapon_settings()
			spawn_popup_message("⚡【連射強化】連射速度が大幅アップ！")
		PATTERN_SPREAD:
			trait_spread_unlocked = true
			spawn_popup_message("⚡【拡散機能獲得】3-WAY 拡散射撃を解放！")
		PATTERN_PIERCE:
			trait_pierce_unlocked = true
			spawn_popup_message("⚡【貫通機能獲得】貫通重弾に進化！")
		PATTERN_HOMING:
			trait_homing_unlocked = true
			spawn_popup_message("⚡【追尾機能獲得】誘導ミサイル追撃解放！")
			
	trigger_screen_flash(Color.GOLD)


func upgrade_weapon(weapon_type: String) -> void:
	if weapons.has(weapon_type):
		weapons[weapon_type]["level"] = 2
		weapons[weapon_type]["analyzed"] = true
		current_weapon = weapon_type
		
		var label_text = "TECHNOLOGY HARVESTED: [" + weapon_type.to_upper() + " LV2]!"
		spawn_popup_message(label_text)
		trigger_screen_flash(Color(1.0, 0.8, 0.2, 0.6))


func trigger_screen_flash(color: Color = Color(1.0, 1.0, 1.0, 0.5)) -> void:
	var main = get_node_or_null("/root/Main")
	if main:
		var ui_node = main.get_node_or_null("UI")
		if ui_node and ui_node.has_method("trigger_flash"):
			ui_node.trigger_flash(color)


func spawn_popup_message(text: String) -> void:
	var label = Label.new()
	label.text = text
	
	var settings = LabelSettings.new()
	settings.font_size = 20
	settings.font_color = Color.CYAN
	settings.outline_size = 5
	settings.outline_color = Color.BLACK
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	label.global_position = global_position + Vector2(-200.0, -70.0)
	label.custom_minimum_size = Vector2(400.0, 30.0)
	
	var main = get_node_or_null("/root/Main")
	if main:
		main.add_child(label)
	else:
		get_parent().add_child(label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0.0, -80.0), 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


func trigger_parry_feedback() -> void:
	trigger_screen_flash(Color(0.3, 0.8, 1.0, 0.45))
	trigger_hit_stop(0.12, 0.05)
	trigger_parry_ring_effect()
	spawn_parry_popup_message("パリィ！")


func trigger_hit_stop(duration_sec: float, scale: float) -> void:
	Engine.time_scale = scale
	var timer = get_tree().create_timer(duration_sec * scale, true)
	timer.timeout.connect(func():
		Engine.time_scale = 1.0
	)


func trigger_parry_ring_effect() -> void:
	parry_ring_radius = 15.0
	parry_ring_alpha = 0.9
	queue_redraw()
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "parry_ring_radius", parry_window_radius * 1.4, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "parry_ring_alpha", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func spawn_parry_popup_message(text: String) -> void:
	var label = Label.new()
	label.text = text
	
	var settings = LabelSettings.new()
	settings.font_size = 36
	settings.font_color = Color.GOLD
	settings.outline_size = 8
	settings.outline_color = Color.BLACK
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	label.global_position = global_position + Vector2(-200.0, -80.0)
	label.custom_minimum_size = Vector2(400.0, 40.0)
	
	var main = get_node_or_null("/root/Main")
	if main:
		main.add_child(label)
	else:
		get_parent().add_child(label)
	
	label.scale = Vector2(0.5, 0.5)
	label.pivot_offset = Vector2(200.0, 20.0)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0.0, -90.0), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var fade_tween = create_tween()
	fade_tween.tween_interval(0.4)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.6)
	
	tween.chain().tween_callback(label.queue_free)


func _draw() -> void:
	if parry_ring_alpha > 0.0:
		var base_color = Color(0.0, 0.9, 1.0)
		match Global.equipped_shield:
			SHIELD_COUNTER:
				base_color = COLOR_SHIELD_COUNTER
			SHIELD_GAUGE:
				base_color = COLOR_SHIELD_GAUGE
			SHIELD_POWER:
				base_color = COLOR_SHIELD_POWER
				
		var color = Color(base_color.r, base_color.g, base_color.b, parry_ring_alpha)
		draw_arc(Vector2.ZERO, parry_ring_radius, 0, TAU, 48, color, 4.0, true)
		var fill_color = Color(base_color.r, base_color.g, base_color.b, parry_ring_alpha * 0.15)
		draw_circle(Vector2.ZERO, parry_ring_radius, fill_color)


func fire_full_burst() -> void:
	if not PLAYER_BULLET_SCENE:
		return
		
	var player_bullets_container = get_node_or_null("/root/Main/PlayerBullets")
	var target_parent = player_bullets_container if player_bullets_container else get_parent()
	
	var target_pos = Vector2(get_viewport_rect().size.x / 2.0, 160.0)
	var main = get_node_or_null("/root/Main")
	if main:
		var boss_node = main.get_node_or_null("Boss")
		if is_instance_valid(boss_node):
			target_pos = boss_node.global_position
			
	var dir_to_boss = (target_pos - global_position).normalized()
	
	var bullet_giga = PLAYER_BULLET_SCENE.instantiate()
	bullet_giga.bullet_type = "giga_laser"
	bullet_giga.global_position = global_position
	bullet_giga.velocity = dir_to_boss * GIGA_LASER_SPEED
	target_parent.add_child(bullet_giga)
	
	var angles = [-25.0, -10.0, 10.0, 25.0]
	for angle in angles:
		var bullet_missile = PLAYER_BULLET_SCENE.instantiate()
		bullet_missile.bullet_type = "hyper_missile"
		bullet_missile.global_position = global_position + Vector2(angle * 1.5, 0.0)
		bullet_missile.velocity = dir_to_boss.rotated(deg_to_rad(angle)) * HYPER_MISSILE_SPEED
		target_parent.add_child(bullet_missile)
		
	for i in range(3):
		var bullet_analysis = PLAYER_BULLET_SCENE.instantiate()
		bullet_analysis.bullet_type = "analysis"
		bullet_analysis.global_position = global_position + Vector2(randf_range(-30.0, 30.0), -20.0)
		bullet_analysis.velocity = dir_to_boss.rotated(randf_range(-0.3, 0.3)) * 1200.0
		target_parent.add_child(bullet_analysis)
		
	trigger_screen_flash(Color(0.2, 0.8, 1.0, 0.1))
