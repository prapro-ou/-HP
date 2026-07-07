extends CharacterBody2D
## プレイヤー機体スクリプト
## - 移動制御
## - 自動射撃
## - スペースキーでのジャストガード（クールダウン5秒）

@export var max_hp: int = 100
@export var move_speed: float = 300.0
@export var parry_window_radius: float = 50.0  # ガード範囲（能動ガードのため、少し広めの50pxに変更）
@export var fire_rate: float = 0.15  # 射撃間隔（初期値は3WAY・速射）

var is_enhanced: bool = false

# ガード関連の変数
@export var parry_active_time: float = 0.25  # ガード判定の持続時間（秒）
@export var parry_cooldown: float = 5.0      # クールダウン時間（秒）

var current_hp: int
var last_fire_time: float = 0.0
var enemy_bullets: Array = []  # 敵弾リファレンス（GameManager から取得）

var active_timer: float = 0.0
var cooldown_timer: float = 0.0
var is_guarding: bool = false
var space_was_pressed: bool = false  # 自前でのキー押下瞬間判定用

var PlayerBulletScene = preload("res://game/scenes/player_bullet.tscn")


func _ready() -> void:
	current_hp = max_hp


func _process(delta: float) -> void:
	# 移動入力（十字キー対応）
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_axis("ui_left", "ui_right")
	input_vector.y = Input.get_axis("ui_up", "ui_down")
	
	velocity = input_vector.normalized() * move_speed
	move_and_slide()
	
	# 画面内に留める
	position.x = clamp(position.x, 0, get_viewport_rect().size.x)
	position.y = clamp(position.y, 0, get_viewport_rect().size.y)
	
	# 射撃
	if Time.get_ticks_msec() / 1000.0 - last_fire_time > fire_rate:
		fire()
		last_fire_time = Time.get_ticks_msec() / 1000.0
	
	# タイマーの更新
	if active_timer > 0.0:
		active_timer -= delta
		if active_timer <= 0.0:
			is_guarding = false
			
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			cooldown_timer = 0.0
	
	# スペースキー入力検出
	var space_pressed = Input.is_key_pressed(KEY_SPACE)
	var space_just_pressed = space_pressed and not space_was_pressed
	space_was_pressed = space_pressed
	
	# ガード発動判定
	if space_just_pressed and cooldown_timer <= 0.0:
		is_guarding = true
		active_timer = parry_active_time
		cooldown_timer = parry_cooldown
	
	# ガード中のパリィ判定
	if is_guarding:
		check_parry()
	
	# 状態によるプレイヤーの見た目の変更（フィードバック）
	update_visual_state()


func fire() -> void:
	"""プレイヤー弾を前方に3WAYで発射"""
	if PlayerBulletScene:
		var angles = [-15, 0, 15]  # 3WAY発射の角度
		var current_speed = 1200.0 if is_enhanced else 800.0  # コピー・強化後はより速いスピードに
		var player_bullets_container = get_node_or_null("/root/Main/PlayerBullets")
		
		for angle in angles:
			var bullet = PlayerBulletScene.instantiate()
			bullet.global_position = global_position
			
			# 進行方向ベクトルを計算（進行方向は上なので-90度ずらす）
			var rad = deg_to_rad(angle - 90)
			var dir = Vector2(cos(rad), sin(rad))
			
			# 速度と角度を設定
			bullet.velocity = dir * current_speed
			bullet.rotation = deg_to_rad(angle)
			
			if player_bullets_container:
				player_bullets_container.add_child(bullet)
			else:
				get_parent().add_child(bullet)


func check_parry() -> void:
	"""敵弾がジャストガード判定ウィンドウ内にあるかチェック"""
	# パリィ対象を走査
	for bullet in enemy_bullets:
		if is_instance_valid(bullet) and not bullet.is_friendly:
			var dist = global_position.distance_to(bullet.global_position)
			if dist <= parry_window_radius:
				bullet.convert_to_friendly()


func update_visual_state() -> void:
	"""状態に応じて機体の色（modulate）を変更"""
	if is_guarding:
		modulate = Color.CYAN  # ガード中は青白く光る
	elif cooldown_timer > 0.0:
		# クールダウン中は少し暗いグレー
		modulate = Color(0.4, 0.4, 0.4, 1.0)
	else:
		modulate = Color.WHITE  # ガード可能状態は通常色


func take_damage(amount: int) -> void:
	"""ダメージ受け取り"""
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0
		# GameManager に通知（敗北）


func heal(amount: int) -> void:
	"""回復（将来用）"""
	current_hp = min(current_hp + amount, max_hp)


func on_parry_registered(count: int) -> void:
	"""ガードが5回成功した際、相手の攻撃特性をコピー・強化する"""
	if count >= 5 and not is_enhanced:
		is_enhanced = true
		fire_rate = 0.08  # 超速射に強化（連射速度アップ）
		spawn_popup_message("解析完了：攻撃特性コピー＆高速化！")


func spawn_popup_message(text: String) -> void:
	"""画面に一時的なポップアップテキストを表示する"""
	var label = Label.new()
	label.text = text
	
	# ラベルの表示設定
	var settings = LabelSettings.new()
	settings.font_size = 18
	settings.font_color = Color.CYAN
	settings.outline_size = 4
	settings.outline_color = Color.BLACK
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# 初期位置の設定（プレイヤーの少し上に中央揃えで配置）
	label.global_position = global_position + Vector2(-150, -50)
	label.custom_minimum_size = Vector2(300, 30)
	
	# メインシーンに追加
	var main = get_node_or_null("/root/Main")
	if main:
		main.add_child(label)
	else:
		get_parent().add_child(label)
	
	# Tweenによる上昇＆フェードアウトアニメーション
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0, -60), 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
