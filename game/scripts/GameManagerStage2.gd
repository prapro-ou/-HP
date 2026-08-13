<<<<<<< HEAD
extends "res://game/core/game_manager.gd"
## GameManagerStage2 - 旧仕様互換用プロキシクラス
## 全ての進行管理は統一された GameManager (game/core/game_manager.gd) および
## データ駆動型 BaseStage (Stage1 / Stage2) にて統一制御されます。
=======
extends Node2D
## ゲーム進行管理（ステージ2構成）
## - Wave1: Dual Extraction（BeamとMissileの混成部隊、両方3回パリィでアンロック）
## - Wave2: Swarm Phase（高速化したドローン軍団を8機撃破する）
## - 中継演出: 警告メッセージ表示（紫と赤の強力な警告）
## - ボス戦: 古代防衛兵器・強化版（HP大幅増、速度アップ、随時ドローンが支援出現）

var player: CharacterBody2D
var boss: Node2D
var ui: Control
var bullet_pool: Node2D

# ステート: "start", "wave1_dual", "wave2_transition", "wave2_swarm", "interlude", "boss", "victory", "defeat"
var state: String = "start"

var parry_count: int = 0
var total_damage_score: int = 0
var drone_scene = preload("res://game/enemies/drone/enemy_drone.tscn")
var spawned_drones: Array = []
var state_timer: float = 0.0
var swarm_destroyed_count: int = 0
const SWARM_TARGET: int = 8
>>>>>>> 3bfac906a74f64b50e1c657a3e2f344081dd98c5

func _ready() -> void:
	super._ready()
