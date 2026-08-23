extends Area2D
class_name DataOrb
## 敵撃破時に飛び出し、プレイヤーに高速吸引される解析エナジーオーブ

var target_player: CharacterBody2D
var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 0.0
var max_lifetime: float = 6.0
var orb_type: String = "straight"
var orb_color: Color = Color.CYAN

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow: ColorRect = $Glow


func _ready() -> void:
	z_index = 15
	add_to_group("data_orbs")
	
	# 初速：敵撃破時に放射状にぽんと飛び散る
	var angle = randf_range(0.0, TAU)
	var initial_spd = randf_range(160.0, 280.0)
	velocity = Vector2(cos(angle), sin(angle)) * initial_spd
	
	scale = Vector2(0.5, 0.5)
	
	# 色適用
	apply_color()
	
	body_entered.connect(_on_body_entered)


func setup_orb(p_type: String, start_pos: Vector2, player_node: CharacterBody2D) -> void:
	orb_type = p_type
	global_position = start_pos
	target_player = player_node
	apply_color()


func apply_color() -> void:
	var color_map = {
		"straight": Color(0.3, 0.8, 1.0),
		"wave": Color(0.2, 1.0, 0.6),
		"charge": Color(1.0, 0.6, 0.2),
		"missile": Color(0.85, 0.45, 1.0),
		"laser": Color(0.4, 0.9, 1.0),
		"irregular": Color(1.0, 0.85, 0.2)
	}
	orb_color = color_map.get(orb_type, Color.CYAN)
	modulate = orb_color
	if is_instance_valid(glow):
		glow.color = Color(orb_color.r, orb_color.g, orb_color.b, 0.6)


func _process(delta: float) -> void:
	lifetime += delta
	if lifetime >= max_lifetime:
		queue_free()
		return
		
	# プレイヤーへのマグネット吸引
	if is_instance_valid(target_player):
		var to_player = (target_player.global_position - global_position)
		var dist = to_player.length()
		
		# 0.15秒後から強い吸引力が働く
		if lifetime > 0.15:
			var pull_force = clamp(1800.0 / max(dist, 20.0), 400.0, 1600.0)
			velocity = velocity.move_toward(to_player.normalized() * pull_force, 2400.0 * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		
	position += velocity * delta


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body == target_player:
		absorb_to_player(body)


func absorb_to_player(player: Node2D) -> void:
	if player.has_method("advance_analysis"):
		player.advance_analysis(orb_type, 12.0)
		
	if player.has_method("heal"):
		player.heal(8)
		
	if player.has_method("spawn_popup_message"):
		player.spawn_popup_message("DATA EXP +12% / HP +8")
		
	# キラキラ消滅
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.08)
	tween.tween_property(self, "modulate:a", 0.0, 0.08)
	tween.chain().tween_callback(queue_free)
