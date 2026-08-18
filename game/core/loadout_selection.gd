extends Control

# Data structures
class LoadoutItem:
	var id: String
	var name: String
	var description: String
	var stats: String
	var is_unlocked: bool = true

var primary_weapons: Array[LoadoutItem] = []
var shields: Array[LoadoutItem] = []
var counter_weapons: Array[LoadoutItem] = []

# Selected IDs
var selected_primary: String = "machine_gun"
var selected_shield: String = "counter"
var selected_counter: String = "none"

# UI elements references
var background_color: ColorRect
var primary_buttons: Dictionary = {}
var shield_buttons: Dictionary = {}
var counter_buttons: Dictionary = {}

var desc_panel: PanelContainer
var desc_title: Label
var desc_type: Label
var desc_stats: Label
var desc_body: Label

var deploy_btn: Button
var back_btn: Button

# Particles/Background
class BGStar:
	var pos: Vector2
	var speed: float
	var size: float
	var color: Color
var stars: Array[BGStar] = []
const NUM_STARS = 45
var time_passed: float = 0.0

func _ready() -> void:
	Global.load_settings()
	var save_data = Global.load_game_data()
	
	init_data()
	setup_ui()
	init_starfield()
	
	# Load pre-selected weapons from Global state
	selected_primary = Global.equipped_weapon
	selected_shield = Global.equipped_shield
	if Global.unlocked_counter_weapons.size() > 0:
		selected_counter = Global.unlocked_counter_weapons[0]
	else:
		selected_counter = "none"
		
	update_button_states()
	show_details("primary", selected_primary) # Show details of selected primary initially

func _process(delta: float) -> void:
	time_passed += delta
	update_starfield(delta)
	queue_redraw()

func init_data() -> void:
	# 1. Primary Weapons (DESIGN.md 基本武装 5種)
	var w1 = LoadoutItem.new()
	w1.id = "machine_gun"
	w1.name = "マシンガン"
	w1.description = "物理実弾を高速連射する標準兵装。安定したDPSと高い制圧力を誇る。"
	w1.stats = "連射:★★★ | 威力:★★☆ | 弾速:★★☆"
	w1.is_unlocked = Global.unlocked_weapons.has("machine_gun")
	primary_weapons.append(w1)
	
	var w2 = LoadoutItem.new()
	w2.id = "burst_rifle"
	w2.name = "ライフル"
	w2.description = "単発火力と弾速に優れる3点バースト徹甲ライフル。硬い敵を貫通粉砕する。"
	w2.stats = "連射:★★☆ | 威力:★★★ | 弾速:★★★"
	w2.is_unlocked = Global.unlocked_weapons.has("burst_rifle")
	primary_weapons.append(w2)
	
	var w3 = LoadoutItem.new()
	w3.id = "pulse_gun"
	w3.name = "パルスガン"
	w3.description = "扇状に広がるプラズマ波動弾。広角に展開し多数の敵を巻き込む。"
	w3.stats = "連射:★★★ | 威力:★★☆ | 弾速:★☆☆"
	w3.is_unlocked = Global.unlocked_weapons.has("pulse_gun")
	primary_weapons.append(w3)
	
	var w4 = LoadoutItem.new()
	w4.id = "plasma_emitter"
	w4.name = "プラズマ放射器"
	w4.description = "高熱プラズマ球を前方へ投射。着弾時に持続放電フィールドで大ダメージを与える。"
	w4.stats = "連射:★★☆ | 威力:★★★ | 弾速:★☆☆"
	w4.is_unlocked = Global.unlocked_weapons.has("plasma_emitter")
	primary_weapons.append(w4)
	
	var w5 = LoadoutItem.new()
	w5.id = "kinetic_tackle"
	w5.name = "タックル"
	w5.description = "機体前方に強力な衝撃破砕波を放つ超近接直接攻撃兵装。密着時に超絶威力。"
	w5.stats = "連射:★☆☆ | 威力:★★★ | 弾速:★★☆"
	w5.is_unlocked = Global.unlocked_weapons.has("kinetic_tackle")
	primary_weapons.append(w5)

	# 2. Shields (技研で各30 TPで開発可能)
	var s1 = LoadoutItem.new()
	s1.id = "counter"
	s1.name = "カウンターシールド"
	s1.description = "パリィ反撃の威力を最大化する標準モデル。"
	s1.stats = "反射:★★★ | 溜め:★★☆ | 強化:★☆☆"
	s1.is_unlocked = Global.unlocked_shields.has("counter")
	shields.append(s1)
	
	var s2 = LoadoutItem.new()
	s2.id = "gauge"
	s2.name = "吸収マトリクス"
	s2.description = "敵撃破時に解析エナジーオーブを磁力吸引！EXP蓄積＆機体修復。"
	s2.stats = "反射:★☆☆ | 吸収:★★★ | 修復:★★☆"
	s2.is_unlocked = Global.unlocked_shields.has("gauge")
	shields.append(s2)
	
	var s3 = LoadoutItem.new()
	s3.id = "power"
	s3.name = "増幅ブースター"
	s3.description = "パリィ成功時に弾丸を吸収し、主兵装の威力を永続スタック強化。"
	s3.stats = "反射:★★☆ | 溜め:★☆☆ | 強化:★★★"
	s3.is_unlocked = Global.unlocked_shields.has("power")
	shields.append(s3)

	# 3. Counter System Weapons (Boss weapons)
	var c0 = LoadoutItem.new()
	c0.id = "none"
	c0.name = "標準レーザー"
	c0.description = "標準の反射レーザーを照射する。"
	c0.stats = "威力:★☆☆ | 範囲:★☆☆"
	c0.is_unlocked = true
	counter_weapons.append(c0)
	
	var c1 = LoadoutItem.new()
	c1.id = "boss_beam"
	c1.name = "ギガレーザー"
	c1.description = "敵を貫く極太エネルギービーム（ボス兵装）。"
	c1.stats = "威力:★★★ | 範囲:★★☆"
	c1.is_unlocked = Global.unlocked_counter_weapons.has("boss_beam")
	counter_weapons.append(c1)
	
	var c2 = LoadoutItem.new()
	c2.id = "boss_missile"
	c2.name = "ハイパーミサイル"
	c2.description = "着弾時に広範囲爆発を起こす誘導ミサイル（ボス兵装）。"
	c2.stats = "威力:★★☆ | 範囲:★★★"
	c2.is_unlocked = Global.unlocked_counter_weapons.has("boss_missile")
	counter_weapons.append(c2)

func setup_ui() -> void:
	# 1. Base dark background
	background_color = ColorRect.new()
	background_color.color = Color(0.04, 0.04, 0.07, 1.0)
	background_color.anchor_right = 1.0
	background_color.anchor_bottom = 1.0
	background_color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_color)
	
	# 2. Main title
	var title = Label.new()
	title.text = "装備選択"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.04
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var title_set = LabelSettings.new()
	title_set.font_size = 38
	title_set.font_color = Color.CYAN
	title_set.outline_size = 8
	title_set.outline_color = Color.BLACK
	title.label_settings = title_set
	add_child(title)
	
	# 3. Main VBox Container for configuration elements
	var main_vbox = VBoxContainer.new()
	main_vbox.anchor_left = 0.08
	main_vbox.anchor_top = 0.12
	main_vbox.anchor_right = 0.92
	main_vbox.anchor_bottom = 0.88
	main_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	main_vbox.offset_left = 0
	main_vbox.offset_right = 0
	main_vbox.offset_top = 0
	main_vbox.offset_bottom = 0
	main_vbox.add_theme_constant_override("separation", 18)
	add_child(main_vbox)
	
	# --- SECTION 1: PRIMARY WEAPON ---
	var p_sec = create_section_vbox("主兵装（メイン）", main_vbox)
	var p_grid = GridContainer.new()
	p_grid.columns = 3
	p_grid.add_theme_constant_override("h_separation", 15)
	p_grid.add_theme_constant_override("v_separation", 10)
	p_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_sec.add_child(p_grid)
	
	for w in primary_weapons:
		var btn = Button.new()
		btn.text = w.name
		btn.custom_minimum_size = Vector2(90, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 18)
		p_grid.add_child(btn)
		primary_buttons[w.id] = btn
		
		if not w.is_unlocked:
			btn.disabled = true
			btn.text = "🔒 未解放"
		else:
			btn.pressed.connect(func(): select_item("primary", w.id))
			btn.mouse_entered.connect(func(): show_details("primary", w.id))
			style_config_button(btn, Color.CYAN)
			
	# --- SECTION 2: SHIELD TYPE ---
	var s_sec = create_section_vbox("シールド（防御）", main_vbox)
	var s_grid = HBoxContainer.new()
	s_grid.add_theme_constant_override("separation", 18)
	s_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s_sec.add_child(s_grid)
	
	for s in shields:
		var btn = Button.new()
		btn.text = s.name.left(6)
		btn.custom_minimum_size = Vector2(90, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 18)
		s_grid.add_child(btn)
		shield_buttons[s.id] = btn
		btn.pressed.connect(func(): select_item("shield", s.id))
		btn.mouse_entered.connect(func(): show_details("shield", s.id))
		style_config_button(btn, Color.GREEN)
		
	# --- SECTION 3: COUNTER SYSTEM ---
	var c_sec = create_section_vbox("カウンター兵装", main_vbox)
	var c_grid = HBoxContainer.new()
	c_grid.add_theme_constant_override("separation", 18)
	c_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_sec.add_child(c_grid)
	
	for c in counter_weapons:
		var btn = Button.new()
		btn.text = c.name
		btn.custom_minimum_size = Vector2(90, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 18)
		c_grid.add_child(btn)
		counter_buttons[c.id] = btn
		
		if not c.is_unlocked:
			btn.disabled = true
			btn.text = "🔒 未解放"
		else:
			btn.pressed.connect(func(): select_item("counter", c.id))
			btn.mouse_entered.connect(func(): show_details("counter", c.id))
			style_config_button(btn, Color.GOLD)

	# --- DESCRIPTION CARD PANEL ---
	desc_panel = PanelContainer.new()
	desc_panel.custom_minimum_size = Vector2(0, 160)
	desc_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(desc_panel)
	
	var sb_desc = StyleBoxFlat.new()
	sb_desc.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	sb_desc.border_width_left = 2
	sb_desc.border_width_top = 2
	sb_desc.border_width_right = 2
	sb_desc.border_width_bottom = 2
	sb_desc.border_color = Color(0.3, 0.5, 0.6)
	sb_desc.corner_radius_top_left = 8
	sb_desc.corner_radius_top_right = 8
	sb_desc.corner_radius_bottom_left = 8
	sb_desc.corner_radius_bottom_right = 8
	desc_panel.add_theme_stylebox_override("panel", sb_desc)
	
	var desc_margin = MarginContainer.new()
	desc_margin.add_theme_constant_override("margin_left", 20)
	desc_margin.add_theme_constant_override("margin_top", 15)
	desc_margin.add_theme_constant_override("margin_right", 20)
	desc_margin.add_theme_constant_override("margin_bottom", 15)
	desc_panel.add_child(desc_margin)
	
	var desc_vbox = VBoxContainer.new()
	desc_vbox.add_theme_constant_override("separation", 6)
	desc_margin.add_child(desc_vbox)
	
	# Header with Title and Type
	var desc_hdr = HBoxContainer.new()
	desc_vbox.add_child(desc_hdr)
	
	desc_title = Label.new()
	var d_title_set = LabelSettings.new()
	d_title_set.font_size = 22
	d_title_set.font_color = Color.WHITE
	d_title_set.outline_size = 4
	d_title_set.outline_color = Color.BLACK
	desc_title.label_settings = d_title_set
	desc_hdr.add_child(desc_title)
	
	desc_type = Label.new()
	var d_type_set = LabelSettings.new()
	d_type_set.font_size = 16
	d_type_set.font_color = Color.GOLD
	desc_type.label_settings = d_type_set
	desc_type.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	desc_hdr.add_child(desc_type)
	
	desc_stats = Label.new()
	var d_stats_set = LabelSettings.new()
	d_stats_set.font_size = 18
	d_stats_set.font_color = Color.CYAN
	desc_stats.label_settings = d_stats_set
	desc_vbox.add_child(desc_stats)
	
	# Divider
	var div = ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(0.2, 0.4, 0.5, 0.4)
	desc_vbox.add_child(div)
	
	desc_body = Label.new()
	desc_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var d_body_set = LabelSettings.new()
	d_body_set.font_size = 18
	d_body_set.font_color = Color(0.9, 0.95, 1.0, 0.95)
	desc_body.label_settings = d_body_set
	desc_vbox.add_child(desc_body)

	# --- FOOTER BUTTONS ---
	var footer_hbox = HBoxContainer.new()
	footer_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_hbox.add_theme_constant_override("separation", 40)
	footer_hbox.anchor_left = 0.0
	footer_hbox.anchor_right = 1.0
	footer_hbox.anchor_top = 0.91
	footer_hbox.anchor_bottom = 0.91
	footer_hbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	footer_hbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(footer_hbox)
	
	back_btn = Button.new()
	back_btn.text = "戻る"
	back_btn.custom_minimum_size = Vector2(180, 52)
	back_btn.add_theme_font_size_override("font_size", 22)
	footer_hbox.add_child(back_btn)
	style_action_btn(back_btn, Color(0.6, 0.6, 0.6), Color(0.8, 0.8, 0.8))
	back_btn.pressed.connect(_on_back_pressed)
	
	deploy_btn = Button.new()
	deploy_btn.text = "出撃開始"
	deploy_btn.custom_minimum_size = Vector2(240, 52)
	deploy_btn.add_theme_font_size_override("font_size", 22)
	footer_hbox.add_child(deploy_btn)
	style_action_btn(deploy_btn, Color.CYAN, Color(0.4, 1.0, 1.0))
	deploy_btn.pressed.connect(_on_deploy_pressed)

func create_section_vbox(title_text: String, parent: Node) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	parent.add_child(vbox)
	
	var lbl = Label.new()
	lbl.text = title_text
	var l_set = LabelSettings.new()
	l_set.font_size = 18
	l_set.font_color = Color.CYAN
	lbl.label_settings = l_set
	vbox.add_child(lbl)
	
	return vbox

const PIXEL_FONT: Font = preload("res://game/assets/fonts/DotGothic16-Regular.ttf")

func style_config_button(btn: Button, accent_color: Color) -> void:
	if PIXEL_FONT:
		btn.add_theme_font_override("font", PIXEL_FONT)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.95)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.2, 0.25, 0.35)
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	
	btn.mouse_entered.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.08)
	)
	btn.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
	)

func style_action_btn(btn: Button, border: Color, hover_border: Color) -> void:
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
	
	var sb_hover = sb.duplicate()
	sb_hover.bg_color = Color(0.1, 0.12, 0.22, 0.95)
	sb_hover.border_color = hover_border
	
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	
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

func select_item(type: String, id: String) -> void:
	match type:
		"primary":
			selected_primary = id
		"shield":
			selected_shield = id
		"counter":
			selected_counter = id
			
	update_button_states()
	show_details(type, id)

func update_button_states() -> void:
	# 1. Primaries
	for id in primary_buttons.keys():
		var btn = primary_buttons[id] as Button
		var sb = btn.get_theme_stylebox("normal") as StyleBoxFlat
		if id == selected_primary:
			sb.border_color = Color.CYAN
			sb.bg_color = Color(0.08, 0.14, 0.18)
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			sb.border_color = Color(0.2, 0.2, 0.25)
			sb.bg_color = Color(0.05, 0.05, 0.08)
			btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			
	# 2. Shields
	for id in shield_buttons.keys():
		var btn = shield_buttons[id] as Button
		var sb = btn.get_theme_stylebox("normal") as StyleBoxFlat
		if id == selected_shield:
			sb.border_color = Color.GREEN
			sb.bg_color = Color(0.05, 0.15, 0.08)
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			sb.border_color = Color(0.2, 0.2, 0.25)
			sb.bg_color = Color(0.05, 0.05, 0.08)
			btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			
	# 3. Counters
	for id in counter_buttons.keys():
		var btn = counter_buttons[id] as Button
		var sb = btn.get_theme_stylebox("normal") as StyleBoxFlat
		if id == selected_counter:
			sb.border_color = Color.GOLD
			sb.bg_color = Color(0.18, 0.14, 0.05)
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			sb.border_color = Color(0.2, 0.2, 0.25)
			sb.bg_color = Color(0.05, 0.05, 0.08)
			btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

func show_details(type: String, id: String) -> void:
	var item: LoadoutItem = null
	var type_label = ""
	var accent = Color.WHITE
	
	match type:
		"primary":
			for w in primary_weapons:
				if w.id == id:
					item = w
			type_label = "主兵装（メイン）"
			accent = Color.CYAN
		"shield":
			for s in shields:
				if s.id == id:
					item = s
			type_label = "シールド（防御）"
			accent = Color.GREEN
		"counter":
			for c in counter_weapons:
				if c.id == id:
					item = c
			type_label = "カウンター兵装"
			accent = Color.GOLD
			
	if item:
		desc_title.text = item.name
		desc_type.text = type_label
		desc_type.label_settings.font_color = accent
		desc_stats.text = item.stats
		desc_body.text = item.description
		
		# Pulse the desc border panel
		var sb = desc_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if sb:
			var t = create_tween()
			t.tween_property(sb, "border_color", accent, 0.15)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://game/core/stage_selection.tscn")

func _on_deploy_pressed() -> void:
	# Save changes to Global
	Global.equipped_weapon = selected_primary
	Global.equipped_shield = selected_shield
	
	# Save custom data temporarily inside global config
	var save_data = Global.load_game_data()
	Global.save_game(save_data.get("stage_num", 1), save_data.get("score", 0), {})
	
	# Start Stage
	get_tree().change_scene_to_file("res://game/main.tscn")

# ----------------- Background Starfield -----------------

func init_starfield() -> void:
	var viewport_size = get_viewport_rect().size
	for i in range(NUM_STARS):
		var star = BGStar.new()
		star.pos = Vector2(randf() * viewport_size.x, randf() * viewport_size.y)
		star.speed = randf_range(15.0, 45.0)
		star.size = randf_range(0.8, 2.5)
		star.color = Color(0.3, 0.6, 0.9, randf_range(0.2, 0.5))
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
	
	# Stars
	for star in stars:
		draw_circle(star.pos, star.size, star.color)
		
	# Tech blueprint grid styling (subtle crosshairs and lines)
	var grid_color = Color(0.1, 0.3, 0.5, 0.03)
	var spacing = 50.0
	for x in range(0, int(v_size.x), int(spacing)):
		draw_line(Vector2(x, 0), Vector2(x, v_size.y), grid_color, 1.0)
	for y in range(0, int(v_size.y), int(spacing)):
		draw_line(Vector2(0, y), Vector2(v_size.x, y), grid_color, 1.0)
