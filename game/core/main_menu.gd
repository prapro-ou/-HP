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

# Menu, Settings and Hangar screens
var menu_container: VBoxContainer
var settings_container: PanelContainer
var confirm_dialog: PanelContainer
var hangar_container: PanelContainer  # Hangar Panel

# Buttons
var continue_btn: Button
var new_game_btn: Button
var hangar_btn: Button  # Hangar open button
var settings_btn: Button
var quit_btn: Button
var autoscale_btn: Button
var hangar_back_btn: Button
var hangar_equip_btn: Button

# Settings UI inputs
var mode_option: OptionButton
var scale_option: OptionButton
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

# Hangar UI specific nodes
var hangar_weapon_list: VBoxContainer
var hangar_desc_label: Label
var hangar_stats_label: Label
var hangar_preview_panel: PanelContainer

# Preview/Animation variables
var preview_timer: float = 0.0
var preview_bullets_array: Array = []
var selected_hangar_weapon: String = "machine_gun"

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
	if hangar_container and hangar_container.visible:
		update_weapon_preview(delta)

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
	
	# 7. Custom confirmation dialog (Hidden initially)
	setup_confirm_dialog()
	
	# 8. Hangar Container (Hidden initially)
	setup_hangar_container()

func setup_menu_container() -> void:
	menu_container = VBoxContainer.new()
	menu_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_container.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_container.theme_type_variation = "VBoxContainer"
	menu_container.add_theme_constant_override("separation", 20)
	main_vbox.add_child(menu_container)
	
	# Continue Button
	continue_btn = Button.new()
	continue_btn.text = "続きから / CONTINUE"
	continue_btn.custom_minimum_size = Vector2(320, 60)
	continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_container.add_child(continue_btn)
	style_button(continue_btn, Color.GOLD, Color(1.0, 0.85, 0.3))
	add_button_animations(continue_btn)
	
	# Start New Game Button
	new_game_btn = Button.new()
	new_game_btn.text = "初めから / START GAME"
	new_game_btn.custom_minimum_size = Vector2(320, 60)
	new_game_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_container.add_child(new_game_btn)
	style_button(new_game_btn, Color.CYAN, Color(0.3, 0.9, 1.0))
	add_button_animations(new_game_btn)
	
	# Hangar / Weapon Selection Button
	hangar_btn = Button.new()
	hangar_btn.text = "兵装選択 / HANGAR"
	hangar_btn.custom_minimum_size = Vector2(320, 60)
	hangar_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_container.add_child(hangar_btn)
	style_button(hangar_btn, Color.GREEN, Color(0.2, 1.0, 0.6))
	add_button_animations(hangar_btn)
	
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
	
	# Small spacer
	var spacer_b = Control.new()
	spacer_b.custom_minimum_size = Vector2(0, 30)
	menu_container.add_child(spacer_b)
	
	# One-touch Auto Scale Button
	autoscale_btn = Button.new()
	autoscale_btn.text = "🖥️ 画面サイズをPCに自動最適化"
	autoscale_btn.custom_minimum_size = Vector2(340, 50)
	autoscale_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_container.add_child(autoscale_btn)
	style_button(autoscale_btn, Color(0.0, 1.0, 0.5), Color(0.2, 1.0, 0.7))
	add_button_animations(autoscale_btn)
	
	# Setup button signals
	new_game_btn.pressed.connect(_on_new_game_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	hangar_btn.pressed.connect(_on_hangar_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	autoscale_btn.pressed.connect(_on_autoscale_pressed)
	
	# Handle Continue availability
	if Global.has_save:
		continue_btn.disabled = false
		var save_data = Global.load_game_data()
		var s_num = save_data.get("stage_num", 1)
		var score = save_data.get("score", 0)
		# Add helper status label below continue button text
		continue_btn.text = "続きから / CONTINUE\n[Stage " + str(s_num) + " - Score: " + str(score) + "]"
	else:
		continue_btn.disabled = true
		continue_btn.text = "続きから / CONTINUE\n[No Save Data]"

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
	settings_title.text = "環境設定 - SETTINGS"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_set = LabelSettings.new()
	title_set.font_size = 22
	title_set.font_color = Color(0.9, 0.6, 1.0)
	title_set.outline_size = 4
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
	
	# Mode
	grid_display.add_child(create_label("画面モード (Window Mode):"))
	mode_option = OptionButton.new()
	mode_option.add_item("ウィンドウ / Windowed", 0)
	mode_option.add_item("フルスクリーン / Fullscreen", 1)
	mode_option.add_item("ボーダレス / Borderless", 2)
	mode_option.custom_minimum_size = Vector2(200, 32)
	grid_display.add_child(mode_option)
	
	# Resolution / Scale (Vertical formats only)
	grid_display.add_child(create_label("画面スケール (Vertical Size):"))
	scale_option = OptionButton.new()
	scale_option.add_item("400x600 (0.50x)", 0)
	scale_option.add_item("600x900 (0.75x)", 1)
	scale_option.add_item("800x1200 (1.00x)", 2)
	scale_option.add_item("1000x1500 (1.25x)", 3)
	scale_option.custom_minimum_size = Vector2(200, 32)
	grid_display.add_child(scale_option)
	
	# VSync
	grid_display.add_child(create_label("垂直同期 (V-Sync):"))
	vsync_check = CheckButton.new()
	vsync_check.text = ""
	grid_display.add_child(vsync_check)
	
	# Shake
	grid_display.add_child(create_label("画面の揺れ (Screen Shake):"))
	shake_check = CheckButton.new()
	shake_check.text = ""
	grid_display.add_child(shake_check)
	
	# --- SECTION 2: AUDIO ---
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
	
	# --- SECTION 3: SYSTEM/DATA ---
	var s_title = Label.new()
	s_title.text = "データ管理 / DATA"
	s_title.label_settings = sec_set
	scroll_content.add_child(s_title)
	
	reset_btn = Button.new()
	reset_btn.text = "セーブデータを初期化する / RESET SAVE DATA"
	reset_btn.custom_minimum_size = Vector2(300, 36)
	style_button(reset_btn, Color(0.9, 0.2, 0.2), Color(1.0, 0.4, 0.4))
	scroll_content.add_child(reset_btn)
	
	# Save & Back
	back_btn = Button.new()
	back_btn.text = "適用して戻る / SAVE & BACK"
	back_btn.custom_minimum_size = Vector2(250, 48)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(back_btn)
	style_button(back_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
	add_button_animations(back_btn)
	
	# Connect signals
	mode_option.item_selected.connect(_on_display_mode_changed)
	scale_option.item_selected.connect(_on_display_scale_changed)
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
	confirm_dialog.custom_minimum_size = Vector2(400, 220)
	confirm_dialog.hide()
	add_child(confirm_dialog)
	
	# Center it on top of everything
	confirm_dialog.anchor_left = 0.5
	confirm_dialog.anchor_top = 0.5
	confirm_dialog.anchor_right = 0.5
	confirm_dialog.anchor_bottom = 0.5
	confirm_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	confirm_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	confirm_dialog.offset_left = -200
	confirm_dialog.offset_top = -110
	
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
		# Update main menu continue button
		continue_btn.disabled = true
		continue_btn.text = "続きから / CONTINUE\n[No Save Data]"
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
	
	# Resolving scale selection indices (0.5, 0.75, 1.0, 1.25)
	if abs(Global.window_scale - 0.5) < 0.05:
		scale_option.selected = 0
	elif abs(Global.window_scale - 0.75) < 0.05:
		scale_option.selected = 1
	elif abs(Global.window_scale - 1.25) < 0.05:
		scale_option.selected = 3
	else:
		scale_option.selected = 2 # 1.0x default
		
	# Disable resolution selection if in fullscreen
	if Global.window_mode == 1:
		scale_option.disabled = true
	else:
		scale_option.disabled = false
		
	vsync_check.button_pressed = Global.vsync
	shake_check.button_pressed = Global.screen_shake
	
	master_slider.value = Global.master_volume
	master_lbl.text = str(int(Global.master_volume)) + "%"
	
	bgm_slider.value = Global.bgm_volume
	bgm_lbl.text = str(int(Global.bgm_volume)) + "%"
	
	sfx_slider.value = Global.sfx_volume
	sfx_lbl.text = str(int(Global.sfx_volume)) + "%"

func _on_new_game_pressed() -> void:
	Global.is_continue = false
	get_tree().change_scene_to_file("res://game/main.tscn")

func _on_continue_pressed() -> void:
	Global.is_continue = true
	get_tree().change_scene_to_file("res://game/main.tscn")

func _on_settings_pressed() -> void:
	# Transition: hide menu container, show settings panel
	var tween = create_tween().set_parallel(true)
	menu_container.hide()
	settings_container.show()
	settings_container.scale = Vector2(0.8, 0.8)
	settings_container.modulate.a = 0.0
	tween.tween_property(settings_container, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(settings_container, "modulate:a", 1.0, 0.2)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_autoscale_pressed() -> void:
	Global.auto_scale_display()
	sync_settings_to_ui()
	
	# Neon flash indicator
	var orig_color = autoscale_btn.get_theme_stylebox("normal").border_color
	var tween = create_tween()
	autoscale_btn.add_theme_color_override("font_color", Color.BLACK)
	tween.tween_method(func(val: float):
		var sb = autoscale_btn.get_theme_stylebox("normal")
		if sb:
			sb.bg_color = Color.WHITE.lerp(Color(0.06, 0.06, 0.1, 0.8), val)
			sb.border_color = Color.WHITE.lerp(orig_color, val)
	, 0.0, 1.0, 0.4)
	tween.chain().tween_callback(func(): autoscale_btn.add_theme_color_override("font_color", Color.WHITE))

func _on_display_mode_changed(idx: int) -> void:
	Global.window_mode = idx
	if idx == 1:
		scale_option.disabled = true
	else:
		scale_option.disabled = false
	Global.apply_display()

func _on_display_scale_changed(idx: int) -> void:
	match idx:
		0: Global.window_scale = 0.5
		1: Global.window_scale = 0.75
		2: Global.window_scale = 1.0
		3: Global.window_scale = 1.25
	Global.apply_display()

func _on_reset_btn_pressed() -> void:
	confirm_dialog.show()
	confirm_dialog.scale = Vector2(0.9, 0.9)
	var tween = create_tween()
	tween.tween_property(confirm_dialog, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_back_btn_pressed() -> void:
	Global.save_settings()
	
	# Transition settings panel out and menu container in
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
	# Drawing stars
	for s in stars:
		draw_circle(s.pos, s.size, s.color)
		
	# Drawing cyber-grid lines (retro aesthetic scanlines)
	var rect = get_viewport_rect()
	var spacing = 8
	for y in range(0, int(rect.size.y), spacing):
		draw_line(Vector2(0, y), Vector2(rect.size.x, y), Color(0, 0, 0, 0.16), 1.0)

func animate_menu_entry() -> void:
	# Animating initial menu load
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
	# Pulsing glow of title text
	var pulse = 1.0 + sin(time_passed * 2.5) * 0.03
	title_label.scale = Vector2(pulse, pulse)
	
	# Slight chromatic neon color pulse
	var blue_glow = Color(0.2, 0.8 + sin(time_passed * 3.0) * 0.15, 1.0)
	title_label.label_settings.font_color = blue_glow


# ----------------- Hangar & Weapon Selection Screen -----------------

func setup_hangar_container() -> void:
	hangar_container = PanelContainer.new()
	hangar_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hangar_container.custom_minimum_size = Vector2(650, 750)
	hangar_container.hide()
	main_vbox.add_child(hangar_container)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.1, 0.96)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.0, 0.9, 0.5, 0.8) # Green sci-fi border
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.shadow_color = Color(0.0, 0.9, 0.5, 0.2)
	sb.shadow_size = 15
	hangar_container.add_theme_stylebox_override("panel", sb)
	
	var margin_inner = MarginContainer.new()
	margin_inner.add_theme_constant_override("margin_left", 20)
	margin_inner.add_theme_constant_override("margin_top", 20)
	margin_inner.add_theme_constant_override("margin_right", 20)
	margin_inner.add_theme_constant_override("margin_bottom", 20)
	hangar_container.add_child(margin_inner)
	
	var main_layout = VBoxContainer.new()
	main_layout.add_theme_constant_override("separation", 15)
	margin_inner.add_child(main_layout)
	
	var header = Label.new()
	header.text = "兵装選択 / HANGAR SYSTEMS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var head_settings = LabelSettings.new()
	head_settings.font_size = 24
	head_settings.font_color = Color(0.1, 1.0, 0.6)
	head_settings.outline_size = 6
	head_settings.outline_color = Color.BLACK
	header.label_settings = head_settings
	main_layout.add_child(header)
	
	var content_hbox = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 20)
	main_layout.add_child(content_hbox)
	
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(250, 0)
	left_vbox.add_theme_constant_override("separation", 12)
	content_hbox.add_child(left_vbox)
	
	var list_title = Label.new()
	list_title.text = "SELECT PHYSICAL UNIT:"
	var lt_set = LabelSettings.new()
	lt_set.font_size = 12
	lt_set.font_color = Color.LIGHT_GRAY
	list_title.label_settings = lt_set
	left_vbox.add_child(list_title)
	
	hangar_weapon_list = VBoxContainer.new()
	hangar_weapon_list.add_theme_constant_override("separation", 10)
	left_vbox.add_child(hangar_weapon_list)
	
	# Build Weapon List Buttons initial
	rebuild_hangar_weapon_list()
	
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 12)
	content_hbox.add_child(right_vbox)
	
	var right_header = Label.new()
	right_header.name = "WeaponName"
	right_header.text = "SELECT A WEAPON"
	var rh_settings = LabelSettings.new()
	rh_settings.font_size = 20
	rh_settings.font_color = Color.CYAN
	right_header.label_settings = rh_settings
	right_vbox.add_child(right_header)
	
	hangar_stats_label = Label.new()
	hangar_stats_label.text = "DMG: - | RATE: - | VEL: -"
	var st_set = LabelSettings.new()
	st_set.font_size = 12
	st_set.font_color = Color.GOLD
	hangar_stats_label.label_settings = st_set
	right_vbox.add_child(hangar_stats_label)
	
	hangar_desc_label = Label.new()
	hangar_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hangar_desc_label.custom_minimum_size = Vector2(300, 70)
	var desc_set = LabelSettings.new()
	desc_set.font_size = 13
	desc_set.font_color = Color.LIGHT_GRAY
	hangar_desc_label.label_settings = desc_set
	right_vbox.add_child(hangar_desc_label)
	
	var prev_title = Label.new()
	prev_title.text = "WEAPON FIELD PREVIEW:"
	var pt_set = LabelSettings.new()
	pt_set.font_size = 11
	pt_set.font_color = Color.DARK_GRAY
	prev_title.label_settings = pt_set
	right_vbox.add_child(prev_title)
	
	hangar_preview_panel = PanelContainer.new()
	hangar_preview_panel.custom_minimum_size = Vector2(300, 240)
	hangar_preview_panel.clip_contents = true
	right_vbox.add_child(hangar_preview_panel)
	
	var pb_style = StyleBoxFlat.new()
	pb_style.bg_color = Color(0.02, 0.02, 0.04, 1.0)
	pb_style.border_width_left = 2
	pb_style.border_width_top = 2
	pb_style.border_width_right = 2
	pb_style.border_width_bottom = 2
	pb_style.border_color = Color(0.1, 0.3, 0.2, 0.8)
	pb_style.corner_radius_top_left = 6
	pb_style.corner_radius_top_right = 6
	pb_style.corner_radius_bottom_left = 6
	pb_style.corner_radius_bottom_right = 6
	hangar_preview_panel.add_theme_stylebox_override("panel", pb_style)
	
	var preview_canvas = Control.new()
	preview_canvas.name = "PreviewCanvas"
	preview_canvas.custom_minimum_size = Vector2(300, 240)
	hangar_preview_panel.add_child(preview_canvas)
	
	var dummy_ship = ColorRect.new()
	dummy_ship.name = "DummyShip"
	dummy_ship.color = Color.CYAN
	dummy_ship.custom_minimum_size = Vector2(16, 16)
	dummy_ship.size = Vector2(16, 16)
	dummy_ship.position = Vector2(142, 210)
	preview_canvas.add_child(dummy_ship)
	
	var act_hbox = HBoxContainer.new()
	act_hbox.alignment = BoxContainer.ALIGNMENT_END
	act_hbox.add_theme_constant_override("separation", 15)
	main_layout.add_child(act_hbox)
	
	hangar_equip_btn = Button.new()
	hangar_equip_btn.text = "EQUIP SYSTEM"
	hangar_equip_btn.custom_minimum_size = Vector2(160, 45)
	act_hbox.add_child(hangar_equip_btn)
	style_button(hangar_equip_btn, Color.CYAN, Color(0.3, 0.9, 1.0))
	add_button_animations(hangar_equip_btn)
	
	hangar_back_btn = Button.new()
	hangar_back_btn.text = "RETURN TO SYSTEM"
	hangar_back_btn.custom_minimum_size = Vector2(180, 45)
	act_hbox.add_child(hangar_back_btn)
	style_button(hangar_back_btn, Color(0.8, 0.4, 1.0), Color(0.9, 0.6, 1.0))
	add_button_animations(hangar_back_btn)
	
	hangar_equip_btn.pressed.connect(_on_hangar_equip_pressed)
	hangar_back_btn.pressed.connect(_on_hangar_back_pressed)
	
	select_hangar_weapon(Global.equipped_weapon)


func rebuild_hangar_weapon_list() -> void:
	if not hangar_weapon_list:
		return
	for child in hangar_weapon_list.get_children():
		child.queue_free()
		
	for w_key in Global.available_weapons.keys():
		var w_data = Global.available_weapons[w_key]
		var btn = Button.new()
		var is_equipped = (w_key == Global.equipped_weapon)
		
		btn.text = ("▶ [EQUIPPED] " if is_equipped else "") + w_data["name"]
		btn.custom_minimum_size = Vector2(240, 50)
		hangar_weapon_list.add_child(btn)
		
		if is_equipped:
			style_button(btn, Color.GOLD, Color(1.0, 0.85, 0.3))
		else:
			style_button(btn, Color.LIGHT_GRAY, Color.WHITE)
			
		add_button_animations(btn)
		btn.pressed.connect(func():
			select_hangar_weapon(w_key)
		)


func select_hangar_weapon(w_key: String) -> void:
	selected_hangar_weapon = w_key
	var w_data = Global.available_weapons[w_key]
	
	clear_preview_bullets()
	preview_timer = 0.0
	
	var name_lbl = hangar_preview_panel.get_parent().get_node("WeaponName")
	if name_lbl:
		name_lbl.text = w_data["name"]
		if w_key == Global.equipped_weapon:
			name_lbl.text += " (EQUIPPED)"
			name_lbl.label_settings.font_color = Color.GOLD
		else:
			name_lbl.label_settings.font_color = Color.CYAN
			
	hangar_desc_label.text = w_data["description"]
	hangar_stats_label.text = w_data["stats"]
	
	if w_key == Global.equipped_weapon:
		hangar_equip_btn.text = "CURRENTLY EQUIPPED"
		hangar_equip_btn.disabled = true
	else:
		hangar_equip_btn.text = "EQUIP SYSTEM"
		hangar_equip_btn.disabled = false


func _on_hangar_equip_pressed() -> void:
	Global.equipped_weapon = selected_hangar_weapon
	var save_data = Global.load_game_data()
	Global.save_game(save_data.get("stage_num", 1), save_data.get("score", 0), save_data.get("weapons", {}))
	
	rebuild_hangar_weapon_list()
	select_hangar_weapon(selected_hangar_weapon)
	
	var flash_tween = create_tween()
	hangar_container.modulate = Color(1.5, 1.5, 1.5)
	flash_tween.tween_property(hangar_container, "modulate", Color.WHITE, 0.2)


func _on_hangar_back_pressed() -> void:
	clear_preview_bullets()
	hangar_container.hide()
	menu_container.show()
	title_label.show()
	subtitle_label.show()
	
	if Global.has_save:
		continue_btn.disabled = false
		var save_data = Global.load_game_data()
		continue_btn.text = "続きから / CONTINUE\n[Stage " + str(save_data.get("stage_num", 1)) + " - Score: " + str(save_data.get("score", 0)) + "]"
	else:
		continue_btn.disabled = true


func _on_hangar_pressed() -> void:
	menu_container.hide()
	title_label.hide()
	subtitle_label.hide()
	hangar_container.show()
	
	# Transition animation for hangar entry
	hangar_container.scale = Vector2(0.85, 0.85)
	hangar_container.modulate.a = 0.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(hangar_container, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(hangar_container, "modulate:a", 1.0, 0.25)
	
	rebuild_hangar_weapon_list()
	select_hangar_weapon(Global.equipped_weapon)


func update_weapon_preview(delta: float) -> void:
	preview_timer += delta
	
	# 1. Move & delete preview bullets
	var bullets_to_remove = []
	for b in preview_bullets_array:
		if is_instance_valid(b):
			var b_speed = b.get_meta("speed", 400.0)
			var b_dir = b.get_meta("dir", Vector2.UP)
			b.position += b_dir * b_speed * delta
			
			# Check out of boundary for preview container (300x240)
			if b.position.y < -30 or b.position.y > 270 or b.position.x < -30 or b.position.x > 330:
				bullets_to_remove.append(b)
				b.queue_free()
		else:
			bullets_to_remove.append(b)
			
	for b in bullets_to_remove:
		preview_bullets_array.erase(b)
		
	# 2. Control shooting interval by weapon
	var fire_interval = 0.2
	match selected_hangar_weapon:
		"machine_gun":
			fire_interval = 0.15
			if preview_timer >= fire_interval:
				preview_timer = 0.0
				# Alternate firing yellow machine gun lines
				var left_turn = (int(Time.get_ticks_msec() / 150) % 2 == 0)
				var spawn_x = 138 if left_turn else 158
				spawn_preview_bullet(Vector2(spawn_x, 205), Vector2.UP, 500.0, Color(1.0, 0.8, 0.3), Vector2(4, 10))
				
		"burst_rifle":
			fire_interval = 0.52
			if preview_timer >= fire_interval:
				preview_timer = 0.0
				# 3-round burst
				for i in range(3):
					get_tree().create_timer(i * 0.08).timeout.connect(func():
						if is_instance_valid(hangar_container) and hangar_container.visible and selected_hangar_weapon == "burst_rifle":
							spawn_preview_bullet(Vector2(150, 205), Vector2.UP, 620.0, Color(1.0, 0.45, 0.1), Vector2(3, 14))
					)
					
		"charge_rifle":
			fire_interval = 1.35
			var canvas = hangar_preview_panel.get_node_or_null("PreviewCanvas")
			if canvas:
				var dummy = canvas.get_node_or_null("DummyShip")
				if dummy:
					if preview_timer < 1.0:
						var pulse = sin(Time.get_ticks_msec() * 0.015) * 0.4 + 0.6
						dummy.modulate = Color(0.3, 0.7, 1.0) * pulse
					else:
						dummy.modulate = Color(1.5, 1.5, 2.0)
						
			if preview_timer >= fire_interval:
				preview_timer = 0.0
				# Large rail bolt laser
				spawn_preview_bullet(Vector2(150, 205), Vector2.UP, 780.0, Color(0.3, 0.8, 1.0), Vector2(9, 28))
				
		"pulse_gun":
			fire_interval = 0.24
			if preview_timer >= fire_interval:
				preview_timer = 0.0
				# Twin expanding green pulse arcs
				var angles = [-12.0, 12.0]
				for angle in angles:
					var rad = deg_to_rad(angle)
					var dir = Vector2.UP.rotated(rad)
					var bullet = spawn_preview_bullet(Vector2(150, 205), dir, 420.0, Color(0.2, 1.0, 0.6), Vector2(8, 4))
					if bullet:
						bullet.rotation = rad


func spawn_preview_bullet(pos: Vector2, direction: Vector2, speed: float, color: Color, size: Vector2) -> ColorRect:
	var canvas = hangar_preview_panel.get_node_or_null("PreviewCanvas")
	if not canvas:
		return null
		
	var bullet = ColorRect.new()
	bullet.color = color
	bullet.size = size
	bullet.pivot_offset = size / 2.0
	bullet.position = pos - (size / 2.0)
	
	canvas.add_child(bullet)
	bullet.set_meta("speed", speed)
	bullet.set_meta("dir", direction)
	
	preview_bullets_array.append(bullet)
	return bullet


func clear_preview_bullets() -> void:
	for b in preview_bullets_array:
		if is_instance_valid(b):
			b.queue_free()
	preview_bullets_array.clear()
