extends Node

const SAVE_PATH = "user://savegame.cfg"
const SETTINGS_PATH = "user://settings.cfg"

# Save Game variables
var is_continue: bool = false
var has_save: bool = false

# Weapon Selection variables
var equipped_weapon: String = "machine_gun"

# New game state variables for customization & progression
var is_first_launch: bool = true
var tech_points: int = 0
var equipped_shield: String = "counter" # "counter" (damage/rebound), "gauge" (faster charge/absorb), "power" (buff primary)
var unlocked_shields: Array = ["counter"] # Available shield frameworks
var unlocked_weapons: Array = ["machine_gun", "burst_rifle", "pulse_gun"] # Available primary weapon frameworks
var unlocked_counter_weapons: Array = [] # Boss weapons unlocked for COUNTER SYSTEM
var unlocked_stages: Array = [1] # Unlocked stages (Stage 1 is unlocked by default)
var discovered_analysis_weapons: Array = [] # Discovered analysis mutation patterns
var upgrade_levels: Dictionary = {
	"hp": 0,
	"parry_window": 0,
	"cooldown": 0
}

# Catalog of all 7 Enemy Analysis Mutation Patterns
var analysis_catalog: Dictionary = {
	"rapid": {
		"name": "高速連射",
		"icon": "⚡",
		"color": Color(0.3, 0.8, 1.0),
		"enemy_color": "青色",
		"enemy_type": "直進フォトン弾ドローン",
		"effect": "主兵装の連射速度を+30%〜+50%短縮＆弾速を大幅加速",
		"stats": "連射速度: ＋30%〜50% | 弾速: ＋200〜450",
		"description": "青色ドローンの高速演算機構を解析。主兵装のエネルギー装填サイクルを極限まで短縮し、圧倒的な高速弾速と連射密度を実現する。"
	},
	"spread": {
		"name": "拡散射撃",
		"icon": "◈",
		"color": Color(0.2, 1.0, 0.6),
		"enemy_color": "緑色",
		"enemy_type": "拡散ウェイブ弾ドローン",
		"effect": "主兵装の同時発射ライン数を増加（2連装➔3連装➔多方向拡散）",
		"stats": "同時発射数: ＋1〜3発 | 攻撃範囲: 扇状広域",
		"description": "緑色ドローンの広角プラズマ照射機構を解析。主兵装の射撃ラインを前方扇状に拡張し、複数の敵を一網打尽にする。"
	},
	"pierce": {
		"name": "貫通重弾",
		"icon": "▲",
		"color": Color(1.0, 0.6, 0.2),
		"enemy_color": "赤色",
		"enemy_type": "重装甲チャージ砲巡洋艦",
		"effect": "主兵装の弾丸に装甲貫通属性を付与し、単発威力を大幅強化",
		"stats": "単発威力: ＋6〜14 | 貫通数: 1体〜全貫通",
		"description": "赤色大型艦の高密度エネルギー充填コアを解析。主兵装に強力な貫通重力を付与し、硬い敵や後方の敵をまとめて貫通粉砕する。"
	},
	"homing": {
		"name": "誘導弾道",
		"icon": "▶",
		"color": Color(0.85, 0.45, 1.0),
		"enemy_color": "紫色",
		"enemy_type": "クラスター追尾ミサイル艦",
		"effect": "主兵装の弾道に索敵誘導補正を付与し、敵を自動追尾",
		"stats": "追尾誘導力: ＋2.0〜4.5 | 命中率: 大幅向上",
		"description": "紫色ミサイル艦の生体誘導センサーを解析。主兵装の弾道が最寄りの敵へ向かって弧を描いて自動追尾し、敏捷な敵も逃さず仕留める。"
	},
	"laser": {
		"name": "集束光線",
		"icon": "━",
		"color": Color(0.4, 0.9, 1.0),
		"enemy_color": "シアン色",
		"enemy_type": "高出力ビーム砲台／要塞光線部",
		"effect": "主兵装をエネルギー集束光線ボルト化（弾速加速＆追加威力を付与）",
		"stats": "光線追加威力: ＋6〜14 | 弾速: ＋150",
		"description": "要塞レーザー砲台の集束照射技術を解析。主兵装の弾丸を高密度エネルギー光線ボルトへ変換し、高い貫通破壊力をもたらす。"
	},
	"cyclone": {
		"name": "旋回スピン",
		"icon": "◎",
		"color": Color(1.0, 0.85, 0.2),
		"enemy_color": "黄色",
		"enemy_type": "不規則旋回ドローン／サイクロンポッド",
		"effect": "主兵装の弾道に螺旋スピン波動を付与し、攻撃幅を大幅拡張",
		"stats": "波動振幅: 80〜160px | 制圧面積: 広域",
		"description": "黄色不規則ドローンのジャイロ運動機構を解析。主兵装の弾道が螺旋状にうねりながら飛翔し、広範囲の敵機を巻き込んで攻撃する。"
	},
	"meteor": {
		"name": "重爆装填",
		"icon": "●",
		"color": Color(1.0, 0.35, 0.2),
		"enemy_color": "橙色",
		"enemy_type": "要塞迎撃ギガメテオランチャー",
		"effect": "主兵装の弾丸に着弾時爆裂衝撃波を付与",
		"stats": "爆発半径: 45〜80px | 爆風威力: ＋6〜14",
		"description": "要塞メテオ射出砲の重力破砕技術を解析。主兵装が敵に着弾した瞬間、周囲へ爆発衝撃波が広がり周囲の敵ごと吹き飛ばす。"
	}
}

func is_stage_unlocked(stage_num: int) -> bool:
	return stage_num == 1 or unlocked_stages.has(stage_num)

func unlock_stage(stage_num: int) -> bool:
	if not unlocked_stages.has(stage_num):
		unlocked_stages.append(stage_num)
		unlocked_stages.sort()
		save_game()
		return true
	return false

func get_stage_difficulty_multiplier(stage_num: int) -> float:
	# ステージが進むごとに1.2倍ずつ敵の強さ（HP・攻撃力）が段階的に強くなる
	# Stage 1: 1.000x, Stage 2: 1.200x, Stage 3: 1.440x, Stage 4: 1.728x, Stage 5: 2.074x
	var exp_step = max(0, stage_num - 1)
	return pow(1.2, float(exp_step))

# Weapon Dictionary Definition
var available_weapons: Dictionary = {
	"machine_gun": {
		"name": "マシンガン",
		"description": "標準的な物理連射弾。高速連射と安定した制圧力を持つ主兵装。",
		"stats": "連射:★★★ | 威力:★★☆ | 弾速:★★☆",
		"unlocked": true
	},
	"burst_rifle": {
		"name": "ライフル (3点バースト)",
		"description": "単発火力・射程重視の徹甲3連射ライフル。硬い敵を貫通粉砕する。",
		"stats": "連射:★★☆ | 威力:★★★ | 弾速:★★★",
		"unlocked": true
	},
	"pulse_gun": {
		"name": "パルスガン",
		"description": "扇状に広がるプラズマ波動弾。広範囲の雑魚敵を一網打尽にする。",
		"stats": "連射:★★★ | 威力:★★☆ | 弾速:★☆☆",
		"unlocked": true
	},
	"plasma_emitter": {
		"name": "プラズマ放射器",
		"description": "超高熱のプラズマ球を射出。着弾時に持続放電フィールドを形成する。",
		"stats": "連射:★★☆ | 威力:★★★ | 弾速:★☆☆",
		"unlocked": false
	},
	"kinetic_tackle": {
		"name": "キネティックタックル",
		"description": "機体前方に強力な衝撃破砕波を発生させる超近接・突撃用兵装。",
		"stats": "連射:★☆☆ | 威力:★★★ | 弾速:★★☆",
		"unlocked": false
	}
}

# Player Appearance variables
var player_color: String = "blue"
var available_player_colors: Dictionary = {
	"blue": {
		"name": "コバルトブルー (標準)",
		"path": "res://game/assets/player/spaceship_small_blue.png",
		"accent_color": Color(0.2, 0.65, 1.0)
	},
	"red": {
		"name": "クリムゾンレッド",
		"path": "res://game/assets/player/spaceship_small_red.png",
		"accent_color": Color(1.0, 0.3, 0.3)
	},
	"green": {
		"name": "エメラルドグリーン",
		"path": "res://game/assets/player/spaceship_small_green.png",
		"accent_color": Color(0.2, 0.9, 0.4)
	},
	"yellow": {
		"name": "トパーズイエロー",
		"path": "res://game/assets/player/spaceship_small_yellow.png",
		"accent_color": Color(1.0, 0.85, 0.2)
	},
	"purple": {
		"name": "アメジストパープル",
		"path": "res://game/assets/player/spaceship_small_purple.png",
		"accent_color": Color(0.8, 0.35, 1.0)
	},
	"orange": {
		"name": "ソーラーオレンジ",
		"path": "res://game/assets/player/spaceship_small_orange.png",
		"accent_color": Color(1.0, 0.55, 0.1)
	}
}

func get_player_texture_path(color_key: String = "") -> String:
	var key = color_key if color_key != "" else player_color
	if available_player_colors.has(key):
		return available_player_colors[key]["path"]
	return "res://game/assets/player/spaceship_small_blue.png"

# Settings variables
var master_volume: float = 80.0
var bgm_volume: float = 80.0
var sfx_volume: float = 80.0
var screen_shake: bool = true
var window_mode: int = 0 # 0: Windowed, 1: Fullscreen, 2: Borderless Windowed
var window_scale: float = 1.0 # 0.5, 0.75, 1.0, 1.25, 1.5
var aspect_ratio: int = 0 # 0: 2:3, 1: 3:4, 2: 9:16
var vsync: bool = true

func _ready() -> void:
	load_settings()
	check_save_game()
	apply_all_settings()
	init_sound_pool()

func check_save_game() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		has_save = true
	else:
		has_save = false

var tutorial_flags: Dictionary = {
	"controls": false,
	"weapon_analysis": false,
	"time_limit": false,
	"boss_info": false
}

func save_game(stage_num: int = -1, score: int = -1, weapons: Dictionary = {}) -> void:
	var config = ConfigFile.new()
	var prev_stage = 1
	var prev_score = 0
	if config.load(SAVE_PATH) == OK:
		prev_stage = config.get_value("game", "stage_num", 1)
		prev_score = config.get_value("game", "score", 0)
		
	var final_stage = stage_num if stage_num > 0 else prev_stage
	var final_score = score if score >= 0 else prev_score
	
	config.set_value("game", "stage_num", final_stage)
	config.set_value("game", "score", final_score)
	config.set_value("game", "weapons", weapons)
	config.set_value("game", "equipped_weapon", equipped_weapon)
	config.set_value("game", "is_first_launch", is_first_launch)
	config.set_value("game", "tech_points", tech_points)
	config.set_value("game", "equipped_shield", equipped_shield)
	config.set_value("game", "unlocked_shields", unlocked_shields)
	config.set_value("game", "unlocked_weapons", unlocked_weapons)
	config.set_value("game", "unlocked_counter_weapons", unlocked_counter_weapons)
	config.set_value("game", "unlocked_stages", unlocked_stages)
	config.set_value("game", "discovered_analysis_weapons", discovered_analysis_weapons)
	config.set_value("game", "upgrade_levels", upgrade_levels)
	config.set_value("game", "tutorial_flags", tutorial_flags)
	config.save(SAVE_PATH)
	has_save = true

func load_game_data(sync_globals: bool = true) -> Dictionary:
	var config = ConfigFile.new()
	var data = {
		"stage_num": 1,
		"score": 0,
		"weapons": {},
		"equipped_weapon": equipped_weapon,
		"is_first_launch": is_first_launch,
		"tech_points": tech_points,
		"equipped_shield": equipped_shield,
		"unlocked_shields": unlocked_shields,
		"unlocked_weapons": unlocked_weapons,
		"unlocked_counter_weapons": unlocked_counter_weapons,
		"unlocked_stages": unlocked_stages,
		"discovered_analysis_weapons": discovered_analysis_weapons,
		"upgrade_levels": upgrade_levels,
		"tutorial_flags": tutorial_flags
	}
	if config.load(SAVE_PATH) == OK:
		data["stage_num"] = config.get_value("game", "stage_num", 1)
		data["score"] = config.get_value("game", "score", 0)
		data["weapons"] = config.get_value("game", "weapons", {})
		data["equipped_weapon"] = config.get_value("game", "equipped_weapon", equipped_weapon)
		data["is_first_launch"] = config.get_value("game", "is_first_launch", true)
		data["tech_points"] = config.get_value("game", "tech_points", 0)
		data["equipped_shield"] = config.get_value("game", "equipped_shield", equipped_shield)
		data["unlocked_shields"] = config.get_value("game", "unlocked_shields", ["counter"])
		data["unlocked_weapons"] = config.get_value("game", "unlocked_weapons", ["machine_gun", "burst_rifle", "pulse_gun"])
		data["unlocked_counter_weapons"] = config.get_value("game", "unlocked_counter_weapons", [])
		data["unlocked_stages"] = config.get_value("game", "unlocked_stages", [1])
		data["discovered_analysis_weapons"] = config.get_value("game", "discovered_analysis_weapons", [])
		data["upgrade_levels"] = config.get_value("game", "upgrade_levels", {"hp": 0, "parry_window": 0, "cooldown": 0})
		data["tutorial_flags"] = config.get_value("game", "tutorial_flags", {
			"controls": false,
			"weapon_analysis": false,
			"time_limit": false,
			"boss_info": false
		})
		
		if sync_globals:
			equipped_weapon = data["equipped_weapon"]
			is_first_launch = data["is_first_launch"]
			tech_points = data["tech_points"]
			equipped_shield = data["equipped_shield"]
			unlocked_shields = data["unlocked_shields"]
			unlocked_weapons = data["unlocked_weapons"]
			unlocked_counter_weapons = data["unlocked_counter_weapons"]
			unlocked_stages = data["unlocked_stages"]
			if not unlocked_stages.has(1):
				unlocked_stages.append(1)
				unlocked_stages.sort()
			discovered_analysis_weapons = data["discovered_analysis_weapons"]
			upgrade_levels = data["upgrade_levels"]
			tutorial_flags = data["tutorial_flags"]
	return data

func reset_upgrade_levels() -> void:
	upgrade_levels = {"hp": 0, "parry_window": 0, "cooldown": 0}
	save_game()

func reset_tech_points() -> void:
	tech_points = 0
	save_game()

func reset_development_progress() -> void:
	discovered_analysis_weapons = []
	unlocked_weapons = ["machine_gun", "burst_rifle", "pulse_gun"]
	unlocked_counter_weapons = []
	unlocked_shields = ["counter"]
	equipped_shield = "counter"
	equipped_weapon = "machine_gun"
	unlocked_stages = [1]
	tutorial_flags = {
		"controls": false,
		"weapon_analysis": false,
		"time_limit": false,
		"boss_info": false
	}
	save_game()

func delete_save_game() -> void:
	var dir = DirAccess.open("user://")
	if dir:
		if dir.file_exists("savegame.cfg"):
			dir.remove("savegame.cfg")
	has_save = false
	is_continue = false
	equipped_weapon = "machine_gun"
	is_first_launch = true
	tech_points = 0
	equipped_shield = "counter"
	unlocked_shields = ["counter"]
	unlocked_weapons = ["machine_gun", "burst_rifle", "pulse_gun"]
	unlocked_counter_weapons = []
	unlocked_stages = [1]
	discovered_analysis_weapons = []
	upgrade_levels = {"hp": 0, "parry_window": 0, "cooldown": 0}
	tutorial_flags = {
		"controls": false,
		"weapon_analysis": false,
		"time_limit": false,
		"boss_info": false
	}

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "bgm_volume", bgm_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("display", "window_mode", window_mode)
	config.set_value("display", "window_scale", window_scale)
	config.set_value("display", "aspect_ratio", aspect_ratio)
	config.set_value("display", "vsync", vsync)
	config.set_value("gameplay", "screen_shake", screen_shake)
	config.set_value("player", "player_color", player_color)
	config.save(SETTINGS_PATH)

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		master_volume = config.get_value("audio", "master_volume", 80.0)
		bgm_volume = config.get_value("audio", "bgm_volume", 80.0)
		sfx_volume = config.get_value("audio", "sfx_volume", 80.0)
		window_mode = config.get_value("display", "window_mode", 0)
		window_scale = config.get_value("display", "window_scale", 1.0)
		aspect_ratio = config.get_value("display", "aspect_ratio", 0)
		vsync = config.get_value("display", "vsync", true)
		screen_shake = config.get_value("gameplay", "screen_shake", true)
		player_color = config.get_value("player", "player_color", "blue")

func apply_all_settings() -> void:
	apply_audio()
	apply_display()

func apply_audio() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("BGM", bgm_volume)
	_set_bus_volume("SFX", sfx_volume)

func _set_bus_volume(bus_name: String, val: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var db = -60.0 if val <= 0.0 else linear_to_db(val / 100.0)
		AudioServer.set_bus_volume_db(idx, db)

func apply_display() -> void:
	var win: Window = null
	var tree = get_tree()
	if tree and tree.root:
		win = tree.root.get_window()

	# Determine base content resolution based on aspect ratio
	var base_w = 800
	var base_h = 1200
	match aspect_ratio:
		0: # 2:3
			base_w = 800
			base_h = 1200
		1: # 3:4
			base_w = 900
			base_h = 1200
		2: # 9:16
			base_w = 675
			base_h = 1200

	# Ensure Godot 4 automatically scales all canvas items, fonts, and UI with the window size
	if win:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		win.content_scale_size = Vector2i(base_w, base_h)

	# Target physical window size
	var target_w = int(base_w * window_scale)
	var target_h = int(base_h * window_scale)
	var target_size = Vector2i(target_w, target_h)

	# Window mode settings
	match window_mode:
		0: # Windowed
			if win:
				win.mode = Window.MODE_WINDOWED
				win.borderless = false
				win.size = target_size
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_size(target_size)
		1: # Fullscreen
			if win:
				win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		2: # Borderless Windowed
			if win:
				win.mode = Window.MODE_WINDOWED
				win.borderless = true
				win.size = target_size
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_size(target_size)
		
	# V-Sync
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)

func auto_scale_display() -> void:
	# One-touch optimizer: scales to fit vertical aspect of screen y-resolution
	var screen_size = DisplayServer.screen_get_size()
	var monitor_height = screen_size.y
	
	# Keep a safety margin for windows title bar and OS taskbar
	var target_height = monitor_height - 120
	target_height = clamp(target_height, 600, 1200)
	
	var target_width = int(target_height * (2.0 / 3.0))
	var target_size = Vector2i(target_width, target_height)
	
	var win: Window = null
	var tree = get_tree()
	if tree and tree.root:
		win = tree.root.get_window()
		
	if win:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		win.content_scale_size = Vector2i(800, 1200)
		win.mode = Window.MODE_WINDOWED
		win.borderless = false
		win.size = target_size
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_size(target_size)
	
	# Recalculate and update current scale setting
	window_scale = snapped(float(target_height) / 1200.0, 0.05)
	window_mode = 0
	
	# Center the window
	var screen_pos = DisplayServer.screen_get_position()
	var window_pos = screen_pos + (screen_size - target_size) / 2
	window_pos.y = max(window_pos.y, 40)
	if win:
		win.position = window_pos
	else:
		DisplayServer.window_set_position(window_pos)
	
	save_settings()


# ==========================================
# プロシージャル効果音生成・再生システム (Global Sound System)
# ==========================================

var _sfx_sounds: Dictionary = {}
var _sfx_player_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_size: int = 14
var _sfx_pool_index: int = 0
var _sfx_last_play_times: Dictionary = {}

func init_sound_pool() -> void:
	# サウンドプールの作成
	for i in range(_sfx_pool_size):
		var asp = AudioStreamPlayer.new()
		asp.bus = "SFX"
		add_child(asp)
		_sfx_player_pool.append(asp)
		
	# プロシージャルサウンドの生成・キャッシュ (8-bit PCM波形)
	_sfx_sounds["hit"] = _create_hit_sound(0.045, 950.0, 0.4, 0.5)
	_sfx_sounds["guard"] = _create_guard_sound(0.06, 1800.0)
	_sfx_sounds["parry"] = _create_parry_sound(0.18)
	_sfx_sounds["heavy_hit"] = _create_heavy_hit_sound(0.08, 420.0)
	_sfx_sounds["explosion"] = _create_explosion_sound(0.25)
	_sfx_sounds["turret_destroy"] = _create_explosion_sound(0.18)


func play_sound(sound_name: String, pitch_scale: float = 1.0, min_interval: float = 0.03) -> void:
	if _sfx_sounds.is_empty():
		init_sound_pool()
		
	var now = Time.get_ticks_msec() / 1000.0
	if _sfx_last_play_times.has(sound_name):
		if now - _sfx_last_play_times[sound_name] < min_interval:
			return
	_sfx_last_play_times[sound_name] = now
	
	if not _sfx_sounds.has(sound_name):
		return
		
	if _sfx_player_pool.is_empty():
		return
		
	var asp = _sfx_player_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % _sfx_player_pool.size()
	
	asp.stream = _sfx_sounds[sound_name]
	asp.pitch_scale = pitch_scale * randf_range(0.95, 1.05)
	asp.play()


func play_hit(pitch: float = 1.0) -> void:
	play_sound("hit", pitch, 0.035)


func play_guard(pitch: float = 1.0) -> void:
	play_sound("guard", pitch, 0.04)


func play_parry(pitch: float = 1.0) -> void:
	play_sound("parry", pitch, 0.03)


func play_heavy_hit(pitch: float = 1.0) -> void:
	play_sound("heavy_hit", pitch, 0.04)


func play_explosion(pitch: float = 1.0) -> void:
	play_sound("explosion", pitch, 0.08)


# --- プロシージャル波形生成ヘルパー ---

func _create_parry_sound(duration: float = 0.18) -> AudioStreamWAV:
	var sample_rate = 22050
	var sample_count = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(sample_count)
	
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 13.0)
		# 鋭い金属共鳴ベル倍音 (2800Hz, 4200Hz, 5600Hz, 8400Hz)
		var f1 = sin(TAU * 2800.0 * t) * 0.45
		var f2 = sin(TAU * 4200.0 * t) * 0.30
		var f3 = sin(TAU * 5600.0 * t) * 0.20
		var f4 = sin(TAU * 8400.0 * t) * 0.12
		var ping = (f1 + f2 + f3 + f4)
		var click = (randf() * 2.0 - 1.0) * exp(-progress * 90.0) * 0.9
		var sample = (ping * 0.82 + click * 0.38) * env
		var byte_val = int(clamp((sample + 1.0) * 127.5, 0, 255))
		data[i] = byte_val
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _create_hit_sound(duration: float, start_freq: float, noise_mix: float, tone_mix: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var sample_count = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(sample_count)
	
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 14.0)
		var freq = start_freq * (1.0 - progress * 0.7)
		var tone = sin(TAU * freq * t)
		var noise = randf() * 2.0 - 1.0
		var sample = (tone * tone_mix + noise * noise_mix) * env
		var byte_val = int(clamp((sample * 0.85 + 1.0) * 127.5, 0, 255))
		data[i] = byte_val
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav


func _create_guard_sound(duration: float, freq: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var sample_count = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(sample_count)
	
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 18.0)
		var tone1 = sin(TAU * freq * t)
		var tone2 = sin(TAU * (freq * 1.48) * t) * 0.5
		var noise = (randf() * 2.0 - 1.0) * 0.2
		var sample = (tone1 + tone2 + noise) * env * 0.8
		var byte_val = int(clamp((sample + 1.0) * 127.5, 0, 255))
		data[i] = byte_val
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav


func _create_heavy_hit_sound(duration: float, start_freq: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var sample_count = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(sample_count)
	
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 9.0)
		var freq = start_freq * (1.0 - progress * 0.6)
		var tone = sin(TAU * freq * t) + sin(TAU * (freq * 0.5) * t) * 0.5
		var noise = (randf() * 2.0 - 1.0) * 0.5
		var sample = (tone * 0.6 + noise * 0.4) * env * 0.9
		var byte_val = int(clamp((sample + 1.0) * 127.5, 0, 255))
		data[i] = byte_val
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav


func _create_explosion_sound(duration: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var sample_count = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(sample_count)
	
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 6.0)
		var low_rumble = sin(TAU * (120.0 * (1.0 - progress * 0.8)) * t) * 0.5
		var noise = (randf() * 2.0 - 1.0) * 0.8
		var sample = (low_rumble + noise) * env * 0.85
		var byte_val = int(clamp((sample + 1.0) * 127.5, 0, 255))
		data[i] = byte_val
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav
