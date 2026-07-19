extends Node2D
## ゲーム進行管理（ステージ1構成）
## - Wave1: Beam Drone（3回パリィでBeamアンロック）
## - Wave2: Missile Drone（3回パリィでMissileアンロック）
## - 中継演出: 警告メッセージ表示
## - ボス戦: 古代防衛兵器（部位破壊＆エネルギー再配分）
## - リッチなUI更新

var player: CharacterBody2D
var boss: Node2D
var ui: CanvasLayer
var bullet_pool: Node2D

# ステージ管理用
@onready var stage_container = get_node("../StageContainer")
var current_stage: Node2D = null
var current_stage_num: int = 1

# ステート: "start", "wave1", "wave2", "interlude", "boss", "victory", "defeat"
var state: String = "start"

var parry_count: int = 0
var total_damage_score: int = 0
var drone_scene = preload("res://game/enemies/drone/enemy_drone.tscn")
var spawned_drones: Array = []
var state_timer: float = 0.0


func _ready() -> void:
	player = get_node("../Player")
	ui = get_node("../UI")
	bullet_pool = get_node_or_null("../BulletPool")
	
	if bullet_pool:
		player.enemy_bullets = bullet_pool.active_bullets
		
	# 続きから始める場合、セーブデータをロードして反映する
	if Global.is_continue and Global.has_save:
		var save_data = Global.load_game_data()
		current_stage_num = save_data.get("stage_num", 1)
		total_damage_score = save_data.get("score", 0)
		
		var saved_weapons = save_data.get("weapons", {})
		if player and not saved_weapons.is_empty():
			# 武器の解析状況を復元
			for w_name in saved_weapons.keys():
				if w_name in player.weapons:
					player.weapons[w_name]["analyzed"] = saved_weapons[w_name].get("analyzed", false)
					player.weapons[w_name]["progress"] = saved_weapons[w_name].get("progress", 0.0)
					player.weapons[w_name]["level"] = saved_weapons[w_name].get("level", 1)
			
			# 既に解析済みの武器があれば初期選択状態にする
			if player.weapons["beam"]["analyzed"]:
				player.current_weapon = "beam"
			elif player.weapons["missile"]["analyzed"]:
				player.current_weapon = "missile"
		
		var stage_path = "res://game/stages/stage_" + str(current_stage_num) + ".tscn"
		if not ResourceLoader.exists(stage_path):
			stage_path = "res://game/stages/stage_1.tscn"
			current_stage_num = 1
		load_stage(stage_path, current_stage_num)
	else:
		# 初めから開始
		load_stage("res://game/stages/stage_1.tscn", 1)


func load_stage(stage_path: String, stage_num: int = 1) -> void:
	current_stage_num = stage_num
	
	# 既存のステージがあればクリーンアップ
	if is_instance_valid(current_stage):
		current_stage.queue_free()
		await get_tree().process_frame
		
	var stage_scene = load(stage_path)
	if not stage_scene:
		print("Failed to load stage scene: ", stage_path)
		return
		
	current_stage = stage_scene.instantiate()
	stage_container.add_child(current_stage)
	
	# ロードしたステージからボスを取得
	if current_stage.has_node("Boss"):
		boss = current_stage.get_node("Boss")
		boss.visible = false
		boss.process_mode = PROCESS_MODE_DISABLED
	else:
		boss = null
		
	# ステージがロードされたタイミングでセーブデータを書き出す
	if player:
		Global.save_game(current_stage_num, total_damage_score, player.weapons)
		
	# シーン開始
	state = "wave1"
	# ステージ開始時にAIの起動メッセージ
	get_tree().create_timer(0.2).timeout.connect(func():
		spawn_popup("[SYSTEM AI]: 装備システムオンライン。\n最初のパリィが実行されるまで、自機のメイン攻撃はロックされます。")
	)
	# 少し遅らせてWave1開始を表示
	get_tree().create_timer(2.6).timeout.connect(func():
		spawn_wave1()
	)


func load_next_stage() -> void:
	# 画面上の弾を全て消去
	clear_all_bullets()
	
	# プレイヤーのHP全回復、状態リセット
	if is_instance_valid(player):
		player.current_hp = player.max_hp
		player.is_full_burst = false
		player.cooldown_timer = 0.0
		player.active_timer = 0.0
		player.is_guarding = false
		# 武器の解析進行度、アンロック状況を初期化
		for w_key in player.weapons.keys():
			player.weapons[w_key]["analyzed"] = false
			player.weapons[w_key]["progress"] = 0
			player.weapons[w_key]["level"] = 1
		player.current_weapon = "none"
		
	# ゲーム状態のリセット
	parry_count = 0
	state_timer = 0.0
	clear_drones()
	
	var next_num = current_stage_num + 1
	var next_path = "res://game/stages/stage_" + str(next_num) + ".tscn"
	
	if ResourceLoader.exists(next_path):
		load_stage(next_path, next_num)
	else:
		# 次のステージが存在しない場合は、全クリアとしてステージ1へループ
		load_stage("res://game/stages/stage_1.tscn", 1)



func spawn_wave1() -> void:
	spawn_popup("[ASSIST AI]: 敵の小規模部隊が接近しています。\n[SPACE]キーで盾を展開し、敵弾をパリィして解析を完了してください。")
	var viewport_w = get_viewport_rect().size.x
	# ドローンを3機配置
	var x_coords = [viewport_w * 0.25, viewport_w * 0.5, viewport_w * 0.75]
	for x in x_coords:
		spawn_drone("beam", Vector2(x, -50))


func spawn_wave2() -> void:
	state = "wave2"
	spawn_popup("[ASSIST AI]: 次の解析対象を検知。\nミサイルの追跡データをパリィで吸収し、技術を逆転してください。")
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
		ui.show_warning("WARNING: ANCIENT GUARDIAN", "[ASSIST AI]: 巨大な古代防衛兵器を検知！")
	
	# 画面全体を赤くフラッシュ
	if player and player.has_method("trigger_screen_flash"):
		player.trigger_screen_flash(Color(1.0, 0.0, 0.0, 0.4))
		
	# アシストAIメッセージを表示
	get_tree().create_timer(1.2).timeout.connect(func():
		spawn_popup("[ASSIST AI]: 敵は巨大ですが、『部位破壊』で無力化できます。\nまた、[X]キーで『COUNTER SYSTEM』を一度だけ解放可能です！")
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
