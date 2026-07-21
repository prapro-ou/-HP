extends CanvasLayer
## UI 表示スクリプト（CanvasLayerを継承し、シーン ui.tscn のノードとバインド）
## - HP バー（Player・Boss）を ProgressBar でスタイリッシュに表現
## - ガード、パリィ、および武器解析率（スロット状況）の表示
## - ボスのエネルギー再配分比率の表示
## - 警告演出・フラッシュ演出・ゲームオーバー表示

@onready var player_hp_bar: ProgressBar = $PlayerHPBar
@onready var player_hp_label: Label = $PlayerHPLabel

@onready var boss_hp_bar: ProgressBar = $BossHPBar
@onready var boss_hp_label: Label = $BossHPLabel

@onready var parry_count_label: Label = $ParryCountLabel
@onready var guard_status_label: Label = $GuardStatusLabel

# 武器解析UI
@onready var slot_beam_label: Label = $BeamSlot/Label
@onready var slot_beam_bar: ProgressBar = $BeamSlot/ProgressBar
@onready var slot_missile_label: Label = $MissileSlot/Label
@onready var slot_missile_bar: ProgressBar = $MissileSlot/ProgressBar

# ボスエネルギー比率UI
@onready var boss_energy_label: Label = $BossEnergyLabel

# 警告・フラッシュ演出UI
@onready var warning_title: Label = $WarningTitle
@onready var warning_subtitle: Label = $WarningSubtitle
@onready var flash_overlay: ColorRect = $FlashOverlay


var shield_heat_bar: ProgressBar


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
	# スタイリングの適用
	style_hp_bar(player_hp_bar, Color(0.2, 0.9, 0.4))
	style_hp_bar(boss_hp_bar, Color(1.0, 0.2, 0.2))
	style_analysis_bar(slot_beam_bar, Color.CYAN)
	style_analysis_bar(slot_missile_bar, Color(0.8, 0.4, 1.0))
	
	setup_label_style(player_hp_label, 18, Color.WHITE, 6)
	setup_label_style(boss_hp_label, 18, Color.WHITE, 6)
	setup_label_style(parry_count_label, 22, Color.CYAN, 6)
	setup_label_style(guard_status_label, 20, Color.GREEN, 6)
	setup_label_style(boss_energy_label, 18, Color.GOLD, 6)
	setup_label_style(warning_title, 48, Color.RED, 10)
	setup_label_style(warning_subtitle, 24, Color.GOLD, 6)
	setup_label_style(slot_beam_label, 18, Color.LIGHT_GRAY, 6)
	setup_label_style(slot_missile_label, 18, Color.LIGHT_GRAY, 6)
	
	# 動的なシールドヒートプログレスバーの追加
	create_shield_heat_bar()


func create_shield_heat_bar() -> void:
	shield_heat_bar = ProgressBar.new()
	shield_heat_bar.name = "ShieldHeatBar"
	shield_heat_bar.show_percentage = false
	shield_heat_bar.custom_minimum_size = Vector2(240, 16)
	shield_heat_bar.position = Vector2(30, 72)
	add_child(shield_heat_bar)
	style_hp_bar(shield_heat_bar, Color(0.2, 0.8, 1.0))


func style_hp_bar(bar: ProgressBar, color: Color) -> void:
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.1, 0.13, 0.8)
	sb_bg.border_width_left = 1
	sb_bg.border_width_top = 1
	sb_bg.border_width_right = 1
	sb_bg.border_width_bottom = 1
	sb_bg.border_color = Color(0.3, 0.3, 0.35, 1)
	sb_bg.corner_radius_top_left = 3
	sb_bg.corner_radius_top_right = 3
	sb_bg.corner_radius_bottom_left = 3
	sb_bg.corner_radius_bottom_right = 3
	
	var sb_fg = StyleBoxFlat.new()
	sb_fg.bg_color = color
	sb_fg.corner_radius_top_left = 2
	sb_fg.corner_radius_top_right = 2
	sb_fg.corner_radius_bottom_left = 2
	sb_fg.corner_radius_bottom_right = 2
	
	bar.add_theme_stylebox_override("background", sb_bg)
	bar.add_theme_stylebox_override("fill", sb_fg)


func style_analysis_bar(bar: ProgressBar, color: Color) -> void:
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	sb_bg.border_width_left = 1
	sb_bg.border_width_top = 1
	sb_bg.border_width_right = 1
	sb_bg.border_width_bottom = 1
	sb_bg.border_color = Color(0.2, 0.2, 0.2, 0.8)
	
	var sb_fg = StyleBoxFlat.new()
	sb_fg.bg_color = color
	
	bar.add_theme_stylebox_override("background", sb_bg)
	bar.add_theme_stylebox_override("fill", sb_fg)


func setup_label_style(label: Label, size: int, color: Color, outline: int = 6) -> void:
	var settings = LabelSettings.new()
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = outline
	settings.outline_color = Color.BLACK
	label.label_settings = settings


func update_player_hp(current: int, max_hp: int) -> void:
	player_hp_bar.max_value = max_hp
	player_hp_bar.value = current
	player_hp_label.text = "自機 HP: %d / %d" % [current, max_hp]


func update_boss_hp(current: int, max_hp: int) -> void:
	boss_hp_bar.visible = true
	boss_hp_label.visible = true
	boss_hp_bar.max_value = max_hp
	boss_hp_bar.value = current
	boss_hp_label.text = "ボス HP: %d / %d" % [current, max_hp]


func hide_boss_hp() -> void:
	boss_hp_bar.visible = false
	boss_hp_label.visible = false


func update_parry_count(count: int) -> void:
	parry_count_label.text = "パリィ: %d 回" % count


func update_guard_status(cooldown: float, is_guarding: bool) -> void:
	# 旧互換
	pass


func update_guard_heat(heat: float, max_heat: float, is_overheated: bool, overheat_timer: float, is_guarding: bool) -> void:
	if is_instance_valid(shield_heat_bar):
		shield_heat_bar.max_value = max_heat
		shield_heat_bar.value = heat
		
		# 動的なプログレスバーのカラー演出
		var fg_style = shield_heat_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fg_style:
			if is_overheated:
				# オーバーヒート時の点滅赤発光
				var flash = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
				fg_style.bg_color = Color(1.0, 0.1, 0.1).lerp(Color(0.4, 0.0, 0.0), flash)
			elif is_guarding:
				fg_style.bg_color = Color(0.2, 1.0, 1.0) # シールド発射中水色
			else:
				var pct = (heat / max_heat)
				if pct > 0.7:
					fg_style.bg_color = Color(1.0, 0.45, 0.1) # 危険オレンジ
				elif pct > 0.35:
					fg_style.bg_color = Color(1.0, 0.85, 0.2) # 注意イエロー
				else:
					fg_style.bg_color = Color(0.2, 0.8, 1.0) # 水色

	if is_overheated:
		guard_status_label.text = "⚠️ OVERHEAT! 冷却中 (%.1fs)" % overheat_timer
		guard_status_label.label_settings.font_color = Color.RED
	elif is_guarding:
		guard_status_label.text = "シールド: 展開中！"
		guard_status_label.label_settings.font_color = Color.CYAN
	else:
		var pct = int((heat / max_heat) * 100.0)
		guard_status_label.text = "シールドヒート [Space]"
		guard_status_label.label_settings.font_color = Color.LIGHT_GRAY


func update_pattern_analysis(patterns: Dictionary) -> void:
	"""4つの攻撃パターンの解析度とアンロック状況をリアルタイム表示"""
	var summary_text = ""
	for key in ["rapid", "spread", "pierce", "homing"]:
		if not key in patterns:
			continue
		var data = patterns[key]
		var name_str = data["name"]
		var prog = int(data["progress"])
		var is_done = data["analyzed"]
		
		if is_done:
			summary_text += "【%s】100%% ⚡ " % name_str
		elif prog > 0:
			summary_text += "%s: %d%% | " % [name_str, prog]
			
	if summary_text != "":
		slot_beam_label.text = "敵弾パターン解析: " + summary_text.trim_suffix(" | ")
		slot_beam_label.label_settings.font_color = Color.GOLD
	else:
		slot_beam_label.text = "敵弾パターン解析: パリィで特徴を吸収せよ"
		slot_beam_label.label_settings.font_color = Color.LIGHT_GRAY


func update_analysis_progress(beam_progress: float, beam_ready: bool, missile_progress: float, missile_ready: bool, active_weapon: String) -> void:
	pass


func update_boss_energy(laser: float, missile: float, core: float) -> void:
	boss_energy_label.text = "エネルギー再分配\nコア %d%% | レーザー %d%% | ミサイル %d%%" % [int(core), int(laser), int(missile)]


func hide_boss_energy() -> void:
	boss_energy_label.text = ""


func trigger_flash(color: Color = Color(1.0, 1.0, 1.0, 0.5)) -> void:
	flash_overlay.color = color
	var tween = create_tween()
	tween.tween_property(flash_overlay, "color", Color(color.r, color.g, color.b, 0.0), 0.35)


func show_warning(title: String, subtitle: String) -> void:
	warning_title.text = title
	warning_subtitle.text = subtitle
	
	warning_title.show()
	warning_subtitle.show()
	
	# 点滅アニメーション
	var tween = create_tween().set_loops(4)
	tween.tween_property(warning_title, "modulate:a", 0.1, 0.4)
	tween.tween_property(warning_title, "modulate:a", 1.0, 0.4)
	
	get_tree().create_timer(3.8).timeout.connect(func():
		warning_title.hide()
		warning_subtitle.hide()
	)


func show_game_over(result: String) -> void:
	if has_node("GameOverPanel"):
		get_node("GameOverPanel").queue_free()
		
	var panel = ColorRect.new()
	panel.name = "GameOverPanel"
	panel.color = Color(0.05, 0.05, 0.08, 0.0)
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.process_mode = PROCESS_MODE_ALWAYS
	add_child(panel)
	
	var tween = create_tween()
	if tween.has_method("set_pause_mode"):
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "color", Color(0.05, 0.05, 0.08, 0.85), 0.6)
	
	var container = VBoxContainer.new()
	container.anchor_left = 0.5
	container.anchor_top = 0.5
	container.anchor_right = 0.5
	container.anchor_bottom = 0.5
	container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container.grow_vertical = Control.GROW_DIRECTION_BOTH
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.custom_minimum_size = Vector2(500, 300)
	container.offset_left = -250
	container.offset_top = -150
	panel.add_child(container)
	
	var result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var settings = LabelSettings.new()
	settings.font_size = 42
	settings.outline_size = 8
	settings.outline_color = Color.BLACK
	
	if result == "VICTORY":
		result_label.text = "作戦完了"
		settings.font_color = Color.CYAN
	else:
		result_label.text = "作戦失敗"
		settings.font_color = Color.ORANGE_RED
		
	result_label.label_settings = settings
	container.add_child(result_label)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	container.add_child(spacer)
	
	var stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stats_settings = LabelSettings.new()
	stats_settings.font_size = 24
	stats_settings.font_color = Color(0.8, 0.9, 1.0, 0.9)
	stats_settings.outline_size = 4
	stats_settings.outline_color = Color.BLACK
	stats_label.label_settings = stats_settings
	
	var parries = 0
	var score = 0
	var game_manager = get_node_or_null("../GameManager")
	if game_manager:
		parries = game_manager.parry_count
		if "total_damage_score" in game_manager:
			score = game_manager.total_damage_score
			
	stats_label.text = "総パリィ数: " + str(parries) + " 回\n技術回収: 100%"
	container.add_child(stats_label)
	
	# スコア表示
	if result == "VICTORY":
		var spacer_score = Control.new()
		spacer_score.custom_minimum_size = Vector2(0, 15)
		container.add_child(spacer_score)
		
		var score_title_label = Label.new()
		score_title_label.text = "最終スコア"
		score_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var score_title_settings = LabelSettings.new()
		score_title_settings.font_size = 22
		score_title_settings.font_color = Color.GOLD
		score_title_settings.outline_size = 4
		score_title_settings.outline_color = Color.BLACK
		score_title_label.label_settings = score_title_settings
		container.add_child(score_title_label)
		
		var score_val_label = Label.new()
		score_val_label.text = format_score(score)
		score_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var score_val_settings = LabelSettings.new()
		score_val_settings.font_size = 52
		score_val_settings.font_color = Color(1.0, 0.85, 0.1)
		score_val_settings.outline_size = 10
		score_val_settings.outline_color = Color(0.1, 0.1, 0.3)
		score_val_label.label_settings = score_val_settings
		container.add_child(score_val_label)
		
		animate_score_count(score_val_label, score)
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	container.add_child(spacer2)
	
	var theme_color = Color.CYAN if result == "VICTORY" else Color.ORANGE_RED
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.08, 0.08, 0.12, 1.0)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = theme_color
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = theme_color
	
	# 勝利時は「次のステージへ」ボタンを表示
	if result == "VICTORY":
		var next_btn = Button.new()
		next_btn.text = "次のステージへ"
		next_btn.custom_minimum_size = Vector2(280, 56)
		next_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		next_btn.add_theme_font_size_override("font_size", 22)
		
		next_btn.add_theme_color_override("font_color", Color.WHITE)
		next_btn.add_theme_color_override("font_hover_color", Color.BLACK)
		next_btn.add_theme_color_override("font_pressed_color", Color.BLACK)
		next_btn.add_theme_stylebox_override("normal", style_normal)
		next_btn.add_theme_stylebox_override("hover", style_hover)
		next_btn.add_theme_stylebox_override("pressed", style_hover)
		next_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		container.add_child(next_btn)
		
		next_btn.pressed.connect(func():
			get_tree().paused = false # ポーズ解除
			if game_manager and game_manager.has_method("load_next_stage"):
				game_manager.load_next_stage()
			panel.queue_free()
		)
		
		var spacer_btn = Control.new()
		spacer_btn.custom_minimum_size = Vector2(0, 10)
		container.add_child(spacer_btn)

	var retry_btn = Button.new()
	retry_btn.text = "再挑戦"
	retry_btn.custom_minimum_size = Vector2(280, 56)
	retry_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry_btn.add_theme_font_size_override("font_size", 22)
	
	retry_btn.add_theme_color_override("font_color", Color.WHITE)
	retry_btn.add_theme_color_override("font_hover_color", Color.BLACK)
	retry_btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	retry_btn.add_theme_stylebox_override("normal", style_normal)
	retry_btn.add_theme_stylebox_override("hover", style_hover)
	retry_btn.add_theme_stylebox_override("pressed", style_hover)
	retry_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	container.add_child(retry_btn)
	
	retry_btn.pressed.connect(func():
		get_tree().paused = false # リスタート前に一時停止を解除
		if game_manager and game_manager.has_method("restart"):
			game_manager.restart()
	)
	
	# メインメニューに戻るボタン
	var menu_btn = Button.new()
	menu_btn.text = "メニューへ"
	menu_btn.custom_minimum_size = Vector2(280, 56)
	menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_btn.add_theme_font_size_override("font_size", 22)
	
	menu_btn.add_theme_color_override("font_color", Color.WHITE)
	menu_btn.add_theme_color_override("font_hover_color", Color.BLACK)
	menu_btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	menu_btn.add_theme_stylebox_override("normal", style_normal)
	menu_btn.add_theme_stylebox_override("hover", style_hover)
	menu_btn.add_theme_stylebox_override("pressed", style_hover)
	menu_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	var spacer_menu = Control.new()
	spacer_menu.custom_minimum_size = Vector2(0, 10)
	container.add_child(spacer_menu)
	container.add_child(menu_btn)
	
	menu_btn.pressed.connect(func():
		get_tree().paused = false # 一時停止を解除
		get_tree().change_scene_to_file("res://game/core/main_menu.tscn")
	)
	
	get_tree().paused = true


func spawn_damage_popup(pos: Vector2, amount: int, is_finish: bool = false) -> void:
	var label = Label.new()
	label.text = str(amount)
	
	var settings = LabelSettings.new()
	if is_finish:
		settings.font_size = randi_range(72, 90)
		settings.font_color = Color(1.0, 0.35, 0.1)
		settings.outline_size = 14
		settings.outline_color = Color.BLACK
	else:
		settings.font_size = randi_range(28, 36)
		if amount > 15:
			settings.font_color = Color(1.0, 0.9, 0.2)
			settings.font_size = randi_range(36, 44)
		else:
			settings.font_color = Color.WHITE
		settings.outline_size = 6
		settings.outline_color = Color.BLACK
		
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.pivot_offset = Vector2(100, 30)
	
	label.global_position = pos + Vector2(randf_range(-40, 40), randf_range(-30, 10))
	add_child(label)
	
	label.scale = Vector2(0.2, 0.2)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.3, 1.3) if is_finish else Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var target_pos = label.global_position + Vector2(randf_range(-40, 40), -120)
	tween.tween_property(label, "global_position", target_pos, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var fade_tween = create_tween()
	fade_tween.tween_interval(0.5)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.4)
	
	tween.chain().tween_callback(label.queue_free)


func spawn_kill_popup(pos: Vector2, text: String = "撃破！") -> void:
	"""敵撃破時の短く超巨大で分かりやすいテキスト演出"""
	var label = Label.new()
	label.text = text
	
	var settings = LabelSettings.new()
	settings.font_size = 88 # 超巨大フォントサイズ
	settings.font_color = Color(1.0, 0.85, 0.0) # 鮮やかなゴールドイエロー
	settings.outline_size = 16 # くっきり見やすい太線枠
	settings.outline_color = Color(0.1, 0.0, 0.0, 1.0)
	
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.pivot_offset = Vector2(150, 45)
	label.global_position = pos + Vector2(-150, -45)
	
	add_child(label)
	
	label.scale = Vector2(0.1, 0.1)
	var tween = create_tween().set_parallel(true)
	# 一気に超巨大表示されてバウンド
	tween.tween_property(label, "scale", Vector2(1.25, 1.25), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "global_position", pos + Vector2(-150, -110), 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var fade = create_tween()
	fade.tween_interval(0.35)
	fade.tween_property(label, "modulate:a", 0.0, 0.4)
	
	tween.chain().tween_callback(label.queue_free)


func format_score(value: int) -> String:
	var s = str(value)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result


func animate_score_count(label: Label, target_score: int) -> void:
	if target_score <= 0:
		if is_instance_valid(label):
			label.text = "0"
		return
		
	label.scale = Vector2(0.8, 0.8)
	label.pivot_offset = Vector2(200, 25)
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	tween.tween_method(func(val):
		if is_instance_valid(label):
			var int_val = int(val)
			label.text = format_score(int_val)
			label.scale = Vector2(1.0, 1.0) + Vector2(randf_range(-0.04, 0.04), randf_range(-0.04, 0.04))
	, 0.0, float(target_score), 1.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func():
		if is_instance_valid(label):
			label.text = format_score(target_score)
			label.scale = Vector2(1.2, 1.2)
			var bounce_tween = create_tween()
			bounce_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			bounce_tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	)
