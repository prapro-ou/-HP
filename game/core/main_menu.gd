extends Control

# Background stars definition
class Star:
	var pos: Vector2
	var speed: float
	var size: float
	var color: Color

var stars: Array[Star] = []
const NUM_STARS = 60

const PIXEL_FONT: Font = preload("res://game/assets/fonts/DotGothic16-Regular.ttf")

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
var credits_dialog: PanelContainer

# Buttons
var play_start_btn: Button
var settings_btn: Button
var credits_btn: Button

# Settings UI inputs
var mode_option: OptionButton
var scale_option: OptionButton
var aspect_option: OptionButton
var vsync_check: CheckButton
var shake_check: CheckButton
var player_color_option: OptionButton
var player_ship_preview: TextureRect
var player_ship_color_name_lbl: Label
var player_color_keys: Array = ["blue", "red", "green", "yellow", "purple", "orange"]
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
	Global.load_game_data()
	
	# Main Menu uses SFX only (Stop BGM)
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("stop_bgm"):
		audio_mgr.stop_bgm(0.3)
	
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
	title_label.text = "PARRY SHOOTER"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_set = LabelSettings.new()
	if PIXEL_FONT:
		title_set.font = PIXEL_FONT
	title_set.font_size = 64
	title_set.font_color = Color.CYAN
	title_set.outline_size = 10
	title_set.outline_color = Color(0.05, 0.05, 0.1)
	title_label.label_settings = title_set
	title_label.pivot_offset = Vector2(350, 60)
	main_vbox.add_child(title_label)
	
	# Subtitle
	subtitle_label = Label.new()
	subtitle_label.text = "パリィで解析・カウンターで撃破"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub_set = LabelSettings.new()
	if PIXEL_FONT:
		sub_set.font = PIXEL_FONT
	sub_set.font_size = 26
	sub_set.font_color = Color.GOLD
	sub_set.outline_size = 5
	sub_set.outline_color = Color.BLACK
	subtitle_label.label_settings = sub_set
	main_vbox.add_child(subtitle_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 70)
	main_vbox.add_child(spacer)
	
	# 5. Main Menu Container
	setup_menu_container()
	
	# 6. Settings Container (Hidden initially)
	setup_settings_container()
	
	# 7. Custom confirmation dialog (Hidden initially)
	setup_confirm_dialog()

	# 8. Tutorial confirmation dialog (Hidden initially)
	setup_tutorial_confirm_dialog()

	# 9. Credits dialog (Hidden initially)
	setup_credits_dialog()

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
	play_start_btn.custom_minimum_size = Vector2(400, 78)
	play_start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_start_btn.add_theme_font_size_override("font_size", 30)
	if PIXEL_FONT:
		play_start_btn.add_theme_font_override("font", PIXEL_FONT)
	menu_container.add_child(play_start_btn)
	style_button(play_start_btn, Color.CYAN, Color(0.3, 0.9, 1.0))
	add_button_animations(play_start_btn)
	
	# Settings Button
	settings_btn = Button.new()
	settings_btn.text = "設定"
	settings_btn.custom_minimum_size = Vector2(400, 78)
	settings_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	settings_btn.add_theme_font_size_override("font_size", 30)
	if PIXEL_FONT:
		settings_btn.add_theme_font_override("font", PIXEL_FONT)
	menu_container.add_child(settings_btn)
	style_button(settings_btn, Color(0.8, 0.4, 1.0), Color(0.9, 0.6, 1.0))
	add_button_animations(settings_btn)
	
	# Credits Button
	credits_btn = Button.new()
	credits_btn.text = "クレジット"
	credits_btn.custom_minimum_size = Vector2(400, 72)
	credits_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	credits_btn.add_theme_font_size_override("font_size", 26)
	if PIXEL_FONT:
		credits_btn.add_theme_font_override("font", PIXEL_FONT)
	menu_container.add_child(credits_btn)
	style_button(credits_btn, Color(0.3, 0.85, 0.65), Color(0.5, 1.0, 0.8))
	add_button_animations(credits_btn)
	
	# Setup button signals
	play_start_btn.pressed.connect(_on_play_start_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	credits_btn.pressed.connect(_on_credits_pressed)

func setup_settings_container() -> void:
	settings_container = PanelContainer.new()
	settings_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	settings_container.custom_minimum_size = Vector2(620, 860)
	settings_container.hide()
	main_vbox.add_child(settings_container)
	
	# Translucent pixel-art panel style (カクカクした3pxドット枠)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.1, 0.98)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.8, 0.4, 1.0, 0.9)
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	settings_container.add_theme_stylebox_override("panel", sb)
	
	var margin_inner = MarginContainer.new()
	margin_inner.add_theme_constant_override("margin_left", 28)
	margin_inner.add_theme_constant_override("margin_top", 28)
	margin_inner.add_theme_constant_override("margin_right", 28)
	margin_inner.add_theme_constant_override("margin_bottom", 28)
	settings_container.add_child(margin_inner)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	margin_inner.add_child(content)
	
	# Title
	var settings_title = Label.new()
	settings_title.text = "設定"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_set = LabelSettings.new()
	if PIXEL_FONT:
		title_set.font = PIXEL_FONT
	title_set.font_size = 36
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
	scroll_content.add_theme_constant_override("separation", 22)
	scroll.add_child(scroll_content)
	
	# --- SECTION 1: DISPLAY ---
	var d_title = Label.new()
	d_title.text = "画面設定"
	var sec_set = LabelSettings.new()
	if PIXEL_FONT:
		sec_set.font = PIXEL_FONT
	sec_set.font_size = 26
	sec_set.font_color = Color.CYAN
	sec_set.outline_size = 4
	sec_set.outline_color = Color.BLACK
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
	mode_option.custom_minimum_size = Vector2(240, 44)
	mode_option.add_theme_font_size_override("font_size", 18)
	if PIXEL_FONT:
		mode_option.add_theme_font_override("font", PIXEL_FONT)
	grid_display.add_child(mode_option)
	
	# Resolution / Scale (Vertical formats only)
	grid_display.add_child(create_label("画面サイズ:"))
	scale_option = OptionButton.new()
	scale_option.add_item("400x600 (0.50x)", 0)
	scale_option.add_item("600x900 (0.75x)", 1)
	scale_option.add_item("800x1200 (1.00x)", 2)
	scale_option.add_item("1000x1500 (1.25x)", 3)
	scale_option.custom_minimum_size = Vector2(240, 44)
	scale_option.add_theme_font_size_override("font_size", 18)
	if PIXEL_FONT:
		scale_option.add_theme_font_override("font", PIXEL_FONT)
	grid_display.add_child(scale_option)
	
	# Aspect Ratio
	grid_display.add_child(create_label("縦横比:"))
	aspect_option = OptionButton.new()
	aspect_option.add_item("縦長 2:3 (標準)", 0)
	aspect_option.add_item("縦長 3:4", 1)
	aspect_option.add_item("縦長 9:16 (極細)", 2)
	aspect_option.custom_minimum_size = Vector2(240, 44)
	aspect_option.add_theme_font_size_override("font_size", 18)
	if PIXEL_FONT:
		aspect_option.add_theme_font_override("font", PIXEL_FONT)
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
	
	# --- SECTION 2: SHIP CUSTOMIZATION ---
	var p_title = Label.new()
	p_title.text = "自機機体カラー設定"
	p_title.label_settings = sec_set
	scroll_content.add_child(p_title)
	
	var ship_card = PanelContainer.new()
	var sc_sb = StyleBoxFlat.new()
	sc_sb.bg_color = Color(0.05, 0.07, 0.12, 0.8)
	sc_sb.border_width_left = 2
	sc_sb.border_width_top = 2
	sc_sb.border_width_right = 2
	sc_sb.border_width_bottom = 2
	sc_sb.border_color = Color(0.2, 0.6, 0.9, 0.6)
	sc_sb.corner_radius_top_left = 8
	sc_sb.corner_radius_top_right = 8
	sc_sb.corner_radius_bottom_left = 8
	sc_sb.corner_radius_bottom_right = 8
	ship_card.add_theme_stylebox_override("panel", sc_sb)
	scroll_content.add_child(ship_card)
	
	var ship_margin = MarginContainer.new()
	ship_margin.add_theme_constant_override("margin_left", 18)
	ship_margin.add_theme_constant_override("margin_top", 16)
	ship_margin.add_theme_constant_override("margin_right", 18)
	ship_margin.add_theme_constant_override("margin_bottom", 16)
	ship_card.add_child(ship_margin)
	
	var ship_box = HBoxContainer.new()
	ship_box.add_theme_constant_override("separation", 24)
	ship_box.alignment = BoxContainer.ALIGNMENT_CENTER
	ship_margin.add_child(ship_box)
	
	# Preview Box
	var preview_panel = PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(90, 90)
	var pp_sb = StyleBoxFlat.new()
	pp_sb.bg_color = Color(0.02, 0.03, 0.06, 0.9)
	pp_sb.border_width_left = 2
	pp_sb.border_width_top = 2
	pp_sb.border_width_right = 2
	pp_sb.border_width_bottom = 2
	pp_sb.border_color = Color(0.3, 0.7, 1.0, 0.5)
	pp_sb.corner_radius_top_left = 6
	pp_sb.corner_radius_top_right = 6
	pp_sb.corner_radius_bottom_left = 6
	pp_sb.corner_radius_bottom_right = 6
	preview_panel.add_theme_stylebox_override("panel", pp_sb)
	ship_box.add_child(preview_panel)
	
	player_ship_preview = TextureRect.new()
	player_ship_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_ship_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_ship_preview.custom_minimum_size = Vector2(72, 72)
	preview_panel.add_child(player_ship_preview)
	
	# Color controls
	var controls_vbox = VBoxContainer.new()
	controls_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_vbox.add_theme_constant_override("separation", 10)
	ship_box.add_child(controls_vbox)
	
	player_ship_color_name_lbl = Label.new()
	player_ship_color_name_lbl.text = "コバルトブルー (標準)"
	var cn_set = LabelSettings.new()
	if PIXEL_FONT:
		cn_set.font = PIXEL_FONT
	cn_set.font_size = 20
	cn_set.font_color = Color.CYAN
	cn_set.outline_size = 4
	cn_set.outline_color = Color.BLACK
	player_ship_color_name_lbl.label_settings = cn_set
	controls_vbox.add_child(player_ship_color_name_lbl)
	
	player_color_option = OptionButton.new()
	player_color_option.custom_minimum_size = Vector2(240, 44)
	player_color_option.add_theme_font_size_override("font_size", 18)
	if PIXEL_FONT:
		player_color_option.add_theme_font_override("font", PIXEL_FONT)
	for i in range(player_color_keys.size()):
		var key = player_color_keys[i]
		var col_info = Global.available_player_colors.get(key, {"name": key})
		player_color_option.add_item(col_info["name"], i)
	controls_vbox.add_child(player_color_option)
	
	# --- SECTION 3: AUDIO ---
	var a_title = Label.new()
	a_title.text = "音量設定"
	a_title.label_settings = sec_set
	scroll_content.add_child(a_title)
	
	var grid_audio = GridContainer.new()
	grid_audio.columns = 2
	grid_audio.add_theme_constant_override("h_separation", 16)
	grid_audio.add_theme_constant_override("v_separation", 14)
	scroll_content.add_child(grid_audio)
	
	# Master
	grid_audio.add_child(create_label("主音量:"))
	var master_box = HBoxContainer.new()
	master_slider = HSlider.new()
	master_slider.min_value = 0
	master_slider.max_value = 100
	master_slider.value = 80
	master_slider.custom_minimum_size = Vector2(170, 30)
	master_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	master_lbl = Label.new()
	master_lbl.text = "80%"
	master_lbl.custom_minimum_size = Vector2(50, 0)
	var master_lset = LabelSettings.new()
	if PIXEL_FONT:
		master_lset.font = PIXEL_FONT
	master_lset.font_size = 20
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
	bgm_slider.custom_minimum_size = Vector2(170, 30)
	bgm_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bgm_lbl = Label.new()
	bgm_lbl.text = "80%"
	bgm_lbl.custom_minimum_size = Vector2(50, 0)
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
	sfx_slider.custom_minimum_size = Vector2(170, 30)
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_lbl = Label.new()
	sfx_lbl.text = "80%"
	sfx_lbl.custom_minimum_size = Vector2(50, 0)
	sfx_lbl.label_settings = master_lset
	sfx_box.add_child(sfx_slider)
	sfx_box.add_child(sfx_lbl)
	grid_audio.add_child(sfx_box)
	
	# --- SECTION 4: CREDITS / クレジット ---
	var cr_title = Label.new()
	cr_title.text = "クレジット"
	cr_title.label_settings = sec_set
	scroll_content.add_child(cr_title)
	
	var credits_card = PanelContainer.new()
	var cr_sb = StyleBoxFlat.new()
	cr_sb.bg_color = Color(0.04, 0.07, 0.12, 0.9)
	cr_sb.border_width_left = 2
	cr_sb.border_width_top = 2
	cr_sb.border_width_right = 2
	cr_sb.border_width_bottom = 2
	cr_sb.border_color = Color(0.3, 0.85, 0.65, 0.7)
	cr_sb.corner_radius_top_left = 6
	cr_sb.corner_radius_top_right = 6
	cr_sb.corner_radius_bottom_left = 6
	cr_sb.corner_radius_bottom_right = 6
	credits_card.add_theme_stylebox_override("panel", cr_sb)
	scroll_content.add_child(credits_card)
	
	var cr_margin = MarginContainer.new()
	cr_margin.add_theme_constant_override("margin_left", 16)
	cr_margin.add_theme_constant_override("margin_top", 16)
	cr_margin.add_theme_constant_override("margin_right", 16)
	cr_margin.add_theme_constant_override("margin_bottom", 16)
	credits_card.add_child(cr_margin)
	
	var cr_vbox = VBoxContainer.new()
	cr_vbox.add_theme_constant_override("separation", 10)
	cr_margin.add_child(cr_vbox)
	
	# 魔王魂
	var maou_btn = Button.new()
	maou_btn.text = "BGM: 魔王魂 (https://maou.audio/)"
	maou_btn.custom_minimum_size = Vector2(0, 40)
	maou_btn.add_theme_font_size_override("font_size", 15)
	if PIXEL_FONT: maou_btn.add_theme_font_override("font", PIXEL_FONT)
	style_button(maou_btn, Color(0.9, 0.75, 0.2), Color(1.0, 0.9, 0.4))
	add_button_animations(maou_btn)
	maou_btn.pressed.connect(func(): _open_url("https://maou.audio/"))
	cr_vbox.add_child(maou_btn)
	
	# 効果音ラボ
	var lab_btn = Button.new()
	lab_btn.text = "SE: 効果音ラボ (https://soundeffect-lab.info/)"
	lab_btn.custom_minimum_size = Vector2(0, 40)
	lab_btn.add_theme_font_size_override("font_size", 15)
	if PIXEL_FONT: lab_btn.add_theme_font_override("font", PIXEL_FONT)
	style_button(lab_btn, Color(0.2, 0.8, 0.9), Color(0.4, 0.95, 1.0))
	add_button_animations(lab_btn)
	lab_btn.pressed.connect(func(): _open_url("https://soundeffect-lab.info/"))
	cr_vbox.add_child(lab_btn)
	
	# フォント
	var font_lbl = Label.new()
	font_lbl.text = "Font: DotGothic16 (SIL Open Font License 1.1)"
	var font_lset = LabelSettings.new()
	if PIXEL_FONT: font_lset.font = PIXEL_FONT
	font_lset.font_size = 15
	font_lset.font_color = Color(0.7, 0.75, 0.85)
	font_lbl.label_settings = font_lset
	cr_vbox.add_child(font_lbl)
	
	# --- SECTION 5: DEBUG / DATA RESET ---
	var s_title = Label.new()
	s_title.text = "【デバッグ用】個別データリセット"
	var dbg_sec_set = LabelSettings.new()
	if PIXEL_FONT:
		dbg_sec_set.font = PIXEL_FONT
	dbg_sec_set.font_size = 24
	dbg_sec_set.font_color = Color(1.0, 0.45, 0.45)
	dbg_sec_set.outline_size = 4
	dbg_sec_set.outline_color = Color.BLACK
	s_title.label_settings = dbg_sec_set
	scroll_content.add_child(s_title)
	
	var dbg_card = PanelContainer.new()
	var dbg_sb = StyleBoxFlat.new()
	dbg_sb.bg_color = Color(0.08, 0.04, 0.05, 0.9)
	dbg_sb.border_width_left = 2
	dbg_sb.border_width_top = 2
	dbg_sb.border_width_right = 2
	dbg_sb.border_width_bottom = 2
	dbg_sb.border_color = Color(0.8, 0.3, 0.3, 0.7)
	dbg_sb.corner_radius_top_left = 6
	dbg_sb.corner_radius_top_right = 6
	dbg_sb.corner_radius_bottom_left = 6
	dbg_sb.corner_radius_bottom_right = 6
	dbg_card.add_theme_stylebox_override("panel", dbg_sb)
	scroll_content.add_child(dbg_card)
	
	var dbg_margin = MarginContainer.new()
	dbg_margin.add_theme_constant_override("margin_left", 16)
	dbg_margin.add_theme_constant_override("margin_top", 16)
	dbg_margin.add_theme_constant_override("margin_right", 16)
	dbg_margin.add_theme_constant_override("margin_bottom", 16)
	dbg_card.add_child(dbg_margin)
	
	var dbg_vbox = VBoxContainer.new()
	dbg_vbox.add_theme_constant_override("separation", 12)
	dbg_margin.add_child(dbg_vbox)
	
	# 1. 強化内容のみリセット
	var reset_upgrades_btn = Button.new()
	reset_upgrades_btn.text = "強化内容のみリセット (HP/パリィ/CD -> 0)"
	reset_upgrades_btn.custom_minimum_size = Vector2(0, 48)
	reset_upgrades_btn.add_theme_font_size_override("font_size", 18)
	if PIXEL_FONT:
		reset_upgrades_btn.add_theme_font_override("font", PIXEL_FONT)
	style_button(reset_upgrades_btn, Color(0.9, 0.45, 0.2), Color(1.0, 0.6, 0.3))
	dbg_vbox.add_child(reset_upgrades_btn)
	reset_upgrades_btn.pressed.connect(func():
		Global.reset_upgrade_levels()
		show_debug_toast("強化内容（HP・パリィ判定・CD）を 0 にリセットしました")
	)
	
	# 2. 開発ポイント(TP)のみリセット
	var reset_tp_btn = Button.new()
	reset_tp_btn.text = "獲得開発ポイント(TP)のみリセット (-> 0)"
	reset_tp_btn.custom_minimum_size = Vector2(0, 48)
	reset_tp_btn.add_theme_font_size_override("font_size", 18)
	if PIXEL_FONT:
		reset_tp_btn.add_theme_font_override("font", PIXEL_FONT)
	style_button(reset_tp_btn, Color(0.85, 0.3, 0.55), Color(1.0, 0.45, 0.7))
	dbg_vbox.add_child(reset_tp_btn)
	reset_tp_btn.pressed.connect(func():
		Global.reset_tech_points()
		show_debug_toast("開発ポイント（TP）を 0 にリセットしました")
	)
	
	# 3. 兵装開発・解析図鑑・ステージ解放リセット
	var reset_dev_btn = Button.new()
	reset_dev_btn.text = "兵装開発・解析図鑑・ステージ解放リセット"
	reset_dev_btn.custom_minimum_size = Vector2(0, 48)
	reset_dev_btn.add_theme_font_size_override("font_size", 18)
	if PIXEL_FONT:
		reset_dev_btn.add_theme_font_override("font", PIXEL_FONT)
	style_button(reset_dev_btn, Color(0.75, 0.3, 0.8), Color(0.9, 0.45, 0.95))
	dbg_vbox.add_child(reset_dev_btn)
	reset_dev_btn.pressed.connect(func():
		Global.reset_development_progress()
		show_debug_toast("兵装開発・解析図鑑・ステージ解放を初期化しました")
	)
	
	# 4. 全データ初期化
	reset_btn = Button.new()
	reset_btn.text = "全セーブデータ一括初期化 (完全消去)"
	reset_btn.custom_minimum_size = Vector2(0, 50)
	reset_btn.add_theme_font_size_override("font_size", 18)
	if PIXEL_FONT:
		reset_btn.add_theme_font_override("font", PIXEL_FONT)
	style_button(reset_btn, Color(0.95, 0.15, 0.15), Color(1.0, 0.3, 0.3))
	dbg_vbox.add_child(reset_btn)
	
	# Save & Back
	back_btn = Button.new()
	back_btn.text = "保存して戻る"
	back_btn.custom_minimum_size = Vector2(300, 62)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.add_theme_font_size_override("font_size", 26)
	content.add_child(back_btn)
	style_button(back_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
	add_button_animations(back_btn)
	
	# Connect signals
	mode_option.item_selected.connect(_on_display_mode_changed)
	scale_option.item_selected.connect(_on_display_scale_changed)
	aspect_option.item_selected.connect(_on_display_aspect_changed)
	player_color_option.item_selected.connect(_on_player_color_changed)
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
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_ui_click"):
			audio_mgr.play_ui_click()
	)
	
	reset_btn.pressed.connect(_on_reset_btn_pressed)
	back_btn.pressed.connect(_on_back_btn_pressed)

func setup_confirm_dialog() -> void:
	confirm_dialog = PanelContainer.new()
	confirm_dialog.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_dialog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	confirm_dialog.custom_minimum_size = Vector2(520, 290)
	confirm_dialog.hide()
	add_child(confirm_dialog)
	
	confirm_dialog.anchor_left = 0.5
	confirm_dialog.anchor_top = 0.5
	confirm_dialog.anchor_right = 0.5
	confirm_dialog.anchor_bottom = 0.5
	confirm_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	confirm_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	confirm_dialog.offset_left = -260
	confirm_dialog.offset_top = -145
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.03, 0.03, 0.98) # Dark Red pixel theme
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1.0, 0.2, 0.2)
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	confirm_dialog.add_theme_stylebox_override("panel", sb)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	confirm_dialog.add_child(margin)
	
	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	margin.add_child(box)
	
	var warn_title = Label.new()
	warn_title.text = "[WARNING] セーブデータ初期化の警告"
	warn_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var w_lbl_set = LabelSettings.new()
	if PIXEL_FONT:
		w_lbl_set.font = PIXEL_FONT
	w_lbl_set.font_size = 28
	w_lbl_set.font_color = Color.RED
	w_lbl_set.outline_size = 4
	w_lbl_set.outline_color = Color.BLACK
	warn_title.label_settings = w_lbl_set
	box.add_child(warn_title)
	
	var warn_desc = Label.new()
	warn_desc.text = "セーブデータを削除しますか？\nこの操作は元に戻せません。"
	warn_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var d_lbl_set = LabelSettings.new()
	if PIXEL_FONT:
		d_lbl_set.font = PIXEL_FONT
	d_lbl_set.font_size = 22
	d_lbl_set.font_color = Color.WHITE
	d_lbl_set.outline_size = 3
	d_lbl_set.outline_color = Color.BLACK
	warn_desc.label_settings = d_lbl_set
	box.add_child(warn_desc)
	
	var btns_box = HBoxContainer.new()
	btns_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btns_box.add_theme_constant_override("separation", 25)
	box.add_child(btns_box)
	
	var delete_confirm_btn = Button.new()
	delete_confirm_btn.text = "削除"
	delete_confirm_btn.custom_minimum_size = Vector2(170, 52)
	delete_confirm_btn.add_theme_font_size_override("font_size", 22)
	if PIXEL_FONT:
		delete_confirm_btn.add_theme_font_override("font", PIXEL_FONT)
	style_button(delete_confirm_btn, Color.RED, Color(1.0, 0.4, 0.4))
	btns_box.add_child(delete_confirm_btn)
	
	var cancel_confirm_btn = Button.new()
	cancel_confirm_btn.text = "キャンセル"
	cancel_confirm_btn.custom_minimum_size = Vector2(170, 52)
	cancel_confirm_btn.add_theme_font_size_override("font_size", 22)
	if PIXEL_FONT:
		cancel_confirm_btn.add_theme_font_override("font", PIXEL_FONT)
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
	tutorial_dialog.custom_minimum_size = Vector2(540, 300)
	tutorial_dialog.hide()
	add_child(tutorial_dialog)
	
	tutorial_dialog.anchor_left = 0.5
	tutorial_dialog.anchor_top = 0.5
	tutorial_dialog.anchor_right = 0.5
	tutorial_dialog.anchor_bottom = 0.5
	tutorial_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tutorial_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	tutorial_dialog.offset_left = -270
	tutorial_dialog.offset_top = -150
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.1, 0.98) # Dark blue pixel theme
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color.CYAN
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	tutorial_dialog.add_theme_stylebox_override("panel", sb)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	tutorial_dialog.add_child(margin)
	
	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	margin.add_child(box)
	
	var t_title = Label.new()
	t_title.text = "チュートリアル"
	t_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t_lbl_set = LabelSettings.new()
	if PIXEL_FONT:
		t_lbl_set.font = PIXEL_FONT
	t_lbl_set.font_size = 28
	t_lbl_set.font_color = Color.CYAN
	t_lbl_set.outline_size = 4
	t_lbl_set.outline_color = Color.BLACK
	t_title.label_settings = t_lbl_set
	box.add_child(t_title)
	
	var t_desc = Label.new()
	t_desc.text = "操作説明と実践チュートリアルを\nプレイしますか？"
	t_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var d_lbl_set = LabelSettings.new()
	if PIXEL_FONT:
		d_lbl_set.font = PIXEL_FONT
	d_lbl_set.font_size = 22
	d_lbl_set.font_color = Color.WHITE
	d_lbl_set.outline_size = 3
	d_lbl_set.outline_color = Color.BLACK
	t_desc.label_settings = d_lbl_set
	box.add_child(t_desc)
	
	var btns_box = HBoxContainer.new()
	btns_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btns_box.add_theme_constant_override("separation", 25)
	box.add_child(btns_box)
	
	var play_btn = Button.new()
	play_btn.text = "プレイ"
	play_btn.custom_minimum_size = Vector2(170, 52)
	play_btn.add_theme_font_size_override("font_size", 22)
	if PIXEL_FONT:
		play_btn.add_theme_font_override("font", PIXEL_FONT)
	style_button(play_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
	btns_box.add_child(play_btn)
	
	var skip_btn = Button.new()
	skip_btn.text = "スキップ"
	skip_btn.custom_minimum_size = Vector2(170, 52)
	skip_btn.add_theme_font_size_override("font_size", 22)
	if PIXEL_FONT:
		skip_btn.add_theme_font_override("font", PIXEL_FONT)
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


func setup_credits_dialog() -> void:
	credits_dialog = PanelContainer.new()
	credits_dialog.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	credits_dialog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	credits_dialog.custom_minimum_size = Vector2(500, 340)
	credits_dialog.hide()
	add_child(credits_dialog)
	
	credits_dialog.anchor_left = 0.5
	credits_dialog.anchor_top = 0.5
	credits_dialog.anchor_right = 0.5
	credits_dialog.anchor_bottom = 0.5
	credits_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	credits_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	credits_dialog.offset_left = -250
	credits_dialog.offset_top = -170
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.09, 0.98)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.3, 0.85, 0.65, 0.95)
	credits_dialog.add_theme_stylebox_override("panel", sb)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	credits_dialog.add_child(margin)
	
	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	
	# Title
	var c_title = Label.new()
	c_title.text = "クレジット"
	c_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t_set = LabelSettings.new()
	if PIXEL_FONT: t_set.font = PIXEL_FONT
	t_set.font_size = 26
	t_set.font_color = Color(0.3, 0.85, 0.65)
	t_set.outline_size = 4
	t_set.outline_color = Color.BLACK
	c_title.label_settings = t_set
	box.add_child(c_title)
	
	# 魔王魂
	var maou_btn = Button.new()
	maou_btn.text = "BGM: 魔王魂 (https://maou.audio/)"
	maou_btn.custom_minimum_size = Vector2(0, 42)
	maou_btn.add_theme_font_size_override("font_size", 16)
	if PIXEL_FONT: maou_btn.add_theme_font_override("font", PIXEL_FONT)
	style_button(maou_btn, Color(0.9, 0.75, 0.2), Color(1.0, 0.9, 0.4))
	add_button_animations(maou_btn)
	maou_btn.pressed.connect(func(): _open_url("https://maou.audio/"))
	box.add_child(maou_btn)
	
	# 効果音ラボ
	var lab_btn = Button.new()
	lab_btn.text = "SE: 効果音ラボ (https://soundeffect-lab.info/)"
	lab_btn.custom_minimum_size = Vector2(0, 42)
	lab_btn.add_theme_font_size_override("font_size", 16)
	if PIXEL_FONT: lab_btn.add_theme_font_override("font", PIXEL_FONT)
	style_button(lab_btn, Color(0.2, 0.8, 0.9), Color(0.4, 0.95, 1.0))
	add_button_animations(lab_btn)
	lab_btn.pressed.connect(func(): _open_url("https://soundeffect-lab.info/"))
	box.add_child(lab_btn)
	
	# フォント
	var font_lbl = Label.new()
	font_lbl.text = "Font: DotGothic16 (SIL Open Font License 1.1)"
	font_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var f_set = LabelSettings.new()
	if PIXEL_FONT: f_set.font = PIXEL_FONT
	f_set.font_size = 15
	f_set.font_color = Color(0.7, 0.75, 0.85)
	font_lbl.label_settings = f_set
	box.add_child(font_lbl)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "閉じる"
	close_btn.custom_minimum_size = Vector2(180, 42)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.add_theme_font_size_override("font_size", 18)
	if PIXEL_FONT: close_btn.add_theme_font_override("font", PIXEL_FONT)
	style_button(close_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
	add_button_animations(close_btn)
	close_btn.pressed.connect(func():
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_ui_cancel"):
			audio_mgr.play_ui_cancel()
		credits_dialog.hide()
	)
	box.add_child(close_btn)

func create_label(text: String) -> Label:
	var l = Label.new()
	l.text = text
	var l_set = LabelSettings.new()
	if PIXEL_FONT:
		l_set.font = PIXEL_FONT
	l_set.font_size = 22
	l_set.font_color = Color.WHITE
	l_set.outline_size = 3
	l_set.outline_color = Color.BLACK
	l.label_settings = l_set
	return l

func style_button(btn: Button, normal_color: Color, hover_color: Color) -> void:
	if PIXEL_FONT:
		btn.add_theme_font_override("font", PIXEL_FONT)
		
	var sb_normal = StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.04, 0.05, 0.08, 0.9)
	sb_normal.border_width_left = 3
	sb_normal.border_width_top = 3
	sb_normal.border_width_right = 3
	sb_normal.border_width_bottom = 3
	sb_normal.border_color = normal_color
	sb_normal.corner_radius_top_left = 0
	sb_normal.corner_radius_top_right = 0
	sb_normal.corner_radius_bottom_left = 0
	sb_normal.corner_radius_bottom_right = 0
	
	var sb_hover = StyleBoxFlat.new()
	sb_hover.bg_color = Color(0.1, 0.12, 0.2, 0.95)
	sb_hover.border_width_left = 3
	sb_hover.border_width_top = 3
	sb_hover.border_width_right = 3
	sb_hover.border_width_bottom = 3
	sb_hover.border_color = hover_color
	sb_hover.corner_radius_top_left = 0
	sb_hover.corner_radius_top_right = 0
	sb_hover.corner_radius_bottom_left = 0
	sb_hover.corner_radius_bottom_right = 0
	
	var sb_pressed = StyleBoxFlat.new()
	sb_pressed.bg_color = hover_color
	sb_pressed.border_width_left = 3
	sb_pressed.border_width_top = 3
	sb_pressed.border_width_right = 3
	sb_pressed.border_width_bottom = 3
	sb_pressed.border_color = Color.WHITE
	sb_pressed.corner_radius_top_left = 0
	sb_pressed.corner_radius_top_right = 0
	sb_pressed.corner_radius_bottom_left = 0
	sb_pressed.corner_radius_bottom_right = 0
	
	var sb_disabled = StyleBoxFlat.new()
	sb_disabled.bg_color = Color(0.02, 0.02, 0.04, 0.5)
	sb_disabled.border_width_left = 2
	sb_disabled.border_width_top = 2
	sb_disabled.border_width_right = 2
	sb_disabled.border_width_bottom = 2
	sb_disabled.border_color = Color(0.2, 0.2, 0.2, 0.4)
	sb_disabled.corner_radius_top_left = 0
	sb_disabled.corner_radius_top_right = 0
	sb_disabled.corner_radius_bottom_left = 0
	sb_disabled.corner_radius_bottom_right = 0
	
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
	
	var color_idx = player_color_keys.find(Global.player_color)
	if color_idx != -1:
		player_color_option.selected = color_idx
	else:
		player_color_option.selected = 0
	update_ship_preview()

func update_ship_preview() -> void:
	if not player_ship_preview:
		return
	var cur_color = Global.player_color
	var tex_path = Global.get_player_texture_path(cur_color)
	if ResourceLoader.exists(tex_path):
		player_ship_preview.texture = load(tex_path)
	if Global.available_player_colors.has(cur_color):
		var data = Global.available_player_colors[cur_color]
		player_ship_color_name_lbl.text = data["name"]
		player_ship_color_name_lbl.label_settings.font_color = data.get("accent_color", Color.CYAN)

func _on_player_color_changed(idx: int) -> void:
	if idx >= 0 and idx < player_color_keys.size():
		Global.player_color = player_color_keys[idx]
		update_ship_preview()

func _on_play_start_pressed() -> void:
	# Check if first launch or not
	Global.load_game_data()
	
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

func _on_credits_pressed() -> void:
	# Transition: show credits dialog modal
	credits_dialog.show()
	credits_dialog.modulate.a = 0.0
	credits_dialog.scale = Vector2(0.8, 0.8)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(credits_dialog, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(credits_dialog, "modulate:a", 1.0, 0.18)

func _open_url(url: String) -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_ui_click"):
		audio_mgr.play_ui_click()
	OS.shell_open(url)

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

func show_debug_toast(text: String) -> void:
	var toast = Label.new()
	toast.text = text
	var t_set = LabelSettings.new()
	if PIXEL_FONT:
		t_set.font = PIXEL_FONT
	t_set.font_size = 18
	t_set.font_color = Color.GREEN_YELLOW
	t_set.outline_size = 5
	t_set.outline_color = Color.BLACK
	toast.label_settings = t_set
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.position = Vector2(50, 600)
	toast.custom_minimum_size = Vector2(700, 35)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(toast, "position:y", toast.position.y - 45.0, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(toast, "modulate:a", 0.0, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(toast.queue_free)

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
