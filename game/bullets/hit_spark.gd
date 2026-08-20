extends Node2D
class_name HitSpark
## 弾丸着弾ヒットスパークエフェクト
## - 通常ヒット: 鮮烈な黄色/オレンジの火花＋十字フラッシュ
## - シールドヒット: 水色の六角形バリア展開＋青白スパーク
## - コア/重撃破: 大口径クリティカル爆砕スパーク

var spark_type: String = "normal" # "normal", "shield", "heavy"
var spark_color: Color = Color(1.0, 0.85, 0.3)
var lifetime: float = 0.15
var timer: float = 0.0
var particles: Array[Dictionary] = []

func _ready() -> void:
	z_index = 60
	z_as_relative = false
	
	var count = 6
	var speed_min = 90.0
	var speed_max = 220.0
	
	if spark_type == "shield":
		count = 8
		spark_color = Color(0.3, 0.85, 1.0)
		speed_min = 120.0
		speed_max = 260.0
	elif spark_type == "heavy":
		count = 10
		spark_color = Color(1.0, 0.6, 0.1)
		speed_min = 140.0
		speed_max = 300.0
		
	for i in range(count):
		var angle = randf() * TAU
		var spd = randf_range(speed_min, speed_max)
		var dir = Vector2(cos(angle), sin(angle))
		particles.append({
			"pos": Vector2.ZERO,
			"vel": dir * spd,
			"length": randf_range(4.0, 10.0),
			"width": randf_range(1.5, 2.5)
		})
	queue_redraw()


func _process(delta: float) -> void:
	timer += delta
	if timer >= lifetime:
		queue_free()
		return
		
	for p in particles:
		p["pos"] += p["vel"] * delta
		p["vel"] *= 0.82 # 強い空気抵抗で減速
		
	queue_redraw()


func _draw() -> void:
	var progress = timer / lifetime
	var alpha = clamp(1.0 - progress, 0.0, 1.0)
	
	# 1. 中心フラッシュ (十字 / 星型)
	if progress < 0.6:
		var flash_alpha = (1.0 - progress / 0.6) * 0.9
		var flash_size = 14.0 * (1.0 - progress * 0.8)
		if spark_type == "heavy":
			flash_size = 22.0 * (1.0 - progress * 0.8)
			
		var core_col = Color(1.0, 1.0, 1.0, flash_alpha)
		# 水平・垂直の鋭い光条
		draw_line(Vector2(-flash_size, 0), Vector2(flash_size, 0), core_col, 2.5)
		draw_line(Vector2(0, -flash_size), Vector2(0, flash_size), core_col, 2.5)
		draw_circle(Vector2.ZERO, flash_size * 0.4, Color(spark_color.r, spark_color.g, spark_color.b, flash_alpha * 0.8))
		
	# 2. シールド時の六角形バリアリップル
	if spark_type == "shield" and progress < 0.8:
		var shield_alpha = (1.0 - progress / 0.8) * 0.85
		var shield_radius = 18.0 + progress * 16.0
		var pts = PackedVector2Array()
		for i in range(6):
			var a = i * (TAU / 6.0)
			pts.append(Vector2(cos(a), sin(a)) * shield_radius)
		pts.append(pts[0])
		draw_polyline(pts, Color(0.4, 0.9, 1.0, shield_alpha), 2.0)
		draw_colored_polygon(pts, Color(0.2, 0.7, 1.0, shield_alpha * 0.25))
		
	# 3. 飛び散る火花ライン
	var spark_col = Color(spark_color.r, spark_color.g, spark_color.b, alpha)
	for p in particles:
		var start_p = p["pos"]
		var end_p = p["pos"] - p["vel"].normalized() * p["length"] * (1.0 - progress * 0.5)
		draw_line(start_p, end_p, spark_col, p["width"])


static func create_spark(parent: Node, pos: Vector2, type: String = "normal", color: Color = Color.GOLD) -> void:
	if not parent or not is_instance_valid(parent):
		return
	var spark = load("res://game/bullets/hit_spark.gd").new()
	spark.global_position = pos
	spark.spark_type = type
	spark.spark_color = color
	parent.add_child(spark)
