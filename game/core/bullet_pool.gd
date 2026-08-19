extends Node2D
## 敵弾プール管理
## - 敵弾の再利用で GC 圧力を軽減

@export var initial_pool_size: int = 100

var bullet_pool: Array = []
var active_bullets: Array = []  # 現在画面上に存在するアクティブな弾のリスト
var bullet_scene: PackedScene = preload("res://game/bullets/enemy_bullet.tscn")


func _ready() -> void:
	# 初期プール生成
	for i in range(initial_pool_size):
		var bullet = bullet_scene.instantiate()
		bullet.hide()
		add_child(bullet)
		bullet_pool.append(bullet)


func get_bullet(type: String = "beam") -> Node2D:
	"""プールから弾を取得"""
	var bullet: Node2D
	if bullet_pool.size() > 0:
		bullet = bullet_pool.pop_front()
	else:
		# プール枯渇時は新規生成
		bullet = bullet_scene.instantiate()
		add_child(bullet)
	
	# 初期状態リセット
	bullet.position = Vector2.ZERO
	bullet.velocity = Vector2.ZERO
	bullet.is_friendly = false
	bullet.is_unparryable = type.contains("unparryable")
	bullet.bullet_type = type
	if bullet.has_method("update_bullet_color"):
		bullet.update_bullet_color()
	bullet.show()
	
	if not active_bullets.has(bullet):
		active_bullets.append(bullet)
	
	return bullet


func return_bullet(bullet: Node2D) -> void:
	"""使用済み弾をプールに戻す"""
	if not is_instance_valid(bullet) or bullet.is_queued_for_deletion():
		return
		
	if active_bullets.has(bullet):
		active_bullets.erase(bullet)
	
	bullet.hide()
	bullet.position = Vector2.ZERO
	bullet.velocity = Vector2.ZERO
	bullet.is_friendly = false
	bullet.is_unparryable = false
	bullet.modulate = Color.WHITE
	
	# プール内に重複して入るのを防ぐ
	if not bullet_pool.has(bullet):
		bullet_pool.append(bullet)
