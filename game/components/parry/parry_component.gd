extends Node
class_name ParryComponent

signal parry_succeeded(bullet_type: String, hit_position: Vector2, streak: int)


func report_success(bullet_type: String, hit_position: Vector2, streak: int) -> void:
	parry_succeeded.emit(bullet_type, hit_position, streak)
