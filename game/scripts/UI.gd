extends Control
## UI 表示スクリプト
## - HP バー（Player・Boss）を ProgressBar でスタイリッシュに表現
## - ガード、パリィ、および武器解析率（スロット状況）の表示
## - ボスのエネルギー再配分比率の表示
## - 警告演出・フラッシュ演出・ゲームオーバー表示

@onready var player_hp_bar: ProgressBar = ProgressBar.new()
@onready var player_hp_label: Label = Label.new()

@onready var boss_hp_bar: ProgressBar = ProgressBar.new()
@onready var boss_hp_label: Label = Label.new()

@onready var parry_count_label: Label = Label.new()
@onready var guard_status_label: Label = Label.new()

# 武器解析UI
var slot_beam_label: Label = Label.new()
var slot_beam_bar: ProgressBar = ProgressBar.new()
var slot_missile_label: Label = Label.new()
var slot_missile_bar: ProgressBar = ProgressBar.new()

# ボスエネルギー比率UI
var boss_energy_label: Label = Label.new()

# 警告・フラッシュ演出UI
var warning_title: Label = Label.new()
var warning_subtitle: Label = Label.new()
var flash_overlay: ColorRect = ColorRect.new()


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	var screen_w = get_viewport_rect().size.x
	var screen_h = get_viewport_rect().size.y
	
	# 1. 画面フラッシュ用オーバーレイ
	flash_overlay.color = Color(1, 1, 1, 0)
	flash_overlay.anchor_right = 1.0
	flash_overlay.anchor_bottom = 1.0
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_overlay)
	
	# 2. プレイヤーHP表示
	setup_hp_bar(player_hp_bar, player_hp_label, Vector2(20, 20), Vector2(250, 20), Color(0.2, 0.9, 0.4))
	player_hp_label.text = "PLAYER VITAL"
	
	# 3. ボスHP表示（初期は非表示）
	setup_hp_bar(boss_hp_bar, boss_hp_label, Vector2(screen_w - 370, 20), Vector2(350, 24), Color(1.0, 0.2, 0.2))
	boss_hp_label.text = "ANCIENT DEFENDER"
	boss_hp_bar.visible = false
	boss_hp_label.visible = false
	
	# 4. パリィカウント
	parry_count_label.text = "EXTRACTED PARRIES: 0"
	parry_count_label.position = Vector2(20, 80)
	setup_label_style(parry_count_label, 14, Color.CYAN)
	add_child(parry_count_label)
	
	# 5. ガードステータス
	guard_status_label.text = "SHIELD SYSTEM: READY"
	guard_status_label.position = Vector2(20, 105)
	setup_label_style(guard_status_label, 14, Color.GREEN)
	add_child(guard_status_label)
	
	# 6. 武器解析スロットUI
	setup_analysis_slot("BEAM SYSTEM", slot_beam_label, slot_beam_bar, Vector2(20, screen_h - 90), Color.CYAN)
	setup_analysis_slot("MISSILE SYSTEM", slot_missile_label, slot_missile_bar, Vector2(20, screen_h - 50), Color(0.8, 0.4, 1.0))
	
	# 7. ボスエネルギーUI
	boss_energy_label.text = ""
	boss_energy_label.position = Vector2(screen_w - 370, 55)
	setup_label_style(boss_energy_label, 13, Color.GOLD)
	add_child(boss_energy_label)
	
	# 8. 警告メッセージ用
	warning_title.anchor_left = 0.5
	warning_title.anchor_right = 0.5
	warning_title.anchor_top = 0.4
	warning_title.anchor_bottom = 0.4
	warning_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	warning_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_label_style(warning_title, 36, Color.RED)
	warning_title.hide()
	add_child(warning_title)
	
	warning_subtitle.anchor_left = 0.5
	warning_subtitle.anchor_right = 0.5
	warning_subtitle.anchor_top = 0.48
	warning_subtitle.anchor_bottom = 0.48
	warning_subtitle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	warning_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_label_style(warning_subtitle, 16, Color.GOLD)
	warning_subtitle.hide()
	add_child(warning_subtitle)


func setup_hp_bar(bar: ProgressBar, label: Label, pos: Vector2, size: Vector2, color: Color) -> void:
	bar.position = pos + Vector2(0, 20)
	bar.size = size
	bar.show_percentage = false
	
	# スタイリング
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
	
	label.position = pos
	setup_label_style(label, 12, Color.WHITE)
	
	add_child(bar)
	add_child(label)


func setup_analysis_slot(title: String, label: Label, bar: ProgressBar, pos: Vector2, color: Color) -> void:
	label.text = title + " [0%]"
	label.position = pos
	setup_label_style(label, 12, Color.LIGHT_GRAY)
	
	bar.position = pos + Vector2(160, 2)
	bar.size = Vector2(150, 10)
	bar.show_percentage = false
	
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
	
	add_child(label)
	add_child(bar)


func setup_label_style(label: Label, size: int, color: Color) -> void:
	var settings = LabelSettings.new()
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = 4
	settings.outline_color = Color.BLACK
	label.label_settings = settings


func update_player_hp(current: int, max_hp: int) -> void:
	player_hp_bar.max_value = max_hp
	player_hp_bar.value = current
	player_hp_label.text = "PLAYER VITAL: %d / %d" % [current, max_hp]


func update_boss_hp(current: int, max_hp: int) -> void:
	boss_hp_bar.visible = true
	boss_hp_label.visible = true
	boss_hp_bar.max_value = max_hp
	boss_hp_bar.value = current
	boss_hp_label.text = "ANCIENT DEFENDER: %d / %d" % [current, max_hp]


func hide_boss_hp() -> void:
	boss_hp_bar.visible = false
	boss_hp_label.visible = false


func update_parry_count(count: int) -> void:
	parry_count_label.text = "EXTRACTED PARRIES: %d" % count


func update_guard_status(cooldown: float, is_guarding: bool) -> void:
	if is_guarding:
		guard_status_label.text = "SHIELD SYSTEM: ACTIVE!"
		guard_status_label.label_settings.font_color = Color.CYAN
	elif cooldown > 0.0:
		guard_status_label.text = "SHIELD SYSTEM: COOLDOWN (%.1fs)" % cooldown
		guard_status_label.label_settings.font_color = Color.ORANGE_RED
	else:
		guard_status_label.text = "SHIELD SYSTEM: READY (SPACE)"
		guard_status_label.label_settings.font_color = Color.GREEN


func update_analysis_progress(beam_progress: float, beam_ready: bool, missile_progress: float, missile_ready: bool, active_weapon: String) -> void:
	slot_beam_bar.value = beam_progress
	if beam_ready:
		if active_weapon == "beam":
			slot_beam_label.text = "SLOT 1: BEAM [ACTIVE]"
			slot_beam_label.label_settings.font_color = Color.CYAN
		else:
			slot_beam_label.text = "SLOT 1: BEAM [Z/Shift to Swap]"
			slot_beam_label.label_settings.font_color = Color(0.4, 0.7, 0.7)
	else:
		slot_beam_label.text = "SLOT 1: BEAM ANALYZING [%d%%]" % int(beam_progress)
		slot_beam_label.label_settings.font_color = Color.LIGHT_GRAY
		
	slot_missile_bar.value = missile_progress
	if missile_ready:
		if active_weapon == "missile":
			slot_missile_label.text = "SLOT 2: MISSILE [ACTIVE]"
			slot_missile_label.label_settings.font_color = Color(0.8, 0.4, 1.0)
		else:
			slot_missile_label.text = "SLOT 2: MISSILE [Z/Shift to Swap]"
			slot_missile_label.label_settings.font_color = Color(0.6, 0.3, 0.7)
	else:
		slot_missile_label.text = "SLOT 2: MISSILE ANALYZING [%d%%]" % int(missile_progress)
		slot_missile_label.label_settings.font_color = Color.LIGHT_GRAY


func update_boss_energy(laser: float, missile: float, core: float) -> void:
	boss_energy_label.text = "ENERGY REALLOCATION:\nCORE: %d%% | LASER: %d%% | MISSILE: %d%%" % [int(core), int(laser), int(missile)]


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
	panel.process_mode = PROCESS_MODE_ALWAYS # 一時停止中もこのパネルは動作する
	add_child(panel)
	
	var tween = create_tween()
	# UIノードがALWAYSなので自動で動くが、念のため安全にポーズ中の動作を設定
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
		result_label.text = "MISSION ACCOMPLISHED"
		settings.font_color = Color.CYAN
	else:
		result_label.text = "SYSTEM DEFEATED"
		settings.font_color = Color.ORANGE_RED
		
	result_label.label_settings = settings
	container.add_child(result_label)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	container.add_child(spacer)
	
	var stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stats_settings = LabelSettings.new()
	stats_settings.font_size = 18
	stats_settings.font_color = Color(0.8, 0.9, 1.0, 0.8)
	stats_label.label_settings = stats_settings
	
	var parries = 0
	var score = 0
	var game_manager = get_node_or_null("../GameManager")
	if game_manager:
		parries = game_manager.parry_count
		if "total_damage_score" in game_manager:
			score = game_manager.total_damage_score
			
	# %d, %% などのフォーマットを避け、文字列結合にすることでエラーを完全に回避
	stats_label.text = "TOTAL PARRIES EXTRACTED: " + str(parries) + "\nTECHNOLOGY HARVEST: 100%"
	container.add_child(stats_label)
	
	# スコア表示（大きく、派手に）
	if result == "VICTORY":
		var spacer_score = Control.new()
		spacer_score.custom_minimum_size = Vector2(0, 15)
		container.add_child(spacer_score)
		
		var score_title_label = Label.new()
		score_title_label.text = "FINAL DAMAGE SCORE"
		score_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var score_title_settings = LabelSettings.new()
		score_title_settings.font_size = 16
		score_title_settings.font_color = Color.GOLD
		score_title_settings.outline_size = 4
		score_title_settings.outline_color = Color.BLACK
		score_title_label.label_settings = score_title_settings
		container.add_child(score_title_label)
		
		var score_val_label = Label.new()
		score_val_label.text = format_score(score)
		score_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var score_val_settings = LabelSettings.new()
		score_val_settings.font_size = 46 # 超巨大
		score_val_settings.font_color = Color(1.0, 0.85, 0.1) # ゴールドイエロー
		score_val_settings.outline_size = 10
		score_val_settings.outline_color = Color(0.1, 0.1, 0.3)
		score_val_label.label_settings = score_val_settings
		container.add_child(score_val_label)
		
		animate_score_count(score_val_label, score)
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	container.add_child(spacer2)
	
	var retry_btn = Button.new()
	retry_btn.text = "RESTART INTERFACE"
	retry_btn.custom_minimum_size = Vector2(250, 50)
	retry_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
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
	
	retry_btn.add_theme_color_override("font_color", Color.WHITE)
	retry_btn.add_theme_color_override("font_hover_color", Color.BLACK)
	retry_btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	retry_btn.add_theme_stylebox_override("normal", style_normal)
	retry_btn.add_theme_stylebox_override("hover", style_hover)
	retry_btn.add_theme_stylebox_override("pressed", style_hover)
	retry_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	if result == "VICTORY" and get_tree().current_scene.scene_file_path.ends_with("main.tscn"):
		var next_btn = Button.new()
		next_btn.text = "PROCEED TO STAGE 2"
		next_btn.custom_minimum_size = Vector2(250, 50)
		next_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
		var next_style_normal = StyleBoxFlat.new()
		next_style_normal.bg_color = Color(0.05, 0.15, 0.1, 1.0)
		next_style_normal.border_width_left = 2
		next_style_normal.border_width_top = 2
		next_style_normal.border_width_right = 2
		next_style_normal.border_width_bottom = 2
		next_style_normal.border_color = Color.GREEN_YELLOW
		next_style_normal.corner_radius_top_left = 4
		next_style_normal.corner_radius_top_right = 4
		next_style_normal.corner_radius_bottom_left = 4
		next_style_normal.corner_radius_bottom_right = 4
		
		var next_style_hover = next_style_normal.duplicate()
		next_style_hover.bg_color = Color.GREEN_YELLOW
		
		next_btn.add_theme_color_override("font_color", Color.WHITE)
		next_btn.add_theme_color_override("font_hover_color", Color.BLACK)
		next_btn.add_theme_color_override("font_pressed_color", Color.BLACK)
		next_btn.add_theme_stylebox_override("normal", next_style_normal)
		next_btn.add_theme_stylebox_override("hover", next_style_hover)
		next_btn.add_theme_stylebox_override("pressed", next_style_hover)
		next_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		container.add_child(next_btn)
		
		next_btn.pressed.connect(func():
			get_tree().paused = false
			get_tree().change_scene_to_file("res://game/scenes/stage2.tscn")
		)
		
		var btn_spacer = Control.new()
		btn_spacer.custom_minimum_size = Vector2(0, 10)
		container.add_child(btn_spacer)

	container.add_child(retry_btn)
	
	retry_btn.pressed.connect(func():
		get_tree().paused = false # リスタート前に一時停止を解除
		if game_manager and game_manager.has_method("restart"):
			game_manager.restart()
	)
	
	# UIの組み立てが完了してから安全にポーズする
	get_tree().paused = true


func spawn_damage_popup(pos: Vector2, amount: int, is_finish: bool = false) -> void:
	var label = Label.new()
	label.text = str(amount)
	
	var settings = LabelSettings.new()
	if is_finish:
		# トドメ演出時は超巨大でゴールド・オレンジ・赤でド派手に
		settings.font_size = randi_range(56, 76)
		settings.font_color = Color(1.0, randf_range(0.2, 0.6), 0.1) # ゴールド〜ビブラントオレンジ
		settings.outline_size = 12
		settings.outline_color = Color.BLACK
	else:
		# 通常時も大きめにする
		settings.font_size = randi_range(24, 32)
		if amount > 15:
			settings.font_color = Color(1.0, 0.9, 0.2) # 明るいイエロー
			settings.font_size = randi_range(30, 36)
		else:
			settings.font_color = Color.WHITE
		settings.outline_size = 6
		settings.outline_color = Color.BLACK
		
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.pivot_offset = Vector2(100, 30) # サイズが大きくなったのでピボットも調整
	
	# 位置を少しばらけさせる
	label.global_position = pos + Vector2(randf_range(-60, 60), randf_range(-40, 20))
	add_child(label)
	
	# アニメーション
	label.scale = Vector2(0.2, 0.2)
	var tween = create_tween()
	tween.set_parallel(true)
	# 飛び出すようなスケールアップ
	tween.tween_property(label, "scale", Vector2(1.2, 1.2) if is_finish else Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 上昇とランダムな左右への跳ね
	var target_pos = label.global_position + Vector2(randf_range(-70, 70), -120)
	tween.tween_property(label, "global_position", target_pos, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 遅れてフェードアウト
	var fade_tween = create_tween()
	fade_tween.tween_interval(0.5)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.4)
	
	tween.chain().tween_callback(label.queue_free)


func format_score(value: int) -> String:
	# 3桁区切りの文字列に変換
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
	# スコアが0以下の場合はアニメーションをスキップして直接0を表示
	if target_score <= 0:
		if is_instance_valid(label):
			label.text = "0"
		return
		
	label.scale = Vector2(0.8, 0.8)
	label.pivot_offset = Vector2(200, 25)
	
	# Tweenで数値をカウントアップする
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # 一時停止中も動くように
	
	# 型アノテーション(val: float)を削除して実行時エラーを防ぐ
	tween.tween_method(func(val):
		if is_instance_valid(label):
			var int_val = int(val)
			label.text = format_score(int_val)
			# カウントアップ中に少しピクピク揺らすと派手になる
			label.scale = Vector2(1.0, 1.0) + Vector2(randf_range(-0.04, 0.04), randf_range(-0.04, 0.04))
	, 0.0, float(target_score), 1.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	# 最後にピタッと止まり、少しバウンドして強調する
	tween.chain().tween_callback(func():
		if is_instance_valid(label):
			label.text = format_score(target_score)
			label.scale = Vector2(1.2, 1.2)
			var bounce_tween = create_tween()
			bounce_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			bounce_tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	)

