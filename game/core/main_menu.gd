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
var stage_select_title_label: Label
var briefing_title_label: Label

# Menu and screens
var menu_container: VBoxContainer
var settings_container: PanelContainer
var stage_select_container: PanelContainer
var pre_battle_container: PanelContainer
var confirm_dialog: PanelContainer
var hangar_container: PanelContainer
var research_container: PanelContainer

# Buttons
var new_game_btn: Button
var hangar_btn: Button
var research_btn: Button
var settings_btn: Button
var quit_btn: Button

# Hangar UI elements
var shield_parry_btn: Button
var shield_mitigate_btn: Button
var hangar_back_btn: Button
var hangar_beam_progress: ProgressBar
var hangar_missile_progress: ProgressBar
var hangar_beam_lbl: Label
var hangar_missile_lbl: Label

# Research UI elements
var research_credits_lbl: Label
var hp_upgrade_btn: Button
var hp_level_lbl: Label
var hp_desc_lbl: Label
var speed_upgrade_btn: Button
var speed_level_lbl: Label
var speed_desc_lbl: Label
var shield_upgrade_btn: Button
var shield_level_lbl: Label
var shield_desc_lbl: Label
var research_back_btn: Button

# Stage buttons
var stage1_btn: Button
var stage2_btn: Button
var stage_back_btn: Button

# Pre-battle UI elements (Weapon Selection / Sortie Screen)
var briefing_label: Label
var player_status_label: Label
var launch_btn: Button
var pre_battle_back_btn: Button

# Weapon/Shield Loadout selections in Sortie screen
var pre_shield_parry_btn: Button
var pre_shield_mitigate_btn: Button
var pre_shield_desc_lbl: Label
var pre_weapon_rifle_btn: Button
var pre_weapon_beam_btn: Button
var pre_weapon_missile_btn: Button
var pre_beam_prog_bar: ProgressBar
var pre_missile_prog_bar: ProgressBar
var pre_beam_lbl: Label
var pre_missile_lbl: Label
var pre_rifle_lbl: Label

# Settings UI inputs
var mode_option: OptionButton
var lang_option: OptionButton
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
	
	# Layout design
	setup_layout()
	init_starfield()
	
	# Load settings data into UI
	sync_settings_to_ui()
	
	# Translate strings init
	translate_ui()
	
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
	title_label.text = "CYBER PARRY\nFORCE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_set = LabelSettings.new()
	title_set.font_size = 54
	title_set.font_color = Color.CYAN
	title_set.outline_size = 12
	title_set.outline_color = Color(0.05, 0.05, 0.1)
	title_label.label_settings = title_set
	title_label.pivot_offset = Vector2(350, 60)
	main_vbox.add_child(title_label)
	
	# Subtitle
	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub_set = LabelSettings.new()
	sub_set.font_size = 18
	sub_set.font_color = Color.GOLD
	sub_set.outline_size = 4
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
	
	# 7. Hangar Container (Hidden initially)
	setup_hangar_container()
	
	# 8. Research Container (Hidden initially)
	setup_research_container()
	
	# 9. Stage Select Container (Hidden initially)
	setup_stage_select_container()
	
	# 10. Pre-battle Container (Hidden initially)
	setup_pre_battle_container()
	
	# 11. Custom confirmation dialog (Hidden initially)
	setup_confirm_dialog()

func setup_menu_container() -> void:
	menu_container = VBoxContainer.new()
	menu_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_container.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_container.theme_type_variation = "VBoxContainer"
	menu_container.add_theme_constant_override("separation", 20)
	main_vbox.add_child(menu_container)
	
	# Start Game Button (Stage Select Screen)
	new_game_btn = Button.new()
	new_game_btn.custom_minimum_size = Vector2(320, 60)
	new_game_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_container.add_child(new_game_btn)
	style_button(new_game_btn, Color.CYAN, Color(0.3, 0.9, 1.0))
	add_button_animations(new_game_btn)
	
	# Hangar Button (Weapon & Shield Selection)
	hangar_btn = Button.new()
	hangar_btn.custom_minimum_size = Vector2(320, 60)
	hangar_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_container.add_child(hangar_btn)
	style_button(hangar_btn, Color(0.3, 0.8, 1.0), Color(0.5, 0.9, 1.0))
	add_button_animations(hangar_btn)
	
	# Research Button (Upgrades)
	research_btn = Button.new()
	research_btn.custom_minimum_size = Vector2(320, 60)
	research_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_container.add_child(research_btn)
	style_button(research_btn, Color.GOLD, Color(1.0, 0.85, 0.3))
	add_button_animations(research_btn)
	
	# Settings Button
	settings_btn = Button.new()
	settings_btn.custom_minimum_size = Vector2(320, 60)
	settings_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_container.add_child(settings_btn)
	style_button(settings_btn, Color(0.8, 0.4, 1.0), Color(0.9, 0.6, 1.0))
	add_button_animations(settings_btn)
	
	# Quit Button
	quit_btn = Button.new()
	quit_btn.custom_minimum_size = Vector2(320, 60)
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_container.add_child(quit_btn)
	style_button(quit_btn, Color(0.8, 0.2, 0.2), Color(1.0, 0.4, 0.4))
	add_button_animations(quit_btn)
	
	# Setup button signals
	new_game_btn.pressed.connect(_on_new_game_pressed)
	hangar_btn.pressed.connect(_on_hangar_pressed)
	research_btn.pressed.connect(_on_research_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

func setup_settings_container() -> void:
	settings_container = PanelContainer.new()
	settings_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	settings_container.custom_minimum_size = Vector2(480, 620)
	settings_container.hide()
	main_vbox.add_child(settings_container)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.8, 0.4, 1.0, 0.8) # Purple theme
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
	
	var settings_title = Label.new()
	settings_title.text = "環境設定 - SETTINGS"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_set = LabelSettings.new()
	title_set.font_size = 26
	title_set.font_color = Color(0.9, 0.6, 1.0)
	title_set.outline_size = 4
	title_set.outline_color = Color.BLACK
	settings_title.label_settings = title_set
	content.add_child(settings_title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	
	var scroll_content = VBoxContainer.new()
	scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_content.add_theme_constant_override("separation", 18)
	scroll.add_child(scroll_content)
	
	# DISPLAY
	var d_title = Label.new()
	d_title.text = "画面・言語設定 / DISPLAY & LANGUAGE"
	var sec_set = LabelSettings.new()
	sec_set.font_size = 18
	sec_set.font_color = Color.CYAN
	d_title.label_settings = sec_set
	scroll_content.add_child(d_title)
	
	var grid_display = GridContainer.new()
	grid_display.columns = 2
	grid_display.add_theme_constant_override("h_separation", 15)
	grid_display.add_theme_constant_override("v_separation", 12)
	scroll_content.add_child(grid_display)
	
	# Language Option
	grid_display.add_child(create_label("表示言語 (Language):"))
	lang_option = OptionButton.new()
	lang_option.add_item("日本語 / Japanese", 0)
	lang_option.add_item("English", 1)
	lang_option.custom_minimum_size = Vector2(200, 32)
	grid_display.add_child(lang_option)
	
	# Window Mode Option
	grid_display.add_child(create_label("画面モード (Window Mode):"))
	mode_option = OptionButton.new()
	mode_option.add_item("ウィンドウ / Windowed", 0)
	mode_option.add_item("フルスクリーン / Fullscreen", 1)
	mode_option.add_item("ボーダレス / Borderless", 2)
	mode_option.custom_minimum_size = Vector2(200, 32)
	grid_display.add_child(mode_option)
	
	grid_display.add_child(create_label("垂直同期 (V-Sync):"))
	vsync_check = CheckButton.new()
	vsync_check.text = ""
	grid_display.add_child(vsync_check)
	
	grid_display.add_child(create_label("画面の揺れ (Screen Shake):"))
	shake_check = CheckButton.new()
	shake_check.text = ""
	grid_display.add_child(shake_check)
	
	# AUDIO
	var a_title = Label.new()
	a_title.text = "音量設定 / AUDIO"
	a_title.label_settings = sec_set
	scroll_content.add_child(a_title)
	
	var grid_audio = GridContainer.new()
	grid_audio.columns = 2
	grid_audio.add_theme_constant_override("h_separation", 15)
	grid_audio.add_theme_constant_override("v_separation", 12)
	scroll_content.add_child(grid_audio)
	
	# Master
	grid_audio.add_child(create_label("マスター音量 (Master):"))
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
	master_box.add_child(master_slider)
	master_box.add_child(master_lbl)
	grid_audio.add_child(master_box)
	
	# BGM
	grid_audio.add_child(create_label("BGM音量 (BGM):"))
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
	bgm_box.add_child(bgm_slider)
	bgm_box.add_child(bgm_lbl)
	grid_audio.add_child(bgm_box)
	
	# SFX
	grid_audio.add_child(create_label("効果音音量 (SFX):"))
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
	sfx_box.add_child(sfx_slider)
	sfx_box.add_child(sfx_lbl)
	grid_audio.add_child(sfx_box)
	
	# SYSTEM/DATA
	var s_title = Label.new()
	s_title.text = "データ管理 / DATA"
	s_title.label_settings = sec_set
	scroll_content.add_child(s_title)
	
	reset_btn = Button.new()
	reset_btn.custom_minimum_size = Vector2(300, 36)
	style_button(reset_btn, Color(0.9, 0.2, 0.2), Color(1.0, 0.4, 0.4))
	scroll_content.add_child(reset_btn)
	
	back_btn = Button.new()
	back_btn.custom_minimum_size = Vector2(250, 48)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(back_btn)
	style_button(back_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
	add_button_animations(back_btn)
	
	# Connect signals
	lang_option.item_selected.connect(_on_language_changed)
	mode_option.item_selected.connect(_on_display_mode_changed)
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

func setup_stage_select_container() -> void:
	stage_select_container = PanelContainer.new()
	stage_select_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stage_select_container.custom_minimum_size = Vector2(480, 500)
	stage_select_container.hide()
	main_vbox.add_child(stage_select_container)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.3, 0.8, 1.0, 0.8) # Cyan theme
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.shadow_color = Color(0.3, 0.8, 1.0, 0.25)
	sb.shadow_size = 15
	stage_select_container.add_theme_stylebox_override("panel", sb)
	
	var margin_inner = MarginContainer.new()
	margin_inner.add_theme_constant_override("margin_left", 30)
	margin_inner.add_theme_constant_override("margin_top", 30)
	margin_inner.add_theme_constant_override("margin_right", 30)
	margin_inner.add_theme_constant_override("margin_bottom", 30)
	stage_select_container.add_child(margin_inner)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 25)
	margin_inner.add_child(content)
	
	# Title
	stage_select_title_label = Label.new()
	stage_select_title_label.name = "TitleLabel"
	stage_select_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_set = LabelSettings.new()
	title_set.font_size = 26
	title_set.font_color = Color(0.3, 0.8, 1.0)
	title_set.outline_size = 4
	title_set.outline_color = Color.BLACK
	stage_select_title_label.label_settings = title_set
	content.add_child(stage_select_title_label)
	
	var stage_list = VBoxContainer.new()
	stage_list.add_theme_constant_override("separation", 18)
	content.add_child(stage_list)
	
	# Stage 1 Button
	stage1_btn = Button.new()
	stage1_btn.custom_minimum_size = Vector2(360, 70)
	style_button(stage1_btn, Color.CYAN, Color(0.5, 0.9, 1.0))
	add_button_animations(stage1_btn)
	stage_list.add_child(stage1_btn)
	stage1_btn.pressed.connect(func(): _on_stage_selected(1))
	
	# Stage 2 Button
	stage2_btn = Button.new()
	stage2_btn.custom_minimum_size = Vector2(360, 70)
	style_button(stage2_btn, Color.GOLD, Color(1.0, 0.85, 0.3))
	add_button_animations(stage2_btn)
	stage_list.add_child(stage2_btn)
	stage2_btn.pressed.connect(func(): _on_stage_selected(2))
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	content.add_child(spacer)
	
	# Back Button
	stage_back_btn = Button.new()
	stage_back_btn.custom_minimum_size = Vector2(250, 48)
	stage_back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	style_button(stage_back_btn, Color.LIGHT_GRAY, Color.WHITE)
	add_button_animations(stage_back_btn)
	content.add_child(stage_back_btn)
	stage_back_btn.pressed.connect(_on_stage_back_pressed)

func setup_pre_battle_container() -> void:
	pre_battle_container = PanelContainer.new()
	pre_battle_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pre_battle_container.custom_minimum_size = Vector2(700, 720)
	pre_battle_container.hide()
	main_vbox.add_child(pre_battle_container)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.96) # Dark terminal background
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.3, 0.8, 1.0, 0.9) # Cyan border
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.shadow_color = Color(0.3, 0.8, 1.0, 0.25)
	sb.shadow_size = 15
	pre_battle_container.add_theme_stylebox_override("panel", sb)
	
	var margin_inner = MarginContainer.new()
	margin_inner.add_theme_constant_override("margin_left", 20)
	margin_inner.add_theme_constant_override("margin_top", 20)
	margin_inner.add_theme_constant_override("margin_right", 20)
	margin_inner.add_theme_constant_override("margin_bottom", 20)
	pre_battle_container.add_child(margin_inner)
	
	var main_content = VBoxContainer.new()
	main_content.add_theme_constant_override("separation", 15)
	margin_inner.add_child(main_content)
	
	# Main Title
	briefing_title_label = Label.new()
	briefing_title_label.name = "TitleLabel"
	briefing_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_set = LabelSettings.new()
	title_set.font_size = 26
	title_set.font_color = Color(0.3, 0.8, 1.0)
	title_set.outline_size = 6
	title_set.outline_color = Color.BLACK
	briefing_title_label.label_settings = title_set
	main_content.add_child(briefing_title_label)
	
	# Horizontal Columns Container
	var columns_hbox = HBoxContainer.new()
	columns_hbox.add_theme_constant_override("separation", 20)
	columns_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_content.add_child(columns_hbox)
	
	# --- LEFT COLUMN: Stage Briefing ---
	var left_col = VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 1.0
	left_col.add_theme_constant_override("separation", 10)
	columns_hbox.add_child(left_col)
	
	var left_title = Label.new()
	left_title.text = "MISSION BRIEFING"
	left_title.name = "LeftTitle"
	var col_title_set = LabelSettings.new()
	col_title_set.font_size = 18
	col_title_set.font_color = Color.GOLD
	left_title.label_settings = col_title_set
	left_col.add_child(left_title)
	
	var detail_panel = PanelContainer.new()
	var dp_style = StyleBoxFlat.new()
	dp_style.bg_color = Color(0.03, 0.03, 0.05, 0.8)
	dp_style.border_width_left = 1
	dp_style.border_width_top = 1
	dp_style.border_width_right = 1
	dp_style.border_width_bottom = 1
	dp_style.border_color = Color(0.2, 0.5, 0.7, 0.4)
	dp_style.corner_radius_top_left = 8
	dp_style.corner_radius_top_right = 8
	dp_style.corner_radius_bottom_left = 8
	dp_style.corner_radius_bottom_right = 8
	dp_style.content_margin_left = 12
	dp_style.content_margin_top = 12
	dp_style.content_margin_right = 12
	dp_style.content_margin_bottom = 12
	detail_panel.add_theme_stylebox_override("panel", dp_style)
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(detail_panel)
	
	var scroll_brief = ScrollContainer.new()
	scroll_brief.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(scroll_brief)
	
	var detail_vbox = VBoxContainer.new()
	detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vbox.add_theme_constant_override("separation", 10)
	scroll_brief.add_child(detail_vbox)
	
	briefing_label = Label.new()
	briefing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var b_set = LabelSettings.new()
	b_set.font_size = 14
	b_set.line_spacing = 6
	b_set.font_color = Color(0.9, 0.9, 0.9)
	briefing_label.label_settings = b_set
	detail_vbox.add_child(briefing_label)
	
	# Dummy/hidden label to avoid null reference crashes
	player_status_label = Label.new()
	player_status_label.hide()
	detail_vbox.add_child(player_status_label)
	
	# --- RIGHT COLUMN: Weapon & Shield Loadout ---
	var right_col = VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 1.2
	right_col.add_theme_constant_override("separation", 10)
	columns_hbox.add_child(right_col)
	
	var right_title = Label.new()
	right_title.text = "WEAPON & SHIELD LOADOUT"
	right_title.name = "RightTitle"
	right_title.label_settings = col_title_set
	right_col.add_child(right_title)
	
	var loadout_panel = PanelContainer.new()
	loadout_panel.add_theme_stylebox_override("panel", dp_style)
	loadout_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(loadout_panel)
	
	var scroll_loadout = ScrollContainer.new()
	scroll_loadout.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	loadout_panel.add_child(scroll_loadout)
	
	var loadout_vbox = VBoxContainer.new()
	loadout_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout_vbox.add_theme_constant_override("separation", 14)
	scroll_loadout.add_child(loadout_vbox)
	
	# SUBSECTION: Shield Select
	var shield_title = Label.new()
	shield_title.text = "SHIELD MODULE"
	shield_title.name = "ShieldTitle"
	var subsec_lbl_set = LabelSettings.new()
	subsec_lbl_set.font_size = 15
	subsec_lbl_set.font_color = Color.CYAN
	shield_title.label_settings = subsec_lbl_set
	loadout_vbox.add_child(shield_title)
	
	var shield_btns_hbox = HBoxContainer.new()
	shield_btns_hbox.add_theme_constant_override("separation", 10)
	loadout_vbox.add_child(shield_btns_hbox)
	
	pre_shield_parry_btn = Button.new()
	pre_shield_parry_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pre_shield_parry_btn.custom_minimum_size = Vector2(0, 36)
	style_button(pre_shield_parry_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
	add_button_animations(pre_shield_parry_btn)
	shield_btns_hbox.add_child(pre_shield_parry_btn)
	
	pre_shield_mitigate_btn = Button.new()
	pre_shield_mitigate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pre_shield_mitigate_btn.custom_minimum_size = Vector2(0, 36)
	style_button(pre_shield_mitigate_btn, Color.LIGHT_GRAY, Color.WHITE)
	add_button_animations(pre_shield_mitigate_btn)
	shield_btns_hbox.add_child(pre_shield_mitigate_btn)
	
	pre_shield_desc_lbl = Label.new()
	pre_shield_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var desc_set = LabelSettings.new()
	desc_set.font_size = 12
	desc_set.font_color = Color.LIGHT_GRAY
	desc_set.line_spacing = 4
	pre_shield_desc_lbl.label_settings = desc_set
	loadout_vbox.add_child(pre_shield_desc_lbl)
	
	var sep_loadout = ColorRect.new()
	sep_loadout.custom_minimum_size = Vector2(0, 1)
	sep_loadout.color = Color(0.3, 0.8, 1.0, 0.2)
	loadout_vbox.add_child(sep_loadout)
	
	# SUBSECTION: Weapon Slots
	var weapon_title = Label.new()
	weapon_title.text = "SPECIAL WEAPONS"
	weapon_title.name = "WeaponTitle"
	weapon_title.label_settings = subsec_lbl_set
	loadout_vbox.add_child(weapon_title)
	
	# 1. Rifle (Standard)
	var rifle_box = VBoxContainer.new()
	rifle_box.add_theme_constant_override("separation", 4)
	loadout_vbox.add_child(rifle_box)
	
	pre_weapon_rifle_btn = Button.new()
	pre_weapon_rifle_btn.custom_minimum_size = Vector2(0, 38)
	pre_weapon_rifle_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	style_button(pre_weapon_rifle_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
	add_button_animations(pre_weapon_rifle_btn)
	rifle_box.add_child(pre_weapon_rifle_btn)
	
	pre_rifle_lbl = Label.new()
	pre_rifle_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pre_rifle_lbl.label_settings = desc_set
	rifle_box.add_child(pre_rifle_lbl)
	
	# 2. Beam Weapon
	var beam_box = VBoxContainer.new()
	beam_box.add_theme_constant_override("separation", 4)
	loadout_vbox.add_child(beam_box)
	
	var beam_hbox = HBoxContainer.new()
	beam_hbox.add_theme_constant_override("separation", 10)
	beam_box.add_child(beam_hbox)
	
	pre_weapon_beam_btn = Button.new()
	pre_weapon_beam_btn.custom_minimum_size = Vector2(0, 38)
	pre_weapon_beam_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pre_weapon_beam_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	style_button(pre_weapon_beam_btn, Color.LIGHT_GRAY, Color.WHITE)
	add_button_animations(pre_weapon_beam_btn)
	beam_hbox.add_child(pre_weapon_beam_btn)
	
	pre_beam_prog_bar = ProgressBar.new()
	pre_beam_prog_bar.custom_minimum_size = Vector2(100, 16)
	pre_beam_prog_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	style_analysis_bar(pre_beam_prog_bar, Color.CYAN)
	beam_hbox.add_child(pre_beam_prog_bar)
	
	pre_beam_lbl = Label.new()
	pre_beam_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pre_beam_lbl.label_settings = desc_set
	beam_box.add_child(pre_beam_lbl)
	
	# 3. Missile Weapon
	var missile_box = VBoxContainer.new()
	missile_box.add_theme_constant_override("separation", 4)
	loadout_vbox.add_child(missile_box)
	
	var missile_hbox = HBoxContainer.new()
	missile_hbox.add_theme_constant_override("separation", 10)
	missile_box.add_child(missile_hbox)
	
	pre_weapon_missile_btn = Button.new()
	pre_weapon_missile_btn.custom_minimum_size = Vector2(0, 38)
	pre_weapon_missile_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pre_weapon_missile_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	style_button(pre_weapon_missile_btn, Color.LIGHT_GRAY, Color.WHITE)
	add_button_animations(pre_weapon_missile_btn)
	missile_hbox.add_child(pre_weapon_missile_btn)
	
	pre_missile_prog_bar = ProgressBar.new()
	pre_missile_prog_bar.custom_minimum_size = Vector2(100, 16)
	pre_missile_prog_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	style_analysis_bar(pre_missile_prog_bar, Color(0.8, 0.4, 1.0))
	missile_hbox.add_child(pre_missile_prog_bar)
	
	pre_missile_lbl = Label.new()
	pre_missile_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pre_missile_lbl.label_settings = desc_set
	missile_box.add_child(pre_missile_lbl)
	
	# Separator before actions
	var main_sep = ColorRect.new()
	main_sep.custom_minimum_size = Vector2(0, 2)
	main_sep.color = Color(0.3, 0.8, 1.0, 0.4)
	main_content.add_child(main_sep)
	
	# Bottom: Action Buttons
	var actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 35)
	main_content.add_child(actions)
	
	launch_btn = Button.new()
	launch_btn.custom_minimum_size = Vector2(240, 52)
	style_button(launch_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
	add_button_animations(launch_btn)
	actions.add_child(launch_btn)
	launch_btn.pressed.connect(_on_launch_pressed)
	
	pre_battle_back_btn = Button.new()
	pre_battle_back_btn.custom_minimum_size = Vector2(180, 52)
	style_button(pre_battle_back_btn, Color.LIGHT_GRAY, Color.WHITE)
	add_button_animations(pre_battle_back_btn)
	actions.add_child(pre_battle_back_btn)
	pre_battle_back_btn.pressed.connect(_on_pre_battle_back_pressed)
	
	# Connect signals for loadout options
	pre_shield_parry_btn.pressed.connect(func(): _select_pre_shield("parry"))
	pre_shield_mitigate_btn.pressed.connect(func(): _select_pre_shield("mitigate"))
	pre_weapon_rifle_btn.pressed.connect(func(): _select_pre_weapon("none"))
	pre_weapon_beam_btn.pressed.connect(func(): _select_pre_weapon("beam"))
	pre_weapon_missile_btn.pressed.connect(func(): _select_pre_weapon("missile"))

func setup_confirm_dialog() -> void:
	confirm_dialog = PanelContainer.new()
	confirm_dialog.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_dialog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	confirm_dialog.custom_minimum_size = Vector2(400, 220)
	confirm_dialog.hide()
	add_child(confirm_dialog)
	
	confirm_dialog.anchor_left = 0.5
	confirm_dialog.anchor_top = 0.5
	confirm_dialog.anchor_right = 0.5
	confirm_dialog.anchor_bottom = 0.5
	confirm_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	confirm_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	confirm_dialog.offset_left = -200
	confirm_dialog.offset_top = -110
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.04, 0.04, 0.98) # Dark Red
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
	warn_title.text = "⚠️ 警告 / WARNING"
	warn_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var w_lbl_set = LabelSettings.new()
	w_lbl_set.font_size = 18
	w_lbl_set.font_color = Color.RED
	warn_title.label_settings = w_lbl_set
	box.add_child(warn_title)
	
	var warn_desc = Label.new()
	warn_desc.text = "セーブデータを完全に削除しますか？\nこの操作は元に戻せません。"
	warn_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var d_lbl_set = LabelSettings.new()
	d_lbl_set.font_size = 13
	d_lbl_set.font_color = Color.WHITE
	warn_desc.label_settings = d_lbl_set
	box.add_child(warn_desc)
	
	var btns_box = HBoxContainer.new()
	btns_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btns_box.add_theme_constant_override("separation", 25)
	box.add_child(btns_box)
	
	var delete_confirm_btn = Button.new()
	delete_confirm_btn.text = "削除する / DELETE"
	delete_confirm_btn.custom_minimum_size = Vector2(150, 40)
	style_button(delete_confirm_btn, Color.RED, Color(1.0, 0.4, 0.4))
	btns_box.add_child(delete_confirm_btn)
	
	var cancel_confirm_btn = Button.new()
	cancel_confirm_btn.text = "キャンセル / CANCEL"
	cancel_confirm_btn.custom_minimum_size = Vector2(150, 40)
	style_button(cancel_confirm_btn, Color.LIGHT_GRAY, Color.WHITE)
	btns_box.add_child(cancel_confirm_btn)
	
	delete_confirm_btn.pressed.connect(func():
		Global.delete_save_game()
		confirm_dialog.hide()
		refresh_stage_select()
	)
	cancel_confirm_btn.pressed.connect(func():
		confirm_dialog.hide()
	)

func create_label(text: String) -> Label:
	var l = Label.new()
	l.text = text
	var l_set = LabelSettings.new()
	l_set.font_size = 16
	l_set.font_color = Color.LIGHT_GRAY
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
	btn.add_theme_font_size_override("font_size", 18)

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

func translate_ui() -> void:
	# Titles
	subtitle_label.text = Global.translate("menu_subtitle")
	
	# Main Buttons
	new_game_btn.text = Global.translate("btn_start_game")
	hangar_btn.text = Global.translate("btn_hangar")
	research_btn.text = Global.translate("btn_research")
	settings_btn.text = Global.translate("btn_settings")
	quit_btn.text = Global.translate("btn_quit")
	
	# Hangar UI
	if hangar_container:
		var title_lbl = hangar_container.find_child("TitleLabel", true, false)
		if title_lbl:
			title_lbl.text = Global.translate("hangar_title")
		var sec_lbl = hangar_container.find_child("ShieldSectionLabel", true, false)
		if sec_lbl:
			sec_lbl.text = Global.translate("hangar_shield_select")
		var w_sec_lbl = hangar_container.find_child("WeaponSectionLabel", true, false)
		if w_sec_lbl:
			w_sec_lbl.text = Global.translate("archive_title")
		
		var p_desc = hangar_container.find_child("ParryDesc", true, false)
		if p_desc:
			p_desc.text = Global.translate("shield_parry_desc")
		var m_desc = hangar_container.find_child("MitigateDesc", true, false)
		if m_desc:
			m_desc.text = Global.translate("shield_mitigate_desc")
			
		hangar_back_btn.text = Global.translate("btn_stage_back")
		update_shield_selection_visual()
		
	# Research UI
	if research_container:
		var title_lbl = research_container.find_child("TitleLabel", true, false)
		if title_lbl:
			title_lbl.text = Global.translate("research_title")
		research_back_btn.text = Global.translate("btn_stage_back")
		refresh_research_ui()
	
	# Settings Buttons
	back_btn.text = Global.translate("btn_save_back")
	reset_btn.text = Global.translate("btn_reset_save")
	
	# Stage Select Title
	if stage_select_container:
		if stage_select_title_label:
			stage_select_title_label.text = Global.translate("stage_select_title")
		stage_back_btn.text = Global.translate("btn_stage_back")
		refresh_stage_select()
		
	# Briefing Title & Buttons (Weapon Select & Sortie)
	if pre_battle_container:
		update_pre_battle_visuals()

func sync_settings_to_ui() -> void:
	lang_option.selected = 0 if Global.language == "ja" else 1
	mode_option.selected = Global.window_mode
	vsync_check.button_pressed = Global.vsync
	shake_check.button_pressed = Global.screen_shake
	
	master_slider.value = Global.master_volume
	master_lbl.text = str(int(Global.master_volume)) + "%"
	
	bgm_slider.value = Global.bgm_volume
	bgm_lbl.text = str(int(Global.bgm_volume)) + "%"
	
	sfx_slider.value = Global.sfx_volume
	sfx_lbl.text = str(int(Global.sfx_volume)) + "%"

func _on_language_changed(idx: int) -> void:
	Global.language = "ja" if idx == 0 else "en"
	Global.save_settings()
	translate_ui()

func _on_new_game_pressed() -> void:
	refresh_stage_select()
	var tween = create_tween().set_parallel(true)
	menu_container.hide()
	stage_select_container.show()
	stage_select_container.scale = Vector2(0.8, 0.8)
	stage_select_container.modulate.a = 0.0
	tween.tween_property(stage_select_container, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(stage_select_container, "modulate:a", 1.0, 0.2)

func _on_settings_pressed() -> void:
	var tween = create_tween().set_parallel(true)
	menu_container.hide()
	settings_container.show()
	settings_container.scale = Vector2(0.8, 0.8)
	settings_container.modulate.a = 0.0
	tween.tween_property(settings_container, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(settings_container, "modulate:a", 1.0, 0.2)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_display_mode_changed(idx: int) -> void:
	Global.window_mode = idx
	Global.apply_display()

func _on_reset_btn_pressed() -> void:
	confirm_dialog.show()
	confirm_dialog.scale = Vector2(0.9, 0.9)
	var tween = create_tween()
	tween.tween_property(confirm_dialog, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_back_btn_pressed() -> void:
	Global.save_settings()
	var tween = create_tween().set_parallel(true)
	tween.tween_property(settings_container, "scale", Vector2(0.8, 0.8), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(settings_container, "modulate:a", 0.0, 0.15)
	
	tween.chain().tween_callback(func():
		settings_container.hide()
		menu_container.show()
		menu_container.modulate.a = 0.0
		var in_tween = create_tween()
		in_tween.tween_property(menu_container, "modulate:a", 1.0, 0.15)
	)

func refresh_stage_select() -> void:
	var save_data = Global.load_game_data()
	var max_unlocked = save_data.get("max_unlocked_stage", 1)
	
	stage1_btn.text = Global.translate("stage_01_name")
	
	if max_unlocked >= 2:
		stage2_btn.disabled = false
		stage2_btn.text = Global.translate("stage_02_name")
	else:
		stage2_btn.disabled = true
		stage2_btn.text = Global.translate("stage_02_locked")

func _on_stage_back_pressed() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(stage_select_container, "scale", Vector2(0.8, 0.8), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(stage_select_container, "modulate:a", 0.0, 0.15)
	
	tween.chain().tween_callback(func():
		stage_select_container.hide()
		menu_container.show()
		menu_container.modulate.a = 0.0
		var in_tween = create_tween()
		in_tween.tween_property(menu_container, "modulate:a", 1.0, 0.15)
	)

func _on_stage_selected(stage_num: int) -> void:
	Global.selected_stage = stage_num
	
	# Briefing text
	briefing_label.text = Global.translate("briefing_stage_1") if stage_num == 1 else Global.translate("briefing_stage_2")
	
	# Synchronize weapon/shield select display
	update_pre_battle_visuals()
	
	# Transition
	var tween = create_tween().set_parallel(true)
	stage_select_container.hide()
	pre_battle_container.show()
	pre_battle_container.scale = Vector2(0.8, 0.8)
	pre_battle_container.modulate.a = 0.0
	tween.tween_property(pre_battle_container, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(pre_battle_container, "modulate:a", 1.0, 0.2)

func _on_pre_battle_back_pressed() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(pre_battle_container, "scale", Vector2(0.8, 0.8), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(pre_battle_container, "modulate:a", 0.0, 0.15)
	
	tween.chain().tween_callback(func():
		pre_battle_container.hide()
		stage_select_container.show()
		stage_select_container.modulate.a = 0.0
		var in_tween = create_tween()
		in_tween.tween_property(stage_select_container, "modulate:a", 1.0, 0.15)
	)

func _on_launch_pressed() -> void:
	get_tree().change_scene_to_file("res://game/main.tscn")

# ----------------- Visual Animations & Background -----------------

func init_starfield() -> void:
	stars.clear()
	var rect = get_viewport_rect()
	for i in range(NUM_STARS):
		var s = Star.new()
		s.pos = Vector2(randf() * rect.size.x, randf() * rect.size.y)
		s.speed = randf_range(30.0, 120.0)
		s.size = randf_range(1.0, 2.5)
		var r = randf()
		if r < 0.2:
			s.color = Color(0.3, 0.8, 1.0, randf_range(0.2, 0.6))
		elif r < 0.4:
			s.color = Color(0.8, 0.3, 1.0, randf_range(0.2, 0.6))
		else:
			s.color = Color(1.0, 1.0, 1.0, randf_range(0.3, 0.8))
		stars.append(s)

func update_starfield(delta: float) -> void:
	var rect = get_viewport_rect()
	for s in stars:
		s.pos.y += s.speed * delta
		if s.pos.y > rect.size.y:
			s.pos.y = 0
			s.pos.x = randf() * rect.size.x
	queue_redraw()

func _draw() -> void:
	for s in stars:
		draw_circle(s.pos, s.size, s.color)
		
	var rect = get_viewport_rect()
	var spacing = 8
	for y in range(0, int(rect.size.y), spacing):
		draw_line(Vector2(0, y), Vector2(rect.size.x, y), Color(0, 0, 0, 0.16), 1.0)

func animate_menu_entry() -> void:
	title_label.modulate.a = 0.0
	title_label.scale = Vector2(0.9, 0.9)
	subtitle_label.modulate.a = 0.0
	menu_container.modulate.a = 0.0
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(title_label, "modulate:a", 1.0, 0.5)
	tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.7)
	
	var chain = tween.chain()
	chain.tween_property(menu_container, "modulate:a", 1.0, 0.3)

func animate_title(delta: float) -> void:
	time_passed += delta
	var pulse = 1.0 + sin(time_passed * 2.5) * 0.03
	title_label.scale = Vector2(pulse, pulse)
	
	var blue_glow = Color(0.2, 0.8 + sin(time_passed * 3.0) * 0.15, 1.0)
	title_label.label_settings.font_color = blue_glow


func setup_hangar_container() -> void:
	hangar_container = PanelContainer.new()
	hangar_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hangar_container.custom_minimum_size = Vector2(480, 600)
	hangar_container.hide()
	main_vbox.add_child(hangar_container)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.3, 0.8, 1.0, 0.8) # Cyan border
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.shadow_color = Color(0.3, 0.8, 1.0, 0.25)
	sb.shadow_size = 15
	hangar_container.add_theme_stylebox_override("panel", sb)
	
	var margin_inner = MarginContainer.new()
	margin_inner.add_theme_constant_override("margin_left", 25)
	margin_inner.add_theme_constant_override("margin_top", 25)
	margin_inner.add_theme_constant_override("margin_right", 25)
	margin_inner.add_theme_constant_override("margin_bottom", 25)
	hangar_container.add_child(margin_inner)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	margin_inner.add_child(content)
	
	# Title
	var title_lbl = Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_set = LabelSettings.new()
	title_set.font_size = 26
	title_set.font_color = Color(0.3, 0.8, 1.0)
	title_set.outline_size = 4
	title_set.outline_color = Color.BLACK
	title_lbl.label_settings = title_set
	content.add_child(title_lbl)
	
	# Section 1: Shield Module Selection
	var shield_sec_lbl = Label.new()
	shield_sec_lbl.name = "ShieldSectionLabel"
	var sec_set = LabelSettings.new()
	sec_set.font_size = 18
	sec_set.font_color = Color.CYAN
	shield_sec_lbl.label_settings = sec_set
	content.add_child(shield_sec_lbl)
	
	var shield_box = VBoxContainer.new()
	shield_box.add_theme_constant_override("separation", 15)
	content.add_child(shield_box)
	
	# Parry Shield Option
	var parry_panel = PanelContainer.new()
	var pp_style = StyleBoxFlat.new()
	pp_style.bg_color = Color(0.04, 0.05, 0.08, 0.8)
	pp_style.corner_radius_top_left = 6
	pp_style.corner_radius_top_right = 6
	pp_style.corner_radius_bottom_left = 6
	pp_style.corner_radius_bottom_right = 6
	pp_style.content_margin_left = 12
	pp_style.content_margin_top = 12
	pp_style.content_margin_right = 12
	pp_style.content_margin_bottom = 12
	parry_panel.add_theme_stylebox_override("panel", pp_style)
	shield_box.add_child(parry_panel)
	
	var parry_vbox = VBoxContainer.new()
	parry_vbox.add_theme_constant_override("separation", 6)
	parry_panel.add_child(parry_vbox)
	
	shield_parry_btn = Button.new()
	shield_parry_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	style_button(shield_parry_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
	parry_vbox.add_child(shield_parry_btn)
	
	var parry_desc = Label.new()
	parry_desc.name = "ParryDesc"
	parry_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var desc_set = LabelSettings.new()
	desc_set.font_size = 13
	desc_set.font_color = Color.LIGHT_GRAY
	parry_desc.label_settings = desc_set
	parry_vbox.add_child(parry_desc)
	
	# Mitigate Shield Option
	var mitigate_panel = PanelContainer.new()
	mitigate_panel.add_theme_stylebox_override("panel", pp_style)
	shield_box.add_child(mitigate_panel)
	
	var mitigate_vbox = VBoxContainer.new()
	mitigate_vbox.add_theme_constant_override("separation", 6)
	mitigate_panel.add_child(mitigate_vbox)
	
	shield_mitigate_btn = Button.new()
	shield_mitigate_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	style_button(shield_mitigate_btn, Color.LIGHT_GRAY, Color.WHITE)
	mitigate_vbox.add_child(shield_mitigate_btn)
	
	var mitigate_desc = Label.new()
	mitigate_desc.name = "MitigateDesc"
	mitigate_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mitigate_desc.label_settings = desc_set
	mitigate_vbox.add_child(mitigate_desc)
	
	# Section 2: Weapon Status
	var weapon_sec_lbl = Label.new()
	weapon_sec_lbl.name = "WeaponSectionLabel"
	weapon_sec_lbl.label_settings = sec_set
	content.add_child(weapon_sec_lbl)
	
	var weapon_box = VBoxContainer.new()
	weapon_box.add_theme_constant_override("separation", 12)
	content.add_child(weapon_box)
	
	# Beam Progress
	var beam_hbox = HBoxContainer.new()
	weapon_box.add_child(beam_hbox)
	hangar_beam_lbl = Label.new()
	hangar_beam_lbl.custom_minimum_size = Vector2(150, 0)
	hangar_beam_lbl.label_settings = desc_set
	beam_hbox.add_child(hangar_beam_lbl)
	hangar_beam_progress = ProgressBar.new()
	hangar_beam_progress.custom_minimum_size = Vector2(200, 20)
	hangar_beam_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	beam_hbox.add_child(hangar_beam_progress)
	
	# Missile Progress
	var missile_hbox = HBoxContainer.new()
	weapon_box.add_child(missile_hbox)
	hangar_missile_lbl = Label.new()
	hangar_missile_lbl.custom_minimum_size = Vector2(150, 0)
	hangar_missile_lbl.label_settings = desc_set
	missile_hbox.add_child(hangar_missile_lbl)
	hangar_missile_progress = ProgressBar.new()
	hangar_missile_progress.custom_minimum_size = Vector2(200, 20)
	hangar_missile_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	missile_hbox.add_child(hangar_missile_progress)
	
	# Back Button
	hangar_back_btn = Button.new()
	hangar_back_btn.custom_minimum_size = Vector2(250, 48)
	hangar_back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	style_button(hangar_back_btn, Color.LIGHT_GRAY, Color.WHITE)
	add_button_animations(hangar_back_btn)
	content.add_child(hangar_back_btn)
	
	# Connect signals
	shield_parry_btn.pressed.connect(func(): _select_shield("parry"))
	shield_mitigate_btn.pressed.connect(func(): _select_shield("mitigate"))
	hangar_back_btn.pressed.connect(_on_hangar_back_pressed)


func setup_research_container() -> void:
	research_container = PanelContainer.new()
	research_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	research_container.custom_minimum_size = Vector2(480, 600)
	research_container.hide()
	main_vbox.add_child(research_container)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.05, 0.95) # Gold/Brown tint
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1.0, 0.7, 0.2, 0.8) # Gold border
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.shadow_color = Color(1.0, 0.7, 0.2, 0.2)
	sb.shadow_size = 15
	research_container.add_theme_stylebox_override("panel", sb)
	
	var margin_inner = MarginContainer.new()
	margin_inner.add_theme_constant_override("margin_left", 25)
	margin_inner.add_theme_constant_override("margin_top", 25)
	margin_inner.add_theme_constant_override("margin_right", 25)
	margin_inner.add_theme_constant_override("margin_bottom", 25)
	research_container.add_child(margin_inner)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	margin_inner.add_child(content)
	
	# Title
	var title_lbl = Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_set = LabelSettings.new()
	title_set.font_size = 26
	title_set.font_color = Color(1.0, 0.7, 0.2)
	title_set.outline_size = 4
	title_set.outline_color = Color.BLACK
	title_lbl.label_settings = title_set
	content.add_child(title_lbl)
	
	# Credits (Recovered Data)
	research_credits_lbl = Label.new()
	research_credits_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cred_set = LabelSettings.new()
	cred_set.font_size = 16
	cred_set.font_color = Color(0.6, 0.9, 1.0)
	research_credits_lbl.label_settings = cred_set
	content.add_child(research_credits_lbl)
	
	var list_vbox = VBoxContainer.new()
	list_vbox.add_theme_constant_override("separation", 14)
	content.add_child(list_vbox)
	
	# 1. HP Upgrade Item
	var hp_panel = PanelContainer.new()
	var ip_style = StyleBoxFlat.new()
	ip_style.bg_color = Color(0.04, 0.04, 0.06, 0.8)
	ip_style.corner_radius_top_left = 6
	ip_style.corner_radius_top_right = 6
	ip_style.corner_radius_bottom_left = 6
	ip_style.corner_radius_bottom_right = 6
	ip_style.content_margin_left = 10
	ip_style.content_margin_top = 10
	ip_style.content_margin_right = 10
	ip_style.content_margin_bottom = 10
	hp_panel.add_theme_stylebox_override("panel", ip_style)
	list_vbox.add_child(hp_panel)
	
	var hp_hbox = HBoxContainer.new()
	hp_hbox.add_theme_constant_override("separation", 15)
	hp_panel.add_child(hp_hbox)
	
	var hp_info_vbox = VBoxContainer.new()
	hp_info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_hbox.add_child(hp_info_vbox)
	
	hp_level_lbl = Label.new()
	var item_title_set = LabelSettings.new()
	item_title_set.font_size = 15
	item_title_set.font_color = Color.WHITE
	hp_level_lbl.label_settings = item_title_set
	hp_info_vbox.add_child(hp_level_lbl)
	
	hp_desc_lbl = Label.new()
	var item_desc_set = LabelSettings.new()
	item_desc_set.font_size = 12
	item_desc_set.font_color = Color.LIGHT_GRAY
	hp_desc_lbl.label_settings = item_desc_set
	hp_info_vbox.add_child(hp_desc_lbl)
	
	hp_upgrade_btn = Button.new()
	hp_upgrade_btn.custom_minimum_size = Vector2(160, 40)
	style_button(hp_upgrade_btn, Color.GOLD, Color(1.0, 0.85, 0.3))
	add_button_animations(hp_upgrade_btn)
	hp_hbox.add_child(hp_upgrade_btn)
	hp_upgrade_btn.pressed.connect(func(): _upgrade_stat("hp"))
	
	# 2. Speed Upgrade Item
	var speed_panel = PanelContainer.new()
	speed_panel.add_theme_stylebox_override("panel", ip_style)
	list_vbox.add_child(speed_panel)
	
	var speed_hbox = HBoxContainer.new()
	speed_hbox.add_theme_constant_override("separation", 15)
	speed_panel.add_child(speed_hbox)
	
	var speed_info_vbox = VBoxContainer.new()
	speed_info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_hbox.add_child(speed_info_vbox)
	
	speed_level_lbl = Label.new()
	speed_level_lbl.label_settings = item_title_set
	speed_info_vbox.add_child(speed_level_lbl)
	
	speed_desc_lbl = Label.new()
	speed_desc_lbl.label_settings = item_desc_set
	speed_info_vbox.add_child(speed_desc_lbl)
	
	speed_upgrade_btn = Button.new()
	speed_upgrade_btn.custom_minimum_size = Vector2(160, 40)
	style_button(speed_upgrade_btn, Color.GOLD, Color(1.0, 0.85, 0.3))
	add_button_animations(speed_upgrade_btn)
	speed_hbox.add_child(speed_upgrade_btn)
	speed_upgrade_btn.pressed.connect(func(): _upgrade_stat("speed"))
	
	# 3. Shield Upgrade Item
	var shield_panel = PanelContainer.new()
	shield_panel.add_theme_stylebox_override("panel", ip_style)
	list_vbox.add_child(shield_panel)
	
	var shield_hbox = HBoxContainer.new()
	shield_hbox.add_theme_constant_override("separation", 15)
	shield_panel.add_child(shield_hbox)
	
	var shield_info_vbox = VBoxContainer.new()
	shield_info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shield_hbox.add_child(shield_info_vbox)
	
	shield_level_lbl = Label.new()
	shield_level_lbl.label_settings = item_title_set
	shield_info_vbox.add_child(shield_level_lbl)
	
	shield_desc_lbl = Label.new()
	shield_desc_lbl.label_settings = item_desc_set
	shield_info_vbox.add_child(shield_desc_lbl)
	
	shield_upgrade_btn = Button.new()
	shield_upgrade_btn.custom_minimum_size = Vector2(160, 40)
	style_button(shield_upgrade_btn, Color.GOLD, Color(1.0, 0.85, 0.3))
	add_button_animations(shield_upgrade_btn)
	shield_hbox.add_child(shield_upgrade_btn)
	shield_upgrade_btn.pressed.connect(func(): _upgrade_stat("shield"))
	
	# Back Button
	research_back_btn = Button.new()
	research_back_btn.custom_minimum_size = Vector2(250, 48)
	research_back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	style_button(research_back_btn, Color.LIGHT_GRAY, Color.WHITE)
	add_button_animations(research_back_btn)
	content.add_child(research_back_btn)
	research_back_btn.pressed.connect(_on_research_back_pressed)


# Hangar logic
func _on_hangar_pressed() -> void:
	refresh_hangar_ui()
	var tween = create_tween().set_parallel(true)
	menu_container.hide()
	hangar_container.show()
	hangar_container.scale = Vector2(0.8, 0.8)
	hangar_container.modulate.a = 0.0
	tween.tween_property(hangar_container, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(hangar_container, "modulate:a", 1.0, 0.2)


func _on_hangar_back_pressed() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(hangar_container, "scale", Vector2(0.8, 0.8), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(hangar_container, "modulate:a", 0.0, 0.15)
	
	tween.chain().tween_callback(func():
		hangar_container.hide()
		menu_container.show()
		menu_container.modulate.a = 0.0
		var in_tween = create_tween()
		in_tween.tween_property(menu_container, "modulate:a", 1.0, 0.15)
	)


func _select_shield(type: String) -> void:
	Global.shield_type = type
	Global.save_game(Global.selected_stage, Global.load_game_data().get("score", 0), Global.load_game_data().get("weapons", {}))
	update_shield_selection_visual()


func update_shield_selection_visual() -> void:
	if Global.shield_type == "parry":
		style_button(shield_parry_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
		shield_parry_btn.text = "▶ " + Global.translate("shield_parry_name") + " [SELECTED]"
		style_button(shield_mitigate_btn, Color(0.4, 0.4, 0.4), Color(0.6, 0.6, 0.6))
		shield_mitigate_btn.text = Global.translate("shield_mitigate_name")
	else:
		style_button(shield_parry_btn, Color(0.4, 0.4, 0.4), Color(0.6, 0.6, 0.6))
		shield_parry_btn.text = Global.translate("shield_parry_name")
		style_button(shield_mitigate_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
		shield_mitigate_btn.text = "▶ " + Global.translate("shield_mitigate_name") + " [SELECTED]"


func refresh_hangar_ui() -> void:
	var save_data = Global.load_game_data()
	var weapons = save_data.get("weapons", {})
	
	var beam_unlocked = weapons.get("beam", {}).get("analyzed", false)
	var beam_prog = weapons.get("beam", {}).get("progress", 0.0)
	var missile_unlocked = weapons.get("missile", {}).get("analyzed", false)
	var missile_prog = weapons.get("missile", {}).get("progress", 0.0)
	
	hangar_beam_progress.value = beam_prog if not beam_unlocked else 100.0
	hangar_missile_progress.value = missile_prog if not missile_unlocked else 100.0
	
	var beam_level = weapons.get("beam", {}).get("level", 1)
	var missile_level = weapons.get("missile", {}).get("level", 1)
	
	if beam_unlocked:
		hangar_beam_lbl.text = "BEAM LASER: ACTIVE (LV %d)" % beam_level
	else:
		hangar_beam_lbl.text = "BEAM LASER: ANALYZING..."
		
	if missile_unlocked:
		hangar_missile_lbl.text = "HOMING MISSILE: ACTIVE (LV %d)" % missile_level
	else:
		hangar_missile_lbl.text = "HOMING MISSILE: ANALYZING..."
		
	update_shield_selection_visual()


# Research logic
func _on_research_pressed() -> void:
	refresh_research_ui()
	var tween = create_tween().set_parallel(true)
	menu_container.hide()
	research_container.show()
	research_container.scale = Vector2(0.8, 0.8)
	research_container.modulate.a = 0.0
	tween.tween_property(research_container, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(research_container, "modulate:a", 1.0, 0.2)


func _on_research_back_pressed() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(research_container, "scale", Vector2(0.8, 0.8), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(research_container, "modulate:a", 0.0, 0.15)
	
	tween.chain().tween_callback(func():
		research_container.hide()
		menu_container.show()
		menu_container.modulate.a = 0.0
		var in_tween = create_tween()
		in_tween.tween_property(menu_container, "modulate:a", 1.0, 0.15)
	)


func refresh_research_ui() -> void:
	var save_data = Global.load_game_data()
	var score = save_data.get("score", 0)
	
	# Current levels from Global properties
	var hp_lvl = Global.hp_upgrade_level
	var speed_lvl = Global.speed_upgrade_level
	var shield_lvl = Global.shield_upgrade_level
	
	# Score is used as Research Credits
	research_credits_lbl.text = Global.translate("research_credits") % score
	
	# 1. HP UI
	var current_hp = 100 + (hp_lvl - 1) * 20
	var next_hp = current_hp + 20
	hp_level_lbl.text = Global.translate("research_hp_title") + " - LV %d" % hp_lvl
	hp_desc_lbl.text = Global.translate("research_hp_desc") % [current_hp, next_hp]
	_setup_upgrade_button(hp_upgrade_btn, hp_lvl, score)
	
	# 2. Speed UI
	var current_speed = 300 + (speed_lvl - 1) * 30
	var next_speed = current_speed + 30
	speed_level_lbl.text = Global.translate("research_speed_title") + " - LV %d" % speed_lvl
	speed_desc_lbl.text = Global.translate("research_speed_desc") % [current_speed, next_speed]
	_setup_upgrade_button(speed_upgrade_btn, speed_lvl, score)
	
	# 3. Shield UI
	var current_cooldown_red = (shield_lvl - 1) * 0.3 # Reduce 0.3s per level
	var next_cooldown_red = current_cooldown_red + 0.3
	shield_level_lbl.text = Global.translate("research_shield_title") + " - LV %d" % shield_lvl
	shield_desc_lbl.text = Global.translate("research_shield_desc") % [current_cooldown_red, next_cooldown_red]
	_setup_upgrade_button(shield_upgrade_btn, shield_lvl, score)


func get_upgrade_cost(level: int) -> int:
	match level:
		1: return 2500
		2: return 6000
		3: return 15000
		4: return 35000
		_: return 999999


func _setup_upgrade_button(btn: Button, lvl: int, score: int) -> void:
	if lvl >= 5:
		btn.disabled = true
		btn.text = Global.translate("btn_upgrade_max")
		style_button(btn, Color(0.4, 0.4, 0.4), Color(0.5, 0.5, 0.5))
	else:
		var cost = get_upgrade_cost(lvl)
		btn.text = Global.translate("btn_upgrade") % cost
		if score >= cost:
			btn.disabled = false
			style_button(btn, Color.GOLD, Color(1.0, 0.85, 0.3))
		else:
			btn.disabled = true
			btn.text = Global.translate("insufficient_credits") + " (%d TB)" % cost
			style_button(btn, Color(0.5, 0.2, 0.2), Color(0.6, 0.3, 0.3))


func _upgrade_stat(stat: String) -> void:
	var save_data = Global.load_game_data()
	var score = save_data.get("score", 0)
	
	match stat:
		"hp":
			var cost = get_upgrade_cost(Global.hp_upgrade_level)
			if score >= cost and Global.hp_upgrade_level < 5:
				score -= cost
				Global.hp_upgrade_level += 1
		"speed":
			var cost = get_upgrade_cost(Global.speed_upgrade_level)
			if score >= cost and Global.speed_upgrade_level < 5:
				score -= cost
				Global.speed_upgrade_level += 1
		"shield":
			var cost = get_upgrade_cost(Global.shield_upgrade_level)
			if score >= cost and Global.shield_upgrade_level < 5:
				score -= cost
				Global.shield_upgrade_level += 1
				
	# Save updated score and upgrade levels
	Global.save_game(
		save_data.get("stage_num", 1),
		score,
		save_data.get("weapons", {})
	)
	refresh_research_ui()


# Pre-battle / Weapon Select helpers
func _select_pre_shield(type: String) -> void:
	Global.shield_type = type
	Global.save_game(Global.selected_stage, Global.load_game_data().get("score", 0), Global.load_game_data().get("weapons", {}))
	update_pre_battle_visuals()


func _select_pre_weapon(type: String) -> void:
	Global.starting_weapon = type
	Global.save_game(Global.selected_stage, Global.load_game_data().get("score", 0), Global.load_game_data().get("weapons", {}))
	update_pre_battle_visuals()


func update_pre_battle_visuals() -> void:
	if not pre_battle_container or not pre_battle_container.visible:
		return
		
	# Titles
	briefing_title_label.text = Global.translate("sortie_title")
	
	var left_t = pre_battle_container.find_child("LeftTitle", true, false)
	if left_t: left_t.text = Global.translate("sortie_briefing")
	
	var right_t = pre_battle_container.find_child("RightTitle", true, false)
	if right_t: right_t.text = Global.translate("sortie_equipment")
	
	var shield_t = pre_battle_container.find_child("ShieldTitle", true, false)
	if shield_t: shield_t.text = Global.translate("hangar_shield_select")
	
	var weapon_t = pre_battle_container.find_child("WeaponTitle", true, false)
	if weapon_t: weapon_t.text = Global.translate("sortie_equipment")
	
	launch_btn.text = Global.translate("btn_launch")
	pre_battle_back_btn.text = Global.translate("btn_cancel")
	
	# Shield status sync
	pre_shield_parry_btn.text = Global.translate("shield_parry_name")
	pre_shield_mitigate_btn.text = Global.translate("shield_mitigate_name")
	
	if Global.shield_type == "parry":
		style_button(pre_shield_parry_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
		pre_shield_parry_btn.text = "▶ " + pre_shield_parry_btn.text + " [" + Global.translate("weapon_active_lbl") + "]"
		style_button(pre_shield_mitigate_btn, Color(0.4, 0.4, 0.4), Color(0.6, 0.6, 0.6))
		pre_shield_desc_lbl.text = Global.translate("shield_parry_desc")
	else:
		style_button(pre_shield_parry_btn, Color(0.4, 0.4, 0.4), Color(0.6, 0.6, 0.6))
		style_button(pre_shield_mitigate_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
		pre_shield_mitigate_btn.text = "▶ " + pre_shield_mitigate_btn.text + " [" + Global.translate("weapon_active_lbl") + "]"
		pre_shield_desc_lbl.text = Global.translate("shield_mitigate_desc")
		
	# Weapon status sync
	var save_data = Global.load_game_data()
	var weapons = save_data.get("weapons", {})
	
	var beam_unlocked = weapons.get("beam", {}).get("analyzed", false)
	var beam_prog = weapons.get("beam", {}).get("progress", 0.0)
	var beam_level = weapons.get("beam", {}).get("level", 1)
	
	var missile_unlocked = weapons.get("missile", {}).get("analyzed", false)
	var missile_prog = weapons.get("missile", {}).get("progress", 0.0)
	var missile_level = weapons.get("missile", {}).get("level", 1)
	
	# Machine Gun
	pre_weapon_rifle_btn.text = Global.translate("weapon_rifle_name")
	pre_rifle_lbl.text = Global.translate("weapon_rifle_desc")
	if Global.starting_weapon == "none":
		style_button(pre_weapon_rifle_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
		pre_weapon_rifle_btn.text = "▶ " + pre_weapon_rifle_btn.text + " [" + Global.translate("weapon_active_lbl") + "]"
	else:
		style_button(pre_weapon_rifle_btn, Color(0.4, 0.4, 0.4), Color(0.6, 0.6, 0.6))
		
	# Beam Lasers
	pre_beam_prog_bar.value = beam_prog if not beam_unlocked else 100.0
	pre_beam_lbl.text = Global.translate("weapon_beam_desc")
	if beam_unlocked:
		pre_beam_prog_bar.hide()
		pre_weapon_beam_btn.disabled = false
		pre_weapon_beam_btn.text = Global.translate("weapon_beam_name") + " (LV %d)" % beam_level
		if Global.starting_weapon == "beam":
			style_button(pre_weapon_beam_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
			pre_weapon_beam_btn.text = "▶ " + pre_weapon_beam_btn.text + " [" + Global.translate("weapon_active_lbl") + "]"
		else:
			style_button(pre_weapon_beam_btn, Color(0.5, 0.8, 1.0), Color(0.7, 0.9, 1.0))
	else:
		pre_beam_prog_bar.show()
		pre_weapon_beam_btn.disabled = true
		style_button(pre_weapon_beam_btn, Color(0.3, 0.3, 0.3), Color(0.3, 0.3, 0.3))
		pre_weapon_beam_btn.text = Global.translate("weapon_beam_name") + " [" + Global.translate("weapon_locked_lbl") + "]"
		pre_beam_lbl.text = Global.translate("weapon_locked_msg")
		
	# Missile System
	pre_missile_prog_bar.value = missile_prog if not missile_unlocked else 100.0
	pre_missile_lbl.text = Global.translate("weapon_missile_desc")
	if missile_unlocked:
		pre_missile_prog_bar.hide()
		pre_weapon_missile_btn.disabled = false
		pre_weapon_missile_btn.text = Global.translate("weapon_missile_name") + " (LV %d)" % missile_level
		if Global.starting_weapon == "missile":
			style_button(pre_weapon_missile_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
			pre_weapon_missile_btn.text = "▶ " + pre_weapon_missile_btn.text + " [" + Global.translate("weapon_active_lbl") + "]"
		else:
			style_button(pre_weapon_missile_btn, Color(0.5, 0.8, 1.0), Color(0.7, 0.9, 1.0))
	else:
		pre_missile_prog_bar.show()
		pre_weapon_missile_btn.disabled = true
		style_button(pre_weapon_missile_btn, Color(0.3, 0.3, 0.3), Color(0.3, 0.3, 0.3))
		pre_weapon_missile_btn.text = Global.translate("weapon_missile_name") + " [" + Global.translate("weapon_locked_lbl") + "]"
		pre_missile_lbl.text = Global.translate("weapon_locked_msg")
