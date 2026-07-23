extends Node2D
## ゲーム進行管理（ステージ2構成）
## - Wave1: Dual Extraction（BeamとMissileの混成部隊、両方3回パリィでアンロック）
## - Wave2: Swarm Phase（高速化したドローン軍団を8機撃破する）
## - 中継演出: 警告メッセージ表示（紫と赤の強力な警告）
## - ボス戦: 古代防衛兵器・強化版（HP大幅増、速度アップ、随時ドローンが支援出現）

var player: CharacterBody2D
var boss: Node2D
var ui: Control
var bullet_pool: Node2D

# ステート: "start", "wave1_dual", "wave2_transition", "wave2_swarm", "interlude", "boss", "victory", "defeat"
var state: String = "start"

var parry_count: int = 0
var total_damage_score: int = 0
var drone_scene = preload("res://game/scenes/enemy_drone.tscn")
var spawned_drones: Array = []
var state_timer: float = 0.0
var swarm_destroyed_count: int = 0
const SWARM_TARGET: int = 8

func _ready() -> void:
	player = get_node("../Player")
	boss = get_node("../Boss")
	ui = get_node("../UI")
	bullet_pool = get_node_or_null("../BulletPool")
	
	if bullet_pool:
		player.enemy_bullets = bullet_pool.active_bullets
		
	# 初期状態設定: ボスは非アクティブ
	if boss:
		boss.visible = false
		boss.process_mode = PROCESS_MODE_DISABLED
		
		# ボスのステータスを大幅に強化 (Stage 2仕様)
		boss.max_hp = 4500
		boss.laser_hp = 800
		boss.missile_hp = 800
		boss.core_hp = 2900
		boss.base_move_speed = 180.0
		boss.current_move_speed = 180.0
		boss.energy_laser = 45.0
		boss.energy_missile = 45.0
		boss.energy_core = 55.0
		
	# シーン開始
	state = "wave1_dual"
	get_tree().create_timer(1.0).timeout.connect(func():
		spawn_wave1_dual()
	)

func spawn_wave1_dual() -> void:
	spawn_popup("WAVE 1: DUAL EXTRACTION\nPARRY BOTH TYPES TO UNLOCK WEAPONS")
	var viewport_w = get_viewport_rect().size.x
	# 混成で4機配置
	spawn_drone("beam", Vector2(viewport_w * 0.2, -50))
	spawn_drone("missile", Vector2(viewport_w * 0.4, -50))
	spawn_drone("beam", Vector2(viewport_w * 0.6, -50))
	spawn_drone("missile", Vector2(viewport_w * 0.8, -50))

func spawn_wave2_swarm() -> void:
	state = "wave2_swarm"
	swarm_destroyed_count = 0
	spawn_popup("WAVE 2: SWARM DETECTED\nELIMINATE 8 ENEMY DRONES")
	var viewport_w = get_viewport_rect().size.x
	# 高速ドローンを4機配置
	for i in range(4):
		var type = "beam" if i % 2 == 0 else "missile"
		var rx = viewport_w * (0.2 + i * 0.2)
		var drone = spawn_drone(type, Vector2(rx, -50))
		if drone:
			# ステージ2のWave2ではドローン自体のパラメータを強化
			drone.speed = 220.0
			drone.shoot_interval = 1.0 if type == "beam" else 1.5

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
	match state:
		"wave1_dual":
			# 両方の武器が解析完了したかチェック
			if player.weapons["beam"]["analyzed"] and player.weapons["missile"]["analyzed"]:
				clear_drones()
				state = "wave2_transition"
				state_timer = 0.0
				spawn_popup("WEAPONS ADAPTED!\nDATA EXTRACTION COMPLETE.")
			else:
				# 解析が終わっていないタイプのドローンが全滅していたら補充
				check_dual_replenish()
				
		"wave2_transition":
			state_timer += delta
			if state_timer >= 2.5:
				spawn_wave2_swarm()
				
		"wave2_swarm":
			if swarm_destroyed_count >= SWARM_TARGET:
				clear_drones()
				state = "interlude"
				state_timer = 0.0
				trigger_warning_interlude()
			else:
				# スワームウェーブ中の補充（常に画面上に3機以上維持する）
				check_swarm_replenish()
				
		"interlude":
			state_timer += delta
			if state_timer >= 4.0:
				start_boss_battle()
				
		"boss":
			check_win_lose()
			# ボス戦中もたまにドローンをスポーンさせて難易度を上げる
			process_boss_drones(delta)
			
	update_ui()

func check_dual_replenish() -> void:
	var active_beam = 0
	var active_missile = 0
	for d in spawned_drones:
		if is_instance_valid(d):
			if d.drone_type == "beam":
				active_beam += 1
			elif d.drone_type == "missile":
				active_missile += 1
				
	if active_beam == 0 and not player.weapons["beam"]["analyzed"]:
		var rx = randf_range(100.0, get_viewport_rect().size.x - 100.0)
		spawn_drone("beam", Vector2(rx, -50))
	if active_missile == 0 and not player.weapons["missile"]["analyzed"]:
		var rx = randf_range(100.0, get_viewport_rect().size.x - 100.0)
		spawn_drone("missile", Vector2(rx, -50))

func check_swarm_replenish() -> void:
	var active = 0
	for d in spawned_drones:
		if is_instance_valid(d):
			active += 1
	# スワーム中は常に3機以上画面にいるようにする（ただし目標破壊数に達するまで）
	if active < 3 and (swarm_destroyed_count + active < SWARM_TARGET):
		var type = "beam" if randf() > 0.5 else "missile"
		var rx = randf_range(100.0, get_viewport_rect().size.x - 100.0)
		var drone = spawn_drone(type, Vector2(rx, -50))
		if drone:
			drone.speed = 220.0
			drone.shoot_interval = 1.0 if type == "beam" else 1.5

var boss_drone_timer: float = 0.0
func process_boss_drones(delta: float) -> void:
	boss_drone_timer += delta
	if boss_drone_timer >= 12.0: # 12秒ごとに1機スポーン
		boss_drone_timer = 0.0
		var active = 0
		for d in spawned_drones:
			if is_instance_valid(d):
				active += 1
		if active < 1: # 画面上に最大1機まで
			var type = "beam" if randf() > 0.5 else "missile"
			var rx = randf_range(100.0, get_viewport_rect().size.x - 100.0)
			var drone = spawn_drone(type, Vector2(rx, -50))
			if drone:
				drone.speed = 180.0
				drone.shoot_interval = 1.2 if type == "beam" else 1.8

func clear_drones() -> void:
	for d in spawned_drones:
		if is_instance_valid(d):
			d.queue_free()
	spawned_drones.clear()

func on_drone_destroyed(drone) -> void:
	if spawned_drones.has(drone):
		spawned_drones.erase(drone)
		if state == "wave2_swarm":
			swarm_destroyed_count += 1
			spawn_popup("SWARM ELIMINATED: " + str(swarm_destroyed_count) + "/" + str(SWARM_TARGET))

func trigger_warning_interlude() -> void:
	if ui and ui.has_method("show_warning"):
		ui.show_warning("CRITICAL WARNING: ANCIENT OVERLORD", "MASSIVE ENERGY SPIKE DETECTED - 1500% ABOVE LIMIT")
	
	# 画面全体を激しくフラッシュ
	if player and player.has_method("trigger_screen_flash"):
		player.trigger_screen_flash(Color(0.8, 0.0, 1.0, 0.5)) # 紫色のフラッシュ
		
	get_tree().create_timer(1.8).timeout.connect(func():
		if state == "interlude" and player and player.has_method("trigger_screen_flash"):
			player.trigger_screen_flash(Color(1.0, 0.0, 0.0, 0.6)) # 赤色のフラッシュ
	)

func start_boss_battle() -> void:
	state = "boss"
	if boss:
		boss.visible = true
		boss.process_mode = PROCESS_MODE_INHERIT
		boss.position = Vector2(get_viewport_rect().size.x / 2.0, -120.0)
		
		var tween = create_tween()
		tween.tween_property(boss, "position", Vector2(get_viewport_rect().size.x / 2.0, 160.0), 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		spawn_popup("BOSS ENGAGED: ANCIENT DEFENSE SYSTEM (OVERLOADED)")

func check_win_lose() -> void:
	if player.current_hp <= 0:
		state = "defeat"
		clear_all_bullets()
		show_game_over("DEFEAT")
	elif not is_instance_valid(boss) or (boss.has_method("get_current_hp") and boss.get_current_hp() <= 0):
		state = "victory_transition"
		clear_all_bullets()
		if is_instance_valid(player):
			player.is_full_burst = true

func clear_all_bullets() -> void:
	if is_instance_valid(bullet_pool) and "active_bullets" in bullet_pool:
		var active_copies = bullet_pool.active_bullets.duplicate()
		for b in active_copies:
			if is_instance_valid(b) and not b.is_queued_for_deletion():
				bullet_pool.return_bullet(b)
				
	var player_bullets_container = get_node_or_null("../PlayerBullets")
	if player_bullets_container:
		for child in player_bullets_container.get_children():
			if is_instance_valid(child) and not child.is_queued_for_deletion():
				child.queue_free()

func update_ui() -> void:
	if not ui:
		return
		
	ui.update_player_hp(player.current_hp, player.max_hp)
	
	if (state == "boss" or state == "victory_transition") and is_instance_valid(boss):
		var current_boss_hp = boss.get_current_hp() if boss.has_method("get_current_hp") else 0
		var max_boss_hp = boss.max_hp if "max_hp" in boss else 1000
		ui.update_boss_hp(current_boss_hp, max_boss_hp)
	else:
		ui.hide_boss_hp()
		
	ui.update_parry_count(parry_count)
	
	if ui.has_method("update_guard_status"):
		ui.update_guard_status(player.cooldown_timer, player.is_guarding)
		
	if ui.has_method("update_analysis_progress"):
		ui.update_analysis_progress(
			player.weapons["beam"]["progress"], player.weapons["beam"]["analyzed"],
			player.weapons["missile"]["progress"], player.weapons["missile"]["analyzed"],
			player.current_weapon
		)
		
	if (state == "boss" or state == "victory_transition") and is_instance_valid(boss) and ui.has_method("update_boss_energy"):
		ui.update_boss_energy(boss.energy_laser, boss.energy_missile, boss.energy_core)
	else:
		if ui.has_method("hide_boss_energy"):
			ui.hide_boss_energy()

func register_parry() -> void:
	parry_count += 1

func add_damage_score(amount: int) -> void:
	total_damage_score += amount

func on_boss_destroyed() -> void:
	state = "victory"
	clear_all_bullets()
	if is_instance_valid(player):
		player.is_full_burst = false
	show_game_over("VICTORY")

func spawn_popup(text: String) -> void:
	if player and player.has_method("spawn_popup_message"):
		player.spawn_popup_message(text)

func show_game_over(result: String) -> void:
	if ui and ui.has_method("show_game_over"):
		ui.show_game_over(result)

func restart() -> void:
	get_tree().reload_current_scene()
