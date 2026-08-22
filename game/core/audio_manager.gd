@tool
extends Node

## ====================================================================
## AudioManager (オーディオマネージャー / 手動オーディオ設定ノード)
## ====================================================================
## 【概要】
## Godotエディタのインスペクターからドラッグ＆ドロップで
## BGMや効果音(SFX)を手動設定・管理・テスト試聴できる一元管理ノードです。
##
## 【特徴】
## 1. インスペクターで各シーンのBGMや効果音ファイルを直接登録可能。
## 2. 音源ファイルが未設定(null)のスロットは、自動でプロシージャル合成音がフォールバック再生されます。
## 3. BGMのクロスフェード・フェードアウト対応。
## 4. 効果音のプール再生（音切れ防止）＆ピッチの自動ランダム微変動。
## 5. エディタ内でのワンクリック試聴（インスペクターテスト）対応。
## ====================================================================

# ----------------------------------------------------------------------
# 🎵 BGM スロット設定 (インスペクターから手動でドラッグ＆ドロップ可能)
# ----------------------------------------------------------------------
@export_group("🎵 BGM スロット (手動割り当て)")
## メインメニュー / タイトル画面 BGM
@export var bgm_main_menu: AudioStream
## ステージ選択 / 兵装選択 / 研究所 BGM
@export var bgm_stage_select: AudioStream
## ステージ1 BGM
@export var bgm_stage1: AudioStream
## ステージ2 BGM
@export var bgm_stage2: AudioStream
## ステージ3 BGM
@export var bgm_stage3: AudioStream
## ステージ4 BGM
@export var bgm_stage4: AudioStream
## ステージ5 BGM
@export var bgm_stage5: AudioStream
## ボス戦 BGM
@export var bgm_boss: AudioStream
## 最終ボス戦 BGM
@export var bgm_final_boss: AudioStream
## ゲームオーバー BGM / ジングル
@export var bgm_game_over: AudioStream
## ステージクリア / 勝利 BGM / ジングル
@export var bgm_victory: AudioStream

## 任意のキー名でBGMを追加登録できるカスタム辞書 (例: "extra_boss": res://...)
@export var custom_bgm: Dictionary = {}

# ----------------------------------------------------------------------
# 🔊 SFX 効果音スロット (インスペクターから手動でドラッグ＆ドロップ可能)
# ----------------------------------------------------------------------
@export_group("🔊 SFX 効果音スロット (手動割り当て)")
## 敵被弾音 (未設定時はプロシージャル合成音を自動再生)
@export var sfx_hit: AudioStream
## シールドガード音
@export var sfx_guard: AudioStream
## パリィ成功音 (高音金属共鳴音)
@export var sfx_parry: AudioStream
## 重攻撃・強弾ヒット音
@export var sfx_heavy_hit: AudioStream
## 撃破・爆発音
@export var sfx_explosion: AudioStream
## レーザー照射音
@export var sfx_laser: AudioStream
## 自機通常ショット発射音
@export var sfx_player_shoot: AudioStream
## 自機被弾音
@export var sfx_player_damage: AudioStream
## 自機撃破音
@export var sfx_player_death: AudioStream
## ボス警告アラート音
@export var sfx_boss_warning: AudioStream
## データオーブ・TP取得音
@export var sfx_item_collect: AudioStream
## 研究所 強化・開発完了音
@export var sfx_upgrade_success: AudioStream
## UI 決定 / ボタンクリック音
@export var sfx_ui_click: AudioStream
## UI 選択フォーカス / ホバー音
@export var sfx_ui_hover: AudioStream
## UI キャンセル / 戻る音
@export var sfx_ui_cancel: AudioStream

## 任意のキー名で効果音を追加登録できるカスタム辞書 (例: "teleport": res://...)
@export var custom_sfx: Dictionary = {}

# ----------------------------------------------------------------------
# 🎛️ 音響バランス・動作設定
# ----------------------------------------------------------------------
@export_group("🎛️ 再生＆バランス設定")
## BGM切り替え時のフェード時間（秒）
@export_range(0.0, 5.0, 0.1) var bgm_fade_duration: float = 0.8
## 効果音再生時のランダムピッチ揺らぎ幅（例: 0.05 = 0.95x ~ 1.05x）
@export_range(0.0, 0.3, 0.01) var sfx_pitch_randomness: float = 0.05
## 効果音多重再生プールのサイズ
@export_range(4, 32, 1) var sfx_pool_size: int = 16
## 同一効果音の連続再生最小間隔（ミリ秒連打防止）
@export_range(0.0, 0.2, 0.005) var default_min_sfx_interval: float = 0.03

# ----------------------------------------------------------------------
# ▶️ エディタ内テスト試聴 (Inspector Test Preview)
# ----------------------------------------------------------------------
@export_group("▶️ インスペクター試聴テスト")
## 試聴したいSFX名を選択または入力して下のトリガーをONにしてください
## (hit, guard, parry, heavy_hit, explosion, laser, shoot, damage, warning, item, upgrade, ui_click)
@export var test_sfx_name: String = "parry"
## チェックを入れると設定したSFXをテスト再生します（自動でOFFに戻ります）
@export var trigger_play_test_sfx: bool = false:
	set(v):
		if v:
			_preview_sfx(test_sfx_name)
		trigger_play_test_sfx = false

## 試聴したいBGM名を選択または入力 (main_menu, stage_select, stage1, stage2, boss, final_boss 等)
@export var test_bgm_name: String = "main_menu"
## チェックを入れると設定したBGMをテスト再生します（自動でOFFに戻ります）
@export var trigger_play_test_bgm: bool = false:
	set(v):
		if v:
			_preview_bgm(test_bgm_name)
		trigger_play_test_bgm = false
## チェックを入れるとBGMを停止します
@export var trigger_stop_test_bgm: bool = false:
	set(v):
		if v:
			stop_bgm(0.3)
		trigger_stop_test_bgm = false


# ----------------------------------------------------------------------
# 内部管理変数
# ----------------------------------------------------------------------
var _bgm_player_a: AudioStreamPlayer
var _bgm_player_b: AudioStreamPlayer
var _current_bgm_player: AudioStreamPlayer
var _current_bgm_name: String = ""
var _bgm_fade_tween: Tween

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0
var _sfx_last_play_times: Dictionary = {}

var _ui_player: AudioStreamPlayer

# プロシージャル合成音キャッシュ
var _procedural_cache: Dictionary = {}


func _ready() -> void:
	# プロセスモードを常時実行に設定（ゲーム停止中・ポーズ中もUI音やBGMを鳴らせるように）
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_nodes()
	_generate_procedural_sounds()


## 内部プレイヤーノードの初期化
func _setup_audio_nodes() -> void:
	# 既存の子プレイヤーがいれば再利用またはクリーンアップ
	for child in get_children():
		if child is AudioStreamPlayer:
			child.queue_free()
	_sfx_pool.clear()
	
	# BGMプレイヤー A & B (クロスフェード用)
	_bgm_player_a = AudioStreamPlayer.new()
	_bgm_player_a.name = "BGM_Player_A"
	_bgm_player_a.bus = "BGM"
	_bgm_player_a.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bgm_player_a)
	
	_bgm_player_b = AudioStreamPlayer.new()
	_bgm_player_b.name = "BGM_Player_B"
	_bgm_player_b.bus = "BGM"
	_bgm_player_b.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bgm_player_b)
	
	_current_bgm_player = _bgm_player_a
	
	# UIプレイヤー
	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UI_Player"
	_ui_player.bus = "UI"
	_ui_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_player)
	
	# SFX 多重再生プール
	for i in range(sfx_pool_size):
		var asp = AudioStreamPlayer.new()
		asp.name = "SFX_Player_%d" % i
		asp.bus = "SFX"
		asp.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(asp)
		_sfx_pool.append(asp)


# ====================================================================
# 🎵 BGM 再生制御 API
# ====================================================================

## BGMを再生する (名前またはAudioStreamインスタンスを指定可能)
## bgm_name 例: "main_menu", "stage_select", "stage1", "stage2", "boss", "final_boss", "game_over", "victory"
func play_bgm(bgm_key_or_stream: Variant, fade_time: float = -1.0) -> void:
	if fade_time < 0.0:
		fade_time = bgm_fade_duration
		
	var stream: AudioStream = null
	var key_str: String = ""
	
	if bgm_key_or_stream is AudioStream:
		stream = bgm_key_or_stream
		key_str = "custom_stream"
	elif bgm_key_or_stream is String:
		key_str = bgm_key_or_stream
		stream = get_bgm_stream(key_str)
	
	if stream == null:
		return
		
	# 既に同じBGMが再生中の場合は何もしない
	if _current_bgm_name == key_str and _current_bgm_player and _current_bgm_player.playing and _current_bgm_player.stream == stream:
		return
		
	_current_bgm_name = key_str
	
	# クロスフェードの切り替え準備
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


## BGMをフェードアウトして停止する
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


## 指定キーに対応するAudioStreamを取得
func get_bgm_stream(key: String) -> AudioStream:
	match key.to_lower():
		"main_menu", "menu", "title":
			return bgm_main_menu
		"stage_select", "stage_selection", "tech_lab", "select", "lab":
			return bgm_stage_select
		"stage1", "stage_1", "stage_01":
			return bgm_stage1
		"stage2", "stage_2", "stage_02":
			return bgm_stage2
		"stage3", "stage_3", "stage_03":
			return bgm_stage3
		"stage4", "stage_4", "stage_04":
			return bgm_stage4
		"stage5", "stage_5", "stage_05":
			return bgm_stage5
		"boss", "stage1_boss", "stage2_boss", "stage3_boss", "stage4_boss":
			return bgm_boss if bgm_boss != null else bgm_stage1
		"final_boss", "stage5_boss":
			return bgm_final_boss if bgm_final_boss != null else bgm_boss
		"game_over", "gameover":
			return bgm_game_over
		"victory", "clear", "stage_clear":
			return bgm_victory
		_:
			if custom_bgm.has(key):
				return custom_bgm[key]
	return null


# ====================================================================
# 🔊 SFX / UI 効果音 再生制御 API
# ====================================================================

## 効果音を再生する (名前またはAudioStreamインスタンスを指定可能)
func play_sfx(sfx_key_or_stream: Variant, pitch_scale: float = 1.0, min_interval: float = -1.0, volume_offset_db: float = 0.0) -> void:
	if min_interval < 0.0:
		min_interval = default_min_sfx_interval
		
	var stream: AudioStream = null
	var key_str: String = ""
	
	if sfx_key_or_stream is AudioStream:
		stream = sfx_key_or_stream
		key_str = "custom_stream_%d" % sfx_key_or_stream.get_instance_id()
	elif sfx_key_or_stream is String:
		key_str = sfx_key_or_stream
		stream = get_sfx_stream(key_str)
		
	# 未登録の場合はプロシージャル波形をフォールバックとして取得
	if stream == null and key_str != "":
		stream = _get_fallback_procedural_sound(key_str)
		
	if stream == null:
		return
		
	# 連続再生間隔チェック
	var now = Time.get_ticks_msec() / 1000.0
	if _sfx_last_play_times.has(key_str):
		if now - _sfx_last_play_times[key_str] < min_interval:
			return
	_sfx_last_play_times[key_str] = now
	
	if _sfx_pool.is_empty():
		_setup_audio_nodes()
		if _sfx_pool.is_empty():
			return
			
	var asp = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % _sfx_pool.size()
	
	asp.stream = stream
	var random_factor = 1.0 + randf_range(-sfx_pitch_randomness, sfx_pitch_randomness)
	asp.pitch_scale = pitch_scale * random_factor
	asp.volume_db = volume_offset_db
	asp.play()


## UI効果音を再生する (UI Bus経由)
func play_ui(sfx_key_or_stream: Variant, pitch_scale: float = 1.0) -> void:
	var stream: AudioStream = null
	if sfx_key_or_stream is AudioStream:
		stream = sfx_key_or_stream
	elif sfx_key_or_stream is String:
		stream = get_sfx_stream(sfx_key_or_stream)
		if stream == null:
			stream = _get_fallback_procedural_sound(sfx_key_or_stream)
			
	if stream == null:
		return
		
	if not is_instance_valid(_ui_player):
		_setup_audio_nodes()
		
	_ui_player.stream = stream
	_ui_player.pitch_scale = pitch_scale
	_ui_player.volume_db = 0.0
	_ui_player.play()


## 指定キーに対応するAudioStreamを取得
func get_sfx_stream(key: String) -> AudioStream:
	match key.to_lower():
		"hit":
			return sfx_hit
		"guard":
			return sfx_guard
		"parry":
			return sfx_parry
		"heavy_hit":
			return sfx_heavy_hit
		"explosion", "turret_destroy":
			return sfx_explosion
		"laser":
			return sfx_laser
		"shoot", "player_shoot":
			return sfx_player_shoot
		"damage", "player_damage":
			return sfx_player_damage
		"death", "player_death":
			return sfx_player_death
		"warning", "boss_warning":
			return sfx_boss_warning
		"item", "item_collect", "orb":
			return sfx_item_collect
		"upgrade", "upgrade_success":
			return sfx_upgrade_success
		"ui_click", "click", "btn_click":
			return sfx_ui_click
		"ui_hover", "hover":
			return sfx_ui_hover
		"ui_cancel", "cancel", "back":
			return sfx_ui_cancel
		_:
			if custom_sfx.has(key):
				return custom_sfx[key]
	return null


# ====================================================================
# 🎯 ショートカット呼び出し API (ゲーム内スクリプトから簡単に呼べる関数群)
# ====================================================================

func play_hit(pitch: float = 1.0) -> void:
	play_sfx("hit", pitch, 0.035)

func play_guard(pitch: float = 1.0) -> void:
	play_sfx("guard", pitch, 0.04)

func play_parry(pitch: float = 1.0) -> void:
	play_sfx("parry", pitch, 0.03)

func play_heavy_hit(pitch: float = 1.0) -> void:
	play_sfx("heavy_hit", pitch, 0.04)

func play_explosion(pitch: float = 1.0) -> void:
	play_sfx("explosion", pitch, 0.08)

func play_laser(pitch: float = 1.0) -> void:
	play_sfx("laser", pitch, 0.04)

func play_player_shoot(pitch: float = 1.0) -> void:
	play_sfx("shoot", pitch, 0.06)

func play_player_damage(pitch: float = 1.0) -> void:
	play_sfx("damage", pitch, 0.1)

func play_boss_warning() -> void:
	play_sfx("warning", 1.0, 0.5)

func play_item_collect() -> void:
	play_sfx("item", 1.0, 0.04)

func play_upgrade_success() -> void:
	play_sfx("upgrade", 1.0, 0.1)

func play_ui_click() -> void:
	play_ui("ui_click", 1.0)

func play_ui_hover() -> void:
	play_ui("ui_hover", 1.0)

func play_ui_cancel() -> void:
	play_ui("ui_cancel", 1.0)


# ====================================================================
# 🎛️ ボリューム調整・AudioBus 制御
# ====================================================================

func set_master_volume(val: float) -> void:
	_set_bus_volume("Master", val)

func set_bgm_volume(val: float) -> void:
	_set_bus_volume("BGM", val)

func set_sfx_volume(val: float) -> void:
	_set_bus_volume("SFX", val)

func set_ui_volume(val: float) -> void:
	_set_bus_volume("UI", val)

func _set_bus_volume(bus_name: String, val: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var db = -60.0 if val <= 0.0 else linear_to_db(val / 100.0)
		AudioServer.set_bus_volume_db(idx, db)


# ====================================================================
# 🛠️ エディタ用プレビュー・テスト実行
# ====================================================================

func _preview_sfx(key: String) -> void:
	if _sfx_pool.is_empty():
		_setup_audio_nodes()
	if _procedural_cache.is_empty():
		_generate_procedural_sounds()
	play_sfx(key)

func _preview_bgm(key: String) -> void:
	if not is_instance_valid(_bgm_player_a):
		_setup_audio_nodes()
	play_bgm(key, 0.2)


# ====================================================================
# 🔊 プロシージャル合成音 (フォールバック生成システム - 44.1kHz PCM)
# ====================================================================

func _generate_procedural_sounds() -> void:
	_procedural_cache["hit"] = _create_hit_sound(0.045, 950.0, 0.4, 0.5)
	_procedural_cache["guard"] = _create_guard_sound(0.06, 1800.0)
	_procedural_cache["parry"] = _create_parry_sound(0.18)
	_procedural_cache["heavy_hit"] = _create_heavy_hit_sound(0.08, 420.0)
	_procedural_cache["explosion"] = _create_explosion_sound(0.25)
	_procedural_cache["turret_destroy"] = _create_explosion_sound(0.18)
	_procedural_cache["laser"] = _create_laser_sound(0.12)
	_procedural_cache["shoot"] = _create_laser_sound(0.08)
	_procedural_cache["damage"] = _create_heavy_hit_sound(0.14, 300.0)
	_procedural_cache["death"] = _create_explosion_sound(0.4)
	_procedural_cache["warning"] = _create_warning_sound(0.25)
	_procedural_cache["item"] = _create_item_sound(0.1)
	_procedural_cache["upgrade"] = _create_upgrade_sound(0.28)
	_procedural_cache["ui_click"] = _create_click_sound(0.03, 1200.0)
	_procedural_cache["ui_hover"] = _create_click_sound(0.02, 1600.0)
	_procedural_cache["ui_cancel"] = _create_click_sound(0.04, 600.0)

func _get_fallback_procedural_sound(key: String) -> AudioStream:
	if _procedural_cache.is_empty():
		_generate_procedural_sounds()
	return _procedural_cache.get(key.to_lower(), null)

func _create_parry_sound(duration: float = 0.18) -> AudioStreamWAV:
	var sample_rate = 44100
	var sample_count = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 13.0)
		var f1 = sin(TAU * 2800.0 * t) * 0.45
		var f2 = sin(TAU * 4200.0 * t) * 0.30
		var f3 = sin(TAU * 5600.0 * t) * 0.20
		var f4 = sin(TAU * 8400.0 * t) * 0.12
		var ping = (f1 + f2 + f3 + f4)
		var click = (randf() * 2.0 - 1.0) * exp(-progress * 90.0) * 0.9
		var sample = (ping * 0.82 + click * 0.38) * env
		data[i] = int(clamp((sample + 1.0) * 127.5, 0, 255))
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
		data[i] = int(clamp((sample * 0.85 + 1.0) * 127.5, 0, 255))
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
		data[i] = int(clamp((sample + 1.0) * 127.5, 0, 255))
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
		data[i] = int(clamp((sample + 1.0) * 127.5, 0, 255))
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
		data[i] = int(clamp((sample + 1.0) * 127.5, 0, 255))
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
		data[i] = int(clamp((sample + 1.0) * 127.5, 0, 255))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _create_click_sound(duration: float = 0.03, freq: float = 1200.0) -> AudioStreamWAV:
	var sample_rate = 44100
	var sample_count = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 25.0)
		var tone = sin(TAU * freq * t)
		var sample = tone * env * 0.7
		data[i] = int(clamp((sample + 1.0) * 127.5, 0, 255))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _create_item_sound(duration: float = 0.1) -> AudioStreamWAV:
	var sample_rate = 44100
	var sample_count = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 12.0)
		var freq = 880.0 + progress * 880.0
		var tone = sin(TAU * freq * t)
		var sample = tone * env * 0.75
		data[i] = int(clamp((sample + 1.0) * 127.5, 0, 255))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _create_upgrade_sound(duration: float = 0.28) -> AudioStreamWAV:
	var sample_rate = 44100
	var sample_count = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 7.0)
		var note_idx = int(progress * 3.0)
		var base_f = 523.25 # C5
		if note_idx == 1: base_f = 659.25 # E5
		elif note_idx == 2: base_f = 783.99 # G5
		var tone = sin(TAU * base_f * t)
		var sample = tone * env * 0.8
		data[i] = int(clamp((sample + 1.0) * 127.5, 0, 255))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _create_warning_sound(duration: float = 0.25) -> AudioStreamWAV:
	var sample_rate = 44100
	var sample_count = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 6.0)
		var freq = 600.0 if int(t * 16.0) % 2 == 0 else 900.0
		var tone = sin(TAU * freq * t)
		var sample = tone * env * 0.85
		data[i] = int(clamp((sample + 1.0) * 127.5, 0, 255))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _exit_tree() -> void:
	if is_instance_valid(_bgm_player_a): _bgm_player_a.stop()
	if is_instance_valid(_bgm_player_b): _bgm_player_b.stop()
	if is_instance_valid(_ui_player): _ui_player.stop()
	for asp in _sfx_pool:
		if is_instance_valid(asp):
			asp.stop()
