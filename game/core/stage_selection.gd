extends Control

# Stage metadata structure
class StageData:
	var id: int
	var title: String
	var codename: String
	var description: String
	var difficulty: String
	var color: Color
	var scene_path: String
	var bg_texture: Texture2D

var stages: Array[StageData] = []
var current_index: int = 0
var is_transitioning: bool = false

# UI Nodes reference
var background_color: ColorRect
var grid_overlay: Control
var stage_container: HBoxContainer
var stage_cards: Array[PanelContainer] = []
var detail_title: Label
var detail_codename: Label
var detail_desc: Label
var detail_diff: Label
var detail_panel: PanelContainer

# Navigation buttons
var prev_btn: Button
var next_btn: Button
var select_btn: Button
var tech_lab_btn: Button
var archive_btn: Button
var tips_btn: Button
var hard_mode_btn: Button
var menu_btn: Button
var archive_panel: PanelContainer
var tips_panel: PanelContainer
var tips_list_container: VBoxContainer
var tips_detail_panel: PanelContainer
var tips_filter_category: String = "all"
var selected_tip_id: String = ""
var tips_category_buttons: Dictionary = {}

# Starfield for sci-fi atmosphere
class BackgroundStar:
	var pos: Vector2
	var speed: float
	var size: float
	var color: Color

var stars: Array[BackgroundStar] = []
const NUM_STARS = 40
var time_passed: float = 0.0

func _ready() -> void:
	Global.load_settings()
	Global.check_save_game()
	
	# Stage Selection uses SFX only (Stop BGM)
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("stop_bgm"):
		audio_mgr.stop_bgm(0.3)
	
	var save_data = Global.load_game_data()
	var saved_stage_num = save_data.get("stage_num", 1)
	
	init_stages()
	
	current_index = clamp(saved_stage_num - 1, 0, stages.size() - 1)
	
	setup_ui()
	init_starfield()
	update_stage_selection(true) # Initial instant update

func _process(delta: float) -> void:
	time_passed += delta
	update_starfield(delta)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if is_transitioning:
		return
		
	if event.is_action_pressed("ui_left"):
		navigate_selection(-1)
	elif event.is_action_pressed("ui_right"):
		navigate_selection(1)
	elif event.is_action_pressed("ui_accept"):
		_on_select_pressed()

func init_stages() -> void:
	# Stage 1: 惑星到達前のデブリ帯
	var st1 = StageData.new()
	st1.id = 1
	st1.title = "デブリ帯突破"
	st1.codename = "第1エリア: 惑星到達前・デブリ宙域"
	st1.description = "惑星到達前の小惑星・残骸漂流地帯。高密度なデブリと哨戒防衛網をジャストガードで解析・突破せよ。"
	st1.difficulty = "難易度: ★☆☆☆☆"
	st1.color = Color(0.2, 0.8, 1.0)
	st1.scene_path = "res://game/stages/stage_1.tscn"
	st1.bg_texture = preload("res://game/assets/backgrounds/backgrnd_stage1.png")
	stages.append(st1)
	
	# Stage 2: 惑星の地上上空
	var st2 = StageData.new()
	st2.id = 2
	st2.title = "大気圏降下戦"
	st2.codename = "第2エリア: 惑星地上上空・成層圏"
	st2.description = "惑星大気圏へ突入。地上防衛迎撃編隊と雲海を切り裂く高速ドッグファイトを展開せよ。"
	st2.difficulty = "難易度: ★★☆☆☆"
	st2.color = Color(0.3, 0.9, 0.4)
	st2.scene_path = "res://game/stages/stage_2.tscn"
	st2.bg_texture = preload("res://game/assets/backgrounds/backgrnd_stage2.png")
	stages.append(st2)
	
	# Stage 3: 惑星内部施設
	var st3 = StageData.new()
	st3.id = 3
	st3.title = "地底要塞中枢"
	st3.codename = "第3エリア: 惑星内部・軍事工廠"
	st3.description = "惑星の地底深く侵入。網の目のように張り巡らされた防衛電磁タレットと中枢コアを制圧せよ。"
	st3.difficulty = "難易度: ★★★☆☆"
	st3.color = Color(1.0, 0.7, 0.2)
	st3.scene_path = "res://game/stages/stage_3.tscn"
	st3.bg_texture = preload("res://game/assets/backgrounds/backgrnd_stage3.png")
	stages.append(st3)

	# Stage 4: 惑星内部からの脱出
	var st4 = StageData.new()
	st4.id = 4
	st4.title = "崩壊地底脱出"
	st4.codename = "第4エリア: 崩壊地底・脱出ルート"
	st4.description = "中枢破壊に伴う大崩壊が発生。マグマと崩落トラップを回避し、追撃殲滅部隊を振り切って脱出せよ。"
	st4.difficulty = "難易度: ★★★★☆"
	st4.color = Color(0.9, 0.3, 1.0)
	st4.scene_path = "res://game/stages/stage_4.tscn"
	st4.bg_texture = preload("res://game/assets/backgrounds/backgrnd_stage4.png")
	stages.append(st4)

	# Stage 5: 最終決戦 - 終焉の支配者
	var st5 = StageData.new()
	st5.id = 5
	st5.title = "APEX OVERLORD"
	st5.codename = "最終エリア: 終焉の支配者・オメガ"
	st5.description = "最終決戦宙域。前哨防衛兵器を撃破後、脈動する真のラストボス「オーバーロード・オメガ」が降臨！"
	st5.difficulty = "難易度: ★★★★★ (FINAL BOSS)"
	st5.color = Color(1.0, 0.25, 0.4)
	st5.scene_path = "res://game/stages/stage_5.tscn"
	st5.bg_texture = preload("res://game/assets/backgrounds/backgrnd_stage5.png")
	stages.append(st5)

func setup_ui() -> void:
	# 1. Base dark background
	background_color = ColorRect.new()
	background_color.color = Color(0.03, 0.03, 0.06, 1.0)
	background_color.anchor_right = 1.0
	background_color.anchor_bottom = 1.0
	background_color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_color)
	
	# 2. Header Title
	var header = Label.new()
	header.text = "作戦エリア選択"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.anchor_left = 0.0
	header.anchor_right = 1.0
	header.anchor_top = 0.04
	header.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var head_set = LabelSettings.new()
	head_set.font_size = 40
	head_set.font_color = Color.CYAN
	head_set.outline_size = 8
	head_set.outline_color = Color.BLACK
	header.label_settings = head_set
	add_child(header)
	
	# 3. Main Center Cards container for active details
	detail_panel = PanelContainer.new()
	detail_panel.anchor_left = 0.04
	detail_panel.anchor_top = 0.16
	detail_panel.anchor_right = 0.96
	detail_panel.anchor_bottom = 0.58
	detail_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	detail_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	detail_panel.offset_left = 0
	detail_panel.offset_right = 0
	detail_panel.offset_top = 0
	detail_panel.offset_bottom = 0
	add_child(detail_panel)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.12, 0.9)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color.CYAN
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.shadow_color = Color(0, 0.8, 1.0, 0.15)
	sb.shadow_size = 12
	detail_panel.add_theme_stylebox_override("panel", sb)
	
	var margin_inner = MarginContainer.new()
	margin_inner.add_theme_constant_override("margin_left", 24)
	margin_inner.add_theme_constant_override("margin_top", 16)
	margin_inner.add_theme_constant_override("margin_right", 24)
	margin_inner.add_theme_constant_override("margin_bottom", 16)
	detail_panel.add_child(margin_inner)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 10)
	margin_inner.add_child(info_vbox)
	
	detail_title = Label.new()
	var t_set = LabelSettings.new()
	if PIXEL_FONT:
		t_set.font = PIXEL_FONT
	t_set.font_size = 40
	t_set.font_color = Color.WHITE
	t_set.outline_size = 6
	t_set.outline_color = Color.BLACK
	detail_title.label_settings = t_set
	info_vbox.add_child(detail_title)
	
	detail_codename = Label.new()
	var code_set = LabelSettings.new()
	if PIXEL_FONT:
		code_set.font = PIXEL_FONT
	code_set.font_size = 22
	code_set.font_color = Color.GOLD
	detail_codename.label_settings = code_set
	info_vbox.add_child(detail_codename)
	
	# Divider line custom control
	var div = ColorRect.new()
	div.custom_minimum_size = Vector2(0, 2)
	div.color = Color(0.2, 0.5, 0.6, 0.6)
	info_vbox.add_child(div)
	
	detail_desc = Label.new()
	detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_desc.custom_minimum_size = Vector2(400, 70)
	var desc_set = LabelSettings.new()
	if PIXEL_FONT:
		desc_set.font = PIXEL_FONT
	desc_set.font_size = 22
	desc_set.font_color = Color(0.9, 0.95, 1.0, 0.95)
	detail_desc.label_settings = desc_set
	info_vbox.add_child(detail_desc)
	
	detail_diff = Label.new()
	var diff_set = LabelSettings.new()
	if PIXEL_FONT:
		diff_set.font = PIXEL_FONT
	diff_set.font_size = 22
	diff_set.font_color = Color.GREEN
	diff_set.outline_size = 4
	diff_set.outline_color = Color.BLACK
	detail_diff.label_settings = diff_set
	info_vbox.add_child(detail_diff)
	
	# 4. Stage list with navigation arrows integrated
	var carousel_row = HBoxContainer.new()
	carousel_row.anchor_left = 0.04
	carousel_row.anchor_right = 0.96
	carousel_row.anchor_top = 0.65
	carousel_row.anchor_bottom = 0.83
	carousel_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	carousel_row.grow_vertical = Control.GROW_DIRECTION_BOTH
	carousel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	carousel_row.add_theme_constant_override("separation", 16)
	add_child(carousel_row)
	
	# Left Arrow button
	prev_btn = Button.new()
	prev_btn.text = "◀"
	prev_btn.custom_minimum_size = Vector2(48, 64)
	prev_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prev_btn.add_theme_font_size_override("font_size", 22)
	carousel_row.add_child(prev_btn)
	style_nav_button(prev_btn)
	prev_btn.pressed.connect(func(): navigate_selection(-1))
	
	# Scroll view
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	carousel_row.add_child(scroll)
	
	stage_container = HBoxContainer.new()
	stage_container.add_theme_constant_override("separation", 24)
	stage_container.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(stage_container)
	
	# Add stage cards
	for stage in stages:
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(170, 95)
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stage_container.add_child(card)
		stage_cards.append(card)
		
		# Inner text
		var card_lbl = Label.new()
		card_lbl.text = "STAGE " + str(stage.id) + "\n" + stage.title
		card_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var lbl_set = LabelSettings.new()
		if PIXEL_FONT:
			lbl_set.font = PIXEL_FONT
		lbl_set.font_size = 18
		lbl_set.font_color = Color.WHITE
		lbl_set.outline_size = 4
		lbl_set.outline_color = Color.BLACK
		card_lbl.label_settings = lbl_set
		card.add_child(card_lbl)
		
		# Styling base
		var sb_card = StyleBoxFlat.new()
		sb_card.bg_color = Color(0.05, 0.05, 0.08, 0.95)
		sb_card.border_width_left = 2
		sb_card.border_width_top = 2
		sb_card.border_width_right = 2
		sb_card.border_width_bottom = 2
		sb_card.border_color = Color(0.3, 0.3, 0.3)
		sb_card.corner_radius_top_left = 6
		sb_card.corner_radius_top_right = 6
		sb_card.corner_radius_bottom_left = 6
		sb_card.corner_radius_bottom_right = 6
		card.add_theme_stylebox_override("panel", sb_card)
		
		# Connect click
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				var idx = stages.find(stage)
				if idx != -1 and idx != current_index:
					navigate_to_index(idx)
		)

	# Right Arrow button
	next_btn = Button.new()
	next_btn.text = "▶"
	next_btn.custom_minimum_size = Vector2(48, 64)
	next_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_btn.add_theme_font_size_override("font_size", 22)
	carousel_row.add_child(next_btn)
	style_nav_button(next_btn)
	next_btn.pressed.connect(func(): navigate_selection(1))
	
	# Top-Right TIPS Button (画面右上)
	tips_btn = Button.new()
	var unread_cnt = Global.get_unread_tips_count()
	tips_btn.text = "TIPS [NEW]" if unread_cnt > 0 else "TIPS戦術"
	tips_btn.custom_minimum_size = Vector2(120, 42)
	tips_btn.add_theme_font_size_override("font_size", 18)
	tips_btn.anchor_left = 1.0
	tips_btn.anchor_right = 1.0
	tips_btn.anchor_top = 0.035
	tips_btn.offset_left = -150
	tips_btn.offset_right = -30
	tips_btn.offset_top = 0
	tips_btn.offset_bottom = 42
	add_child(tips_btn)
	style_btn(tips_btn, Color(0.2, 0.9, 0.5) if unread_cnt == 0 else Color(1.0, 0.35, 0.35), Color(0.4, 1.0, 0.7) if unread_cnt == 0 else Color(1.0, 0.6, 0.6))
	tips_btn.pressed.connect(_on_tips_pressed)
	
	# Hard Mode Toggle Button (ステージバーの中央上)
	hard_mode_btn = Button.new()
	hard_mode_btn.custom_minimum_size = Vector2(300, 42)
	hard_mode_btn.add_theme_font_size_override("font_size", 18)
	hard_mode_btn.anchor_left = 0.5
	hard_mode_btn.anchor_right = 0.5
	hard_mode_btn.anchor_top = 0.60
	hard_mode_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hard_mode_btn.offset_left = -150
	hard_mode_btn.offset_right = 150
	hard_mode_btn.offset_top = 0
	hard_mode_btn.offset_bottom = 42
	add_child(hard_mode_btn)
	update_hard_mode_btn_style()
	hard_mode_btn.pressed.connect(func():
		Global.hard_mode_enabled = not Global.hard_mode_enabled
		var cur_data = Global.load_game_data(false)
		Global.save_game(cur_data.get("stage_num", 1), cur_data.get("score", 0), {})
		Global.play_ui_select()
		update_hard_mode_btn_style()
		update_stage_selection(false)
	)
	
	# Action buttons at the absolute bottom
	var action_hbox = HBoxContainer.new()
	action_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_hbox.add_theme_constant_override("separation", 18)
	action_hbox.anchor_left = 0.0
	action_hbox.anchor_right = 1.0
	action_hbox.anchor_top = 0.90
	action_hbox.anchor_bottom = 0.90
	action_hbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	action_hbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(action_hbox)
	
	menu_btn = Button.new()
	menu_btn.text = "戻る"
	menu_btn.custom_minimum_size = Vector2(130, 52)
	menu_btn.add_theme_font_size_override("font_size", 20)
	action_hbox.add_child(menu_btn)
	style_btn(menu_btn, Color(0.6, 0.6, 0.6), Color(0.8, 0.8, 0.8))
	menu_btn.pressed.connect(_on_menu_pressed)
	
	archive_btn = Button.new()
	archive_btn.text = "解析図鑑"
	archive_btn.custom_minimum_size = Vector2(160, 52)
	archive_btn.add_theme_font_size_override("font_size", 20)
	action_hbox.add_child(archive_btn)
	style_btn(archive_btn, Color(0.85, 0.45, 1.0), Color(1.0, 0.6, 1.0))
	archive_btn.pressed.connect(_on_archive_pressed)
	
	tech_lab_btn = Button.new()
	tech_lab_btn.text = "機体強化"
	tech_lab_btn.custom_minimum_size = Vector2(160, 52)
	tech_lab_btn.add_theme_font_size_override("font_size", 20)
	action_hbox.add_child(tech_lab_btn)
	style_btn(tech_lab_btn, Color.GOLD, Color(1.0, 0.85, 0.3))
	tech_lab_btn.pressed.connect(_on_tech_lab_pressed)
	
	select_btn = Button.new()
	select_btn.text = "出撃準備"
	select_btn.custom_minimum_size = Vector2(180, 52)
	select_btn.add_theme_font_size_override("font_size", 20)
	action_hbox.add_child(select_btn)
	style_btn(select_btn, Color.CYAN, Color(0.3, 0.9, 1.0))
	select_btn.pressed.connect(_on_select_pressed)
	
	setup_archive_panel()
	setup_tips_panel()

const PIXEL_FONT: Font = preload("res://game/assets/fonts/DotGothic16-Regular.ttf")

func style_nav_button(btn: Button) -> void:
	if PIXEL_FONT:
		btn.add_theme_font_override("font", PIXEL_FONT)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.9)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color.CYAN
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	
	var sb_hover = sb.duplicate()
	sb_hover.bg_color = Color(0.1, 0.12, 0.2, 0.95)
	sb_hover.border_color = Color.WHITE
	
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	btn.add_theme_color_override("font_color", Color.CYAN)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

func style_btn(btn: Button, border: Color, hover_border: Color) -> void:
	if PIXEL_FONT:
		btn.add_theme_font_override("font", PIXEL_FONT)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.95)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = border
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	
	var sb_hover = StyleBoxFlat.new()
	sb_hover.bg_color = Color(0.1, 0.12, 0.22, 0.95)
	sb_hover.border_width_left = 3
	sb_hover.border_width_top = 3
	sb_hover.border_width_right = 3
	sb_hover.border_width_bottom = 3
	sb_hover.border_color = hover_border
	sb_hover.corner_radius_top_left = 0
	sb_hover.corner_radius_top_right = 0
	sb_hover.corner_radius_bottom_left = 0
	sb_hover.corner_radius_bottom_right = 0
	
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	
	# Scale animation
	btn.mouse_entered.connect(func():
		btn.pivot_offset = btn.size / 2
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)
	)
	btn.mouse_exited.connect(func():
		btn.pivot_offset = btn.size / 2
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	)

func navigate_selection(dir: int) -> void:
	var next_idx = clamp(current_index + dir, 0, stages.size() - 1)
	if next_idx != current_index:
		navigate_to_index(next_idx)

func navigate_to_index(idx: int) -> void:
	current_index = idx
	update_stage_selection(false)

func update_hard_mode_btn_style() -> void:
	if not is_instance_valid(hard_mode_btn):
		return
	var active_stage = stages[current_index] if current_index < stages.size() else null
	var is_hard_unlocked = Global.is_stage_hard_unlocked(active_stage.id) if active_stage else false
	
	if not is_hard_unlocked:
		hard_mode_btn.text = "HARD MODE: 未解放 [クリアで解放]"
		hard_mode_btn.disabled = true
		style_btn(hard_mode_btn, Color(0.35, 0.35, 0.4), Color(0.45, 0.45, 0.5))
	else:
		hard_mode_btn.disabled = false
		if Global.hard_mode_enabled:
			hard_mode_btn.text = "★ HARD MODE [ON] (HP 2x / 攻撃 1.3x)"
			style_btn(hard_mode_btn, Color(1.0, 0.25, 0.25), Color(1.0, 0.6, 0.6))
		else:
			hard_mode_btn.text = "MODE: NORMAL [標準難易度]"
			style_btn(hard_mode_btn, Color(0.3, 0.6, 0.8), Color(0.5, 0.85, 1.0))


func update_stage_selection(instant: bool) -> void:
	var active_stage = stages[current_index]
	var is_unlocked = Global.is_stage_unlocked(active_stage.id)
	var is_hard_unlocked = Global.is_stage_hard_unlocked(active_stage.id)
	update_hard_mode_btn_style()
	
	# Update active detail card details
	if is_unlocked:
		detail_title.text = active_stage.title
		detail_codename.text = active_stage.codename
		detail_desc.text = active_stage.description
		var diff_str = active_stage.difficulty
		if is_hard_unlocked and Global.hard_mode_enabled:
			diff_str += " 【HARD: HP 2.0x / 攻撃 1.3x】"
			detail_diff.label_settings.font_color = Color(1.0, 0.35, 0.35)
		else:
			detail_diff.label_settings.font_color = active_stage.color
		detail_diff.text = "DIFFICULTY: " + diff_str
		select_btn.text = "出撃準備"
		select_btn.disabled = false
		style_btn(select_btn, Color.CYAN, Color(0.3, 0.9, 1.0))
	else:
		detail_title.text = "STAGE %d: 未解放エリア" % active_stage.id
		detail_codename.text = "[アクセス権限: 未解除]"
		var prev_stage_name = stages[active_stage.id - 2].title if active_stage.id > 1 and active_stage.id - 2 < stages.size() else "前ステージ"
		detail_desc.text = "前ステージ (STAGE %d: %s) をクリアすることで作戦宙域へのアクセス権限が解放されます。" % [active_stage.id - 1, prev_stage_name]
		detail_diff.text = "DIFFICULTY: LOCKED"
		detail_diff.label_settings.font_color = Color(0.6, 0.3, 0.3)
		select_btn.text = "未解放"
		select_btn.disabled = true
		style_btn(select_btn, Color(0.3, 0.3, 0.3), Color(0.4, 0.4, 0.4))
	
	# Update detail panel borders to match active color
	var sb = detail_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		var target_color = active_stage.color if is_unlocked else Color(0.35, 0.35, 0.4)
		if instant:
			sb.border_color = target_color
			sb.shadow_color = Color(target_color.r, target_color.g, target_color.b, 0.2)
		else:
			var tween = create_tween().set_parallel(true)
			tween.tween_property(sb, "border_color", target_color, 0.25)
			tween.tween_property(sb, "shadow_color", Color(target_color.r, target_color.g, target_color.b, 0.2), 0.25)
			
	# Animate card scale/color focusing in HBox
	for i in range(stage_cards.size()):
		var card = stage_cards[i]
		var stage_item = stages[i]
		var item_unlocked = Global.is_stage_unlocked(stage_item.id)
		var card_sb = card.get_theme_stylebox("panel") as StyleBoxFlat
		var card_lbl = card.get_child(0) as Label
		
		# Update card label text
		if item_unlocked:
			card_lbl.text = "STAGE " + str(stage_item.id) + "\n" + stage_item.title
		else:
			card_lbl.text = "STAGE " + str(stage_item.id) + "\nLOCKED"
		
		if i == current_index:
			# Focused Card
			card_lbl.label_settings.font_color = Color.WHITE if item_unlocked else Color(0.8, 0.6, 0.6)
			var border_col = stage_item.color if item_unlocked else Color(0.6, 0.3, 0.3)
			if instant:
				card.scale = Vector2(1.15, 1.15)
				card_sb.border_color = border_col
				card_sb.bg_color = Color(0.1, 0.1, 0.16) if item_unlocked else Color(0.08, 0.05, 0.05)
			else:
				var t = create_tween().set_parallel(true)
				t.tween_property(card, "scale", Vector2(1.15, 1.15), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				t.tween_property(card_sb, "border_color", border_col, 0.2)
				t.tween_property(card_sb, "bg_color", Color(0.1, 0.1, 0.16) if item_unlocked else Color(0.08, 0.05, 0.05), 0.2)
		else:
			# Unfocused Cards
			card_lbl.label_settings.font_color = Color(0.5, 0.5, 0.5) if item_unlocked else Color(0.35, 0.3, 0.3)
			if instant:
				card.scale = Vector2(0.9, 0.9)
				card_sb.border_color = Color(0.2, 0.2, 0.2)
				card_sb.bg_color = Color(0.03, 0.03, 0.05)
			else:
				var t = create_tween().set_parallel(true)
				t.tween_property(card, "scale", Vector2(0.9, 0.9), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				t.tween_property(card_sb, "border_color", Color(0.2, 0.2, 0.2), 0.2)
				t.tween_property(card_sb, "bg_color", Color(0.03, 0.03, 0.05), 0.2)

	# Scroll focusing in stage_container
	var container_parent = stage_container.get_parent() as ScrollContainer
	if container_parent:
		var target_scroll_h = 0
		if current_index > 0:
			var card_width = 160.0
			var sep = 35.0
			var offset_x = current_index * (card_width + sep)
			target_scroll_h = int(offset_x - (container_parent.size.x - card_width) / 2.0)
			target_scroll_h = max(0, target_scroll_h)
			
		if instant:
			container_parent.scroll_horizontal = target_scroll_h
		else:
			var t_scroll = create_tween()
			t_scroll.tween_property(container_parent, "scroll_horizontal", target_scroll_h, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://game/core/main_menu.tscn")

func _on_tech_lab_pressed() -> void:
	get_tree().change_scene_to_file("res://game/core/tech_lab.tscn")

var archive_cards_container: VBoxContainer
var archive_summary_label: Label

func setup_archive_panel() -> void:
	archive_panel = PanelContainer.new()
	archive_panel.name = "ArchivePanel"
	archive_panel.anchor_left = 0.05
	archive_panel.anchor_top = 0.05
	archive_panel.anchor_right = 0.95
	archive_panel.anchor_bottom = 0.95
	archive_panel.hide()
	add_child(archive_panel)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.98)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.85, 0.45, 1.0)
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.shadow_color = Color(0.85, 0.45, 1.0, 0.25)
	sb.shadow_size = 20
	archive_panel.add_theme_stylebox_override("panel", sb)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_bottom", 20)
	archive_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)
	
	# Header
	var title = Label.new()
	title.text = "【解析兵装アーカイブ / WEAPON ARCHIVE】"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t_set = LabelSettings.new()
	if PIXEL_FONT:
		t_set.font = PIXEL_FONT
	t_set.font_size = 26
	t_set.font_color = Color(0.9, 0.6, 1.0)
	t_set.outline_size = 6
	t_set.outline_color = Color.BLACK
	title.label_settings = t_set
	vbox.add_child(title)
	
	archive_summary_label = Label.new()
	archive_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s_set = LabelSettings.new()
	if PIXEL_FONT:
		s_set.font = PIXEL_FONT
	s_set.font_size = 15
	s_set.font_color = Color.GOLD
	archive_summary_label.label_settings = s_set
	vbox.add_child(archive_summary_label)
	
	# Scroll area for 7 weapons
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	
	archive_cards_container = VBoxContainer.new()
	archive_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	archive_cards_container.add_theme_constant_override("separation", 14)
	scroll.add_child(archive_cards_container)
	
	# Footer Close Button
	var close_btn = Button.new()
	close_btn.text = "アーカイブを閉じる"
	close_btn.custom_minimum_size = Vector2(260, 48)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if PIXEL_FONT:
		close_btn.add_theme_font_override("font", PIXEL_FONT)
	close_btn.add_theme_font_size_override("font_size", 20)
	style_btn(close_btn, Color(0.85, 0.45, 1.0), Color(1.0, 0.7, 1.0))
	vbox.add_child(close_btn)
	close_btn.pressed.connect(func():
		var tween = create_tween().set_parallel(true)
		tween.tween_property(archive_panel, "scale", Vector2(0.9, 0.9), 0.15)
		tween.tween_property(archive_panel, "modulate:a", 0.0, 0.15)
		tween.chain().tween_callback(archive_panel.hide)
	)

func _on_archive_pressed() -> void:
	update_archive_content()
	archive_panel.show()
	archive_panel.modulate.a = 0.0
	archive_panel.scale = Vector2(0.9, 0.9)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(archive_panel, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(archive_panel, "modulate:a", 1.0, 0.2)

func update_archive_content() -> void:
	for child in archive_cards_container.get_children():
		child.queue_free()
		
	var discovered = Global.discovered_analysis_weapons
	var total_count = Global.analysis_catalog.size()
	var unlocked_count = 0
	for k in Global.analysis_catalog.keys():
		if discovered.has(k):
			unlocked_count += 1
			
	archive_summary_label.text = "解析解放状況: %d / %d 系統完了 （敵弾をジャストガードして解析）" % [unlocked_count, total_count]
	
	for key in Global.analysis_catalog.keys():
		var data = Global.analysis_catalog[key]
		var is_disc = discovered.has(key)
		
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var card_sb = StyleBoxFlat.new()
		card_sb.bg_color = Color(0.06, 0.07, 0.12, 0.95) if is_disc else Color(0.03, 0.03, 0.05, 0.9)
		card_sb.border_width_left = 2
		card_sb.border_width_top = 2
		card_sb.border_width_right = 2
		card_sb.border_width_bottom = 2
		card_sb.border_color = data["color"] if is_disc else Color(0.25, 0.25, 0.35)
		card.add_theme_stylebox_override("panel", card_sb)
		
		var cm = MarginContainer.new()
		cm.add_theme_constant_override("margin_left", 14)
		cm.add_theme_constant_override("margin_top", 12)
		cm.add_theme_constant_override("margin_right", 14)
		cm.add_theme_constant_override("margin_bottom", 12)
		card.add_child(cm)
		
		var cv = VBoxContainer.new()
		cv.add_theme_constant_override("separation", 5)
		cm.add_child(cv)
		
		var hdr_lbl = Label.new()
		var l_set = LabelSettings.new()
		if PIXEL_FONT:
			l_set.font = PIXEL_FONT
		l_set.outline_size = 4
		l_set.outline_color = Color.BLACK
		
		if is_disc:
			hdr_lbl.text = "%s 【%s】 [解析解放済み]" % [data["icon"], data["name"]]
			l_set.font_size = 20
			l_set.font_color = data["color"]
		else:
			hdr_lbl.text = "【未解析アーカイブ】"
			l_set.font_size = 18
			l_set.font_color = Color(0.5, 0.5, 0.6)
		hdr_lbl.label_settings = l_set
		cv.add_child(hdr_lbl)
		
		var src_lbl = Label.new()
		var src_set = LabelSettings.new()
		if PIXEL_FONT:
			src_set.font = PIXEL_FONT
		src_set.font_size = 15
		
		if is_disc:
			src_lbl.text = "【出現敵】 %s （%s）" % [data["enemy_color"], data["enemy_type"]]
			src_set.font_color = Color(0.85, 0.95, 1.0)
		else:
			src_lbl.text = "【入手条件】 %sの敵弾（%s）をジャストガードして解析ゲージを100%%にすると解放" % [data["enemy_color"], data["enemy_type"]]
			src_set.font_color = Color.GOLD
		src_lbl.label_settings = src_set
		cv.add_child(src_lbl)
		
		var stat_lbl = Label.new()
		var st_set = LabelSettings.new()
		if PIXEL_FONT:
			st_set.font = PIXEL_FONT
		st_set.font_size = 14
		st_set.font_color = Color.CYAN if is_disc else Color.DARK_GRAY
		stat_lbl.text = "【性能】 " + (data["stats"] if is_disc else "[未解析パラメータ]")
		stat_lbl.label_settings = st_set
		cv.add_child(stat_lbl)
		
		var desc_lbl = Label.new()
		var d_set = LabelSettings.new()
		if PIXEL_FONT:
			d_set.font = PIXEL_FONT
		d_set.font_size = 14
		d_set.font_color = Color(0.8, 0.85, 0.9) if is_disc else Color(0.4, 0.45, 0.5)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.text = data["description"] if is_disc else "「戦闘宙域で当該敵機の弾丸をジャストガードすることで解析が進行します。」"
		desc_lbl.label_settings = d_set
		cv.add_child(desc_lbl)
		
		archive_cards_container.add_child(card)

func setup_tips_panel() -> void:
	tips_panel = PanelContainer.new()
	tips_panel.anchor_left = 0.02
	tips_panel.anchor_top = 0.03
	tips_panel.anchor_right = 0.98
	tips_panel.anchor_bottom = 0.97
	tips_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tips_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	tips_panel.z_index = 100
	tips_panel.hide()
	add_child(tips_panel)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.09, 0.98)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.2, 0.9, 0.5)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.shadow_color = Color(0.1, 0.9, 0.4, 0.15)
	sb.shadow_size = 16
	tips_panel.add_theme_stylebox_override("panel", sb)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	tips_panel.add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)
	
	# 1. Header
	var header_hb = HBoxContainer.new()
	main_vbox.add_child(header_hb)
	
	var title_lbl = Label.new()
	title_lbl.text = "TIPS 戦術アーカイブ / TACTICAL ARCHIVE"
	var t_set = LabelSettings.new()
	if PIXEL_FONT:
		t_set.font = PIXEL_FONT
	t_set.font_size = 26
	t_set.font_color = Color(0.2, 1.0, 0.6)
	t_set.outline_size = 6
	t_set.outline_color = Color.BLACK
	title_lbl.label_settings = t_set
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hb.add_child(title_lbl)
	
	# 2. Category Filter Buttons Bar
	var cat_scroll = ScrollContainer.new()
	cat_scroll.custom_minimum_size = Vector2(0, 42)
	cat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	cat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(cat_scroll)
	
	var cat_hbox = HBoxContainer.new()
	cat_hbox.add_theme_constant_override("separation", 8)
	cat_scroll.add_child(cat_hbox)
	
	tips_category_buttons.clear()
	for cat_key in Global.tips_categories.keys():
		var cat_name = Global.tips_categories[cat_key]
		var c_btn = Button.new()
		c_btn.text = cat_name
		c_btn.custom_minimum_size = Vector2(100, 36)
		if PIXEL_FONT:
			c_btn.add_theme_font_override("font", PIXEL_FONT)
		c_btn.add_theme_font_size_override("font_size", 16)
		cat_hbox.add_child(c_btn)
		tips_category_buttons[cat_key] = c_btn
		c_btn.pressed.connect(func():
			tips_filter_category = cat_key
			update_tips_ui()
		)
		
	# 3. Main Split Body (Left: Scroll List, Right: Details Panel)
	var body_hb = HBoxContainer.new()
	body_hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hb.add_theme_constant_override("separation", 14)
	main_vbox.add_child(body_hb)
	
	# Left: Scroll List Container (Width 380px)
	var left_scroll = ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(380, 0)
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_hb.add_child(left_scroll)
	
	tips_list_container = VBoxContainer.new()
	tips_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tips_list_container.add_theme_constant_override("separation", 6)
	left_scroll.add_child(tips_list_container)
	
	# Right: Detail Viewer Panel (Width fill)
	tips_detail_panel = PanelContainer.new()
	tips_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tips_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var r_sb = StyleBoxFlat.new()
	r_sb.bg_color = Color(0.06, 0.08, 0.14, 0.95)
	r_sb.border_width_left = 2
	r_sb.border_width_top = 2
	r_sb.border_width_right = 2
	r_sb.border_width_bottom = 2
	r_sb.border_color = Color(0.25, 0.35, 0.45)
	r_sb.corner_radius_top_left = 6
	r_sb.corner_radius_top_right = 6
	r_sb.corner_radius_bottom_left = 6
	r_sb.corner_radius_bottom_right = 6
	tips_detail_panel.add_theme_stylebox_override("panel", r_sb)
	body_hb.add_child(tips_detail_panel)
	
	# 4. Footer Close Button
	var close_btn = Button.new()
	close_btn.text = "TIPSを閉じる"
	close_btn.custom_minimum_size = Vector2(260, 48)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if PIXEL_FONT:
		close_btn.add_theme_font_override("font", PIXEL_FONT)
	close_btn.add_theme_font_size_override("font_size", 20)
	style_btn(close_btn, Color(0.2, 0.9, 0.5), Color(0.4, 1.0, 0.7))
	main_vbox.add_child(close_btn)
	close_btn.pressed.connect(func():
		var tween = create_tween().set_parallel(true)
		tween.tween_property(tips_panel, "scale", Vector2(0.95, 0.95), 0.15)
		tween.tween_property(tips_panel, "modulate:a", 0.0, 0.15)
		tween.chain().tween_callback(tips_panel.hide)
		# TIPSボタンのNEW表記更新
		if is_instance_valid(tips_btn):
			var u_cnt = Global.get_unread_tips_count()
			tips_btn.text = "TIPS [NEW]" if u_cnt > 0 else "TIPS戦術"
			style_btn(tips_btn, Color(0.2, 0.9, 0.5) if u_cnt == 0 else Color(1.0, 0.35, 0.35), Color(0.4, 1.0, 0.7) if u_cnt == 0 else Color(1.0, 0.6, 0.6))
	)

func _on_tips_pressed() -> void:
	update_tips_ui()
	tips_panel.show()
	tips_panel.modulate.a = 0.0
	tips_panel.scale = Vector2(0.95, 0.95)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(tips_panel, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(tips_panel, "modulate:a", 1.0, 0.2)

func update_tips_ui() -> void:
	# Update category buttons styling
	for cat_key in tips_category_buttons.keys():
		var btn: Button = tips_category_buttons[cat_key]
		if cat_key == tips_filter_category:
			style_btn(btn, Color(0.2, 0.9, 0.6), Color.CYAN)
		else:
			style_btn(btn, Color(0.4, 0.4, 0.5), Color(0.6, 0.6, 0.7))
			
	# Clear list
	for child in tips_list_container.get_children():
		child.queue_free()
		
	var unlocked_items: Array[Dictionary] = []
	for tip in Global.tips_catalog:
		var is_unlocked = Global.unlocked_tips.has(tip["id"])
		if not is_unlocked:
			continue
		if tips_filter_category != "all" and tip.get("category", "") != tips_filter_category:
			continue
		unlocked_items.append(tip)
		
	if unlocked_items.size() == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "当該カテゴリの解放済みTIPSはありません。\n（出撃ごとに1つずつ解析解放されます）"
		var e_set = LabelSettings.new()
		if PIXEL_FONT:
			e_set.font = PIXEL_FONT
		e_set.font_size = 16
		e_set.font_color = Color.GRAY
		empty_lbl.label_settings = e_set
		tips_list_container.add_child(empty_lbl)
		render_empty_tip_detail()
		return
		
	# If no selection or invalid selection, pick first
	if selected_tip_id == "" or not Global.unlocked_tips.has(selected_tip_id):
		selected_tip_id = unlocked_items[0]["id"]
		
	var selected_found = false
	for tip in unlocked_items:
		if tip["id"] == selected_tip_id:
			selected_found = true
			break
	if not selected_found and unlocked_items.size() > 0:
		selected_tip_id = unlocked_items[0]["id"]

	for tip in unlocked_items:
		var t_id: String = tip["id"]
		var is_selected = (t_id == selected_tip_id)
		var is_unread = Global.is_tip_unread(t_id)
		
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 56)
		
		var card_sb = StyleBoxFlat.new()
		if is_selected:
			card_sb.bg_color = Color(0.1, 0.16, 0.25, 0.95)
			card_sb.border_color = Color(0.2, 0.9, 1.0)
			card_sb.border_width_left = 3
			card_sb.border_width_top = 2
			card_sb.border_width_right = 2
			card_sb.border_width_bottom = 2
		else:
			card_sb.bg_color = Color(0.05, 0.06, 0.1, 0.9)
			card_sb.border_color = Color(0.2, 0.25, 0.35)
			card_sb.border_width_left = 1
			card_sb.border_width_top = 1
			card_sb.border_width_right = 1
			card_sb.border_width_bottom = 1
		card_sb.corner_radius_top_left = 4
		card_sb.corner_radius_top_right = 4
		card_sb.corner_radius_bottom_left = 4
		card_sb.corner_radius_bottom_right = 4
		card.add_theme_stylebox_override("panel", card_sb)
		
		var cm = MarginContainer.new()
		cm.add_theme_constant_override("margin_left", 12)
		cm.add_theme_constant_override("margin_top", 8)
		cm.add_theme_constant_override("margin_right", 12)
		cm.add_theme_constant_override("margin_bottom", 8)
		card.add_child(cm)
		
		var hb = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		cm.add_child(hb)
		
		var vb = VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 2)
		hb.add_child(vb)
		
		var tag_lbl = Label.new()
		tag_lbl.text = "[%s]" % tip.get("category_name", "情報")
		var tag_set = LabelSettings.new()
		if PIXEL_FONT:
			tag_set.font = PIXEL_FONT
		tag_set.font_size = 12
		tag_set.font_color = Color.GOLD if not is_selected else Color.CYAN
		tag_lbl.label_settings = tag_set
		vb.add_child(tag_lbl)
		
		var item_lbl = Label.new()
		item_lbl.text = tip.get("title", "")
		var i_set = LabelSettings.new()
		if PIXEL_FONT:
			i_set.font = PIXEL_FONT
		i_set.font_size = 16
		i_set.font_color = Color.WHITE if is_selected else Color(0.85, 0.9, 0.95)
		item_lbl.label_settings = i_set
		vb.add_child(item_lbl)
		
		# Right: NEW Badge
		if is_unread:
			var new_badge = Label.new()
			new_badge.text = "[NEW]"
			var b_set = LabelSettings.new()
			if PIXEL_FONT:
				b_set.font = PIXEL_FONT
			b_set.font_size = 14
			b_set.font_color = Color(1.0, 0.3, 0.3)
			b_set.outline_size = 4
			b_set.outline_color = Color.BLACK
			new_badge.label_settings = b_set
			new_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hb.add_child(new_badge)
			
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				selected_tip_id = t_id
				Global.mark_tip_as_read(t_id)
				update_tips_ui()
		)
		
		tips_list_container.add_child(card)
		
	# Render detail
	var cur_tip = null
	for tip in Global.tips_catalog:
		if tip["id"] == selected_tip_id:
			cur_tip = tip
			break
	if cur_tip:
		Global.mark_tip_as_read(selected_tip_id)
		render_tip_detail(cur_tip)
	else:
		render_empty_tip_detail()

func render_tip_detail(tip: Dictionary) -> void:
	for child in tips_detail_panel.get_children():
		child.queue_free()
		
	var cm = MarginContainer.new()
	cm.add_theme_constant_override("margin_left", 22)
	cm.add_theme_constant_override("margin_top", 20)
	cm.add_theme_constant_override("margin_right", 22)
	cm.add_theme_constant_override("margin_bottom", 20)
	tips_detail_panel.add_child(cm)
	
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	cm.add_child(vb)
	
	# Header (Category + Title)
	var cat_badge = Label.new()
	cat_badge.text = "【分類: %s】" % tip.get("category_name", "情報")
	var c_set = LabelSettings.new()
	if PIXEL_FONT:
		c_set.font = PIXEL_FONT
	c_set.font_size = 16
	c_set.font_color = Color.GOLD
	cat_badge.label_settings = c_set
	vb.add_child(cat_badge)
	
	var title_lbl = Label.new()
	title_lbl.text = tip.get("title", "")
	var t_set = LabelSettings.new()
	if PIXEL_FONT:
		t_set.font = PIXEL_FONT
	t_set.font_size = 24
	t_set.font_color = Color.WHITE
	t_set.outline_size = 6
	t_set.outline_color = Color.BLACK
	title_lbl.label_settings = t_set
	vb.add_child(title_lbl)
	
	var div = ColorRect.new()
	div.custom_minimum_size = Vector2(0, 2)
	div.color = Color(0.2, 0.6, 0.8, 0.6)
	vb.add_child(div)
	
	# Body description
	var desc_lbl = Label.new()
	desc_lbl.text = tip.get("desc", "")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_constant_override("line_spacing", 6)
	var d_set = LabelSettings.new()
	d_set.font = Global.get_readable_font()
	d_set.font_size = 18
	d_set.font_color = Color(0.92, 0.96, 1.0)
	desc_lbl.label_settings = d_set
	vb.add_child(desc_lbl)
	
	# Hint / Key operation box
	if tip.has("hint") and tip["hint"] != "":
		var hint_panel = PanelContainer.new()
		var h_sb = StyleBoxFlat.new()
		h_sb.bg_color = Color(0.08, 0.12, 0.2, 0.9)
		h_sb.border_width_left = 2
		h_sb.border_width_top = 1
		h_sb.border_width_right = 1
		h_sb.border_width_bottom = 1
		h_sb.border_color = Color.CYAN
		h_sb.corner_radius_top_left = 4
		h_sb.corner_radius_top_right = 4
		h_sb.corner_radius_bottom_left = 4
		h_sb.corner_radius_bottom_right = 4
		hint_panel.add_theme_stylebox_override("panel", h_sb)
		
		var hm = MarginContainer.new()
		hm.add_theme_constant_override("margin_left", 14)
		hm.add_theme_constant_override("margin_top", 10)
		hm.add_theme_constant_override("margin_right", 14)
		hm.add_theme_constant_override("margin_bottom", 10)
		hint_panel.add_child(hm)
		
		var hint_lbl = Label.new()
		hint_lbl.text = tip["hint"]
		hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_lbl.add_theme_constant_override("line_spacing", 4)
		var hint_set = LabelSettings.new()
		hint_set.font = Global.get_readable_font()
		hint_set.font_size = 16
		hint_set.font_color = Color.CYAN
		hint_lbl.label_settings = hint_set
		hm.add_child(hint_lbl)
		
		vb.add_child(hint_panel)

func render_empty_tip_detail() -> void:
	for child in tips_detail_panel.get_children():
		child.queue_free()
	var lbl = Label.new()
	lbl.text = "左側のリストからTIPSを選択してください。"
	var l_set = LabelSettings.new()
	if PIXEL_FONT:
		l_set.font = PIXEL_FONT
	l_set.font_size = 18
	l_set.font_color = Color.GRAY
	lbl.label_settings = l_set
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tips_detail_panel.add_child(lbl)

func _on_select_pressed() -> void:
	var active_stage = stages[current_index]
	if not Global.is_stage_unlocked(active_stage.id):
		return
		
	# ハードモード未解放ステージの場合はハードモードを自動解除
	if not Global.is_stage_hard_unlocked(active_stage.id):
		Global.hard_mode_enabled = false
		
	Global.is_continue = false
	
	# Pass the selected stage number
	# We transition to the Loadout Selection Screen
	# Save stage num to global settings momentarily
	var save_data = Global.load_game_data(false)
	save_data["stage_num"] = active_stage.id
	Global.save_game(active_stage.id, save_data.get("score", 0), save_data.get("weapons", {}))
	
	# Load next Loadout selection scene
	get_tree().change_scene_to_file("res://game/core/loadout_selection.tscn")

# ----------------- Starfield & Grid Draw -----------------

func init_starfield() -> void:
	var viewport_size = get_viewport_rect().size
	for i in range(NUM_STARS):
		var star = BackgroundStar.new()
		star.pos = Vector2(randf() * viewport_size.x, randf() * viewport_size.y)
		star.speed = randf_range(10.0, 40.0)
		star.size = randf_range(0.8, 2.5)
		star.color = Color(0.2, 0.7, 1.0, randf_range(0.15, 0.6))
		stars.append(star)

func update_starfield(delta: float) -> void:
	var viewport_size = get_viewport_rect().size
	for star in stars:
		star.pos.y += star.speed * delta
		if star.pos.y > viewport_size.y:
			star.pos.y = 0
			star.pos.x = randf() * viewport_size.x

func _draw() -> void:
	var v_size = get_viewport_rect().size
	
	# Draw custom stars
	for star in stars:
		draw_circle(star.pos, star.size, star.color)
		
	# Draw cyan sci-fi background grid
	var grid_spacing = 60.0
	var offset_y = fmod(time_passed * 15.0, grid_spacing)
	var grid_color = Color(0.0, 0.4, 0.6, 0.05)
	
	# Vertical lines
	var x = 0.0
	while x < v_size.x:
		draw_line(Vector2(x, 0), Vector2(x, v_size.y), grid_color, 1.0)
		x += grid_spacing
		
	# Horizontal lines sliding down
	var y = offset_y
	while y < v_size.y:
		draw_line(Vector2(0, y), Vector2(v_size.x, y), grid_color, 1.0)
		y += grid_spacing
