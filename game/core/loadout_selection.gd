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
	# 1. Primary Weapons
	var w1 = LoadoutItem.new()
	w1.id = "machine_gun"
	w1.name = "STANDARD MACHINE GUN"
	w1.description = "Rapid physical projectile deployment. Offers steady, reliable fire coverage. Starts firing after the first parry."
	w1.stats = "RATE: ★★★ | DMG: ★★☆ | VEL: ★★☆"
	w1.is_unlocked = Global.unlocked_weapons.has("machine_gun")
	primary_weapons.append(w1)
	
	var w2 = LoadoutItem.new()
	w2.id = "burst_rifle"
	w2.name = "3-ROUND BURST RIFLE"
	w2.description = "Fires high-impact 3-round burst rounds. Excellent penetrative capacity. Starts firing after the first parry."
	w2.stats = "RATE: ★★☆ | DMG: ★★★ | VEL: ★★★"
	w2.is_unlocked = Global.unlocked_weapons.has("burst_rifle")
	primary_weapons.append(w2)
	
	var w3 = LoadoutItem.new()
	w3.id = "pulse_gun"
	w3.name = "DUAL PULSE CANNON"
	w3.description = "Releases twin spreading plasma pulses. Excellent coverage for sweeping screens. Starts firing after the first parry."
	w3.stats = "RATE: ★★★ | DMG: ★★☆ | VEL: ★☆☆"
	w3.is_unlocked = Global.unlocked_weapons.has("pulse_gun")
	primary_weapons.append(w3)
	
	var w4 = LoadoutItem.new()
	w4.id = "charge_rifle"
	w4.name = "COIL CHARGE RIFLE"
	w4.description = "Charges raw energy to release a massive penetrative railgun bolt. Extreme destruction. Starts firing after the first parry."
	w4.stats = "RATE: ★☆☆ | DMG: ★★★ | VEL: ★★★"
	w4.is_unlocked = Global.unlocked_weapons.has("charge_rifle")
	primary_weapons.append(w4)
	
	var w5 = LoadoutItem.new()
	w5.id = "plasma_emitter"
	w5.name = "PLASMA EMITTER"
	w5.description = "Fires thermal plasma bolts that deal continuous damage inside field clusters. Unlockable in the Tech Lab."
	w5.stats = "RATE: ★★☆ | DMG: ★★★ | VEL: ★★☆"
	w5.is_unlocked = Global.unlocked_weapons.has("plasma_emitter")
	primary_weapons.append(w5)
	
	var w6 = LoadoutItem.new()
	w6.id = "kinetic_tackle"
	w6.name = "KINETIC TACKLE"
	w6.description = "Short-range kinetic thruster ramming. Directly crushes enemies with ship hull inertia. Unlockable in the Tech Lab."
	w6.stats = "RATE: ★☆☆ | DMG: ★★★ | VEL: ★☆☆"
	w6.is_unlocked = Global.unlocked_weapons.has("kinetic_tackle")
	primary_weapons.append(w6)

	# 2. Shields
	var s1 = LoadoutItem.new()
	s1.id = "counter"
	s1.name = "COUNTERCORE SHIELD"
	s1.description = "Default counter model. Maximizes damage output of parried enemy bullets and counter laser rebounds."
	s1.stats = "REFLECT: ★★★ | CHARGE: ★★☆ | BUFF: ★☆☆"
	shields.append(s1)
	
	var s2 = LoadoutItem.new()
	s2.id = "gauge"
	s2.name = "ABSORPTION MATRIX"
	s2.description = "Focuses on parry energy conversion. Rapidly fills the counter system gauge, allowing faster unleash rates."
	s2.stats = "REFLECT: ★☆☆ | CHARGE: ★★★ | BUFF: ★★☆"
	shields.append(s2)
	
	var s3 = LoadoutItem.new()
	s3.id = "power"
	s3.name = "AMPLITUDE BOOSTER"
	s3.description = "Bypasses complex counter algorithms to directly feed parry energy as a permanent damage boost to the primary weapon."
	s3.stats = "REFLECT: ★★☆ | CHARGE: ★☆☆ | BUFF: ★★★"
	shields.append(s3)

	# 3. Counter System Weapons (Boss weapons)
	var c0 = LoadoutItem.new()
	c0.id = "none"
	c0.name = "NO COUNTER WEAPON"
	c0.description = "Deploys standard parry rebound lasers. Equipped when no specialized boss weapons have been unlocked."
	c0.stats = "POWER: ★☆☆ | AOE: ★☆☆"
	c0.is_unlocked = true
	counter_weapons.append(c0)
	
	var c1 = LoadoutItem.new()
	c1.id = "boss_beam"
	c1.name = "ANCIENT GIGA LASER"
	c1.description = "Stage 1 Boss Weapon. Fires a colossal energy beam that pierces through all defenses. Unlocked by harvesting Boss parts."
	c1.stats = "POWER: ★★★ | AOE: ★★☆"
	c1.is_unlocked = Global.unlocked_counter_weapons.has("boss_beam")
	counter_weapons.append(c1)
	
	var c2 = LoadoutItem.new()
	c2.id = "boss_missile"
	c2.name = "SPLASH HYPER MISSILE"
	c2.description = "Stage 2 Boss Weapon. Fires tracking payload missiles that trigger huge thermal splash explosions on impact."
	c2.stats = "POWER: ★★☆ | AOE: ★★★"
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
	title.text = "LOADOUT CONFIGURATION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.04
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var title_set = LabelSettings.new()
	title_set.font_size = 28
	title_set.font_color = Color.CYAN
	title_set.outline_size = 6
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
	var p_sec = create_section_vbox("PRIMARY WEAPON FRAME (メイン武器の枠)", main_vbox)
	var p_grid = GridContainer.new()
	p_grid.columns = 3
	p_grid.add_theme_constant_override("h_separation", 15)
	p_grid.add_theme_constant_override("v_separation", 10)
	p_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_sec.add_child(p_grid)
	
	for w in primary_weapons:
		var btn = Button.new()
		btn.text = w.name.split(" ")[-1] if w.name.split(" ").size() > 1 else w.name
		btn.custom_minimum_size = Vector2(80, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_grid.add_child(btn)
		primary_buttons[w.id] = btn
		
		if not w.is_unlocked:
			btn.disabled = true
			btn.text = "🔒 LOCKED"
		else:
			btn.pressed.connect(func(): select_item("primary", w.id))
			btn.mouse_entered.connect(func(): show_details("primary", w.id))
			style_config_button(btn, Color.CYAN)
			
	# --- SECTION 2: SHIELD TYPE ---
	var s_sec = create_section_vbox("DEFENSIVE SHIELD SYSTEM (シールド選択)", main_vbox)
	var s_grid = HBoxContainer.new()
	s_grid.add_theme_constant_override("separation", 18)
	s_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s_sec.add_child(s_grid)
	
	for s in shields:
		var btn = Button.new()
		btn.text = s.name.split(" ")[0]
		btn.custom_minimum_size = Vector2(80, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_grid.add_child(btn)
		shield_buttons[s.id] = btn
		btn.pressed.connect(func(): select_item("shield", s.id))
		btn.mouse_entered.connect(func(): show_details("shield", s.id))
		style_config_button(btn, Color.GREEN)
		
	# --- SECTION 3: COUNTER SYSTEM ---
	var c_sec = create_section_vbox("COUNTER SYSTEM UPGRADE (反撃兵装)", main_vbox)
	var c_grid = HBoxContainer.new()
	c_grid.add_theme_constant_override("separation", 18)
	c_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_sec.add_child(c_grid)
	
	for c in counter_weapons:
		var btn = Button.new()
		btn.text = c.name.split(" ")[-1] if c.id != "none" else "STANDARD"
		btn.custom_minimum_size = Vector2(80, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c_grid.add_child(btn)
		counter_buttons[c.id] = btn
		
		if not c.is_unlocked:
			btn.disabled = true
			btn.text = "🔒 " + (c.name.split(" ")[-1] if c.name.split(" ").size() > 1 else c.name)
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
	d_title_set.font_size = 18
	d_title_set.font_color = Color.WHITE
	desc_title.label_settings = d_title_set
	desc_hdr.add_child(desc_title)
	
	desc_type = Label.new()
	var d_type_set = LabelSettings.new()
	d_type_set.font_size = 11
	d_type_set.font_color = Color.GOLD
	desc_type.label_settings = d_type_set
	desc_type.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	desc_hdr.add_child(desc_type)
	
	desc_stats = Label.new()
	var d_stats_set = LabelSettings.new()
	d_stats_set.font_size = 12
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
	d_body_set.font_size = 13
	d_body_set.font_color = Color(0.8, 0.85, 0.9, 0.9)
	desc_body.label_settings = d_body_set
	desc_vbox.add_child(desc_body)

	# --- FOOTER BUTTONS ---
	var footer_hbox = HBoxContainer.new()
	footer_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_hbox.add_theme_constant_override("separation", 40)
	footer_hbox.anchor_left = 0.0
	footer_hbox.anchor_right = 1.0
	footer_hbox.anchor_top = 0.93
	footer_hbox.anchor_bottom = 0.93
	footer_hbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	footer_hbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(footer_hbox)
	
	back_btn = Button.new()
	back_btn.text = "戻る / BACK"
	back_btn.custom_minimum_size = Vector2(200, 48)
	footer_hbox.add_child(back_btn)
	style_action_btn(back_btn, Color(0.6, 0.6, 0.6), Color(0.8, 0.8, 0.8))
	back_btn.pressed.connect(_on_back_pressed)
	
	deploy_btn = Button.new()
	deploy_btn.text = "戦区へ出撃 / DEPLOY TO SECTOR"
	deploy_btn.custom_minimum_size = Vector2(260, 48)
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
	l_set.font_size = 13
	l_set.font_color = Color.LIGHT_GRAY
	lbl.label_settings = l_set
	vbox.add_child(lbl)
	
	return vbox

func style_config_button(btn: Button, accent_color: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.9)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.2, 0.2, 0.25)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	
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
			type_label = "PRIMARY WEAPON FRAME"
			accent = Color.CYAN
		"shield":
			for s in shields:
				if s.id == id:
					item = s
			type_label = "DEFENSIVE SHIELD UNIT"
			accent = Color.GREEN
		"counter":
			for c in counter_weapons:
				if c.id == id:
					item = c
			type_label = "COUNTER SYSTEM ARMAMENT"
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
	Global.save_game(save_data.get("stage_num", 1), save_data.get("score", 0), save_data.get("weapons", {}))
	
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
