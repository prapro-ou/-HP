extends Node2D
## ゲーム進行管理（ステージ5：最終決戦 - 終焉の支配者）
## - Wave1: Apex Drone Formation（高密度攻撃ドローン大群）
## - Mid-Boss: 前哨防衛機甲兵器（第1ボス HP 6500）
## - 撃破時特大演出: 連続大爆発、スローモーション、画面赤熱フラッシュ、警報カットイン
## - Final Boss: 【終焉の支配者】オーバーロード・オメガ（巨大オーラ、2フェーズ覚醒、全方位螺旋弾幕）
## - 討伐特大演出: スーパーノヴァ白光大爆発＆VICTORY

var player: CharacterBody2D
var boss1: Node2D
var final_boss: Node2D
var ui: Control
var bullet_pool: Node2D

# ステート: 
# "start", "wave1", "boss1_warning", "boss1", "interlude_boss1_defeat", 
# "final_boss_entrance", "final_boss", "victory_transition", "victory", "defeat"
var state: String = "start"

var parry_count: int = 0
var total_damage_score: int = 0
var drone_scene = preload("res://game/enemies/drone/enemy_drone.tscn")
var spawned_drones: Array = []
var state_timer: float = 0.0

var interlude_timer: float = 0.0
var interlude_explosion_count: int = 0
var flash_overlay: ColorRect = null

func _ready() -> void:
	player = get_node_or_null("../Player")
	if not player:
		player = get_parent().get_node_or_null("Player")
		
	ui = get_node_or_null("../UI")
	if not ui:
		ui = get_parent().get_node_or_null("UI")
		
	bullet_pool = get_node_or_null("../BulletPool")
	if not bullet_pool:
		bullet_pool = get_parent().get_node_or_null("BulletPool")
		
	if bullet_pool and is_instance_valid(player):
		player.enemy_bullets = bullet_pool.active_bullets
		
	# ボスノード取得
	var stage_node = get_node_or_null("../StageContainer")
	if stage_node and stage_node.get_child_count() > 0:
		var st = stage_node.get_child(0)
		boss1 = st.get_node_or_null("Boss")
		final_boss = st.get_node_or_null("FinalBoss")
	else:
		boss1 = get_node_or_null("../Boss")
		final_boss = get_node_or_null("../FinalBoss")
		
	# ボス初期非表示
	if is_instance_valid(boss1):
		boss1.visible = false
		boss1.process_mode = PROCESS_MODE_DISABLED
		boss1.max_hp = 6500
		boss1.laser_hp = 1800
		boss1.missile_hp = 1800
		boss1.core_hp = 4700
		
	if is_instance_valid(final_boss):
		final_boss.visible = false
		final_boss.process_mode = PROCESS_MODE_DISABLED

	setup_flash_overlay()

	state = "wave1"
	get_tree().create_timer(1.0).timeout.connect(func():
		spawn_wave1()
	)

func setup_flash_overlay() -> void:
	flash_overlay = ColorRect.new()
	flash_overlay.color = Color(1, 0, 0, 0)
	flash_overlay.anchor_right = 1.0
	flash_overlay.anchor_bottom = 1.0
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_overlay)

func spawn_wave1() -> void:
	spawn_popup("FINAL SECTOR: APEX OVERLORD\nELIMINATE THE VANGUARD DRONE FORMATION!")
	var viewport_w = get_viewport_rect().size.x
	var wave1_configs = [
		{"type": "laser", "pos": Vector2(viewport_w * 0.15, -60)},
		{"type": "charge", "pos": Vector2(viewport_w * 0.35, -80)},
		{"type": "missile", "pos": Vector2(viewport_w * 0.50, -50)},
		{"type": "charge", "pos": Vector2(viewport_w * 0.65, -80)},
		{"type": "laser", "pos": Vector2(viewport_w * 0.85, -60)}
	]
	for config in wave1_configs:
		spawn_drone(config["type"], config["pos"])

func spawn_drone(type: String, pos: Vector2) -> Node2D:
	if not drone_scene:
		return null
	var drone = drone_scene.instantiate()
	drone.drone_type = type
	drone.global_position = pos
	get_parent().add_child(drone)
	spawned_drones.append(drone)
	return drone

func _process(delta: float) -> void:
	if state != "defeat" and state != "victory" and state != "victory_transition":
		if is_instance_valid(player) and player.current_hp <= 0:
			state = "defeat"
			clear_all_bullets()
			update_ui()
			show_game_over("DEFEAT")
			return

	match state:
		"wave1":
			check_wave1_completion()
		"boss1_warning":
			state_timer += delta
			if state_timer >= 2.5:
				start_boss1_battle()
		"boss1":
			check_boss1_health()
		"interlude_boss1_defeat":
			process_boss1_defeat_interlude(delta)
		"final_boss_entrance":
			state_timer += delta
			if state_timer >= 3.0:
				start_final_boss_battle()
		"final_boss":
			check_final_boss_health()

	update_ui()

func check_wave1_completion() -> void:
	var active = 0
	for d in spawned_drones:
		if is_instance_valid(d):
			active += 1
	if active == 0:
		state = "boss1_warning"
		state_timer = 0.0
		spawn_popup("VANGUARD DESTROYED!\nPRIMARY DREADNOUGHT SIGNATURE DETECTED!")

func start_boss1_battle() -> void:
	state = "boss1"
	if is_instance_valid(boss1):
		boss1.visible = true
		boss1.process_mode = PROCESS_MODE_INHERIT

func check_boss1_health() -> void:
	if is_instance_valid(boss1):
		# boss1 の核心が破壊されたか判定
		if "core_alive" in boss1 and not boss1.core_alive:
			trigger_boss1_defeat_sequence()

func trigger_boss1_defeat_sequence() -> void:
	state = "interlude_boss1_defeat"
	state_timer = 0.0
	interlude_timer = 0.0
	interlude_explosion_count = 0
	
	clear_all_bullets()
	clear_drones()
	
	# ヒットストップ＆スローモーション演出
	Engine.time_scale = 0.3
	
	# 演出開始アナウンス
	spawn_popup("MID-BOSS CRITICAL CORE COLLAPSE!\nANOMALOUS ENERGY SPIKE FROM UNDERGROUND!")

func process_boss1_defeat_interlude(delta: float) -> void:
	state_timer += delta
	interlude_timer += delta
	
	# 連続爆発エフェクト
	if interlude_timer >= 0.1:
		interlude_timer = 0.0
		interlude_explosion_count += 1
		if is_instance_valid(boss1):
			var rx = randf_range(-120, 120)
			var ry = randf_range(-80, 80)
			spawn_large_explosion(boss1.global_position + Vector2(rx, ry), Color(1.0, 0.5, 0.1))
			trigger_screen_shake(0.3, 12.0)
			
		# フラッシュ点滅
		if flash_overlay:
			var tween = create_tween()
			tween.tween_property(flash_overlay, "color", Color(1.0, 0.1, 0.1, 0.4), 0.05)
			tween.tween_property(flash_overlay, "color", Color(0, 0, 0, 0), 0.15)
			
	if state_timer >= 3.0:
		Engine.time_scale = 1.0 # 正常な時間経過に戻す
		if is_instance_valid(boss1):
			boss1.queue_free()
			boss1 = null
			
		state = "final_boss_entrance"
		state_timer = 0.0
		trigger_final_boss_warning()

func trigger_final_boss_warning() -> void:
	spawn_popup("【WARNING】EMERGENCY! OVERLORD OMEGA HAS AWAKENED!\nPREPARE FOR THE ULTIMATE BATTLE!")
	if flash_overlay:
		var tween = create_tween()
		tween.tween_property(flash_overlay, "color", Color(0.8, 0.1, 0.9, 0.6), 0.3)
		tween.tween_property(flash_overlay, "color", Color(0, 0, 0, 0), 0.8)

func start_final_boss_battle() -> void:
	state = "final_boss"
	if is_instance_valid(final_boss):
		final_boss.visible = true
		final_boss.process_mode = PROCESS_MODE_INHERIT

func check_final_boss_health() -> void:
	if is_instance_valid(final_boss):
		if "core_alive" in final_boss and not final_boss.core_alive:
			trigger_final_boss_victory_sequence()

func trigger_final_boss_victory_sequence() -> void:
	state = "victory_transition"
	clear_all_bullets()
	clear_drones()
	
	# 超絶クライマックス大爆発
	Engine.time_scale = 0.2
	
	if is_instance_valid(final_boss):
		for i in range(12):
			get_tree().create_timer(i * 0.1).timeout.connect(func():
				if is_instance_valid(final_boss):
					var rx = randf_range(-160, 160)
					var ry = randf_range(-120, 120)
					spawn_large_explosion(final_boss.global_position + Vector2(rx, ry), Color(2.0, 1.8, 0.4))
			)
			
	get_tree().create_timer(2.0).timeout.connect(func():
		Engine.time_scale = 1.0
		if is_instance_valid(final_boss):
			final_boss.queue_free()
		state = "victory"
		show_game_over("VICTORY")
	)

func spawn_large_explosion(pos: Vector2, color: Color) -> void:
	var particle_scene = load("res://game/bullets/parry_particle.tscn")
	if particle_scene:
		var p = particle_scene.instantiate()
		p.global_position = pos
		p.modulate = color
		p.scale = Vector2(4.5, 4.5)
		get_parent().add_child(p)

func trigger_screen_shake(duration: float, intensity: float) -> void:
	var parent_main = get_parent()
	if parent_main and parent_main.has_node("Camera2D"):
		var cam = parent_main.get_node("Camera2D")
		var orig_offset = cam.offset
		var tween = create_tween().set_loops(int(duration * 20.0))
		tween.tween_callback(func():
			cam.offset = orig_offset + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		)
		tween.tween_interval(0.05)
		get_tree().create_timer(duration).timeout.connect(func():
			cam.offset = orig_offset
		)

func clear_all_bullets() -> void:
	if bullet_pool and bullet_pool.has_method("clear_all"):
		bullet_pool.clear_all()

func clear_drones() -> void:
	for d in spawned_drones:
		if is_instance_valid(d):
			d.queue_free()
	spawned_drones.clear()

func spawn_popup(msg: String) -> void:
	if ui and ui.has_method("show_popup"):
		ui.show_popup(msg)

func update_ui() -> void:
	if ui and ui.has_method("update_hud"):
		var hp = player.current_hp if is_instance_valid(player) else 0
		var max_hp = player.max_hp if is_instance_valid(player) else 100
		
		# ボスHPの計算
		var b_hp = 0
		var b_max = 1
		if state == "boss1" and is_instance_valid(boss1):
			b_hp = boss1.laser_hp + boss1.missile_hp + boss1.core_hp
			b_max = boss1.max_hp
		elif (state == "final_boss" or state == "interlude_boss1_defeat") and is_instance_valid(final_boss):
			b_hp = final_boss.laser_hp + final_boss.missile_hp + final_boss.core_hp
			b_max = final_boss.max_hp
			
		ui.update_hud(hp, max_hp, b_hp, b_max, total_damage_score, state.to_upper())

func show_game_over(title: String) -> void:
	if ui and ui.has_method("show_game_over"):
		ui.show_game_over(title)
