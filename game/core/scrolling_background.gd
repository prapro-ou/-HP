extends Node2D
class_name ScrollingBackground
## 無限下スクロール背景スクリプト
## 3枚の連続スプライトにより、正方形画像や縦長画像などあらゆる比率の背景で
## 画面の隙間（ブラックアウト）を生じさせずに完全シームレスにスクロールします。

@export var scroll_speed: float = 150.0
@export var background_texture: Texture2D = preload("res://game/assets/backgrounds/backgrnd_stage1.png")

var sprites: Array[Sprite2D] = []
var sprite_height: float = 1200.0


func _ready() -> void:
	z_index = -30
	setup_sprites()


func set_background_texture(tex: Texture2D) -> void:
	if not tex:
		return
	background_texture = tex
	setup_sprites()


func setup_sprites() -> void:
	if not background_texture:
		return
		
	var vp_size = get_viewport_rect().size
	var target_w = max(800.0, vp_size.x)
	var tex_w = background_texture.get_width()
	var tex_h = background_texture.get_height()
	var scale_factor = target_w / float(tex_w)
	sprite_height = tex_h * scale_factor
	
	# 3枚のスプライトを準備
	while sprites.size() < 3:
		var sp = Sprite2D.new()
		add_child(sp)
		sprites.append(sp)
		
	for i in range(3):
		var sp = sprites[i]
		sp.texture = background_texture
		sp.scale = Vector2(scale_factor, scale_factor)
		# i=0: 中央 (0〜H), i=1: 上部 (-H〜0), i=2: 下部 (H〜2H)
		var center_y = (sprite_height / 2.0) + (i - 1) * sprite_height
		sp.position = Vector2(target_w / 2.0, center_y)


func _process(delta: float) -> void:
	if sprites.size() < 3:
		return
		
	var move_y = scroll_speed * delta
	var vp_h = max(1200.0, get_viewport_rect().size.y)
	
	for sp in sprites:
		sp.position.y += move_y
		
	for sp in sprites:
		# スプライトの上端が画面下端を超えたら、一番上にあるスプライトの真上へ移動
		if sp.position.y - (sprite_height / 2.0) >= vp_h:
			var min_y = INF
			for other in sprites:
				if other != sp and other.position.y < min_y:
					min_y = other.position.y
			sp.position.y = min_y - sprite_height

