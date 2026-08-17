extends Node2D
class_name ScrollingBackground
## e4.png を使用した無限下スクロール背景スクリプト
## 最背面 (z_index = -10) に配置され、下方向にシームレスにスクロールし続けます。

@export var scroll_speed: float = 150.0
@export var background_texture: Texture2D = preload("res://game/assets/e4.png")

var sprite1: Sprite2D
var sprite2: Sprite2D
var sprite_height: float = 1200.0


func _ready() -> void:
	z_index = -10
	
	var vp_size = get_viewport_rect().size
	var target_w = vp_size.x
	
	if background_texture:
		var tex_w = background_texture.get_width()
		var tex_h = background_texture.get_height()
		var scale_factor = target_w / float(tex_w)
		sprite_height = tex_h * scale_factor
		
		# 1枚目
		sprite1 = Sprite2D.new()
		sprite1.texture = background_texture
		sprite1.scale = Vector2(scale_factor, scale_factor)
		sprite1.position = Vector2(target_w / 2.0, sprite_height / 2.0)
		add_child(sprite1)
		
		# 2枚目 (1枚目の真上に接続)
		sprite2 = Sprite2D.new()
		sprite2.texture = background_texture
		sprite2.scale = Vector2(scale_factor, scale_factor)
		sprite2.position = Vector2(target_w / 2.0, -sprite_height / 2.0)
		add_child(sprite2)


func _process(delta: float) -> void:
	if not sprite1 or not sprite2:
		return
		
	# 下方向にスクロール
	var move_y = scroll_speed * delta
	sprite1.position.y += move_y
	sprite2.position.y += move_y
	
	# 画面下に抜けたら真上に再配置 (シームレスループ)
	if sprite1.position.y >= sprite_height * 1.5:
		sprite1.position.y = sprite2.position.y - sprite_height
		
	if sprite2.position.y >= sprite_height * 1.5:
		sprite2.position.y = sprite1.position.y - sprite_height
