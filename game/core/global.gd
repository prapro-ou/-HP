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
		"effect": "主兵装の連射速度を+30%〜+50%大幅加速",
		"stats": "連射速度: ＋30%〜50% | 弾数密度: 極大",
		"description": "青色ドローンの高速演算機構を解析。主兵装のエネルギー装填サイクルを極限まで短縮し、圧倒的な弾幕密度を実現する。"
	},
	"spread": {
		"name": "拡散射撃",
		"icon": "◈",
		"color": Color(0.2, 1.0, 0.6),
		"enemy_color": "緑色",
		"enemy_type": "拡散ウェイブ弾ドローン",
		"effect": "主兵装の同時発射弾数を増加（2連装➔4連装➔扇状拡散）",
		"stats": "同時発射数: ＋2〜4発 | 攻撃範囲: 扇状広域",
		"description": "緑色ドローンの広角プラズマ照射機構を解析。主兵装の射撃ラインを前方扇状に拡張し、複数の敵を一網打尽にする。"
	},
	"pierce": {
		"name": "貫通重弾",
		"icon": "▲",
		"color": Color(1.0, 0.6, 0.2),
		"enemy_color": "赤色",
		"enemy_type": "重装甲チャージ砲巡洋艦",
		"effect": "弾丸が敵を貫通し、基礎威力が大幅上昇",
		"stats": "単発威力: ＋6〜15 | 装甲貫通: 有効",
		"description": "赤色大型艦の高密度エネルギー充填コアを解析。弾丸に強力な貫通重力を付与し、硬い敵や後方の敵をまとめて貫通粉砕する。"
	},
	"homing": {
		"name": "誘導ミサイル",
		"icon": "▶",
		"color": Color(0.85, 0.45, 1.0),
		"enemy_color": "紫色",
		"enemy_type": "クラスター追尾ミサイル艦",
		"effect": "射撃時に最寄りの敵を自動追尾するマイクロミサイルを射出",
		"stats": "副兵装威力: 24〜45 | 索敵追尾: 100%",
		"description": "紫色ミサイル艦の生体誘導センサーを解析。主兵装射撃と連動して自動追尾ミサイルを斉射し、死角の敵も逃さず殲滅する。"
	},
	"laser": {
		"name": "フォトン光線",
		"icon": "━",
		"color": Color(0.4, 0.9, 1.0),
		"enemy_color": "シアン色",
		"enemy_type": "高出力ビーム砲台／要塞光線部",
		"effect": "超高速の直線フォトンビームを追加照射",
		"stats": "レーザー威力: 30〜60 | 弾速: 2400 (超高速)",
		"description": "要塞レーザー砲台の集束照射技術を解析。前方の敵を一瞬で焼き払う高出力フォトンレーザーを自機から連続照射する。"
	},
	"cyclone": {
		"name": "旋回スピン",
		"icon": "◎",
		"color": Color(1.0, 0.85, 0.2),
		"enemy_color": "黄色",
		"enemy_type": "不規則旋回ドローン／サイクロンポッド",
		"effect": "螺旋状に旋回しながら飛翔するトルネード弾を射出",
		"stats": "スピン威力: 22〜44 | 制圧力: 超広角",
		"description": "黄色不規則ドローンのジャイロ運動機構を解析。渦を巻いて広がるサイクロン弾を放ち、広域の敵弾と敵機を同時に薙ぎ払う。"
	},
	"meteor": {
		"name": "ギガメテオ",
		"icon": "●",
		"color": Color(1.0, 0.35, 0.2),
		"enemy_color": "橙色",
		"enemy_type": "要塞迎撃ギガメテオランチャー",
		"effect": "画面を粉砕する超巨大隕石を確率で前方に投下",
		"stats": "メテオ威力: 55〜110 | 範囲爆破: 超絶大",
		"description": "要塞メテオ射出砲の重力破砕技術を解析。超高密度のエネルギー質量体を前方へ投下し、画面内の敵に破滅的な破砕ダメージを与える。"
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

func check_save_game() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		has_save = true
	else:
		has_save = false

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
		"upgrade_levels": upgrade_levels
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
	return data

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
	# Window mode settings
	match window_mode:
		0: # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1: # Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		2: # Borderless Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	
	# Scale settings (only applied when windowed)
	if window_mode == 0 or window_mode == 2:
		var target_h = int(1200 * window_scale)
		var target_w = int(800 * window_scale)
		match aspect_ratio:
			0: # 2:3
				target_w = int(800 * window_scale)
			1: # 3:4
				target_w = int(900 * window_scale)
			2: # 9:16
				target_w = int(675 * window_scale)
		DisplayServer.window_set_size(Vector2i(target_w, target_h))
		
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
	
	# Set window mode to normal windowed
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_size(Vector2i(target_width, target_height))
	
	# Recalculate and update current scale setting
	window_scale = snapped(float(target_height) / 1200.0, 0.05)
	window_mode = 0
	
	# Center the window
	var screen_pos = DisplayServer.screen_get_position()
	var window_pos = screen_pos + (screen_size - Vector2i(target_width, target_height)) / 2
	window_pos.y = max(window_pos.y, 40)
	DisplayServer.window_set_position(window_pos)
	
	save_settings()
