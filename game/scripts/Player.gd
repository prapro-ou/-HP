extends CharacterBody2D
## プレイヤー機体スクリプト
## - 移動制御
## - 武器スロット・自動射撃・解析武器の切り替え
## - スペースキーでのジャストガード（クールダウン短縮：2.0秒）

@export var max_hp: int = 100
@export var move_speed: float = 300.0
@export var parry_window_radius: float = 65.0  # ガード範囲をやや広げてパリィしやすく
@export var fire_rate: float = 0.2  # 射撃間隔

# ガード関連の変数
@export var parry_active_time: float = 0.25  # ガード判定の持続時間
@export var parry_cooldown: float = 2.0      # クールダウン時間（2秒にして難易度緩和）

var current_hp: int
var last_fire_time: float = 0.0
var enemy_bullets: Array = []  # 敵弾リファレンス（GameManager から取得）

var active_timer: float = 0.0
var cooldown_timer: float = 0.0
var is_guarding: bool = false
var space_was_pressed: bool = false  # 自前でのキー押下瞬間判定用

# 武器システム
# - progress: 0~100 (解析率)
# - level: 1 (通常), 2 (部位破壊による技術獲得で強化)
var weapons: Dictionary = {
	"beam": { "analyzed": false, "progress": 0, "level": 1 },
	"missile": { "analyzed": false, "progress": 0, "level": 1 }
}
var current_weapon: String = "none" # "none", "beam", "missile"
var toggle_key_pressed: bool = false

var PlayerBulletScene = preload("res://game/scenes/player_bullet.tscn")


func _ready() -> void:
	current_hp = max_hp


func _process(delta: float) -> void:
	# 移動入力（十字キーまたはWASD対応）
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_axis("ui_left", "ui_right")
	input_vector.y = Input.get_axis("ui_up", "ui_down")
	
	velocity = input_vector.normalized() * move_speed
	move_and_slide()
	
	# 画面内に留める
	var viewport_size = get_viewport_rect().size
	position.x = clamp(position.x, 20, viewport_size.x - 20)
	position.y = clamp(position.y, 20, viewport_size.y - 20)
	
	# 武器切り替え入力 (Shift, Z, Cキーのいずれかでトグル切り替え)
	var is_toggle_pressed = Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_C)
	if is_toggle_pressed:
		if not toggle_key_pressed:
			toggle_key_pressed = true
			toggle_weapon()
	else:
		toggle_key_pressed = false
	
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


func toggle_weapon() -> void:
	# 両方未アンロックの場合は切り替えない
	if not weapons["beam"]["analyzed"] and not weapons["missile"]["analyzed"]:
		return
		
	# 片方だけアンロックの場合
	if weapons["beam"]["analyzed"] and not weapons["missile"]["analyzed"]:
		if current_weapon != "beam":
			current_weapon = "beam"
			spawn_popup_message("WEAPON ENGAGED: BEAM")
		return
	if weapons["missile"]["analyzed"] and not weapons["beam"]["analyzed"]:
		if current_weapon != "missile":
			current_weapon = "missile"
			spawn_popup_message("WEAPON ENGAGED: MISSILE")
		return
		
	# 両方アンロックされている場合は相互トグル
	if current_weapon == "beam":
		current_weapon = "missile"
	else:
		current_weapon = "beam"
	spawn_popup_message("WEAPON ENGAGED: " + current_weapon.to_upper())


func fire() -> void:
	"""弾を発射"""
	if not PlayerBulletScene:
		return
		
	var player_bullets_container = get_node_or_null("/root/Main/PlayerBullets")
	var target_parent = player_bullets_container if player_bullets_container else get_parent()
	
	# 1. 常に「解析ショット (Analysis Shot)」を正面に発射
	var analysis_shot = PlayerBulletScene.instantiate()
	analysis_shot.bullet_type = "analysis"
	analysis_shot.global_position = global_position + Vector2(0, -20)
	analysis_shot.velocity = Vector2.UP * 900.0
	target_parent.add_child(analysis_shot)
	
	# 2. 選択武器がアンロックされていれば発射
	if current_weapon == "beam" and weapons["beam"]["analyzed"]:
		if weapons["beam"]["level"] == 1:
			# 標準レーザー (高速直線レーザー)
			var bullet = PlayerBulletScene.instantiate()
			bullet.bullet_type = "beam"
			bullet.global_position = global_position
			bullet.velocity = Vector2.UP * 1500.0
			target_parent.add_child(bullet)
		else:
			# 強化レーザー (極太 Giga Laser)
			var bullet = PlayerBulletScene.instantiate()
			bullet.bullet_type = "giga_laser"
			bullet.global_position = global_position
			bullet.velocity = Vector2.UP * 2000.0
			target_parent.add_child(bullet)
			
	elif current_weapon == "missile" and weapons["missile"]["analyzed"]:
		var is_hyper = weapons["missile"]["level"] > 1
		var missile_type = "hyper_missile" if is_hyper else "missile"
		
		# ミサイルは自機の横から飛び出させる
		var offsets = [Vector2(-20, 0), Vector2(20, 0)]
		if is_hyper:
			offsets.append(Vector2(-35, 10))
			offsets.append(Vector2(35, 10))
			
		for offset in offsets:
			var bullet = PlayerBulletScene.instantiate()
			bullet.bullet_type = missile_type
			bullet.global_position = global_position + offset
			# 少し斜め外向きに発射して、そこから追尾させる
			var launch_dir = Vector2(offset.x, -50).normalized()
			bullet.velocity = launch_dir * (550.0 if is_hyper else 450.0)
			target_parent.add_child(bullet)


func check_parry() -> void:
	"""敵弾がジャストガード判定ウィンドウ内にあるかチェック"""
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
		modulate = Color(0.5, 0.5, 0.5, 1.0)
	else:
		# 選択中の武器に応じてベースカラーを微調整
		match current_weapon:
			"beam":
				modulate = Color(0.7, 1.0, 1.0) # 薄水色
			"missile":
				modulate = Color(0.9, 0.7, 1.0) # 薄紫色
			_:
				modulate = Color.WHITE


func take_damage(amount: int) -> void:
	"""ダメージ受け取り"""
	# ガード中はダメージ無効
	if is_guarding:
		return
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0


func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)


func advance_analysis(bullet_type: String, amount: int) -> void:
	"""パリィや敵撃破で解析度を進める"""
	var weapon_key = ""
	if bullet_type.contains("beam"):
		weapon_key = "beam"
	elif bullet_type.contains("missile"):
		weapon_key = "missile"
		
	if weapon_key == "" or weapons[weapon_key]["analyzed"]:
		return
		
	weapons[weapon_key]["progress"] += amount
	if weapons[weapon_key]["progress"] >= 100:
		weapons[weapon_key]["progress"] = 100
		weapons[weapon_key]["analyzed"] = true
		
		# 自動で装備
		current_weapon = weapon_key
		spawn_popup_message("ANALYSIS COMPLETE: [" + weapon_key.to_upper() + "] ONLINE!")
		trigger_screen_flash(Color(0.2, 1.0, 1.0, 0.4))


func upgrade_weapon(weapon_type: String) -> void:
	"""部位破壊時に武器をレベル2（強化状態）にする"""
	if weapons.has(weapon_type):
		weapons[weapon_type]["level"] = 2
		weapons[weapon_type]["analyzed"] = true # まだ解析できていなかった場合でも強制アンロック
		current_weapon = weapon_type
		
		var label_text = "TECHNOLOGY HARVESTED: [" + weapon_type.to_upper() + " LV2]!"
		spawn_popup_message(label_text)
		trigger_screen_flash(Color(1.0, 0.8, 0.2, 0.6))


func trigger_screen_flash(color: Color = Color(1.0, 1.0, 1.0, 0.5)) -> void:
	var main = get_node_or_null("/root/Main")
	if main:
		var ui_node = main.get_node_or_null("UI")
		if ui_node and ui_node.has_method("trigger_flash"):
			ui_node.trigger_flash(color)


func spawn_popup_message(text: String) -> void:
	"""画面に一時的なポップアップテキストを表示する"""
	var label = Label.new()
	label.text = text
	
	# ラベルの表示設定
	var settings = LabelSettings.new()
	settings.font_size = 20
	settings.font_color = Color.CYAN
	settings.outline_size = 5
	settings.outline_color = Color.BLACK
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# 初期位置の設定（プレイヤーの少し上に中央揃えで配置）
	label.global_position = global_position + Vector2(-200, -70)
	label.custom_minimum_size = Vector2(400, 30)
	
	# メインシーンに追加
	var main = get_node_or_null("/root/Main")
	if main:
		main.add_child(label)
	else:
		get_parent().add_child(label)
	
	# Tweenによる上昇＆フェードアウトアニメーション
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0, -80), 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

