extends CharacterBody2D
## プレイヤー機体スクリプト
## - 移動・ガード・攻撃・各種解析変異およびフルバースト制御

# --- 基本パラメータ ---
@export var max_hp: int = 400
@export var move_speed: float = 300.0
@export var parry_window_radius: float = 85.0  # パリィ判定範囲 (65 -> 85へ拡大)
@export var fire_rate: float = 0.2            # 射撃間隔
@export var parry_active_time: float = 0.28  # ガード持続時間
@export var parry_cooldown: float = 1.5      # クールダウン時間
@export var invincible_duration: float = 1.4  # 被弾後無敵時間（1.4秒）

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

# 定数：解析パターンキー (敵の全7挙動)
const PATTERN_RAPID = "rapid"
const PATTERN_SPREAD = "spread"
const PATTERN_PIERCE = "pierce"
const PATTERN_HOMING = "homing"
const PATTERN_LASER = "laser"
const PATTERN_CYCLONE = "cyclone"
const PATTERN_METEOR = "meteor"

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

var current_hp: int = 400
var last_fire_time: float = 0.0
var enemy_bullets: Array = []

var is_invincible: bool = false
var invincibility_timer: float = 0.0

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

# --- シールド・オーバーヒートシステム (マイルド調整) ---
@export var max_shield_heat: float = 100.0
@export var heat_per_use: float = 20.0        # 1回あたり20% (連続5回使用可能)
@export var heat_recovery_rate: float = 45.0   # 素早く放熱 (1秒で45%冷却)
@export var overheat_cooldown: float = 2.0     # オーバーヒート2秒で復帰

var shield_heat: float = 0.0
var overheat_timer: float = 0.0
var is_overheated: bool = false

# --- 攻撃パターン解析＆変異スロットシステム (最大3枠制限＆Lv制) ---
const MAX_TRAIT_SLOTS: int = 3
var active_traits: Array[String] = [] # 現在装備中の最大3つの属性キー

var analysis_patterns: Dictionary = {
	PATTERN_RAPID:   { "progress": 0.0, "analyzed": false, "level": 0, "max_level": 2, "name": "高速連射", "icon": "⚡", "color": Color(0.3, 0.8, 1.0) },
	PATTERN_SPREAD:  { "progress": 0.0, "analyzed": false, "level": 0, "max_level": 2, "name": "拡散射撃", "icon": "◈", "color": Color(0.2, 1.0, 0.6) },
	PATTERN_PIERCE:  { "progress": 0.0, "analyzed": false, "level": 0, "max_level": 2, "name": "貫通重弾", "icon": "▲", "color": Color(1.0, 0.6, 0.2) },
	PATTERN_HOMING:  { "progress": 0.0, "analyzed": false, "level": 0, "max_level": 2, "name": "誘導ミサイル", "icon": "▶", "color": Color(0.85, 0.45, 1.0) },
	PATTERN_LASER:   { "progress": 0.0, "analyzed": false, "level": 0, "max_level": 2, "name": "フォトン光線", "icon": "━", "color": Color(0.4, 0.9, 1.0) },
	PATTERN_CYCLONE: { "progress": 0.0, "analyzed": false, "level": 0, "max_level": 2, "name": "旋回スピン", "icon": "◎", "color": Color(1.0, 0.85, 0.2) },
	PATTERN_METEOR:  { "progress": 0.0, "analyzed": false, "level": 0, "max_level": 2, "name": "ギガメテオ", "icon": "●", "color": Color(1.0, 0.35, 0.2) }
}

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
	max_hp = 400 + 50 * hp_lvl
	current_hp = max_hp
	is_invincible = false
	invincibility_timer = 0.0
	
	var parry_lvl = Global.upgrade_levels.get("parry_window", 0)
	parry_window_radius = 85.0 + 5.0 * parry_lvl
	
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
	
	active_traits.clear()
	
	for key in analysis_patterns.keys():
		analysis_patterns[key]["progress"] = 0.0
		analysis_patterns[key]["analyzed"] = false
		analysis_patterns[key]["level"] = 0
	
	apply_equipped_weapon_settings()
	
	var main_ui_sync = get_node_or_null("/root/Main")
	if main_ui_sync:
		var ui_node = main_ui_sync.get_node_or_null("UI")
		if ui_node and ui_node.has_method("update_equipped_weapon_hud"):
			ui_node.update_equipped_weapon_hud(Global.equipped_weapon)
	
	if Global.is_first_launch:
		get_tree().create_timer(0.8).timeout.connect(func():
			if is_instance_valid(self) and not is_attack_unlocked:
				spawn_popup_message("【AIアシスト】方向キー（矢印キー / WASD）で機体を移動してください。")
		)


func apply_equipped_weapon_settings() -> void:
	var eq_w = Global.equipped_weapon
	match eq_w:
		WEAPON_MACHINE_GUN:
			fire_rate = 0.16 # 高速マシンガン
		WEAPON_BURST_RIFLE:
			fire_rate = 0.42 # 3点バーストライフル
		WEAPON_PULSE_GUN:
			fire_rate = 0.28 # パルス波動砲
		WEAPON_PLASMA_EMITTER:
			fire_rate = 0.38 # 高熱プラズマ放射器
		WEAPON_KINETIC_TACKLE:
			fire_rate = 0.55 # キネティック衝撃タックル
		_:
			fire_rate = 0.25
			
	if active_traits.has(PATTERN_RAPID):
		var r_lvl = analysis_patterns[PATTERN_RAPID]["level"]
		fire_rate *= (0.70 if r_lvl == 1 else 0.50)


func cycle_equipped_weapon(dir: int) -> void:
	var unlocked = Global.unlocked_weapons
	if unlocked.size() <= 1:
		return
	var cur_idx = unlocked.find(Global.equipped_weapon)
	if cur_idx == -1:
		cur_idx = 0
	var next_idx = (cur_idx + dir + unlocked.size()) % unlocked.size()
	var new_weapon = unlocked[next_idx]
	Global.equipped_weapon = new_weapon
	apply_equipped_weapon_settings()
	
	var w_name = new_weapon
	if Global.available_weapons.has(new_weapon):
		w_name = Global.available_weapons[new_weapon].get("name", new_weapon)
	spawn_popup_message("⚡ 主兵装切替: 【%s】" % w_name)
	
	var main = get_node_or_null("/root/Main")
	if main:
		var ui_node = main.get_node_or_null("UI")
		if ui_node and ui_node.has_method("update_equipped_weapon_hud"):
			ui_node.update_equipped_weapon_hud(new_weapon)


func _process(delta: float) -> void:
	# 無敵タイマー減算 & 点滅処理
	if is_invincible:
		invincibility_timer -= delta
		var sprite = get_node_or_null("Sprite2D")
		if sprite:
			sprite.modulate.a = 0.3 if int(invincibility_timer * 22.0) % 2 == 0 else 0.9
		if invincibility_timer <= 0.0:
			is_invincible = false
			if sprite:
				sprite.modulate.a = 1.0

	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_axis("ui_left", "ui_right")
	input_vector.y = Input.get_axis("ui_up", "ui_down")
	
	velocity = input_vector.normalized() * move_speed
	move_and_slide()
	
	var viewport_size = get_viewport_rect().size
	position.x = clamp(position.x, 20.0, viewport_size.x - 20.0)
	position.y = clamp(position.y, 20.0, viewport_size.y - 20.0)
	
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
	
	# --- チュートリアル：初回パリィ接近時スローモーション判定 ---
	if not is_attack_unlocked:
		var has_close_bullet = false
		var all_targets = []
		all_targets.append_array(enemy_bullets)
		for p in get_tree().get_nodes_in_group("enemy_projectiles"):
			if is_instance_valid(p) and not all_targets.has(p):
				all_targets.append(p)
				
		for b in all_targets:
			if is_instance_valid(b) and not b.is_friendly:
				var dist = global_position.distance_to(b.global_position)
				if dist <= parry_window_radius + 45.0:
					has_close_bullet = true
					break
					
		if has_close_bullet:
			if Engine.time_scale > 0.3:
				Engine.time_scale = 0.15
				spawn_popup_message("【AIアシスト】敵弾がガード範囲に接近！SPACEキーでパリィ！")
		else:
			if Engine.time_scale < 0.5:
				Engine.time_scale = 1.0

	var space_pressed = Input.is_key_pressed(KEY_SPACE)
	var space_just_pressed = space_pressed and not space_was_pressed
	space_was_pressed = space_pressed
	
	# --- 兵装のリアルタイム切替 (Q / E / C) ---
	if Input.is_key_pressed(KEY_Q) and not get_meta("q_was_pressed", false):
		set_meta("q_was_pressed", true)
		cycle_equipped_weapon(-1)
	elif not Input.is_key_pressed(KEY_Q):
		set_meta("q_was_pressed", false)
		
	if (Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_C)) and not get_meta("e_was_pressed", false):
		set_meta("e_was_pressed", true)
		cycle_equipped_weapon(1)
	elif not (Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_C)):
		set_meta("e_was_pressed", false)
	
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


func fire() -> void:
	if current_hp <= 0 or not is_attack_unlocked or not PLAYER_BULLET_SCENE:
		return
		
	var player_bullets_container = get_node_or_null("/root/Main/PlayerBullets")
	var target_parent = player_bullets_container if player_bullets_container else get_parent()
	
	# 1. 選択された基本武装（主兵装）の射撃実行
	fire_equipped_physics_weapon(target_parent)
	
	# 2. 変異スロット補助兵装：誘導ミサイル (スロット装備時: Lv.1=2基, Lv.2=4基)
	if active_traits.has(PATTERN_HOMING):
		var homing_lvl = analysis_patterns[PATTERN_HOMING]["level"]
		var offsets = [Vector2(-22.0, 5.0), Vector2(22.0, 5.0)]
		if homing_lvl >= 2:
			offsets.append(Vector2(-36.0, 15.0))
			offsets.append(Vector2(36.0, 15.0))
		for off in offsets:
			var m_bullet = PLAYER_BULLET_SCENE.instantiate()
			m_bullet.bullet_type = "hyper_missile" if homing_lvl >= 2 else "missile"
			m_bullet.global_position = global_position + off
			var launch_dir = Vector2(off.x, -40.0).normalized()
			m_bullet.velocity = launch_dir * SUB_MISSILE_SPEED
			m_bullet.damage += int(power_shield_damage_buff)
			target_parent.add_child(m_bullet)

	# 3. 変異スロット補助兵装：フォトンレーザー (スロット装備時: Lv.1=1本, Lv.2=ツイン)
	if active_traits.has(PATTERN_LASER):
		var laser_lvl = analysis_patterns[PATTERN_LASER]["level"]
		var x_offsets = [0.0] if laser_lvl == 1 else [-16.0, 16.0]
		for lx in x_offsets:
			var l_bullet = PLAYER_BULLET_SCENE.instantiate()
			l_bullet.bullet_type = "photon_laser"
			l_bullet.global_position = global_position + Vector2(lx, -30.0)
			l_bullet.damage += int(power_shield_damage_buff)
			target_parent.add_child(l_bullet)

	# 4. 変異スロット補助兵装：サイクロンスピン弾 (スロット装備時: Lv.1=2発, Lv.2=4発)
	if active_traits.has(PATTERN_CYCLONE):
		var cyc_lvl = analysis_patterns[PATTERN_CYCLONE]["level"]
		var dirs = [-1.0, 1.0] if cyc_lvl == 1 else [-1.5, -0.6, 0.6, 1.5]
		for dir_x in dirs:
			var c_bullet = PLAYER_BULLET_SCENE.instantiate()
			c_bullet.bullet_type = "cyclone"
			c_bullet.global_position = global_position + Vector2(dir_x * 16.0, -10.0)
			c_bullet.velocity = Vector2(dir_x * 110.0, -650.0)
			c_bullet.damage += int(power_shield_damage_buff)
			target_parent.add_child(c_bullet)

	# 5. 変異スロット補助兵装：ギガメテオ (スロット装備時: 確率で射出)
	if active_traits.has(PATTERN_METEOR):
		var met_lvl = analysis_patterns[PATTERN_METEOR]["level"]
		var chance = 0.25 if met_lvl == 1 else 0.40
		if randf() < chance:
			var meteor = PLAYER_BULLET_SCENE.instantiate()
			meteor.bullet_type = "player_meteor"
			meteor.global_position = global_position + Vector2(randf_range(-30, 30), -35.0)
			meteor.velocity = Vector2(randf_range(-180, 180), -550.0)
			meteor.damage += int(power_shield_damage_buff)
			target_parent.add_child(meteor)


func fire_equipped_physics_weapon(target_parent: Node) -> void:
	if current_hp <= 0 or not is_instance_valid(target_parent):
		return
		
	var is_spread_active = active_traits.has(PATTERN_SPREAD)
	var spread_lvl = analysis_patterns[PATTERN_SPREAD]["level"] if is_spread_active else 0
	
	var is_pierce_active = active_traits.has(PATTERN_PIERCE)
	var pierce_lvl = analysis_patterns[PATTERN_PIERCE]["level"] if is_pierce_active else 0
	
	var eq_w = Global.equipped_weapon
	match eq_w:
		WEAPON_MACHINE_GUN:
			# マシンガン: 高速物理弾連射（拡散変異で2連装➔4連装➔扇状連射へ進化）
			var angles = [0.0]
			var offsets = [Vector2(-10.0, -15.0), Vector2(10.0, -15.0)]
			if is_spread_active:
				if spread_lvl == 1:
					offsets = [Vector2(-16.0, -15.0), Vector2(-6.0, -15.0), Vector2(6.0, -15.0), Vector2(16.0, -15.0)]
				else:
					angles = [-12.0, 0.0, 12.0]
			
			for deg in angles:
				for offset in offsets:
					var bullet = PLAYER_BULLET_SCENE.instantiate()
					bullet.bullet_type = "charge_bolt" if (is_pierce_active and pierce_lvl >= 2) else "machine_gun"
					bullet.global_position = global_position + offset
					var dir = Vector2.UP.rotated(deg_to_rad(deg))
					bullet.velocity = dir * 1200.0
					bullet.damage += int(power_shield_damage_buff)
					if is_pierce_active:
						bullet.damage += 6
					target_parent.add_child(bullet)
				
		WEAPON_BURST_RIFLE:
			# ライフル: 3点徹甲バースト射撃（貫通変異や拡散変異で重粒子ビームボルト化）
			var burst_count = 3 if not is_spread_active else (4 if spread_lvl == 1 else 5)
			for i in range(burst_count):
				get_tree().create_timer(i * 0.06).timeout.connect(func():
					if is_instance_valid(self) and current_hp > 0 and is_instance_valid(target_parent):
						var bullet = PLAYER_BULLET_SCENE.instantiate()
						bullet.bullet_type = "charge_bolt" if is_pierce_active else "burst_rifle"
						bullet.global_position = global_position + Vector2(0, -22.0)
						bullet.velocity = Vector2.UP * (1600.0 if is_pierce_active else 1400.0)
						bullet.damage += int(power_shield_damage_buff)
						if is_pierce_active and pierce_lvl >= 2:
							bullet.damage += 15
						target_parent.add_child(bullet)
				)
				
		WEAPON_PULSE_GUN:
			# パルスガン: 広角プラズマ波動（拡散変異で広角5WAY〜7WAYへ拡張）
			var angles = [-14.0, 14.0]
			if is_spread_active:
				angles = [-22.0, -11.0, 11.0, 22.0] if spread_lvl == 1 else [-30.0, -18.0, -6.0, 6.0, 18.0, 30.0]
			for angle_deg in angles:
				var bullet = PLAYER_BULLET_SCENE.instantiate()
				bullet.bullet_type = "pulse"
				bullet.global_position = global_position + Vector2(angle_deg * 0.6, -15.0)
				var dir = Vector2.UP.rotated(deg_to_rad(angle_deg))
				bullet.velocity = dir * 1000.0
				bullet.damage += int(power_shield_damage_buff)
				if is_pierce_active:
					bullet.damage += 8
				target_parent.add_child(bullet)
				
		WEAPON_PLASMA_EMITTER:
			# プラズマ放射器: 高熱持続プラズマ球（拡散変異でツイン〜トリプルプラズマへ進化）
			var offsets = [Vector2(0, -20.0)]
			if is_spread_active:
				offsets = [Vector2(-18.0, -18.0), Vector2(18.0, -18.0)] if spread_lvl == 1 else [Vector2(-24.0, -15.0), Vector2(0, -22.0), Vector2(24.0, -15.0)]
			for offset in offsets:
				var bullet = PLAYER_BULLET_SCENE.instantiate()
				bullet.bullet_type = "plasma"
				bullet.global_position = global_position + offset
				bullet.velocity = Vector2.UP * 600.0
				bullet.damage += int(power_shield_damage_buff)
				if is_pierce_active and pierce_lvl >= 2:
					bullet.damage += 16
				target_parent.add_child(bullet)
			
		WEAPON_KINETIC_TACKLE:
			# タックル: キネティック衝撃破砕波（拡散変異で超巨大ショックウェーブ化）
			var count = 1 if not is_spread_active else (2 if spread_lvl == 1 else 3)
			for i in range(count):
				var offset_x = (i - (count - 1) * 0.5) * 28.0
				var bullet = PLAYER_BULLET_SCENE.instantiate()
				bullet.bullet_type = "tackle"
				bullet.global_position = global_position + Vector2(offset_x, -30.0)
				bullet.velocity = Vector2.UP * 850.0
				bullet.damage += int(power_shield_damage_buff)
				if is_pierce_active:
					bullet.damage += 20
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
		modulate = Color.WHITE


var consecutive_parries: int = 0

func check_parry() -> void:
	if current_hp <= 0:
		return
	var parry_triggered_now = false
	var shield_type = Global.equipped_shield
	
	var all_targets = []
	all_targets.append_array(enemy_bullets)
	for p in get_tree().get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(p) and not all_targets.has(p):
			all_targets.append(p)
	
	for bullet in all_targets:
		if is_instance_valid(bullet) and not bullet.is_friendly:
			# パリィ不可弾は跳ね返し判定を完全にスキップ
			var is_unparryable = bullet.get("is_unparryable") == true or (bullet.get("bullet_type") != null and String(bullet.get("bullet_type")).contains("unparryable"))
			if is_unparryable:
				continue
				
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
				
				var b_type = bullet.bullet_type if "bullet_type" in bullet else "missile"
				var analysis_pts = 4.0
				if b_type.contains("meteor"):
					analysis_pts = 16.0 # 巨大隕石パリィは+16%
				elif b_type.contains("decel") or b_type.contains("boss_missile"):
					analysis_pts = 10.0 # 追尾ミサイルパリィは+10%
				elif b_type.contains("boss_laser") or b_type.contains("beam"):
					analysis_pts = 8.0  # ビームマシンガンパリィは+8%
					
				advance_analysis(b_type, analysis_pts)
				
				if shield_type == SHIELD_POWER:
					if bullet.has_method("recycle_bullet"):
						bullet.recycle_bullet()
					elif bullet.has_method("explode_and_free"):
						bullet.explode_and_free()
					else:
						bullet.queue_free()
					power_shield_damage_buff = min(power_shield_damage_buff + 4.0, 20.0)
					
					var main = get_node_or_null("/root/Main")
					if main:
						var manager = main.get_node_or_null("GameManager")
						if manager and manager.has_method("register_parry"):
							manager.register_parry()
				else:
					if bullet.has_method("convert_to_friendly"):
						bullet.convert_to_friendly()
					if shield_type == SHIELD_COUNTER:
						if "damage" in bullet:
							bullet.damage = int(bullet.damage * 1.5)
						
				parry_triggered_now = true
				
	if parry_triggered_now and not parried_in_current_frame:
		parried_in_current_frame = true
		consecutive_parries += 1
		# 10連続パリィ達成ごとにボーナス回復
		if consecutive_parries % 10 == 0:
			heal(25)
			spawn_popup_message("⚡ %dx PARRY COMBO! 機体修復 +25 HP" % consecutive_parries)
			
		trigger_parry_feedback()


func take_damage(amount: int) -> void:
	if is_guarding or is_invincible:
		return
		
	consecutive_parries = 0 # 被弾でコンボリセット
		
	if Global.is_first_launch and Engine.time_scale < 0.5:
		Engine.time_scale = 1.0
		
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0
		is_attack_unlocked = false
		is_guarding = false
		velocity = Vector2.ZERO
	else:
		# 被弾無敵時間 (1.4秒) を付与して多段ヒット即死を防止
		is_invincible = true
		invincibility_timer = invincible_duration
		
	trigger_screen_flash(Color(1.0, 0.0, 0.0, 0.4))


func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)


func advance_analysis(bullet_type: String, amount: float = 8.0) -> void:
	var pattern_key = PATTERN_RAPID
	match bullet_type:
		"meteor":
			pattern_key = PATTERN_METEOR
		"irregular", "cyclone":
			pattern_key = PATTERN_CYCLONE
		"laser", "boss_laser", "beam":
			pattern_key = PATTERN_LASER
		"missile", "boss_missile", "decel_missile", "homing":
			pattern_key = PATTERN_HOMING
		"charge", "pierce":
			pattern_key = PATTERN_PIERCE
		"wave", "spread", "pulse":
			pattern_key = PATTERN_SPREAD
		"straight", "rapid", _:
			pattern_key = PATTERN_RAPID
		
	var actual_amount = amount
	if Global.equipped_shield == SHIELD_GAUGE:
		actual_amount *= 1.5
		
	add_pattern_analysis(pattern_key, actual_amount)


func add_pattern_analysis(pattern_key: String, amount: float) -> void:
	if not pattern_key in analysis_patterns:
		return
		
	var data = analysis_patterns[pattern_key]
	var current_lvl = data["level"]
	if current_lvl >= data["max_level"]:
		return # 最大レベル到達時はこれ以上加算しない
		
	data["progress"] = min(100.0, data["progress"] + amount)
	
	if data["progress"] >= 100.0:
		data["progress"] = 0.0
		data["level"] += 1
		data["analyzed"] = true
		heal(50) # 解析完了時に機体大幅修復 (+50 HP)
		apply_pattern_trait(pattern_key)


func apply_pattern_trait(pattern_key: String) -> void:
	var data = analysis_patterns[pattern_key]
	var lvl = data["level"]
	
	# スロット装備判定 (最大3枠)
	if not active_traits.has(pattern_key):
		if active_traits.size() >= MAX_TRAIT_SLOTS:
			var removed_key = active_traits.pop_front() # 最も古いスロットを押し出し
			if analysis_patterns.has(removed_key):
				spawn_popup_message("【スロット交代】%s ➔ %s" % [analysis_patterns[removed_key]["name"], data["name"]])
		active_traits.append(pattern_key)
	
	trigger_level_up_burst(data, lvl)
	apply_equipped_weapon_settings()
	
	var main = get_node_or_null("/root/Main")
	if main:
		var manager = main.get_node_or_null("GameManager")
		if manager and manager.has_method("register_analysis_upgrade"):
			manager.register_analysis_upgrade()


func trigger_level_up_burst(data: Dictionary, lvl: int) -> void:
	# 1. HP大幅修復 (+60 HP)
	heal(60)
	
	# 2. 全画面金色フラッシュ
	trigger_screen_flash(Color(1.0, 0.9, 0.2, 0.45))
	
	# 3. EMPバースト：画面内の敵弾を全消滅
	var main = get_node_or_null("/root/Main")
	if main:
		var pool = main.get_node_or_null("BulletPool")
		if pool and "active_bullets" in pool:
			var bullets = pool.active_bullets.duplicate()
			for b in bullets:
				if is_instance_valid(b) and not b.is_queued_for_deletion():
					pool.return_bullet(b)
					
	# 4. 画面内の全ドローンに EMP ショックウェーブ（100ダメージ）
	var drones = get_tree().get_nodes_in_group("drones")
	for d in drones:
		if is_instance_valid(d) and d.has_method("take_damage"):
			d.take_damage(100)
			
	# 5. ドット調ビッグバナー演出
	spawn_big_levelup_banner(data["name"], lvl, data.get("icon", "⚡"))
	
	# 6. パーティクル爆発
	var p_scene = preload("res://game/bullets/parry_particle.tscn")
	if p_scene and get_parent():
		for i in range(12):
			var p = p_scene.instantiate()
			p.global_position = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
			p.scale = Vector2(2.5, 2.5)
			p.modulate = Color.GOLD
			get_parent().add_child(p)


func spawn_big_levelup_banner(trait_name: String, lvl: int, icon: String) -> void:
	var label = Label.new()
	label.text = "⚡ LEVEL UP! ⚡\n%s 【%s Lv.%d】 解放！" % [icon, trait_name, lvl]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var set = LabelSettings.new()
	var pixel_font = preload("res://game/assets/fonts/DotGothic16-Regular.ttf")
	if pixel_font:
		set.font = pixel_font
	set.font_size = 24
	set.font_color = Color.GOLD
	set.outline_size = 8
	set.outline_color = Color(0.1, 0.05, 0.0)
	label.label_settings = set
	
	var vp_w = get_viewport_rect().size.x
	label.custom_minimum_size = Vector2(500, 70)
	label.global_position = Vector2(vp_w / 2.0 - 250, 240)
	label.z_index = 30
	get_parent().add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "scale", Vector2(1.15, 1.15), 0.2).from(Vector2(0.6, 0.6))
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15)
	tween.tween_interval(1.0)
	tween.tween_property(label, "global_position:y", label.global_position.y - 40.0, 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)


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
