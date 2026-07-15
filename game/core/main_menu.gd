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

# Menu and screens
var menu_container: VBoxContainer
var settings_container: PanelContainer
var stage_select_container: PanelContainer
var pre_battle_container: PanelContainer
var confirm_dialog: PanelContainer

# Buttons
var new_game_btn: Button
var settings_btn: Button
var quit_btn: Button

# Stage buttons
var stage1_btn: Button
var stage2_btn: Button
var stage_back_btn: Button

# Pre-battle UI elements
var briefing_label: Label
var player_status_label: Label
var launch_btn: Button
var pre_battle_back_btn: Button

# Settings UI inputs
var mode_option: OptionButton
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
	subtitle_label.text = "PARRY TO ANALYZE - SURVIVE THE BULLETS"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub_set = LabelSettings.new()
	sub_set.font_size = 14
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
	
	# 7. Stage Select Container (Hidden initially)
	setup_stage_select_container()
	
	# 8. Pre-battle Container (Hidden initially)
	setup_pre_battle_container()
	
	# 9. Custom confirmation dialog (Hidden initially)
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
	new_game_btn.text = "ゲーム開始 / START GAME"
	new_game_btn.custom_minimum_size = Vector2(320, 60)
	new_game_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_container.add_child(new_game_btn)
	style_button(new_game_btn, Color.CYAN, Color(0.3, 0.9, 1.0))
	add_button_animations(new_game_btn)
	
	# Settings Button
	settings_btn = Button.new()
	settings_btn.text = "環境設定 / SETTINGS"
	settings_btn.custom_minimum_size = Vector2(320, 60)
	settings_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_container.add_child(settings_btn)
	style_button(settings_btn, Color(0.8, 0.4, 1.0), Color(0.9, 0.6, 1.0))
	add_button_animations(settings_btn)
	
	# Quit Button
	quit_btn = Button.new()
	quit_btn.text = "ゲーム終了 / QUIT"
	quit_btn.custom_minimum_size = Vector2(320, 60)
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_container.add_child(quit_btn)
	style_button(quit_btn, Color(0.8, 0.2, 0.2), Color(1.0, 0.4, 0.4))
	add_button_animations(quit_btn)
	
	# Setup button signals
	new_game_btn.pressed.connect(_on_new_game_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

func setup_settings_container() -> void:
	settings_container = PanelContainer.new()
	settings_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	settings_container.custom_minimum_size = Vector2(480, 600)
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
	title_set.font_size = 22
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
	d_title.text = "画面設定 / DISPLAY"
	var sec_set = LabelSettings.new()
	sec_set.font_size = 14
	sec_set.font_color = Color.CYAN
	d_title.label_settings = sec_set
	scroll_content.add_child(d_title)
	
	var grid_display = GridContainer.new()
	grid_display.columns = 2
	grid_display.add_theme_constant_override("h_separation", 15)
	grid_display.add_theme_constant_override("v_separation", 12)
	scroll_content.add_child(grid_display)
	
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
	reset_btn.text = "セーブデータを初期化する / RESET SAVE DATA"
	reset_btn.custom_minimum_size = Vector2(300, 36)
	style_button(reset_btn, Color(0.9, 0.2, 0.2), Color(1.0, 0.4, 0.4))
	scroll_content.add_child(reset_btn)
	
	back_btn = Button.new()
	back_btn.text = "適用して戻る / SAVE & BACK"
	back_btn.custom_minimum_size = Vector2(250, 48)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(back_btn)
	style_button(back_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
	add_button_animations(back_btn)
	
	# Connect signals
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
	var select_title = Label.new()
	select_title.text = "STAGE SELECT / 作戦領域選択"
	select_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_set = LabelSettings.new()
	title_set.font_size = 22
	title_set.font_color = Color(0.3, 0.8, 1.0)
	title_set.outline_size = 4
	title_set.outline_color = Color.BLACK
	select_title.label_settings = title_set
	content.add_child(select_title)
	
	var stage_list = VBoxContainer.new()
	stage_list.add_theme_constant_override("separation", 18)
	content.add_child(stage_list)
	
	# Stage 1 Button
	stage1_btn = Button.new()
	stage1_btn.text = "STAGE 01\nBEAM & MISSILE DRONES"
	stage1_btn.custom_minimum_size = Vector2(360, 70)
	style_button(stage1_btn, Color.CYAN, Color(0.5, 0.9, 1.0))
	add_button_animations(stage1_btn)
	stage_list.add_child(stage1_btn)
	stage1_btn.pressed.connect(func(): _on_stage_selected(1))
	
	# Stage 2 Button
	stage2_btn = Button.new()
	stage2_btn.text = "STAGE 02\nANCIENT GUARDIAN"
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
	stage_back_btn.text = "メインメニューに戻る / BACK"
	stage_back_btn.custom_minimum_size = Vector2(250, 48)
	stage_back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	style_button(stage_back_btn, Color.LIGHT_GRAY, Color.WHITE)
	add_button_animations(stage_back_btn)
	content.add_child(stage_back_btn)
	stage_back_btn.pressed.connect(_on_stage_back_pressed)

func setup_pre_battle_container() -> void:
	pre_battle_container = PanelContainer.new()
	pre_battle_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pre_battle_container.custom_minimum_size = Vector2(480, 520)
	pre_battle_container.hide()
	main_vbox.add_child(pre_battle_container)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, 0.95)
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
	pre_battle_container.add_theme_stylebox_override("panel", sb)
	
	var margin_inner = MarginContainer.new()
	margin_inner.add_theme_constant_override("margin_left", 25)
	margin_inner.add_theme_constant_override("margin_top", 25)
	margin_inner.add_theme_constant_override("margin_right", 25)
	margin_inner.add_theme_constant_override("margin_bottom", 25)
	pre_battle_container.add_child(margin_inner)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	margin_inner.add_child(content)
	
	# Title
	var briefing_title = Label.new()
	briefing_title.text = "MISSION BRIEFING / 作戦指令"
	briefing_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_set = LabelSettings.new()
	title_set.font_size = 22
	title_set.font_color = Color(1.0, 0.7, 0.2)
	title_set.outline_size = 4
	title_set.outline_color = Color.BLACK
	briefing_title.label_settings = title_set
	content.add_child(briefing_title)
	
	var detail_panel = PanelContainer.new()
	var dp_style = StyleBoxFlat.new()
	dp_style.bg_color = Color(0.04, 0.04, 0.06, 0.8)
	dp_style.corner_radius_top_left = 6
	dp_style.corner_radius_top_right = 6
	dp_style.corner_radius_bottom_left = 6
	dp_style.corner_radius_bottom_right = 6
	dp_style.content_margin_left = 15
	dp_style.content_margin_top = 15
	dp_style.content_margin_right = 15
	dp_style.content_margin_bottom = 15
	detail_panel.add_theme_stylebox_override("panel", dp_style)
	content.add_child(detail_panel)
	
	var detail_vbox = VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 12)
	detail_panel.add_child(detail_vbox)
	
	briefing_label = Label.new()
	briefing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var b_set = LabelSettings.new()
	b_set.font_size = 13
	b_set.line_spacing = 6
	briefing_label.label_settings = b_set
	detail_vbox.add_child(briefing_label)
	
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color(1.0, 0.7, 0.2, 0.3)
	detail_vbox.add_child(sep)
	
	player_status_label = Label.new()
	player_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var s_set = LabelSettings.new()
	s_set.font_size = 12
	s_set.font_color = Color(0.6, 0.9, 1.0)
	s_set.line_spacing = 4
	player_status_label.label_settings = s_set
	detail_vbox.add_child(player_status_label)
	
	var actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 20)
	content.add_child(actions)
	
	launch_btn = Button.new()
	launch_btn.text = "🖥️ 出撃開始 / LAUNCH"
	launch_btn.custom_minimum_size = Vector2(200, 50)
	style_button(launch_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
	add_button_animations(launch_btn)
	actions.add_child(launch_btn)
	launch_btn.pressed.connect(_on_launch_pressed)
	
	pre_battle_back_btn = Button.new()
	pre_battle_back_btn.text = "戻る / CANCEL"
	pre_battle_back_btn.custom_minimum_size = Vector2(160, 50)
	style_button(pre_battle_back_btn, Color.LIGHT_GRAY, Color.WHITE)
	add_button_animations(pre_battle_back_btn)
	actions.add_child(pre_battle_back_btn)
	pre_battle_back_btn.pressed.connect(_on_pre_battle_back_pressed)

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
	l_set.font_size = 13
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
	vsync_check.button_pressed = Global.vsync
	shake_check.button_pressed = Global.screen_shake
	
	master_slider.value = Global.master_volume
	master_lbl.text = str(int(Global.master_volume)) + "%"
	
	bgm_slider.value = Global.bgm_volume
	bgm_lbl.text = str(int(Global.bgm_volume)) + "%"
	
	sfx_slider.value = Global.sfx_volume
	sfx_lbl.text = str(int(Global.sfx_volume)) + "%"

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
	
	if max_unlocked >= 2:
		stage2_btn.disabled = false
		stage2_btn.text = "STAGE 02\nANCIENT GUARDIAN"
	else:
		stage2_btn.disabled = true
		stage2_btn.text = "🔒 STAGE 02\n[LOCKED - CLEAR STAGE 01]"

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
	
	# Briefing text setup
	var briefing_text = ""
	if stage_num == 1:
		briefing_text = "【領域】 作戦区域 01: ドローン警備網\n"
		briefing_text += "【脅威】 ビームドローン / ミサイルドローン\n\n"
		briefing_text += "【指令】 本セクターの自動警備部隊を無力化せよ。敵ドローンの弾幕をパリィすることで、その攻撃波形からエネルギー兵装データを抽出・複製可能。3回パリィで「BEAM」、さらに3回で「MISSILE」兵装のロックが解除される。"
	elif stage_num == 2:
		briefing_text = "【領域】 作戦区域 02: 古代防衛コア\n"
		briefing_text += "【脅威】 古代遺跡防衛要塞 (超大型ボス)\n\n"
		briefing_text += "【指令】 警備網深部の巨大防衛ユニットを撃破せよ。対象は破壊可能なサブアーム（レーザー部・ミサイル部）を持ち、コアを守っている。敵の攻撃エネルギー再配分比率を見極め、部位破壊を狙いコアを沈めよ。"
	
	briefing_label.text = briefing_text
	
	# Player weapons stats
	var save_data = Global.load_game_data()
	var weapons = save_data.get("weapons", {})
	
	var beam_status = "未解析"
	var missile_status = "未解析"
	if not weapons.is_empty():
		if weapons.get("beam", {}).get("analyzed", false):
			beam_status = "解析完了 (LV " + str(weapons["beam"].get("level", 1)) + ")"
		else:
			var prog = weapons.get("beam", {}).get("progress", 0.0) * 100.0
			beam_status = "データ収集中 (" + str(int(prog)) + "%)"
			
		if weapons.get("missile", {}).get("analyzed", false):
			missile_status = "解析完了 (LV " + str(weapons["missile"].get("level", 1)) + ")"
		else:
			var prog = weapons.get("missile", {}).get("progress", 0.0) * 100.0
			missile_status = "データ収集中 (" + str(int(prog)) + "%)"
			
	player_status_label.text = "【兵装解析アーカイブ状況】\n"
	player_status_label.text += "・ビームシステム:  " + beam_status + "\n"
	player_status_label.text += "・ミサイルシステム: " + missile_status
	
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
	# Start selected stage
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
