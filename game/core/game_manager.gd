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
@onready var counter_system: CounterSystem = $CounterSystem

@onready var stage_container: Node2D = get_node("../StageContainer")
var current_stage: BaseStage = null
var current_stage_num: int = 1

# ステート
var state: String = "start" # 外部互換用文字列プロパティ
var current_state: State = State.START
var current_wave_index: int = 0
var current_wave_level: int = 1
var total_wave_kills: int = 0

# 有限ウェーブ全体の時計（ウェーブ間の待ちも含む）
const WAVE_PHASE_MAX_DURATION: float = 60.0
var wave_phase_timer: float = WAVE_PHASE_MAX_DURATION
var wave_clock_started: bool = false
var wave_elapsed: float = 0.0
var pending_wave_spawns: Array = []
var rewarded_wave_indices: Array[int] = []

# 戦績データ
var parry_count: int = 0
var total_damage_score: int = 0
var spawned_drones: Array = []
var state_timer: float = 0.0
var boss_drone_timer: float = 0.0
var stage_generation: int = 0

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
	if is_instance_valid(player) and player.get_node_or_null("ParryComponent"):
		player.get_node("ParryComponent").parry_succeeded.connect(_on_parry_succeeded)
	counter_system.gauge_changed.connect(_on_counter_gauge_changed)
	counter_system.counter_activated.connect(_on_counter_activated)
	counter_system.counter_finished.connect(_on_counter_finished)
	counter_system.state_changed.connect(_on_counter_state_changed)
	
	if bullet_pool and is_instance_valid(player):
		player.enemy_bullets = bullet_pool.active_bullets
		
	var save_data = {"stage_num": Global.practice_config.get("stage", 1), "score": 0} if Global.practice_active else Global.load_game_data(false)
	current_stage_num = clampi(int(save_data.get("stage_num", 1)), 1, 5)
		
	total_damage_score = save_data.get("score", 0)
	
	var stage_path = DEFAULT_STAGE_PATH_FMT % current_stage_num
	if not ResourceLoader.exists(stage_path):
		stage_path = FALLBACK_STAGE_PATH
		current_stage_num = 1
		
	load_stage(stage_path, current_stage_num)


func clean_stage_entities() -> void:
	"""前ステージの残存敵・ボス・弾幕・タイマーを完全に削除・初期化する"""
	stage_generation += 1
	cancel_wave_spawns()
	get_tree().paused = false
	Engine.time_scale = 1.0
	
	clear_all_bullets()
	clear_drones()
	
	for node in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(node) and node != player:
			if node.get("is_alive") != null:
				node.set("is_alive", false)
			node.queue_free()
			
	for node in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(node):
			node.queue_free()
			
	for node in get_tree().get_nodes_in_group("drone"):
		if is_instance_valid(node):
			node.queue_free()
			
	for node in get_tree().get_nodes_in_group("support_turrets"):
		if is_instance_valid(node):
			node.queue_free()
			
	if is_instance_valid(current_stage):
		current_stage.queue_free()
		current_stage = null
		
	parry_count = 0
	counter_system.reset_run()
	state_timer = 0.0
	boss_drone_timer = 0.0
	total_wave_kills = 0
	current_wave_index = 0
	current_wave_level = 1
	wave_phase_timer = WAVE_PHASE_MAX_DURATION
	rewarded_wave_indices.clear()
	current_state = State.START
	state = "start"
	
	if is_instance_valid(player) and player.has_method("reset_state"):
		player.reset_state()
		
	if is_instance_valid(ui):
		if ui.has_method("reset_counter_system_ui"):
			ui.reset_counter_system_ui()
		if ui.has_method("hide_boss_hp"):
			ui.hide_boss_hp()
		if ui.has_method("update_parry_count"):
			ui.update_parry_count(0)


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
	# 自機状態・位置の再確認（ステージ開始地点へ確実に配置）
	if is_instance_valid(player) and player.has_method("reset_state"):
		player.reset_state()
	
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
		
	if Global.practice_active:
		start_practice_session()
		return
	Global.save_game(current_stage_num, total_damage_score, {})
	
	current_state = State.START
	state = "start"
	current_wave_index = 0
	
	# ステージBGM再生
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_bgm"):
		audio_mgr.play_bgm("stage%d" % current_stage_num, 1.0)
	
	# ステージ開始の大判テロップ表示 (4.2秒間、画面中央に大きく表示)
	var st_name = current_stage.stage_name if current_stage else "STAGE " + str(current_stage_num)
	if Global.hard_mode_enabled:
		st_name += " [HARD MODE]"
	var codename = ""
	var goal = "敵弾を捕まえて追撃し、COUNTERでボスを撃破せよ"
	match current_stage_num:
		1:
			codename = "第1エリア: 惑星到達前・デブリ宙域"
			goal = "敵部隊の弾を捕まえ、追撃で防衛要塞を突破せよ！"
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
			goal = "敵弾を捕まえて追撃し、COUNTERでボスを撃破せよ"
			
	if Global.hard_mode_enabled:
		codename += " 【HARD: HP 2倍 / 攻撃 1.3倍】"
			
	goal += "\n全ウェーブ撃破で突破 / 道中は最大60秒"
	if ui and ui.has_method("show_stage_intro_banner"):
		ui.show_stage_intro_banner(current_stage_num, st_name, codename, goal)
	
	# 1. チュートリアル: 機体操作・射撃・パリィの説明（初回出撃時）
	if not Global.tutorial_flags.get("controls", false):
		schedule_stage(0.6, func():
			if ui and ui.has_method("show_tutorial_guide_modal"):
				ui.show_tutorial_guide_modal("controls")
		)
	
	var first_wave = current_stage.get_wave(0)
	if first_wave:
		schedule_stage(3.8, func():
			if current_state == State.START:
				if ui and ui.has_method("show_wave_announcement") and first_wave.start_message != "":
					ui.show_wave_announcement(first_wave.display_title, first_wave.start_message, 4.0)
				start_wave(0)
		)
	else:
		start_boss_battle()


func schedule_stage(delay: float, callback: Callable) -> void:
	var generation := stage_generation
	get_tree().create_timer(delay, false).timeout.connect(func():
		if is_inside_tree() and generation == stage_generation:
			callback.call()
	)

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
	if not is_instance_valid(current_stage) or get_tree().paused:
		return
	if wave_clock_started and current_state == State.WAVE and current_wave_index == index:
		return
	current_wave_index = index
	current_wave_level = index + 1
	current_state = State.WAVE
	state = "wave" + str(index + 1)
	var wave_data = current_stage.get_wave(index)
	if not wave_data:
		trigger_interlude()
		return
	wave_clock_started = true
	wave_elapsed = 0.0
	pending_wave_spawns = wave_data.initial_spawns.duplicate()
	pending_wave_spawns.sort_custom(func(a, b): return a.spawn_delay < b.spawn_delay)
	spawn_due_wave_drones()
	if index > 0 and ui:
		ui.show_wave_announcement("WAVE %d: %s" % [current_wave_level, wave_data.display_title], wave_data.start_message)

func cancel_wave_spawns() -> void:
	pending_wave_spawns.clear()
	wave_clock_started = false
	wave_elapsed = 0.0

func spawn_due_wave_drones() -> void:
	while not pending_wave_spawns.is_empty() and pending_wave_spawns[0].spawn_delay <= wave_elapsed:
		var config: BaseStage.WaveSpawnConfig = pending_wave_spawns.pop_front()
		var drone := spawn_drone(config.drone_type, Vector2(get_viewport_rect().size.x * config.pos_ratio_x, config.pos_y), config.is_slow)
		if drone != null and config.lane_y >= 0.0:
			drone.set_wave_lane(config.lane_y, config.lane_sway, config.entry_speed)

func alive_wave_drones() -> int:
	var alive := 0
	for drone in spawned_drones:
		if is_instance_valid(drone) and not drone.is_queued_for_deletion() and drone.is_alive:
			alive += 1
	return alive

func wave_remaining() -> int:
	return pending_wave_spawns.size() + alive_wave_drones()

func advance_wave_clock(delta: float) -> bool:
	if get_tree().paused or not wave_clock_started:
		return false
	check_win_lose()
	if current_state == State.DEFEAT:
		return false
	wave_phase_timer = maxf(0.0, wave_phase_timer - delta)
	if wave_phase_timer <= 0.0:
		trigger_interlude()
		return false
	return true

func spawn_drone(type: String, pos: Vector2, p_is_slow: Variant = null) -> Node2D:
	if not DRONE_SCENE:
		return null
	var drone = DRONE_SCENE.instantiate()
	drone.drone_type = type
	drone.global_position = pos
	if p_is_slow != null and "force_slow_mode" in drone:
		drone.force_slow_mode = p_is_slow
	get_parent().add_child(drone)
	spawned_drones.append(drone)
	return drone


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if Global.practice_active:
		process_practice(delta)
		update_ui()
		return
	match current_state:
		State.START:
			check_win_lose()
		State.WAVE:
			process_wave_state(delta)
		State.WAVE_TRANSITION:
			if not advance_wave_clock(delta):
				update_ui()
				return
			state_timer += delta
			var wave_data = current_stage.get_wave(current_wave_index - 1)
			var delay = wave_data.transition_delay if wave_data else 0.65
			if state_timer >= delay:
				start_wave(current_wave_index)
		State.INTERLUDE:
			state_timer += delta
			if state_timer >= 2.0:
				start_boss_battle()
		State.BOSS:
			check_win_lose()
			if current_stage and current_stage.boss_config.enable_support_drones:
				process_boss_support_drones(delta)
	update_ui()

func process_wave_state(delta: float) -> void:
	if not advance_wave_clock(delta):
		return
	if wave_phase_timer <= 30.0 and not Global.tutorial_flags.get("time_limit", false):
		if ui and ui.has_method("show_tutorial_guide_modal"):
			ui.show_tutorial_guide_modal("time_limit")
			return
	wave_elapsed += delta
	spawn_due_wave_drones()
	if wave_remaining() > 0:
		return
	if current_wave_index + 1 >= current_stage.waves.size():
		trigger_interlude()
		return
	if not rewarded_wave_indices.has(current_wave_index):
		rewarded_wave_indices.append(current_wave_index)
		player.heal(30)
		Global.tech_points += 10
	clear_all_bullets()
	current_wave_index += 1
	current_state = State.WAVE_TRANSITION
	state = "wave_transition"
	state_timer = 0.0

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
			var type = "straight"
			var rx = randf_range(100.0, get_viewport_rect().size.x - 100.0)
			var drone = spawn_drone(type, Vector2(rx, -50))
			if drone:
				if drone.has_method("set_override_speed"):
					drone.set_override_speed(160.0)
				else:
					drone.speed = 160.0
				drone.shoot_interval = 2.0


func clear_drones() -> void:
	for d in spawned_drones:
		if is_instance_valid(d):
			d.is_alive = false
			d.queue_free()
	spawned_drones.clear()


func on_drone_destroyed(drone) -> void:
	if spawned_drones.has(drone):
		spawned_drones.erase(drone)
		total_wave_kills += 1
		
		if ui and ui.has_method("update_wave_phase_hud"):
			update_ui()


func trigger_interlude() -> void:
	if not current_state in [State.WAVE, State.WAVE_TRANSITION, State.START]:
		return
	stage_generation += 1
	cancel_wave_spawns()
	current_state = State.INTERLUDE
	state = "interlude"
	state_timer = 0.0
	clear_all_bullets()
	clear_drones()
	if is_instance_valid(player):
		player.lock_controls()
	if is_instance_valid(ui):
		ui.hide_wave_phase_hud()
		ui.show_warning("BOSS APPROACHING", "パリィ追撃と、一度きりのCOUNTERで迎撃せよ")

func start_boss_battle() -> void:
	if current_state in [State.BOSS, State.DEFEAT, State.VICTORY, State.VICTORY_TRANSITION]:
		return
	cancel_wave_spawns()
	current_state = State.BOSS
	state = "boss"
	
	# ボスBGM再生 (ステージ5の場合はfinal_boss、それ以外はboss)
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_bgm"):
		var boss_bgm_key = "final_boss" if current_stage_num == 5 else "boss"
		audio_mgr.play_bgm(boss_bgm_key, 0.8)
	
	if is_instance_valid(player):
		player.is_control_locked = false
		player.is_attack_unlocked = true
	counter_system.begin_battle(Global.counter_only_mode_enabled)
	
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
			var mult = Global.get_stage_difficulty_multiplier(current_stage_num)
			boss.max_hp = int(cfg.max_hp * mult * Global.get_enemy_hp_multiplier())
			if "current_hp" in boss:
				boss.current_hp = boss.max_hp
		
		if Global.practice_active:
			boss.current_hp = int(boss.max_hp * (0.3 if Global.practice_config.get("intense", false) else 1.0))
		if boss.has_method("start_intro_sequence"):
			boss.start_intro_sequence(0.6 if Global.practice_active else 5.0)
		
		var b_name = cfg.name if cfg else "古代防衛要塞"
		if not Global.practice_active and ui and ui.has_method("show_wave_announcement"):
			ui.show_wave_announcement("BOSS WARNING", "要塞ボス接近: 【" + b_name + "】", 4.0)
			
		# 4. チュートリアル: ボスについて（ボス戦移行時・砲台の防御特性・パリィ不可攻撃の警告）
		if not Global.practice_active and not Global.tutorial_flags.get("boss_info", false):
			schedule_stage(1.2, func():
				if current_state == State.BOSS and ui and ui.has_method("show_tutorial_guide_modal"):
					ui.show_tutorial_guide_modal("boss_info")
			)


func check_win_lose() -> void:
	if is_instance_valid(player) and player.current_hp <= 0:
		stage_generation += 1
		cancel_wave_spawns()
		counter_system.reset_run()
		clear_drones()
		for enemy in get_tree().get_nodes_in_group("enemy"):
			enemy.set_process(false)
			if enemy.get("is_alive") != null:
				enemy.set("is_alive", false)
		player.is_control_locked = true
		player.is_attack_unlocked = false
		current_state = State.DEFEAT
		state = "defeat"
		clear_all_bullets()
		show_game_over("DEFEAT")
	elif current_state == State.BOSS and (not is_instance_valid(boss) or (boss.has_method("get_current_hp") and boss.get_current_hp() <= 0)):
		if current_state != State.VICTORY_TRANSITION and current_state != State.VICTORY:
			stage_generation += 1
			cancel_wave_spawns()
			counter_system.reset_run()
			clear_drones()
			current_state = State.VICTORY_TRANSITION
			state = "victory_transition"


func clear_all_bullets() -> void:
	if is_instance_valid(player) and is_instance_valid(player.capture_volley):
		player.capture_volley.clear()
	for group in ["plasma_heat_fields", "gravity_vortex_fields"]:
		for effect in get_tree().get_nodes_in_group(group):
			effect.queue_free()
	for node in get_tree().get_nodes_in_group("enemy_projectiles"):
		if not node.has_method("recycle_bullet"):
			node.queue_free()
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
	
	if Global.practice_active and current_state == State.WAVE:
		ui.update_practice_hud()
	elif current_state in [State.WAVE, State.WAVE_TRANSITION]:
		if ui.has_method("update_wave_phase_hud"):
			ui.update_wave_phase_hud(current_wave_index + 1, wave_phase_timer, total_wave_kills, wave_remaining(), current_stage.waves.size(), current_state == State.WAVE_TRANSITION)
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
		var gauge_ct = player.gauge_shield_timer if "gauge_shield_timer" in player else 0.0
		var max_gct = player.gauge_shield_cooldown if "gauge_shield_cooldown" in player else 3.0
		ui.update_guard_heat(player.shield_heat, player.max_shield_heat, player.is_overheated, player.overheat_timer, player.is_guarding, Global.equipped_shield, gauge_ct, max_gct)
		
	ui.update_capture_hud(player.capture_volley.shots, player.power_boost_remaining)

	if (current_state == State.BOSS or current_state == State.VICTORY_TRANSITION) and is_instance_valid(boss) and "energy_laser" in boss and ui.has_method("update_boss_energy"):
		ui.update_boss_energy(boss.energy_laser, boss.energy_missile, boss.energy_core)
	else:
		if ui and ui.has_method("hide_boss_energy"):
			ui.hide_boss_energy()


func register_parry() -> void:
	parry_count += 1


func _on_parry_succeeded(bullet_type: String, _hit_position: Vector2, streak: int) -> void:
	if current_state != State.WAVE and current_state != State.BOSS:
		return
	parry_count += 1
	if current_state == State.BOSS:
		counter_system.register_parry(streak, 1.5 if Global.equipped_shield == "gauge" else 1.0)
	if Global.practice_active:
		return
	var kinds: Array[String] = [WeaponCatalog.capture_kind(bullet_type)]
	for shot in player.capture_volley.shots:
		if not kinds.has(shot["kind"]):
			kinds.append(shot["kind"])
	var discovered := false
	for kind in kinds:
		if not Global.discovered_analysis_weapons.has(kind):
			Global.discovered_analysis_weapons.append(kind)
			discovered = true
	if discovered:
		Global.save_game()











func _on_counter_gauge_changed(value: float, ready: bool) -> void:
	if is_instance_valid(ui) and ui.is_node_ready() and ui.has_method("update_v3_counter_gauge"):
		ui.update_v3_counter_gauge(value, ready)


func request_counter_activation() -> void:
	if current_state != State.BOSS or not is_instance_valid(player) or player.current_hp <= 0:
		return
	if not counter_system.try_activate(player.get_counter_duration()):
		if counter_system.phase == CounterSystem.Phase.CHARGING:
			spawn_popup("COUNTER %d%%" % int(counter_system.gauge))
		elif counter_system.phase == CounterSystem.Phase.SPENT:
			spawn_popup("COUNTER 使用済み")

func _on_counter_activated() -> void:
	if is_instance_valid(player):
		player.activate_counter_system(counter_system.remaining)

func _on_counter_finished() -> void:
	if is_instance_valid(player):
		player.stop_counter_system()

func _on_counter_state_changed(phase: CounterSystem.Phase) -> void:
	if is_instance_valid(ui) and ui.is_node_ready():
		ui.update_v3_counter_status(phase, counter_system.gauge)
	if phase == CounterSystem.Phase.READY:
		spawn_popup("COUNTER READY")
		if is_instance_valid(player):
			player.trigger_parry_ring_effect(Color.GOLD)

func register_analysis_upgrade() -> void:
	pass


func add_damage_score(amount: int) -> void:
	if Global.practice_active:
		return
	total_damage_score += amount


func add_tech_points(amount: int) -> void:
	if Global.practice_active:
		return
	Global.tech_points += amount
	if is_instance_valid(player):
		Global.save_game(current_stage_num, total_damage_score, {})


func on_boss_destroyed() -> void:
	if Global.practice_active:
		return
	if current_state != State.BOSS and current_state != State.VICTORY_TRANSITION:
		return
	counter_system.reset_run()
	current_state = State.VICTORY
	state = "victory"
	clear_all_bullets()
	
	if is_instance_valid(player):
		player.stop_counter_system()
		
	# ステージ報酬処理
	var reward = current_stage.reward_config
	if reward.counter_weapon_unlock != "" and not Global.unlocked_counter_weapons.has(reward.counter_weapon_unlock):
		Global.unlocked_counter_weapons.append(reward.counter_weapon_unlock)
		if reward.unlock_message != "":
			spawn_popup(reward.unlock_message)
			
	if reward.tech_points > 0:
		Global.tech_points += reward.tech_points
		spawn_popup("強化ポイント +%d 獲得！" % reward.tech_points)
		
	# 現在ステージのクリア記録（ハードモード解放）
	var is_first_clear = Global.mark_stage_cleared(current_stage_num)
	if is_first_clear:
		spawn_popup("【HARD MODE 解放！】STAGE %d のハードモードが解放されました！" % current_stage_num)
		
	# 次ステージの開放（アンロック）処理
	var next_stage_num = current_stage_num + 1
	if reward.unlocked_stage > 0:
		next_stage_num = reward.unlocked_stage
	
	if next_stage_num <= 5:
		var is_new_unlock = Global.unlock_stage(next_stage_num)
		if is_new_unlock:
			spawn_popup("次の作戦エリア【STAGE %d】が解放されました！" % next_stage_num)
		
	if current_stage_num == 5:
		Global.stage5_clears_count += 1
		if Global.stage5_clears_count >= 5 and not Global.counter_only_mode_unlocked:
			spawn_popup("【極秘通信】ステージ5を5回攻略！テックラボにてCOUNTER ONLY出撃が解放可能になりました！")

	if is_instance_valid(player):
		Global.save_game(current_stage_num, total_damage_score, {})
		
	show_game_over("VICTORY")


func spawn_popup(text: String) -> void:
	if player and player.has_method("spawn_popup_message"):
		player.spawn_popup_message(text)


func show_game_over(result: String) -> void:
	if Global.practice_active:
		ui.show_practice_end()
		return
	# 出撃完了（クリアまたは撃破）ごとにTIPSアーカイブを1つ解放
	var unlocked_tip_title = Global.unlock_next_tip()
	if unlocked_tip_title != "":
		spawn_popup("【戦術アーカイブ解放】新規TIPS: 『%s』" % unlocked_tip_title)

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("stop_bgm"):
		audio_mgr.stop_bgm(0.5)
			
	if ui and ui.has_method("show_game_over"):
		ui.show_game_over(result)


func restart() -> void:
	clean_stage_entities()
	get_tree().reload_current_scene()

func debug_jump_to_boss() -> bool:
	if not Global.development_debug_active() or not current_state in [State.WAVE, State.WAVE_TRANSITION, State.INTERLUDE]:
		return false
	stage_generation += 1
	cancel_wave_spawns()
	counter_system.reset_run()
	player.stop_counter_system()
	player.lock_controls()
	clear_all_bullets()
	for drone in spawned_drones:
		if is_instance_valid(drone): drone.is_alive = false
	clear_drones()
	ui.warning_title.hide()
	ui.warning_subtitle.hide()
	start_boss_battle()
	return true

var practice_spawn_timer: float = 0.0
var practice_spawned_once: bool = false

func start_practice_session() -> void:
	practice_spawn_timer = 0.0
	practice_spawned_once = false
	total_damage_score = 0
	if Global.practice_config.get("kind") == "boss":
		start_boss_battle()
	else:
		current_state = State.WAVE
		state = "practice"
		spawn_practice_drone()
	ui.show_practice_hint(str(Global.practice_config.get("drone", "boss")))

func spawn_practice_drone() -> void:
	var width := get_viewport_rect().size.x
	# Offset from the automatic forward fire so the first capture can be observed.
	spawn_drone(str(Global.practice_config.get("drone", "straight")), Vector2(width * 0.28, 160.0))
	practice_spawned_once = true

func process_practice(delta: float) -> void:
	if current_state == State.DEFEAT:
		return
	if player.current_hp <= 0:
		check_practice_defeat()
		return
	if current_state == State.BOSS:
		if current_stage.boss_config.enable_support_drones:
			process_boss_support_drones(delta)
	elif current_state == State.WAVE:
		practice_spawn_timer -= delta
		var alive := 0
		for drone in spawned_drones:
			if is_instance_valid(drone) and drone.is_alive and not drone.is_queued_for_deletion():
				alive += 1
		if Global.practice_config.get("repeat", false) and alive < 3 and practice_spawn_timer <= 0.0:
			spawn_practice_drone()
			practice_spawn_timer = 2.0

func check_practice_defeat() -> void:
	stage_generation += 1
	cancel_wave_spawns()
	counter_system.reset_run()
	player.stop_counter_system()
	player.lock_controls()
	clear_all_bullets()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.get("is_alive") != null:
			enemy.set("is_alive", false)
		enemy.process_mode = PROCESS_MODE_DISABLED
	current_state = State.DEFEAT
	state = "defeat"
	Engine.time_scale = 1.0
	ui.show_practice_end()

func exit_practice(to_options: bool = false) -> void:
	clean_stage_entities()
	player.stop_counter_system()
	Global.end_practice()
	Global.return_to_options = to_options
	get_tree().change_scene_to_file("res://game/core/main_menu.tscn" if to_options else "res://game/core/practice_setup.tscn")
