extends Label
class_name CombatPopup

const PIXEL_FONT: Font = preload("res://game/assets/fonts/DotGothic16-Regular.ttf")


func show_damage(amount: int, is_finish: bool = false, is_critical: bool = false) -> void:
	text = str(amount) + ("!" if is_critical else "")
	var settings := LabelSettings.new()
	settings.font = PIXEL_FONT
	if is_finish:
		settings.font_size = 22
		settings.font_color = Color(1.0, 0.6, 0.2)
		settings.outline_size = 3
		settings.outline_color = Color.BLACK
	elif is_critical:
		settings.font_size = 20
		settings.font_color = Color(1.0, 0.88, 0.15)
		settings.outline_size = 4
		settings.outline_color = Color(0.35, 0.05, 0.0)
	else:
		settings.font_size = 15
		settings.font_color = Color(1.0, 0.9, 0.3) if amount > 15 else Color(0.9, 0.95, 1.0, 0.9)
		settings.outline_size = 2
		settings.outline_color = Color.BLACK
	label_settings = settings
	pivot_offset = Vector2(40, 15)
	var start_scale := Vector2(0.8, 0.8) if is_critical else Vector2(0.5, 0.5)
	var end_scale := Vector2(1.3, 1.3) if is_critical else Vector2.ONE
	scale = start_scale
	var target_position := global_position + Vector2(randf_range(-15, 15), -45 if is_critical else -35)
	_animate(end_scale, target_position, 0.18, 0.20)


func show_kill(message: String) -> void:
	text = message
	var settings := LabelSettings.new()
	settings.font = PIXEL_FONT
	settings.font_size = 24
	settings.font_color = Color(1.0, 0.85, 0.2)
	settings.outline_size = 3
	settings.outline_color = Color(0.1, 0.05, 0.0, 1.0)
	label_settings = settings
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pivot_offset = Vector2(60, 20)
	scale = Vector2(0.4, 0.4)
	_animate(Vector2.ONE, global_position + Vector2(0, -30), 0.25, 0.20)


func _animate(end_scale: Vector2, target_position: Vector2, fade_delay: float, fade_duration: float) -> void:
	var motion := create_tween().set_parallel(true)
	motion.tween_property(self, "scale", end_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion.tween_property(self, "global_position", target_position, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var fade := create_tween()
	fade.tween_interval(fade_delay)
	fade.tween_property(self, "modulate:a", 0.0, fade_duration)
	motion.chain().tween_callback(queue_free)
