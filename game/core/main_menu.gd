extends Control

# Background stars definition
class Star:
	var pos: Vector2
	var speed: float
	var size: float
	var color: Color

var stars: Array[Star] = []
const NUM_STARS = 60

# UI Nodes reference
var background_color: ColorRect
var main_margin: MarginContainer
var main_vbox: VBoxContainer

# Titles
var title_label: Label
var subtitle_label: Label

# Menu, Settings and Confirm screens
var menu_container: VBoxContainer
var settings_container: PanelContainer
var confirm_dialog: PanelContainer
var tutorial_dialog: PanelContainer

# Buttons
var play_start_btn: Button
var settings_btn: Button

# Settings UI inputs
var mode_option: OptionButton
var scale_option: OptionButton
var aspect_option: OptionButton
var vsync_check: CheckButton
var shake_check: CheckButton
var master_slider: HSlider
var master_lbl: Label
var bgm_slider: HSlider
var bgm_lbl: Label
var sfx_slider: HSlider
var sfx_lbl: Label
var reset_btn: Button
var back_btn: Button

# Title animation variables
var time_passed: float = 0.0

func _ready() -> void:
	# Ensure the global settings are loaded
	Global.load_settings()
	Global.check_save_game()
	
	# Load save data to sync status
	var save_data = Global.load_game_data()
	
	# Layout design
	setup_layout()
	init_starfield()
	
	# Load settings data into UI
	sync_settings_to_ui()
	
	# Animation entry
	animate_menu_entry()

func _process(delta: float) -> void:
	update_starfield(delta)
	animate_title(delta)

# ----------------- UI Creation & Styling -----------------

func setup_layout() -> void:
	# 1. Base dark background
	background_color = ColorRect.new()
	background_color.color = Color(0.04, 0.04, 0.07, 1.0)
	background_color.anchor_right = 1.0
	background_color.anchor_bottom = 1.0
	background_color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_color)
	
	# 2. Main Margin Container
	main_margin = MarginContainer.new()
	main_margin.anchor_right = 1.0
	main_margin.anchor_bottom = 1.0
	main_margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_margin.grow_vertical = Control.GROW_DIRECTION_BOTH
	main_margin.add_theme_constant_override("margin_left", 50)
	main_margin.add_theme_constant_override("margin_top", 120)
	main_margin.add_theme_constant_override("margin_right", 50)
	main_margin.add_theme_constant_override("margin_bottom", 80)
	add_child(main_margin)
	
	# 3. Main vertical stack
	main_vbox = VBoxContainer.new()
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_margin.add_child(main_vbox)
	
	# 4. Sci-Fi Title
	title_label = Label.new()
	title_label.text = "カウンターコア"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_set = LabelSettings.new()
	title_set.font_size = 64
	title_set.font_color = Color.CYAN
	title_set.outline_size = 14
	title_set.outline_color = Color(0.05, 0.05, 0.1)
	title_label.label_settings = title_set
	title_label.pivot_offset = Vector2(350, 60)
	main_vbox.add_child(title_label)
	
	# Subtitle
	subtitle_label = Label.new()
	subtitle_label.text = "パリィで解析・カウンターで撃破"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub_set = LabelSettings.new()
	sub_set.font_size = 22
	sub_set.font_color = Color.GOLD
	sub_set.outline_size = 6
	sub_set.outline_color = Color.BLACK
	subtitle_label.label_settings = sub_set
	main_vbox.add_child(subtitle_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 80)
	main_vbox.add_child(spacer)
	
	# 5. Main Menu Container
	setup_menu_container()
	
	# 6. Settings Container (Hidden initially)
	setup_settings_container()
	
	# 7. Custom confirmation dialog (Hidden initially)
	setup_confirm_dialog()

	# 8. Tutorial confirmation dialog (Hidden initially)
	setup_tutorial_confirm_dialog()

func setup_menu_container() -> void:
	menu_container = VBoxContainer.new()
	menu_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_container.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_container.theme_type_variation = "VBoxContainer"
	menu_container.add_theme_constant_override("separation", 24)
	main_vbox.add_child(menu_container)
	
	# Play Start Button
	play_start_btn = Button.new()
	play_start_btn.text = "出撃開始"
	play_start_btn.custom_minimum_size = Vector2(340, 75)
	play_start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_start_btn.add_theme_font_size_override("font_size", 28)
	menu_container.add_child(play_start_btn)
	style_button(play_start_btn, Color.CYAN, Color(0.3, 0.9, 1.0))
	add_button_animations(play_start_btn)
	
	# Settings Button
	settings_btn = Button.new()
	settings_btn.text = "設定"
	settings_btn.custom_minimum_size = Vector2(340, 75)
	settings_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	settings_btn.add_theme_font_size_override("font_size", 28)
	menu_container.add_child(settings_btn)
	style_button(settings_btn, Color(0.8, 0.4, 1.0), Color(0.9, 0.6, 1.0))
	add_button_animations(settings_btn)
	
	# Setup button signals
	play_start_btn.pressed.connect(_on_play_start_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)

func setup_settings_container() -> void:
	settings_container = PanelContainer.new()
	settings_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	settings_container.custom_minimum_size = Vector2(480, 700)
	settings_container.hide()
	main_vbox.add_child(settings_container)
	
	# Translucent glassmorphic panel style
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.8, 0.4, 1.0, 0.8) # Purple sci-fi theme
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.shadow_color = Color(0.8, 0.4, 1.0, 0.3)
	sb.shadow_size = 15
	settings_container.add_theme_stylebox_override("panel", sb)
	
	var margin_inner = MarginContainer.new()
	margin_inner.add_theme_constant_override("margin_left", 25)
	margin_inner.add_theme_constant_override("margin_top", 25)
	margin_inner.add_theme_constant_override("margin_right", 25)
	margin_inner.add_theme_constant_override("margin_bottom", 25)
	settings_container.add_child(margin_inner)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 22)
	margin_inner.add_child(content)
	
	# Title
	var settings_title = Label.new()
	settings_title.text = "設定"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_set = LabelSettings.new()
	title_set.font_size = 28
	title_set.font_color = Color(0.9, 0.6, 1.0)
	title_set.outline_size = 6
	title_set.outline_color = Color.BLACK
	settings_title.label_settings = title_set
	content.add_child(settings_title)
	
	# Scroll area for clean overflow
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	
	var scroll_content = VBoxContainer.new()
	scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_content.add_theme_constant_override("separation", 18)
	scroll.add_child(scroll_content)
	
	# --- SECTION 1: DISPLAY ---
	var d_title = Label.new()
	d_title.text = "画面設定"
	var sec_set = LabelSettings.new()
	sec_set.font_size = 20
	sec_set.font_color = Color.CYAN
	d_title.label_settings = sec_set
	scroll_content.add_child(d_title)
	
	var grid_display = GridContainer.new()
	grid_display.columns = 2
	grid_display.add_theme_constant_override("h_separation", 15)
	grid_display.add_theme_constant_override("v_separation", 12)
	scroll_content.add_child(grid_display)
	
	# Mode
	grid_display.add_child(create_label("画面モード:"))
	mode_option = OptionButton.new()
	mode_option.add_item("ウィンドウ", 0)
	mode_option.add_item("フルスクリーン", 1)
	mode_option.add_item("ボーダレス", 2)
	mode_option.custom_minimum_size = Vector2(200, 36)
	mode_option.add_theme_font_size_override("font_size", 16)
	grid_display.add_child(mode_option)
	
	# Resolution / Scale (Vertical formats only)
	grid_display.add_child(create_label("画面サイズ:"))
	scale_option = OptionButton.new()
	scale_option.add_item("400x600 (0.50x)", 0)
	scale_option.add_item("600x900 (0.75x)", 1)
	scale_option.add_item("800x1200 (1.00x)", 2)
	scale_option.add_item("1000x1500 (1.25x)", 3)
	scale_option.custom_minimum_size = Vector2(200, 36)
	scale_option.add_theme_font_size_override("font_size", 16)
	grid_display.add_child(scale_option)
	
	# Aspect Ratio
	grid_display.add_child(create_label("縦横比:"))
	aspect_option = OptionButton.new()
	aspect_option.add_item("縦長 2:3 (標準)", 0)
	aspect_option.add_item("縦長 3:4", 1)
	aspect_option.add_item("縦長 9:16 (極細)", 2)
	aspect_option.custom_minimum_size = Vector2(200, 36)
	aspect_option.add_theme_font_size_override("font_size", 16)
	grid_display.add_child(aspect_option)
	
	# VSync
	grid_display.add_child(create_label("垂直同期:"))
	vsync_check = CheckButton.new()
	vsync_check.text = ""
	grid_display.add_child(vsync_check)
	
	# Shake
	grid_display.add_child(create_label("画面振動:"))
	shake_check = CheckButton.new()
	shake_check.text = ""
	grid_display.add_child(shake_check)
	
	# --- SECTION 2: AUDIO ---
	var a_title = Label.new()
	a_title.text = "音量設定"
	a_title.label_settings = sec_set
	scroll_content.add_child(a_title)
	
	var grid_audio = GridContainer.new()
	grid_audio.columns = 2
	grid_audio.add_theme_constant_override("h_separation", 15)
	grid_audio.add_theme_constant_override("v_separation", 12)
	scroll_content.add_child(grid_audio)
	
	# Master
	grid_audio.add_child(create_label("主音量:"))
	var master_box = HBoxContainer.new()
	master_slider = HSlider.new()
	master_slider.min_value = 0
	master_slider.max_value = 100
	master_slider.value = 80
	master_slider.custom_minimum_size = Vector2(140, 24)
	master_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	master_lbl = Label.new()
	master_lbl.text = "80%"
	master_lbl.custom_minimum_size = Vector2(40, 0)
	var master_lset = LabelSettings.new()
	master_lset.font_size = 16
	master_lset.font_color = Color.WHITE
	master_lbl.label_settings = master_lset
	master_box.add_child(master_slider)
	master_box.add_child(master_lbl)
	grid_audio.add_child(master_box)
	
	# BGM
	grid_audio.add_child(create_label("BGM音量:"))
	var bgm_box = HBoxContainer.new()
	bgm_slider = HSlider.new()
	bgm_slider.min_value = 0
	bgm_slider.max_value = 100
	bgm_slider.value = 80
	bgm_slider.custom_minimum_size = Vector2(140, 24)
	bgm_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bgm_lbl = Label.new()
	bgm_lbl.text = "80%"
	bgm_lbl.custom_minimum_size = Vector2(40, 0)
	bgm_lbl.label_settings = master_lset
	bgm_box.add_child(bgm_slider)
	bgm_box.add_child(bgm_lbl)
	grid_audio.add_child(bgm_box)
	
	# SFX
	grid_audio.add_child(create_label("効果音:"))
	var sfx_box = HBoxContainer.new()
	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0
	sfx_slider.max_value = 100
	sfx_slider.value = 80
	sfx_slider.custom_minimum_size = Vector2(140, 24)
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_lbl = Label.new()
	sfx_lbl.text = "80%"
	sfx_lbl.custom_minimum_size = Vector2(40, 0)
	sfx_lbl.label_settings = master_lset
	sfx_box.add_child(sfx_slider)
	sfx_box.add_child(sfx_lbl)
	grid_audio.add_child(sfx_box)
	
	# --- SECTION 3: SYSTEM/DATA ---
	var s_title = Label.new()
	s_title.text = "データ設定"
	s_title.label_settings = sec_set
	scroll_content.add_child(s_title)
	
	reset_btn = Button.new()
	reset_btn.text = "データ初期化"
	reset_btn.custom_minimum_size = Vector2(300, 44)
	reset_btn.add_theme_font_size_override("font_size", 18)
	style_button(reset_btn, Color(0.9, 0.2, 0.2), Color(1.0, 0.4, 0.4))
	scroll_content.add_child(reset_btn)
	
	# Save & Back
	back_btn = Button.new()
	back_btn.text = "保存して戻る"
	back_btn.custom_minimum_size = Vector2(250, 52)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.add_theme_font_size_override("font_size", 22)
	content.add_child(back_btn)
	style_button(back_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
	add_button_animations(back_btn)
	
	# Connect signals
	mode_option.item_selected.connect(_on_display_mode_changed)
	scale_option.item_selected.connect(_on_display_scale_changed)
	aspect_option.item_selected.connect(_on_display_aspect_changed)
	vsync_check.toggled.connect(func(t): Global.vsync = t)
	shake_check.toggled.connect(func(t): Global.screen_shake = t)
	
	master_slider.value_changed.connect(func(v):
		Global.master_volume = v
		master_lbl.text = str(int(v)) + "%"
		Global.apply_audio()
	)
	bgm_slider.value_changed.connect(func(v):
		Global.bgm_volume = v
		bgm_lbl.text = str(int(v)) + "%"
		Global.apply_audio()
	)
	sfx_slider.value_changed.connect(func(v):
		Global.sfx_volume = v
		sfx_lbl.text = str(int(v)) + "%"
		Global.apply_audio()
	)
	
	reset_btn.pressed.connect(_on_reset_btn_pressed)
	back_btn.pressed.connect(_on_back_btn_pressed)

func setup_confirm_dialog() -> void:
	confirm_dialog = PanelContainer.new()
	confirm_dialog.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_dialog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	confirm_dialog.custom_minimum_size = Vector2(420, 240)
	confirm_dialog.hide()
	add_child(confirm_dialog)
	
	# Center it on top of everything
	confirm_dialog.anchor_left = 0.5
	confirm_dialog.anchor_top = 0.5
	confirm_dialog.anchor_right = 0.5
	confirm_dialog.anchor_bottom = 0.5
	confirm_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	confirm_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	confirm_dialog.offset_left = -210
	confirm_dialog.offset_top = -120
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.04, 0.04, 0.98) # Dark Red themed
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1.0, 0.2, 0.2)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.shadow_color = Color(1.0, 0.0, 0.0, 0.3)
	sb.shadow_size = 20
	confirm_dialog.add_theme_stylebox_override("panel", sb)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	confirm_dialog.add_child(margin)
	
	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	margin.add_child(box)
	
	var warn_title = Label.new()
	warn_title.text = "⚠️ 警告"
	warn_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var w_lbl_set = LabelSettings.new()
	w_lbl_set.font_size = 26
	w_lbl_set.font_color = Color.RED
	w_lbl_set.outline_size = 4
	w_lbl_set.outline_color = Color.BLACK
	warn_title.label_settings = w_lbl_set
	box.add_child(warn_title)
	
	var warn_desc = Label.new()
	warn_desc.text = "セーブデータを削除しますか？\nこの操作は元に戻せません。"
	warn_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var d_lbl_set = LabelSettings.new()
	d_lbl_set.font_size = 18
	d_lbl_set.font_color = Color.WHITE
	warn_desc.label_settings = d_lbl_set
	box.add_child(warn_desc)
	
	var btns_box = HBoxContainer.new()
	btns_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btns_box.add_theme_constant_override("separation", 25)
	box.add_child(btns_box)
	
	var delete_confirm_btn = Button.new()
	delete_confirm_btn.text = "削除"
	delete_confirm_btn.custom_minimum_size = Vector2(150, 48)
	delete_confirm_btn.add_theme_font_size_override("font_size", 20)
	style_button(delete_confirm_btn, Color.RED, Color(1.0, 0.4, 0.4))
	btns_box.add_child(delete_confirm_btn)
	
	var cancel_confirm_btn = Button.new()
	cancel_confirm_btn.text = "キャンセル"
	cancel_confirm_btn.custom_minimum_size = Vector2(150, 48)
	cancel_confirm_btn.add_theme_font_size_override("font_size", 20)
	style_button(cancel_confirm_btn, Color.LIGHT_GRAY, Color.WHITE)
	btns_box.add_child(cancel_confirm_btn)
	
	delete_confirm_btn.pressed.connect(func():
		Global.delete_save_game()
		confirm_dialog.hide()
	)
	cancel_confirm_btn.pressed.connect(func():
		confirm_dialog.hide()
	)


func setup_tutorial_confirm_dialog() -> void:
	tutorial_dialog = PanelContainer.new()
	tutorial_dialog.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tutorial_dialog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tutorial_dialog.custom_minimum_size = Vector2(440, 250)
	tutorial_dialog.hide()
	add_child(tutorial_dialog)
	
	# Center it on top of everything
	tutorial_dialog.anchor_left = 0.5
	tutorial_dialog.anchor_top = 0.5
	tutorial_dialog.anchor_right = 0.5
	tutorial_dialog.anchor_bottom = 0.5
	tutorial_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tutorial_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	tutorial_dialog.offset_left = -220
	tutorial_dialog.offset_top = -125
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.98) # Dark blue themed
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color.CYAN
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.shadow_color = Color(0.0, 0.8, 1.0, 0.3)
	sb.shadow_size = 20
	tutorial_dialog.add_theme_stylebox_override("panel", sb)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	tutorial_dialog.add_child(margin)
	
	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	margin.add_child(box)
	
	var t_title = Label.new()
	t_title.text = "🤖 チュートリアル"
	t_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t_lbl_set = LabelSettings.new()
	t_lbl_set.font_size = 26
	t_lbl_set.font_color = Color.CYAN
	t_lbl_set.outline_size = 4
	t_lbl_set.outline_color = Color.BLACK
	t_title.label_settings = t_lbl_set
	box.add_child(t_title)
	
	var t_desc = Label.new()
	t_desc.text = "操作説明（スロー機能）の\nチュートリアルをプレイしますか？"
	t_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var d_lbl_set = LabelSettings.new()
	d_lbl_set.font_size = 18
	d_lbl_set.font_color = Color.WHITE
	t_desc.label_settings = d_lbl_set
	box.add_child(t_desc)
	
	var btns_box = HBoxContainer.new()
	btns_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btns_box.add_theme_constant_override("separation", 25)
	box.add_child(btns_box)
	
	var play_btn = Button.new()
	play_btn.text = "プレイ"
	play_btn.custom_minimum_size = Vector2(150, 48)
	play_btn.add_theme_font_size_override("font_size", 20)
	style_button(play_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
	btns_box.add_child(play_btn)
	
	var skip_btn = Button.new()
	skip_btn.text = "スキップ"
	skip_btn.custom_minimum_size = Vector2(150, 48)
	skip_btn.add_theme_font_size_override("font_size", 20)
	style_button(skip_btn, Color.GOLD, Color(1.0, 0.85, 0.3))
	btns_box.add_child(skip_btn)
	
	play_btn.pressed.connect(func():
		tutorial_dialog.hide()
		Global.is_continue = false
		get_tree().change_scene_to_file("res://game/main.tscn")
	)
	
	skip_btn.pressed.connect(func():
		tutorial_dialog.hide()
		Global.is_first_launch = false
		Global.save_game(1, 0, {})
		get_tree().change_scene_to_file("res://game/core/stage_selection.tscn")
	)

func create_label(text: String) -> Label:
	var l = Label.new()
	l.text = text
	var l_set = LabelSettings.new()
	l_set.font_size = 18
	l_set.font_color = Color.WHITE
	l.label_settings = l_set
	return l

func style_button(btn: Button, normal_color: Color, hover_color: Color) -> void:
	var sb_normal = StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.06, 0.06, 0.1, 0.8)
	sb_normal.border_width_left = 2
	sb_normal.border_width_top = 2
	sb_normal.border_width_right = 2
	sb_normal.border_width_bottom = 2
	sb_normal.border_color = normal_color
	sb_normal.corner_radius_top_left = 6
	sb_normal.corner_radius_top_right = 6
	sb_normal.corner_radius_bottom_left = 6
	sb_normal.corner_radius_bottom_right = 6
	sb_normal.shadow_color = Color(normal_color.r, normal_color.g, normal_color.b, 0.15)
	sb_normal.shadow_size = 4
	
	var sb_hover = StyleBoxFlat.new()
	sb_hover.bg_color = Color(0.12, 0.12, 0.22, 0.85)
	sb_hover.border_width_left = 2
	sb_hover.border_width_top = 2
	sb_hover.border_width_right = 2
	sb_hover.border_width_bottom = 2
	sb_hover.border_color = hover_color
	sb_hover.corner_radius_top_left = 6
	sb_hover.corner_radius_top_right = 6
	sb_hover.corner_radius_bottom_left = 6
	sb_hover.corner_radius_bottom_right = 6
	sb_hover.shadow_color = Color(hover_color.r, hover_color.g, hover_color.b, 0.4)
	sb_hover.shadow_size = 8
	
	var sb_pressed = StyleBoxFlat.new()
	sb_pressed.bg_color = hover_color
	sb_pressed.border_width_left = 2
	sb_pressed.border_width_top = 2
	sb_pressed.border_width_right = 2
	sb_pressed.border_width_bottom = 2
	sb_pressed.border_color = Color.WHITE
	sb_pressed.corner_radius_top_left = 6
	sb_pressed.corner_radius_top_right = 6
	sb_pressed.corner_radius_bottom_left = 6
	sb_pressed.corner_radius_bottom_right = 6
	
	var sb_disabled = StyleBoxFlat.new()
	sb_disabled.bg_color = Color(0.03, 0.03, 0.05, 0.5)
	sb_disabled.border_width_left = 1
	sb_disabled.border_width_top = 1
	sb_disabled.border_width_right = 1
	sb_disabled.border_width_bottom = 1
	sb_disabled.border_color = Color(0.2, 0.2, 0.2, 0.4)
	sb_disabled.corner_radius_top_left = 6
	sb_disabled.corner_radius_top_right = 6
	sb_disabled.corner_radius_bottom_left = 6
	sb_disabled.corner_radius_bottom_right = 6
	
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("disabled", sb_disabled)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))

func add_button_animations(btn: Button) -> void:
	btn.mouse_entered.connect(func():
		btn.pivot_offset = btn.size / 2
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		btn.pivot_offset = btn.size / 2
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)

# ----------------- Interactive Handling -----------------

func sync_settings_to_ui() -> void:
	mode_option.selected = Global.window_mode
	
	# Resolving scale selection indices (0.5, 0.75, 1.0, 1.25)
	if abs(Global.window_scale - 0.5) < 0.05:
		scale_option.selected = 0
	elif abs(Global.window_scale - 0.75) < 0.05:
		scale_option.selected = 1
	elif abs(Global.window_scale - 1.25) < 0.05:
		scale_option.selected = 3
	else:
		scale_option.selected = 2 # 1.0x default
		
	aspect_option.selected = Global.aspect_ratio
	
	# Disable resolution selection if in fullscreen
	if Global.window_mode == 1:
		scale_option.disabled = true
		aspect_option.disabled = true
	else:
		scale_option.disabled = false
		aspect_option.disabled = false
		
	vsync_check.button_pressed = Global.vsync
	shake_check.button_pressed = Global.screen_shake
	
	master_slider.value = Global.master_volume
	master_lbl.text = str(int(Global.master_volume)) + "%"
	
	bgm_slider.value = Global.bgm_volume
	bgm_lbl.text = str(int(Global.bgm_volume)) + "%"
	
	sfx_slider.value = Global.sfx_volume
	sfx_lbl.text = str(int(Global.sfx_volume)) + "%"

func _on_play_start_pressed() -> void:
	# Check if first launch or not
	var save_data = Global.load_game_data()
	
	if Global.is_first_launch:
		# Show tutorial confirm dialog
		tutorial_dialog.show()
		tutorial_dialog.modulate.a = 0.0
		tutorial_dialog.scale = Vector2(0.8, 0.8)
		var tween = create_tween().set_parallel(true)
		tween.tween_property(tutorial_dialog, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(tutorial_dialog, "modulate:a", 1.0, 0.15)
	else:
		# Subsequent launches: Go to Stage Selection Screen
		get_tree().change_scene_to_file("res://game/core/stage_selection.tscn")

func _on_settings_pressed() -> void:
	# Transition: hide menu container, show settings panel
	var tween = create_tween().set_parallel(true)
	menu_container.hide()
	settings_container.show()
	settings_container.scale = Vector2(0.8, 0.8)
	settings_container.modulate.a = 0.0
	tween.tween_property(settings_container, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(settings_container, "modulate:a", 1.0, 0.2)

func _on_display_mode_changed(idx: int) -> void:
	Global.window_mode = idx
	if idx == 1:
		scale_option.disabled = true
		aspect_option.disabled = true
	else:
		scale_option.disabled = false
		aspect_option.disabled = false
	Global.apply_display()

func _on_display_scale_changed(idx: int) -> void:
	match idx:
		0: Global.window_scale = 0.5
		1: Global.window_scale = 0.75
		2: Global.window_scale = 1.0
		3: Global.window_scale = 1.25
	Global.apply_display()

func _on_display_aspect_changed(idx: int) -> void:
	Global.aspect_ratio = idx
	Global.apply_display()

func _on_reset_btn_pressed() -> void:
	confirm_dialog.show()
	confirm_dialog.modulate.a = 0.0
	confirm_dialog.scale = Vector2(0.8, 0.8)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(confirm_dialog, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(confirm_dialog, "modulate:a", 1.0, 0.15)

func _on_back_btn_pressed() -> void:
	Global.save_settings()
	var tween = create_tween().set_parallel(true)
	tween.tween_property(settings_container, "scale", Vector2(0.8, 0.8), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(settings_container, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(func():
		settings_container.hide()
		menu_container.show()
	)

# ----------------- Starfield & Title Animation -----------------

func init_starfield() -> void:
	var viewport_size = get_viewport_rect().size
	for i in range(NUM_STARS):
		var star = Star.new()
		star.pos = Vector2(randf() * viewport_size.x, randf() * viewport_size.y)
		star.speed = randf_range(20.0, 80.0)
		star.size = randf_range(1.0, 3.5)
		# Varying cyan/purple sci-fi colors for stars
		var hue = randf_range(0.5, 0.85) # Cyan to Purple
		star.color = Color.from_hsv(hue, randf_range(0.4, 0.8), randf_range(0.6, 1.0), randf_range(0.3, 0.8))
		stars.append(star)

func update_starfield(delta: float) -> void:
	var viewport_size = get_viewport_rect().size
	for star in stars:
		star.pos.y += star.speed * delta
		if star.pos.y > viewport_size.y:
			star.pos.y = 0
			star.pos.x = randf() * viewport_size.x
	queue_redraw()

func _draw() -> void:
	# Drawing custom sci-fi stars
	for star in stars:
		draw_circle(star.pos, star.size, star.color)

func animate_title(delta: float) -> void:
	time_passed += delta
	# Subtle floating & pulse effect for sci-fi look
	if title_label:
		title_label.position.y += sin(time_passed * 2.2) * 0.15
		var scale_pulse = 1.0 + sin(time_passed * 1.5) * 0.015
		title_label.scale = Vector2(scale_pulse, scale_pulse)

func animate_menu_entry() -> void:
	# Slide and fade-in animation for main menu UI
	menu_container.modulate.a = 0.0
	var original_pos = menu_container.position
	menu_container.position.y += 30
	var tween = create_tween().set_parallel(true)
	tween.tween_property(menu_container, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu_container, "position:y", original_pos.y, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
