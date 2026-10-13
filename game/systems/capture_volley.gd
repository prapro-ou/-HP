extends Node2D
class_name CaptureVolley
## Captures keep value snapshots, never references to reusable enemy bullets.
const DISPLAY_TIME: float = 0.26
const CAPACITY: int = 12
var shots: Array[Dictionary] = []

func _ready() -> void:
	z_index = 75
	z_as_relative = false

func capture(source: Node2D, multiplier: float = 1.0, precision: bool = false) -> bool:
	if not is_instance_valid(source) or not source.is_visible_in_tree() or source.get("is_friendly") != false or not CombatTargets.can_parry(source):
		return false
	var source_type := str(source.get("bullet_type"))
	var base_damage = source.get("damage")
	store(source_type, float(base_damage) if base_damage != null else 16.0, source.global_position, source.modulate, multiplier, precision)
	# Even overflow is safely defended; only the visible follow-up has a cap.
	CombatTargets.erase(source)
	queue_redraw()
	return true

func store(source_type: String, base_damage: float, point: Vector2, tint: Color, multiplier: float = 1.0, precision: bool = false) -> void:
	if shots.size() < CAPACITY:
		shots.append({"kind": WeaponCatalog.capture_kind(source_type), "source_type": source_type,
			"damage": int(maxf(base_damage, 12.0) * 2.2 * multiplier),
			"precision": precision, "color": tint, "age": 0.0, "origin": to_local(point)})
	queue_redraw()

func clear() -> void:
	shots.clear()
	queue_redraw()

func take_ready() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var waiting: Array[Dictionary] = []
	for index in range(shots.size()):
		var shot := shots[index]
		if float(shot["age"]) >= DISPLAY_TIME:
			var released := shot.duplicate()
			released["offset"] = held_position(index)
			result.append(released)
		else:
			waiting.append(shot)
	shots.assign(waiting)
	queue_redraw()
	return result

func _process(delta: float) -> void:
	for shot in shots:
		shot["age"] = float(shot["age"]) + delta
	if not shots.is_empty():
		queue_redraw()

func held_position(index: int) -> Vector2:
	var angle := TAU * index / maxf(shots.size(), 1.0) + PI * 0.5
	var point := global_position + Vector2.from_angle(angle) * 40.0
	return to_local(point.clamp(Vector2(12, 12), get_viewport_rect().size - Vector2(12, 12)))

func _draw() -> void:
	for index in range(shots.size()):
		var shot := shots[index]
		var progress := clampf(float(shot["age"]) / DISPLAY_TIME, 0.0, 1.0)
		var point: Vector2 = shot["origin"].lerp(held_position(index), 1.0 - pow(1.0 - progress, 3.0))
		var tint: Color = shot["color"]
		tint = tint.lerp(Color.CYAN, 0.35)
		tint.a = 0.9
		draw_circle(point, 10.0, Color(0.0, 0.05, 0.08, 0.7))
		draw_arc(point, 10.0, 0, TAU, 16, Color.GOLD if shot.get("precision", false) else Color(0.4, 1.0, 1.0, 0.7), 2.0 if shot.get("precision", false) else 1.0)
		match shot["kind"]:
			"homing":
				draw_colored_polygon(PackedVector2Array([point + Vector2(0, -8), point + Vector2(5, 6), point + Vector2(-5, 6)]), tint)
			"laser", "pierce":
				draw_line(point + Vector2(0, -7), point + Vector2(0, 7), tint, 4.0)
			"spread", "cyclone", "vortex":
				draw_arc(point, 5.0, 0, TAU * 0.8, 12, tint, 3.0)
			"blade":
				draw_line(point + Vector2(-7, 3), point + Vector2(7, -3), tint, 3.0)
			"thunder":
				draw_polyline(PackedVector2Array([point + Vector2(3, -7), point + Vector2(-3, 0), point + Vector2(3, 0), point + Vector2(-3, 7)]), tint, 2.0)
			_:
				draw_circle(point, 5.0 if shot["kind"] != "meteor" else 7.0, tint)
