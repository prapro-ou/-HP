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
		return
		
	var panel = ColorRect.new()
	panel.name = "GameOverPanel"
	panel.color = Color(0.05, 0.05, 0.08, 0.0)
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.process_mode = PROCESS_MODE_ALWAYS # 一時停止中もこのパネルは動作する
	add_child(panel)
	
	# ゲーム全体を一時停止する
	get_tree().paused = true
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # 一時停止中でもアニメーションする設定
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
	var game_manager = get_node_or_null("../GameManager")
	if game_manager:
		parries = game_manager.parry_count
	stats_label.text = "TOTAL PARRIES EXTRACTED: %d\nTECHNOLOGY HARVEST: 100%%" % parries
	container.add_child(stats_label)
	
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
	
	container.add_child(retry_btn)
	
	retry_btn.pressed.connect(func():
		get_tree().paused = false # リスタート前に一時停止を解除
		if game_manager and game_manager.has_method("restart"):
			game_manager.restart()
	)

