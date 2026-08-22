extends Node2D
class_name GravityVortexEffect
## 重力特異点（ブラックホール）エフェクト＆吸引制御コンポーネント

@export var radius: float = 80.0
@export var damage_per_tick: int = 10
@export var duration: float = 1.4
@export var vortex_color: Color = Color(0.75, 0.3, 1.0)

var time_passed: float = 0.0
var life_timer: float = 0.0
var tick_timer: float = 0.0
var current_alpha: float = 1.0


func _ready() -> void:
	z_index = 45
	z_as_relative = false
	
	# スムーズな出現＆フェードアウト
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	tween.tween_interval(duration - 0.45)
	tween.tween_property(self, "modulate:a", 0.0, 0.30)
	tween.chain().tween_callback(queue_free)


func setup_vortex(pos: Vector2, rad: float = 80.0, dmg: int = 10, dur: float = 1.4, col: Color = Color(0.75, 0.3, 1.0)) -> void:
	global_position = pos
	radius = rad
	damage_per_tick = dmg
	duration = dur
	vortex_color = col


func _process(delta: float) -> void:
	time_passed += delta
	life_timer += delta
	tick_timer += delta
	rotation += delta * 7.5 # 高速回転
	
	# 0.2秒ごとの吸引とダメージ
	if tick_timer >= 0.2:
		tick_timer = 0.0
		apply_vortex_force()
		
	queue_redraw()


func apply_vortex_force() -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if is_instance_valid(e) and e.visible:
			var d = global_position.distance_to(e.global_position)
			if d <= radius:
				var pull_dir = (global_position - e.global_position).normalized()
				if "position" in e:
					e.position += pull_dir * 18.0
				if e.has_method("take_damage"):
					e.take_damage(damage_per_tick)
				elif e.has_method("take_damage_on_part"):
					e.take_damage_on_part("core", damage_per_tick)
					
	# パーティクル
	var p_scene = load("res://game/bullets/parry_particle.tscn")
	if p_scene and get_parent():
		var p = p_scene.instantiate()
		p.global_position = global_position
		p.modulate = vortex_color
		p.scale = Vector2(0.45, 0.45)
		get_parent().add_child(p)


func _draw() -> void:
	# 1. 中心ブラックホール核
	draw_circle(Vector2.ZERO, 14.0, Color(0.04, 0.02, 0.08, 0.95))
	draw_arc(Vector2.ZERO, 16.0, 0, TAU, 24, Color.WHITE, 2.0)
	
	# 2. 渦巻きアーム（3本の重力スパイラル）
	var arms = 3
	for i in range(arms):
		var base_angle = i * (TAU / float(arms))
		var pts = PackedVector2Array()
		for seg in range(12):
			var t = float(seg) / 12.0
			var a = base_angle + t * 3.5
			var r = 16.0 + t * (radius * 0.85)
			pts.append(Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, Color(vortex_color.r, vortex_color.g, vortex_color.b, 0.75), 3.0)
		
	# 3. 最外郭イベントホライズン境界リング
	var pulse = sin(time_passed * 12.0) * 4.0
	draw_arc(Vector2.ZERO, radius + pulse, 0, TAU, 36, Color(vortex_color.r, vortex_color.g, vortex_color.b, 0.35), 2.0)
