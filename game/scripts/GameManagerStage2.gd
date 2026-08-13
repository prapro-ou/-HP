extends "res://game/core/game_manager.gd"
## GameManagerStage2 - 旧仕様互換用プロキシクラス
## 全ての進行管理は統一された GameManager (game/core/game_manager.gd) および
## データ駆動型 BaseStage (Stage1 / Stage2) にて統一制御されます。

func _ready() -> void:
	super._ready()
