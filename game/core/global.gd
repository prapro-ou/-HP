extends Node

const SAVE_PATH = "user://savegame_v3.cfg"
const SETTINGS_PATH = "user://settings_v3.cfg"

# Save Game variables
var is_continue: bool = false
var has_save: bool = false

# Weapon Selection variables
var equipped_weapon: String = "machine_gun"

# New game state variables for customization & progression
var is_first_launch: bool = true
var tech_points: int = 0
var equipped_shield: String = "counter" # "counter" (damage/rebound), "gauge" (faster charge/absorb), "power" (buff primary)
var equipped_counter_weapon: String = "turret" # "turret" (支援砲台部隊), "funnel" (サイバーファンネル部隊), "boss_beam", "boss_missile"
var unlocked_shields: Array = ["counter"] # Available shield frameworks
var unlocked_weapons: Array = ["machine_gun", "burst_rifle", "pulse_gun"] # Available primary weapon frameworks
var unlocked_counter_weapons: Array = ["turret", "funnel"] # Boss & support weapons unlocked for COUNTER SYSTEM
var unlocked_stages: Array = [1] # Unlocked stages (Stage 1 is unlocked by default)
var cleared_stages: Array = [] # Stages cleared at least once (unlocks hard mode for that stage)
var discovered_analysis_weapons: Array = [] # Discovered analysis mutation patterns
var upgrade_levels: Dictionary = {
	"hp": 0,
	"parry_window": 0,
	"cooldown": 0,
	"shot_power": 0,
	"capture_power": 0
}

# 各シールド固有のジャストガード範囲強化レベル (Lv.0〜5)
var shield_radius_upgrades: Dictionary = {
	"counter": 0,
	"gauge": 0,
	"power": 0
}

# ジャストガード フォーカス設定 (0: 標準 100%/1.0x, 1: 集中 75%/1.5x, 2: 極小ピンポイント 50%/2.2x)
var just_guard_focus_mode: int = 0

# COUNTER SYSTEM 強化レベル (Lv.0〜5)
var counter_system_duration_lvl: int = 0 # 10s -> 12s -> 14s -> 16s -> 18s -> 20s
var counter_system_power_lvl: int = 0    # 1.0x -> 1.2x -> 1.5x -> 2.0x -> 3.0x -> 5.0x

# エンドコンテンツ: COUNTER ONLY 出撃モード (ステージ5を5回クリア + 150 TPで解放)
var stage5_clears_count: int = 0
var counter_only_mode_unlocked: bool = false
var counter_only_mode_enabled: bool = false

# ハードモード設定 (敵HP 2.0倍 / 攻撃頻度 1.3倍 [攻撃スパン短縮])
var hard_mode_enabled: bool = false

# 操作キー割り当て設定
# 0: 両方 (WASD ＆ 十字キー), 1: WASD 専用, 2: 十字キー 専用, 3: カスタム割り当て
var control_move_preset: int = 0

# 各アクションのキーコード (任意のキーに割り当て可能)
var key_counter_system: int = KEY_X
var key_shield: int = KEY_SPACE
var key_up: int = KEY_W
var key_down: int = KEY_S
var key_left: int = KEY_A
var key_right: int = KEY_D
var key_weapon_prev: int = KEY_Q
var key_weapon_next: int = KEY_E

func get_key_display_name(keycode: int) -> String:
	match keycode:
		KEY_SPACE: return "Space"
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_ENTER: return "Enter"
		KEY_TAB: return "Tab"
		KEY_BACKSPACE: return "Backspace"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		_:
			var s = OS.get_keycode_string(keycode)
			return s.to_upper() if s != "" else ("Key " + str(keycode))

func get_counter_system_key_name() -> String:
	return get_key_display_name(key_counter_system)

func get_combat_key_name(keycode: int) -> String:
	var name := get_key_display_name(keycode)
	return {"BACKSPACE": "Bksp", "PAGEDOWN": "PgDn", "PAGEUP": "PgUp", "CAPSLOCK": "Caps", "PRINTSCREEN": "PrtSc", "SCROLLLOCK": "ScrLk"}.get(name.to_upper(), name)

func get_enemy_hp_multiplier() -> float:
	return 2.0 if hard_mode_enabled else 1.0

func get_enemy_attack_interval_multiplier() -> float:
	return (1.0 / 1.3) if hard_mode_enabled else 1.0

# TIPS 戦術アーカイブ管理 (出撃ごとに1つずつ解放)
var unlocked_tips: Array = ["tip_move", "tip_shoot"]
var unread_tips: Array = ["tip_move", "tip_shoot"]

var tips_categories: Dictionary = {
	"all": "すべて",
	"basic": "基本操作",
	"shield": "シールド",
	"attack": "攻撃",
	"boss": "ボス",
	"upgrade": "強化要素",
	"other": "その他"
}

var tips_catalog: Array[Dictionary] = [
	{
		"id": "tip_move",
		"category": "basic",
		"category_name": "基本操作",
		"title": "機体の基本移動と回避",
		"desc": "方向キーまたはWASDキーで機体を360度自在に移動できます。設定画面で移動キーを変更できます。",
		"hint": "操作: [WASD] / [方向キー]"
	},
	{
		"id": "tip_shoot",
		"category": "basic",
		"category_name": "基本操作",
		"title": "主兵装の常時フルオート射撃",
		"desc": "出撃直後から主兵装が自動で連射されます。捕まえた敵弾は、次の射撃に追撃として加わります。攻撃ボタンの押しっぱなしは不要なため、敵弾の回避やシールドでのパリィ、設定したキーでのCOUNTER発動に集中して立ち回ることができます。",
		"hint": "仕様: 常時フルオート自動連射 (攻撃操作不要)"
	},
	{
		"id": "tip_wave_route",
		"category": "basic",
		"category_name": "基本操作",
		"title": "敵部隊を倒して道中突破",
		"desc": "道中は3〜4組の有限ウェーブ。予定の出現と生存敵の処理が終わると次へ進み、全部隊の撃破で早くボスへ到達します。道中全体の上限は60秒で、ウェーブ間の待ちも含みます。ポーズと操作説明中は時計が止まります。",
		"hint": "突破: 次ウェーブへ+30HP/+10TP。時間切れで未突破分の報酬は入りません。"
	},
	{
		"id": "tip_guard_basic",
		"category": "shield",
		"category_name": "シールド",
		"title": "シールドの展開と熱管理",
		"desc": "設定したシールドキーまたは右クリックで展開し、通常の敵弾を捕まえます。ガード不可の攻撃は回避が必要です。カウンターシールドと増幅ブースターは熱で管理し、連続展開でオーバーヒートします。吸収マトリクスは熱を使わず、再展開までの待ち時間で管理します。",
		"hint": "操作: シールドキー / 右クリック。熱または再展開時間に注意"
	},
	{
		"id": "tip_just_guard",
		"category": "shield",
		"category_name": "シールド",
		"title": "パリィと捕獲追撃",
		"desc": "敵弾が自機周囲の有効範囲に入った瞬間にシールドを展開するとパリィが発動します。敵弾を捕まえて機体周囲に並べ、短く保持した後、次の射撃で追撃します。成功5回で機体を修復します。",
		"hint": "判定: 自機周囲のサイバーリング内に敵弾侵入時"
	},
	{
		"id": "tip_focus_tuning",
		"category": "shield",
		"category_name": "シールド",
		"title": "パリィのフォーカス設定",
		"desc": "技術研究所にて判定範囲を縮小する代わりに追撃威力を最大1.4倍まで引き上げることが可能です。リスクは高まりますが、強敵相手に圧倒的なカウンターダメージを与えられます。",
		"hint": "設定場所: 技術研究所 (STANDARD / FOCUS / PINPOINT)"
	},
	{
		"id": "tip_analysis_slot",
		"category": "attack",
		"category_name": "攻撃",
		"title": "捕まえた弾の追撃",
		"desc": "パリィで捕まえた弾が次の自動射撃に加わります。保持上限は12発。ミサイルは誘導、拡散弾は3方向、重弾は爆発の追撃になります。",
		"hint": "仕様: 最大12発 / 次の自動射撃で追撃"
	},
	{
		"id": "tip_fusion_weapon",
		"category": "attack",
		"category_name": "攻撃",
		"title": "主兵装と追撃の役割",
		"desc": "動く単体はマシンガンで射線を合わせ、縦列はバーストの貫通、横分散はパルスの広角、密集はプラズマの熱場で攻められます。捕まえた敵弾は、その弾の性質を持つ追撃になります。",
		"hint": "仕様: 主兵装は固定 / 追撃は捕まえた弾次第"
	},
	{
		"id": "tip_counter_system",
		"category": "attack",
		"category_name": "攻撃",
		"title": "COUNTER SYSTEM",
		"desc": "ボス戦中のパリィでゲージを満たし、設定した発動キーで装備中のカウンター兵装を使用します。通常出撃ではボス戦につき1回です。装備した兵装によって射線・狙い・範囲が異なります。準備完了を確認して、砲台や敵弾が集まる瞬間を狙って使いましょう。",
		"hint": "操作: 設定した発動キー / ボス戦中に充填"
	},
	{
		"id": "tip_boss_turret",
		"category": "boss",
		"category_name": "ボス",
		"title": "要塞ボスのサブ砲台と装甲",
		"desc": "サブ砲台が稼働している間、ボスの強固な防壁により本体へのダメージが大幅に軽減されます。まず左右のサブ砲台を集中破壊することで本体の装甲を破り大ダメージを与えられます。",
		"hint": "攻略要点: サブ砲台の破壊でボス装甲を解除"
	},
	{
		"id": "tip_unparryable",
		"category": "boss",
		"category_name": "ボス",
		"title": "ガード不可攻撃の緊急回避",
		"desc": "画面上部が赤く点灯した際はガード不可能な断絶レーザー攻撃の合図です。シールドを貫通して致命傷を与えるため、照射軸から直ちに機体を横移動させて回避してください。",
		"hint": "警告: 赤色点灯時はシールド無効・即座に離脱"
	},
	{
		"id": "tip_tech_points",
		"category": "upgrade",
		"category_name": "強化要素",
		"title": "調査ポイント(TP)と機体強化",
		"desc": "敵ドローンの撃破やサブ砲台の破壊、ステージクリアによりTPを獲得できます。獲得したTPは技術研究所にて最大HP増加、シールド範囲拡大、新兵装開発に使用します。",
		"hint": "用途: 技術研究所での恒久アップグレード"
	},
	{
		"id": "tip_shield_research",
		"category": "upgrade",
		"category_name": "強化要素",
		"title": "特殊シールドフレームの換装",
		"desc": "カウンターシールドは捕獲成功で熱を8返し、強い追撃へつなげます。吸収マトリクスは広い弾幕をまとめて捕まえ、再展開まで基本3秒。増幅ブースターは成功時に近距離衝撃波を放ち、2秒間の主兵装強化で攻め込めます。",
		"hint": "開発: 技術研究所にて各30 TPで開発"
	},
	{
		"id": "tip_counter_only",
		"category": "other",
		"category_name": "その他",
		"title": "極秘作戦：COUNTER ONLY出撃",
		"desc": "ステージ5を5回クリアし150 TPを消費することで解放される特殊作戦です。主兵装と捕獲追撃を停止し、選択したCOUNTER兵装を繰り返し使用できます。毎回、パリィで再充填して手動発動します。",
		"hint": "解放条件: STAGE 5を5回クリア ＆ 150 TP"
	}
]

# Catalog of all 10 Enemy Analysis Mutation Patterns
var analysis_catalog: Dictionary = WeaponCatalog.analysis_info()


func get_fusion_info(trait_a: String, trait_b: String) -> Dictionary:
	var a: Dictionary = analysis_catalog.get(trait_a, {})
	var b: Dictionary = analysis_catalog.get(trait_b, {})
	return {
		"name": "%s × %s" % [a.get("name", trait_a), b.get("name", trait_b)],
		"title_en": "%s + %s" % [trait_a.to_upper(), trait_b.to_upper()],
		"summary": "主兵装への複合強化",
		"description": "%s\n%s" % [a.get("description", ""), b.get("description", "")],
		"color": a.get("color", Color.CYAN).lerp(b.get("color", Color.CYAN), 0.5)
	}

func get_fusion_name(trait_a: String, trait_b: String) -> String:
	return get_fusion_info(trait_a, trait_b).get("name", "複合融合兵装")

func is_stage_unlocked(stage_num: int) -> bool:
	return stage_num == 1 or unlocked_stages.has(stage_num)

func unlock_stage(stage_num: int) -> bool:
	if practice_active:
		return false
	if not unlocked_stages.has(stage_num):
		unlocked_stages.append(stage_num)
		unlocked_stages.sort()
		save_game()
		return true
	return false

func is_stage_cleared(stage_num: int) -> bool:
	if cleared_stages.has(stage_num):
		return true
	# 後続のステージが解放済みの場合は前ステージをクリア済みと判定
	for s in unlocked_stages:
		if s > stage_num:
			return true
	return false

func mark_stage_cleared(stage_num: int) -> bool:
	if practice_active:
		return false
	if not cleared_stages.has(stage_num):
		cleared_stages.append(stage_num)
		cleared_stages.sort()
		save_game()
		return true
	return false

func is_stage_hard_unlocked(stage_num: int) -> bool:
	return is_stage_cleared(stage_num)

func get_stage_difficulty_multiplier(stage_num: int) -> float:
	# ステージが進むごとの敵の強さ（HP・攻撃力）の上昇率を大幅に緩和
	# Stage 1: 1.000x, Stage 2: 1.080x, Stage 3: 1.166x, Stage 4: 1.260x, Stage 5: 1.360x
	var exp_step = max(0, stage_num - 1)
	return pow(1.08, float(exp_step))

# Weapon Dictionary Definition
var available_weapons: Dictionary = WeaponCatalog.PRIMARY


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
	if development_debug_active():
		has_save = true
		return
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
	if practice_active:
		return
	if development_debug_active():
		var debug := get_node("/root/DebugTools")
		if stage_num > 0: debug.stage_num = stage_num
		if score >= 0: debug.score = score
		return
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
	config.set_value("game", "equipped_counter_weapon", equipped_counter_weapon)
	config.set_value("game", "unlocked_shields", unlocked_shields)
	config.set_value("game", "unlocked_weapons", unlocked_weapons)
	config.set_value("game", "unlocked_counter_weapons", unlocked_counter_weapons)
	config.set_value("game", "unlocked_stages", unlocked_stages)
	config.set_value("game", "cleared_stages", cleared_stages)
	config.set_value("game", "discovered_analysis_weapons", discovered_analysis_weapons)
	config.set_value("game", "upgrade_levels", upgrade_levels)
	config.set_value("game", "shield_radius_upgrades", shield_radius_upgrades)
	config.set_value("game", "just_guard_focus_mode", just_guard_focus_mode)
	config.set_value("game", "counter_system_duration_lvl", counter_system_duration_lvl)
	config.set_value("game", "counter_system_power_lvl", counter_system_power_lvl)
	config.set_value("game", "stage5_clears_count", stage5_clears_count)
	config.set_value("game", "counter_only_mode_unlocked", counter_only_mode_unlocked)
	config.set_value("game", "counter_only_mode_enabled", counter_only_mode_enabled)
	config.set_value("game", "hard_mode_enabled", hard_mode_enabled)
	config.set_value("game", "unlocked_tips", unlocked_tips)
	config.set_value("game", "unread_tips", unread_tips)
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
		"equipped_counter_weapon": equipped_counter_weapon,
		"unlocked_shields": unlocked_shields,
		"unlocked_weapons": unlocked_weapons,
		"unlocked_counter_weapons": unlocked_counter_weapons,
		"unlocked_stages": unlocked_stages,
		"cleared_stages": cleared_stages,
		"discovered_analysis_weapons": discovered_analysis_weapons,
		"upgrade_levels": upgrade_levels,
		"shield_radius_upgrades": shield_radius_upgrades,
		"just_guard_focus_mode": just_guard_focus_mode,
		"counter_system_duration_lvl": counter_system_duration_lvl,
		"counter_system_power_lvl": counter_system_power_lvl,
		"stage5_clears_count": stage5_clears_count,
		"counter_only_mode_unlocked": counter_only_mode_unlocked,
		"counter_only_mode_enabled": counter_only_mode_enabled,
		"hard_mode_enabled": hard_mode_enabled,
		"unlocked_tips": ["tip_move", "tip_shoot"],
		"unread_tips": ["tip_move", "tip_shoot"],
		"tutorial_flags": tutorial_flags
	}
	if development_debug_active():
		var debug := get_node("/root/DebugTools")
		data["stage_num"] = debug.stage_num
		data["score"] = debug.score
		data["unlocked_tips"] = unlocked_tips.duplicate()
		data["unread_tips"] = unread_tips.duplicate()
		return data
	if config.load(SAVE_PATH) == OK:
		data["stage_num"] = config.get_value("game", "stage_num", 1)
		data["score"] = config.get_value("game", "score", 0)
		data["weapons"] = config.get_value("game", "weapons", {})
		data["equipped_weapon"] = config.get_value("game", "equipped_weapon", equipped_weapon)
		data["is_first_launch"] = config.get_value("game", "is_first_launch", true)
		data["tech_points"] = config.get_value("game", "tech_points", 0)
		data["equipped_shield"] = config.get_value("game", "equipped_shield", equipped_shield)
		data["equipped_counter_weapon"] = config.get_value("game", "equipped_counter_weapon", "turret")
		data["unlocked_shields"] = config.get_value("game", "unlocked_shields", ["counter"])
		data["unlocked_weapons"] = config.get_value("game", "unlocked_weapons", ["machine_gun", "burst_rifle", "pulse_gun"])
		data["unlocked_counter_weapons"] = config.get_value("game", "unlocked_counter_weapons", ["turret", "funnel"])
		data["unlocked_stages"] = config.get_value("game", "unlocked_stages", [1])
		data["cleared_stages"] = config.get_value("game", "cleared_stages", [])
		data["discovered_analysis_weapons"] = config.get_value("game", "discovered_analysis_weapons", [])
		data["upgrade_levels"] = config.get_value("game", "upgrade_levels", {"hp": 0, "parry_window": 0, "cooldown": 0, "shot_power": 0, "capture_power": 0})
		data["shield_radius_upgrades"] = config.get_value("game", "shield_radius_upgrades", {"counter": 0, "gauge": 0, "power": 0})
		data["just_guard_focus_mode"] = config.get_value("game", "just_guard_focus_mode", 0)
		data["counter_system_duration_lvl"] = config.get_value("game", "counter_system_duration_lvl", 0)
		data["counter_system_power_lvl"] = config.get_value("game", "counter_system_power_lvl", 0)
		data["stage5_clears_count"] = config.get_value("game", "stage5_clears_count", 0)
		data["counter_only_mode_unlocked"] = config.get_value("game", "counter_only_mode_unlocked", false)
		data["counter_only_mode_enabled"] = config.get_value("game", "counter_only_mode_enabled", false)
		data["hard_mode_enabled"] = config.get_value("game", "hard_mode_enabled", false)
		data["unlocked_tips"] = config.get_value("game", "unlocked_tips", ["tip_move", "tip_shoot"])
		data["unread_tips"] = config.get_value("game", "unread_tips", ["tip_move", "tip_shoot"])
		data["tutorial_flags"] = config.get_value("game", "tutorial_flags", {
			"controls": false,
			"weapon_analysis": false,
			"time_limit": false,
			"boss_info": false
		})
		
		if sync_globals and not practice_active:
			equipped_weapon = data["equipped_weapon"]
			is_first_launch = data["is_first_launch"]
			tech_points = data["tech_points"]
			equipped_shield = data["equipped_shield"]
			equipped_counter_weapon = data["equipped_counter_weapon"]
			unlocked_shields = data["unlocked_shields"]
			unlocked_weapons = data["unlocked_weapons"]
			unlocked_counter_weapons = data["unlocked_counter_weapons"]
			unlocked_stages = data["unlocked_stages"]
			if not unlocked_stages.has(1):
				unlocked_stages.append(1)
				unlocked_stages.sort()
			cleared_stages = data["cleared_stages"]
			discovered_analysis_weapons = data["discovered_analysis_weapons"]
			upgrade_levels = data["upgrade_levels"]
			shield_radius_upgrades = data["shield_radius_upgrades"]
			just_guard_focus_mode = data["just_guard_focus_mode"]
			counter_system_duration_lvl = data["counter_system_duration_lvl"]
			counter_system_power_lvl = data["counter_system_power_lvl"]
			stage5_clears_count = data["stage5_clears_count"]
			counter_only_mode_unlocked = data["counter_only_mode_unlocked"]
			counter_only_mode_enabled = data["counter_only_mode_enabled"]
			hard_mode_enabled = data["hard_mode_enabled"]
			unlocked_tips = data["unlocked_tips"]
			unread_tips = data["unread_tips"]
			tutorial_flags = data["tutorial_flags"]
	return data

func reset_upgrade_levels() -> void:
	if not development_debug_active() or practice_active:
		return
	upgrade_levels = {"hp": 0, "parry_window": 0, "cooldown": 0, "shot_power": 0, "capture_power": 0}
	shield_radius_upgrades = {"counter": 0, "gauge": 0, "power": 0}
	just_guard_focus_mode = 0
	counter_system_duration_lvl = 0
	counter_system_power_lvl = 0
	save_game()

func reset_tech_points() -> void:
	if not development_debug_active() or practice_active:
		return
	tech_points = 0
	save_game()

func reset_development_progress() -> void:
	if not development_debug_active() or practice_active:
		return
	discovered_analysis_weapons = []
	unlocked_weapons = ["machine_gun", "burst_rifle", "pulse_gun"]
	unlocked_counter_weapons = ["turret", "funnel"]
	unlocked_shields = ["counter"]
	equipped_shield = "counter"
	equipped_counter_weapon = "turret"
	equipped_weapon = "machine_gun"
	unlocked_stages = [1]
	cleared_stages = []
	shield_radius_upgrades = {"counter": 0, "gauge": 0, "power": 0}
	just_guard_focus_mode = 0
	counter_system_duration_lvl = 0
	counter_system_power_lvl = 0
	stage5_clears_count = 0
	counter_only_mode_unlocked = false
	counter_only_mode_enabled = false
	hard_mode_enabled = false
	tutorial_flags = {
		"controls": false,
		"weapon_analysis": false,
		"time_limit": false,
		"boss_info": false
	}
	save_game()

func delete_save_game() -> bool:
	if development_debug_active() or practice_active:
		return false
	# A directory or an inaccessible file must never become a successful reset.
	if DirAccess.dir_exists_absolute(SAVE_PATH):
		return false
	if FileAccess.file_exists(SAVE_PATH):
		if DirAccess.remove_absolute(SAVE_PATH) != OK or FileAccess.file_exists(SAVE_PATH):
			return false
	has_save = false
	is_continue = false
	equipped_weapon = "machine_gun"
	is_first_launch = true
	tech_points = 0
	equipped_shield = "counter"
	unlocked_shields = ["counter"]
	unlocked_weapons = ["machine_gun", "burst_rifle", "pulse_gun"]
	equipped_counter_weapon = "turret"
	unlocked_counter_weapons = ["turret", "funnel"]
	unlocked_stages = [1]
	cleared_stages = []
	discovered_analysis_weapons = []
	upgrade_levels = {"hp": 0, "parry_window": 0, "cooldown": 0, "shot_power": 0, "capture_power": 0}
	shield_radius_upgrades = {"counter": 0, "gauge": 0, "power": 0}
	just_guard_focus_mode = 0
	counter_system_duration_lvl = 0
	counter_system_power_lvl = 0
	stage5_clears_count = 0
	counter_only_mode_unlocked = false
	counter_only_mode_enabled = false
	hard_mode_enabled = false
	unlocked_tips = ["tip_move", "tip_shoot"]
	unread_tips = ["tip_move", "tip_shoot"]
	tutorial_flags = {
		"controls": false,
		"weapon_analysis": false,
		"time_limit": false,
		"boss_info": false
	}
	return true

# --- TIPS 戦術アーカイブ ヘルパー関数 ---

func unlock_next_tip() -> String:
	if practice_active:
		return ""
	for tip in tips_catalog:
		var tip_id: String = tip["id"]
		if not unlocked_tips.has(tip_id):
			unlocked_tips.append(tip_id)
			unread_tips.append(tip_id)
			save_game()
			return tip["title"]
	return ""

func mark_tip_as_read(tip_id: String) -> void:
	if practice_active:
		return
	if unread_tips.has(tip_id):
		unread_tips.erase(tip_id)
		save_game()

func is_tip_unread(tip_id: String) -> bool:
	return unread_tips.has(tip_id)

func get_unread_tips_count() -> int:
	return unread_tips.size()

var readable_font: Font = null

func get_readable_font() -> Font:
	if readable_font == null and ResourceLoader.exists("res://game/assets/design/fonts/MPLUS1Code-Variable.ttf"):
		readable_font = load("res://game/assets/design/fonts/MPLUS1Code-Variable.ttf") as Font
	if readable_font == null:
		var sf = SystemFont.new()
		sf.font_names = PackedStringArray([
			"Yu Gothic UI",
			"Meiryo",
			"Hiragino Sans",
			"Hiragino Kaku Gothic ProN",
			"Noto Sans CJK JP",
			"Noto Sans JP",
			"MS Gothic",
			"sans-serif"
		])
		sf.antialiasing = TextServer.FONT_ANTIALIASING_LCD
		sf.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		readable_font = sf
	return readable_font

# --- COUNTER SYSTEM パラメータ計算 ---

func get_counter_system_duration() -> float:
	# 10.0秒 -> 12.0秒 -> 14.0秒 -> 16.0秒 -> 18.0秒 -> 20.0秒
	return 10.0 + counter_system_duration_lvl * 2.0

func get_counter_system_power_multiplier() -> float:
	# 1.0倍 -> 1.15倍 -> 1.30倍 -> 1.45倍 -> 1.60倍 -> 1.80倍
	match counter_system_power_lvl:
		0: return 1.0
		1: return 1.15
		2: return 1.30
		3: return 1.45
		4: return 1.60
		5: return 1.80
	return 1.0

# --- ジャストガード判定範囲 ＆ 威力倍率の計算 ---

func get_just_guard_radius(shield_type: String = "") -> float:
	var s_type = shield_type if shield_type != "" else equipped_shield
	var s_lvl = shield_radius_upgrades.get(s_type, 0)
	var global_window_lvl = upgrade_levels.get("parry_window", 0)
	
	# シールド別基礎半径
	var base_radius = 85.0
	match s_type:
		"counter":
			base_radius = 85.0 + s_lvl * 6.0 + global_window_lvl * 4.0
		"gauge":
			# 吸収マトリクス: 広域吸収仕様
			base_radius = 140.0 + s_lvl * 8.0 + global_window_lvl * 4.0
		"power":
			# パワーシールド: タイトな集中仕様
			base_radius = 75.0 + s_lvl * 5.0 + global_window_lvl * 4.0
			
	# フォーカス設定による範囲補正
	var focus_mult = 1.0
	match just_guard_focus_mode:
		0: focus_mult = 1.00 # STANDARD: 100%
		1: focus_mult = 0.75 # FOCUS: 75%
		2: focus_mult = 0.50 # PINPOINT: 50%
		
	return base_radius * focus_mult

func get_just_guard_damage_multiplier() -> float:
	# フォーカス設定によるジャストガード追撃威力倍率
	match just_guard_focus_mode:
		0: return 1.00 # 標準
		1: return 1.20 # 集中: 1.2倍 (+20%)
		2: return 1.40 # 極小ピンポイント: 1.4倍 (+40%)
	return 1.00

func get_focus_mode_info(mode: int = -1) -> Dictionary:
	var m = mode if mode >= 0 else just_guard_focus_mode
	match m:
		0:
			return {
				"mode": 0,
				"name": "STANDARD [標準範囲]",
				"radius_pct": "100%",
				"dmg_mult": "1.0倍",
				"description": "安定した標準範囲でのパリィ。安全な防御重視モード。"
			}
		1:
			return {
				"mode": 1,
				"name": "FOCUS [集中]",
				"radius_pct": "75% (-25%)",
				"dmg_mult": "1.2倍 (+20%)",
				"description": "有効範囲を25%絞る代わりに、捕獲追撃の威力が1.2倍に強化。"
			}
		2:
			return {
				"mode": 2,
				"name": "PINPOINT [極小高出力]",
				"radius_pct": "50% (-50%)",
				"dmg_mult": "1.4倍 (+40%)",
				"description": "有効範囲が半分になるハイリスク設定。成功時は追撃が1.4倍の破壊力に跳ね上がる！"
			}
	return {}

func save_settings() -> void:
	if practice_active or development_debug_active():
		return
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
	config.set_value("controls", "move_preset", control_move_preset)
	config.set_value("controls", "key_counter", key_counter_system)
	config.set_value("controls", "key_shield", key_shield)
	config.set_value("controls", "key_up", key_up)
	config.set_value("controls", "key_down", key_down)
	config.set_value("controls", "key_left", key_left)
	config.set_value("controls", "key_right", key_right)
	config.set_value("controls", "key_w_prev", key_weapon_prev)
	config.set_value("controls", "key_w_next", key_weapon_next)
	config.save(SETTINGS_PATH)

func load_settings() -> void:
	if development_debug_active():
		return
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
		control_move_preset = config.get_value("controls", "move_preset", config.get_value("controls", "move_type", 0))
		key_counter_system = config.get_value("controls", "key_counter", KEY_X)
		key_shield = config.get_value("controls", "key_shield", KEY_SPACE)
		key_up = config.get_value("controls", "key_up", KEY_W)
		key_down = config.get_value("controls", "key_down", KEY_S)
		key_left = config.get_value("controls", "key_left", KEY_A)
		key_right = config.get_value("controls", "key_right", KEY_D)
		key_weapon_prev = config.get_value("controls", "key_w_prev", KEY_Q)
		key_weapon_next = config.get_value("controls", "key_w_next", KEY_E)

func apply_all_settings() -> void:
	apply_audio()
	apply_display()

func apply_audio() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("BGM", bgm_volume)
	_set_bus_volume("SFX", sfx_volume)
	_set_bus_volume("UI", sfx_volume)

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
	var window_pos = screen_pos + Vector2i((Vector2(screen_size - target_size) * 0.5).round())
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
	_sfx_sounds["laser"] = _create_laser_sound(0.12)


func play_sound(sound_name: String, pitch_scale: float = 1.0, min_interval: float = 0.03) -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sound_name, pitch_scale, min_interval)
		return
		
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


func play_laser(pitch: float = 1.0) -> void:
	play_sound("laser", pitch, 0.04)


func play_upgrade_success(pitch: float = 1.0) -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_upgrade_success"):
		audio_mgr.play_upgrade_success()
	else:
		play_sound("upgrade", pitch, 0.05)


func play_ui_select() -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_ui_select"):
		audio_mgr.play_ui_select()


func play_ui_cancel() -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_ui_cancel"):
		audio_mgr.play_ui_cancel()


func _exit_tree() -> void:
	for asp in _sfx_player_pool:
		if is_instance_valid(asp):
			asp.stop()


# --- プロシージャル波形生成ヘルパー (44.1kHz 標準サンプリングレート) ---

func _create_parry_sound(duration: float = 0.18) -> AudioStreamWAV:
	var sample_rate = 44100
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
	var sample_rate = 44100
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
	var sample_rate = 44100
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
	var sample_rate = 44100
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
	var sample_rate = 44100
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


func _create_laser_sound(duration: float = 0.12) -> AudioStreamWAV:
	var sample_rate = 44100
	var sample_count = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(sample_count)
	
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 8.0)
		var freq = 2200.0 * (1.0 - progress * 0.75) + 300.0
		var tone = sin(TAU * freq * t)
		var sample = tone * env * 0.85
		var byte_val = int(clamp((sample + 1.0) * 127.5, 0, 255))
		data[i] = byte_val
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func get_primary_power_multiplier() -> float:
	return 1.0 + clampi(int(upgrade_levels.get("shot_power", 0)), 0, 5) * 0.08

func get_capture_power_multiplier() -> float:
	return 1.0 + clampi(int(upgrade_levels.get("capture_power", 0)), 0, 5) * 0.12

# Practice configuration survives retry, but no simulator state is persisted.
var practice_active: bool = false
var practice_config: Dictionary = {}
var return_to_options: bool = false
var _practice_snapshot: Dictionary = {}
const PRACTICE_STATE_KEYS = ["equipped_weapon", "is_first_launch", "tech_points", "equipped_shield", "equipped_counter_weapon", "unlocked_shields", "unlocked_weapons", "unlocked_counter_weapons", "unlocked_stages", "cleared_stages", "discovered_analysis_weapons", "upgrade_levels", "shield_radius_upgrades", "just_guard_focus_mode", "counter_system_duration_lvl", "counter_system_power_lvl", "stage5_clears_count", "counter_only_mode_unlocked", "counter_only_mode_enabled", "hard_mode_enabled", "unlocked_tips", "unread_tips", "tutorial_flags", "master_volume", "bgm_volume", "sfx_volume", "window_mode", "window_scale", "aspect_ratio", "vsync", "screen_shake", "player_color", "control_move_preset", "key_counter_system", "key_shield", "key_up", "key_down", "key_left", "key_right", "key_weapon_prev", "key_weapon_next", "is_continue", "has_save"]

func begin_practice(config: Dictionary) -> bool:
	var stage := int(config.get("stage", 1))
	var kind := str(config.get("kind", ""))
	if kind == "boss":
		if stage < 1 or stage > 5 or not is_stage_cleared(stage):
			return false
	elif kind == "drone":
		if not ["straight", "wave", "charge", "irregular", "laser", "beam", "missile", "thunder", "vortex", "blade", "meteor"].has(str(config.get("drone", ""))):
			return false
		config["stage"] = 1
	else:
		return false
	if not practice_active:
		for key in PRACTICE_STATE_KEYS:
			var value = get(key)
			_practice_snapshot[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	practice_config = config.duplicate(true)
	practice_active = true
	return true

func end_practice() -> void:
	if not practice_active:
		return
	for key in _practice_snapshot:
		set(key, _practice_snapshot[key])
	_practice_snapshot.clear()
	practice_active = false
	apply_all_settings()

func practice_infinite_hp() -> bool:
	return practice_active and bool(practice_config.get("infinite_hp", false))

func apply_body_font(node: Node) -> void:
	# Preserve short large display titles, use the bundled font for reading.
	if node is Label and node.label_settings != null:
		if node.label_settings.font_size < 32:
			node.label_settings = node.label_settings.duplicate()
			node.label_settings.font = get_readable_font()
	elif node is Control:
		node.add_theme_font_override("font", get_readable_font())
		if node is RichTextLabel:
			node.add_theme_font_override("normal_font", get_readable_font())
	for child in node.get_children():
		apply_body_font(child)

func development_debug_active() -> bool:
	var debug := get_node_or_null("/root/DebugTools")
	return debug != null and debug.is_active()

func debug_infinite_hp() -> bool:
	var debug := get_node_or_null("/root/DebugTools")
	return debug != null and debug.has_infinite_hp()

func get_window_scale_choices() -> Array[float]:
	var choices: Array[float] = [0.5, 0.75, 1.0, 1.25]
	if not choices.any(func(value): return is_equal_approx(value, window_scale)):
		choices.append(window_scale)
		choices.sort()
	return choices
