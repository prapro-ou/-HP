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
var menu_btn: Button

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
	# Stage 1
	var st1 = StageData.new()
	st1.id = 1
	st1.title = "遺跡コア"
	st1.codename = "第1エリア: 古代聖域"
	st1.description = "地下コアへの入口。パリィ操作の慣らしに最適なテストエリア。"
	st1.difficulty = "難易度: 初級"
	st1.color = Color.GREEN
	st1.scene_path = "res://game/stages/stage_1.tscn"
	stages.append(st1)
	
	# Stage 2
	var st2 = StageData.new()
	st2.id = 2
	st2.title = "防衛グリッド"
	st2.codename = "第2エリア: 警備要塞"
	st2.description = "自動防衛システムが稼働中。高密度弾幕と高速機動兵器が待ち受ける。"
	st2.difficulty = "難易度: 中級"
	st2.color = Color.CYAN
	st2.scene_path = "res://game/stages/stage_2.tscn"
	stages.append(st2)
	
	# Stage 3 (Locked/Demos for progression feel)
	var st3 = StageData.new()
	st3.id = 3
	st3.title = "大気圏境界"
	st3.codename = "第3エリア: 軌道ターミナル"
	st3.description = "軌道防衛アレイ。超高速迎撃システムが展開されている。"
	st3.difficulty = "難易度: 上級 (開発中)"
	st3.color = Color.RED
	st3.scene_path = "res://game/stages/stage_1.tscn" # Loops for demo
	stages.append(st3)

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
	detail_panel.anchor_left = 0.08
	detail_panel.anchor_top = 0.18
	detail_panel.anchor_right = 0.92
	detail_panel.anchor_bottom = 0.56
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
	margin_inner.add_theme_constant_override("margin_left", 30)
	margin_inner.add_theme_constant_override("margin_top", 20)
	margin_inner.add_theme_constant_override("margin_right", 30)
	margin_inner.add_theme_constant_override("margin_bottom", 20)
	detail_panel.add_child(margin_inner)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 12)
	margin_inner.add_child(info_vbox)
	
	detail_title = Label.new()
	var t_set = LabelSettings.new()
	t_set.font_size = 36
	t_set.font_color = Color.WHITE
	t_set.outline_size = 6
	t_set.outline_color = Color.BLACK
	detail_title.label_settings = t_set
	info_vbox.add_child(detail_title)
	
	detail_codename = Label.new()
	var code_set = LabelSettings.new()
	code_set.font_size = 18
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
	detail_desc.custom_minimum_size = Vector2(400, 80)
	var desc_set = LabelSettings.new()
	desc_set.font_size = 20
	desc_set.font_color = Color(0.9, 0.95, 1.0, 0.95)
	detail_desc.label_settings = desc_set
	info_vbox.add_child(detail_desc)
	
	detail_diff = Label.new()
	var diff_set = LabelSettings.new()
	diff_set.font_size = 20
	diff_set.font_color = Color.GREEN
	diff_set.outline_size = 4
	diff_set.outline_color = Color.BLACK
	detail_diff.label_settings = diff_set
	info_vbox.add_child(detail_diff)
	
	# 4. Stage list scroll container at the bottom
	var list_panel = Panel.new()
	list_panel.anchor_left = 0.08
	list_panel.anchor_top = 0.64
	list_panel.anchor_right = 0.92
	list_panel.anchor_bottom = 0.84
	list_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	list_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	list_panel.offset_left = 0
	list_panel.offset_right = 0
	list_panel.offset_top = 0
	list_panel.offset_bottom = 0
	add_child(list_panel)
	
	var sb_list = StyleBoxEmpty.new()
	list_panel.add_theme_stylebox_override("panel", sb_list)
	
	# Scroll view
	var scroll = ScrollContainer.new()
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(scroll)
	
	stage_container = HBoxContainer.new()
	stage_container.add_theme_constant_override("separation", 35)
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

	# 5. Buttons controls
	# Previous & Next Arrow buttons
	prev_btn = Button.new()
	prev_btn.text = "◀"
	prev_btn.custom_minimum_size = Vector2(45, 55)
	prev_btn.anchor_left = 0.02
	prev_btn.anchor_top = 0.74
	prev_btn.anchor_bottom = 0.74
	prev_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	prev_btn.offset_top = -27
	add_child(prev_btn)
	style_nav_button(prev_btn)
	prev_btn.pressed.connect(func(): navigate_selection(-1))
	
	next_btn = Button.new()
	next_btn.text = "▶"
	next_btn.custom_minimum_size = Vector2(45, 55)
	next_btn.anchor_right = 0.98
	next_btn.anchor_top = 0.74
	next_btn.anchor_bottom = 0.74
	next_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	next_btn.offset_top = -27
	add_child(next_btn)
	style_nav_button(next_btn)
	next_btn.pressed.connect(func(): navigate_selection(1))
	
	# Action buttons at the absolute bottom
	var action_hbox = HBoxContainer.new()
	action_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_hbox.add_theme_constant_override("separation", 25)
	action_hbox.anchor_left = 0.0
	action_hbox.anchor_right = 1.0
	action_hbox.anchor_top = 0.90
	action_hbox.anchor_bottom = 0.90
	action_hbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	action_hbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(action_hbox)
	
	menu_btn = Button.new()
	menu_btn.text = "戻る"
	menu_btn.custom_minimum_size = Vector2(160, 52)
	menu_btn.add_theme_font_size_override("font_size", 22)
	action_hbox.add_child(menu_btn)
	style_btn(menu_btn, Color(0.6, 0.6, 0.6), Color(0.8, 0.8, 0.8))
	menu_btn.pressed.connect(_on_menu_pressed)
	
	tech_lab_btn = Button.new()
	tech_lab_btn.text = "機体強化"
	tech_lab_btn.custom_minimum_size = Vector2(180, 52)
	tech_lab_btn.add_theme_font_size_override("font_size", 22)
	action_hbox.add_child(tech_lab_btn)
	style_btn(tech_lab_btn, Color.GOLD, Color(1.0, 0.85, 0.3))
	tech_lab_btn.pressed.connect(_on_tech_lab_pressed)
	
	select_btn = Button.new()
	select_btn.text = "出撃準備"
	select_btn.custom_minimum_size = Vector2(200, 52)
	select_btn.add_theme_font_size_override("font_size", 22)
	action_hbox.add_child(select_btn)
	style_btn(select_btn, Color.CYAN, Color(0.3, 0.9, 1.0))
	select_btn.pressed.connect(_on_select_pressed)

func style_nav_button(btn: Button) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.15, 0.7)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color.CYAN
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	
	var sb_hover = sb.duplicate()
	sb_hover.bg_color = Color(0.15, 0.15, 0.28, 0.8)
	sb_hover.border_color = Color.WHITE
	
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	btn.add_theme_color_override("font_color", Color.CYAN)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

func style_btn(btn: Button, border: Color, hover_border: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.1, 0.9)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = border
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	
	var sb_hover = StyleBoxFlat.new()
	sb_hover.bg_color = Color(0.12, 0.12, 0.2, 0.9)
	sb_hover.border_width_left = 2
	sb_hover.border_width_top = 2
	sb_hover.border_width_right = 2
	sb_hover.border_width_bottom = 2
	sb_hover.border_color = hover_border
	sb_hover.corner_radius_top_left = 6
	sb_hover.corner_radius_top_right = 6
	sb_hover.corner_radius_bottom_left = 6
	sb_hover.corner_radius_bottom_right = 6
	
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

func update_stage_selection(instant: bool) -> void:
	var active_stage = stages[current_index]
	
	# Update active detail card details
	detail_title.text = active_stage.title
	detail_codename.text = active_stage.codename
	detail_desc.text = active_stage.description
	detail_diff.text = "DIFFICULTY: " + active_stage.difficulty
	detail_diff.label_settings.font_color = active_stage.color
	
	# Update detail panel borders to match active color
	var sb = detail_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		var target_color = active_stage.color
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
		var card_sb = card.get_theme_stylebox("panel") as StyleBoxFlat
		var card_lbl = card.get_child(0) as Label
		
		if i == current_index:
			# Focused Card
			card_lbl.label_settings.font_color = Color.WHITE
			if instant:
				card.scale = Vector2(1.15, 1.15)
				card_sb.border_color = active_stage.color
				card_sb.bg_color = Color(0.1, 0.1, 0.16)
			else:
				var t = create_tween().set_parallel(true)
				t.tween_property(card, "scale", Vector2(1.15, 1.15), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				t.tween_property(card_sb, "border_color", active_stage.color, 0.2)
				t.tween_property(card_sb, "bg_color", Color(0.1, 0.1, 0.16), 0.2)
		else:
			# Unfocused Cards
			card_lbl.label_settings.font_color = Color(0.5, 0.5, 0.5)
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
	# We center the focused card inside the HBox
	var container_parent = stage_container.get_parent() as ScrollContainer
	if container_parent:
		var target_scroll_h = 0
		if current_index > 0:
			# Estimate position. Card width = 160, separation = 35. Center is (focusedCardX - scrollWidth/2 + cardWidth/2)
			var card_width = 160.0
			var sep = 35.0
			var offset_x = current_index * (card_width + sep)
			# Center position
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

func _on_select_pressed() -> void:
	# Save selection to Global
	var active_stage = stages[current_index]
	Global.is_continue = false
	
	# Pass the selected stage number
	# We override equipped weapon and shield during loadout selection
	# We transition to the Loadout Selection Screen
	# Save stage num to global settings momentarily
	var save_data = Global.load_game_data()
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
