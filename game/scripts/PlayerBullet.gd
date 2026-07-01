extends Area2D
## プレイヤー弾スクリプト
## - 前方移動
## - 画面外判定で削除
## - 敵（BossDamageShape）との衝突検知

@export var speed: float = 800.0
@export var damage: int = 10

var velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	velocity = Vector2.UP * speed  # 上方向に移動
	# エリア侵入時のシグナルを接続
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	position += velocity * delta
	
	# 画面外チェック (画面上部)
	if position.y < -50:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	"""他のArea2Dに入った時の処理"""
	if area.name == "BossDamageShape" or area.is_in_group("boss"):
		# ボス（あるいは衝突エリア）が take_damage を持っている場合
		if area.has_method("take_damage"):
			area.take_damage(damage)
		elif area.get_parent().has_method("take_damage"):
			area.get_parent().take_damage(damage)
		
		# 弾を消滅させる
		queue_free()
