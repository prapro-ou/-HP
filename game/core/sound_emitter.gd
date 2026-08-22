@tool
extends Node2D
class_name SoundEmitter

## ====================================================================
## SoundEmitter (汎用効果音エミッター / 手動設定コンポーネント)
## ====================================================================
## 【概要】
## 敵、弾丸、ボスパーツ、演出オブジェクト等の任意のノードに子ノードとして配置し、
## インスペクターから手動で音源（AudioStream）や再生挙動を設定できるコンポーネントです。
##
## 【使い方】
## 1. 鳴らしたいノード（敵や弾など）の子として「SoundEmitter」ノードを追加。
## 2. インスペクターの「Sound Stream」に好きな音声ファイルをドラッグ＆ドロップ。
## 3. 「Play On Ready」や「Play On Tree Exiting」にチェックを入れるだけで
##    コードを書かずに生成時・消滅時に自動再生できます。
## 4. スクリプトから鳴らす場合は `$SoundEmitter.play_sound()` を呼ぶだけです。
## ====================================================================

# ----------------------------------------------------------------------
# 🎵 音源・トリガー設定
# ----------------------------------------------------------------------
@export_group("🎵 音源・トリガー設定")
## 再生する音声ファイル（.wav, .ogg, .mp3等）
@export var sound_stream: AudioStream
## 音声ファイルが未設定の場合、AudioManagerのこのキー名のフォールバック音を再生
@export var fallback_sfx_name: String = ""
## ノード生成（_ready）時に自動再生するかどうか
@export var play_on_ready: bool = false
## ノード削除（消滅・撃破時）に自動再生するかどうか
@export var play_on_tree_exiting: bool = false
## 2D空間音響（距離減衰・パンニング）を有効にするか（true: AudioStreamPlayer2D, false: AudioStreamPlayer）
@export var use_spatial_2d: bool = false

# ----------------------------------------------------------------------
# 🎛️ 音量・ピッチ設定
# ----------------------------------------------------------------------
@export_group("🎛️ 音響パラメータ")
## 出力オーディオバス ("SFX", "UI", "BGM", "Master")
@export var bus: String = "SFX"
## 音量オフセット (dB)
@export_range(-40.0, 20.0, 0.5) var volume_db: float = 0.0
## 基本ピッチ倍率
@export_range(0.1, 4.0, 0.05) var pitch_scale: float = 1.0
## ピッチのランダム揺らぎ幅（例: 0.05 で 0.95x ~ 1.05x）
@export_range(0.0, 0.5, 0.01) var pitch_randomness: float = 0.05
## 2D空間音響時の最大可聴距離（ピクセル）
@export var max_distance: float = 2000.0

# ----------------------------------------------------------------------
# ▶️ エディタ内テスト試聴
# ----------------------------------------------------------------------
@export_group("▶️ インスペクター試聴テスト")
## チェックを入れると設定した音をテスト再生します
@export var trigger_test_play: bool = false:
	set(v):
		if v:
			play_sound()
		trigger_test_play = false


var _player_2d: AudioStreamPlayer2D
var _player_global: AudioStreamPlayer


func _ready() -> void:
	_setup_player()
	
	if not Engine.is_editor_hint():
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


## 音声を再生する
func play_sound(custom_pitch: float = 1.0) -> void:
	var stream_to_play: AudioStream = sound_stream
	
	# 音源が直接指定されていない場合、AudioManagerのフォールバックを使用
	if stream_to_play == null and fallback_sfx_name != "":
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("get_sfx_stream"):
			stream_to_play = audio_mgr.get_sfx_stream(fallback_sfx_name)
		if stream_to_play == null and audio_mgr and audio_mgr.has_method("_get_fallback_procedural_sound"):
			stream_to_play = audio_mgr._get_fallback_procedural_sound(fallback_sfx_name)
			
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


## ノード破棄時の自動再生トリガー
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_UNPARENTED:
		if play_on_tree_exiting and not Engine.is_editor_hint():
			# 自身が破棄される場合はAudioManagerのプール経由で音だけ残して鳴らす
			var audio_mgr = get_node_or_null("/root/AudioManager")
			if audio_mgr and audio_mgr.has_method("play_sfx"):
				if sound_stream:
					audio_mgr.play_sfx(sound_stream, pitch_scale, 0.0, volume_db)
				elif fallback_sfx_name != "":
					audio_mgr.play_sfx(fallback_sfx_name, pitch_scale, 0.0, volume_db)
