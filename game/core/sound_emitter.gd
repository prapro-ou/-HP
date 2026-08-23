extends Node2D
class_name SoundEmitter

@export var sound_stream: AudioStream
@export var fallback_sfx_name: String = ""
@export var play_on_ready: bool = false
@export var play_on_tree_exiting: bool = false
@export var use_spatial_2d: bool = false
@export var bus: String = "SFX"
@export var volume_db: float = 0.0
@export var pitch_scale: float = 1.0
@export var pitch_randomness: float = 0.05
@export var max_distance: float = 2000.0

var _player_2d: AudioStreamPlayer2D
var _player_global: AudioStreamPlayer

func _ready() -> void:
	_setup_player()
	if play_on_ready:
		play_sound()

func _setup_player() -> void:
	if use_spatial_2d:
		if not is_instance_valid(_player_2d):
			_player_2d = AudioStreamPlayer2D.new()
			_player_2d.name = "SpatialPlayer"
			_player_2d.bus = bus
			_player_2d.max_distance = max_distance
			add_child(_player_2d)
	else:
		if not is_instance_valid(_player_global):
			_player_global = AudioStreamPlayer.new()
			_player_global.name = "GlobalPlayer"
			_player_global.bus = bus
			add_child(_player_global)

func play_sound(custom_pitch: float = 1.0) -> void:
	var stream_to_play: AudioStream = sound_stream
	if stream_to_play == null and fallback_sfx_name != "":
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("get_sfx_stream"):
			stream_to_play = audio_mgr.get_sfx_stream(fallback_sfx_name)
	if stream_to_play == null:
		return

	var final_pitch = pitch_scale * custom_pitch * (1.0 + randf_range(-pitch_randomness, pitch_randomness))
	if use_spatial_2d:
		if not is_instance_valid(_player_2d):
			_setup_player()
		_player_2d.stream = stream_to_play
		_player_2d.volume_db = volume_db
		_player_2d.pitch_scale = final_pitch
		_player_2d.play()
	else:
		if not is_instance_valid(_player_global):
			_setup_player()
		_player_global.stream = stream_to_play
		_player_global.volume_db = volume_db
		_player_global.pitch_scale = final_pitch
		_player_global.play()

func _notification(what: int) -> void:
	if (what == NOTIFICATION_PREDELETE or what == NOTIFICATION_UNPARENTED) and play_on_tree_exiting:
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			if sound_stream:
				audio_mgr.play_sfx(sound_stream, pitch_scale, 0.0, volume_db)
			elif fallback_sfx_name != "":
				audio_mgr.play_sfx(fallback_sfx_name, pitch_scale, 0.0, volume_db)
