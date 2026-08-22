extends Node2D
class_name ChainLightningEffect
## 連鎖電撃アーク描画エフェクト

@export var start_pos: Vector2 = Vector2.ZERO
@export var target_pos: Vector2 = Vector2.ZERO
@export var bolt_color: Color = Color(1.0, 0.95, 0.3, 0.9)
@export var duration: float = 0.18

var pts: PackedVector2Array = PackedVector2Array()
var current_alpha: float = 1.0


func _ready() -> void:
	z_index = 60
	z_as_relative = false
	generate_lightning_points()
	var tween = create_tween()
	tween.tween_property(self, "current_alpha", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


func setup_lightning(from_pos: Vector2, to_pos: Vector2, col: Color = Color(1.0, 0.95, 0.3, 0.9), dur: float = 0.18) -> void:
	start_pos = from_pos
	target_pos = to_pos
	bolt_color = col
	duration = dur
	generate_lightning_points()
	queue_redraw()


func generate_lightning_points() -> void:
	pts.clear()
	pts.append(start_pos)
	
	var dist = start_pos.distance_to(target_pos)
	var steps = clamp(int(dist / 30.0), 2, 8)
	var dir = (target_pos - start_pos).normalized()
	var normal = Vector2(-dir.y, dir.x)
	
	for i in range(1, steps):
		var t = float(i) / float(steps)
		var base_p = start_pos + dir * (dist * t)
		var jitter = normal * randf_range(-18.0, 18.0)
		pts.append(base_p + jitter)
		
	pts.append(target_pos)


func _draw() -> void:
	if pts.size() < 2 or current_alpha <= 0.0:
		return
		
	# 1. 外郭プラズマオーラ
	var glow_col = Color(bolt_color.r, bolt_color.g, bolt_color.b, current_alpha * 0.4)
	draw_polyline(pts, glow_col, 6.5)
	
	# 2. 内側白熱雷光
	var core_col = Color(1.0, 1.0, 1.0, current_alpha * 0.95)
	draw_polyline(pts, core_col, 2.5)
	
	# 3. 終端スパーク
	draw_circle(target_pos, 6.0, core_col)
