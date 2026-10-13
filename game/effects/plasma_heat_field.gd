extends Node2D
class_name PlasmaHeatField

var radius: float = 58.0
var damage_per_tick: int = 8
var remaining: float = 1.2
var tick_timer: float = 0.0

func setup(point: Vector2, size: float, amount: int) -> void:
	global_position = point
	radius = size
	damage_per_tick = amount

func _ready() -> void:
	add_to_group("plasma_heat_fields")
	z_index = 40
	var fields := get_tree().get_nodes_in_group("plasma_heat_fields")
	if fields.size() > 8:
		fields[0].queue_free()

func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
		return
	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer = 0.2
		for target in CombatTargets.in_radius(self, global_position, radius):
			CombatTargets.damage(target, damage_per_tick, global_position)
	queue_redraw()

func _draw() -> void:
	var alpha := minf(remaining / 0.3, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(0.2, 1.0, 0.4, 0.12 * alpha))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 36, Color(0.4, 1.0, 0.6, 0.6 * alpha), 2.0)
	draw_arc(Vector2.ZERO, radius * (0.7 + sin(remaining * 10.0) * 0.1), 0, TAU, 24, Color(0.8, 1.0, 0.5, 0.4 * alpha), 1.5)
