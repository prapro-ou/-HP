extends Node2D
@export var initial_pool_size: int = 120
@export var max_active_bullets: int = 150
var bullet_pool: Array = []
var active_bullets: Array = []
var bullet_scene: PackedScene = preload("res://game/bullets/enemy_bullet.tscn")

func _ready() -> void:
	for index in range(initial_pool_size):
		var bullet = bullet_scene.instantiate()
		add_child(bullet)
		bullet.set_active(false)
		bullet_pool.append(bullet)

func get_bullet(type: String = "beam") -> Node2D:
	while active_bullets.size() >= max_active_bullets:
		return_bullet(active_bullets[0])
	var bullet: Node2D
	if not bullet_pool.is_empty():
		bullet = bullet_pool.pop_back()
	else:
		bullet = bullet_scene.instantiate()
		add_child(bullet)
	bullet.reset_for_spawn(type)
	active_bullets.append(bullet)
	bullet.set_active(true)
	return bullet

func return_bullet(bullet: Node2D) -> void:
	if not is_instance_valid(bullet) or bullet.is_queued_for_deletion():
		active_bullets.erase(bullet)
		return
	active_bullets.erase(bullet)
	bullet.set_active(false)
	if not bullet_pool.has(bullet):
		bullet_pool.append(bullet)
