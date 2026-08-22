extends Node

const BGM_CYBER19 = preload("res://game/assets/sounds/maou_bgm_cyber19.mp3")
const BGM_CYBER20 = preload("res://game/assets/sounds/maou_bgm_cyber20.mp3")
const BGM_CYBER35 = preload("res://game/assets/sounds/maou_bgm_cyber35.mp3")
const BGM_CYBER43 = preload("res://game/assets/sounds/maou_bgm_cyber43.mp3")

var bgm_stage1: AudioStream = BGM_CYBER35
var bgm_stage2: AudioStream = BGM_CYBER35
var bgm_stage3: AudioStream = BGM_CYBER20
var bgm_stage4: AudioStream = BGM_CYBER19
var bgm_stage5: AudioStream = BGM_CYBER43
var bgm_main_menu: AudioStream = null
var bgm_stage_select: AudioStream = BGM_CYBER20
var bgm_boss: AudioStream = BGM_CYBER43
var bgm_final_boss: AudioStream = BGM_CYBER43
var bgm_game_over: AudioStream = null
var bgm_victory: AudioStream = null

const SFX_HIT = preload("res://game/assets/sounds/打撃3.mp3")
const SFX_GUARD = preload("res://game/assets/sounds/ロボットを殴る2.mp3")
const SFX_PARRY = preload("res://game/assets/sounds/スローモーション.mp3")
const SFX_HEAVY_HIT = preload("res://game/assets/sounds/ロボットを強く殴る1.mp3")
const SFX_LASER = preload("res://game/assets/sounds/異次元空間.mp3")
const SFX_UPGRADE = preload("res://game/assets/sounds/決定ボタンを押す38.mp3")
const SFX_UI_CLICK = preload("res://game/assets/sounds/決定ボタンを押す9.mp3")
const SFX_UI_HOVER = preload("res://game/assets/sounds/カーソル移動4.mp3")
const SFX_UI_CANCEL = preload("res://game/assets/sounds/コンセントを抜く.mp3")

var bgm_fade_duration: float = 0.8
var sfx_pitch_randomness: float = 0.05
var sfx_pool_size: int = 16
var default_min_sfx_interval: float = 0.03

var _bgm_player_a: AudioStreamPlayer
var _bgm_player_b: AudioStreamPlayer
var _current_bgm_player: AudioStreamPlayer
var _current_bgm_name: String = ""
var _bgm_fade_tween: Tween

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0
var _sfx_last_play_times: Dictionary = {}
var _ui_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_nodes()

func _setup_audio_nodes() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.queue_free()
	_sfx_pool.clear()

	_bgm_player_a = _create_player("BGM_Player_A", "BGM")
	_bgm_player_b = _create_player("BGM_Player_B", "BGM")
	_current_bgm_player = _bgm_player_a
	_ui_player = _create_player("UI_Player", "UI")

	for i in range(sfx_pool_size):
		_sfx_pool.append(_create_player("SFX_Player_%d" % i, "SFX"))

func _create_player(p_name: String, bus_name: String) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.name = p_name
	p.bus = bus_name
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p

func play_bgm(bgm_key_or_stream: Variant, fade_time: float = -1.0) -> void:
	if fade_time < 0.0:
		fade_time = bgm_fade_duration
	var stream: AudioStream = bgm_key_or_stream if bgm_key_or_stream is AudioStream else get_bgm_stream(str(bgm_key_or_stream))
	var key_str: String = "custom_stream" if bgm_key_or_stream is AudioStream else str(bgm_key_or_stream)
	if stream == null or (_current_bgm_name == key_str and _current_bgm_player and _current_bgm_player.playing and _current_bgm_player.stream == stream):
		return
	_current_bgm_name = key_str
	var next_player = _bgm_player_b if _current_bgm_player == _bgm_player_a else _bgm_player_a
	var prev_player = _current_bgm_player
	if _bgm_fade_tween and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	_bgm_fade_tween = create_tween().set_parallel(true)
	next_player.stream = stream
	next_player.volume_db = -40.0
	next_player.play()
	if fade_time > 0.01:
		_bgm_fade_tween.tween_property(next_player, "volume_db", 0.0, fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if prev_player and prev_player.playing:
			_bgm_fade_tween.tween_property(prev_player, "volume_db", -40.0, fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_bgm_fade_tween.chain().tween_callback(prev_player.stop)
	else:
		next_player.volume_db = 0.0
		if prev_player:
			prev_player.stop()
	_current_bgm_player = next_player

func stop_bgm(fade_time: float = -1.0) -> void:
	if fade_time < 0.0:
		fade_time = bgm_fade_duration
	_current_bgm_name = ""
	if _bgm_fade_tween and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	if fade_time > 0.01 and _current_bgm_player and _current_bgm_player.playing:
		_bgm_fade_tween = create_tween()
		_bgm_fade_tween.tween_property(_current_bgm_player, "volume_db", -40.0, fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_bgm_fade_tween.tween_callback(_current_bgm_player.stop)
	else:
		if _bgm_player_a: _bgm_player_a.stop()
		if _bgm_player_b: _bgm_player_b.stop()

func get_bgm_stream(key: String) -> AudioStream:
	match key.to_lower():
		"main_menu", "menu", "title": return bgm_main_menu
		"stage_select", "stage_selection", "tech_lab", "select", "lab": return bgm_stage_select
		"stage1", "stage_1", "stage_01": return bgm_stage1
		"stage2", "stage_2", "stage_02": return bgm_stage2
		"stage3", "stage_3", "stage_03": return bgm_stage3
		"stage4", "stage_4", "stage_04": return bgm_stage4
		"stage5", "stage_5", "stage_05": return bgm_stage5
		"boss", "stage1_boss", "stage2_boss", "stage3_boss", "stage4_boss": return bgm_boss
		"final_boss", "stage5_boss": return bgm_final_boss
		"cyber19", "maou_bgm_cyber19": return BGM_CYBER19
		"cyber20", "maou_bgm_cyber20": return BGM_CYBER20
		"cyber35", "maou_bgm_cyber35": return BGM_CYBER35
		"cyber43", "maou_bgm_cyber43": return BGM_CYBER43
		"game_over", "gameover": return bgm_game_over
		"victory", "clear", "stage_clear": return bgm_victory
	return null

func play_sfx(sfx_key_or_stream: Variant, pitch_scale: float = 1.0, min_interval: float = -1.0, volume_offset_db: float = 0.0) -> void:
	if min_interval < 0.0:
		min_interval = default_min_sfx_interval
	var stream: AudioStream = sfx_key_or_stream if sfx_key_or_stream is AudioStream else get_sfx_stream(str(sfx_key_or_stream))
	var key_str: String = ("custom_stream_%d" % sfx_key_or_stream.get_instance_id()) if sfx_key_or_stream is AudioStream else str(sfx_key_or_stream)
	if stream == null:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if _sfx_last_play_times.has(key_str) and now - _sfx_last_play_times[key_str] < min_interval:
		return
	_sfx_last_play_times[key_str] = now
	if _sfx_pool.is_empty():
		_setup_audio_nodes()
		if _sfx_pool.is_empty():
			return
	var asp = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % _sfx_pool.size()
	asp.stream = stream
	asp.pitch_scale = pitch_scale * (1.0 + randf_range(-sfx_pitch_randomness, sfx_pitch_randomness))
	asp.volume_db = volume_offset_db
	asp.play()

func play_ui(sfx_key_or_stream: Variant, pitch_scale: float = 1.0) -> void:
	var stream: AudioStream = sfx_key_or_stream if sfx_key_or_stream is AudioStream else get_sfx_stream(str(sfx_key_or_stream))
	if stream == null:
		return
	if not is_instance_valid(_ui_player):
		_setup_audio_nodes()
	_ui_player.stream = stream
	_ui_player.pitch_scale = pitch_scale
	_ui_player.volume_db = 0.0
	_ui_player.play()

func get_sfx_stream(key: String) -> AudioStream:
	match key.to_lower():
		"hit": return SFX_HIT
		"guard": return SFX_GUARD
		"parry": return SFX_PARRY
		"heavy_hit": return SFX_HEAVY_HIT
		"laser": return SFX_LASER
		"upgrade", "upgrade_success": return SFX_UPGRADE
		"ui_click", "click", "btn_click": return SFX_UI_CLICK
		"ui_hover", "hover": return SFX_UI_HOVER
		"ui_cancel", "cancel", "back": return SFX_UI_CANCEL
	return null

func play_hit(pitch: float = 1.0) -> void: play_sfx("hit", pitch, 0.035)
func play_guard(pitch: float = 1.0) -> void: play_sfx("guard", pitch, 0.04)
func play_parry(pitch: float = 1.0) -> void: play_sfx("parry", pitch, 0.03)
func play_heavy_hit(pitch: float = 1.0) -> void: play_sfx("heavy_hit", pitch, 0.04)
func play_explosion(pitch: float = 1.0) -> void: play_sfx("heavy_hit", pitch * 0.8, 0.08)
func play_laser(pitch: float = 1.0) -> void: play_sfx("laser", pitch, 0.04)
func play_player_shoot(pitch: float = 1.0) -> void: play_sfx("laser", pitch * 1.4, 0.06)
func play_player_damage(pitch: float = 1.0) -> void: play_sfx("heavy_hit", pitch * 0.9, 0.1)
func play_boss_warning() -> void: play_sfx("laser", 0.7, 0.5)
func play_item_collect() -> void: play_sfx("ui_click", 1.5, 0.04)
func play_upgrade_success() -> void: play_sfx("upgrade", 1.0, 0.1)
func play_ui_click() -> void: play_ui("ui_click", 1.0)
func play_ui_hover() -> void: play_ui("ui_hover", 1.0)
func play_ui_cancel() -> void: play_ui("ui_cancel", 1.0)

func set_master_volume(val: float) -> void: _set_bus_volume("Master", val)
func set_bgm_volume(val: float) -> void: _set_bus_volume("BGM", val)
func set_sfx_volume(val: float) -> void: _set_bus_volume("SFX", val)
func set_ui_volume(val: float) -> void: _set_bus_volume("UI", val)

func _set_bus_volume(bus_name: String, val: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, -60.0 if val <= 0.0 else linear_to_db(val / 100.0))

func _exit_tree() -> void:
	if is_instance_valid(_bgm_player_a): _bgm_player_a.stop()
	if is_instance_valid(_bgm_player_b): _bgm_player_b.stop()
	if is_instance_valid(_ui_player): _ui_player.stop()
	for asp in _sfx_pool:
		if is_instance_valid(asp): asp.stop()
