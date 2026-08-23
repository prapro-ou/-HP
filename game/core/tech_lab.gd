extends Control

## 機体強化ラボ (TECH LAB) スクリプト
## - 基礎能力強化、フォーカス設定、COUNTER SYSTEM強化、特殊兵装・シールド開発をカテゴリごとにタブ切り替え・スクロール表示
## - 各設定切り替え時のレイアウト固定（サイズガタつき防止）

const PIXEL_FONT: Font = preload("res://game/assets/fonts/DotGothic16-Regular.ttf")

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

# Focus mode tuning variables
var focus_mode_btn: Button
var focus_mode_desc_lbl: Label
var focus_mode_stat_lbl: Label
var focus_mode_sub_lbl: Label

# COUNTER SYSTEM enhancement variables
var cs_dur_lvl_lbl: Label
var cs_dur_cost_btn: Button
var cs_pwr_lvl_lbl: Label
var cs_pwr_cost_btn: Button

# COUNTER ONLY mode variables
var counter_only_btn: Button
var counter_only_status_lbl: Label

# Shield research buttons
var shield_gauge_btn: Button
var shield_power_btn: Button

# Weapon research buttons
var plasma_btn: Button
var tackle_btn: Button

var back_btn: Button
var demo_btn: Button

# Tab management
var current_tab: String = "basic"
var tab_buttons: Dictionary = {}
var page_containers: Dictionary = {}
var scroll_container: ScrollContainer

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
	
	# Tech Lab uses SFX only (Stop BGM)
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("stop_bgm"):
		audio_mgr.stop_bgm(0.3)
	
	# Give starting points if none exists for a better first-time demo experience
	if Global.tech_points == 0 and not Global.has_save:
		Global.tech_points = 30
		Global.save_game(1, 0, {})
		
	setup_ui()
	init_starfield()
	update_lab_hud()
	switch_tab("basic")


func _process(delta: float) -> void:
	time_passed += delta
	update_starfield(delta)
	queue_redraw()


func setup_ui() -> void:
	# 1. Base dark background
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.035, 0.07, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	
	# 2. Main lab container
	var main_vbox = VBoxContainer.new()
	main_vbox.anchor_left = 0.03
	main_vbox.anchor_top = 0.02
	main_vbox.anchor_right = 0.97
	main_vbox.anchor_bottom = 0.98
	main_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)
	
	# Title Section
	var title_lbl = Label.new()
	title_lbl.text = "機体強化ラボ / TECH LAB"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_set = LabelSettings.new()
	if PIXEL_FONT:
		title_set.font = PIXEL_FONT
	title_set.font_size = 36
	title_set.font_color = Color.GOLD
	title_set.outline_size = 8
	title_set.outline_color = Color.BLACK
	title_lbl.label_settings = title_set
	main_vbox.add_child(title_lbl)
	
	# HUD Panel for Tech Points
	var hud_panel = PanelContainer.new()
	hud_panel.custom_minimum_size = Vector2(300, 48)
	hud_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(hud_panel)
	
	var sb_hud = StyleBoxFlat.new()
	sb_hud.bg_color = Color(0.08, 0.07, 0.13, 0.92)
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
	if PIXEL_FONT:
		tech_set.font = PIXEL_FONT
	tech_set.font_size = 22
	tech_set.font_color = Color.GOLD
	tech_set.outline_size = 4
	tech_set.outline_color = Color.BLACK
	tech_points_label.label_settings = tech_set
	hud_panel.add_child(tech_points_label)
	
	# 3. Category Tab Bar
	setup_tab_bar(main_vbox)
	
	# 4. Scroll Container for Category Pages
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_vbox.add_child(scroll_container)
	
	var content_margin = MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 4)
	content_margin.add_theme_constant_override("margin_top", 6)
	content_margin.add_theme_constant_override("margin_right", 4)
	content_margin.add_theme_constant_override("margin_bottom", 6)
	scroll_container.add_child(content_margin)
	
	var pages_root = VBoxContainer.new()
	pages_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(pages_root)
	
	# Build Page 1: 基礎能力 & フォーカス
	var page_basic = VBoxContainer.new()
	page_basic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_basic.add_theme_constant_override("separation", 14)
	pages_root.add_child(page_basic)
	page_containers["basic"] = page_basic
	build_basic_page(page_basic)
	
	# Build Page 2: COUNTER SYSTEM
	var page_counter = VBoxContainer.new()
	page_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_counter.add_theme_constant_override("separation", 14)
	pages_root.add_child(page_counter)
	page_containers["counter"] = page_counter
	build_counter_page(page_counter)
	
	# Build Page 3: 兵装 & シールド開発
	var page_tech = VBoxContainer.new()
	page_tech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_tech.add_theme_constant_override("separation", 14)
	pages_root.add_child(page_tech)
	page_containers["tech"] = page_tech
	build_tech_page(page_tech)
	
	# 5. Footer (戻る & デバッグ)
	var footer_hbox = HBoxContainer.new()
	footer_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_hbox.add_theme_constant_override("separation", 30)
	footer_hbox.custom_minimum_size = Vector2(0, 56)
	main_vbox.add_child(footer_hbox)
	
	back_btn = Button.new()
	back_btn.text = "作戦選択へ戻る"
	back_btn.custom_minimum_size = Vector2(220, 48)
	back_btn.add_theme_font_size_override("font_size", 20)
	footer_hbox.add_child(back_btn)
	style_btn(back_btn, Color(0.6, 0.6, 0.6), Color(0.85, 0.85, 0.85))
	back_btn.pressed.connect(_on_back_pressed)
	
	demo_btn = Button.new()
	demo_btn.text = "+50 TP (テスト用)"
	demo_btn.custom_minimum_size = Vector2(200, 48)
	demo_btn.add_theme_font_size_override("font_size", 18)
	footer_hbox.add_child(demo_btn)
	style_btn(demo_btn, Color.GOLD, Color(1.0, 0.88, 0.3))
	demo_btn.pressed.connect(_on_demo_pressed)


func setup_tab_bar(parent: Node) -> void:
	var tab_hbox = HBoxContainer.new()
	tab_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_hbox.add_theme_constant_override("separation", 8)
	tab_hbox.custom_minimum_size = Vector2(0, 46)
	parent.add_child(tab_hbox)
	
	var tabs_config = [
		{ "id": "basic", "title": "【1】基礎能力 ＆ 調整", "color": Color.CYAN },
		{ "id": "counter", "title": "【2】COUNTER SYSTEM", "color": Color(1.0, 0.45, 0.9) },
		{ "id": "tech", "title": "【3】兵装 ＆ シールド開発", "color": Color(1.0, 0.85, 0.25) }
	]
	
	for t in tabs_config:
		var btn = Button.new()
		btn.text = t["title"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 44)
		btn.add_theme_font_size_override("font_size", 18)
		if PIXEL_FONT:
			btn.add_theme_font_override("font", PIXEL_FONT)
		tab_hbox.add_child(btn)
		tab_buttons[t["id"]] = btn
		
		var tid: String = t["id"]
		btn.pressed.connect(func():
			switch_tab(tid)
		)


func style_tab_button(btn: Button, is_active: bool, accent_color: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	
	if is_active:
		sb.bg_color = Color(0.12, 0.16, 0.28, 0.95)
		sb.border_width_left = 2
		sb.border_width_top = 3
		sb.border_width_right = 2
		sb.border_width_bottom = 4
		sb.border_color = accent_color
		sb.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.3)
		sb.shadow_size = 8
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		sb.bg_color = Color(0.04, 0.05, 0.09, 0.85)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 2
		sb.border_color = Color(0.2, 0.25, 0.35, 0.7)
		btn.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
		
	var sb_hover = sb.duplicate()
	sb_hover.bg_color = Color(0.16, 0.20, 0.36, 0.95)
	sb_hover.border_color = accent_color.lerp(Color.WHITE, 0.3)
	
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("disabled", sb)


func switch_tab(tab_id: String) -> void:
	current_tab = tab_id
	for t_id in page_containers:
		if is_instance_valid(page_containers[t_id]):
			page_containers[t_id].visible = (t_id == tab_id)
	for t_id in tab_buttons:
		if is_instance_valid(tab_buttons[t_id]):
			var col = Color.CYAN if t_id == "basic" else (Color(1.0, 0.45, 0.9) if t_id == "counter" else Color.GOLD)
			style_tab_button(tab_buttons[t_id], t_id == tab_id, col)
	if is_instance_valid(scroll_container):
		scroll_container.scroll_vertical = 0
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_ui_select"):
		audio_mgr.play_ui_select()


func build_basic_page(parent: VBoxContainer) -> void:
	# SECTION: 基礎能力の強化
	var cap_sec = create_section_vbox("機体基礎スペック強化", parent)
	
	var hp_row = create_upgrade_row(
		"最大HP増加", 
		"装甲を補強し、最大HPを+50増加。",
		cap_sec
	)
	hp_lvl_lbl = hp_row.level_label
	hp_cost_btn = hp_row.cost_button
	hp_cost_btn.pressed.connect(func(): perform_upgrade("hp"))
	
	var parry_row = create_upgrade_row(
		"ジャストガード基本範囲拡大", 
		"全シールド共通の基本判定範囲を拡張し、ジャストガードを容易にする。",
		cap_sec
	)
	parry_lvl_lbl = parry_row.level_label
	parry_cost_btn = parry_row.cost_button
	parry_cost_btn.pressed.connect(func(): perform_upgrade("parry_window"))
	
	var cd_row = create_upgrade_row(
		"冷却時間短縮", 
		"冷却機構を強化し、シールドの再使用・放熱時間を短縮。",
		cap_sec
	)
	cd_lvl_lbl = cd_row.level_label
	cd_cost_btn = cd_row.cost_button
	cd_cost_btn.pressed.connect(func(): perform_upgrade("cooldown"))
	
	# SECTION: ジャストガード・フォーカス設定
	var focus_sec = create_section_vbox("ジャストガード・フォーカス設定 (効果範囲 ⇔ 威力調整)", parent)
	create_focus_tuning_ui(focus_sec)


func build_counter_page(parent: VBoxContainer) -> void:
	# SECTION: COUNTER SYSTEM 強化
	var cs_sec = create_section_vbox("COUNTER SYSTEM 兵装強化 (Xキー支援砲台部隊)", parent)
	
	var dur_row = create_upgrade_row(
		"支援砲台・展開持続時間",
		"ボスタレット支援部隊の滞在時間を延長 (10秒 -> 最大20秒)。",
		cs_sec
	)
	cs_dur_lvl_lbl = dur_row.level_label
	cs_dur_cost_btn = dur_row.cost_button
	cs_dur_cost_btn.pressed.connect(func(): perform_counter_system_upgrade("duration"))
	
	var pwr_row = create_upgrade_row(
		"支援砲台・攻撃力倍率",
		"支援タレットの全弾丸威力を大幅増幅 (1.0倍 -> 最大5.0倍)。",
		cs_sec
	)
	cs_pwr_lvl_lbl = pwr_row.level_label
	cs_pwr_cost_btn = pwr_row.cost_button
	cs_pwr_cost_btn.pressed.connect(func(): perform_counter_system_upgrade("power"))
	
	# SECTION: 極秘作戦 COUNTER ONLY
	var only_sec = create_section_vbox("極秘作戦：COUNTER ONLY 出撃モード", parent)
	create_counter_only_mode_ui(only_sec)


func build_tech_page(parent: VBoxContainer) -> void:
	# SECTION: 特殊シールド開発
	var sh_sec = create_section_vbox("特殊シールド開発 ＆ 固有機能解放", parent)
	var sh_vbox = VBoxContainer.new()
	sh_vbox.add_theme_constant_override("separation", 8)
	sh_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh_sec.add_child(sh_vbox)
	
	var gauge_card = create_weapon_research_card(
		"吸収マトリクス",
		"敵撃破時に解析エナジーオーブを放出し、自機へ磁力吸引！EXP＆HP修復。",
		"コスト: 30 TP",
		sh_vbox
	)
	shield_gauge_btn = gauge_card.unlock_button
	shield_gauge_btn.pressed.connect(func(): unlock_shield("gauge", 30))
	
	var power_card = create_weapon_research_card(
		"増幅ブースター",
		"ジャストガード成功時に弾丸を吸収し、主兵装の攻撃力を永続スタック強化。",
		"コスト: 30 TP",
		sh_vbox
	)
	shield_power_btn = power_card.unlock_button
	shield_power_btn.pressed.connect(func(): unlock_shield("power", 30))

	# SECTION: 特殊兵装開発
	var wp_sec = create_section_vbox("特殊主兵装開発", parent)
	var wp_vbox = VBoxContainer.new()
	wp_vbox.add_theme_constant_override("separation", 8)
	wp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wp_sec.add_child(wp_vbox)
	
	var plasma_card = create_weapon_research_card(
		"プラズマ放射器",
		"持続ダメージを与える熱プラズマを扇状放射。",
		"コスト: 40 TP",
		wp_vbox
	)
	plasma_btn = plasma_card.unlock_button
	plasma_btn.pressed.connect(func(): unlock_weapon("plasma_emitter", 40))
	
	var tackle_card = create_weapon_research_card(
		"タックル",
		"機体体当たり攻撃。近距離超威力の物理衝撃波。",
		"コスト: 50 TP",
		wp_vbox
	)
	tackle_btn = tackle_card.unlock_button
	tackle_btn.pressed.connect(func(): unlock_weapon("kinetic_tackle", 50))


func create_section_vbox(title_text: String, parent: Node) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	parent.add_child(vbox)
	
	var lbl = Label.new()
	lbl.text = title_text
	var l_set = LabelSettings.new()
	if PIXEL_FONT:
		l_set.font = PIXEL_FONT
	l_set.font_size = 20
	l_set.font_color = Color.CYAN
	lbl.label_settings = l_set
	vbox.add_child(lbl)
	
	return vbox


class UpgradeRowNodes:
	var level_label: Label
	var cost_button: Button

func create_upgrade_row(title_text: String, desc_text: String, parent: Node) -> UpgradeRowNodes:
	var row_panel = PanelContainer.new()
	parent.add_child(row_panel)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.1, 0.75)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.2, 0.24, 0.35)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	row_panel.add_theme_stylebox_override("panel", sb)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
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
	if PIXEL_FONT:
		t_set.font = PIXEL_FONT
	t_set.font_size = 19
	t_set.font_color = Color.WHITE
	title.label_settings = t_set
	text_vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = desc_text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var d_set = LabelSettings.new()
	d_set.font = Global.get_readable_font()
	d_set.font_size = 15
	d_set.font_color = Color(0.75, 0.85, 0.95)
	desc.label_settings = d_set
	text_vbox.add_child(desc)
	
	# Current Level indicator
	var lvl_lbl = Label.new()
	lvl_lbl.text = "LV. 0"
	lvl_lbl.custom_minimum_size = Vector2(90, 0)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var l_set = LabelSettings.new()
	if PIXEL_FONT:
		l_set.font = PIXEL_FONT
	l_set.font_size = 19
	l_set.font_color = Color.CYAN
	l_set.outline_size = 4
	l_set.outline_color = Color.BLACK
	lvl_lbl.label_settings = l_set
	hbox.add_child(lvl_lbl)
	
	# Upgrade Button
	var cost_btn = Button.new()
	cost_btn.text = "強化\n(10 TP)"
	cost_btn.custom_minimum_size = Vector2(130, 48)
	cost_btn.add_theme_font_size_override("font_size", 17)
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
	sb.bg_color = Color(0.06, 0.06, 0.1, 0.75)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.2, 0.24, 0.35)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	card.add_theme_stylebox_override("panel", sb)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	var name_lbl = Label.new()
	name_lbl.text = w_name
	var n_set = LabelSettings.new()
	if PIXEL_FONT:
		n_set.font = PIXEL_FONT
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
	d_set.font = Global.get_readable_font()
	d_set.font_size = 15
	d_set.font_color = Color(0.75, 0.85, 0.95)
	desc_lbl.label_settings = d_set
	vbox.add_child(desc_lbl)
	
	# Action button
	var btn = Button.new()
	btn.text = "開発 (" + cost_text + ")"
	btn.custom_minimum_size = Vector2(0, 42)
	btn.add_theme_font_size_override("font_size", 17)
	if PIXEL_FONT:
		btn.add_theme_font_override("font", PIXEL_FONT)
	vbox.add_child(btn)
	style_action_btn(btn, Color.GOLD)
	
	var ret = WeaponCardNodes.new()
	ret.unlock_button = btn
	return ret


func create_focus_tuning_ui(parent: Control) -> void:
	var card_panel = PanelContainer.new()
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_panel.custom_minimum_size = Vector2(0, 135)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.16, 0.85)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.3, 0.75, 1.0, 0.5)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	card_panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(card_panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	card_panel.add_child(margin)
	
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)
	
	var top_hb = HBoxContainer.new()
	top_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(top_hb)
	
	var text_left = VBoxContainer.new()
	text_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_left.add_theme_constant_override("separation", 2)
	top_hb.add_child(text_left)
	
	focus_mode_stat_lbl = Label.new()
	focus_mode_stat_lbl.text = "設定: STANDARD [標準範囲]"
	var f_set = LabelSettings.new()
	if PIXEL_FONT:
		f_set.font = PIXEL_FONT
	f_set.font_size = 18
	f_set.font_color = Color.WHITE
	focus_mode_stat_lbl.label_settings = f_set
	text_left.add_child(focus_mode_stat_lbl)
	
	focus_mode_sub_lbl = Label.new()
	focus_mode_sub_lbl.text = "範囲: 100% ｜ 反射威力: 1.0倍"
	var sub_set = LabelSettings.new()
	if PIXEL_FONT:
		sub_set.font = PIXEL_FONT
	sub_set.font_size = 15
	sub_set.font_color = Color(0.35, 0.85, 1.0)
	focus_mode_sub_lbl.label_settings = sub_set
	text_left.add_child(focus_mode_sub_lbl)
	
	focus_mode_btn = Button.new()
	focus_mode_btn.text = "設定切替\n[CLICK]"
	focus_mode_btn.custom_minimum_size = Vector2(150, 44)
	focus_mode_btn.add_theme_font_size_override("font_size", 16)
	style_neon_button(focus_mode_btn, Color(0.3, 0.75, 1.0), Color.CYAN)
	focus_mode_btn.pressed.connect(func():
		Global.just_guard_focus_mode = (Global.just_guard_focus_mode + 1) % 3
		Global.save_game(1, 0, {})
		update_lab_hud()
		play_flash_effect(Color.CYAN)
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_upgrade_success"):
			audio_mgr.play_upgrade_success()
	)
	top_hb.add_child(focus_mode_btn)
	
	focus_mode_desc_lbl = Label.new()
	focus_mode_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	focus_mode_desc_lbl.custom_minimum_size = Vector2(0, 40)
	focus_mode_desc_lbl.text = "安定した標準範囲でのジャストガード。"
	var fd_set = LabelSettings.new()
	fd_set.font = Global.get_readable_font()
	fd_set.font_size = 15
	fd_set.font_color = Color(0.75, 0.88, 1.0, 0.95)
	focus_mode_desc_lbl.label_settings = fd_set
	vb.add_child(focus_mode_desc_lbl)


func create_counter_only_mode_ui(parent: Control) -> void:
	var card_panel = PanelContainer.new()
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_panel.custom_minimum_size = Vector2(0, 120)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.16, 0.85)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(1.0, 0.4, 0.8, 0.5)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	card_panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(card_panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	card_panel.add_child(margin)
	
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)
	
	var top_hb = HBoxContainer.new()
	vb.add_child(top_hb)
	
	counter_only_status_lbl = Label.new()
	counter_only_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	counter_only_status_lbl.custom_minimum_size = Vector2(0, 26)
	counter_only_status_lbl.text = "COUNTER ONLY 出撃: 【未解放】"
	var co_set = LabelSettings.new()
	if PIXEL_FONT:
		co_set.font = PIXEL_FONT
	co_set.font_size = 18
	co_set.font_color = Color.WHITE
	counter_only_status_lbl.label_settings = co_set
	top_hb.add_child(counter_only_status_lbl)
	
	counter_only_btn = Button.new()
	counter_only_btn.text = "極秘作戦解放"
	counter_only_btn.custom_minimum_size = Vector2(160, 38)
	counter_only_btn.add_theme_font_size_override("font_size", 16)
	style_neon_button(counter_only_btn, Color(1.0, 0.3, 0.8), Color.MAGENTA)
	counter_only_btn.pressed.connect(func():
		if not Global.counter_only_mode_unlocked:
			if Global.stage5_clears_count >= 5 and Global.tech_points >= 150:
				Global.tech_points -= 150
				Global.counter_only_mode_unlocked = true
				Global.counter_only_mode_enabled = true
				Global.save_game(1, 0, {})
				update_lab_hud()
				play_flash_effect(Color.MAGENTA)
				var audio_mgr = get_node_or_null("/root/AudioManager")
				if audio_mgr and audio_mgr.has_method("play_upgrade_success"):
					audio_mgr.play_upgrade_success()
		else:
			Global.counter_only_mode_enabled = not Global.counter_only_mode_enabled
			Global.save_game(1, 0, {})
			update_lab_hud()
			play_flash_effect(Color.MAGENTA)
			var audio_mgr = get_node_or_null("/root/AudioManager")
			if audio_mgr and audio_mgr.has_method("play_upgrade_success"):
				audio_mgr.play_upgrade_success()
	)
	top_hb.add_child(counter_only_btn)
	
	var desc_lbl = Label.new()
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(0, 46)
	desc_lbl.text = "【解放条件: STAGE 5を5回クリア ＆ 150 TP】\n自機の通常射撃を行わず、4基のボスタレット支援部隊が常時・自動で自機を守護・殲滅する超爽快モード！"
	var cod_set = LabelSettings.new()
	cod_set.font = Global.get_readable_font()
	cod_set.font_size = 15
	cod_set.font_color = Color(1.0, 0.82, 0.92, 0.95)
	desc_lbl.label_settings = cod_set
	vb.add_child(desc_lbl)


func update_lab_hud() -> void:
	tech_points_label.text = "所持ポイント: " + str(Global.tech_points) + " TP"
	
	# 1. HP Upgrade button state
	if is_instance_valid(hp_lvl_lbl) and is_instance_valid(hp_cost_btn):
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
	if is_instance_valid(parry_lvl_lbl) and is_instance_valid(parry_cost_btn):
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
	if is_instance_valid(cd_lvl_lbl) and is_instance_valid(cd_cost_btn):
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

	# 4. Focus mode state
	if is_instance_valid(focus_mode_stat_lbl) and is_instance_valid(focus_mode_desc_lbl):
		var f_info = Global.get_focus_mode_info()
		focus_mode_stat_lbl.text = "設定: " + f_info.get("name", "STANDARD")
		if is_instance_valid(focus_mode_sub_lbl):
			focus_mode_sub_lbl.text = "範囲: %s ｜ 反射威力: %s" % [f_info.get("radius_pct", "100%"), f_info.get("dmg_mult", "1.0倍")]
		focus_mode_desc_lbl.text = f_info.get("description", "")

	# 5. COUNTER SYSTEM Duration state (10s -> 20s)
	if is_instance_valid(cs_dur_lvl_lbl) and is_instance_valid(cs_dur_cost_btn):
		var dur_lvl = Global.counter_system_duration_lvl
		var cur_dur = Global.get_counter_system_duration()
		cs_dur_lvl_lbl.text = "LV. %d (%.0fs)" % [dur_lvl, cur_dur]
		if dur_lvl >= 5:
			cs_dur_lvl_lbl.text = "MAX (20s)"
			cs_dur_cost_btn.disabled = true
			cs_dur_cost_btn.text = "MAX"
		else:
			var cost = 15 + dur_lvl * 15
			cs_dur_cost_btn.text = "強化\n(%d TP)" % cost
			cs_dur_cost_btn.disabled = Global.tech_points < cost

	# 6. COUNTER SYSTEM Power state (1.0x -> 5.0x)
	if is_instance_valid(cs_pwr_lvl_lbl) and is_instance_valid(cs_pwr_cost_btn):
		var pwr_lvl = Global.counter_system_power_lvl
		var cur_pwr = Global.get_counter_system_power_multiplier()
		cs_pwr_lvl_lbl.text = "LV. %d (%.1fx)" % [pwr_lvl, cur_pwr]
		if pwr_lvl >= 5:
			cs_pwr_lvl_lbl.text = "MAX (5.0x)"
			cs_pwr_cost_btn.disabled = true
			cs_pwr_cost_btn.text = "MAX"
		else:
			var cost = 20 + pwr_lvl * 20
			cs_pwr_cost_btn.text = "強化\n(%d TP)" % cost
			cs_pwr_cost_btn.disabled = Global.tech_points < cost

	# 7. COUNTER ONLY Mode state
	if is_instance_valid(counter_only_status_lbl) and is_instance_valid(counter_only_btn):
		if not Global.counter_only_mode_unlocked:
			var clears = Global.stage5_clears_count
			counter_only_status_lbl.text = "COUNTER ONLY 出撃: 【未解放】 (STAGE 5 クリア: %d/5回)" % clears
			if clears < 5:
				counter_only_btn.disabled = true
				counter_only_btn.text = "条件未達成\n(%d/5回)" % clears
			else:
				counter_only_btn.disabled = Global.tech_points < 150
				counter_only_btn.text = "極秘解放\n(150 TP)"
		else:
			if Global.counter_only_mode_enabled:
				counter_only_status_lbl.text = "COUNTER ONLY 出撃: 【有効 (砲台部隊専任出撃中)】"
				counter_only_btn.disabled = false
				counter_only_btn.text = "出撃設定:\n【有効 (ON)】"
			else:
				counter_only_status_lbl.text = "COUNTER ONLY 出撃: 【無効 (通常出撃)】"
				counter_only_btn.disabled = false
				counter_only_btn.text = "出撃設定:\n【無効 (OFF)】"

	# 8. Shields Research states (30 TP each)
	if is_instance_valid(shield_gauge_btn):
		if Global.unlocked_shields.has("gauge"):
			shield_gauge_btn.disabled = true
			shield_gauge_btn.text = "開発完了"
		else:
			shield_gauge_btn.disabled = Global.tech_points < 30
			shield_gauge_btn.text = "開発 (30 TP)"

	if is_instance_valid(shield_power_btn):
		if Global.unlocked_shields.has("power"):
			shield_power_btn.disabled = true
			shield_power_btn.text = "開発完了"
		else:
			shield_power_btn.disabled = Global.tech_points < 30
			shield_power_btn.text = "開発 (30 TP)"

	# 9. Weapons Research states
	if is_instance_valid(plasma_btn):
		if Global.unlocked_weapons.has("plasma_emitter"):
			plasma_btn.disabled = true
			plasma_btn.text = "開発完了"
		else:
			plasma_btn.disabled = Global.tech_points < 40
			plasma_btn.text = "開発 (40 TP)"

	if is_instance_valid(tackle_btn):
		if Global.unlocked_weapons.has("kinetic_tackle"):
			tackle_btn.disabled = true
			tackle_btn.text = "開発完了"
		else:
			tackle_btn.disabled = Global.tech_points < 50
			tackle_btn.text = "開発 (50 TP)"


func perform_counter_system_upgrade(type: String) -> void:
	if type == "duration":
		var lvl = Global.counter_system_duration_lvl
		var cost = 15 + lvl * 15
		if Global.tech_points >= cost and lvl < 5:
			Global.tech_points -= cost
			Global.counter_system_duration_lvl += 1
			Global.save_game(1, 0, {})
			update_lab_hud()
			play_flash_effect(Color.CYAN)
			var audio_mgr = get_node_or_null("/root/AudioManager")
			if audio_mgr and audio_mgr.has_method("play_upgrade_success"):
				audio_mgr.play_upgrade_success()
	elif type == "power":
		var lvl = Global.counter_system_power_lvl
		var cost = 20 + lvl * 20
		if Global.tech_points >= cost and lvl < 5:
			Global.tech_points -= cost
			Global.counter_system_power_lvl += 1
			Global.save_game(1, 0, {})
			update_lab_hud()
			play_flash_effect(Color.GOLD)
			var audio_mgr = get_node_or_null("/root/AudioManager")
			if audio_mgr and audio_mgr.has_method("play_upgrade_success"):
				audio_mgr.play_upgrade_success()


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
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_upgrade_success"):
			audio_mgr.play_upgrade_success()
	else:
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_ui_cancel"):
			audio_mgr.play_ui_cancel()


func unlock_shield(s_id: String, cost: int) -> void:
	if Global.tech_points >= cost and not Global.unlocked_shields.has(s_id):
		Global.tech_points -= cost
		Global.unlocked_shields.append(s_id)
		Global.save_game(1, 0, {})
		update_lab_hud()
		play_flash_effect(Color.CYAN)
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_upgrade_success"):
			audio_mgr.play_upgrade_success()
	else:
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_ui_cancel"):
			audio_mgr.play_ui_cancel()


func unlock_weapon(w_id: String, cost: int) -> void:
	if Global.tech_points >= cost and not Global.unlocked_weapons.has(w_id):
		Global.tech_points -= cost
		Global.unlocked_weapons.append(w_id)
		Global.save_game(1, 0, {})
		update_lab_hud()
		play_flash_effect(Color.GOLD)
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_upgrade_success"):
			audio_mgr.play_upgrade_success()
	else:
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_ui_cancel"):
			audio_mgr.play_ui_cancel()


func play_flash_effect(color: Color) -> void:
	if is_instance_valid(tech_points_label):
		var parent_panel = tech_points_label.get_parent() as PanelContainer
		if is_instance_valid(parent_panel):
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


# ----------------- Button Style Helpers -----------------

func style_action_btn(btn: Button, accent_color: Color) -> void:
	if PIXEL_FONT:
		btn.add_theme_font_override("font", PIXEL_FONT)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.07, 0.95)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = accent_color
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	
	var sb_hover = sb.duplicate()
	sb_hover.bg_color = Color(accent_color.r * 0.25, accent_color.g * 0.25, accent_color.b * 0.25)
	
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


func style_neon_button(btn: Button, border: Color, hover_border: Color) -> void:
	style_btn(btn, border, hover_border)


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
	
	var sb_hover = sb.duplicate()
	sb_hover.border_color = hover_border
	sb_hover.bg_color = Color(0.1, 0.12, 0.22, 0.95)
	
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	
	btn.mouse_entered.connect(func():
		btn.pivot_offset = btn.size / 2
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.08)
	)
	btn.mouse_exited.connect(func():
		btn.pivot_offset = btn.size / 2
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
	)


# ----------------- Starfield & Grid Draw -----------------

func init_starfield() -> void:
	var viewport_size = get_viewport_rect().size
	for i in range(NUM_STARS):
		var star = BGStar.new()
		star.pos = Vector2(randf() * viewport_size.x, randf() * viewport_size.y)
		star.speed = randf_range(10.0, 30.0)
		star.size = randf_range(0.8, 2.2)
		star.color = Color(0.8, 0.6, 1.0, randf_range(0.15, 0.45))
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
