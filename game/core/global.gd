extends Node

const SAVE_PATH = "user://savegame.cfg"
const SETTINGS_PATH = "user://settings.cfg"

# Save Game variables
var is_continue: bool = false
var has_save: bool = false
var selected_stage: int = 1

# Settings variables
var master_volume: float = 80.0
var bgm_volume: float = 80.0
var sfx_volume: float = 80.0
var screen_shake: bool = true
var window_mode: int = 0 # 0: Windowed, 1: Fullscreen, 2: Borderless Windowed
var window_scale: float = 1.0 # 0.5, 0.75, 1.0, 1.25, 1.5
var vsync: bool = true
var language: String = "ja" # "ja" or "en"

var translations = {
	"ja": {
		"menu_subtitle": "弾幕をパリィして兵器データを解析し、生き残れ",
		"btn_start_game": "ゲーム開始 / START GAME",
		"btn_settings": "環境設定 / SETTINGS",
		"btn_quit": "ゲーム終了 / QUIT",
		"btn_save_back": "適用して戻る / SAVE & BACK",
		"btn_reset_save": "セーブデータを初期化する / RESET SAVE DATA",
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
		
		# Gameplay UI
		"ui_player_vital": "プレイヤー生命力 / PLAYER VITAL",
		"ui_parries": "パリィ解析数: %d / EXTRACTED PARRIES: %d",
		"ui_shield_ready": "シールド展開: 可能 (SPACE) / READY",
		"ui_shield_recharging": "シールド再チャージ中 (%.1fs) / RECHARGING",
		"ui_shield_active": "シールド展開中 / ACTIVE",
		"ui_beam_label": "ビーム兵器 [%d%%]",
		"ui_beam_analyzed": "ビーム兵器 [解析完了]",
		"ui_missile_label": "ミサイル兵器 [%d%%]",
		"ui_missile_analyzed": "ミサイル兵器 [解析完了]",
		"ui_shield_warning": "本体シールド有効: 部位を破壊せよ！ / SHIELD ACTIVE: DESTROY PARTS!",
		
		"gameover_defeat": "ミッション失敗 / SYSTEM DEFEATED",
		"gameover_victory": "ミッション完了 / MISSION ACCOMPLISHED",
		"gameover_stats": "累計パリィ抽出数: %d\nテクノロジー回収率: 100%",
		"gameover_score_title": "最終ダメージスコア / FINAL DAMAGE SCORE",
		"gameover_next_stage": "次のステージへ進む / PROCEED",
		"gameover_restart": "システムを再起動 / RESTART",
		"gameover_return_menu": "メインメニューに戻る / RETURN",
		
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
		"btn_settings": "SETTINGS",
		"btn_quit": "QUIT",
		"btn_save_back": "SAVE & BACK",
		"btn_reset_save": "RESET SAVE DATA",
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
		
		# Gameplay UI
		"ui_player_vital": "PLAYER VITAL",
		"ui_parries": "EXTRACTED PARRIES: %d",
		"ui_shield_ready": "SHIELD SYSTEM: READY (SPACE)",
		"ui_shield_recharging": "SHIELD RECHARGING (%.1fs)",
		"ui_shield_active": "SHIELD ACTIVE",
		"ui_beam_label": "BEAM SYSTEM [%d%%]",
		"ui_beam_analyzed": "BEAM SYSTEM [ANALYZED]",
		"ui_missile_label": "MISSILE SYSTEM [%d%%]",
		"ui_missile_analyzed": "MISSILE SYSTEM [ANALYZED]",
		"ui_shield_warning": "SHIELD ACTIVE: DESTROY PARTS FIRST!",
		
		"gameover_defeat": "SYSTEM DEFEATED",
		"gameover_victory": "MISSION ACCOMPLISHED",
		"gameover_stats": "TOTAL PARRIES EXTRACTED: %d\nTECHNOLOGY HARVEST: 100%",
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
	config.save(SAVE_PATH)
	has_save = true

func load_game_data() -> Dictionary:
	var config = ConfigFile.new()
	var data = {
		"stage_num": 1,
		"max_unlocked_stage": 1,
		"score": 0,
		"weapons": {}
	}
	if config.load(SAVE_PATH) == OK:
		data["stage_num"] = config.get_value("game", "stage_num", 1)
		data["max_unlocked_stage"] = config.get_value("game", "max_unlocked_stage", 1)
		data["score"] = config.get_value("game", "score", 0)
		data["weapons"] = config.get_value("game", "weapons", {})
	return data

func delete_save_game() -> void:
	var dir = DirAccess.open("user://")
	if dir:
		if dir.file_exists("savegame.cfg"):
			dir.remove("savegame.cfg")
	has_save = false
	is_continue = false

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "bgm_volume", bgm_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("display", "window_mode", window_mode)
	config.set_value("display", "window_scale", window_scale)
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
		var target_w = int(800 * window_scale)
		var target_h = int(1200 * window_scale)
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
