extends Node2D
## 敵弾プール管理
## - 敵弾の再利用で GC 圧力を軽減
## - 画面内の最大アクティブ弾数を制限し、上限到達時に最古弾を自然消滅・リサイクル

@export var initial_pool_size: int = 120
@export var max_active_bullets: int = 150 # 同時存在アクティブ敵弾の上限

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
	"""プールから弾を取得（上限超過時は最古弾を自然消滅させて再利用）"""
	# アクティブ弾数が上限に達している場合、最も古い弾を自然消滅させて回収
	while active_bullets.size() >= max_active_bullets and active_bullets.size() > 0:
		var oldest = active_bullets[0]
		if is_instance_valid(oldest):
			if oldest.has_method("dissolve_and_recycle"):
				oldest.dissolve_and_recycle(true) # 強制自然消滅
			else:
				return_bullet(oldest)
		else:
			active_bullets.remove_at(0)
			
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
	bullet.modulate = Color.WHITE
	
	if "lifetime" in bullet:
		bullet.lifetime = 0.0
	if "is_dissolving" in bullet:
		bullet.is_dissolving = false
		
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
	if "lifetime" in bullet:
		bullet.lifetime = 0.0
	if "is_dissolving" in bullet:
		bullet.is_dissolving = false
	
	# プール内に重複して入るのを防ぐ
	if not bullet_pool.has(bullet):
		bullet_pool.append(bullet)

