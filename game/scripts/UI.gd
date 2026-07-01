extends Control
## UI 表示スクリプト
## - HP バー（Player・Boss）
## - パリィカウント
## - ゲームオーバー画面

@onready var player_hp_label: Label = Label.new()
@onready var boss_hp_label: Label = Label.new()
@onready var parry_count_label: Label = Label.new()
@onready var guard_status_label: Label = Label.new()


func _ready() -> void:
	# ラベル作成
	player_hp_label.text = "Player HP: 100/100"
	player_hp_label.position = Vector2(10, 10)
	add_child(player_hp_label)
	
	boss_hp_label.text = "Boss HP: 900/900"
	boss_hp_label.position = Vector2(10, 40)
	add_child(boss_hp_label)
	
	parry_count_label.text = "Parries: 0"
	parry_count_label.position = Vector2(10, 70)
	add_child(parry_count_label)
	
	guard_status_label.text = "Guard: READY (SPACE)"
	guard_status_label.position = Vector2(10, 100)
	add_child(guard_status_label)


func update_player_hp(current: int, max_hp: int) -> void:
	"""プレイヤー HP 更新"""
	player_hp_label.text = "Player HP: %d/%d" % [current, max_hp]


func update_boss_hp(current: int, max_hp: int) -> void:
	"""ボス HP 更新"""
	boss_hp_label.text = "Boss HP: %d/%d" % [current, max_hp]


func update_parry_count(count: int) -> void:
	"""パリィカウント更新"""
	parry_count_label.text = "Parries: %d" % count


func update_guard_status(cooldown: float, is_guarding: bool) -> void:
	"""ガード状態表示更新"""
	if is_guarding:
		guard_status_label.text = "Guard: ACTIVE!"
		guard_status_label.modulate = Color.CYAN
	elif cooldown > 0.0:
		guard_status_label.text = "Guard Cooldown: %.1fs" % cooldown
		guard_status_label.modulate = Color.ORANGE_RED
	else:
		guard_status_label.text = "Guard: READY (SPACE)"
		guard_status_label.modulate = Color.GREEN


func show_game_over(result: String) -> void:
	"""ゲームオーバーまたはクリア（VICTORY）画面をリッチに表示"""
	# 重複表示を防止
	if has_node("GameOverPanel"):
		return
		
	# 1. 画面全体を覆う半透明背景 (ColorRect)
	var panel = ColorRect.new()
	panel.name = "GameOverPanel"
	panel.color = Color(0.05, 0.05, 0.08, 0.0)  # 初期状態は完全透明
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	add_child(panel)
	
	# 背景のフェードインアニメーション
	var tween = create_tween()
	tween.tween_property(panel, "color", Color(0.05, 0.05, 0.08, 0.85), 0.5)
	
	# 2. 中央配置用のVBoxContainer
	var container = VBoxContainer.new()
	container.anchor_left = 0.5
	container.anchor_top = 0.5
	container.anchor_right = 0.5
	container.anchor_bottom = 0.5
	container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container.grow_vertical = Control.GROW_DIRECTION_BOTH
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.custom_minimum_size = Vector2(400, 300)
	container.offset_left = -200
	container.offset_top = -150
	panel.add_child(container)
	
	# 3. 結果タイトル表示
	var result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var settings = LabelSettings.new()
	settings.font_size = 48
	settings.outline_size = 10
	settings.outline_color = Color(0, 0, 0, 1)
	
	if result == "VICTORY":
		result_label.text = "MISSION ACCOMPLISHED"
		settings.font_color = Color.CYAN
	else:
		result_label.text = "SYSTEM DEFEATED"
		settings.font_color = Color.ORANGE_RED
		
	result_label.label_settings = settings
	container.add_child(result_label)
	
	# スペーサー
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 15)
	container.add_child(spacer)
	
	# 4. パリィ実績などのゲームデータ表示
	var stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var stats_settings = LabelSettings.new()
	stats_settings.font_size = 22
	stats_settings.font_color = Color(0.8, 0.9, 1.0, 0.9)
	stats_label.label_settings = stats_settings
	
	var parries = 0
	var game_manager = get_node_or_null("../GameManager")
	if game_manager:
		parries = game_manager.parry_count
	stats_label.text = "TOTAL PARRIES EXTRACTED: %d" % parries
	container.add_child(stats_label)
	
	# スペーサー
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 35)
	container.add_child(spacer2)
	
	# 5. スタイリッシュなリトライボタン
	var retry_btn = Button.new()
	retry_btn.text = "RESTART SYSTEM"
	retry_btn.custom_minimum_size = Vector2(220, 50)
	retry_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# スタイリング (StyleBoxFlat の設定)
	var theme_color = Color.CYAN if result == "VICTORY" else Color.ORANGE_RED
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.08, 0.08, 0.12, 1.0)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = theme_color
	style_normal.corner_radius_top_left = 6
	style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_left = 6
	style_normal.corner_radius_bottom_right = 6
	style_normal.expand_margin_left = 10
	style_normal.expand_margin_right = 10
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = theme_color
	
	retry_btn.add_theme_color_override("font_color", Color.WHITE)
	retry_btn.add_theme_color_override("font_hover_color", Color.BLACK)
	retry_btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	
	retry_btn.add_theme_stylebox_override("normal", style_normal)
	retry_btn.add_theme_stylebox_override("hover", style_hover)
	retry_btn.add_theme_stylebox_override("pressed", style_hover)
	retry_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	container.add_child(retry_btn)
	
	# 接続
	retry_btn.pressed.connect(func():
		if game_manager and game_manager.has_method("restart"):
			game_manager.restart()
	)
