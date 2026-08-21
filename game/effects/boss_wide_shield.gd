extends Node2D
class_name BossWideShield
## ボス下面ワイドエネルギーウォール防護シールド＆送電ビームコンポーネント

@export var shield_pos: Vector2 = Vector2.ZERO:
	set(val):
		shield_pos = val
		queue_redraw()
@export var generator_pos: Vector2 = Vector2.ZERO:
	set(val):
		generator_pos = val
		queue_redraw()
@export var shield_width: float = 460.0
@export var shield_height: float = 55.0
@export var shield_color: Color = Color(0.25, 0.85, 1.0)
@export var is_active: bool = true

var time_passed: float = 0.0
var current_alpha: float = 1.0


func _ready() -> void:
	z_index = 48
	z_as_relative = false


func _process(delta: float) -> void:
	if not is_active:
		if current_alpha > 0.0:
			current_alpha = max(0.0, current_alpha - delta * 4.0)
			queue_redraw()
		return
		
	if current_alpha < 1.0:
		current_alpha = min(1.0, current_alpha + delta * 4.0)
		
	time_passed += delta
	queue_redraw()


func _draw() -> void:
	if current_alpha <= 0.0:
		return
		
	var local_b_pos = shield_pos - global_position
	var local_gen_pos = generator_pos - global_position
	
	var pulse = 0.5 + 0.5 * sin(time_passed * 6.0)
	var glow_pulse = 0.7 + 0.3 * sin(time_passed * 12.0)
	var half_w = shield_width * 0.5
	var arc_depth = shield_height
	
	# 1. 砲台からボス下面シールドへの「送電ビーム」（多層エネルギーアーク）
	if generator_pos != Vector2.ZERO:
		var beam_col = Color(shield_color.r, shield_color.g, shield_color.b, current_alpha * (0.45 + pulse * 0.25))
		draw_line(local_gen_pos, local_b_pos, beam_col, 8.0, true)
		draw_line(local_gen_pos, local_b_pos, Color(1.0, 1.0, 1.0, current_alpha * 0.85), 2.5, true)
		
		# 送電コネクトノード
		draw_circle(local_gen_pos, 8.0 + pulse * 2.0, Color(shield_color.r, shield_color.g, shield_color.b, current_alpha * 0.7))
		draw_circle(local_gen_pos, 3.5, Color.WHITE)
		draw_circle(local_b_pos, 10.0 + pulse * 3.0, Color(shield_color.r, shield_color.g, shield_color.b, current_alpha * 0.7))
		draw_circle(local_b_pos, 4.0, Color.WHITE)
		
	# 2. ボス下面のワイド湾曲エネルギーウォール（ポリゴンメッシュ）
	var num_pts = 24
	var outer_wall = PackedVector2Array()
	var inner_wall = PackedVector2Array()
	
	for i in range(num_pts + 1):
		var t = float(i) / float(num_pts)
		var x = -half_w + t * (half_w * 2.0)
		var norm_x = (t - 0.5) * 2.0 # -1.0 to 1.0
		var curve_y = (1.0 - norm_x * norm_x) * arc_depth
		outer_wall.append(local_b_pos + Vector2(x, curve_y + 12.0))
		inner_wall.append(local_b_pos + Vector2(x, curve_y - 12.0))
		
	var poly_pts = PackedVector2Array()
	for p in outer_wall:
		poly_pts.append(p)
	for i in range(inner_wall.size() - 1, -1, -1):
		poly_pts.append(inner_wall[i])
		
	# 半透明エネルギーフィル
	var fill_col = Color(shield_color.r * 0.8, shield_color.g * 0.95, shield_color.b, current_alpha * (0.16 + pulse * 0.08))
	draw_colored_polygon(poly_pts, fill_col)
	
	# 外縁・内縁の多層アークライン
	var edge_col_main = Color(shield_color.r, shield_color.g, shield_color.b, current_alpha * (0.75 + glow_pulse * 0.25))
	var edge_col_core = Color(1.0, 1.0, 1.0, current_alpha * (0.65 + pulse * 0.35))
	draw_polyline(outer_wall, edge_col_main, 4.0)
	draw_polyline(outer_wall, edge_col_core, 1.5)
	draw_polyline(inner_wall, Color(shield_color.r, shield_color.g, shield_color.b, current_alpha * 0.4), 2.0)
	
	# ヘックスパターン装飾
	for h_i in range(-3, 4):
		var h_x = h_i * 60.0
		var norm_hx = h_x / half_w
		var h_y = (1.0 - norm_hx * norm_hx) * arc_depth
		var h_center = local_b_pos + Vector2(h_x, h_y)
		var hex_r = 14.0 + pulse * 2.0
		var h_pts = PackedVector2Array()
		for a_i in range(6):
			var a = a_i * (TAU / 6.0)
			h_pts.append(h_center + Vector2(cos(a), sin(a)) * hex_r)
		h_pts.append(h_pts[0])
		draw_polyline(h_pts, Color(shield_color.r, shield_color.g, shield_color.b, current_alpha * 0.35), 1.2)
