extends CharacterBody2D
## プレイヤー機体スクリプト
## - 移動制御
## - 自動射撃
## - スペースキーでのジャストガード（クールダウン5秒）

@export var max_hp: int = 100
@export var move_speed: float = 300.0
@export var parry_window_radius: float = 50.0  # ガード範囲（能動ガードのため、少し広めの50pxに変更）
@export var fire_rate: float = 20.0 / 60.0  # 射撃間隔

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
	"""プレイヤー弾を前方に発射"""
	if PlayerBulletScene:
		var bullet = PlayerBulletScene.instantiate()
		bullet.global_position = global_position
		
		# Mainシーンの PlayerBullets コンテナ、または親ノードに追加する
		var player_bullets_container = get_node_or_null("/root/Main/PlayerBullets")
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
