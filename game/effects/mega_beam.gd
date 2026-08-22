extends Node2D
class_name MegaBeamEffect
## 多層レイヤー極太ビーム・レーザー描画コンポーネント
## - 最外郭プラズマオーラ（超極太・半透明）
## - 中間高熱フレア層（太・高輝度・脈動）
## - 白熱コア層（純白）
## - 発射口＆着弾点プラズマ光球
## - 周囲の螺旋放電アーク

@export var start_pos: Vector2 = Vector2.ZERO:
	set(val):
		start_pos = val
		queue_redraw()
@export var end_pos: Vector2 = Vector2.ZERO:
	set(val):
		end_pos = val
		queue_redraw()
@export var beam_color: Color = Color(0.3, 0.85, 1.0)
@export var beam_width: float = 36.0 # 基本太さ（細〜極太まで対応）
@export var is_pulsing: bool = true
@export var has_discharge_arcs: bool = true
@export var auto_fade_duration: float = 0.0 # 0より大きい場合は自動フェードアウト

var time_passed: float = 0.0
var current_alpha: float = 1.0


func _ready() -> void:
	z_index = 55
	z_as_relative = false
	if auto_fade_duration > 0.0:
		var tween = create_tween()
		tween.tween_property(self, "current_alpha", 0.0, auto_fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(queue_free)


func setup_beam(start_p: Vector2, end_p: Vector2, col: Color = Color(0.3, 0.85, 1.0), width: float = 36.0, duration: float = 0.0) -> void:
	start_pos = start_p
	end_pos = end_p
	beam_color = col
	beam_width = width
	auto_fade_duration = duration
	if duration > 0.0:
		var tween = create_tween()
		tween.tween_property(self, "current_alpha", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(queue_free)
	queue_redraw()


func _process(delta: float) -> void:
	time_passed += delta
	queue_redraw()


func _draw() -> void:
	if current_alpha <= 0.0 or start_pos == end_pos:
		return
		
	# 時間によるエネルギーの脈動
	var pulse = (sin(time_passed * 36.0) * 0.15 + 1.0) if is_pulsing else 1.0
	var eff_w = beam_width * pulse
	
	# 1. 最外郭プラズマオーラ (超極太・半透明)
	var outer_w = eff_w * 2.2
	var outer_col = Color(beam_color.r, beam_color.g, beam_color.b, current_alpha * 0.22)
	draw_line(start_pos, end_pos, outer_col, outer_w, true)
	
	# 2. 中間高熱フレア層 (太・高輝度)
	var mid_w = eff_w * 1.1
	var mid_col = Color(beam_color.r, beam_color.g, beam_color.b, current_alpha * 0.75)
	draw_line(start_pos, end_pos, mid_col, mid_w, true)
	
	# 3. 白熱中心コア (純白)
	var core_w = max(2.5, eff_w * 0.35)
	var core_col = Color(1.0, 1.0, 1.0, current_alpha * 0.95)
	draw_line(start_pos, end_pos, core_col, core_w, true)
	
	# 4. 発射口＆着弾点の大プラズマ光球
	draw_circle(start_pos, outer_w * 0.5, outer_col)
	draw_circle(start_pos, core_w * 1.4, core_col)
	draw_circle(end_pos, outer_w * 0.6, outer_col)
	draw_circle(end_pos, core_w * 1.6, core_col)
	
	# 5. 周囲に絡みつく螺旋放電アーク（細い稲妻）
	if has_discharge_arcs and beam_width >= 16.0:
		var beam_len = start_pos.distance_to(end_pos)
		if beam_len > 30.0:
			var dir = (end_pos - start_pos).normalized()
			var normal = Vector2(-dir.y, dir.x)
			var segments = clamp(int(beam_len / 35.0), 4, 18)
			var arc_pts = PackedVector2Array([start_pos])
			for i in range(1, segments):
				var t = float(i) / float(segments)
				var p = start_pos + dir * (beam_len * t)
				var offset_mag = sin(t * 22.0 + time_passed * 28.0) * (eff_w * 0.8)
				arc_pts.append(p + normal * offset_mag)
			arc_pts.append(end_pos)
			draw_polyline(arc_pts, Color(1.0, 1.0, 1.0, current_alpha * 0.7), max(1.5, core_w * 0.35))
