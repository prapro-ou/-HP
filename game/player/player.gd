extends CharacterBody2D
## プレイヤー機体スクリプト
## - 移動・ガード・攻撃・各種解析変異およびフルバースト制御

# --- 基本パラメータ ---
@export var max_hp: int = 500
@export var move_speed: float = 300.0
@export var parry_window_radius: float = 85.0  # パリィ判定範囲 (65 -> 85へ拡大)
@export var fire_rate: float = 0.2            # 射撃間隔
@export var parry_active_time: float = 0.28  # ガード持続時間
@export var invincible_duration: float = 1.6  # 被弾後無敵時間（1.6秒に延長して多段ヒット防止）

# 定数：フォント定義
const PIXEL_FONT: Font = preload("res://game/assets/fonts/DotGothic16-Regular.ttf")

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
# 定数：解析パターンキー (全10属性)
const PATTERN_RAPID = "rapid"
const PATTERN_SPREAD = "spread"
const PATTERN_PIERCE = "pierce"
const PATTERN_HOMING = "homing"
const PATTERN_LASER = "laser"
const PATTERN_CYCLONE = "cyclone"
const PATTERN_METEOR = "meteor"
const PATTERN_THUNDER = "thunder"
const PATTERN_VORTEX = "vortex"
const PATTERN_BLADE = "blade"

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

var current_hp: int = 500
var last_fire_time: float = 0.0
var enemy_bullets: Array = []

var is_invincible: bool = false
var invincibility_timer: float = 0.0

var active_timer: float = 0.0
var is_guarding: bool = false
var space_was_pressed: bool = false

var is_attack_unlocked: bool = false
var power_shield_damage_buff: float = 0.0

var parry_ring_radius: float = 0.0
var parry_ring_alpha: float = 0.0
var parry_shockwave_radius: float = 0.0
var parry_shockwave_alpha: float = 0.0
var parry_hex_alpha: float = 0.0
var parry_hex_scale: float = 1.0
var parry_sparks: Array[Dictionary] = [] # 放射状火花スパーク粒子

var parried_in_current_frame: bool = false
var parry_succeeded_in_guard: bool = false
var guard_recovery_timer: float = 0.0 # ガード終了直後の隙（カウンター受付時間）
var is_full_burst: bool = false
var counter_system_turrets: Array[Node2D] = []
var is_control_locked: bool = false
var is_victory_flyby: bool = false
var flyby_timer: float = 0.0
var flyby_boost_alpha: float = 0.0

# --- シールド・オーバーヒートシステム (リスク＆リターン調整) ---
@export var max_shield_heat: float = 100.0
@export var heat_per_use: float = 22.0        # 1回あたり22% (連続4回で過熱)
@export var heat_recovery_rate: float = 40.0   # 1秒で40%放熱
@export var overheat_cooldown: float = 2.2     # オーバーヒート2.2秒で復帰

# --- パリィ回復ゲージシステム (5回パリィでHP回復・シールド共通) ---
var parry_heal_counter: int = 0
const PARRY_HEAL_THRESHOLD: int = 5
const PARRY_HEAL_AMOUNT: int = 60

# --- 吸収シールド専用パラメータ (3.0s クールダウン＆超高速解析) ---
@export var gauge_shield_cooldown: float = 3.0 # 吸収パルス 1回展開で3秒クールダウン
var gauge_shield_timer: float = 0.0

var shield_heat: float = 0.0
var overheat_timer: float = 0.0
var is_overheated: bool = false

# --- 攻撃パターン解析＆変異スロットシステム (最大2枠固定＆上限Lv5集中強化) ---
const MAX_TRAIT_SLOTS: int = 2
var active_traits: Array[String] = [] # 現在固定装備中の最大2つの属性キー

var analysis_patterns: Dictionary = {
	PATTERN_RAPID:   { "progress": 0.0, "analyzed": false, "level": 0, "max_level": 5, "name": "高速連射", "icon": "", "color": Color(0.3, 0.8, 1.0) },
	PATTERN_SPREAD:  { "progress": 0.0, "analyzed": false, "level": 0, "max_level": 5, "name": "拡散射撃", "icon": "◈", "color": Color(0.2, 1.0, 0.6) },
	PATTERN_PIERCE:  { "progress": 0.0, "analyzed": false, "level": 0, "max_level": 5, "name": "貫通重弾", "icon": "▲", "color": Color(1.0, 0.6, 0.2) },
	PATTERN_HOMING:  { "progress": 0.0, "analyzed": false, "level": 0, "max_level": 5, "name": "誘導ミサイル", "icon": "▶", "color": Color(0.85, 0.45, 1.0) },
	PATTERN_LASER:   { "progress": 0.0, "analyzed": false, "level": 0, "max_level": 5, "name": "フォトン光線", "icon": "━", "color": Color(0.4, 0.9, 1.0) },
	PATTERN_CYCLONE: { "progress": 0.0, "analyzed": false, "level": 0, "max_level": 5, "name": "旋回スピン", "icon": "◎", "color": Color(1.0, 0.85, 0.2) },
	PATTERN_METEOR:  { "progress": 0.0, "analyzed": false, "level": 0, "max_level": 5, "name": "ギガメテオ", "icon": "●", "color": Color(1.0, 0.35, 0.2) },
	PATTERN_THUNDER: { "progress": 0.0, "analyzed": false, "level": 0, "max_level": 5, "name": "電撃連鎖", "icon": "", "color": Color(0.95, 0.9, 0.2) },
	PATTERN_VORTEX:  { "progress": 0.0, "analyzed": false, "level": 0, "max_level": 5, "name": "重力特異点", "icon": "", "color": Color(0.75, 0.3, 1.0) },
	PATTERN_BLADE:   { "progress": 0.0, "analyzed": false, "level": 0, "max_level": 5, "name": "真空斬撃", "icon": "", "color": Color(0.2, 1.0, 0.85) }
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
	max_hp = 500 + 60 * hp_lvl
	current_hp = max_hp
	is_invincible = false
	invincibility_timer = 0.0
	
	parry_window_radius = Global.get_just_guard_radius()
	
	is_attack_unlocked = false
	power_shield_damage_buff = 0.0
	is_full_burst = false
	is_guarding = false
	active_timer = 0.0
	guard_recovery_timer = 0.0
	parry_succeeded_in_guard = false
	parry_ring_radius = 0.0
	parry_ring_alpha = 0.0
	parry_shockwave_radius = 0.0
	parry_shockwave_alpha = 0.0
	parry_hex_alpha = 0.0
	parry_hex_scale = 1.0
	parry_sparks.clear()
	consecutive_parries = 0
	
	shield_heat = 0.0
	overheat_timer = 0.0
	is_overheated = false
	gauge_shield_timer = 0.0
	is_control_locked = false
	is_victory_flyby = false
	flyby_boost_alpha = 0.0
	flyby_timer = 0.0
	
	# COUNTER SYSTEM 状態・支援砲台の完全初期化
	set_meta("is_counter_system_used", false)
	for t in counter_system_turrets:
		if is_instance_valid(t):
			t.queue_free()
	counter_system_turrets.clear()
	for t in get_tree().get_nodes_in_group("support_turrets"):
		if is_instance_valid(t):
			t.queue_free()
	
	# 弾の解析・進化状態の完全初期化
	active_traits.clear()
	for key in analysis_patterns.keys():
		analysis_patterns[key]["progress"] = 0.0
		analysis_patterns[key]["analyzed"] = false
		analysis_patterns[key]["level"] = 0
	
	apply_equipped_weapon_settings()
	
	var main_ui_sync = get_node_or_null("/root/Main")
	if main_ui_sync:
		var ui_node = main_ui_sync.get_node_or_null("UI")
		if ui_node:
			if ui_node.has_method("update_equipped_weapon_hud"):
				ui_node.update_equipped_weapon_hud(Global.equipped_weapon)
			if ui_node.has_method("reset_counter_system_ui"):
				ui_node.reset_counter_system_ui()
			if ui_node.has_method("update_pattern_analysis"):
				ui_node.update_pattern_analysis(analysis_patterns, active_traits)
	
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
			fire_rate = 0.40 # 3点バーストライフル
		WEAPON_PULSE_GUN:
			fire_rate = 0.26 # パルス波動砲
		WEAPON_PLASMA_EMITTER:
			fire_rate = 0.36 # 高熱プラズマ放射器
		WEAPON_KINETIC_TACKLE:
			fire_rate = 0.50 # キネティック衝撃タックル
		_:
			fire_rate = 0.25
			
	var r_lvl = analysis_patterns[PATTERN_RAPID]["level"]
	if r_lvl > 0:
		var reduction = clamp(0.10 * r_lvl, 0.0, 0.50)
		fire_rate *= (1.0 - reduction)


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
	spawn_popup_message("主兵装切替: 【%s】" % w_name)
	
	var main = get_node_or_null("/root/Main")
	if main:
		var ui_node = main.get_node_or_null("UI")
		if ui_node and ui_node.has_method("update_equipped_weapon_hud"):
			ui_node.update_equipped_weapon_hud(new_weapon)


func lock_controls() -> void:
	is_control_locked = true
	is_guarding = false
	is_attack_unlocked = false
	is_full_burst = false
	is_invincible = true
	velocity = Vector2.ZERO


func _process(delta: float) -> void:
	if is_control_locked or is_victory_flyby:
		if is_victory_flyby:
			flyby_timer += delta
			queue_redraw()
		return

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
	
	# 主兵装は常時フルオート連射（COUNTER ONLYモード時のみ射撃制限）
	if is_attack_unlocked and not Global.counter_only_mode_enabled:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_fire_time > fire_rate:
			fire()
			last_fire_time = current_time
	
	if active_timer > 0.0:
		active_timer -= delta
		if active_timer <= 0.0:
			is_guarding = false
			if not parry_succeeded_in_guard and Global.equipped_shield != SHIELD_GAUGE:
				guard_recovery_timer = 0.24 # 空振りによる隙（カウンター被弾リスク）
				shield_heat = min(max_shield_heat, shield_heat + 6.0) # 空振りペナルティ発熱
				
	if guard_recovery_timer > 0.0:
		guard_recovery_timer -= delta
			
	# --- 吸収シールドのクールダウン管理 (3秒CT) ---
	if gauge_shield_timer > 0.0:
		var prev_gt = gauge_shield_timer
		gauge_shield_timer = max(0.0, gauge_shield_timer - delta)
		if prev_gt > 0.0 and gauge_shield_timer == 0.0:
			spawn_popup_message("吸収パルス充填完了！ READY")
			trigger_screen_flash(Color(0.1, 1.0, 0.6, 0.25))

	if is_overheated:
		overheat_timer -= delta
		shield_heat = (overheat_timer / overheat_cooldown) * max_shield_heat
		if overheat_timer <= 0.0:
			overheat_timer = 0.0
			shield_heat = 0.0
			is_overheated = false
			spawn_popup_message("シールド完全冷却完了！防御フィールド復旧")
			trigger_screen_flash(Color.CYAN)
	else:
		if not is_guarding and shield_heat > 0.0:
			shield_heat = max(0.0, shield_heat - heat_recovery_rate * delta)

	# --- パリィ火花スパーク粒子の更新 ---
	if parry_sparks.size() > 0:
		var remaining: Array[Dictionary] = []
		for p in parry_sparks:
			p["pos"] = p.get("pos", Vector2.ZERO) + p.get("vel", Vector2.ZERO) * delta
			var life = p.get("life", 0.0) - delta
			p["life"] = life
			var max_l = p.get("max_life", 0.3)
			p["alpha"] = clamp(life / max_l, 0.0, 1.0)
			if life > 0.0:
				remaining.append(p)
		parry_sparks = remaining
		queue_redraw()

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
	
	# --- シールド展開入力 (Spaceキー) ---
	if space_just_pressed:
		if Global.equipped_shield == SHIELD_GAUGE:
			# 吸収マトリクス: 1回展開で3.0秒クールダウン（超高速解析＆修復のピーキー仕様）
			if gauge_shield_timer > 0.0:
				spawn_popup_message("[RECHARGE] 吸収パルス充填中... (残り %.1fs)" % gauge_shield_timer)
			else:
				is_guarding = true
				active_timer = 0.35 # 0.35秒の瞬間パルス展開
				gauge_shield_timer = gauge_shield_cooldown # 3.0秒クールダウン開始
				guard_recovery_timer = 0.0
				parry_succeeded_in_guard = false
				parried_in_current_frame = false
				Global.play_guard(1.3)
				trigger_screen_flash(Color(0.1, 1.0, 0.6, 0.35))
				trigger_parry_ring_effect(Color(0.1, 1.0, 0.6))
				spawn_popup_message("吸収パルスフィールド展開！")
		else:
			# 通常 / カウンター / パワーシールド (ヒート制)
			if is_overheated:
				spawn_popup_message("シールド過熱冷却中！(装甲脆弱・被ダメ1.6倍)")
			elif shield_heat < max_shield_heat:
				is_guarding = true
				active_timer = parry_active_time
				guard_recovery_timer = 0.0
				parry_succeeded_in_guard = false
				shield_heat += heat_per_use
				parried_in_current_frame = false
				Global.play_guard(1.0)
				
				if shield_heat >= max_shield_heat:
					shield_heat = max_shield_heat
					is_overheated = true
					overheat_timer = overheat_cooldown
					is_guarding = false
					trigger_screen_flash(Color(1.0, 0.2, 0.2, 0.5))
					spawn_popup_message("シールドオーバーヒート！装甲脆弱化 (被ダメ 1.6倍)")
	
	if is_guarding:
		check_parry()
	
	update_visual_state()
	
	if parry_ring_alpha > 0.0 or parry_shockwave_alpha > 0.0 or parry_hex_alpha > 0.0 or parry_sparks.size() > 0:
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
				spawn_popup_message("危険: SPACEでジャストガードを実行！")
		else:
			if Engine.time_scale < 0.5 and not is_guarding:
				Engine.time_scale = 1.0

	# COUNTER SYSTEM 手動発動 (Xキー)
	if not is_full_burst and not get_meta("is_counter_system_used", false):
		if Input.is_key_pressed(KEY_X) or Input.is_action_just_pressed("ui_focus_next"):
			set_meta("is_counter_system_used", true)
			activate_counter_system()

	# ジャストガード有効範囲リングの常時プロット再描画
	queue_redraw()


func activate_counter_system() -> void:
	if is_full_burst:
		return
	is_full_burst = true
	
	var duration = Global.get_counter_system_duration()
	var dmg_mult = Global.get_counter_system_power_multiplier()
	
	spawn_popup_message("[COUNTER SYSTEM ONLINE] 支援砲台部隊 展開！ (%.0fs / %.1fx)" % [duration, dmg_mult])
	
	# 全画面プレイヤーカラーフィルター＆専用HUDの起動
	var main_node = get_node_or_null("/root/Main")
	if main_node:
		var ui_node = main_node.get_node_or_null("UI")
		if ui_node and ui_node.has_method("activate_counter_system_tint"):
			ui_node.activate_counter_system_tint(duration)
			
	# 支援ボスタレットポッドの召喚
	var main_parent = get_parent()
	var num_turrets = 4 if Global.counter_only_mode_enabled else 2
	for i in range(num_turrets):
		var turret = PlayerSupportTurret.new()
		turret.setup_turret(self, i, num_turrets, duration, dmg_mult)
		turret.global_position = global_position + Vector2((i - 0.5) * 60.0, 30.0)
		if main_parent:
			main_parent.add_child(turret)
			counter_system_turrets.append(turret)
			
	Global.play_explosion(1.2)
	
	get_tree().create_timer(duration).timeout.connect(func():
		is_full_burst = false
		counter_system_turrets.clear()
		if is_instance_valid(self) and current_hp > 0:
			spawn_popup_message("COUNTER SYSTEM: 支援部隊帰還")
			# COUNTER ONLY MODE なら 2.0秒後に自動再展開！
			if Global.counter_only_mode_enabled:
				get_tree().create_timer(2.0).timeout.connect(func():
					if is_instance_valid(self) and current_hp > 0:
						activate_counter_system()
				)
	)


func fire() -> void:
	# COUNTER ONLY MODE 出撃時は手動主兵装射撃をスキップ（砲台部隊専任モード）
	if Global.counter_only_mode_enabled:
		return
		
	if current_hp <= 0 or not is_attack_unlocked or not PLAYER_BULLET_SCENE:
		return
		
	var player_bullets_container = get_node_or_null("/root/Main/PlayerBullets")
	var target_parent = player_bullets_container if player_bullets_container else get_parent()
	
	# メイン武装の射撃実行（固定装備した2つの変異解析属性が直接融合強化される）
	fire_equipped_physics_weapon(target_parent)


func fire_equipped_physics_weapon(target_parent: Node) -> void:
	if current_hp <= 0 or not is_instance_valid(target_parent):
		return
		
	var is_rapid_active = active_traits.has(PATTERN_RAPID)
	var rapid_lvl = analysis_patterns[PATTERN_RAPID]["level"] if is_rapid_active else 0
	
	var is_spread_active = active_traits.has(PATTERN_SPREAD)
	var spread_lvl = analysis_patterns[PATTERN_SPREAD]["level"] if is_spread_active else 0
	
	var is_pierce_active = active_traits.has(PATTERN_PIERCE)
	var pierce_lvl = analysis_patterns[PATTERN_PIERCE]["level"] if is_pierce_active else 0
	
	var is_homing_active = active_traits.has(PATTERN_HOMING)
	var homing_lvl = analysis_patterns[PATTERN_HOMING]["level"] if is_homing_active else 0
	
	var is_laser_active = active_traits.has(PATTERN_LASER)
	var laser_lvl = analysis_patterns[PATTERN_LASER]["level"] if is_laser_active else 0
	
	var is_cyclone_active = active_traits.has(PATTERN_CYCLONE)
	var cyclone_lvl = analysis_patterns[PATTERN_CYCLONE]["level"] if is_cyclone_active else 0
	
	var is_meteor_active = active_traits.has(PATTERN_METEOR)
	var meteor_lvl = analysis_patterns[PATTERN_METEOR]["level"] if is_meteor_active else 0
	
	var is_thunder_active = active_traits.has(PATTERN_THUNDER)
	var thunder_lvl = analysis_patterns[PATTERN_THUNDER]["level"] if is_thunder_active else 0
	
	var is_vortex_active = active_traits.has(PATTERN_VORTEX)
	var vortex_lvl = analysis_patterns[PATTERN_VORTEX]["level"] if is_vortex_active else 0
	
	var is_blade_active = active_traits.has(PATTERN_BLADE)
	var blade_lvl = analysis_patterns[PATTERN_BLADE]["level"] if is_blade_active else 0
	
	var global_dmg_bonus = get_global_analysis_damage_bonus()
	
	# 融合強化パラメータの算出 (固定スロット装備中の2属性による直接強化)
	var speed_bonus = rapid_lvl * 160.0 + laser_lvl * 140.0
	var trait_dmg = pierce_lvl * 8 + laser_lvl * 10 + rapid_lvl * 5
	
	var p_limit = 0
	if is_pierce_active:
		if pierce_lvl == 1: p_limit = 1
		elif pierce_lvl == 2: p_limit = 2
		elif pierce_lvl == 3: p_limit = 4
		elif pierce_lvl == 4: p_limit = 7
		elif pierce_lvl >= 5: p_limit = 99
	
	var h_strength = 0.0
	if is_homing_active:
		if homing_lvl == 1: h_strength = 2.5
		elif homing_lvl == 2: h_strength = 4.8
		elif homing_lvl == 3: h_strength = 7.0
		elif homing_lvl == 4: h_strength = 9.2
		elif homing_lvl >= 5: h_strength = 12.0
	
	var w_amp = cyclone_lvl * 45.0 if is_cyclone_active else 0.0
	var exp_rad = meteor_lvl * 25.0 if is_meteor_active else 0.0
	var exp_dmg = meteor_lvl * 12 if is_meteor_active else 0
	var c_count = thunder_lvl * 2 if is_thunder_active else 0
	var c_dmg = thunder_lvl * 14 if is_thunder_active else 0
	var v_rad = vortex_lvl * 30.0 if is_vortex_active else 0.0
	var v_dmg = vortex_lvl * 10 if is_vortex_active else 0

	# 拡散パターンの角度＆オフセット生成 (拡散時はLv1〜5で同時発射数が2〜7発に増加！)
	var spread_angles = [0.0]
	var spread_offsets = [Vector2(0.0, -18.0)]
	if is_spread_active:
		if spread_lvl == 1:
			# Lv.1: 2発同時発射
			spread_angles = [-7.0, 7.0]
			spread_offsets = [Vector2(-10.0, -15.0), Vector2(10.0, -15.0)]
		elif spread_lvl == 2:
			# Lv.2: 3発同時発射
			spread_angles = [-11.0, 0.0, 11.0]
			spread_offsets = [Vector2(-14.0, -15.0), Vector2(0.0, -18.0), Vector2(14.0, -15.0)]
		elif spread_lvl == 3:
			# Lv.3: 4発同時発射
			spread_angles = [-15.0, -5.0, 5.0, 15.0]
			spread_offsets = [Vector2(-16.0, -15.0), Vector2(-6.0, -17.0), Vector2(6.0, -17.0), Vector2(16.0, -15.0)]
		elif spread_lvl == 4:
			# Lv.4: 5発同時発射
			spread_angles = [-18.0, -9.0, 0.0, 9.0, 18.0]
			spread_offsets = [Vector2(-18.0, -15.0), Vector2(-9.0, -17.0), Vector2(0.0, -20.0), Vector2(9.0, -17.0), Vector2(18.0, -15.0)]
		elif spread_lvl >= 5:
			# Lv.5: 7発同時超広角発射
			spread_angles = [-24.0, -16.0, -8.0, 0.0, 8.0, 16.0, 24.0]
			spread_offsets = [Vector2(-22.0, -14.0), Vector2(-15.0, -16.0), Vector2(-7.0, -18.0), Vector2(0.0, -20.0), Vector2(7.0, -18.0), Vector2(15.0, -16.0), Vector2(22.0, -14.0)]

	var eq_w = Global.equipped_weapon
	match eq_w:
		WEAPON_MACHINE_GUN:
			# マシンガン: 弾速・連射に優れるメイン機関砲（拡散でワイド化、速射高Lvで多連装ストリーム化）
			var default_offsets = [Vector2(-8.0, -15.0), Vector2(8.0, -15.0)]
			if rapid_lvl >= 3:
				default_offsets = [Vector2(-12.0, -15.0), Vector2(0.0, -18.0), Vector2(12.0, -15.0)]
			var offsets = spread_offsets if is_spread_active else default_offsets
			for i in range(offsets.size()):
				var deg = spread_angles[i % spread_angles.size()] if is_spread_active else 0.0
				var bullet = PLAYER_BULLET_SCENE.instantiate()
				bullet.bullet_type = "machine_gun"
				bullet.global_position = global_position + offsets[i]
				var base_spd = 1200.0 + speed_bonus
				bullet.speed = base_spd
				var dir = Vector2.UP.rotated(deg_to_rad(deg))
				bullet.velocity = dir * base_spd
				bullet.damage += trait_dmg + int(power_shield_damage_buff) + global_dmg_bonus
				bullet.pierce_limit = p_limit
				bullet.homing_strength = h_strength
				bullet.wave_amp = w_amp
				bullet.explosion_radius = exp_rad
				bullet.explosion_dmg = exp_dmg
				bullet.chain_count = c_count
				bullet.chain_damage = c_dmg
				bullet.vortex_radius = v_rad
				bullet.vortex_dmg = v_dmg
				bullet.is_blade = is_blade_active
				bullet.blade_lvl = blade_lvl
				if laser_lvl >= 1:
					bullet.modulate = Color(0.4, 0.9, 1.0)
				target_parent.add_child(bullet)

		WEAPON_BURST_RIFLE:
			# ライフル: 徹甲精密バースト（速射で連射数増加、拡散で扇状拡散弾幕化）
			var burst_waves = 3 + rapid_lvl
			var angles_to_fire = spread_angles if is_spread_active else [0.0]
			var offsets_to_fire = spread_offsets if is_spread_active else [Vector2(0, -22.0)]
			
			for wave in range(burst_waves):
				get_tree().create_timer(wave * 0.05).timeout.connect(func():
					if is_instance_valid(self) and current_hp > 0 and is_instance_valid(target_parent):
						for idx in range(offsets_to_fire.size()):
							var deg = angles_to_fire[idx % angles_to_fire.size()]
							var offset = offsets_to_fire[idx]
							var bullet = PLAYER_BULLET_SCENE.instantiate()
							bullet.bullet_type = "burst_rifle"
							bullet.global_position = global_position + offset
							var base_spd = 1500.0 + speed_bonus
							bullet.speed = base_spd
							bullet.velocity = Vector2.UP.rotated(deg_to_rad(deg)) * base_spd
							bullet.damage += trait_dmg + int(power_shield_damage_buff) + global_dmg_bonus
							bullet.pierce_limit = max(p_limit, 1 + pierce_lvl) # ライフル固有貫通力
							bullet.homing_strength = h_strength
							bullet.wave_amp = w_amp * 0.5
							bullet.explosion_radius = exp_rad
							bullet.explosion_dmg = exp_dmg
							bullet.chain_count = c_count
							bullet.chain_damage = c_dmg
							bullet.vortex_radius = v_rad
							bullet.vortex_dmg = v_dmg
							bullet.is_blade = is_blade_active
							bullet.blade_lvl = blade_lvl
							if laser_lvl >= 1:
								bullet.modulate = Color(1.0, 0.6, 0.2)
							target_parent.add_child(bullet)
				)

		WEAPON_PULSE_GUN:
			# パルスガン: 拡散プラズマ波動（拡散Lvに応じて全方位・大輪パルス化）
			var angles = spread_angles if is_spread_active else [-10.0, 10.0]
			var offsets = spread_offsets if is_spread_active else [Vector2(-8.0, -15.0), Vector2(8.0, -15.0)]
			for idx in range(offsets.size()):
				var angle_deg = angles[idx % angles.size()]
				var bullet = PLAYER_BULLET_SCENE.instantiate()
				bullet.bullet_type = "pulse"
				bullet.global_position = global_position + offsets[idx]
				var base_spd = 950.0 + speed_bonus
				bullet.speed = base_spd
				var dir = Vector2.UP.rotated(deg_to_rad(angle_deg))
				bullet.velocity = dir * base_spd
				bullet.damage += trait_dmg + int(power_shield_damage_buff) + global_dmg_bonus
				bullet.pierce_limit = max(p_limit, 1) # パルスは群れを貫通
				bullet.homing_strength = h_strength
				bullet.wave_amp = w_amp
				bullet.explosion_radius = max(exp_rad, 25.0) if is_meteor_active else 0.0
				bullet.explosion_dmg = exp_dmg
				bullet.chain_count = c_count
				bullet.chain_damage = c_dmg
				bullet.vortex_radius = v_rad
				bullet.vortex_dmg = v_dmg
				bullet.is_blade = is_blade_active
				bullet.blade_lvl = blade_lvl
				target_parent.add_child(bullet)

		WEAPON_PLASMA_EMITTER:
			# プラズマ放射器: 高熱エネルギー大玉球（拡散時は扇状ワイドに大玉マルチ放射！）
			var angles = spread_angles if is_spread_active else [0.0]
			var offsets = spread_offsets if is_spread_active else [Vector2(0, -20.0)]
			for idx in range(offsets.size()):
				var deg = angles[idx % angles.size()] if is_spread_active else 0.0
				var offset = offsets[idx]
				var bullet = PLAYER_BULLET_SCENE.instantiate()
				bullet.bullet_type = "plasma"
				bullet.global_position = global_position + offset
				var base_spd = 650.0 + speed_bonus
				bullet.speed = base_spd
				var dir = Vector2.UP.rotated(deg_to_rad(deg))
				bullet.velocity = dir * base_spd
				bullet.damage += trait_dmg + int(power_shield_damage_buff) + global_dmg_bonus
				bullet.pierce_limit = 99 # プラズマは持続貫通
				bullet.homing_strength = h_strength
				bullet.wave_amp = w_amp * 0.5
				bullet.explosion_radius = max(exp_rad, 55.0 + meteor_lvl * 18.0 + spread_lvl * 8.0)
				bullet.explosion_dmg = exp_dmg
				bullet.chain_count = c_count
				bullet.chain_damage = c_dmg
				bullet.vortex_radius = v_rad
				bullet.vortex_dmg = v_dmg
				bullet.is_blade = is_blade_active
				bullet.blade_lvl = blade_lvl
				target_parent.add_child(bullet)

		WEAPON_KINETIC_TACKLE:
			# タックル: キネティック衝撃破砕波（拡散で超ワイド破砕領域形成）
			var angles = spread_angles if is_spread_active else [0.0]
			var offsets = spread_offsets if is_spread_active else [Vector2(0, -30.0)]
			for i in range(offsets.size()):
				var deg = angles[i % angles.size()]
				var offset = offsets[i]
				var bullet = PLAYER_BULLET_SCENE.instantiate()
				bullet.bullet_type = "tackle"
				bullet.global_position = global_position + offset
				var base_spd = 900.0 + speed_bonus
				bullet.speed = base_spd
				bullet.velocity = Vector2.UP.rotated(deg_to_rad(deg)) * base_spd
				bullet.damage += trait_dmg + int(power_shield_damage_buff) + global_dmg_bonus
				bullet.pierce_limit = 99
				bullet.homing_strength = h_strength * 0.5
				bullet.wave_amp = w_amp
				bullet.explosion_radius = max(exp_rad, 75.0 + meteor_lvl * 20.0 + spread_lvl * 10.0)
				bullet.explosion_dmg = exp_dmg
				bullet.chain_count = c_count
				bullet.chain_damage = c_dmg
				bullet.vortex_radius = v_rad
				bullet.vortex_dmg = v_dmg
				bullet.is_blade = is_blade_active
				bullet.blade_lvl = blade_lvl
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
	parry_window_radius = Global.get_just_guard_radius()
	var focus_dmg_mult = Global.get_just_guard_damage_multiplier()
	
	var all_targets = []
	all_targets.append_array(enemy_bullets)
	for p in get_tree().get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(p) and not all_targets.has(p):
			all_targets.append(p)
	
	var last_parry_pos = global_position
	for bullet in all_targets:
		if is_instance_valid(bullet) and not bullet.is_friendly:
			# ジャストガード不可弾は跳ね返し判定を完全にスキップ
			var is_unparryable = bullet.get("is_unparryable") == true or (bullet.get("bullet_type") != null and String(bullet.get("bullet_type")).contains("unparryable"))
			if is_unparryable:
				continue
				
			var dist = global_position.distance_to(bullet.global_position)
			if dist <= parry_window_radius:
				last_parry_pos = bullet.global_position
				if not is_attack_unlocked:
					is_attack_unlocked = true
					if Global.is_first_launch:
						Global.is_first_launch = false
						Engine.time_scale = 1.0
						spawn_popup_message("ジャストガード成功！武装システムオンライン！")
						
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
					analysis_pts = 16.0 # 巨大隕石ジャストガードは+16%
				elif b_type.contains("decel") or b_type.contains("boss_missile"):
					analysis_pts = 10.0 # 追尾ミサイルジャストガードは+10%
				elif b_type.contains("boss_laser") or b_type.contains("beam"):
					analysis_pts = 8.0  # ビームマシンガンジャストガードは+8%
					
				advance_analysis(b_type, analysis_pts)
				
				if shield_type == SHIELD_POWER:
					# パワーシールド: 弾を吸収し主兵装ダメージ永続加算 (バフ量2倍UP)
					if bullet.has_method("recycle_bullet"):
						bullet.recycle_bullet()
					elif bullet.has_method("explode_and_free"):
						bullet.explode_and_free()
					else:
						bullet.queue_free()
					power_shield_damage_buff = min(power_shield_damage_buff + 8.0 * focus_dmg_mult, 50.0)
					
					var main = get_node_or_null("/root/Main")
					if main:
						var manager = main.get_node_or_null("GameManager")
						if manager and manager.has_method("register_parry"):
							manager.register_parry()
				elif shield_type == SHIELD_GAUGE:
					# 吸収マトリクス: 弾丸を直接吸収消滅
					if bullet.has_method("recycle_bullet"):
						bullet.recycle_bullet()
					elif bullet.has_method("explode_and_free"):
						bullet.explode_and_free()
					else:
						bullet.queue_free()
					
					var main = get_node_or_null("/root/Main")
					if main:
						var manager = main.get_node_or_null("GameManager")
						if manager and manager.has_method("register_parry"):
							manager.register_parry()
				else:
					# カウンターシールド / 通常シールド: 弾丸を友軍弾に変換して超威力反射
					if bullet.has_method("convert_to_friendly"):
						bullet.convert_to_friendly()
					if "damage" in bullet:
						bullet.damage += get_global_analysis_damage_bonus() * 2
						if shield_type == SHIELD_COUNTER:
							bullet.damage = int(bullet.damage * 2.5 * focus_dmg_mult)
						
				parry_triggered_now = true
				
	if parry_triggered_now and not parried_in_current_frame:
		parried_in_current_frame = true
		consecutive_parries += 1
		trigger_parry_feedback(last_parry_pos)


func take_damage(amount: int, is_guard_break: bool = false) -> void:
	if is_invincible:
		return
		
	# 通常のガード展開中は被弾無効（ただしパリィ不可攻撃やガードブレイクは貫通）
	if is_guarding and not is_guard_break:
		return
		
	if Global.is_first_launch and Engine.time_scale < 0.5:
		Engine.time_scale = 1.0
		
	var dmg_multiplier: float = 1.0
	var alert_text: String = ""
	var is_critical_hit: bool = false
	
	# ① パリィ不可弾直撃 / ガードブレイク (1.75倍 -> 1.20倍に緩和)
	if is_guard_break or (is_guarding and is_guard_break):
		dmg_multiplier = 1.20
		is_critical_hit = true
		alert_text = "GUARD BREAK! -%d"
		is_guarding = false
		if Global.equipped_shield != SHIELD_GAUGE:
			is_overheated = true
			overheat_timer = overheat_cooldown * 0.75
			shield_heat = max_shield_heat
	# ② オーバーヒート中の被弾 (1.60倍 -> 1.15倍に緩和)
	elif is_overheated:
		dmg_multiplier = 1.15
		is_critical_hit = true
		alert_text = "OVERHEAT HIT! -%d"
	# ③ ガード隙（リカバリー硬直中）の被弾 (1.50倍 -> 1.10倍に緩和)
	elif guard_recovery_timer > 0.0:
		dmg_multiplier = 1.10
		is_critical_hit = true
		alert_text = "COUNTER HIT! -%d"
		
	var final_damage = int(amount * dmg_multiplier)
	current_hp -= final_damage
	consecutive_parries = 0 # 被弾でコンボリセット
	guard_recovery_timer = 0.0
	
	if alert_text != "":
		spawn_popup_message(alert_text % final_damage)
		
	if is_critical_hit:
		Global.play_heavy_hit(0.75)
		trigger_screen_flash(Color(1.0, 0.05, 0.05, 0.65))
	else:
		Global.play_hit(0.85)
		trigger_screen_flash(Color(1.0, 0.0, 0.0, 0.4))
		
	if current_hp <= 0:
		current_hp = 0
		is_attack_unlocked = false
		is_guarding = false
		velocity = Vector2.ZERO
	else:
		# 被弾無敵時間 (1.4秒) を付与して多段ヒット即死を防止
		is_invincible = true
		invincibility_timer = invincible_duration


func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)


func advance_analysis(bullet_type: String, amount: float = 12.0) -> void:
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
		"thunder", "spark", "electric", "storm":
			pattern_key = PATTERN_THUNDER
		"vortex", "blackhole", "gravity":
			pattern_key = PATTERN_VORTEX
		"blade", "slash", "cutter":
			pattern_key = PATTERN_BLADE
		"straight", "rapid", _:
			pattern_key = PATTERN_RAPID
		
	var actual_amount = amount
	if Global.equipped_shield == SHIELD_GAUGE:
		actual_amount *= 3.0 # 吸収シールドは通常の3倍の超高速解析！
		
	# 【解析仕様】
	# 1. 最初の2種決定前（スロットが0枠または1枠のとき）:
	#    パリィした弾の属性ゲージを直接加算（100%でスロットに固定登録）
	if active_traits.size() < MAX_TRAIT_SLOTS:
		add_pattern_analysis(pattern_key, actual_amount)
	else:
		# 2. スロット2種決定後:
		#    ・同じ種類の弾 (スロット登録済みの属性): ゲージが大きく溜まる（高効率 100%）
		#    ・別の種類の弾 (スロット未登録の属性): 登録済みの2種に少量ずつ均等ボーナス蓄積（中効率 35%）
		if active_traits.has(pattern_key):
			add_pattern_analysis(pattern_key, actual_amount)
		else:
			var sub_amount = actual_amount * 0.35
			for t_key in active_traits:
				add_pattern_analysis(t_key, sub_amount)


func get_total_analysis_level() -> int:
	var total = 0
	for p in analysis_patterns.values():
		total += p.get("level", 0)
	return total


func get_global_analysis_damage_bonus() -> int:
	# 全兵装共鳴強化: 解析レベル1毎に全攻撃力+5
	return get_total_analysis_level() * 5


func add_pattern_analysis(pattern_key: String, amount: float) -> void:
	if not pattern_key in analysis_patterns:
		return
		
	var data = analysis_patterns[pattern_key]
	var current_lvl = data["level"]
	if current_lvl >= data["max_level"]:
		return # 最大レベル到達時はこれ以上加算しない
		
	data["progress"] = min(100.0, data["progress"] + amount)
	
	# 自機頭上にリアルタイム解析進捗ポップアップを表示
	spawn_analysis_progress_popup(data.get("name", "属性"), amount, data["progress"], data.get("color", Color.CYAN))
	
	if data["progress"] >= 100.0:
		data["progress"] = 0.0
		data["level"] += 1
		data["analyzed"] = true
		heal(50) # 解析完了時に機体修復 (+50 HP)
		Global.play_upgrade_success()
		
		# 画面中央＆頭上に [ANALYSIS COMPLETE] メッセージ
		spawn_popup_message("[ANALYSIS COMPLETE] 『%s』Lv.%d 獲得・主兵装融合" % [data.get("name", "兵装"), data["level"]])
		
		# 初めて入手・解放された解析兵装のチェック
		var is_first_discovery = false
		if not Global.discovered_analysis_weapons.has(pattern_key):
			Global.discovered_analysis_weapons.append(pattern_key)
			Global.save_game()
			is_first_discovery = true
			
		apply_pattern_trait(pattern_key)
		
		if is_first_discovery:
			var main = get_node_or_null("/root/Main")
			if main:
				var ui_node = main.get_node_or_null("UI")
				if ui_node:
					# 2. チュートリアル: 武器種（解放時・どのように解放されるかなどの概要）
					if not Global.tutorial_flags.get("weapon_analysis", false) and ui_node.has_method("show_tutorial_guide_modal"):
						ui_node.show_tutorial_guide_modal("weapon_analysis")
					elif ui_node.has_method("show_analysis_unlock_modal"):
						ui_node.show_analysis_unlock_modal(pattern_key, data)


func spawn_analysis_progress_popup(p_name: String, added: float, current_prog: float, p_color: Color) -> void:
	var label = Label.new()
	label.text = "[ANALYSIS] %s +%d%% (%d%%)" % [p_name, int(added), int(current_prog)]
	
	var settings = LabelSettings.new()
	if PIXEL_FONT:
		settings.font = PIXEL_FONT
	settings.font_size = 14
	settings.font_color = p_color
	settings.outline_size = 3
	settings.outline_color = Color(0.05, 0.08, 0.12, 0.95)
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.global_position = global_position + Vector2(-120, -50 + randf_range(-10, 10))
	label.custom_minimum_size = Vector2(240, 20)
	get_parent().add_child(label)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 32.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


func apply_pattern_trait(pattern_key: String) -> void:
	var data = analysis_patterns[pattern_key]
	var lvl = data["level"]
	
	# スロット固定装備判定 (最大2枠・上書きなし！)
	if not active_traits.has(pattern_key):
		if active_traits.size() < MAX_TRAIT_SLOTS:
			active_traits.append(pattern_key)
			if active_traits.size() == 2:
				var f_info = Global.get_fusion_info(active_traits[0], active_traits[1])
				spawn_popup_message("[FUSION COMPLETE] 融合兵装: 『%s』完成" % f_info.get("name", "融合兵装"))
			else:
				spawn_popup_message("[SLOT %d] %s Lv.%d" % [active_traits.size(), data["name"], lvl])
		else:
			# スロットが満杯の場合は絶対に上書きしない
			return
	
	# 全属性共鳴バフ適用（機体基本性能底上げ）
	var tot_lvl = get_total_analysis_level()
	move_speed = 300.0 + tot_lvl * 15.0
	
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
	spawn_big_levelup_banner(data["name"], lvl, data.get("icon", ""))
	
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
	label.text = "LEVEL UP!\n%s 【%s Lv.%d】 解放！" % [icon, trait_name, lvl]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var label_settings = LabelSettings.new()
	var pixel_font = preload("res://game/assets/fonts/DotGothic16-Regular.ttf")
	if pixel_font:
		label_settings.font = pixel_font
	label_settings.font_size = 24
	label_settings.font_color = Color.GOLD
	label_settings.outline_size = 8
	label_settings.outline_color = Color.BLACK
	label.label_settings = label_settings
	
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
	var container = PanelContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.09, 0.88)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.3, 0.75, 1.0, 0.8)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	container.add_theme_stylebox_override("panel", sb)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 4)
	container.add_child(margin)
	
	var label = Label.new()
	label.text = text
	var settings = LabelSettings.new()
	if PIXEL_FONT:
		settings.font = PIXEL_FONT
	settings.font_size = 18
	settings.font_color = Color.CYAN
	settings.outline_size = 4
	settings.outline_color = Color.BLACK
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	margin.add_child(label)
	
	container.global_position = global_position + Vector2(-170.0, -85.0)
	container.custom_minimum_size = Vector2(340.0, 32.0)
	
	var main = get_node_or_null("/root/Main")
	if main:
		main.add_child(container)
	else:
		get_parent().add_child(container)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(container, "global_position", container.global_position + Vector2(0.0, -50.0), 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(container, "modulate:a", 0.0, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(container.queue_free)


const PARRY_FX_SCENE: PackedScene = preload("res://game/effects/parry_fx.tscn")

func trigger_parry_feedback(hit_pos: Vector2 = Vector2.ZERO) -> void:
	Global.play_parry(randf_range(0.96, 1.04))
	trigger_screen_flash(Color(0.4, 0.95, 1.0, 0.6))
	trigger_hit_stop(0.10, 0.03) # ビタッと止まる極上ヒットストップ
	
	parry_succeeded_in_guard = true
	guard_recovery_timer = 0.0
	
	# 分離シーン（ParryFX）のインスタンス化
	var actual_origin = hit_pos if hit_pos != Vector2.ZERO else global_position + Vector2(0, -15.0)
	var parent_node = get_parent()
	if PARRY_FX_SCENE and parent_node:
		var pfx = PARRY_FX_SCENE.instantiate()
		var col = Color(0.3, 0.95, 1.0)
		if Global.equipped_shield == SHIELD_GAUGE:
			col = Color(0.2, 1.0, 0.6)
		elif Global.equipped_shield == SHIELD_POWER:
			col = Color(1.0, 0.6, 0.2)
		pfx.setup_parry(actual_origin, parry_window_radius, col)
		parent_node.add_child(pfx)
	
	# パリィ成功時の回復ゲージ加算 (5回パリィでHP回復)
	add_parry_heal_progress()
	
	var popup_text = "JUST PARRY! [%d/%d]" % [parry_heal_counter, PARRY_HEAL_THRESHOLD]
	if Global.equipped_shield == SHIELD_GAUGE:
		popup_text = "ABSORB PARRY! [%d/%d]" % [parry_heal_counter, PARRY_HEAL_THRESHOLD]
	spawn_parry_popup_message(popup_text)


func add_parry_heal_progress() -> void:
	parry_heal_counter += 1
	var main = get_node_or_null("/root/Main")
	if main:
		var ui_node = main.get_node_or_null("UI")
		if ui_node and ui_node.has_method("update_parry_heal_gauge"):
			ui_node.update_parry_heal_gauge(parry_heal_counter, PARRY_HEAL_THRESHOLD)
			
	if parry_heal_counter >= PARRY_HEAL_THRESHOLD:
		parry_heal_counter = 0
		heal(PARRY_HEAL_AMOUNT)
		trigger_screen_flash(Color(0.2, 1.0, 0.5, 0.45))
		spawn_popup_message("PARRY HEAL! 機体修復 +%d HP" % PARRY_HEAL_AMOUNT)
		Global.play_upgrade_success()
		if main:
			var ui_node = main.get_node_or_null("UI")
			if ui_node and ui_node.has_method("update_parry_heal_gauge"):
				ui_node.update_parry_heal_gauge(0, PARRY_HEAL_THRESHOLD)


func trigger_hit_stop(duration_sec: float, time_scale_val: float) -> void:
	Engine.time_scale = time_scale_val
	var timer = get_tree().create_timer(duration_sec * time_scale_val, true)
	timer.timeout.connect(func():
		Engine.time_scale = 1.0
	)


func trigger_parry_ring_effect(_color_override: Color = Color.TRANSPARENT) -> void:
	parry_ring_radius = 15.0
	parry_ring_alpha = 0.95
	parry_shockwave_radius = 20.0
	parry_shockwave_alpha = 0.90
	queue_redraw()
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "parry_ring_radius", parry_window_radius * 1.35, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "parry_ring_alpha", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "parry_shockwave_radius", parry_window_radius * 1.85, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "parry_shockwave_alpha", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func spawn_parry_popup_message(text: String) -> void:
	var label = Label.new()
	label.text = text
	
	var settings = LabelSettings.new()
	if PIXEL_FONT:
		settings.font = PIXEL_FONT
	settings.font_size = 28
	settings.font_color = Color.GOLD
	settings.outline_size = 6
	settings.outline_color = Color.BLACK
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	label.global_position = global_position + Vector2(-200.0, -85.0)
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
	tween.tween_property(label, "scale", Vector2(1.25, 1.25), 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0.0, -90.0), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var fade_tween = create_tween()
	fade_tween.tween_interval(0.4)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.6)
	
	tween.chain().tween_callback(label.queue_free)


func _draw() -> void:
	# 1. 常時プロット：ジャストガード有効判定範囲リング (Focus Tuning ＆ シールド別カラー)
	if current_hp > 0 and not is_victory_flyby:
		var cur_radius = Global.get_just_guard_radius()
		var s_type = Global.equipped_shield
		var shield_color = Color(0.35, 0.75, 1.0) # カウンター: シアン
		if s_type == SHIELD_GAUGE:
			shield_color = Color(0.2, 1.0, 0.6) # 吸収マトリクス: エメラルドグリーン
		elif s_type == SHIELD_POWER:
			shield_color = Color(1.0, 0.55, 0.15) # パワーシールド: ネオンオレンジ
			
		# 通常時は落ち着いた半透明、ガード展開中・被弾時は発光
		var base_alpha = 0.28 if not is_guarding else 0.85
		var pulse = sin(Time.get_ticks_msec() * 0.005) * 0.06
		var ring_alpha = clamp(base_alpha + pulse, 0.15, 0.95)
		
		# ガード展開中の内部エネルギーフィールド（半透明塗りつぶし）
		if is_guarding:
			draw_circle(Vector2.ZERO, cur_radius, Color(shield_color.r, shield_color.g, shield_color.b, 0.12))
			
		# 外郭プロットリング (高精度アーク描画)
		var line_w = 1.5 if not is_guarding else 2.5
		draw_arc(Vector2.ZERO, cur_radius, 0, TAU, 48, Color(shield_color.r, shield_color.g, shield_color.b, ring_alpha), line_w)
		
		# 4方向の照準プロットマーカー（サイバー目盛り）
		var marker_len = 5.0 if not is_guarding else 9.0
		for angle_deg in [0, 90, 180, 270]:
			var dir = Vector2.RIGHT.rotated(deg_to_rad(angle_deg))
			var p1 = dir * (cur_radius - marker_len)
			var p2 = dir * (cur_radius + marker_len)
			draw_line(p1, p2, Color(shield_color.r, shield_color.g, shield_color.b, ring_alpha * 1.2), line_w)

	# 勝利フライバイ時の巨大アフターバーナー炎描画
	if is_victory_flyby and flyby_boost_alpha > 0.0:
		var flame_len = (110.0 + sin(flyby_timer * 40.0) * 25.0) * flyby_boost_alpha
		var flame_w = (24.0 + sin(flyby_timer * 30.0) * 5.0) * flyby_boost_alpha
		var flame_col = Color(0.1, 0.7, 1.0, flyby_boost_alpha * 0.85)
		var mid_col = Color(0.4, 0.95, 1.0, flyby_boost_alpha * 0.95)
		var core_col = Color(1.0, 1.0, 1.0, flyby_boost_alpha)
		
		# 1. 最外郭ジェットプラズマ
		var outer_pts = PackedVector2Array([
			Vector2(-flame_w * 1.3, 12.0),
			Vector2(flame_w * 1.3, 12.0),
			Vector2(0.0, 12.0 + flame_len * 1.25)
		])
		draw_colored_polygon(outer_pts, Color(0.0, 0.4, 1.0, flyby_boost_alpha * 0.4))

		# 2. メインジェット炎
		var pts = PackedVector2Array([
			Vector2(-flame_w, 12.0),
			Vector2(flame_w, 12.0),
			Vector2(0.0, 12.0 + flame_len)
		])
		draw_colored_polygon(pts, flame_col)
		
		# 3. 中間高輝度炎
		var mid_pts = PackedVector2Array([
			Vector2(-flame_w * 0.65, 12.0),
			Vector2(flame_w * 0.65, 12.0),
			Vector2(0.0, 12.0 + flame_len * 0.75)
		])
		draw_colored_polygon(mid_pts, mid_col)
		
		# 4. 内側白熱コア炎
		var core_pts = PackedVector2Array([
			Vector2(-flame_w * 0.35, 12.0),
			Vector2(flame_w * 0.35, 12.0),
			Vector2(0.0, 12.0 + flame_len * 0.45)
		])
		draw_colored_polygon(core_pts, core_col)
		
		# 5. ジェットリング（ショックダイヤモンド光輪）
		for ring_i in range(3):
			var r_y = 12.0 + (ring_i + 1) * (flame_len * 0.22)
			var r_w = flame_w * (1.0 - ring_i * 0.25)
			draw_arc(Vector2(0, r_y), r_w, 0, TAU, 24, Color(1.0, 1.0, 1.0, flyby_boost_alpha * (0.8 - ring_i * 0.2)), 2.5)


func play_victory_flyby() -> void:
	is_invincible = true
	is_victory_flyby = true
	is_control_locked = true
	is_guarding = false
	is_attack_unlocked = false
	is_full_burst = false
	velocity = Vector2.ZERO
	modulate = Color.WHITE
	
	var vp_size = get_viewport_rect().size
	var center_x = vp_size.x / 2.0
	var prepare_pos = Vector2(center_x, vp_size.y * 0.76)
	var escape_pos = Vector2(center_x, -320.0)
	
	spawn_popup_message("FULL AFTERBURNER ONLINE: ACCELERATE!")
	
	var tween = create_tween()
	# 1. 画面中央下部へスムーズに位置合わせ (0.5秒)
	tween.tween_property(self, "global_position", prepare_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 2. アフターバーナー全開点火 (0.35秒)
	tween.tween_property(self, "flyby_boost_alpha", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_callback(func():
		Global.play_explosion(1.35)
		trigger_screen_flash(Color(0.3, 0.8, 1.0, 0.4))
	)
	tween.tween_interval(0.2)
	
	# 3. 上空へ向かって超高速急加速（大気圏・成層圏を突き抜けるフライバイ） (1.0秒)
	tween.tween_property(self, "global_position", escape_pos, 1.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	# ソニックブーム衝撃波リング＆パーティクルの連続放出
	tween.parallel().tween_callback(func():
		var p_scene = preload("res://game/bullets/parry_particle.tscn")
		var main_parent = get_parent()
		if not main_parent:
			return
			
		for i in range(12):
			get_tree().create_timer(i * 0.07).timeout.connect(func():
				if is_instance_valid(self) and is_instance_valid(main_parent):
					# ソニックブームリング
					ExplosionEffect.create(main_parent, global_position + Vector2(0, 30.0), 90.0, Color(0.3, 0.85, 1.0), 0.3)
					if p_scene:
						var p = p_scene.instantiate()
						p.global_position = global_position + Vector2(randf_range(-20, 20), 20.0)
						p.scale = Vector2(3.5, 3.5)
						p.modulate = Color(0.4, 0.9, 1.0)
						main_parent.add_child(p)
			)
	)


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
