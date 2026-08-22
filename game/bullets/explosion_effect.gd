extends Node2D
class_name ExplosionEffect
## 爆発エフェクト（プロシージャル衝撃波＋白熱コア＋飛散デブリ）

var duration: float = 0.4
var timer: float = 0.0
var max_radius: float = 70.0
var base_color: Color = Color(1.0, 0.55, 0.15)
var debris: Array[Dictionary] = []

func _ready() -> void:
	z_index = 65
	z_as_relative = false
	
	# デブリ火花の生成
	var count = int(clamp(max_radius * 0.25, 8.0, 24.0))
	for i in range(count):
		var angle = randf() * TAU
		var spd = randf_range(80.0, 260.0) * (max_radius / 70.0)
		debris.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * spd,
			"size": randf_range(2.0, 4.5) * (max_radius / 70.0),
			"len": randf_range(4.0, 12.0)
		})
	queue_redraw()


func _process(delta: float) -> void:
	timer += delta
	if timer >= duration:
		queue_free()
		return
		
	for d in debris:
		d["pos"] += d["vel"] * delta
		d["vel"] *= 0.88
		
	queue_redraw()


func _draw() -> void:
	var t = timer / duration # 0.0 -> 1.0
	
	# 1. 衝撃波リング（高速拡大＆フェードアウト）
	var shock_radius = max_radius * (0.3 + t * 1.1)
	var shock_alpha = clamp((1.0 - t) * 0.95, 0.0, 1.0)
	draw_arc(Vector2.ZERO, shock_radius, 0, TAU, 32, Color(1.0, 1.0, 1.0, shock_alpha), 2.5)
	if t < 0.5:
		draw_arc(Vector2.ZERO, shock_radius * 0.85, 0, TAU, 28, Color(base_color.r, base_color.g, base_color.b, shock_alpha * 0.6), 1.5)

	# 2. 炎球・プラズマ球（急拡大 ➔ 収縮）
	if t < 0.65:
		var fire_t = t / 0.65
		var fire_radius = max_radius * sin(fire_t * PI * 0.5)
		var fire_alpha = (1.0 - fire_t) * 0.85
		
		# 外側（炎色/プラズマ色）
		draw_circle(Vector2.ZERO, fire_radius, Color(base_color.r, base_color.g, base_color.b, fire_alpha))
		# 中間（オレンジ/イエロー）
		draw_circle(Vector2.ZERO, fire_radius * 0.7, Color(1.0, 0.85, 0.3, fire_alpha))
		# 中心（白熱コア）
		draw_circle(Vector2.ZERO, fire_radius * 0.4, Color(1.0, 1.0, 1.0, fire_alpha * 1.2))

	# 3. 四方に飛び散る火花デブリ
	var deb_alpha = clamp(1.0 - t, 0.0, 1.0)
	var deb_col = Color(base_color.r, base_color.g, base_color.b, deb_alpha)
	for d in debris:
		var p1 = d["pos"]
		var p2 = d["pos"] - d["vel"].normalized() * d["len"] * (1.0 - t * 0.5)
		draw_line(p1, p2, deb_col, d["size"])
		draw_circle(p1, d["size"] * 0.8, Color(1.0, 0.9, 0.7, deb_alpha))


static func create(parent: Node, pos: Vector2, radius: float = 70.0, color: Color = Color(1.0, 0.55, 0.15), dur: float = 0.4) -> void:
	if not parent or not is_instance_valid(parent):
		return
	var exp_node = load("res://game/bullets/explosion_effect.gd").new()
	exp_node.global_position = pos
	exp_node.max_radius = radius
	exp_node.base_color = color
	exp_node.duration = dur
	parent.add_child(exp_node)
