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

# New loadout and capability variables
var is_attack_unlocked: bool = false
var power_shield_damage_buff: float = 0.0

# パリィリング演出用
var parry_ring_radius: float = 0.0
var parry_ring_alpha: float = 0.0
var parried_in_current_frame: bool = false # 同一ガード期間内の演出重複防止

# トドメ演出用フルバーストフラグ
var is_full_burst: bool = false

# 武器システム
# - progress: 0~100 (解析率)
# - level: 1 (通常), 2 (部位破壊による技術獲得で強化)
var weapons: Dictionary = {
	"beam": { "analyzed": false, "progress": 0, "level": 1 },
	"missile": { "analyzed": false, "progress": 0, "level": 1 }
}
var current_weapon: String = "none" # "none", "beam", "missile"
var toggle_key_pressed: bool = false

var PlayerBulletScene = preload("res://game/player/player_bullet.tscn")


func _ready() -> void:
	# Apply Lab Upgrades from Global state
	var hp_lvl = Global.upgrade_levels.get("hp", 0)
	max_hp = 100 + 10 * hp_lvl
	current_hp = max_hp
	
	var parry_lvl = Global.upgrade_levels.get("parry_window", 0)
	parry_window_radius = 65.0 + 5.0 * parry_lvl
	
	var cd_lvl = Global.upgrade_levels.get("cooldown", 0)
	parry_cooldown = 2.0 - 0.1 * cd_lvl
	
	is_attack_unlocked = false
	power_shield_damage_buff = 0.0
	
	apply_equipped_weapon_settings()


func apply_equipped_weapon_settings() -> void:
	# グローバルから装備武器を取得し、発射レート等を調整
	var eq_w = Global.equipped_weapon
	match eq_w:
		"machine_gun":
			fire_rate = 0.14
		"burst_rifle":
			fire_rate = 0.48
		"charge_rifle":
			fire_rate = 1.25
		"pulse_gun":
			fire_rate = 0.2
		"plasma_emitter":
			fire_rate = 0.35
		"kinetic_tackle":
			fire_rate = 0.8
		_:
			fire_rate = 0.2


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
	
	# 射撃 (最初のパリィ成功で攻撃アンロックされる仕様)
	if is_attack_unlocked:
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
		parried_in_current_frame = false # 新規ガード開始時にリセット
	
	# ガード中のパリィ判定
	if is_guarding:
		check_parry()
	
	# 状態によるプレイヤーの見た目の変更（フィードバック）
	update_visual_state()
	
	# パリィリングの描画更新
	if parry_ring_alpha > 0.0:
		queue_redraw()
		
	# トドメ演出時のフルバースト射撃
	if is_full_burst:
		if not has_meta("last_burst_time"):
			set_meta("last_burst_time", 0.0)
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - get_meta("last_burst_time") > 0.06:
			fire_full_burst()
			set_meta("last_burst_time", current_time)

	# チュートリアル用のスローモーション制御 (初回起動時のみ)
	if Global.is_first_launch and not is_attack_unlocked:
		var near_bullet_found = false
		for bullet in enemy_bullets:
			if is_instance_valid(bullet) and not bullet.is_friendly:
				var dist = global_position.distance_to(bullet.global_position)
				# パリィフィールドの手前でスローにする
				if dist <= parry_window_radius * 2.2 and dist > parry_window_radius * 0.4:
					near_bullet_found = true
					break
		
		if near_bullet_found and not is_guarding:
			Engine.time_scale = 0.15
			if not has_meta("slow_alert_shown"):
				set_meta("slow_alert_shown", true)
				spawn_popup_message("⚠️ DANGER: PRESS SPACE TO PARRY!")
		else:
			if Engine.time_scale < 0.5 and not is_guarding:
				Engine.time_scale = 1.0

	# ボス戦中の COUNTER SYSTEM (1ステージ1回のみの超反撃) の手動発動 (Xキー)
	if not is_full_burst and not get_meta("is_counter_system_used", false):
		var main = get_node_or_null("/root/Main")
		if main:
			var manager = main.get_node_or_null("GameManager")
			if manager and manager.get("state") == "boss":
				if Input.is_key_pressed(KEY_X):
					set_meta("is_counter_system_used", true)
					is_full_burst = true
					spawn_popup_message("⚠️ COUNTER SYSTEM ACTIVE: FULL BURST!")
					
					# 3秒後にフルバーストを自動停止
					get_tree().create_timer(3.0).timeout.connect(func():
						is_full_burst = false
						spawn_popup_message("COUNTER SYSTEM: DEPLETED")
					)


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
	analysis_shot.damage += int(power_shield_damage_buff)
	target_parent.add_child(analysis_shot)
	
	# 2. 出撃前選択された物理武装の射撃
	fire_equipped_physics_weapon(target_parent)
	
	# 3. 解析・アンロックされた特殊武器（副兵装）がアクティブなら追加発射
	if current_weapon == "beam" and weapons["beam"]["analyzed"]:
		if weapons["beam"]["level"] == 1:
			# 標準レーザー (高速直線レーザー)
			var bullet = PlayerBulletScene.instantiate()
			bullet.bullet_type = "beam"
			bullet.global_position = global_position
			bullet.velocity = Vector2.UP * 1500.0
			bullet.damage += int(power_shield_damage_buff)
			target_parent.add_child(bullet)
		else:
			# 強化レーザー (極太 Giga Laser)
			var bullet = PlayerBulletScene.instantiate()
			bullet.bullet_type = "giga_laser"
			bullet.global_position = global_position
			bullet.velocity = Vector2.UP * 2000.0
			bullet.damage += int(power_shield_damage_buff)
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
			bullet.damage += int(power_shield_damage_buff)
			# 少し斜め外向きに発射して、そこから追尾させる
			var launch_dir = Vector2(offset.x, -50).normalized()
			bullet.velocity = launch_dir * (550.0 if is_hyper else 450.0)
			target_parent.add_child(bullet)


func fire_equipped_physics_weapon(target_parent: Node) -> void:
	var eq_w = Global.equipped_weapon
	match eq_w:
		"machine_gun":
			# 交互または並行に2発
			var offsets = [Vector2(-12, -10), Vector2(12, -10)]
			for offset in offsets:
				var bullet = PlayerBulletScene.instantiate()
				bullet.bullet_type = "machine_gun"
				bullet.global_position = global_position + offset
				bullet.velocity = Vector2.UP * 1100.0
				bullet.damage += int(power_shield_damage_buff)
				target_parent.add_child(bullet)
				
		"burst_rifle":
			# 3点バーストをタイマーで少しずらして発射
			for i in range(3):
				get_tree().create_timer(i * 0.07).timeout.connect(func():
					if is_instance_valid(self) and is_instance_valid(target_parent):
						var bullet = PlayerBulletScene.instantiate()
						bullet.bullet_type = "burst_rifle"
						bullet.global_position = global_position + Vector2(0, -20)
						bullet.velocity = Vector2.UP * 1300.0
						bullet.damage += int(power_shield_damage_buff)
						target_parent.add_child(bullet)
				)
				
		"charge_rifle":
			# チャージ完了として極太のレールガンショット
			var bullet = PlayerBulletScene.instantiate()
			bullet.bullet_type = "charge_bolt"
			bullet.global_position = global_position + Vector2(0, -25)
			bullet.velocity = Vector2.UP * 1800.0
			bullet.damage += int(power_shield_damage_buff)
			target_parent.add_child(bullet)
			
			# チャージ完了演出（少し画面を揺らすなど）
			trigger_screen_flash(Color(0.8, 0.9, 1.0, 0.15))
			
		"pulse_gun":
			# 斜め方向に広がる2つのパルス
			var angles = [-12.0, 12.0]
			for angle in angles:
				var bullet = PlayerBulletScene.instantiate()
				bullet.bullet_type = "pulse"
				bullet.global_position = global_position + Vector2(angle * 0.8, -15)
				var dir = Vector2.UP.rotated(deg_to_rad(angle))
				bullet.velocity = dir * 950.0
				bullet.damage += int(power_shield_damage_buff)
				target_parent.add_child(bullet)
				
		"plasma_emitter":
			# 3方向に広がるプラズマボルト
			var angles = [-20, 0, 20]
			for angle in angles:
				var bullet = PlayerBulletScene.instantiate()
				bullet.bullet_type = "plasma"
				bullet.global_position = global_position + Vector2(angle * 0.5, -20)
				var dir = Vector2.UP.rotated(deg_to_rad(angle))
				bullet.velocity = dir * 500.0
				bullet.damage += int(power_shield_damage_buff)
				target_parent.add_child(bullet)
				
		"kinetic_tackle":
			# 前方に巨大な衝撃波/タックルエネルギーを飛ばす
			var bullet = PlayerBulletScene.instantiate()
			bullet.bullet_type = "tackle"
			bullet.global_position = global_position + Vector2(0, -30)
			bullet.velocity = Vector2.UP * 750.0
			bullet.damage += int(power_shield_damage_buff)
			target_parent.add_child(bullet)


func check_parry() -> void:
	"""敵弾がジャストガード判定ウィンドウ内にあるかチェック"""
	var parry_triggered_now = false
	var shield_type = Global.equipped_shield
	
	for bullet in enemy_bullets:
		if is_instance_valid(bullet) and not bullet.is_friendly:
			var dist = global_position.distance_to(bullet.global_position)
			if dist <= parry_window_radius:
				# 攻撃機能アンロック（最初のパリィ）
				if not is_attack_unlocked:
					is_attack_unlocked = true
					if Global.is_first_launch:
						Global.is_first_launch = false
						Engine.time_scale = 1.0
						spawn_popup_message("PARRY SUCCESSFUL! WEAPONS SYSTEM ENGAGED.")
						
						# セーブデータを書き出す
						var current_stage = 1
						var main = get_node_or_null("/root/Main")
						if main:
							var manager = main.get_node_or_null("GameManager")
							if manager and "current_stage_num" in manager:
								current_stage = manager.current_stage_num
						Global.save_game(current_stage, 0, weapons)
				
				if shield_type == "power":
					# 初期装備強化型 (Power): 敵弾を吸収し、自機の基礎攻撃力を強化する
					bullet.recycle_bullet()
					power_shield_damage_buff = min(power_shield_damage_buff + 4.0, 20.0) # 最大+20ダメージ加算
					
					# 変換しない代わりに、手動で解析進捗とパリィ登録を実行する
					advance_analysis(bullet.bullet_type, 15)
					
					var main = get_node_or_null("/root/Main")
					if main:
						var manager = main.get_node_or_null("GameManager")
						if manager and manager.has_method("register_parry"):
							manager.register_parry()
				else:
					# カウンター特化型 (Counter) または ゲージ回収型 (Gauge)
					bullet.convert_to_friendly()
					if shield_type == "counter":
						# 反射弾のダメージを1.5倍に強化
						bullet.damage = int(bullet.damage * 1.5)
						
				parry_triggered_now = true
				
	if parry_triggered_now and not parried_in_current_frame:
		parried_in_current_frame = true
		trigger_parry_feedback()


func update_visual_state() -> void:
	"""状態に応じて機体の色（modulate）を変更"""
	if is_guarding:
		# シールドの種類に応じてガード中の発光色を変更
		match Global.equipped_shield:
			"counter":
				modulate = Color(0.9, 0.4, 1.0) # 紫発光
			"gauge":
				modulate = Color(0.3, 1.0, 0.6) # 緑発光
			"power":
				modulate = Color(1.0, 0.6, 0.2) # オレンジ発光
			_:
				modulate = Color.CYAN
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
		
	# チュートリアル中に被弾した場合はスローモーション解除
	if Global.is_first_launch and Engine.time_scale < 0.5:
		Engine.time_scale = 1.0
		
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
		
	# ゲージ回収シールドなら1.8倍のゲージ増加
	var actual_amount = amount
	if Global.equipped_shield == "gauge":
		actual_amount = int(amount * 1.8)
		
	weapons[weapon_key]["progress"] += actual_amount
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


func trigger_parry_feedback() -> void:
	# 1. 画面フラッシュ (水色)
	trigger_screen_flash(Color(0.3, 0.8, 1.0, 0.45))
	
	# 2. ヒットストップ (0.12秒間スローモーション)
	trigger_hit_stop(0.12, 0.05)
	
	# 3. シールド波紋リング
	trigger_parry_ring_effect()
	
	# 4. ポップアップメッセージ
	spawn_parry_popup_message("PARRY!")


func trigger_hit_stop(duration_sec: float, scale: float) -> void:
	Engine.time_scale = scale
	# ignore_time_scale引数が無い古いGodotバージョンに対応するため、
	# スロー倍率を掛け算した時間を指定して実時間待機を実現
	var timer = get_tree().create_timer(duration_sec * scale, true)
	timer.timeout.connect(func():
		Engine.time_scale = 1.0
	)


func trigger_parry_ring_effect() -> void:
	parry_ring_radius = 15.0
	parry_ring_alpha = 0.9
	queue_redraw()
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "parry_ring_radius", parry_window_radius * 1.4, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "parry_ring_alpha", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func spawn_parry_popup_message(text: String) -> void:
	var label = Label.new()
	label.text = text
	
	var settings = LabelSettings.new()
	settings.font_size = 28 # 通常より大きく
	settings.font_color = Color.GOLD # ゴールドで豪華に
	settings.outline_size = 6
	settings.outline_color = Color.BLACK
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	label.global_position = global_position + Vector2(-200, -80)
	label.custom_minimum_size = Vector2(400, 40)
	
	var main = get_node_or_null("/root/Main")
	if main:
		main.add_child(label)
	else:
		get_parent().add_child(label)
	
	# ポップアップのアニメーション（素早く拡大してフェードアウト）
	label.scale = Vector2(0.5, 0.5)
	label.pivot_offset = Vector2(200, 20)
	
	var tween = create_tween()
	tween.set_parallel(true)
	# 拡大
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# 上昇
	tween.tween_property(label, "global_position", label.global_position + Vector2(0, -90), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 遅れてフェードアウト
	var fade_tween = create_tween()
	fade_tween.tween_interval(0.4)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.6)
	
	tween.chain().tween_callback(label.queue_free)


func _draw() -> void:
	if parry_ring_alpha > 0.0:
		var base_color = Color(0.0, 0.9, 1.0)
		match Global.equipped_shield:
			"counter":
				base_color = Color(0.8, 0.3, 1.0) # Purple/Magenta
			"gauge":
				base_color = Color(0.1, 0.9, 0.5) # Lime Green
			"power":
				base_color = Color(1.0, 0.5, 0.0) # Vivid Orange
				
		var color = Color(base_color.r, base_color.g, base_color.b, parry_ring_alpha)
		draw_arc(Vector2.ZERO, parry_ring_radius, 0, TAU, 48, color, 4.0, true)
		var fill_color = Color(base_color.r, base_color.g, base_color.b, parry_ring_alpha * 0.15)
		draw_circle(Vector2.ZERO, parry_ring_radius, fill_color)


func fire_full_burst() -> void:
	"""トドメ用のフルバースト射撃"""
	if not PlayerBulletScene:
		return
		
	var player_bullets_container = get_node_or_null("/root/Main/PlayerBullets")
	var target_parent = player_bullets_container if player_bullets_container else get_parent()
	
	# ボスを狙う方向
	var target_pos = Vector2(get_viewport_rect().size.x / 2.0, 160.0) # ボスの概算位置
	var main = get_node_or_null("/root/Main")
	if main:
		var boss_node = main.get_node_or_null("Boss")
		if is_instance_valid(boss_node):
			target_pos = boss_node.global_position
			
	var dir_to_boss = (target_pos - global_position).normalized()
	
	# 1. 強化レーザー (極太 Giga Laser)
	var bullet_giga = PlayerBulletScene.instantiate()
	bullet_giga.bullet_type = "giga_laser"
	bullet_giga.global_position = global_position
	bullet_giga.velocity = dir_to_boss * 2500.0
	target_parent.add_child(bullet_giga)
	
	# 2. ハイパーミサイルを扇状に4発
	var angles = [-25, -10, 10, 25]
	for angle in angles:
		var bullet_missile = PlayerBulletScene.instantiate()
		bullet_missile.bullet_type = "hyper_missile"
		bullet_missile.global_position = global_position + Vector2(angle * 1.5, 0)
		bullet_missile.velocity = dir_to_boss.rotated(deg_to_rad(angle)) * 800.0
		target_parent.add_child(bullet_missile)
		
	# 3. 解析ショットを大量にばらまく
	for i in range(3):
		var bullet_analysis = PlayerBulletScene.instantiate()
		bullet_analysis.bullet_type = "analysis"
		bullet_analysis.global_position = global_position + Vector2(randf_range(-30, 30), -20)
		bullet_analysis.velocity = dir_to_boss.rotated(randf_range(-0.3, 0.3)) * 1200.0
		target_parent.add_child(bullet_analysis)
		
	# 演出として画面フラッシュを小さく発生させる
	trigger_screen_flash(Color(0.2, 0.8, 1.0, 0.1))
