extends Node2D
## Boss-owned, pause-aware salvos. Pending shots disappear with their owner.

const WARNING_TIME: float = 0.75
const RECOVERY_TIME: float = 0.65
const PATTERN_NAMES: Dictionary = {
	"gap_wall": "連続弾幕 — 隙間へ移動 / 捕獲可能",
	"aimed_burst": "照準固定連射 — 射線から離脱 / 捕獲可能",
	"crossfire": "左右交差射撃 — 交点に注意 / 捕獲可能",
	"sweep": "扇状掃射 — 掃射方向に注意 / 捕獲可能"
}

var boss: Node2D
var pattern: String = ""
var elapsed: float = 0.0
var next_event: int = 0
var end_time: float = 0.0
var events: Array[Dictionary] = []
var warning_lines: Array[PackedVector2Array] = []
var gap_rect: Rect2
var viewport_size: Vector2
var warning_label: Label
var intense_pattern: bool = false

func setup(owner_boss: Node2D, attack: String, intense: bool, variation: int) -> void:
	boss = owner_boss
	pattern = attack
	intense_pattern = intense
	viewport_size = boss.get_viewport_rect().size
	var multiplier: float = boss.get_stage_difficulty_mult()
	var rounds: int = 3 if intense else 2
	var target := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.7)
	if is_instance_valid(boss.player):
		target = boss.player.global_position
	var center := Vector2(viewport_size.x * 0.5, 170.0)
	match pattern:
		"gap_wall":
			var gap_width := maxf(110.0, viewport_size.x * 0.22)
			var gap_x := viewport_size.x * (0.3 if variation % 2 == 0 else 0.7)
			gap_rect = Rect2(gap_x - gap_width * 0.5, 160.0, gap_width, viewport_size.y - 160.0)
			for round_index in range(rounds):
				for lane in range(13):
					var origin := Vector2(viewport_size.x * float(lane + 1) / 14.0, 160.0)
					if absf(origin.x - gap_x) < gap_width * 0.5:
						continue
					add_shot(round_index * 0.32, origin, Vector2.DOWN, "straight", int(14 * multiplier), 290.0)
					if round_index == 0:
						add_warning(origin, Vector2(origin.x, viewport_size.y))
		"aimed_burst":
			for side in [0.28, 0.72]:
				var origin := Vector2(viewport_size.x * side, 170.0)
				var direction := (target - origin).normalized()
				add_warning(origin, origin + direction * viewport_size.y)
				for shot_index in range(5 if intense else 3):
					add_shot(shot_index * 0.18, origin, direction, "laser", int(16 * multiplier), 430.0)
		"crossfire":
			for side in [0.12, 0.88]:
				var origin := Vector2(viewport_size.x * side, 180.0)
				var direction := (target - origin).normalized()
				for offset in [-12.0, 0.0, 12.0]:
					var shot_direction := direction.rotated(deg_to_rad(offset))
					add_warning(origin, origin + shot_direction * viewport_size.y)
					for round_index in range(rounds):
						add_shot(round_index * 0.28, origin, shot_direction, "straight", int(14 * multiplier), 350.0)
		"sweep":
			var reverse := variation % 2 == 1
			var steps: int = 9 if intense else 7
			for step in range(steps):
				var angle := lerpf(-48.0, 48.0, float(step) / float(steps - 1))
				if reverse:
					angle = -angle
				for offset in [-6.0, 6.0]:
					var direction := Vector2.DOWN.rotated(deg_to_rad(angle + offset))
					add_shot(step * 0.11, center, direction, "laser", int(14 * multiplier), 320.0)
				add_warning(center, center + Vector2.DOWN.rotated(deg_to_rad(angle)) * viewport_size.y)
	# Sort by firing time so two emitters do not serialize each other's salvos.
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
	end_time = WARNING_TIME + RECOVERY_TIME
	if not events.is_empty():
		end_time = float(events.back()["time"]) + RECOVERY_TIME

func add_shot(delay: float, origin: Vector2, direction: Vector2, kind: String, damage: int, speed: float) -> void:
	events.append({"time": WARNING_TIME + delay, "origin": origin, "direction": direction,
		"kind": kind, "damage": damage, "speed": speed})

func add_warning(origin: Vector2, target: Vector2) -> void:
	warning_lines.append(PackedVector2Array([origin, target]))

func _ready() -> void:
	z_index = 65
	z_as_relative = false
	add_to_group("boss_attack_sequences")
	warning_label = Label.new()
	warning_label.text = ("猛攻: " if intense_pattern else "") + str(PATTERN_NAMES.get(pattern, "捕獲可能弾幕")).replace(" / 捕獲可能", "")
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning_label.position = to_local(Vector2(24, 92))
	warning_label.size = Vector2(viewport_size.x - 48.0, 44.0)
	warning_label.add_theme_font_override("font", Global.get_readable_font())
	warning_label.add_theme_font_size_override("font_size", 22)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	warning_label.add_theme_color_override("font_outline_color", Color.BLACK)
	warning_label.add_theme_constant_override("outline_size", 2)
	add_child(warning_label)
	var ui = get_node_or_null("/root/Main/UI")
	if ui:
		ui.show_combat_notice(warning_label.text, Color.GOLD, WARNING_TIME, 1)
		warning_label.hide()

func _process(delta: float) -> void:
	if not is_instance_valid(boss) or boss.is_queued_for_deletion() or not boss.is_alive or not boss.is_active or boss.current_hp <= 0 or not boss.is_visible_in_tree():
		queue_free()
		return
	if not is_instance_valid(boss.player) or boss.player.current_hp <= 0 or boss.player.is_control_locked:
		queue_free()
		return
	elapsed += delta
	var ui = get_node_or_null("/root/Main/UI")
	warning_label.visible = elapsed < WARNING_TIME and ui == null
	while next_event < events.size() and float(events[next_event]["time"]) <= elapsed:
		var event: Dictionary = events[next_event]
		if is_instance_valid(boss.bullet_pool):
			var bullet = boss.bullet_pool.get_bullet(event["kind"])
			if is_instance_valid(bullet):
				bullet.global_position = event["origin"]
				bullet.damage = event["damage"]
				bullet.set_direction(event["direction"], event["speed"])
		next_event += 1
	if elapsed >= end_time:
		queue_free()
	queue_redraw()

func _draw() -> void:
	if elapsed >= WARNING_TIME:
		return
	var alpha := 0.3 + 0.35 * (elapsed / WARNING_TIME)
	for line in warning_lines:
		draw_line(to_local(line[0]), to_local(line[1]), Color(1.0, 0.75, 0.25, alpha), 1.5)
		draw_circle(to_local(line[0]), 8.0 + elapsed * 7.0, Color(1.0, 0.8, 0.3, alpha))
	if pattern == "gap_wall":
		draw_rect(Rect2(to_local(gap_rect.position), gap_rect.size), Color(0.3, 0.9, 1.0, 0.09))
		draw_line(to_local(gap_rect.position), to_local(gap_rect.position + Vector2(0, gap_rect.size.y)), Color(0.3, 0.9, 1.0, alpha), 2.0)
		draw_line(to_local(gap_rect.position + Vector2(gap_rect.size.x, 0)), to_local(gap_rect.end), Color(0.3, 0.9, 1.0, alpha), 2.0)

