extends Node2D
class_name ParryFX
## パリィ成功時の多層リング・六角形ヘックス・火花スパーク粒子エフェクト

@export var ring_radius: float = 85.0
@export var fx_color: Color = Color(0.3, 0.95, 1.0)
@export var duration: float = 0.40

var ring_current_r: float = 15.0
var ring_alpha: float = 0.95
var shockwave_r: float = 20.0
var shockwave_alpha: float = 0.90
var hex_scale: float = 0.6
var hex_alpha: float = 1.0
var sparks: Array[Dictionary] = []


func _ready() -> void:
	z_index = 65
	z_as_relative = false
	
	# 火花スパーク粒子の生成
	var spark_colors = [Color.WHITE, fx_color, Color.GOLD, Color(0.2, 1.0, 0.6)]
	for i in range(16):
		var angle = randf() * TAU
		var spd = randf_range(180.0, 480.0)
		var life = randf_range(0.25, 0.42)
		sparks.append({
			"pos": Vector2.RIGHT.rotated(angle) * randf_range(5.0, 18.0),
			"vel": Vector2.RIGHT.rotated(angle) * spd,
			"color": spark_colors.pick_random(),
			"life": life,
			"max_life": life,
			"alpha": 1.0,
			"size": randf_range(2.0, 3.5)
		})
		
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "ring_current_r", ring_radius * 1.35, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "ring_alpha", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "shockwave_r", ring_radius * 1.85, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "shockwave_alpha", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "hex_scale", 1.35, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "hex_alpha", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	get_tree().create_timer(duration + 0.1).timeout.connect(queue_free)


func setup_parry(pos: Vector2, radius: float = 85.0, col: Color = Color(0.3, 0.95, 1.0)) -> void:
	global_position = pos
	ring_radius = radius
	fx_color = col


func _process(delta: float) -> void:
	if sparks.size() > 0:
		var remaining: Array[Dictionary] = []
		for p in sparks:
			p["pos"] = p.get("pos", Vector2.ZERO) + p.get("vel", Vector2.ZERO) * delta
			var life = p.get("life", 0.0) - delta
			p["life"] = life
			var max_l = p.get("max_life", 0.3)
			p["alpha"] = clamp(life / max_l, 0.0, 1.0)
			if life > 0.0:
				remaining.append(p)
		sparks = remaining
	queue_redraw()


func _draw() -> void:
	# 1. 放射状火花スパーク
	for p in sparks:
		var a = p.get("alpha", 1.0)
		var base_col = p.get("color", Color.WHITE)
		var c = Color(base_col.r, base_col.g, base_col.b, a)
		var pos_v = p.get("pos", Vector2.ZERO)
		var vel_v = p.get("vel", Vector2.ZERO)
		var sz = p.get("size", 2.5)
		var tail = pos_v - vel_v * 0.035
		draw_line(pos_v, tail, c, sz)
		draw_circle(pos_v, sz * 0.8, Color(1.0, 1.0, 1.0, a))
		
	# 2. 六角形ヘックスバリア
	if hex_alpha > 0.0:
		var hex_r = ring_radius * hex_scale
		var hex_pts = PackedVector2Array()
		for i in range(6):
			var a = i * (TAU / 6.0) - PI / 6.0
			hex_pts.append(Vector2(cos(a), sin(a)) * hex_r)
		hex_pts.append(hex_pts[0])
		
		var col = Color(fx_color.r, fx_color.g, fx_color.b, hex_alpha)
		draw_colored_polygon(hex_pts, Color(col.r, col.g, col.b, hex_alpha * 0.22))
		draw_polyline(hex_pts, col, 3.5, true)
		
	# 3. 多層パリィリング ＆ ショックウェーブ
	if ring_alpha > 0.0:
		var col = Color(fx_color.r, fx_color.g, fx_color.b, ring_alpha)
		draw_arc(Vector2.ZERO, ring_current_r, 0, TAU, 48, col, 4.5, true)
		draw_circle(Vector2.ZERO, ring_current_r, Color(col.r, col.g, col.b, ring_alpha * 0.2))
		
	if shockwave_alpha > 0.0:
		draw_arc(Vector2.ZERO, shockwave_r, 0, TAU, 36, Color(1.0, 1.0, 1.0, shockwave_alpha * 0.8), 2.5, true)
