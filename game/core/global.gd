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

func save_game(stage_num: int, score: int, weapons: Dictionary) -> void:
	var config = ConfigFile.new()
	config.set_value("game", "stage_num", stage_num)
	config.set_value("game", "score", score)
	config.set_value("game", "weapons", weapons)
	config.set_value("game", "equipped_weapon", equipped_weapon)
	config.set_value("game", "is_first_launch", is_first_launch)
	config.set_value("game", "tech_points", tech_points)
	config.set_value("game", "equipped_shield", equipped_shield)
	config.set_value("game", "unlocked_shields", unlocked_shields)
	config.set_value("game", "unlocked_weapons", unlocked_weapons)
	config.set_value("game", "unlocked_counter_weapons", unlocked_counter_weapons)
	config.set_value("game", "upgrade_levels", upgrade_levels)
	config.save(SAVE_PATH)
	has_save = true

func load_game_data() -> Dictionary:
	var config = ConfigFile.new()
	var data = {
		"stage_num": 1,
		"score": 0,
		"weapons": {},
		"equipped_weapon": "machine_gun",
		"is_first_launch": true,
		"tech_points": 0,
		"equipped_shield": "counter",
		"unlocked_shields": ["counter"],
		"unlocked_weapons": ["machine_gun", "pulse_gun"],
		"unlocked_counter_weapons": [],
		"upgrade_levels": {"hp": 0, "parry_window": 0, "cooldown": 0}
	}
	if config.load(SAVE_PATH) == OK:
		data["stage_num"] = config.get_value("game", "stage_num", 1)
		data["score"] = config.get_value("game", "score", 0)
		data["weapons"] = config.get_value("game", "weapons", {})
		data["equipped_weapon"] = config.get_value("game", "equipped_weapon", "machine_gun")
		equipped_weapon = data["equipped_weapon"]
		
		data["is_first_launch"] = config.get_value("game", "is_first_launch", true)
		is_first_launch = data["is_first_launch"]
		
		data["tech_points"] = config.get_value("game", "tech_points", 0)
		tech_points = data["tech_points"]
		
		data["equipped_shield"] = config.get_value("game", "equipped_shield", "counter")
		equipped_shield = data["equipped_shield"]
		
		data["unlocked_shields"] = config.get_value("game", "unlocked_shields", ["counter"])
		unlocked_shields = data["unlocked_shields"]
		
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
	equipped_weapon = "machine_gun"
	is_first_launch = true
	tech_points = 0
	equipped_shield = "counter"
	unlocked_shields = ["counter"]
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
