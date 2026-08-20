extends Node
## プロシージャル効果音生成・再生マネージャー (SoundManager)
## - 外部音声ファイル不要でGodot 4標準のAudioStreamWAVを動的生成
## - 連射時の音割れ・発音飽和を防ぐ同時発音制御
## - 敵被弾、シールド弾き、コア直撃、爆発などのSEを提供

static var instance: Node

var sounds: Dictionary = {}
var player_pool: Array[AudioStreamPlayer] = []
var pool_size: int = 12
var pool_index: int = 0
var last_play_times: Dictionary = {}

func _init() -> void:
	instance = self


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	instance = self
	
	# サウンドプールの作成
	for i in range(pool_size):
		var asp = AudioStreamPlayer.new()
		asp.bus = "SFX"
		add_child(asp)
		player_pool.append(asp)
		
	# プロシージャルサウンドの生成・キャッシュ
	sounds["hit"] = _create_hit_sound(0.045, 950.0, 0.4, 0.5)
	sounds["guard"] = _create_guard_sound(0.06, 1800.0)
	sounds["heavy_hit"] = _create_heavy_hit_sound(0.08, 420.0)
	sounds["explosion"] = _create_explosion_sound(0.25)
	sounds["turret_destroy"] = _create_explosion_sound(0.18)


static func get_instance() -> Node:
	if instance and is_instance_valid(instance):
		return instance
	var root = Engine.get_main_loop() as SceneTree
	if root and root.root:
		var found = root.root.get_node_or_null("SoundManager")
		if found:
			instance = found
			return instance
		var new_mgr = load("res://game/core/sound_manager.gd").new()
		new_mgr.name = "SoundManager"
		root.root.call_deferred("add_child", new_mgr)
		instance = new_mgr
		return instance
	return null


func play_sound(sound_name: String, pitch_scale: float = 1.0, min_interval: float = 0.03) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	if last_play_times.has(sound_name):
		if now - last_play_times[sound_name] < min_interval:
			return
	last_play_times[sound_name] = now
	
	if not sounds.has(sound_name):
		return
		
	if player_pool.is_empty():
		return
		
	var asp = player_pool[pool_index]
	pool_index = (pool_index + 1) % player_pool.size()
	
	asp.stream = sounds[sound_name]
	asp.pitch_scale = pitch_scale * randf_range(0.95, 1.05)
	asp.play()


static func play_hit(pitch: float = 1.0) -> void:
	var mgr = get_instance()
	if mgr:
		mgr.play_sound("hit", pitch, 0.035)


static func play_guard(pitch: float = 1.0) -> void:
	var mgr = get_instance()
	if mgr:
		mgr.play_sound("guard", pitch, 0.04)


static func play_heavy_hit(pitch: float = 1.0) -> void:
	var mgr = get_instance()
	if mgr:
		mgr.play_sound("heavy_hit", pitch, 0.04)


static func play_explosion(pitch: float = 1.0) -> void:
	var mgr = get_instance()
	if mgr:
		mgr.play_sound("explosion", pitch, 0.08)


# --- プロシージャル波形生成ヘルパー ---

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
		# 2つの高周波による金属的なリングモジュレーション
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
