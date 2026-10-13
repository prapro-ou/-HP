extends Node2D
class_name BaseStage

## ステージ設定・ウェーブ構成・ボスパラメーターを管理するベースクラス
## 新ステージ追加時は本クラスを継承して波構成やボス設定を記述することで、高い拡張性と保守性を実現します。

class WaveSpawnConfig:
	var drone_type: String
	var pos_ratio_x: float
	var pos_y: float
	var is_slow: Variant = null
	var spawn_delay: float = 0.0
	var lane_y: float = -1.0
	var lane_sway: float = 0.0
	var entry_speed: float = 180.0
	
	func _init(p_type: String, p_ratio_x: float, p_y: float = -50.0, p_is_slow: Variant = null) -> void:
		drone_type = p_type
		pos_ratio_x = p_ratio_x
		pos_y = p_y
		is_slow = p_is_slow

class WaveData:
	var wave_id: String
	var display_title: String
	var start_message: String
	var initial_spawns: Array = []
	var transition_delay: float = 0.65

class InterludeData:
	var title: String = "警告"
	var subtitle: String = "強大な敵反応を検知！"
	var flash_color: Color = Color(1.0, 0.0, 0.0, 0.4)
	var secondary_flash_color: Color = Color.TRANSPARENT
	var assist_message: String = ""
	var duration: float = 4.0

class BossConfig:
	var name: String = "古代防衛兵器"
	var max_hp: int = 2400
	var laser_hp: int = 500
	var missile_hp: int = 500
	var core_hp: int = 1400
	var base_move_speed: float = 140.0
	var energy_laser: float = 30.0
	var energy_missile: float = 30.0
	var energy_core: float = 40.0
	var enable_support_drones: bool = false
	var support_drone_interval: float = 20.0

class RewardConfig:
	var counter_weapon_unlock: String = ""
	var tech_points: int = 30
	var unlocked_stage: int = 0
	var unlock_message: String = ""


@export var stage_name: String = "STAGE"
@export var stage_number: int = 1
@export var background_texture: Texture2D
@export var boss_background_texture: Texture2D

var waves: Array[WaveData] = []
var interlude: InterludeData = InterludeData.new()
var boss_config: BossConfig = BossConfig.new()
var reward_config: RewardConfig = RewardConfig.new()

func _ready() -> void:
	_ready_stage()

## 子ステージでオーバーライドして各ステージのデータを構築します
func _ready_stage() -> void:
	pass

func get_wave(index: int) -> WaveData:
	if index >= 0 and index < waves.size():
		return waves[index]
	return null

## Campaign-only entry and bounded movement data. Default drone AI is unchanged.
func lane_spawn(kind: String, x: float, y: float, delay: float, sway: float, entry_speed: float = 180.0) -> WaveSpawnConfig:
	var config := WaveSpawnConfig.new(kind, x, -60.0, false)
	config.spawn_delay = delay
	config.lane_y = y
	config.lane_sway = sway
	config.entry_speed = entry_speed
	return config

func encounter_wave(id: String, title: String, message: String) -> WaveData:
	var wave := WaveData.new()
	wave.wave_id = id
	wave.display_title = title
	wave.start_message = message
	return wave

func patrol_wave(kinds: Array, id: String = "patrol") -> WaveData:
	var wave := encounter_wave(id, "移動哨戒", "横移動で射線を合わせる。敵弾は捕まえて追撃。")
	for i in kinds.size():
		wave.initial_spawns.append(lane_spawn(kinds[i], 0.30 if i % 2 == 0 else 0.70, 320.0 + (i % 2) * 40.0, i * 2.4, 48.0))
	return wave

func column_wave(kinds: Array) -> WaveData:
	var wave := encounter_wave("column", "縦列部隊", "縦に射線を通す。貫通弾で後方の敵も狙える。")
	for i in kinds.size():
		wave.initial_spawns.append(lane_spawn(kinds[i], 0.50, 470.0 - i * 80.0, i * 0.25, 6.0, 210.0))
	return wave

func spread_cluster_wave(spread: Array, cluster: Array) -> WaveData:
	var wave := encounter_wave("spread_cluster", "分散・密集部隊", "広角射撃で横を制圧。密集には爆風と熱場。")
	for i in spread.size():
		wave.initial_spawns.append(lane_spawn(spread[i], 0.34 + i * 0.16, 330.0, i * 0.15, 5.0))
	for i in cluster.size():
		wave.initial_spawns.append(lane_spawn(cluster[i], 0.47 + i * 0.03, 370.0 - i * 18.0, 3.2 + i * 0.12, 6.0, 130.0))
	return wave
