extends Node2D
class_name BaseStage

## ステージのベースクラス
## - 各ステージの基本設定（ステージ名、ステージ番号）を保持
## - モニター毎の比率調整や背景の処理など、将来的な共通ギミックをここに配置可能

@export var stage_name: String = "STAGE"
@export var stage_number: int = 1

func _ready() -> void:
	_ready_stage()

## 子ステージでの初期化用仮想メソッド
func _ready_stage() -> void:
	pass
