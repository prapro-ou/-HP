extends Node2D
## ゲーム進行管理（ステージ1構成）
## - Wave1: Beam Drone（3回パリィでBeamアンロック）
## - Wave2: Missile Drone（3回パリィでMissileアンロック）
## - 中継演出: 警告メッセージ表示
## - ボス戦: 古代防衛兵器（部位破壊＆エネルギー再配分）
## - リッチなUI更新

var player: CharacterBody2D
var boss: Node2D
var ui: Control
var bullet_pool: Node2D

# ステート: "start", "wave1", "wave2", "interlude", "boss", "victory", "defeat"
var state: String = "start"

var parry_count: int = 0
var total_damage_score: int = 0
var drone_scene = preload("res://game/scenes/enemy_drone.tscn")
var spawned_drones: Array = []
var state_timer: float = 0.0


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
		
	# シーン開始
	state = "wave1"
	# 少し遅らせてWave1開始を表示
	get_tree().create_timer(1.0).timeout.connect(func():
		spawn_wave1()
	)


func spawn_wave1() -> void:
	spawn_popup("WAVE 1: BEAM DRONE INCOMING\nPARRY 3 TIMES TO ANALYSIS BEAM")
	var viewport_w = get_viewport_rect().size.x
	# ドローンを3機配置
	var x_coords = [viewport_w * 0.25, viewport_w * 0.5, viewport_w * 0.75]
	for x in x_coords:
		spawn_drone("beam", Vector2(x, -50))


func spawn_wave2() -> void:
	state = "wave2"
	spawn_popup("WAVE 2: MISSILE DRONE INCOMING\nPARRY 3 TIMES TO ANALYSIS MISSILE")
	var viewport_w = get_viewport_rect().size.x
	var x_coords = [viewport_w * 0.25, viewport_w * 0.5, viewport_w * 0.75]
	for x in x_coords:
		spawn_drone("missile", Vector2(x, -50))


func spawn_drone(type: String, pos: Vector2) -> void:
	if not drone_scene:
		return
	var drone = drone_scene.instantiate()
	drone.drone_type = type
	drone.global_position = pos
	get_parent().add_child(drone)
	spawned_drones.append(drone)


func _process(delta: float) -> void:
	match state:
		"wave1":
			# Beam 解析率が100%に達したかチェック
			if player.weapons["beam"]["analyzed"]:
				clear_drones()
				state = "wave2_transition"
				state_timer = 0.0
				spawn_popup("BEAM SHIELD BREAK!\nDATA EXTRACTED SUCCESSFULLY.")
			else:
				# ドローンが全滅したのに100%になっていなければ、再度1機補充
				check_drone_replenish("beam")
				
		"wave2_transition":
			state_timer += delta
			if state_timer >= 2.5:
				spawn_wave2()
				
		"wave2":
			if player.weapons["missile"]["analyzed"]:
				clear_drones()
				state = "interlude"
				state_timer = 0.0
				trigger_warning_interlude()
			else:
				check_drone_replenish("missile")
				
		"interlude":
			state_timer += delta
			if state_timer >= 4.0:
				start_boss_battle()
				
		"boss":
			check_win_lose()
			
	update_ui()


func check_drone_replenish(type: String) -> void:
	# 有効なドローンが0なら追加スポーン
	var active = 0
	for d in spawned_drones:
		if is_instance_valid(d):
			active += 1
	if active == 0:
		var rx = randf_range(100.0, get_viewport_rect().size.x - 100.0)
		spawn_drone(type, Vector2(rx, -50))


func clear_drones() -> void:
	for d in spawned_drones:
		if is_instance_valid(d):
			d.queue_free()
	spawned_drones.clear()


func on_drone_destroyed(drone) -> void:
	if spawned_drones.has(drone):
		spawned_drones.erase(drone)


func trigger_warning_interlude() -> void:
	if ui and ui.has_method("show_warning"):
		ui.show_warning("WARNING: ANCIENT GUARDIAN DETECTION", "ENERGY SPIKE DETECTED - 1000% ABOVE CRITICAL")
	
	# 画面全体を赤くフラッシュ
	if player and player.has_method("trigger_screen_flash"):
		player.trigger_screen_flash(Color(1.0, 0.0, 0.0, 0.4))
		
	# 2秒後に再度警告フラッシュ
	get_tree().create_timer(1.8).timeout.connect(func():
		if state == "interlude" and player and player.has_method("trigger_screen_flash"):
			player.trigger_screen_flash(Color(1.0, 0.0, 0.0, 0.5))
	)


func start_boss_battle() -> void:
	state = "boss"
	if boss:
		boss.visible = true
		boss.process_mode = PROCESS_MODE_INHERIT
		boss.position = Vector2(get_viewport_rect().size.x / 2.0, -120.0)
		
		# ボスが画面内にゆっくり降りてくる
		var tween = create_tween()
		tween.tween_property(boss, "position", Vector2(get_viewport_rect().size.x / 2.0, 160.0), 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		spawn_popup("BOSS ENGAGED: ANCIENT DEFENSE SYSTEM")


func check_win_lose() -> void:
	if player.current_hp <= 0:
		state = "defeat"
		clear_all_bullets()
		show_game_over("DEFEAT")
	elif not is_instance_valid(boss) or (boss.has_method("get_current_hp") and boss.get_current_hp() <= 0):
		# ボス撃破検知: 爆発演出を見せるため遷移ステートへ移行し、画面の弾を消去
		state = "victory_transition"
		clear_all_bullets()
		# 撃破の瞬間からプレイヤーをフルバースト状態にしてトドメ攻撃をさせる
		if is_instance_valid(player):
			player.is_full_burst = true


func clear_all_bullets() -> void:
	# 敵弾プールのアクティブな弾をすべてクリア
	if is_instance_valid(bullet_pool) and "active_bullets" in bullet_pool:
		var active_copies = bullet_pool.active_bullets.duplicate()
		for b in active_copies:
			if is_instance_valid(b) and not b.is_queued_for_deletion():
				bullet_pool.return_bullet(b)
				
	# プレイヤーの弾も画面から消す
	var player_bullets_container = get_node_or_null("../PlayerBullets")
	if player_bullets_container:
		for child in player_bullets_container.get_children():
			if is_instance_valid(child) and not child.is_queued_for_deletion():
				child.queue_free()


func update_ui() -> void:
	if not ui:
		return
		
	ui.update_player_hp(player.current_hp, player.max_hp)
	
	# ボスHPの表示 (ボス戦中および撃破演出中)
	if (state == "boss" or state == "victory_transition") and is_instance_valid(boss):
		var current_boss_hp = boss.get_current_hp() if boss.has_method("get_current_hp") else 0
		var max_boss_hp = boss.max_hp if "max_hp" in boss else 1000
		ui.update_boss_hp(current_boss_hp, max_boss_hp)
	else:
		ui.hide_boss_hp()
		
	ui.update_parry_count(parry_count)
	
	# ガードと解析情報の更新
	if ui.has_method("update_guard_status"):
		ui.update_guard_status(player.cooldown_timer, player.is_guarding)
		
	if ui.has_method("update_analysis_progress"):
		ui.update_analysis_progress(
			player.weapons["beam"]["progress"], player.weapons["beam"]["analyzed"],
			player.weapons["missile"]["progress"], player.weapons["missile"]["analyzed"],
			player.current_weapon
		)
		
	# ボスのエネルギー状況を表示する
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

