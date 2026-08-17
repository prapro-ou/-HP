extends Node2D
## ゲーム進行管理（ステージ3：最終決戦構成）
## - Wave1: Triple Overload（高密度弾幕ドローン軍団、8回パリィ達成で突破）
## - Wave2: Elite Assault（超高速・高火力エリートドローン10機を撃破する）
## - 中継演出: 最凶の警告メッセージ表示（全画面フラッシュ演出）
## - ボス戦: 古代要塞皇帝・完全体（HP 6800, 高速移動＆激しい突進, 定期支援ドローン生成）

var player: CharacterBody2D
var boss: Node2D
var ui: Control
var bullet_pool: Node2D

# ステート: "start", "wave1_overload", "wave2_transition", "wave2_elite", "interlude", "boss", "victory", "defeat"
var state: String = "start"

var parry_count: int = 0
var total_damage_score: int = 0
var drone_scene = preload("res://game/enemies/drone/enemy_drone.tscn")
var spawned_drones: Array = []
var state_timer: float = 0.0
var last_active_stage: String = "WAVE 1: TRIPLE OVERLOAD"

var wave1_parry_start: int = 0
const WAVE1_PARRY_GOAL: int = 8 # Wave1クリアに必要なパリィ数

var wave2_destroyed_count: int = 0
const WAVE2_TARGET: int = 10 # Wave2クリアに必要なドローン撃破数

var boss_drone_timer: float = 0.0

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
		
		# ボスのステータスを強化 (Stage 3仕様)
		boss.max_hp = 6800
		if "current_hp" in boss:
			boss.current_hp = 6800

		
	# シーン開始
	state = "wave1_overload"
	last_active_stage = "WAVE 1: TRIPLE OVERLOAD"
	wave1_parry_start = parry_count
	
	get_tree().create_timer(1.0).timeout.connect(func():
		spawn_wave1_overload()
	)


func spawn_wave1_overload() -> void:
	spawn_popup("WAVE 1: TRIPLE OVERLOAD\nPERFORM 8 PARRIES TO BREAK SHIELD")
	var viewport_w = get_viewport_rect().size.x
	# 5機のドローンを高密度配置
	for i in range(5):
		var type = "beam" if i % 2 == 0 else "missile"
		var rx = viewport_w * (0.15 + i * 0.175)
		var drone = spawn_drone(type, Vector2(rx, -50))
		if drone:
			drone.speed = 180.0
			drone.shoot_interval = 1.3


func spawn_wave2_elite() -> void:
	state = "wave2_elite"
	last_active_stage = "WAVE 2: ELITE ASSAULT"
	wave2_destroyed_count = 0
	spawn_popup("WAVE 2: ELITE ASSAULT\nELIMINATE 10 ENEMY DRONES")
	var viewport_w = get_viewport_rect().size.x
	for i in range(4):
		var type = "beam" if i % 2 == 0 else "missile"
		var rx = viewport_w * (0.2 + i * 0.2)
		var drone = spawn_drone(type, Vector2(rx, -50))
		if drone:
			drone.speed = 250.0 # 超高速
			drone.shoot_interval = 0.9 if type == "beam" else 1.2


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
	# 全ウェーブでの死亡判定
	if state != "defeat" and state != "victory" and state != "victory_transition":
		if is_instance_valid(player) and player.current_hp <= 0:
			state = "defeat"
			clear_all_bullets()
			update_ui()
			show_game_over("DEFEAT")
			return

	match state:
		"wave1_overload":
			var current_wave1_parries = parry_count - wave1_parry_start
			if current_wave1_parries >= WAVE1_PARRY_GOAL or (player.weapons["beam"]["analyzed"] and player.weapons["missile"]["analyzed"]):
				clear_drones()
				state = "wave2_transition"
				state_timer = 0.0
				spawn_popup("OVERLOAD BROKEN!\nPROCEEDING TO ELITE PHASE.")
			else:
				check_overload_replenish()
				
		"wave2_transition":
			state_timer += delta
			if state_timer >= 2.5:
				spawn_wave2_elite()
				
		"wave2_elite":
			if wave2_destroyed_count >= WAVE2_TARGET:
				clear_drones()
				state = "interlude"
				state_timer = 0.0
				trigger_warning_interlude()
			else:
				check_elite_replenish()
				
		"interlude":
			state_timer += delta
			if state_timer >= 4.0:
				start_boss_battle()
				
		"boss":
			check_win_lose()
			process_boss_drones(delta)
			
	update_ui()


func check_overload_replenish() -> void:
	var active = 0
	for d in spawned_drones:
		if is_instance_valid(d):
			active += 1
	if active < 4:
		var type = "beam" if randf() > 0.5 else "missile"
		var rx = randf_range(80.0, get_viewport_rect().size.x - 80.0)
		var drone = spawn_drone(type, Vector2(rx, -50))
		if drone:
			drone.speed = 190.0
			drone.shoot_interval = 1.3


func check_elite_replenish() -> void:
	var active = 0
	for d in spawned_drones:
		if is_instance_valid(d):
			active += 1
	if active < 4 and (wave2_destroyed_count + active < WAVE2_TARGET):
		var type = "beam" if randf() > 0.5 else "missile"
		var rx = randf_range(80.0, get_viewport_rect().size.x - 80.0)
		var drone = spawn_drone(type, Vector2(rx, -50))
		if drone:
			drone.speed = 250.0
			drone.shoot_interval = 0.9 if type == "beam" else 1.2


func process_boss_drones(delta: float) -> void:
	boss_drone_timer += delta
	if boss_drone_timer >= 8.0: # 8秒ごとに支援ドローンをスポーン
		boss_drone_timer = 0.0
		var active = 0
		for d in spawned_drones:
			if is_instance_valid(d):
				active += 1
		if active < 2: # ボス戦中最大2機まで同画面に登場
			var type = "beam" if randf() > 0.5 else "missile"
			var rx = randf_range(100.0, get_viewport_rect().size.x - 100.0)
			var drone = spawn_drone(type, Vector2(rx, -50))
			if drone:
				drone.speed = 200.0
				drone.shoot_interval = 1.1


func clear_drones() -> void:
	for d in spawned_drones:
		if is_instance_valid(d):
			d.queue_free()
	spawned_drones.clear()


func on_drone_destroyed(drone) -> void:
	if spawned_drones.has(drone):
		spawned_drones.erase(drone)
		if state == "wave2_elite":
			wave2_destroyed_count += 1
			spawn_popup("ELITE DESTROYED: " + str(wave2_destroyed_count) + "/" + str(WAVE2_TARGET))


func trigger_warning_interlude() -> void:
	last_active_stage = "BOSS BATTLE: ANCIENT CORE EMPEROR"
	if ui and ui.has_method("show_warning"):
		ui.show_warning("EMPEROR CLASS DETECTED!", "ANCIENT CORE EMPEROR IS ENTERING THE FIELD")
	
	if player and player.has_method("trigger_screen_flash"):
		player.trigger_screen_flash(Color(1.0, 0.2, 0.0, 0.6))
		
	get_tree().create_timer(1.8).timeout.connect(func():
		if state == "interlude" and player and player.has_method("trigger_screen_flash"):
			player.trigger_screen_flash(Color(0.2, 0.8, 1.0, 0.6))
	)


func start_boss_battle() -> void:
	state = "boss"
	last_active_stage = "BOSS BATTLE: ANCIENT CORE EMPEROR"
	if boss:
		boss.visible = true
		boss.process_mode = PROCESS_MODE_INHERIT
		boss.position = Vector2(get_viewport_rect().size.x / 2.0, -120.0)
		
		var tween = create_tween()
		tween.tween_property(boss, "position", Vector2(get_viewport_rect().size.x / 2.0, 160.0), 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		spawn_popup("FINAL BOSS ENGAGED: ANCIENT CORE EMPEROR")


func check_win_lose() -> void:
	if player.current_hp <= 0:
		state = "defeat"
		clear_all_bullets()
		update_ui()
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
		
	if (state == "boss" or state == "victory_transition") and is_instance_valid(boss) and "energy_laser" in boss and ui.has_method("update_boss_energy"):
		ui.update_boss_energy(boss.energy_laser, boss.energy_missile, boss.energy_core)
	else:
		if ui and ui.has_method("hide_boss_energy"):
			ui.hide_boss_energy()



func get_failed_stage_name() -> String:
	return last_active_stage


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
