extends Node2D
## ゲーム進行管理（データ駆動型ステージランナー）
## BaseStage から波構成、警告設定、ボス仕様、報酬データを取得し、ゲーム進行を一括制御します。

enum State {
	START,
	WAVE,
	WAVE_TRANSITION,
	INTERLUDE,
	BOSS,
	VICTORY_TRANSITION,
	VICTORY,
	DEFEAT
}

# 外部参照・シグナル用プロパティ
var player: CharacterBody2D
var boss: Node2D
var ui: CanvasLayer
var bullet_pool: Node2D

@onready var stage_container: Node2D = get_node("../StageContainer")
var current_stage: BaseStage = null
var current_stage_num: int = 1

# ステート
var state: String = "start" # 外部互換用文字列プロパティ
var current_state: State = State.START
var current_wave_index: int = 0
var current_wave_level: int = 1
var swarm_destroyed_count: int = 0
var total_wave_kills: int = 0
var wave_parry_count: int = 0
var wave_upgrade_count: int = 0

# 90秒防衛＆育成タイマー定数
const WAVE_PHASE_MAX_DURATION: float = 90.0
var wave_phase_timer: float = 90.0

# 戦績データ
var parry_count: int = 0
var total_damage_score: int = 0
var spawned_drones: Array = []
var state_timer: float = 0.0
var boss_drone_timer: float = 0.0

# プリロード
const DRONE_SCENE: PackedScene = preload("res://game/enemies/drone/enemy_drone.tscn")

# 画面・タイマー定数
const DEFAULT_STAGE_PATH_FMT: String = "res://game/stages/stage_%d.tscn"
const FALLBACK_STAGE_PATH: String = "res://game/stages/stage_1.tscn"
const BOSS_DESCENT_DURATION: float = 3.0
const BOSS_INITIAL_Y: float = -120.0
const BOSS_TARGET_Y: float = 160.0


func _ready() -> void:
	player = get_node_or_null("../Player")
	ui = get_node_or_null("../UI")
	bullet_pool = get_node_or_null("../BulletPool")
	
	if bullet_pool and is_instance_valid(player):
		player.enemy_bullets = bullet_pool.active_bullets
		
	var save_data = Global.load_game_data(false)
	if Global.is_first_launch:
		current_stage_num = 1
	else:
		current_stage_num = save_data.get("stage_num", 1)
		
	total_damage_score = save_data.get("score", 0)
	
	var stage_path = DEFAULT_STAGE_PATH_FMT % current_stage_num
	if not ResourceLoader.exists(stage_path):
		stage_path = FALLBACK_STAGE_PATH
		current_stage_num = 1
		
	load_stage(stage_path, current_stage_num)


func clean_stage_entities() -> void:
	"""前ステージの残存敵・ボス・弾幕・タイマーを完全に削除・初期化する"""
	get_tree().paused = false
	
	clear_all_bullets()
	clear_drones()
	
	for node in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(node) and node != player:
			node.queue_free()
			
	for node in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(node):
			node.queue_free()
			
	for node in get_tree().get_nodes_in_group("drone"):
		if is_instance_valid(node):
			node.queue_free()
			
	if is_instance_valid(current_stage):
		current_stage.queue_free()
		current_stage = null
		
	parry_count = 0
	wave_parry_count = 0
	wave_upgrade_count = 0
	state_timer = 0.0
	boss_drone_timer = 0.0
	swarm_destroyed_count = 0
	total_wave_kills = 0
	current_wave_index = 0
	current_wave_level = 1
	wave_phase_timer = WAVE_PHASE_MAX_DURATION
	current_state = State.START
	state = "start"
	
	if is_instance_valid(player) and player.has_method("reset_state"):
		player.reset_state()


func load_stage(stage_path: String, stage_num: int = 1) -> void:
	current_stage_num = stage_num
	clean_stage_entities()
	await get_tree().process_frame
	
	var stage_scene = load(stage_path)
	if not stage_scene:
		print("Failed to load stage scene: ", stage_path)
		return
		
	current_stage = stage_scene.instantiate()
	stage_container.add_child(current_stage)
	
	if current_stage.has_node("Boss"):
		boss = current_stage.get_node("Boss")
		boss.visible = false
		boss.process_mode = PROCESS_MODE_DISABLED
	else:
		boss = null
		
	# 背景テクスチャの反映
	var bg_node = get_node_or_null("../ScrollingBackground")
	if bg_node and bg_node.has_method("set_background_texture"):
		if current_stage and current_stage.background_texture:
			bg_node.set_background_texture(current_stage.background_texture)
		else:
			var bg_path = "res://game/assets/backgrounds/backgrnd_stage%d.png" % current_stage_num
			if ResourceLoader.exists(bg_path):
				bg_node.set_background_texture(load(bg_path))
		
	Global.save_game(current_stage_num, total_damage_score, {})
	
	current_state = State.WAVE
	state = "wave1"
	current_wave_index = 0
	
	# ステージ開始の大判テロップ表示 (4.2秒間、画面中央に大きく表示)
	var st_name = current_stage.stage_name if current_stage else "STAGE " + str(current_stage_num)
	var codename = ""
	var goal = "90秒間防衛＆敵弾解析 ➔ ボス要塞を撃破せよ"
	match current_stage_num:
		1:
			codename = "第1エリア: 惑星到達前・デブリ宙域"
			goal = "敵部隊の攻撃をパリィ解析し、防衛要塞を突破せよ！"
		2:
			codename = "第2エリア: 惑星地上上空・成層圏"
			goal = "雲海防衛網を突破し、空中要塞キャリアを撃墜せよ！"
		3:
			codename = "第3エリア: 惑星内部・軍事工廠"
			goal = "網の目の電磁網を制圧し、中枢コアを破壊せよ！"
		4:
			codename = "第4エリア: 崩壊地底・脱出ルート"
			goal = "崩壊トラップを回避し、追撃部隊を振り切って脱出せよ！"
		5:
			codename = "最終エリア: 終焉の支配者・オメガ"
			goal = "全兵装を同期解放し、覚醒惑星オメガを殲滅せよ！"
			
	if ui and ui.has_method("show_stage_intro_banner"):
		ui.show_stage_intro_banner(current_stage_num, st_name, codename, goal)
	
	var first_wave = current_stage.get_wave(0)
	if first_wave:
		get_tree().create_timer(3.8).timeout.connect(func():
			if current_state == State.WAVE:
				if ui and ui.has_method("show_wave_announcement") and first_wave.start_message != "":
					ui.show_wave_announcement(first_wave.display_title, first_wave.start_message, 4.0)
				start_wave(0)
		)
	else:
		start_boss_battle()


func load_next_stage() -> void:
	var next_num = current_stage_num + 1
	var next_path = DEFAULT_STAGE_PATH_FMT % next_num
	
	if ResourceLoader.exists(next_path):
		load_stage(next_path, next_num)
	else:
		clean_stage_entities()
		Global.save_game(1, total_damage_score, {})
		get_tree().change_scene_to_file("res://game/core/stage_selection.tscn")


func start_wave(index: int) -> void:
	current_wave_index = index
	current_state = State.WAVE
	state = "wave" + str(index + 1)
	swarm_destroyed_count = 0
	wave_parry_count = 0
	wave_upgrade_count = 0
	
	var wave_data = current_stage.get_wave(index)
	if not wave_data:
		trigger_interlude()
		return
		
	var viewport_w = get_viewport_rect().size.x
	for config in wave_data.initial_spawns:
		var pos = Vector2(viewport_w * config.pos_ratio_x, config.pos_y)
		var drone = spawn_drone(config.drone_type, pos)
		if drone and wave_data.drone_speed_override > 0.0:
			drone.speed = wave_data.drone_speed_override
			if config.drone_type == "beam" and wave_data.drone_shoot_interval_beam > 0.0:
				drone.shoot_interval = wave_data.drone_shoot_interval_beam
			elif config.drone_type == "missile" and wave_data.drone_shoot_interval_missile > 0.0:
				drone.shoot_interval = wave_data.drone_shoot_interval_missile


func spawn_drone(type: String, pos: Vector2) -> Node2D:
	if not DRONE_SCENE:
		return null
	var drone = DRONE_SCENE.instantiate()
	drone.drone_type = type
	drone.global_position = pos
	get_parent().add_child(drone)
	spawned_drones.append(drone)
	return drone


func _process(delta: float) -> void:
	match current_state:
		State.WAVE:
			process_wave_state(delta)
			
		State.WAVE_TRANSITION:
			state_timer += delta
			var wave_data = current_stage.get_wave(current_wave_index - 1)
			var delay = wave_data.transition_delay if wave_data else 2.2
			if state_timer >= delay:
				start_wave(current_wave_index)
				
		State.INTERLUDE:
			state_timer += delta
			if state_timer >= current_stage.interlude.duration:
				start_boss_battle()
				
		State.BOSS:
			check_win_lose()
			if current_stage and current_stage.boss_config.enable_support_drones:
				process_boss_support_drones(delta)
				
	update_ui()


func process_wave_state(delta: float) -> void:
	# 90秒制限時間タイマーの減算
	wave_phase_timer -= delta
	
	if wave_phase_timer <= 0.0:
		wave_phase_timer = 0.0
		clear_drones()
		if ui and ui.has_method("show_wave_announcement"):
			ui.show_wave_announcement("⏱️ 90秒防衛達成！", "強大な敵反応を検知！ボス迎撃態勢に移行せよ！", 3.8)
		trigger_interlude()
		return
		
	# 90秒間の時間経過に合わせて、ステージのWave段階を自動ステップアップ！
	if current_stage and current_stage.waves.size() > 0:
		var total_waves = current_stage.waves.size()
		var elapsed_time = WAVE_PHASE_MAX_DURATION - wave_phase_timer
		var step_duration = WAVE_PHASE_MAX_DURATION / float(total_waves)
		var target_wave_idx = clamp(int(elapsed_time / step_duration), 0, total_waves - 1)
		
		if target_wave_idx > current_wave_index:
			current_wave_index = target_wave_idx
			current_wave_level = current_wave_index + 1
			state = "wave" + str(current_wave_level)
			
			# ウェーブ移行ボーナス：機体修復 (+30 HP) & ボーナスTP (+10 TP)
			if is_instance_valid(player) and player.has_method("heal"):
				player.heal(30)
			Global.tech_points += 10
			
			var new_wave_data = current_stage.get_wave(current_wave_index)
			if new_wave_data:
				var title_str = new_wave_data.display_title
				if title_str == "":
					title_str = "⚡ WAVE %d 突入！敵増援！" % current_wave_level
				if ui and ui.has_method("show_wave_announcement"):
					ui.show_wave_announcement(title_str, new_wave_data.start_message, 3.8)
				
	var wave_data = current_stage.get_wave(current_wave_index) if current_stage else null
	if wave_data:
		check_drone_replenish(wave_data)


func get_player_analyzed_count() -> int:
	var count = 0
	if is_instance_valid(player) and "analysis_patterns" in player:
		for p in player.analysis_patterns.values():
			if p.get("analyzed", false):
				count += 1
	return count


func get_boosted_replenish_type(wave_data: BaseStage.WaveData = null) -> String:
	# プレイヤーが装備中（Lv.2未満）または解析進行中の属性に対応する敵を優先抽出
	var target_drone_types: Array[String] = []
	
	if is_instance_valid(player) and "analysis_patterns" in player:
		var trait_to_drone = {
			"rapid": "straight",
			"spread": "wave",
			"pierce": "charge",
			"homing": "missile",
			"laser": "laser",
			"cyclone": "irregular"
		}
		
		# 1. スロット装備中の属性でLv.2未満のものを最優先
		var active = player.active_traits if "active_traits" in player else []
		for t_key in active:
			if player.analysis_patterns.has(t_key):
				var data = player.analysis_patterns[t_key]
				if data.get("level", 0) < data.get("max_level", 2):
					if trait_to_drone.has(t_key):
						target_drone_types.append(trait_to_drone[t_key])
						
		# 2. 直近でパリィ・解析中の属性も対象に追加
		for t_key in player.analysis_patterns.keys():
			var data = player.analysis_patterns[t_key]
			if data.get("progress", 0.0) > 0.0 and data.get("level", 0) < data.get("max_level", 2):
				if trait_to_drone.has(t_key) and not target_drone_types.has(trait_to_drone[t_key]):
					target_drone_types.append(trait_to_drone[t_key])
					
	# 75%の確率で育成対象の敵タイプを集中出現！
	if target_drone_types.size() > 0 and randf() < 0.75:
		return target_drone_types.pick_random()
		
	# 通常フォールバック
	if wave_data and wave_data.replenish_types.size() > 0:
		return wave_data.replenish_types.pick_random()
	return "straight"


func check_drone_replenish(wave_data: BaseStage.WaveData) -> void:
	var active = 0
	for d in spawned_drones:
		if is_instance_valid(d):
			active += 1
			
	# 目標撃破数による停止は行わず、制限時間いっぱいまで常時敵を補充！
	if active < wave_data.min_active_drones:
		var rx = randf_range(100.0, get_viewport_rect().size.x - 100.0)
		var chosen_type = get_boosted_replenish_type(wave_data)
		var drone = spawn_drone(chosen_type, Vector2(rx, -50))
		if drone and wave_data.drone_speed_override > 0.0:
			drone.speed = wave_data.drone_speed_override
			if chosen_type == "laser" and wave_data.drone_shoot_interval_beam > 0.0:
				drone.shoot_interval = wave_data.drone_shoot_interval_beam
			elif chosen_type == "missile" and wave_data.drone_shoot_interval_missile > 0.0:
				drone.shoot_interval = wave_data.drone_shoot_interval_missile


func process_boss_support_drones(delta: float) -> void:
	boss_drone_timer += delta
	var interval = current_stage.boss_config.support_drone_interval if current_stage else 8.0
	if boss_drone_timer >= interval:
		boss_drone_timer = 0.0
		var active = 0
		for d in spawned_drones:
			if is_instance_valid(d):
				active += 1
		if active < 2:
			var type = get_boosted_replenish_type(null)
			var rx = randf_range(100.0, get_viewport_rect().size.x - 100.0)
			var drone = spawn_drone(type, Vector2(rx, -50))
			if drone:
				drone.speed = 160.0
				drone.shoot_interval = 2.0


func clear_drones() -> void:
	for d in spawned_drones:
		if is_instance_valid(d):
			d.queue_free()
	spawned_drones.clear()


func on_drone_destroyed(drone) -> void:
	if spawned_drones.has(drone):
		spawned_drones.erase(drone)
		swarm_destroyed_count += 1
		total_wave_kills += 1
		
		if ui and ui.has_method("update_wave_phase_hud"):
			ui.update_wave_phase_hud(current_wave_level, wave_phase_timer, total_wave_kills)


func trigger_interlude() -> void:
	current_state = State.INTERLUDE
	state = "interlude"
	state_timer = 0.0
	
	if ui and ui.has_method("hide_wave_phase_hud"):
		ui.hide_wave_phase_hud()
	
	var inter_data = current_stage.interlude
	if ui and ui.has_method("show_warning"):
		ui.show_warning(inter_data.title, inter_data.subtitle)
		
	if player and player.has_method("trigger_screen_flash"):
		player.trigger_screen_flash(inter_data.flash_color)
		
	if inter_data.secondary_flash_color != Color.TRANSPARENT:
		get_tree().create_timer(1.8).timeout.connect(func():
			if current_state == State.INTERLUDE and player and player.has_method("trigger_screen_flash"):
				player.trigger_screen_flash(inter_data.secondary_flash_color)
		)
		
	if inter_data.assist_message != "":
		get_tree().create_timer(1.2).timeout.connect(func():
			if current_state == State.INTERLUDE:
				spawn_popup(inter_data.assist_message)
		)


func start_boss_battle() -> void:
	current_state = State.BOSS
	state = "boss"
	
	if is_instance_valid(player):
		player.is_attack_unlocked = true
	
	if ui and ui.has_method("hide_wave_phase_hud"):
		ui.hide_wave_phase_hud()
		
	# ボス戦専用背景があれば切り替え
	if current_stage and current_stage.boss_background_texture:
		var bg_node = get_node_or_null("../ScrollingBackground")
		if bg_node and bg_node.has_method("set_background_texture"):
			bg_node.set_background_texture(current_stage.boss_background_texture)
	
	if boss:
		boss.visible = true
		boss.process_mode = PROCESS_MODE_INHERIT
		
		# ボスパラメータ適用
		var cfg = current_stage.boss_config if current_stage else null
		if cfg:
			boss.max_hp = cfg.max_hp
			if "current_hp" in boss:
				boss.current_hp = cfg.max_hp
		
		if boss.has_method("start_intro_sequence"):
			boss.start_intro_sequence(5.0)
		
		var b_name = cfg.name if cfg else "古代防衛要塞"
		if ui and ui.has_method("show_wave_announcement"):
			ui.show_wave_announcement("⚠️ BOSS WARNING ⚠️", "要塞ボス接近: 【" + b_name + "】", 4.0)


func check_win_lose() -> void:
	if is_instance_valid(player) and player.current_hp <= 0:
		current_state = State.DEFEAT
		state = "defeat"
		clear_all_bullets()
		show_game_over("DEFEAT")
	elif not is_instance_valid(boss) or (boss.has_method("get_current_hp") and boss.get_current_hp() <= 0):
		current_state = State.VICTORY_TRANSITION
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
	if not ui or not is_instance_valid(player):
		return
		
	ui.update_player_hp(player.current_hp, player.max_hp)
	
	if current_state == State.WAVE:
		if ui.has_method("update_wave_phase_hud"):
			ui.update_wave_phase_hud(current_wave_level, wave_phase_timer, total_wave_kills)
	else:
		if ui.has_method("hide_wave_phase_hud"):
			ui.hide_wave_phase_hud()
	
	if (current_state == State.BOSS or current_state == State.VICTORY_TRANSITION) and is_instance_valid(boss):
		var current_boss_hp = boss.get_current_hp() if boss.has_method("get_current_hp") else 0
		var max_boss_hp = boss.max_hp if "max_hp" in boss else 1000
		ui.update_boss_hp(current_boss_hp, max_boss_hp)
	else:
		ui.hide_boss_hp()
		
	ui.update_parry_count(parry_count)
	
	if ui.has_method("update_guard_heat"):
		ui.update_guard_heat(player.shield_heat, player.max_shield_heat, player.is_overheated, player.overheat_timer, player.is_guarding)
		
	if ui.has_method("update_pattern_analysis"):
		var traits = player.active_traits if "active_traits" in player else []
		ui.update_pattern_analysis(player.analysis_patterns, traits)
		
	if (current_state == State.BOSS or current_state == State.VICTORY_TRANSITION) and is_instance_valid(boss) and "energy_laser" in boss and ui.has_method("update_boss_energy"):
		ui.update_boss_energy(boss.energy_laser, boss.energy_missile, boss.energy_core)
	else:
		if ui and ui.has_method("hide_boss_energy"):
			ui.hide_boss_energy()


func register_parry() -> void:
	parry_count += 1
	wave_parry_count += 1


func register_analysis_upgrade() -> void:
	wave_upgrade_count += 1


func add_damage_score(amount: int) -> void:
	total_damage_score += amount


func add_tech_points(amount: int) -> void:
	Global.tech_points += amount
	if is_instance_valid(player):
		Global.save_game(current_stage_num, total_damage_score, player.weapons)


func on_boss_destroyed() -> void:
	current_state = State.VICTORY
	state = "victory"
	clear_all_bullets()
	
	if is_instance_valid(player):
		player.is_full_burst = false
		
	# ステージ報酬処理
	var reward = current_stage.reward_config
	if reward.counter_weapon_unlock != "" and not Global.unlocked_counter_weapons.has(reward.counter_weapon_unlock):
		Global.unlocked_counter_weapons.append(reward.counter_weapon_unlock)
		if reward.unlock_message != "":
			spawn_popup(reward.unlock_message)
			
	if reward.tech_points > 0:
		Global.tech_points += reward.tech_points
		spawn_popup("強化ポイント +%d 獲得！" % reward.tech_points)
		
	# 次ステージの開放（アンロック）処理
	var next_stage_num = current_stage_num + 1
	if reward.unlocked_stage > 0:
		next_stage_num = reward.unlocked_stage
	
	if next_stage_num <= 5:
		var is_new_unlock = Global.unlock_stage(next_stage_num)
		if is_new_unlock:
			spawn_popup("🔓 次の作戦エリア【STAGE %d】が解放されました！" % next_stage_num)
		
	if is_instance_valid(player):
		Global.save_game(current_stage_num, total_damage_score, {})
		
	show_game_over("VICTORY")


func spawn_popup(text: String) -> void:
	if player and player.has_method("spawn_popup_message"):
		player.spawn_popup_message(text)


func show_game_over(result: String) -> void:
	if ui and ui.has_method("show_game_over"):
		ui.show_game_over(result)


func restart() -> void:
	clean_stage_entities()
	get_tree().reload_current_scene()
