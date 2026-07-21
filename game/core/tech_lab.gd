extends Control

# Upgrade item structure
class UpgradeItem:
	var id: String
	var name: String
	var description: String
	var current_level: int = 0
	var max_level: int = 5
	var base_cost: int = 10
	var cost_multiplier: float = 1.5

var tech_points_label: Label
var hp_lvl_lbl: Label
var hp_cost_btn: Button
var parry_lvl_lbl: Label
var parry_cost_btn: Button
var cd_lvl_lbl: Label
var cd_cost_btn: Button

# Weapon research buttons
var plasma_btn: Button
var tackle_btn: Button

var back_btn: Button
var demo_btn: Button

# Background styling
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
	Global.load_game_data()
	
	# Give starting points if none exists for a better first-time demo experience
	if Global.tech_points == 0 and not Global.has_save:
		Global.tech_points = 30
		Global.save_game(1, 0, {})
		
	setup_ui()
	init_starfield()
	update_lab_hud()

func _process(delta: float) -> void:
	time_passed += delta
	update_starfield(delta)
	queue_redraw()

func setup_ui() -> void:
	# 1. Base dark background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	
	# 2. Main lab container
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.08
	vbox.anchor_top = 0.08
	vbox.anchor_right = 0.92
	vbox.anchor_bottom = 0.92
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.offset_left = 0
	vbox.offset_right = 0
	vbox.offset_top = 0
	vbox.offset_bottom = 0
	vbox.add_theme_constant_override("separation", 18)
	add_child(vbox)
	
func setup_ui() -> void:
	# 1. Base dark background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	
	# 2. Main lab container
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.08
	vbox.anchor_top = 0.06
	vbox.anchor_right = 0.92
	vbox.anchor_bottom = 0.94
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.offset_left = 0
	vbox.offset_right = 0
	vbox.offset_top = 0
	vbox.offset_bottom = 0
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)
	
	# Title Section
	var title_lbl = Label.new()
	title_lbl.text = "機体強化ラボ"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_set = LabelSettings.new()
	title_set.font_size = 38
	title_set.font_color = Color.GOLD
	title_set.outline_size = 8
	title_set.outline_color = Color.BLACK
	title_lbl.label_settings = title_set
	vbox.add_child(title_lbl)
	
	# HUD Panel for Tech Points
	var hud_panel = PanelContainer.new()
	hud_panel.custom_minimum_size = Vector2(300, 54)
	hud_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hud_panel)
	
	var sb_hud = StyleBoxFlat.new()
	sb_hud.bg_color = Color(0.1, 0.08, 0.14, 0.9)
	sb_hud.border_width_left = 2
	sb_hud.border_width_top = 2
	sb_hud.border_width_right = 2
	sb_hud.border_width_bottom = 2
	sb_hud.border_color = Color.GOLD
	sb_hud.corner_radius_top_left = 6
	sb_hud.corner_radius_top_right = 6
	sb_hud.corner_radius_bottom_left = 6
	sb_hud.corner_radius_bottom_right = 6
	sb_hud.shadow_color = Color(0.9, 0.7, 0.1, 0.15)
	sb_hud.shadow_size = 8
	hud_panel.add_theme_stylebox_override("panel", sb_hud)
	
	tech_points_label = Label.new()
	tech_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tech_points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tech_set = LabelSettings.new()
	tech_set.font_size = 24
	tech_set.font_color = Color.GOLD
	tech_set.outline_size = 4
	tech_set.outline_color = Color.BLACK
	tech_points_label.label_settings = tech_set
	hud_panel.add_child(tech_points_label)
	
	# --- SECTION 1: BASIC CAPABILITY ENHANCEMENTS ---
	var cap_sec = create_section_vbox("基礎能力の強化", vbox)
	
	# HP Enhancement Row
	var hp_row = create_upgrade_row(
		"最大HP増加", 
		"装甲を補強し、最大HPを+10増加。",
		cap_sec
	)
	hp_lvl_lbl = hp_row.level_label
	hp_cost_btn = hp_row.cost_button
	hp_cost_btn.pressed.connect(func(): perform_upgrade("hp"))
	
	# Parry Area Row
	var parry_row = create_upgrade_row(
		"パリィ範囲拡大", 
		"シールド範囲を拡張し、パリィを容易にする。",
		cap_sec
	)
	parry_lvl_lbl = parry_row.level_label
	parry_cost_btn = parry_row.cost_button
	parry_cost_btn.pressed.connect(func(): perform_upgrade("parry_window"))
	
	# Cooldown Row
	var cd_row = create_upgrade_row(
		"冷却時間短縮", 
		"冷却機構を強化し、パリィの再使用時間を短縮。",
		cap_sec
	)
	cd_lvl_lbl = cd_row.level_label
	cd_cost_btn = cd_row.cost_button
	cd_cost_btn.pressed.connect(func(): perform_upgrade("cooldown"))
	
	# --- SECTION 2: WEAPONS ANALYSIS & RESEARCH ---
	var wp_sec = create_section_vbox("兵装開発", vbox)
	var wp_vbox = VBoxContainer.new()
	wp_vbox.add_theme_constant_override("separation", 10)
	wp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wp_sec.add_child(wp_vbox)
	
	# Plasma weapon card
	var plasma_card = create_weapon_research_card(
		"プラズマ放射器",
		"持続ダメージを与える熱プラズマを放射。",
		"コスト: 40 TP",
		wp_vbox
	)
	plasma_btn = plasma_card.unlock_button
	plasma_btn.pressed.connect(func(): unlock_weapon("plasma_emitter", 40))
	
	# Tackle weapon card
	var tackle_card = create_weapon_research_card(
		"タックル",
		"機体体当たり攻撃。近距離超威力。",
		"コスト: 50 TP",
		wp_vbox
	)
	tackle_btn = tackle_card.unlock_button
	tackle_btn.pressed.connect(func(): unlock_weapon("kinetic_tackle", 50))

	# --- FOOTER ---
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
	style_btn(back_btn, Color(0.6, 0.6, 0.6), Color(0.8, 0.8, 0.8))
	back_btn.pressed.connect(_on_back_pressed)
	
	demo_btn = Button.new()
	demo_btn.text = "+50 TP (デバッグ)"
	demo_btn.custom_minimum_size = Vector2(220, 52)
	demo_btn.add_theme_font_size_override("font_size", 20)
	footer_hbox.add_child(demo_btn)
	style_btn(demo_btn, Color.GOLD, Color(1.0, 0.85, 0.3))
	demo_btn.pressed.connect(_on_demo_pressed)

func create_section_vbox(title_text: String, parent: Node) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	parent.add_child(vbox)
	
	var lbl = Label.new()
	lbl.text = title_text
	var l_set = LabelSettings.new()
	l_set.font_size = 20
	l_set.font_color = Color.CYAN
	lbl.label_settings = l_set
	vbox.add_child(lbl)
	
	return vbox

# Helper class to return row nodes
class UpgradeRowNodes:
	var level_label: Label
	var cost_button: Button

func create_upgrade_row(title_text: String, desc_text: String, parent: Node) -> UpgradeRowNodes:
	var row_panel = PanelContainer.new()
	parent.add_child(row_panel)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.1, 0.7)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.2, 0.2, 0.3)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	row_panel.add_theme_stylebox_override("panel", sb)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 10)
	row_panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)
	
	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(text_vbox)
	
	var title = Label.new()
	title.text = title_text
	var t_set = LabelSettings.new()
	t_set.font_size = 18
	t_set.font_color = Color.WHITE
	title.label_settings = t_set
	text_vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = desc_text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var d_set = LabelSettings.new()
	d_set.font_size = 15
	d_set.font_color = Color(0.7, 0.8, 0.9)
	desc.label_settings = d_set
	text_vbox.add_child(desc)
	
	# Current Level indicator
	var lvl_lbl = Label.new()
	lvl_lbl.text = "LV. 0"
	lvl_lbl.custom_minimum_size = Vector2(80, 0)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var l_set = LabelSettings.new()
	l_set.font_size = 18
	l_set.font_color = Color.CYAN
	l_set.outline_size = 4
	l_set.outline_color = Color.BLACK
	lvl_lbl.label_settings = l_set
	hbox.add_child(lvl_lbl)
	
	# Upgrade Button
	var cost_btn = Button.new()
	cost_btn.text = "強化\n(10 TP)"
	cost_btn.custom_minimum_size = Vector2(130, 48)
	cost_btn.add_theme_font_size_override("font_size", 16)
	hbox.add_child(cost_btn)
	style_action_btn(cost_btn, Color.CYAN)
	
	var ret = UpgradeRowNodes.new()
	ret.level_label = lvl_lbl
	ret.cost_button = cost_btn
	return ret

class WeaponCardNodes:
	var unlock_button: Button

func create_weapon_research_card(w_name: String, w_desc: String, cost_text: String, parent: Node) -> WeaponCardNodes:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 110)
	parent.add_child(card)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.1, 0.7)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.2, 0.2, 0.3)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	card.add_theme_stylebox_override("panel", sb)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	var name_lbl = Label.new()
	name_lbl.text = w_name
	var n_set = LabelSettings.new()
	n_set.font_size = 20
	n_set.font_color = Color.WHITE
	name_lbl.label_settings = n_set
	vbox.add_child(name_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = w_desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(0, 36)
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var d_set = LabelSettings.new()
	d_set.font_size = 16
	d_set.font_color = Color(0.7, 0.8, 0.9)
	desc_lbl.label_settings = d_set
	vbox.add_child(desc_lbl)
	
	# Action button
	var btn = Button.new()
	btn.text = "開発 (" + cost_text + ")"
	btn.custom_minimum_size = Vector2(0, 42)
	btn.add_theme_font_size_override("font_size", 18)
	vbox.add_child(btn)
	style_action_btn(btn, Color.GOLD)
	
	var ret = WeaponCardNodes.new()
	ret.unlock_button = btn
	return ret

func style_action_btn(btn: Button, accent_color: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.07, 0.8)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = accent_color
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	
	var sb_hover = sb.duplicate()
	sb_hover.bg_color = Color(accent_color.r * 0.15, accent_color.g * 0.15, accent_color.b * 0.15)
	
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	
	btn.mouse_entered.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.08)
	)
	btn.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
	)

func style_btn(btn: Button, border: Color, hover_border: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.1, 0.95)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = border
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	
	var sb_hover = sb.duplicate()
	sb_hover.border_color = hover_border
	sb_hover.bg_color = Color(0.12, 0.12, 0.2, 0.95)
	
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

func update_lab_hud() -> void:
	tech_points_label.text = "所持ポイント: " + str(Global.tech_points) + " TP"
	
	# 1. HP Upgrade button state
	var hp_lvl = Global.upgrade_levels.get("hp", 0)
	hp_lvl_lbl.text = "LV. " + str(hp_lvl)
	if hp_lvl >= 5:
		hp_lvl_lbl.text = "MAX"
		hp_cost_btn.disabled = true
		hp_cost_btn.text = "MAX"
	else:
		var cost = get_upgrade_cost("hp", hp_lvl)
		hp_cost_btn.text = "強化\n(" + str(cost) + " TP)"
		hp_cost_btn.disabled = Global.tech_points < cost

	# 2. Parry Window Upgrade button state
	var parry_lvl = Global.upgrade_levels.get("parry_window", 0)
	parry_lvl_lbl.text = "LV. " + str(parry_lvl)
	if parry_lvl >= 5:
		parry_lvl_lbl.text = "MAX"
		parry_cost_btn.disabled = true
		parry_cost_btn.text = "MAX"
	else:
		var cost = get_upgrade_cost("parry_window", parry_lvl)
		parry_cost_btn.text = "強化\n(" + str(cost) + " TP)"
		parry_cost_btn.disabled = Global.tech_points < cost

	# 3. Cooldown Upgrade button state
	var cd_lvl = Global.upgrade_levels.get("cooldown", 0)
	cd_lvl_lbl.text = "LV. " + str(cd_lvl)
	if cd_lvl >= 5:
		cd_lvl_lbl.text = "MAX"
		cd_cost_btn.disabled = true
		cd_cost_btn.text = "MAX"
	else:
		var cost = get_upgrade_cost("cooldown", cd_lvl)
		cd_cost_btn.text = "強化\n(" + str(cost) + " TP)"
		cd_cost_btn.disabled = Global.tech_points < cost

	# 4. Weapons Research states
	if Global.unlocked_weapons.has("plasma_emitter"):
		plasma_btn.disabled = true
		plasma_btn.text = "開発完了"
	else:
		plasma_btn.disabled = Global.tech_points < 40
		plasma_btn.text = "開発 (40 TP)"

	if Global.unlocked_weapons.has("kinetic_tackle"):
		tackle_btn.disabled = true
		tackle_btn.text = "開発完了"
	else:
		tackle_btn.disabled = Global.tech_points < 50
		tackle_btn.text = "開発 (50 TP)"

func get_upgrade_cost(type: String, current_lvl: int) -> int:
	match type:
		"hp":
			return 10 + current_lvl * 8
		"parry_window":
			return 12 + current_lvl * 10
		"cooldown":
			return 15 + current_lvl * 12
	return 999

func perform_upgrade(type: String) -> void:
	var lvl = Global.upgrade_levels.get(type, 0)
	var cost = get_upgrade_cost(type, lvl)
	
	if Global.tech_points >= cost and lvl < 5:
		Global.tech_points -= cost
		Global.upgrade_levels[type] = lvl + 1
		Global.save_game(1, 0, {})
		update_lab_hud()
		play_flash_effect(Color.CYAN)

func unlock_weapon(w_id: String, cost: int) -> void:
	if Global.tech_points >= cost and not Global.unlocked_weapons.has(w_id):
		Global.tech_points -= cost
		Global.unlocked_weapons.append(w_id)
		Global.save_game(1, 0, {})
		update_lab_hud()
		play_flash_effect(Color.GOLD)

func play_flash_effect(color: Color) -> void:
	# Subtle HUD border glow pulse tween
	var parent_panel = tech_points_label.get_parent() as PanelContainer
	var sb = parent_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		var orig = sb.border_color
		var tween = create_tween()
		tween.tween_property(sb, "border_color", color, 0.08)
		tween.tween_property(sb, "border_color", orig, 0.25)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://game/core/stage_selection.tscn")

func _on_demo_pressed() -> void:
	Global.tech_points += 50
	Global.save_game(1, 0, {})
	update_lab_hud()
	play_flash_effect(Color.GREEN)

# ----------------- Starfield & Grid Draw -----------------

func init_starfield() -> void:
	var viewport_size = get_viewport_rect().size
	for i in range(NUM_STARS):
		var star = BGStar.new()
		star.pos = Vector2(randf() * viewport_size.x, randf() * viewport_size.y)
		star.speed = randf_range(10.0, 30.0)
		star.size = randf_range(0.8, 2.2)
		star.color = Color(0.8, 0.6, 1.0, randf_range(0.15, 0.45)) # Lavender/purple
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
		
	# Lavender/Purple tech laboratory grid lines
	var grid_color = Color(0.6, 0.3, 0.8, 0.02)
	var spacing = 65.0
	for x in range(0, int(v_size.x), int(spacing)):
		draw_line(Vector2(x, 0), Vector2(x, v_size.y), grid_color, 1.0)
	for y in range(0, int(v_size.y), int(spacing)):
		draw_line(Vector2(0, y), Vector2(v_size.x, y), grid_color, 1.0)
