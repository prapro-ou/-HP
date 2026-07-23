extends Node

const SAVE_PATH = "user://savegame.cfg"
const SETTINGS_PATH = "user://settings.cfg"

# Save Game variables
var is_continue: bool = false
var has_save: bool = false
var selected_stage: int = 1

# Hangar & Research settings (Saved)
var shield_type: String = "parry" # "parry" or "mitigate"
var starting_weapon: String = "none" # "none", "beam", or "missile"
var hp_upgrade_level: int = 1
var speed_upgrade_level: int = 1
var shield_upgrade_level: int = 1

# Weapon Selection variables
var equipped_weapon: String = "machine_gun"

# New game state variables for customization & progression
var is_first_launch: bool = true
var tech_points: int = 0
var equipped_shield: String = "counter" # "counter" (damage/rebound), "gauge" (faster charge), "power" (buff primary)
var unlocked_weapons: Array = ["machine_gun", "pulse_gun"] # Available primary weapon frameworks
var unlocked_counter_weapons: Array = [] # Boss weapons unlocked for COUNTER SYSTEM
var upgrade_levels: Dictionary = {
	"hp": 0,
	"parry_window": 0,
	"cooldown": 0
}

# Weapon Dictionary Definition
var available_weapons: Dictionary = {
	"machine_gun": {
		"name": "STANDARD MACHINE GUN",
		"description": "Rapid-fire physical rounds. Offers steady fire rate and reliable coverage.",
		"stats": "DMG: ★★☆ | RATE: ★★★ | VEL: ★★☆",
		"unlocked": true
	},
	"burst_rifle": {
		"name": "3-ROUND BURST RIFLE",
		"description": "Fires 3-round bursts of high-impact penetrative bullets with short delay.",
		"stats": "DMG: ★★★ | RATE: ★★☆ | VEL: ★★★",
		"unlocked": true
	},
	"charge_rifle": {
		"name": "COIL CHARGE RIFLE",
		"description": "Charges energy to release a concentrated, high-damage railgun energy bolt.",
		"stats": "DMG: ★★★ | RATE: ★☆☆ | VEL: ★★★",
		"unlocked": true
	},
	"pulse_gun": {
		"name": "DUAL PULSE CANNON",
		"description": "Fires twin spreading plasma pulse waves. Excellent for crowd control.",
		"stats": "DMG: ★★☆ | RATE: ★★★ | VEL: ★☆☆",
		"unlocked": true
	}
}

# Settings variables
var master_volume: float = 80.0
var bgm_volume: float = 80.0
var sfx_volume: float = 80.0
var screen_shake: bool = true
var window_mode: int = 0 # 0: Windowed, 1: Fullscreen, 2: Borderless Windowed
var window_scale: float = 1.0 # 0.5, 0.75, 1.0, 1.25, 1.5
var aspect_ratio: int = 0 # 0: 2:3, 1: 3:4, 2: 9:16
var vsync: bool = true
var language: String = "ja" # "ja" or "en"

var translations = {
	"ja": {
		"menu_subtitle": "弾幕をパリィして兵器データを解析し、生き残れ",
		"btn_start_game": "作戦開始 / START GAME",
		"btn_hangar": "兵装編成 / HANGAR",
		"btn_research": "技術開発 / RESEARCH",
		"btn_settings": "環境設定 / SETTINGS",
		"btn_quit": "ゲーム終了 / QUIT",
		"btn_save_back": "適用して戻る / SAVE & BACK",
		"btn_reset_save": "セーブデータを初期化する / RESET SAVE DATA",
		
		"hangar_title": "HANGAR / 兵装編成",
		"hangar_shield_select": "シールドモジュール選択",
		"shield_parry_name": "パリィシールド (PARRY SHIELD)",
		"shield_parry_desc": "【機能】弾幕をパリィし弾速を上げて敵に跳ね返す。\n【冷却】5.0秒 | 【ゲージ蓄積】中",
		"shield_mitigate_name": "軽減シールド (MITIGATE SHIELD)",
		"shield_mitigate_desc": "【機能】敵の弾幕を消去し、被ダメージを軽減する。\n【冷却】3.0秒 | 【ゲージ蓄積】大 (反撃不可)",
		
		"research_title": "RESEARCH LAB / 技術開発",
		"research_credits": "回収済データ残量: %d TB",
		"research_hp_title": "機体耐久値 (MAX HP)",
		"research_hp_desc": "試作機の最大耐久力を底上げする。\n(現在: %d / 最大: %d)",
		"research_speed_title": "推進機関 (ENGINE SPEED)",
		"research_speed_desc": "機体の最大回避速度を向上する。\n(現在: %d / 最大: %d)",
		"research_shield_title": "シールド回路 (SHIELD RECHARGE)",
		"research_shield_desc": "シールドの充填速度（クールダウン）を短縮する。\n(現在: -%.1f秒 / 最大: -%.1f秒)",
		"btn_upgrade": "アップグレード: %d TB",
		"btn_upgrade_max": "限界突破 (MAX)",
		"insufficient_credits": "データ容量不足",
		
		"stage_select_title": "STAGE SELECT / 作戦領域選択",
		"btn_stage_back": "メインメニューに戻る / BACK",
		"briefing_title": "MISSION BRIEFING / 作戦指令",
		"btn_launch": "🖥️ 出撃開始 / LAUNCH",
		"btn_cancel": "戻る / CANCEL",
		
		"stage_01_name": "STAGE 01\nBEAM & MISSILE DRONES",
		"stage_02_name": "STAGE 02\nANCIENT GUARDIAN",
		"stage_02_locked": "🔒 STAGE 02\n[未解放 - ステージ01をクリアせよ]",
		
		"briefing_stage_1": "【領域】 作戦区域 01: ドローン警備網\n【脅威】 ビームドローン / ミサイルドローン\n\n【指令】 本セクターの自動警備部隊を無力化せよ。敵ドローンの弾幕をパリィすることで、その攻撃波形からエネルギー兵装データを抽出・複製可能。3回パリィで「BEAM」、さらに3回で「MISSILE」兵装のロックが解除される。",
		
		"briefing_stage_2": "【領域】 作戦区域 02: 古代防衛コア\n【脅威】 古代遺跡防衛要塞 (超大型ボス)\n\n【指令】 警備網深部の巨大防衛ユニットを撃破せよ。対象は破壊可能なサブアーム（レーザー部・ミサイル部）を持ち、コアを守っている。敵の攻撃エネルギー再配分比率を見極め、部位破壊を狙いコアを沈めよ。",
		
		"archive_title": "【兵装解析アーカイブ状況】\n",
		"archive_beam": "・ビームシステム:  ",
		"archive_missile": "・ミサイルシステム: ",
		"status_analyzed": "解析完了 (LV %d)",
		"status_progress": "データ収集中 (%d%%)",
		"status_unlocked": "未解析",
		
		# Sortie & Weapon Select Screen
		"sortie_title": "出撃準備 / DEPLOYMENT PREPARATION",
		"sortie_briefing": "作戦指令 / MISSION BRIEFING",
		"sortie_equipment": "兵装選択 / WEAPON & SHIELD",
		"weapon_rifle_name": "実弾マシンガン (STANDARD MACHINE GUN)",
		"weapon_rifle_desc": "【機能】標準装備の実弾機関砲。連射速度が高く、オート射撃を行う。\n【威力】低 | 【射撃】フルオート [常時装備]",
		"weapon_beam_name": "ビームシステム (BEAM LASER)",
		"weapon_beam_desc": "【機能】貫通力のある高出力光条。強力な一発を手動発射する。\n【威力】極大 | 【射撃】セミオート",
		"weapon_missile_name": "ミサイルシステム (HOMING MISSILE)",
		"weapon_missile_desc": "【機能】自動追尾誘導ミサイル。一定間隔で自動発射する。\n【威力】中 | 【射撃】フルオート追尾",
		"weapon_locked_msg": "【解析ロック】敵の攻撃波形データを解析せよ",
		"weapon_active_lbl": "▶ 装備中",
		"weapon_equip_btn": "装備する",
		"weapon_locked_lbl": "🔒 解析ロック中",
		
		# Gameplay UI
		"ui_vital_fmt": "生命力: %d / %d",
		"ui_boss_vital_fmt": "古代防衛要塞: %d / %d",
		"ui_parry_fmt": "パリィ解析数: %d",
		"ui_shield_active": "シールド展開: アクティブ！",
		"ui_shield_cooldown": "シールド再チャージ中 (%.1fs)",
		"ui_shield_ready": "シールド展開: 可能 (SPACE)",
		"ui_beam_active": "スロット1: ビーム [使用中]",
		"ui_beam_swap": "スロット1: ビーム [Z/Shiftで切替]",
		"ui_beam_analyzing": "スロット1: ビーム 解析中 [%d%%]",
		"ui_missile_active": "スロット2: ミサイル [使用中]",
		"ui_missile_swap": "スロット2: ミサイル [Z/Shiftで切替]",
		"ui_missile_analyzing": "スロット2: ミサイル 解析中 [%d%%]",
		"ui_boss_energy_fmt": "ボスエネルギー再配分:\nコア: %d%% | レーザー: %d%% | ミサイル: %d%%",
		"ui_shield_warning": "本体シールド有効: 部位を破壊せよ！",
		
		"gameover_defeat": "ミッション失敗",
		"gameover_victory": "ミッション完了",
		"gameover_stats": "累計パリィ抽出数: %d\nテクノロジー回収率: 100%%",
		"gameover_score_title": "最終ダメージスコア",
		"gameover_next_stage": "次のステージへ進む",
		"gameover_restart": "システムを再起動",
		"gameover_return_menu": "メインメニューに戻る",
		
		# Game Manager Popups
		"popup_wave1": "WAVE 1: ビームドローン接近中\nパリィを3回成功させてビーム兵器を解析せよ",
		"popup_wave2": "WAVE 2: ミサイルドローン接近中\nパリィを3回成功させてミサイル兵器を解析せよ",
		"popup_beam_break": "ビームシールド突破！\nデータの抽出に成功しました。",
		"popup_warning_title": "警告: 古代防衛兵器を検知",
		"popup_warning_sub": "エネルギー反応が限界値の 1000% を突破！",
		"popup_boss_engaged": "ボス戦開始: 古代防衛ユニット"
	},
	"en": {
		"menu_subtitle": "PARRY TO ANALYZE - SURVIVE THE BULLETS",
		"btn_start_game": "START GAME",
		"btn_hangar": "HANGAR",
		"btn_research": "RESEARCH LAB",
		"btn_settings": "SETTINGS",
		"btn_quit": "QUIT",
		"btn_save_back": "SAVE & BACK",
		"btn_reset_save": "RESET SAVE DATA",
		
		"hangar_title": "HANGAR / WEAPON & SHIELD",
		"hangar_shield_select": "SELECT SHIELD MODULE",
		"shield_parry_name": "PARRY SHIELD",
		"shield_parry_desc": "[EFFECT] Reflects bullets back with increased speed.\n[COOLDOWN] 5.0s | [CHARGE] Mid",
		"shield_mitigate_name": "MITIGATE SHIELD",
		"shield_mitigate_desc": "[EFFECT] Absorbs bullets and reduces damage. No reflection.\n[COOLDOWN] 3.0s | [CHARGE] High",
		
		"research_title": "RESEARCH LAB / UPGRADES",
		"research_credits": "HARVESTED DATA: %d TB",
		"research_hp_title": "MAX HP UPGRADE",
		"research_hp_desc": "Increases max durability.\n(Current: %d / Max: %d)",
		"research_speed_title": "ENGINE SPEED",
		"research_speed_desc": "Increases thruster movement speed.\n(Current: %d / Max: %d)",
		"research_shield_title": "SHIELD PROCESSOR",
		"research_shield_desc": "Reduces shield cooldown time.\n(Current: -%.1fs / Max: -%.1fs)",
		"btn_upgrade": "UPGRADE: %d TB",
		"btn_upgrade_max": "FULLY UPGRADED",
		"insufficient_credits": "INSUFFICIENT DATA",
		
		"stage_select_title": "STAGE SELECT",
		"btn_stage_back": "BACK TO MENU",
		"briefing_title": "MISSION BRIEFING",
		"btn_launch": "LAUNCH MISSION",
		"btn_cancel": "CANCEL",
		
		"stage_01_name": "STAGE 01\nBEAM & MISSILE DRONES",
		"stage_02_name": "STAGE 02\nANCIENT GUARDIAN",
		"stage_02_locked": "🔒 STAGE 02\n[LOCKED - CLEAR STAGE 01]",
		
		"briefing_stage_1": "[AREA] Sector 01: Drone Security Net\n[THREAT] Beam Drones / Missile Drones\n\n[DIRECTIVE] Neutralize the security force. Parry the drone attacks to harvest energy weapon data. 3 parries unlocks the BEAM weapon, and 3 more unlocks the MISSILE weapon.",
		
		"briefing_stage_2": "[AREA] Sector 02: Ancient Core\n[THREAT] Ancient Guardian Defense Weapon\n\n[DIRECTIVE] Defeat the giant defense unit in the deep core. The boss has destructible sub-arms (Laser/Missile) shielding its core. Destroy a part to drop the shield, then destroy the core.",
		
		"archive_title": "【WEAPON ARCHIVE STATUS】\n",
		"archive_beam": "・Beam System:    ",
		"archive_missile": "・Missile System: ",
		"status_analyzed": "ANALYZED (LV %d)",
		"status_progress": "ANALYZING (%d%%)",
		"status_unlocked": "UNANALYZED",
		
		# Sortie & Weapon Select Screen
		"sortie_title": "DEPLOYMENT PREPARATION",
		"sortie_briefing": "MISSION BRIEFING",
		"sortie_equipment": "WEAPON & SHIELD LOADOUT",
		"weapon_rifle_name": "STANDARD MACHINE GUN",
		"weapon_rifle_desc": "[EFFECT] Default kinetic rifle. Fires rapid bullets automatically.\n[POWER] Low | [FIRE] Full-Auto [Always Equipped]",
		"weapon_beam_name": "BEAM LASER SYSTEM",
		"weapon_beam_desc": "[EFFECT] High-intensity penetrating light. Fires powerful shot manually.\n[POWER] Massive | [FIRE] Semi-Auto",
		"weapon_missile_name": "HOMING MISSILE SYSTEM",
		"weapon_missile_desc": "[EFFECT] Self-guided homing missiles. Fires automatically.\n[POWER] Medium | [FIRE] Full-Auto Homing",
		"weapon_locked_msg": "[ANALYSIS LOCKED] Parry enemy bullet data to unlock",
		"weapon_active_lbl": "▶ ACTIVE",
		"weapon_equip_btn": "EQUIP",
		"weapon_locked_lbl": "🔒 LOCKED",
		
		# Gameplay UI
		"ui_vital_fmt": "PLAYER VITAL: %d / %d",
		"ui_boss_vital_fmt": "ANCIENT DEFENDER: %d / %d",
		"ui_parry_fmt": "EXTRACTED PARRIES: %d",
		"ui_shield_active": "SHIELD SYSTEM: ACTIVE!",
		"ui_shield_cooldown": "SHIELD SYSTEM: COOLDOWN (%.1fs)",
		"ui_shield_ready": "SHIELD SYSTEM: READY (SPACE)",
		"ui_beam_active": "SLOT 1: BEAM [ACTIVE]",
		"ui_beam_swap": "SLOT 1: BEAM [Z/Shift to Swap]",
		"ui_beam_analyzing": "SLOT 1: BEAM ANALYZING [%d%%]",
		"ui_missile_active": "SLOT 2: MISSILE [ACTIVE]",
		"ui_missile_swap": "SLOT 2: MISSILE [Z/Shift to Swap]",
		"ui_missile_analyzing": "SLOT 2: MISSILE ANALYZING [%d%%]",
		"ui_boss_energy_fmt": "ENERGY REALLOCATION:\nCORE: %d%% | LASER: %d%% | MISSILE: %d%%",
		"ui_shield_warning": "SHIELD ACTIVE: DESTROY PARTS FIRST!",
		
		"gameover_defeat": "SYSTEM DEFEATED",
		"gameover_victory": "MISSION ACCOMPLISHED",
		"gameover_stats": "TOTAL PARRIES EXTRACTED: %d\nTECHNOLOGY HARVEST: 100%%",
		"gameover_score_title": "FINAL DAMAGE SCORE",
		"gameover_next_stage": "PROCEED TO NEXT STAGE",
		"gameover_restart": "RESTART SYSTEM",
		"gameover_return_menu": "RETURN TO CORE SYSTEM",
		
		# Game Manager Popups
		"popup_wave1": "WAVE 1: BEAM DRONE INCOMING\nPARRY 3 TIMES TO ANALYZE BEAM",
		"popup_wave2": "WAVE 2: MISSILE DRONE INCOMING\nPARRY 3 TIMES TO ANALYZE MISSILE",
		"popup_beam_break": "BEAM SHIELD BREAK!\nDATA EXTRACTED SUCCESSFULLY.",
		"popup_warning_title": "WARNING: ANCIENT GUARDIAN DETECTION",
		"popup_warning_sub": "ENERGY SPIKE DETECTED - 1000% ABOVE CRITICAL",
		"popup_boss_engaged": "BOSS ENGAGED: ANCIENT DEFENSE SYSTEM"
	}
}

func translate(key: String) -> String:
	if translations.has(language) and translations[language].has(key):
		return translations[language][key]
	return key

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

func save_game(stage_num: int, score: int, weapons: Dictionary) -> void:
	var config = ConfigFile.new()
	var current_max = 1
	var current_data = load_game_data()
	current_max = current_data.get("max_unlocked_stage", 1)
	var new_max = max(current_max, stage_num)
	
	config.set_value("game", "max_unlocked_stage", new_max)
	config.set_value("game", "stage_num", stage_num)
	config.set_value("game", "score", score)
	config.set_value("game", "weapons", weapons)
	config.set_value("game", "shield_type", shield_type)
	config.set_value("game", "starting_weapon", starting_weapon)
	config.set_value("game", "hp_upgrade_level", hp_upgrade_level)
	config.set_value("game", "speed_upgrade_level", speed_upgrade_level)
	config.set_value("game", "shield_upgrade_level", shield_upgrade_level)
	config.set_value("game", "equipped_weapon", equipped_weapon)
	config.set_value("game", "is_first_launch", is_first_launch)
	config.set_value("game", "tech_points", tech_points)
	config.set_value("game", "equipped_shield", equipped_shield)
	config.set_value("game", "unlocked_weapons", unlocked_weapons)
	config.set_value("game", "unlocked_counter_weapons", unlocked_counter_weapons)
	config.set_value("game", "upgrade_levels", upgrade_levels)
	config.save(SAVE_PATH)
	has_save = true

func load_game_data() -> Dictionary:
	var config = ConfigFile.new()
	var data = {
		"stage_num": 1,
		"max_unlocked_stage": 1,
		"score": 0,
		"weapons": {},
		"shield_type": "parry",
		"starting_weapon": "none",
		"hp_upgrade_level": 1,
		"speed_upgrade_level": 1,
		"shield_upgrade_level": 1,
		"equipped_weapon": "machine_gun",
		"is_first_launch": true,
		"tech_points": 0,
		"equipped_shield": "counter",
		"unlocked_weapons": ["machine_gun", "pulse_gun"],
		"unlocked_counter_weapons": [],
		"upgrade_levels": {"hp": 0, "parry_window": 0, "cooldown": 0}
	}
	if config.load(SAVE_PATH) == OK:
		data["stage_num"] = config.get_value("game", "stage_num", 1)
		data["max_unlocked_stage"] = config.get_value("game", "max_unlocked_stage", 1)
		data["score"] = config.get_value("game", "score", 0)
		data["weapons"] = config.get_value("game", "weapons", {})
		data["shield_type"] = config.get_value("game", "shield_type", "parry")
		data["starting_weapon"] = config.get_value("game", "starting_weapon", "none")
		data["hp_upgrade_level"] = config.get_value("game", "hp_upgrade_level", 1)
		data["speed_upgrade_level"] = config.get_value("game", "speed_upgrade_level", 1)
		data["shield_upgrade_level"] = config.get_value("game", "shield_upgrade_level", 1)
		
		# Sync to Global properties
		shield_type = data["shield_type"]
		starting_weapon = data["starting_weapon"]
		hp_upgrade_level = data["hp_upgrade_level"]
		speed_upgrade_level = data["speed_upgrade_level"]
		shield_upgrade_level = data["shield_upgrade_level"]

		data["equipped_weapon"] = config.get_value("game", "equipped_weapon", "machine_gun")
		equipped_weapon = data["equipped_weapon"]
		
		data["is_first_launch"] = config.get_value("game", "is_first_launch", true)
		is_first_launch = data["is_first_launch"]
		
		data["tech_points"] = config.get_value("game", "tech_points", 0)
		tech_points = data["tech_points"]
		
		data["equipped_shield"] = config.get_value("game", "equipped_shield", "counter")
		equipped_shield = data["equipped_shield"]
		
		data["unlocked_weapons"] = config.get_value("game", "unlocked_weapons", ["machine_gun", "pulse_gun"])
		unlocked_weapons = data["unlocked_weapons"]
		
		data["unlocked_counter_weapons"] = config.get_value("game", "unlocked_counter_weapons", [])
		unlocked_counter_weapons = data["unlocked_counter_weapons"]
		
		data["upgrade_levels"] = config.get_value("game", "upgrade_levels", {"hp": 0, "parry_window": 0, "cooldown": 0})
		upgrade_levels = data["upgrade_levels"]
	return data

func delete_save_game() -> void:
	var dir = DirAccess.open("user://")
	if dir:
		if dir.file_exists("savegame.cfg"):
			dir.remove("savegame.cfg")
	has_save = false
	is_continue = false
	shield_type = "parry"
	starting_weapon = "none"
	hp_upgrade_level = 1
	speed_upgrade_level = 1
	shield_upgrade_level = 1
	equipped_weapon = "machine_gun"
	is_first_launch = true
	tech_points = 0
	equipped_shield = "counter"
	unlocked_weapons = ["machine_gun", "pulse_gun"]
	unlocked_counter_weapons = []
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
	config.set_value("display", "language", language)
	config.set_value("gameplay", "screen_shake", screen_shake)
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
		language = config.get_value("display", "language", "ja")
		screen_shake = config.get_value("gameplay", "screen_shake", true)

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
	match window_mode:
		0: # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1: # Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		2: # Borderless Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	
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
		
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)

func auto_scale_display() -> void:
	var screen_size = DisplayServer.screen_get_size()
	var monitor_height = screen_size.y
	
	var target_height = monitor_height - 120
	target_height = clamp(target_height, 600, 1200)
	
	var target_width = int(target_height * (2.0 / 3.0))
	
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_size(Vector2i(target_width, target_height))
	
	window_scale = snapped(float(target_height) / 1200.0, 0.05)
	window_mode = 0
	
	var screen_pos = DisplayServer.screen_get_position()
	var window_pos = screen_pos + (screen_size - Vector2i(target_width, target_height)) / 2
	window_pos.y = max(window_pos.y, 40)
	DisplayServer.window_set_position(window_pos)
	
	save_settings()
