extends Area2D
## ボスの特定部位（Core, LaserCannon, MissilePod）のダメージ中継スクリプト

@export var part_name: String = "core"  # "core", "laser", "missile"


func take_damage(amount: int, hit_pos: Vector2 = Vector2.ZERO) -> void:
	if get_parent() and get_parent().has_method("take_damage_on_part"):
		get_parent().take_damage_on_part(part_name, amount, hit_pos)
