extends CharacterBody2D
## プレイヤー機体スクリプト
## - 移動・パリィ捕獲・自動射撃・COUNTER制御

# --- 基本パラメータ ---
@export var max_hp: int = 500
@export var move_speed: float = 300.0
@export var parry_window_radius: float = 85.0  # パリィ判定範囲 (65 -> 85へ拡大)
@export var fire_rate: float = 0.2            # 射撃間隔
@export var parry_active_time: float = 0.28  # ガード持続時間
@export var invincible_duration: float = 0.8  # 被弾後の無敵時間（秒）

# 定数：フォント定義
const PIXEL_FONT: Font = preload("res://game/assets/fonts/DotGothic16-Regular.ttf")

@onready var parry_component: ParryComponent = $ParryComponent

# 定数：武器タイプ定義
const WEAPON_MACHINE_GUN = "machine_gun"
const WEAPON_BURST_RIFLE = "burst_rifle"
const WEAPON_PULSE_GUN = "pulse_gun"
const WEAPON_PLASMA_EMITTER = "plasma_emitter"
const WEAPON_KINETIC_TACKLE = "kinetic_tackle"

# 定数：シールドタイプ
const SHIELD_COUNTER = "counter"
const SHIELD_GAUGE = "gauge"
const SHIELD_POWER = "power"

# 定数：カラー定義
const COLOR_SHIELD_COUNTER = Color(0.8, 0.3, 1.0)
const COLOR_SHIELD_GAUGE = Color(0.1, 0.9, 0.5)
const COLOR_SHIELD_POWER = Color(1.0, 0.5, 0.0)
const COLOR_OVERHEAT = Color(1.0, 0.3, 0.3, 1.0)

# 定数：弾速・ダメージ

const PLAYER_SUPPORT_TURRET_SCRIPT: GDScript = preload("res://game/player/support_turret.gd")
const PLAYER_FUNNEL_UNIT_SCRIPT: GDScript = preload("res://game/player/player_funnel_unit.gd")
const PLAYER_GIGANTIC_ORB_SCRIPT: GDScript = preload("res://game/player/player_gigantic_orb.gd")
const PLAYER_COUNTER_BEAM_SCRIPT = preload("res://game/player/player_counter_beam.gd")
const PLAYER_CHAIN_SWEEP_SCRIPT: GDScript = preload("res://game/player/player_chain_sweep.gd")

var current_hp: int = 500
var last_fire_time: float = 0.0
var enemy_bullets: Array = []

var is_invincible: bool = false
var invincibility_timer: float = 0.0

var active_timer: float = 0.0
var is_guarding: bool = false
var space_was_pressed: bool = false

var is_attack_unlocked: bool = false
var attack_generation: int = 0

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
var victory_flyby_tween: Tween = null

# --- シールド・オーバーヒートシステム (リスク＆リターン調整) ---
@export var max_shield_heat: float = 100.0
@export var heat_per_use: float = 22.0        # 1回あたり22% (連続4回で過熱)
@export var heat_recovery_rate: float = 40.0   # 1秒で40%放熱
@export var overheat_cooldown: float = 2.2     # オーバーヒート2.2秒で復帰

# --- パリィ回復ゲージシステム (5回パリィでHP回復・シールド共通) ---
var parry_heal_counter: int = 0
const PARRY_HEAL_THRESHOLD: int = 5
const PARRY_HEAL_AMOUNT: int = 60

# --- 吸収シールド専用パラメータ (基本3.0秒の再展開時間) ---
@export var gauge_shield_cooldown: float = 3.0 # 吸収パルス 1回展開で3秒クールダウン
var gauge_shield_timer: float = 0.0

var shield_heat: float = 0.0
var overheat_timer: float = 0.0
var is_overheated: bool = false

var capture_volley: CaptureVolley
var power_boost_remaining: float = 0.0
const COUNTER_HEAT_REFUND: float = 8.0
const POWER_PULSE_RADIUS: float = 125.0
const POWER_PULSE_DAMAGE: int = 32
const POWER_PULSE_DURATION: float = 0.3
var power_pulse_remaining: float = 0.0
var power_pulse_origin: Vector2 = Vector2.ZERO

const PLAYER_BULLET_SCENE: PackedScene = preload("res://game/player/player_bullet.tscn")


func _ready() -> void:
	capture_volley = CaptureVolley.new()
	capture_volley.name = "CaptureVolley"
	add_child(capture_volley)
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
	attack_generation += 1
	precision_feedback_in_guard = false
	precision_flash_remaining = 0.0
	space_was_pressed = Input.is_key_pressed(Global.key_shield) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	apply_appearance()
	var hp_lvl = Global.upgrade_levels.get("hp", 0)
	max_hp = 500 + 60 * hp_lvl
	current_hp = max_hp
	is_invincible = false
	invincibility_timer = 0.0
	
	parry_window_radius = Global.get_just_guard_radius()
	
	# アフターバーナー等の進行中Tweenを強制停止
	if victory_flyby_tween and victory_flyby_tween.is_valid():
		victory_flyby_tween.kill()
		victory_flyby_tween = null
		
	# 自機座標・姿勢・透明度・移動状態の完全初期化 (画面中央下部へ復帰)
	var vp_w = get_viewport_rect().size.x
	global_position = Vector2(vp_w / 2.0 if vp_w > 0.0 else 400.0, 720.0)
	position = global_position
	velocity = Vector2.ZERO
	rotation = 0.0
	modulate = Color.WHITE
	visible = true
	
	is_attack_unlocked = true
	power_boost_remaining = 0.0
	power_pulse_remaining = 0.0
	if is_instance_valid(capture_volley):
		capture_volley.clear()
	last_fire_time = 0.0
	var cooling := clampi(int(Global.upgrade_levels.get("cooldown", 0)), 0, 5)
	heat_recovery_rate = 40.0 * (1.0 + cooling * 0.1)
	overheat_cooldown = 2.2 * (1.0 - cooling * 0.08)
	gauge_shield_cooldown = 3.0 * (1.0 - cooling * 0.08)
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
	parry_heal_counter = 0
	
	shield_heat = 0.0
	overheat_timer = 0.0
	is_overheated = false
	gauge_shield_timer = 0.0
	is_control_locked = false
	is_victory_flyby = false
	flyby_boost_alpha = 0.0
	flyby_timer = 0.0
	
	# COUNTER SYSTEM 状態・支援砲台の完全初期化
	set_meta("counter_key_was_pressed", false)
	for t in counter_system_turrets:
		if is_instance_valid(t):
			t.queue_free()
	counter_system_turrets.clear()
	for t in get_tree().get_nodes_in_group("support_turrets"):
		if is_instance_valid(t):
			t.queue_free()
	
	apply_equipped_weapon_settings()
	
	var main_ui_sync = get_node_or_null("/root/Main")
	if main_ui_sync:
		var ui_node = main_ui_sync.get_node_or_null("UI")
		if is_instance_valid(ui_node):
			if ui_node.has_method("update_player_hp"):
				ui_node.update_player_hp(current_hp, max_hp)
			if ui_node.has_method("update_equipped_weapon_hud"):
				ui_node.update_equipped_weapon_hud(Global.equipped_weapon)
			if ui_node.has_method("reset_counter_system_ui"):
				ui_node.reset_counter_system_ui()
			if ui_node.has_method("update_guard_heat"):
				ui_node.update_guard_heat(0.0, max_shield_heat, false, 0.0, false, Global.equipped_shield, 0.0, gauge_shield_cooldown)
			if ui_node.has_method("update_parry_count"):
				ui_node.update_parry_count(0)
	
func apply_equipped_weapon_settings() -> void:
	var spec: Dictionary = WeaponCatalog.PRIMARY.get(Global.equipped_weapon, WeaponCatalog.PRIMARY[WEAPON_MACHINE_GUN])
	fire_rate = float(spec["interval"])



func lock_controls() -> void:
	attack_generation += 1
	stop_counter_system()
	precision_flash_remaining = 0.0
	shield_heat = 0.0
	is_overheated = false
	overheat_timer = 0.0
	gauge_shield_timer = 0.0
	active_timer = 0.0
	guard_recovery_timer = 0.0
	is_control_locked = true
	power_boost_remaining = 0.0
	power_pulse_remaining = 0.0
	if is_instance_valid(capture_volley):
		capture_volley.clear()
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
	var move_preset = Global.control_move_preset
	var left_in = false
	var right_in = false
	var up_in = false
	var down_in = false
	
	if move_preset == 0: # Both WASD and Arrows
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): left_in = true
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): right_in = true
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): up_in = true
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): down_in = true
	elif move_preset == 1: # WASD only
		if Input.is_key_pressed(KEY_A): left_in = true
		if Input.is_key_pressed(KEY_D): right_in = true
		if Input.is_key_pressed(KEY_W): up_in = true
		if Input.is_key_pressed(KEY_S): down_in = true
	elif move_preset == 2: # Arrows only
		if Input.is_key_pressed(KEY_LEFT): left_in = true
		if Input.is_key_pressed(KEY_RIGHT): right_in = true
		if Input.is_key_pressed(KEY_UP): up_in = true
		if Input.is_key_pressed(KEY_DOWN): down_in = true
	elif move_preset == 3: # Custom
		if Input.is_key_pressed(Global.key_left): left_in = true
		if Input.is_key_pressed(Global.key_right): right_in = true
		if Input.is_key_pressed(Global.key_up): up_in = true
		if Input.is_key_pressed(Global.key_down): down_in = true
		
	if left_in: input_vector.x -= 1.0
	if right_in: input_vector.x += 1.0
	if up_in: input_vector.y -= 1.0
	if down_in: input_vector.y += 1.0
	
	velocity = input_vector.normalized() * move_speed
	move_and_slide()
	
	var viewport_size = get_viewport_rect().size
	position.x = clamp(position.x, 20.0, viewport_size.x - 20.0)
	position.y = clamp(position.y, 20.0, viewport_size.y - 20.0)
	
	precision_flash_remaining = maxf(precision_flash_remaining - delta, 0.0)
	power_boost_remaining = maxf(power_boost_remaining - delta, 0.0)
	power_pulse_remaining = maxf(power_pulse_remaining - delta, 0.0)
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
			spawn_popup_message("シールド READY")
			trigger_screen_flash(Color(0.1, 1.0, 0.6, 0.25))

	if is_overheated:
		overheat_timer -= delta
		shield_heat = (overheat_timer / overheat_cooldown) * max_shield_heat
		if overheat_timer <= 0.0:
			overheat_timer = 0.0
			shield_heat = 0.0
			is_overheated = false
			spawn_popup_message("シールド復旧")
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

	# --- シールド展開入力 (Space / カスタムキー) ---
	var shield_pressed = Input.is_key_pressed(Global.key_shield) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var space_just_pressed = shield_pressed and not space_was_pressed
	space_was_pressed = shield_pressed

	# --- シールド展開処理 ---
	if space_just_pressed:
		precision_feedback_in_guard = false
		if Global.equipped_shield == SHIELD_GAUGE:
			# 吸収マトリクス: 広い捕獲範囲とCOUNTER充填を優先する。
			if gauge_shield_timer > 0.0:
				spawn_popup_message("再展開まで %.1f秒" % gauge_shield_timer)
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
				spawn_popup_message("吸収シールド展開")
		else:
			# 通常 / カウンター / パワーシールド (ヒート制)
			if is_overheated:
				spawn_popup_message("オーバーヒート")
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
					spawn_popup_message("オーバーヒート")
	
	if is_guarding:
		check_parry()
	
	update_visual_state()
	
	if parry_ring_alpha > 0.0 or parry_shockwave_alpha > 0.0 or parry_hex_alpha > 0.0 or parry_sparks.size() > 0:
		queue_redraw()
		
	var cs_pressed := Input.is_key_pressed(Global.key_counter_system)
	var cs_just_pressed: bool = cs_pressed and not get_meta("counter_key_was_pressed", false)
	set_meta("counter_key_was_pressed", cs_pressed)
	if cs_just_pressed:
		var manager = get_node_or_null("/root/Main/GameManager")
		if manager:
			manager.request_counter_activation()

	# ジャストガード有効範囲リングの常時プロット再描画
	queue_redraw()


func get_counter_duration() -> float:
	var duration := Global.get_counter_system_duration()
	match Global.equipped_counter_weapon:
		"chain_explosions": return duration * 0.15
		"boss_beam": return duration * 0.6
		"gigantic_orb": return minf(duration, maxf((global_position.y + 70.0) / 220.0, 0.4))
	return duration

func activate_counter_system(duration: float) -> void:
	stop_counter_system()
	is_full_burst = true
	var multiplier := Global.get_counter_system_power_multiplier()
	var kind := Global.equipped_counter_weapon
	var parent := get_parent()
	match kind:
		"funnel":
			for index in range(4):
				var unit = PLAYER_FUNNEL_UNIT_SCRIPT.new()
				unit.setup_funnel(self, index, 4, duration, multiplier)
				unit.global_position = global_position
				parent.add_child(unit)
				counter_system_turrets.append(unit)
		"gigantic_orb":
			var orb = PLAYER_GIGANTIC_ORB_SCRIPT.new()
			orb.setup_orb(global_position + Vector2(0, -50), duration, multiplier)
			parent.add_child(orb)
			counter_system_turrets.append(orb)
		"chain_explosions":
			var sweep = PLAYER_CHAIN_SWEEP_SCRIPT.new()
			sweep.setup_sweep(self, duration, multiplier)
			parent.add_child(sweep)
			counter_system_turrets.append(sweep)
		"boss_beam":
			var beam = PLAYER_COUNTER_BEAM_SCRIPT.new()
			beam.setup(self, multiplier)
			parent.add_child(beam)
			counter_system_turrets.append(beam)
		_:
			for index in range(2):
				var turret = PLAYER_SUPPORT_TURRET_SCRIPT.new()
				turret.weapon_mode = kind
				turret.setup_turret(self, index, 2, duration, multiplier)
				turret.global_position = global_position + Vector2((index - 0.5) * 120, 10)
				parent.add_child(turret)
				counter_system_turrets.append(turret)
	spawn_popup_message("COUNTER 発動")
	var ui = get_node_or_null("/root/Main/UI")
	if ui:
		ui.activate_counter_system_tint(duration)
	Global.play_explosion(1.2)

func stop_counter_system() -> void:
	is_full_burst = false
	for entity in counter_system_turrets:
		if is_instance_valid(entity):
			entity.set_process(false)
			entity.queue_free()
	counter_system_turrets.clear()
	for bullet in get_tree().get_nodes_in_group("counter_projectiles"):
		if bullet.has_method("recycle_bullet"):
			bullet.recycle_bullet()
		else:
			bullet.set_process(false)
			bullet.queue_free()
	var ui = get_node_or_null("/root/Main/UI")
	if is_instance_valid(ui) and ui.is_node_ready():
		ui.reset_counter_system_ui()

func fire() -> void:
	# COUNTER ONLY MODE 出撃時は手動主兵装射撃をスキップ（砲台部隊専任モード）
	if Global.counter_only_mode_enabled:
		return
		
	if current_hp <= 0 or not is_attack_unlocked or not PLAYER_BULLET_SCENE:
		return
		
	var player_bullets_container = get_node_or_null("/root/Main/PlayerBullets")
	var target_parent = player_bullets_container if player_bullets_container else get_parent()
	
	# Captured shots are released once alongside the next eligible primary volley.
	fire_equipped_physics_weapon(target_parent)
	for shot in capture_volley.take_ready():
		emit_capture_shot(target_parent, shot)


func fire_equipped_physics_weapon(target_parent: Node) -> void:
	if current_hp <= 0 or not is_instance_valid(target_parent):
		return
	var weapon_id := Global.equipped_weapon
	if weapon_id == WEAPON_BURST_RIFLE:
		# Captured follow-ups do not change the primary's three-shot rhythm.
		var generation := attack_generation
		emit_primary_volley(target_parent, weapon_id)
		for shot in range(1, 3):
			get_tree().create_timer(shot * 0.05, false).timeout.connect(func():
				if generation == attack_generation and current_hp > 0 and not is_control_locked and is_instance_valid(target_parent):
					emit_primary_volley(target_parent, weapon_id)
			)
	else:
		emit_primary_volley(target_parent, weapon_id)

func emit_primary_volley(target_parent: Node, weapon_id: String) -> void:
	var angles: Array[float] = [0.0]
	var offsets: Array[float] = [0.0]
	if weapon_id == WEAPON_MACHINE_GUN:
		angles = [0.0, 0.0]
		offsets = [-8.0, 8.0]
	elif weapon_id == WEAPON_PULSE_GUN:
		angles = [-16.0, 0.0, 16.0]
		offsets = [-10.0, 0.0, 10.0]
	for index in range(angles.size()):
		var bullet = PLAYER_BULLET_SCENE.instantiate()
		configure_primary_bullet(bullet, weapon_id)
		bullet.global_position = global_position + Vector2(offsets[index], -22.0)
		bullet.velocity = Vector2.UP.rotated(deg_to_rad(angles[index])) * bullet.speed
		target_parent.add_child(bullet)

func configure_primary_bullet(bullet: Area2D, weapon_id: String) -> void:
	var spec: Dictionary = WeaponCatalog.PRIMARY.get(weapon_id, WeaponCatalog.PRIMARY[WEAPON_MACHINE_GUN])
	var multiplier := Global.get_primary_power_multiplier() * (1.25 if power_boost_remaining > 0.0 else 1.0)
	bullet.bullet_type = spec["bullet"]
	bullet.damage = int(float(spec["damage"]) * multiplier)
	bullet.speed = float(spec["speed"])
	bullet.set_meta("primary_weapon", weapon_id)
	if weapon_id == WEAPON_BURST_RIFLE:
		bullet.pierce_limit = 1
	elif weapon_id == WEAPON_PLASMA_EMITTER:
		bullet.heat_radius = 58.0
		bullet.heat_damage = int(8 * multiplier)
	elif weapon_id == WEAPON_KINETIC_TACKLE:
		bullet.max_distance = 180.0
		bullet.pierce_limit = 99

func emit_capture_shot(target_parent: Node, shot: Dictionary) -> void:
	var kind := String(shot["kind"])
	var angles: Array[float] = [0.0]
	if kind == "spread":
		angles.assign([-18.0, 0.0, 18.0])
	for angle in angles:
		var bullet = PLAYER_BULLET_SCENE.instantiate()
		bullet.bullet_type = {"rapid": "machine_gun", "pierce": "charge_bolt", "homing": "missile", "laser": "photon_laser", "cyclone": "cyclone", "meteor": "player_meteor"}.get(kind, "analysis")
		bullet.damage = int(shot["damage"])
		bullet.modulate = Color(shot["color"]).lerp(Color.CYAN, 0.35)
		bullet.modulate.a = 0.95
		bullet.set_meta("captured_kind", kind)
		bullet.set_meta("source_type", shot["source_type"])
		bullet.set_meta("precision_capture", shot.get("precision", false))
		match kind:
			"pierce": bullet.pierce_limit = 2
			"laser": bullet.pierce_limit = 3
			"meteor":
				bullet.explosion_radius = 72.0
				bullet.explosion_dmg = maxi(10, bullet.damage / 3)
			"thunder":
				bullet.chain_count = 2
				bullet.chain_damage = maxi(8, bullet.damage / 3)
			"vortex":
				bullet.vortex_radius = 58.0
				bullet.vortex_dmg = maxi(5, bullet.damage / 5)
			"blade":
				bullet.is_blade = true
				bullet.blade_lvl = 1
				bullet.pierce_limit = 1
		bullet.global_position = global_position + Vector2(shot.get("offset", Vector2(0, -26)))
		bullet.velocity = Vector2.UP.rotated(deg_to_rad(angle)) * bullet.speed
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
	elif power_boost_remaining > 0.0 and Global.equipped_shield == SHIELD_POWER:
		modulate = Color(1.0, 0.75, 0.35)
	else:
		modulate = Color.WHITE


const PRECISION_RADIUS_RATIO: float = 2.0 / 3.0
const PRECISION_DAMAGE_MULTIPLIER: float = 1.25
var precision_flash_remaining: float = 0.0
var precision_feedback_in_guard: bool = false
var consecutive_parries: int = 0

func is_precision_capture(point: Vector2) -> bool:
	return global_position.distance_to(point) <= Global.get_just_guard_radius() * PRECISION_RADIUS_RATIO

func capture_multiplier(point: Vector2) -> float:
	var multiplier := Global.get_capture_power_multiplier() * Global.get_just_guard_damage_multiplier()
	if Global.equipped_shield == SHIELD_COUNTER:
		multiplier *= 1.4
	return multiplier * (PRECISION_DAMAGE_MULTIPLIER if is_precision_capture(point) else 1.0)

func show_precision_feedback() -> void:
	if precision_feedback_in_guard:
		return
	precision_feedback_in_guard = true
	precision_flash_remaining = 0.35
	Global.play_parry(1.35)
	var label := Label.new()
	label.text = "精密捕獲!"
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.44))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(180, 36)
	label.position = Vector2(-90, -78)
	label.z_index = 80
	add_child(label)
	var tween := create_tween()
	tween.tween_interval(0.25)
	tween.tween_property(label, "modulate:a", 0.0, 0.10)
	tween.tween_callback(label.queue_free)
	queue_redraw()


func check_parry(touching_bullet: Node2D = null) -> void:
	if current_hp <= 0:
		return
	parry_window_radius = Global.get_just_guard_radius()
	var captured_now := false
	var last_position := global_position
	var source_type := "straight"
	var precision_now := false
	# Iterate a copy: returning a captured bullet mutates the pool's active array.
	for bullet in CombatTargets.projectiles(get_tree()):
		if not CombatTargets.can_parry(bullet) or (global_position.distance_to(bullet.global_position) > parry_window_radius and bullet != touching_bullet):
			continue
		last_position = bullet.global_position
		source_type = str(bullet.get("bullet_type"))
		if Global.counter_only_mode_enabled:
			CombatTargets.erase(bullet)
		else:
			var precise := is_precision_capture(last_position)
			capture_volley.capture(bullet, capture_multiplier(last_position), precise)
			precision_now = precision_now or precise
		captured_now = true
	for trap in get_tree().get_nodes_in_group("boss_traps"):
		if is_instance_valid(trap) and trap.is_active and not trap.is_parried and global_position.distance_to(trap.global_position) <= parry_window_radius + 40.0:
			last_position = trap.global_position
			source_type = "meteor"
			precision_now = precision_now or is_precision_capture(last_position)
			trap.trigger_just_guard_parry(self)
			captured_now = true
	if captured_now:
		if Global.equipped_shield == SHIELD_POWER:
			power_boost_remaining = 2.0
		if Global.is_first_launch and not Global.practice_active:
			Global.is_first_launch = false
		# Heal, statistics, and COUNTER all count one successful guard activation.
		if not parry_succeeded_in_guard:
			if Global.equipped_shield == SHIELD_COUNTER and not is_overheated:
				shield_heat = maxf(0.0, shield_heat - COUNTER_HEAT_REFUND)
			elif Global.equipped_shield == SHIELD_POWER and not Global.counter_only_mode_enabled:
				emit_shield_shockwave()
			consecutive_parries += 1
			parry_component.report_success(source_type, last_position, consecutive_parries)
			trigger_parry_feedback(last_position)
		else:
			queue_redraw()
		if precision_now and not Global.counter_only_mode_enabled:
			show_precision_feedback()

func emit_shield_shockwave() -> void:
	power_pulse_origin = global_position
	power_pulse_remaining = POWER_PULSE_DURATION
	var amount := int(POWER_PULSE_DAMAGE * Global.get_primary_power_multiplier())
	for target in CombatTargets.in_radius(self, power_pulse_origin, POWER_PULSE_RADIUS):
		CombatTargets.damage(target, amount, power_pulse_origin)
	queue_redraw()

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
	if not Global.practice_infinite_hp() and not Global.debug_infinite_hp():
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
		attack_generation += 1
		is_attack_unlocked = false
		power_boost_remaining = 0.0
		power_pulse_remaining = 0.0
		capture_volley.clear()
		is_guarding = false
		velocity = Vector2.ZERO
	else:
		# 被弾後の無敵時間を付与して、瞬間的な多段ヒットを防止
		is_invincible = true
		invincibility_timer = invincible_duration


func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)


func advance_analysis(_bullet_type: String, _amount: float = 12.0) -> void:
	# Legacy pickups no longer award combat upgrades.
	return






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
	
	spawn_parry_popup_message("PARRY!" if Global.counter_only_mode_enabled else "CAPTURE! 追撃待機 %d" % capture_volley.shots.size())


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
		spawn_popup_message("機体修復  +%d HP" % PARRY_HEAL_AMOUNT)
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
	if power_pulse_remaining > 0.0:
		var progress := 1.0 - power_pulse_remaining / POWER_PULSE_DURATION
		var center := to_local(power_pulse_origin)
		draw_circle(center, POWER_PULSE_RADIUS * progress, Color(1.0, 0.55, 0.15, 0.12 * (1.0 - progress)))
		draw_arc(center, POWER_PULSE_RADIUS * progress, 0, TAU, 48, Color(1.0, 0.8, 0.3, 0.9 * (1.0 - progress)), 3.0)
	if power_boost_remaining > 0.0 and Global.equipped_shield == SHIELD_POWER:
		var alpha := minf(1.0, power_boost_remaining / 0.3)
		draw_circle(Vector2(-8, -22), 5.0, Color(1.0, 0.7, 0.2, alpha * 0.7))
		draw_circle(Vector2(8, -22), 5.0, Color(1.0, 0.7, 0.2, alpha * 0.7))
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
		
		var inner_radius: float = cur_radius * PRECISION_RADIUS_RATIO
		var inner_alpha := 0.5 if not is_guarding else 1.0
		var inner_tint := Color(0.69, 0.97, 1.0, inner_alpha)
		if precision_flash_remaining > 0.0:
			inner_tint = Color(1.0, 0.86, 0.44)
			for angle in [0, 90, 180, 270]:
				var direction := Vector2.from_angle(deg_to_rad(angle))
				draw_line(direction * (inner_radius + 4.0), direction * (inner_radius + 10.0), inner_tint, 2.0)
		draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 48, inner_tint, 2.0)
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
	capture_volley.clear()
	is_invincible = true
	is_victory_flyby = true
	is_control_locked = true
	if is_instance_valid(capture_volley):
		capture_volley.clear()
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
	
	if victory_flyby_tween and victory_flyby_tween.is_valid():
		victory_flyby_tween.kill()
		
	victory_flyby_tween = create_tween()
	# 1. 画面中央下部へスムーズに位置合わせ (0.5秒)
	victory_flyby_tween.tween_property(self, "global_position", prepare_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 2. アフターバーナー全開点火 (0.35秒)
	victory_flyby_tween.tween_property(self, "flyby_boost_alpha", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	victory_flyby_tween.parallel().tween_callback(func():
		Global.play_explosion(1.35)
		trigger_screen_flash(Color(0.3, 0.8, 1.0, 0.4))
	)
	victory_flyby_tween.tween_interval(0.2)
	
	# 3. 上空へ向かって超高速急加速（大気圏・成層圏を突き抜けるフライバイ） (1.0秒)
	victory_flyby_tween.tween_property(self, "global_position", escape_pos, 1.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	# ソニックブーム衝撃波リング＆パーティクルの連続放出
	victory_flyby_tween.parallel().tween_callback(func():
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
