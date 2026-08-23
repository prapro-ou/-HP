extends Node2D
class_name BaseStage

## ステージ設定・ウェーブ構成・ボスパラメーターを管理するベースクラス
## 新ステージ追加時は本クラスを継承して波構成やボス設定を記述することで、高い拡張性と保守性を実現します。

class WaveSpawnConfig:
	var drone_type: String
	var pos_ratio_x: float
	var pos_y: float
	
	func _init(p_type: String, p_ratio_x: float, p_y: float = -50.0) -> void:
		drone_type = p_type
		pos_ratio_x = p_ratio_x
		pos_y = p_y

class WaveData:
	var wave_id: String
	var display_title: String
	var start_message: String
	var initial_spawns: Array = []
	var replenish_types: Array = []
	var min_active_drones: int = 2
	var drone_speed_override: float = 0.0
	var drone_shoot_interval_beam: float = 0.0
	var drone_shoot_interval_missile: float = 0.0

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
