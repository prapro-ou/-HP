extends CanvasLayer
## UI 表示スクリプト（CanvasLayerを継承し、シーン ui.tscn のノードとバインド）
## - HP バー（Player・Boss）
## - ガード・パリィ・武器解析率表示
## - ボスエネルギー再配分表示
## - 警告演出・フラッシュ演出・ゲームオーバー表示

# カラー定数
const COLOR_PLAYER_HP = Color(0.2, 0.9, 0.4)
const COLOR_BOSS_HP = Color(1.0, 0.2, 0.2)
const COLOR_SHIELD_HEAT_DEFAULT = Color(0.2, 0.8, 1.0)

# フォントサイズ定数
const FONT_SIZE_HP: int = 18
const FONT_SIZE_PARRY: int = 22
const FONT_SIZE_GUARD: int = 20
const FONT_SIZE_WARNING_TITLE: int = 48
const FONT_SIZE_WARNING_SUBTITLE: int = 24

@onready var player_hp_bar: ProgressBar = $PlayerHPBar
@onready var player_hp_label: Label = $PlayerHPLabel

@onready var boss_hp_bar: ProgressBar = $BossHPBar
@onready var boss_hp_label: Label = $BossHPLabel

@onready var parry_count_label: Label = $ParryCountLabel
@onready var guard_status_label: Label = $GuardStatusLabel

# 警告・フラッシュ演出UI
@onready var warning_title: Label = $WarningTitle
@onready var warning_subtitle: Label = $WarningSubtitle
@onready var flash_overlay: ColorRect = $FlashOverlay

var shield_heat_bar: ProgressBar


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
	style_hp_bar(player_hp_bar, COLOR_PLAYER_HP)
	style_hp_bar(boss_hp_bar, COLOR_BOSS_HP)
	
	# 左上プレイヤー情報配置
	player_hp_label.position = Vector2(20, 14)
	player_hp_bar.position = Vector2(20, 32)
	player_hp_bar.custom_minimum_size = Vector2(220, 14)
	player_hp_bar.size = Vector2(220, 14)
	
	setup_label_style(player_hp_label, 12, Color.WHITE, 4)
	setup_label_style(boss_hp_label, 12, Color.GOLD, 4)
	setup_label_style(parry_count_label, 11, Color.CYAN, 4)
	setup_label_style(guard_status_label, 11, Color.GREEN, 4)
	setup_label_style(warning_title, FONT_SIZE_WARNING_TITLE, Color.RED, 10)
	setup_label_style(warning_subtitle, FONT_SIZE_WARNING_SUBTITLE, Color.GOLD, 6)
	
	parry_count_label.position = Vector2(20, 64)
	guard_status_label.position = Vector2(20, 80)
	
	# 中央ボス情報配置
	boss_hp_label.position = Vector2(260, 14)
	boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_hp_bar.position = Vector2(260, 32)
	boss_hp_bar.custom_minimum_size = Vector2(240, 14)
	boss_hp_bar.size = Vector2(240, 14)
	
	create_shield_heat_bar()
	create_analysis_matrix_ui()


func create_shield_heat_bar() -> void:
	shield_heat_bar = ProgressBar.new()
	shield_heat_bar.name = "ShieldHeatBar"
	shield_heat_bar.show_percentage = false
	shield_heat_bar.custom_minimum_size = Vector2(220, 10)
	shield_heat_bar.size = Vector2(220, 10)
	shield_heat_bar.position = Vector2(20, 48)
	add_child(shield_heat_bar)
	style_hp_bar(shield_heat_bar, COLOR_SHIELD_HEAT_DEFAULT)


var slot_cards: Array = []
var active_analysis_label: Label
var active_analysis_bar: ProgressBar

func create_analysis_matrix_ui() -> void:
	var trait_panel = PanelContainer.new()
	trait_panel.name = "TraitSlotsPanel"
	trait_panel.position = Vector2(510, 14)
	trait_panel.custom_minimum_size = Vector2(265, 86)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.9)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.25, 0.4, 0.65, 0.9)
	trait_panel.add_theme_stylebox_override("panel", sb)
	add_child(trait_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	trait_panel.add_child(vbox)
	
	# タイトル
	var title = Label.new()
	title.text = "【変異スロット (MAX 3)】"
	var t_set = LabelSettings.new()
	if PIXEL_FONT:
		t_set.font = PIXEL_FONT
	t_set.font_size = 13
	t_set.font_color = Color.CYAN
	title.label_settings = t_set
	vbox.add_child(title)
	
	# 3つのスロットボックス（横並び）
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(hbox)
	
	slot_cards.clear()
	for i in range(3):
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(80, 32)
		var c_sb = StyleBoxFlat.new()
		c_sb.bg_color = Color(0.08, 0.1, 0.14, 0.9)
		c_sb.border_width_left = 1
		c_sb.border_width_top = 1
		c_sb.border_width_right = 1
		c_sb.border_width_bottom = 1
		c_sb.border_color = Color(0.2, 0.25, 0.35, 0.8)
		card.add_theme_stylebox_override("panel", c_sb)
		
		var lbl = Label.new()
		lbl.text = "SLOT %d\n[空き]" % (i + 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var l_set = LabelSettings.new()
		if PIXEL_FONT:
			l_set.font = PIXEL_FONT
		l_set.font_size = 11
		l_set.font_color = Color(0.4, 0.45, 0.55)
		lbl.label_settings = l_set
		card.add_child(lbl)
		
		hbox.add_child(card)
		slot_cards.append({ "panel": card, "style": c_sb, "label": lbl })
		
	# 直近の解析進行バー (1行)
	var prog_row = HBoxContainer.new()
	prog_row.add_theme_constant_override("separation", 6)
	vbox.add_child(prog_row)
	
	active_analysis_label = Label.new()
	active_analysis_label.text = "解析待機中"
	active_analysis_label.custom_minimum_size = Vector2(100, 14)
	var a_set = LabelSettings.new()
	if PIXEL_FONT:
		a_set.font = PIXEL_FONT
	a_set.font_size = 11
	a_set.font_color = Color.LIGHT_GRAY
	active_analysis_label.label_settings = a_set
	prog_row.add_child(active_analysis_label)
	
	active_analysis_bar = ProgressBar.new()
	active_analysis_bar.show_percentage = false
	active_analysis_bar.custom_minimum_size = Vector2(150, 8)
	active_analysis_bar.max_value = 100
	active_analysis_bar.value = 0
	style_analysis_bar(active_analysis_bar, Color.CYAN)
	prog_row.add_child(active_analysis_bar)


func update_pattern_analysis(patterns: Dictionary, active_traits: Array = []) -> void:
	# 1. 3つのスロット表示の更新
	for i in range(3):
		var card = slot_cards[i]
		if i < active_traits.size():
			var t_key = active_traits[i]
			if patterns.has(t_key):
				var data = patterns[t_key]
				var lvl = data.get("level", 1)
				card["label"].text = "%s %s\nLv.%d" % [data.get("icon", "⚡"), data.get("name", "属性"), lvl]
				card["label"].label_settings.font_color = Color.WHITE if lvl == 1 else Color.GOLD
				card["style"].border_color = data.get("color", Color.CYAN)
				card["style"].bg_color = Color(0.1, 0.15, 0.22, 0.95)
		else:
			card["label"].text = "SLOT %d\n[空き]" % (i + 1)
			card["label"].label_settings.font_color = Color(0.4, 0.45, 0.55)
			card["style"].border_color = Color(0.2, 0.25, 0.35, 0.8)
			card["style"].bg_color = Color(0.06, 0.08, 0.1, 0.85)
			
	# 2. 現在進行中の解析（直近で最も進捗の高い、未MAXパターン）の表示
	var latest_pattern = null
	var highest_progress = 0.0
	for key in patterns.keys():
		var data = patterns[key]
		var prog = data.get("progress", 0.0)
		var lvl = data.get("level", 0)
		var max_lvl = data.get("max_level", 2)
		if lvl < max_lvl and prog > highest_progress:
			highest_progress = prog
			latest_pattern = data
			
	if latest_pattern and highest_progress > 0:
		var name_str = latest_pattern.get("name", "未知")
		active_analysis_label.text = "解析中: %s" % name_str
		active_analysis_label.label_settings.font_color = latest_pattern.get("color", Color.CYAN)
		active_analysis_bar.value = highest_progress
		style_analysis_bar(active_analysis_bar, latest_pattern.get("color", Color.CYAN))
	else:
		active_analysis_label.text = "解析: パリィで吸収"
		active_analysis_label.label_settings.font_color = Color.GRAY
		active_analysis_bar.value = 0


const PIXEL_FONT: Font = preload("res://game/assets/fonts/DotGothic16-Regular.ttf")

func style_hp_bar(bar: ProgressBar, color: Color) -> void:
	# ドット絵風の角張ったピクセルフレーム (角丸ゼロ・2px枠線)
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.04, 0.05, 0.08, 0.95)
	sb_bg.border_width_left = 2
	sb_bg.border_width_top = 2
	sb_bg.border_width_right = 2
	sb_bg.border_width_bottom = 2
	sb_bg.border_color = Color(0.25, 0.35, 0.5, 1.0)
	sb_bg.corner_radius_top_left = 0
	sb_bg.corner_radius_top_right = 0
	sb_bg.corner_radius_bottom_left = 0
	sb_bg.corner_radius_bottom_right = 0
	
	var sb_fg = StyleBoxFlat.new()
	sb_fg.bg_color = color
	sb_fg.corner_radius_top_left = 0
	sb_fg.corner_radius_top_right = 0
	sb_fg.corner_radius_bottom_left = 0
	sb_fg.corner_radius_bottom_right = 0
	
	bar.add_theme_stylebox_override("background", sb_bg)
	bar.add_theme_stylebox_override("fill", sb_fg)


func style_analysis_bar(bar: ProgressBar, color: Color) -> void:
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.03, 0.04, 0.06, 0.95)
	sb_bg.border_width_left = 2
	sb_bg.border_width_top = 2
	sb_bg.border_width_right = 2
	sb_bg.border_width_bottom = 2
	sb_bg.border_color = Color(0.2, 0.25, 0.35, 0.9)
	sb_bg.corner_radius_top_left = 0
	sb_bg.corner_radius_top_right = 0
	sb_bg.corner_radius_bottom_left = 0
	sb_bg.corner_radius_bottom_right = 0
	
	var sb_fg = StyleBoxFlat.new()
	sb_fg.bg_color = color
	sb_fg.corner_radius_top_left = 0
	sb_fg.corner_radius_top_right = 0
	sb_fg.corner_radius_bottom_left = 0
	sb_fg.corner_radius_bottom_right = 0
	
	bar.add_theme_stylebox_override("background", sb_bg)
	bar.add_theme_stylebox_override("fill", sb_fg)


func setup_label_style(label: Label, size: int, color: Color, outline: int = 4) -> void:
	var settings = LabelSettings.new()
	if PIXEL_FONT:
		settings.font = PIXEL_FONT
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = outline
	settings.outline_color = Color.BLACK
	label.label_settings = settings


func update_player_hp(current: int, max_hp_val: int) -> void:
	player_hp_bar.max_value = max_hp_val
	player_hp_bar.value = current
	player_hp_label.text = "自機 HP: %d / %d" % [current, max_hp_val]


func update_boss_hp(current: int, max_hp_val: int) -> void:
	boss_hp_bar.visible = true
	boss_hp_label.visible = true
	boss_hp_bar.max_value = max_hp_val
	boss_hp_bar.value = current
	boss_hp_label.text = "ボス HP: %d / %d" % [current, max_hp_val]


func hide_boss_hp() -> void:
	boss_hp_bar.visible = false
	boss_hp_label.visible = false


func update_parry_count(count: int) -> void:
	parry_count_label.text = "パリィ: %d 回" % count


func update_guard_status(_cooldown: float, _is_guarding: bool) -> void:
	pass


func update_guard_heat(heat: float, max_heat: float, is_overheated: bool, overheat_timer: float, is_guarding: bool) -> void:
	if is_instance_valid(shield_heat_bar):
		shield_heat_bar.max_value = max_heat
		shield_heat_bar.value = heat
		
		var fg_style = shield_heat_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fg_style:
			if is_overheated:
				var flash = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
				fg_style.bg_color = Color(1.0, 0.1, 0.1).lerp(Color(0.4, 0.0, 0.0), flash)
			elif is_guarding:
				fg_style.bg_color = Color(0.2, 1.0, 1.0)
			else:
				var pct = (heat / max_heat)
				if pct > 0.7:
					fg_style.bg_color = Color(1.0, 0.45, 0.1)
				elif pct > 0.35:
					fg_style.bg_color = Color(1.0, 0.85, 0.2)
				else:
					fg_style.bg_color = COLOR_SHIELD_HEAT_DEFAULT

	if is_overheated:
		guard_status_label.text = "⚠️ OVERHEAT! 冷却中 (%.1fs)" % overheat_timer
		guard_status_label.label_settings.font_color = Color.RED
	elif is_guarding:
		guard_status_label.text = "シールド: 展開中！"
		guard_status_label.label_settings.font_color = Color.CYAN
	else:
		guard_status_label.text = "シールドヒート [Space]"
		guard_status_label.label_settings.font_color = Color.LIGHT_GRAY





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
	panel.process_mode = PROCESS_MODE_ALWAYS
	add_child(panel)
	
	var tween = create_tween()
	if tween.has_method("set_pause_mode"):
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "color", Color(0.05, 0.05, 0.08, 0.85), 0.6)
	
	var container = VBoxContainer.new()
	container.anchor_left = 0.0
	container.anchor_right = 1.0
	container.anchor_top = 0.0
	container.anchor_bottom = 1.0
	container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container.grow_vertical = Control.GROW_DIRECTION_BOTH
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 14)
	panel.add_child(container)
	
	var result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var settings = LabelSettings.new()
	if PIXEL_FONT:
		settings.font = PIXEL_FONT
	settings.font_size = 48
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
	if PIXEL_FONT:
		stats_settings.font = PIXEL_FONT
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
			
	stats_label.text = "総パリィ数: %d 回\n技術回収: 100%%" % parries
	container.add_child(stats_label)
	
	if result == "VICTORY":
		var spacer_score = Control.new()
		spacer_score.custom_minimum_size = Vector2(0, 15)
		container.add_child(spacer_score)
		
		var score_title_label = Label.new()
		score_title_label.text = "最終スコア"
		score_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var score_title_settings = LabelSettings.new()
		if PIXEL_FONT:
			score_title_settings.font = PIXEL_FONT
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
		if PIXEL_FONT:
			score_val_settings.font = PIXEL_FONT
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
	style_normal.bg_color = Color(0.06, 0.07, 0.1, 0.95)
	style_normal.border_width_left = 3
	style_normal.border_width_top = 3
	style_normal.border_width_right = 3
	style_normal.border_width_bottom = 3
	style_normal.border_color = theme_color
	style_normal.corner_radius_top_left = 0
	style_normal.corner_radius_top_right = 0
	style_normal.corner_radius_bottom_left = 0
	style_normal.corner_radius_bottom_right = 0
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = theme_color
	
	if result == "VICTORY":
		var next_btn = Button.new()
		next_btn.text = "次のステージへ"
		next_btn.custom_minimum_size = Vector2(280, 56)
		next_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		next_btn.add_theme_font_size_override("font_size", 22)
		if PIXEL_FONT:
			next_btn.add_theme_font_override("font", PIXEL_FONT)
		
		next_btn.add_theme_color_override("font_color", Color.WHITE)
		next_btn.add_theme_color_override("font_hover_color", Color.BLACK)
		next_btn.add_theme_color_override("font_pressed_color", Color.BLACK)
		next_btn.add_theme_stylebox_override("normal", style_normal)
		next_btn.add_theme_stylebox_override("hover", style_hover)
		next_btn.add_theme_stylebox_override("pressed", style_hover)
		next_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		container.add_child(next_btn)
		
		next_btn.pressed.connect(func():
			get_tree().paused = false
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
	if PIXEL_FONT:
		retry_btn.add_theme_font_override("font", PIXEL_FONT)
	
	retry_btn.add_theme_color_override("font_color", Color.WHITE)
	retry_btn.add_theme_color_override("font_hover_color", Color.BLACK)
	retry_btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	retry_btn.add_theme_stylebox_override("normal", style_normal)
	retry_btn.add_theme_stylebox_override("hover", style_hover)
	retry_btn.add_theme_stylebox_override("pressed", style_hover)
	retry_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	container.add_child(retry_btn)
	
	retry_btn.pressed.connect(func():
		get_tree().paused = false
		if game_manager and game_manager.has_method("restart"):
			game_manager.restart()
	)
	
	var menu_btn = Button.new()
	menu_btn.text = "メニューへ"
	menu_btn.custom_minimum_size = Vector2(280, 56)
	menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_btn.add_theme_font_size_override("font_size", 22)
	if PIXEL_FONT:
		menu_btn.add_theme_font_override("font", PIXEL_FONT)
	
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
		get_tree().paused = false
		get_tree().change_scene_to_file("res://game/core/main_menu.tscn")
	)
	
	get_tree().paused = true


func spawn_damage_popup(pos: Vector2, amount: int, is_finish: bool = false) -> void:
	var label = Label.new()
	label.text = str(amount)
	
	var settings = LabelSettings.new()
	if PIXEL_FONT:
		settings.font = PIXEL_FONT
	if is_finish:
		settings.font_size = randi_range(64, 80)
		settings.font_color = Color(1.0, 0.35, 0.1)
		settings.outline_size = 8
		settings.outline_color = Color.BLACK
	else:
		settings.font_size = randi_range(24, 32)
		if amount > 15:
			settings.font_color = Color(1.0, 0.9, 0.2)
			settings.font_size = randi_range(32, 40)
		else:
			settings.font_color = Color.WHITE
		settings.outline_size = 4
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
	var label = Label.new()
	label.text = text
	
	var settings = LabelSettings.new()
	settings.font_size = 88
	settings.font_color = Color(1.0, 0.85, 0.0)
	settings.outline_size = 16
	settings.outline_color = Color(0.1, 0.0, 0.0, 1.0)
	
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.pivot_offset = Vector2(150, 45)
	label.global_position = pos + Vector2(-150, -45)
	
	add_child(label)
	
	label.scale = Vector2(0.1, 0.1)
	var tween = create_tween().set_parallel(true)
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
