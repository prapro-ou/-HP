extends Node2D
class_name PlayerCounterBeam
var player: Node2D
var damage_multiplier: float = 1.0
var tick_timer: float = 0.0
var age: float = 0.0
var half_width: float = 30.0

func setup(owner_player: Node2D, multiplier: float) -> void:
	player = owner_player
	damage_multiplier = multiplier

func _ready() -> void:
	add_to_group("counter_effects")
	z_index = 55

func _process(delta: float) -> void:
	if not is_instance_valid(player) or player.current_hp <= 0:
		queue_free()
		return
	global_position = player.global_position + Vector2(0, -28)
	age += delta
	tick_timer -= delta
	if age >= 0.3 and tick_timer <= 0.0:
		tick_timer = 0.15
		var corridor := Rect2(Vector2(global_position.x - half_width, -100), Vector2(half_width * 2, global_position.y + 100))
		for target in CombatTargets.in_rectangle(self, corridor):
			CombatTargets.damage(target, int(44 * damage_multiplier), target.global_position)
	queue_redraw()

func _draw() -> void:
	var top := Vector2(0, -global_position.y - 100)
	if age < 0.3:
		draw_line(Vector2.ZERO, top, Color(0.4, 1.0, 1.0, 0.5), 2.0)
		return
	draw_line(Vector2.ZERO, top, Color(0.2, 0.85, 1.0, 0.12), half_width * 2.4)
	draw_line(Vector2.ZERO, top, Color(0.4, 0.95, 1.0, 0.55), half_width * 2.0)
	draw_line(Vector2.ZERO, top, Color(0.9, 1.0, 1.0, 0.9), 12.0)
	draw_arc(Vector2.ZERO, half_width + sin(age * 15.0) * 3, 0, TAU, 24, Color.CYAN, 2.0)
