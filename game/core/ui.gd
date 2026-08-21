extends CanvasLayer
## UI 表示スクリプト（CanvasLayerを継承し、シーン ui.tscn のノードとバインド）
## - HP バー（Player・Boss）
## - ガード・パリィ・武器解析率表示
## - ボスエネルギー再配分表示
## - 警告演出・フラッシュ演出・ゲームオーバー表示

# カラー定数
const COLOR_PLAYER_HP = Color(0.2, 0.9, 0.4)
const COLOR_BOSS_HP = Color(1.0, 0.2, 0.2)
const COLOR_SHIELD_HEAT_DEFAULT = Color(0.2, 0.8, 1.0)

# フォントサイズ定数
const FONT_SIZE_HP: int = 18
const FONT_SIZE_PARRY: int = 22
const FONT_SIZE_GUARD: int = 20
const FONT_SIZE_WARNING_TITLE: int = 48
const FONT_SIZE_WARNING_SUBTITLE: int = 24

@onready var player_hp_bar: ProgressBar = $PlayerHPBar
@onready var player_hp_label: Label = $PlayerHPLabel

@onready var boss_hp_bar: ProgressBar = $BossHPBar
@onready var boss_hp_label: Label = $BossHPLabel

@onready var parry_count_label: Label = $ParryCountLabel
@onready var guard_status_label: Label = $GuardStatusLabel

# 警告・フラッシュ演出UI
@onready var warning_title: Label = $WarningTitle
@onready var warning_subtitle: Label = $WarningSubtitle
@onready var flash_overlay: ColorRect = $FlashOverlay

var shield_heat_bar: ProgressBar


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
	style_hp_bar(player_hp_bar, COLOR_PLAYER_HP)
	style_hp_bar(boss_hp_bar, COLOR_BOSS_HP)
	
	# 左上プレイヤー情報配置 (大きめのフォント・バーで視認性向上)
	player_hp_label.position = Vector2(20, 10)
	player_hp_bar.position = Vector2(20, 32)
	player_hp_bar.custom_minimum_size = Vector2(240, 16)
	player_hp_bar.size = Vector2(240, 16)
	
	setup_label_style(player_hp_label, 18, Color.WHITE, 4)
	setup_label_style(boss_hp_label, 18, Color.GOLD, 4)
	setup_label_style(parry_count_label, 16, Color.CYAN, 4)
	setup_label_style(guard_status_label, 16, Color.GREEN, 4)
	setup_label_style(warning_title, FONT_SIZE_WARNING_TITLE, Color.RED, 10)
	setup_label_style(warning_subtitle, FONT_SIZE_WARNING_SUBTITLE, Color.GOLD, 6)
	
	parry_count_label.position = Vector2(20, 68)
	guard_status_label.position = Vector2(20, 88)
	
	# 主兵装HUD表示
	create_equipped_weapon_hud()
	
	# 中央ボス情報配置
	boss_hp_label.position = Vector2(250, 10)
	boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_hp_bar.position = Vector2(250, 32)
	boss_hp_bar.custom_minimum_size = Vector2(240, 16)
	boss_hp_bar.size = Vector2(240, 16)
	
	create_shield_heat_bar()
	create_analysis_matrix_ui()
	create_wave_phase_ui()
	create_top_warning_ui()


var equipped_weapon_label: Label

func create_equipped_weapon_hud() -> void:
	equipped_weapon_label = Label.new()
	equipped_weapon_label.name = "EquippedWeaponLabel"
	equipped_weapon_label.position = Vector2(20, 108)
	setup_label_style(equipped_weapon_label, 16, Color(1.0, 0.85, 0.3), 4)
	add_child(equipped_weapon_label)
	update_equipped_weapon_hud(Global.equipped_weapon)


func update_equipped_weapon_hud(weapon_id: String) -> void:
	if is_instance_valid(equipped_weapon_label):
		var w_name = weapon_id
		if Global.available_weapons.has(weapon_id):
			w_name = Global.available_weapons[weapon_id].get("name", weapon_id)
		equipped_weapon_label.text = "主兵装: %s [Q/E切替]" % w_name


var top_warning_overlay: ColorRect
var top_warning_label: Label
var top_warning_tween: Tween

func create_top_warning_ui() -> void:
	top_warning_overlay = ColorRect.new()
	top_warning_overlay.name = "TopWarningOverlay"
	top_warning_overlay.anchor_left = 0.0
	top_warning_overlay.anchor_right = 1.0
	top_warning_overlay.offset_top = 0.0
	top_warning_overlay.offset_bottom = 260.0
	top_warning_overlay.color = Color(1.0, 0.0, 0.08, 0.0)
	top_warning_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_warning_overlay)
	
	top_warning_label = Label.new()
	top_warning_label.name = "TopWarningLabel"
	top_warning_label.anchor_left = 0.0
	top_warning_label.anchor_right = 1.0
	top_warning_label.offset_top = 110.0
	top_warning_label.offset_bottom = 160.0
	top_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_warning_label.text = "⚠️ DANGER: パリィ不可攻撃警告 ⚠️\n【PARRY IMPOSSIBLE - EVADE!】"
	var l_set = LabelSettings.new()
	if PIXEL_FONT:
		l_set.font = PIXEL_FONT
	l_set.font_size = 20
	l_set.font_color = Color(1.0, 0.25, 0.25)
	l_set.outline_size = 6
	l_set.outline_color = Color(0.15, 0.0, 0.0)
	top_warning_label.label_settings = l_set
	top_warning_label.modulate.a = 0.0
	top_warning_overlay.add_child(top_warning_label)


func show_top_unparryable_warning(duration: float = 2.0, message: String = "") -> void:
	if not is_instance_valid(top_warning_overlay):
		return
	if message != "":
		top_warning_label.text = message
	else:
		top_warning_label.text = "⚠️ DANGER: パリィ不可攻撃警告 ⚠️\n【PARRY IMPOSSIBLE - EVADE!】"
		
	if is_instance_valid(top_warning_tween):
		top_warning_tween.kill()
		
	top_warning_tween = create_tween().set_parallel(true)
	# やんわり赤く点灯（alpha 0.35）
	top_warning_tween.tween_property(top_warning_overlay, "color:a", 0.36, 0.3).set_trans(Tween.TRANS_SINE)
	top_warning_tween.tween_property(top_warning_label, "modulate:a", 1.0, 0.3)
	
	# やんわりパルス
	var pulse_loops = max(1, int(duration / 0.4))
	var pulse_tween = create_tween().set_loops(pulse_loops)
	pulse_tween.tween_property(top_warning_overlay, "color:a", 0.20, 0.2).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(top_warning_overlay, "color:a", 0.40, 0.2).set_trans(Tween.TRANS_SINE)
	
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(top_warning_overlay):
			var fade_tween = create_tween().set_parallel(true)
			fade_tween.tween_property(top_warning_overlay, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
			fade_tween.tween_property(top_warning_label, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	)


var wave_timer_panel: PanelContainer
var wave_level_label: Label
var wave_countdown_label: Label
var wave_kills_label: Label

func create_wave_phase_ui() -> void:
	wave_timer_panel = PanelContainer.new()
	wave_timer_panel.name = "WaveTimerPanel"
	wave_timer_panel.position = Vector2(250, 10)
	wave_timer_panel.custom_minimum_size = Vector2(250, 88)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.08, 0.70)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.2, 0.5, 0.8, 0.8)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	wave_timer_panel.add_theme_stylebox_override("panel", sb)
	add_child(wave_timer_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	wave_timer_panel.add_child(vbox)
	
	var hdr = HBoxContainer.new()
	hdr.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hdr)
	
	wave_level_label = Label.new()
	wave_level_label.text = "⚡ WAVE 1"
	var w_set = LabelSettings.new()
	if PIXEL_FONT:
		w_set.font = PIXEL_FONT
	w_set.font_size = 14
	w_set.font_color = Color.GOLD
	w_set.outline_size = 4
	w_set.outline_color = Color.BLACK
	wave_level_label.label_settings = w_set
	hdr.add_child(wave_level_label)
	
	wave_countdown_label = Label.new()
	wave_countdown_label.text = "⏱️ 01:30"
	wave_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var c_set = LabelSettings.new()
	if PIXEL_FONT:
		c_set.font = PIXEL_FONT
	c_set.font_size = 20
	c_set.font_color = Color.CYAN
	c_set.outline_size = 6
	c_set.outline_color = Color.BLACK
	wave_countdown_label.label_settings = c_set
	vbox.add_child(wave_countdown_label)
	
	wave_kills_label = Label.new()
	wave_kills_label.text = "💀 撃破数: 0 体"
	wave_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var k_set = LabelSettings.new()
	if PIXEL_FONT:
		k_set.font = PIXEL_FONT
	k_set.font_size = 13
	k_set.font_color = Color(0.9, 0.9, 0.9)
	k_set.outline_size = 4
	k_set.outline_color = Color.BLACK
	wave_kills_label.label_settings = k_set
	vbox.add_child(wave_kills_label)


func update_wave_phase_hud(wave_num: int, remaining_time: float, kills: int) -> void:
	if is_instance_valid(wave_timer_panel):
		wave_timer_panel.visible = true
		wave_level_label.text = "⚡ WAVE %d" % wave_num
		
		var total_sec = max(0, int(ceil(remaining_time)))
		var mins = total_sec / 60
		var secs = total_sec % 60
		wave_countdown_label.text = "⏱️ %02d:%02d" % [mins, secs]
		
		if remaining_time <= 10.0:
			var flash = int(remaining_time * 6.0) % 2 == 0
			wave_countdown_label.label_settings.font_color = Color.RED if flash else Color.YELLOW
		else:
			wave_countdown_label.label_settings.font_color = Color.CYAN
			
		wave_kills_label.text = "💀 撃破数: %d 体" % kills


func hide_wave_phase_hud() -> void:
	if is_instance_valid(wave_timer_panel):
		wave_timer_panel.visible = false


func create_shield_heat_bar() -> void:
	shield_heat_bar = ProgressBar.new()
	shield_heat_bar.name = "ShieldHeatBar"
	shield_heat_bar.show_percentage = false
	shield_heat_bar.custom_minimum_size = Vector2(220, 10)
	shield_heat_bar.size = Vector2(220, 10)
	shield_heat_bar.position = Vector2(20, 48)
	add_child(shield_heat_bar)
	style_hp_bar(shield_heat_bar, COLOR_SHIELD_HEAT_DEFAULT)


var slot_cards: Array = []
var active_analysis_label: Label
var active_analysis_bar: ProgressBar

func create_analysis_matrix_ui() -> void:
	var trait_panel = PanelContainer.new()
	trait_panel.name = "TraitSlotsPanel"
	trait_panel.position = Vector2(490, 10)
	trait_panel.custom_minimum_size = Vector2(290, 105)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.08, 0.70)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.25, 0.4, 0.65, 0.8)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	trait_panel.add_theme_stylebox_override("panel", sb)
	add_child(trait_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	trait_panel.add_child(vbox)
	
	# タイトル
	var title = Label.new()
	title.text = "【変異スロット (MAX 3)】"
	var t_set = LabelSettings.new()
	if PIXEL_FONT:
		t_set.font = PIXEL_FONT
	t_set.font_size = 15
	t_set.font_color = Color.CYAN
	title.label_settings = t_set
	vbox.add_child(title)
	
	# 3つのスロットボックス（横並び）
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(hbox)
	
	slot_cards.clear()
	for i in range(3):
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(88, 42)
		var c_sb = StyleBoxFlat.new()
		c_sb.bg_color = Color(0.08, 0.1, 0.14, 0.9)
		c_sb.border_width_left = 1
		c_sb.border_width_top = 1
		c_sb.border_width_right = 1
		c_sb.border_width_bottom = 1
		c_sb.border_color = Color(0.2, 0.25, 0.35, 0.8)
		card.add_theme_stylebox_override("panel", c_sb)
		
		var lbl = Label.new()
		lbl.text = "SLOT %d\n[空き]" % (i + 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var l_set = LabelSettings.new()
		if PIXEL_FONT:
			l_set.font = PIXEL_FONT
		l_set.font_size = 14
		l_set.font_color = Color(0.4, 0.45, 0.55)
		lbl.label_settings = l_set
		card.add_child(lbl)
		
		hbox.add_child(card)
		slot_cards.append({ "panel": card, "style": c_sb, "label": lbl })
		
	# 直近の解析進行バー (1行)
	var prog_row = HBoxContainer.new()
	prog_row.add_theme_constant_override("separation", 6)
	vbox.add_child(prog_row)
	
	active_analysis_label = Label.new()
	active_analysis_label.text = "解析待機中"
	active_analysis_label.custom_minimum_size = Vector2(110, 18)
	var a_set = LabelSettings.new()
	if PIXEL_FONT:
		a_set.font = PIXEL_FONT
	a_set.font_size = 13
	a_set.font_color = Color.LIGHT_GRAY
	active_analysis_label.label_settings = a_set
	prog_row.add_child(active_analysis_label)
	
	active_analysis_bar = ProgressBar.new()
	active_analysis_bar.show_percentage = false
	active_analysis_bar.custom_minimum_size = Vector2(160, 10)
	active_analysis_bar.max_value = 100
	active_analysis_bar.value = 0
	style_analysis_bar(active_analysis_bar, Color.CYAN)
	prog_row.add_child(active_analysis_bar)


func update_pattern_analysis(patterns: Dictionary, active_traits: Array = []) -> void:
	# 1. 3つのスロット表示の更新
	for i in range(3):
		var card = slot_cards[i]
		if i < active_traits.size():
			var t_key = active_traits[i]
			if patterns.has(t_key):
				var data = patterns[t_key]
				var lvl = data.get("level", 1)
				card["label"].text = "%s %s\nLv.%d" % [data.get("icon", "⚡"), data.get("name", "属性"), lvl]
				card["label"].label_settings.font_color = Color.WHITE if lvl == 1 else Color.GOLD
				card["style"].border_color = data.get("color", Color.CYAN)
				card["style"].bg_color = Color(0.1, 0.15, 0.22, 0.95)
		else:
			card["label"].text = "SLOT %d\n[空き]" % (i + 1)
			card["label"].label_settings.font_color = Color(0.4, 0.45, 0.55)
			card["style"].border_color = Color(0.2, 0.25, 0.35, 0.8)
			card["style"].bg_color = Color(0.06, 0.08, 0.1, 0.85)
			
	# 2. 現在進行中の解析（直近で最も進捗の高い、未MAXパターン）の表示
	var latest_pattern = null
	var highest_progress = 0.0
	for key in patterns.keys():
		var data = patterns[key]
		var prog = data.get("progress", 0.0)
		var lvl = data.get("level", 0)
		var max_lvl = data.get("max_level", 2)
		if lvl < max_lvl and prog > highest_progress:
			highest_progress = prog
			latest_pattern = data
			
	if latest_pattern and highest_progress > 0:
		var name_str = latest_pattern.get("name", "未知")
		active_analysis_label.text = "解析中: %s" % name_str
		active_analysis_label.label_settings.font_color = latest_pattern.get("color", Color.CYAN)
		active_analysis_bar.value = highest_progress
		style_analysis_bar(active_analysis_bar, latest_pattern.get("color", Color.CYAN))
	else:
		active_analysis_label.text = "解析: パリィで吸収"
		active_analysis_label.label_settings.font_color = Color.GRAY
		active_analysis_bar.value = 0


const PIXEL_FONT: Font = preload("res://game/assets/fonts/DotGothic16-Regular.ttf")

func style_hp_bar(bar: ProgressBar, color: Color) -> void:
	# ドット絵風の角張ったピクセルフレーム (角丸ゼロ・2px枠線)
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.04, 0.05, 0.08, 0.95)
	sb_bg.border_width_left = 2
	sb_bg.border_width_top = 2
	sb_bg.border_width_right = 2
	sb_bg.border_width_bottom = 2
	sb_bg.border_color = Color(0.25, 0.35, 0.5, 1.0)
	sb_bg.corner_radius_top_left = 0
	sb_bg.corner_radius_top_right = 0
	sb_bg.corner_radius_bottom_left = 0
	sb_bg.corner_radius_bottom_right = 0
	
	var sb_fg = StyleBoxFlat.new()
	sb_fg.bg_color = color
	sb_fg.corner_radius_top_left = 0
	sb_fg.corner_radius_top_right = 0
	sb_fg.corner_radius_bottom_left = 0
	sb_fg.corner_radius_bottom_right = 0
	
	bar.add_theme_stylebox_override("background", sb_bg)
	bar.add_theme_stylebox_override("fill", sb_fg)


func style_analysis_bar(bar: ProgressBar, color: Color) -> void:
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.03, 0.04, 0.06, 0.95)
	sb_bg.border_width_left = 2
	sb_bg.border_width_top = 2
	sb_bg.border_width_right = 2
	sb_bg.border_width_bottom = 2
	sb_bg.border_color = Color(0.2, 0.25, 0.35, 0.9)
	sb_bg.corner_radius_top_left = 0
	sb_bg.corner_radius_top_right = 0
	sb_bg.corner_radius_bottom_left = 0
	sb_bg.corner_radius_bottom_right = 0
	
	var sb_fg = StyleBoxFlat.new()
	sb_fg.bg_color = color
	sb_fg.corner_radius_top_left = 0
	sb_fg.corner_radius_top_right = 0
	sb_fg.corner_radius_bottom_left = 0
	sb_fg.corner_radius_bottom_right = 0
	
	bar.add_theme_stylebox_override("background", sb_bg)
	bar.add_theme_stylebox_override("fill", sb_fg)


var stage_intro_banner: Control
var stage_intro_tween: Tween

func show_stage_intro_banner(stage_num: int, stage_title: String, subtitle: String = "", mission_goal: String = "") -> void:
	if is_instance_valid(stage_intro_banner):
		stage_intro_banner.queue_free()
		
	if is_instance_valid(stage_intro_tween):
		stage_intro_tween.kill()
		
	stage_intro_banner = Control.new()
	stage_intro_banner.name = "StageIntroBanner"
	stage_intro_banner.anchor_left = 0.05
	stage_intro_banner.anchor_right = 0.95
	stage_intro_banner.offset_top = 240.0
	stage_intro_banner.offset_bottom = 420.0
	stage_intro_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage_intro_banner)
	
	# Background strip (半透明にして背後の敵や背景が見えるように)
	var bg_rect = ColorRect.new()
	bg_rect.color = Color(0.02, 0.04, 0.08, 0.50)
	bg_rect.anchor_right = 1.0
	bg_rect.anchor_bottom = 1.0
	stage_intro_banner.add_child(bg_rect)
	
	# Top & Bottom accent lines
	var line_top = ColorRect.new()
	line_top.color = Color(0.3, 0.9, 1.0, 0.8)
	line_top.anchor_right = 1.0
	line_top.offset_bottom = 2.0
	stage_intro_banner.add_child(line_top)
	
	var line_bottom = ColorRect.new()
	line_bottom.color = Color(0.3, 0.9, 1.0, 0.8)
	line_bottom.anchor_top = 1.0
	line_bottom.anchor_right = 1.0
	line_bottom.anchor_bottom = 1.0
	line_bottom.offset_top = -2.0
	stage_intro_banner.add_child(line_bottom)
	
	var margin = MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 12)
	stage_intro_banner.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	var num_lbl = Label.new()
	num_lbl.text = "── OPERATION STAGE %d ──" % stage_num
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_label_style(num_lbl, 16, Color(0.3, 0.9, 1.0), 4)
	vbox.add_child(num_lbl)
	
	var title_lbl = Label.new()
	title_lbl.text = stage_title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_label_style(title_lbl, 28, Color.WHITE, 6)
	vbox.add_child(title_lbl)
	
	if subtitle != "":
		var sub_lbl = Label.new()
		sub_lbl.text = subtitle
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		setup_label_style(sub_lbl, 16, Color.GOLD, 4)
		vbox.add_child(sub_lbl)
		
	if mission_goal != "":
		var goal_lbl = Label.new()
		goal_lbl.text = "【作戦目標】%s" % mission_goal
		goal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		setup_label_style(goal_lbl, 14, Color(0.9, 0.95, 1.0), 3)
		vbox.add_child(goal_lbl)
		
	stage_intro_banner.modulate.a = 0.0
	stage_intro_banner.scale = Vector2(0.96, 0.96)
	stage_intro_banner.pivot_offset = Vector2(360.0, 90.0)
	
	stage_intro_tween = create_tween().set_parallel(true)
	stage_intro_tween.tween_property(stage_intro_banner, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD)
	stage_intro_tween.tween_property(stage_intro_banner, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_QUAD)
	
	# 3.2秒表示してスムーズにフェードアウト
	get_tree().create_timer(3.2).timeout.connect(func():
		if is_instance_valid(stage_intro_banner):
			var fade_t = create_tween().set_parallel(true)
			fade_t.tween_property(stage_intro_banner, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_QUAD)
			fade_t.chain().tween_callback(func():
				if is_instance_valid(stage_intro_banner):
					stage_intro_banner.queue_free()
			)
	)


var wave_telop_banner: Control
var wave_telop_tween: Tween

func show_wave_announcement(title: String, message: String = "", duration: float = 2.2) -> void:
	if is_instance_valid(wave_telop_banner):
		wave_telop_banner.queue_free()
		
	if is_instance_valid(wave_telop_tween):
		wave_telop_tween.kill()
		
	var display_time = min(duration, 2.4) if duration > 0 else 2.2
		
	wave_telop_banner = Control.new()
	wave_telop_banner.name = "WaveTelopBanner"
	# HUD直下（Y: 120〜175）に配置。主戦場（Y: 200〜）を一切遮らないコンパクトサイズ
	wave_telop_banner.anchor_left = 0.12
	wave_telop_banner.anchor_right = 0.88
	wave_telop_banner.offset_top = 120.0
	wave_telop_banner.offset_bottom = 175.0 if message != "" else 152.0
	wave_telop_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wave_telop_banner)
	
	var panel = PanelContainer.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	
	var sb = StyleBoxFlat.new()
	# 半透明のサイバーフロスト背景（alpha 0.38）で背後の敵弾がはっきり透けて見える
	sb.bg_color = Color(0.02, 0.05, 0.10, 0.38)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.3, 0.75, 1.0, 0.65)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.shadow_color = Color(0.1, 0.5, 0.9, 0.15)
	sb.shadow_size = 6
	panel.add_theme_stylebox_override("panel", sb)
	wave_telop_banner.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)
	
	var t_lbl = Label.new()
	t_lbl.text = title
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_label_style(t_lbl, 16, Color.GOLD, 4)
	vbox.add_child(t_lbl)
	
	if message != "":
		var m_lbl = Label.new()
		m_lbl.text = message
		m_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		setup_label_style(m_lbl, 13, Color(0.9, 0.95, 1.0), 3)
		vbox.add_child(m_lbl)
		
	wave_telop_banner.modulate.a = 0.0
	wave_telop_banner.position.y = 110.0
	
	wave_telop_tween = create_tween().set_parallel(true)
	wave_telop_tween.tween_property(wave_telop_banner, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD)
	wave_telop_tween.tween_property(wave_telop_banner, "position:y", 120.0, 0.2).set_trans(Tween.TRANS_QUAD)
	
	get_tree().create_timer(display_time).timeout.connect(func():
		if is_instance_valid(wave_telop_banner):
			var fade_t = create_tween().set_parallel(true)
			fade_t.tween_property(wave_telop_banner, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD)
			fade_t.tween_property(wave_telop_banner, "position:y", 112.0, 0.3).set_trans(Tween.TRANS_QUAD)
			fade_t.chain().tween_callback(func():
				if is_instance_valid(wave_telop_banner):
					wave_telop_banner.queue_free()
			)
	)


func _unhandled_input(event: InputEvent) -> void:
	if has_node("TutorialGuideModal"):
		if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_Z)):
			get_node("TutorialGuideModal").queue_free()
			get_tree().paused = false
			get_viewport().set_input_as_handled()
			return

	if has_node("AnalysisUnlockModal"):
		if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_Z)):
			get_node("AnalysisUnlockModal").queue_free()
			get_tree().paused = false
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_P)):
		if not has_node("GameOverPanel") and not has_node("AnalysisUnlockModal") and not has_node("TutorialGuideModal"):
			toggle_pause_menu()


func show_analysis_unlock_modal(pattern_key: String, data: Dictionary) -> void:
	if has_node("AnalysisUnlockModal"):
		get_node("AnalysisUnlockModal").queue_free()
		
	get_tree().paused = true
	
	var overlay = ColorRect.new()
	overlay.name = "AnalysisUnlockModal"
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0.02, 0.03, 0.06, 0.90)
	overlay.process_mode = PROCESS_MODE_ALWAYS
	add_child(overlay)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 480)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -250
	panel.offset_top = -240
	panel.offset_right = 250
	panel.offset_bottom = 240
	overlay.add_child(panel)
	
	var cat_info = Global.analysis_catalog.get(pattern_key, {})
	var col = cat_info.get("color", data.get("color", Color.CYAN))
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.12, 0.98)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = col
	sb.shadow_color = Color(col.r, col.g, col.b, 0.35)
	sb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", sb)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)
	
	var h_lbl = Label.new()
	h_lbl.text = "⚡ 新変異兵装・解析完了！"
	h_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_label_style(h_lbl, 24, Color.GOLD, 6)
	vbox.add_child(h_lbl)
	
	var name_lbl = Label.new()
	name_lbl.text = "%s 【%s】" % [cat_info.get("icon", data.get("icon", "◈")), cat_info.get("name", data.get("name", "新変異"))]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_label_style(name_lbl, 32, col, 8)
	vbox.add_child(name_lbl)
	
	var src_lbl = Label.new()
	src_lbl.text = "【解析元】%s（%s）" % [cat_info.get("enemy_color", "敵弾"), cat_info.get("enemy_type", "通常敵")]
	src_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_label_style(src_lbl, 16, Color(0.8, 0.9, 1.0), 4)
	vbox.add_child(src_lbl)
	
	var desc_box = PanelContainer.new()
	var desc_sb = StyleBoxFlat.new()
	desc_sb.bg_color = Color(0.03, 0.04, 0.07, 0.9)
	desc_sb.border_width_left = 1
	desc_sb.border_width_top = 1
	desc_sb.border_width_right = 1
	desc_sb.border_width_bottom = 1
	desc_sb.border_color = Color(0.2, 0.3, 0.45)
	desc_box.add_theme_stylebox_override("panel", desc_sb)
	vbox.add_child(desc_box)
	
	var desc_margin = MarginContainer.new()
	desc_margin.add_theme_constant_override("margin_left", 14)
	desc_margin.add_theme_constant_override("margin_top", 12)
	desc_margin.add_theme_constant_override("margin_right", 14)
	desc_margin.add_theme_constant_override("margin_bottom", 12)
	desc_box.add_child(desc_margin)
	
	var desc_vbox = VBoxContainer.new()
	desc_vbox.add_theme_constant_override("separation", 8)
	desc_margin.add_child(desc_vbox)
	
	var stat_lbl = Label.new()
	stat_lbl.text = cat_info.get("stats", "")
	setup_label_style(stat_lbl, 16, Color.CYAN, 4)
	desc_vbox.add_child(stat_lbl)
	
	var body_lbl = Label.new()
	body_lbl.text = cat_info.get("description", "") + "\n\n※変異スロットに自動装備されました（最大3枠）。"
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup_label_style(body_lbl, 15, Color.WHITE, 4)
	desc_vbox.add_child(body_lbl)
	
	var resume_btn = Button.new()
	resume_btn.text = "同期完了・戦闘再開 (SPACE / クリック)"
	resume_btn.custom_minimum_size = Vector2(0, 52)
	if PIXEL_FONT:
		resume_btn.add_theme_font_override("font", PIXEL_FONT)
	resume_btn.add_theme_font_size_override("font_size", 20)
	style_game_over_button(resume_btn, col)
	vbox.add_child(resume_btn)
	
	var close_fn = func():
		get_tree().paused = false
		overlay.queue_free()
		
	resume_btn.pressed.connect(close_fn)


func show_tutorial_guide_modal(topic: String) -> void:
	if has_node("TutorialGuideModal"):
		get_node("TutorialGuideModal").queue_free()
		
	get_tree().paused = true
	Global.tutorial_flags[topic] = true
	Global.save_game()
	
	var overlay = ColorRect.new()
	overlay.name = "TutorialGuideModal"
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0.02, 0.03, 0.06, 0.92)
	overlay.process_mode = PROCESS_MODE_ALWAYS
	add_child(overlay)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 560)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -290
	panel.offset_top = -280
	panel.offset_right = 290
	panel.offset_bottom = 280
	overlay.add_child(panel)
	
	# トピックごとの設定データ
	var title_text = "🔰 チュートリアル"
	var sub_text = ""
	var border_col = Color.CYAN
	var items = []
	
	match topic:
		"controls":
			title_text = "🔰 【機体操作 ＆ パリィ指南】"
			sub_text = "基本システムを把握し、激戦を生き残れ！"
			border_col = Color(0.2, 0.8, 1.0)
			items = [
				{
					"title": "🎮 機体移動",
					"color": Color.CYAN,
					"desc": "[W][A][S][D] / [方向キー] / [マウス移動]\n自機を360度自在に操り、敵の弾幕をすり抜けろ。"
				},
				{
					"title": "⚔️ 主兵装射撃",
					"color": Color(0.4, 1.0, 0.5),
					"desc": "[Zキー] / [左クリック]（押しっぱなしで自動連射）\n通常物理弾で雑魚ドローンを撃破し、侵攻を食い止めろ。"
				},
				{
					"title": "🛡️ シールド ＆ パリィ",
					"color": Color.GOLD,
					"desc": "[スペースキー] / [右クリック]\nシールドを展開。敵弾着弾の直前に展開すると【パリィ】発動！敵弾を赤色反射弾に変換して大ダメージ＆機体修復！"
				}
			]
		"weapon_analysis":
			title_text = "⚡ 【敵弾解析 ＆ 変異兵装】"
			sub_text = "敵の攻撃を解析し、自機の武装へと変換せよ！"
			border_col = Color(1.0, 0.85, 0.2)
			items = [
				{
					"title": "🔬 敵弾の解析",
					"color": Color.CYAN,
					"desc": "敵弾をガードまたはパリィすると、画面左下の解析マトリクスに敵の兵装データがスキャン・蓄積されます。"
				},
				{
					"title": "🧬 変異兵装の解放",
					"color": Color.GOLD,
					"desc": "解析度100%で【変異兵装】が解放！全属性に共鳴EXPが波及し、機体の全攻撃力・機動性も底上げされます。"
				},
				{
					"title": "💠 変異スロット装備",
					"color": Color(0.9, 0.45, 1.0),
					"desc": "解放された変異（拡散射撃・貫通重弾・誘導ミサイル等）は最大3スロットに自動装備され、主兵装が強力に進化！"
				}
			]
		"time_limit":
			title_text = "⏱️ 【防衛フェーズ残り30秒 ＆ ボス接近】"
			sub_text = "迫る超巨大要塞ボスとの決戦に備えよ！"
			border_col = Color(1.0, 0.55, 0.2)
			items = [
				{
					"title": "⏳ 制限時間（90秒）",
					"color": Color(1.0, 0.6, 0.2),
					"desc": "各ステージの通常防衛時間は【90秒間】です（現在1分経過、残り30秒！）。"
				},
				{
					"title": "💥 最終防衛態勢",
					"color": Color(0.3, 0.9, 1.0),
					"desc": "敵の増援が激化します。敵を撃破してテックポイント（TP）を獲得し、変異兵装を解析強化しましょう！"
				},
				{
					"title": "⚠️ ボス戦移行",
					"color": Color(1.0, 0.3, 0.3),
					"desc": "90秒が経過すると画面が暗転し、巨大な「要塞ボス」が出現・戦闘フェーズに移行します！"
				}
			]
		"boss_info":
			title_text = "⚠️ 【要塞ボス戦 ＆ サブ砲台の防壁】"
			sub_text = "サブ砲台を破壊し、要塞の装甲を突破せよ！"
			border_col = Color(1.0, 0.2, 0.2)
			items = [
				{
					"title": "🛡️ サブ砲台の防壁",
					"color": Color(1.0, 0.35, 0.35),
					"desc": "左右のサブ砲台が生存中は、ボスの強固な防壁により【ボス本体への被ダメージが80%カット】されます！"
				},
				{
					"title": "🎯 攻略手順",
					"color": Color(0.3, 0.9, 1.0),
					"desc": "まずは左右のサブ砲台を集中攻撃して破壊するか、砲台の弾幕をパリィしてボスに反射ダメージを与えましょう！"
				},
				{
					"title": "⚠️ 【パリィ不可】真紅の警告",
					"color": Color(1.0, 0.1, 0.15),
					"desc": "画面上部が赤く点灯した際はパリィ不可・断絶レーザーの合図！ガードを貫通するため緊急回避してください！"
				}
			]
			
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.11, 0.98)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = border_col
	sb.shadow_color = Color(border_col.r, border_col.g, border_col.b, 0.35)
	sb.shadow_size = 20
	panel.add_theme_stylebox_override("panel", sb)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)
	
	var h_lbl = Label.new()
	h_lbl.text = title_text
	h_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_label_style(h_lbl, 26, border_col, 6)
	vbox.add_child(h_lbl)
	
	if sub_text != "":
		var sub_lbl = Label.new()
		sub_lbl.text = sub_text
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		setup_label_style(sub_lbl, 18, Color(0.85, 0.9, 1.0), 4)
		vbox.add_child(sub_lbl)
		
	# Cards
	for it in items:
		var c_panel = PanelContainer.new()
		var c_sb = StyleBoxFlat.new()
		c_sb.bg_color = Color(0.02, 0.03, 0.06, 0.85)
		c_sb.border_width_left = 2
		c_sb.border_width_top = 2
		c_sb.border_width_right = 2
		c_sb.border_width_bottom = 2
		c_sb.border_color = Color(it.get("color", Color.CYAN).r, it.get("color", Color.CYAN).g, it.get("color", Color.CYAN).b, 0.6)
		c_panel.add_theme_stylebox_override("panel", c_sb)
		vbox.add_child(c_panel)
		
		var c_margin = MarginContainer.new()
		c_margin.add_theme_constant_override("margin_left", 14)
		c_margin.add_theme_constant_override("margin_top", 10)
		c_margin.add_theme_constant_override("margin_right", 14)
		c_margin.add_theme_constant_override("margin_bottom", 10)
		c_panel.add_child(c_margin)
		
		var c_vbox = VBoxContainer.new()
		c_vbox.add_theme_constant_override("separation", 4)
		c_margin.add_child(c_vbox)
		
		var it_title = Label.new()
		it_title.text = it.get("title", "")
		setup_label_style(it_title, 20, it.get("color", Color.CYAN), 4)
		c_vbox.add_child(it_title)
		
		var it_desc = Label.new()
		it_desc.text = it.get("desc", "")
		it_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		setup_label_style(it_desc, 17, Color.WHITE, 3)
		c_vbox.add_child(it_desc)
		
	var resume_btn = Button.new()
	resume_btn.text = "了解・戦闘開始 (SPACE / クリック)"
	resume_btn.custom_minimum_size = Vector2(0, 56)
	if PIXEL_FONT:
		resume_btn.add_theme_font_override("font", PIXEL_FONT)
	resume_btn.add_theme_font_size_override("font_size", 22)
	style_game_over_button(resume_btn, border_col)
	vbox.add_child(resume_btn)
	
	var close_fn = func():
		get_tree().paused = false
		overlay.queue_free()
		
	resume_btn.pressed.connect(close_fn)


func toggle_pause_menu() -> void:
	if has_node("PausePanel"):
		get_node("PausePanel").queue_free()
		get_tree().paused = false
		return
		
	get_tree().paused = true
	
	var panel = ColorRect.new()
	panel.name = "PausePanel"
	panel.color = Color(0.04, 0.05, 0.08, 0.94)
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.process_mode = PROCESS_MODE_ALWAYS
	add_child(panel)
	
	var margin = MarginContainer.new()
	margin.anchor_left = 0.08
	margin.anchor_top = 0.05
	margin.anchor_right = 0.92
	margin.anchor_bottom = 0.95
	panel.add_child(margin)
	
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)
	
	var title = Label.new()
	title.text = "【作戦一時停止 - PAUSE】"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_label_style(title, 34, Color.CYAN, 8)
	vbox.add_child(title)
	
	# Current Weapon info
	var w_name = Global.equipped_weapon
	if Global.available_weapons.has(w_name):
		w_name = Global.available_weapons[w_name].get("name", w_name)
	var status_lbl = Label.new()
	status_lbl.text = "装備主兵装: %s [Q/E切替可能] | シールド: %s" % [w_name, Global.equipped_shield]
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_label_style(status_lbl, 16, Color.GOLD, 4)
	vbox.add_child(status_lbl)
	
	# Section: 解析変異兵装ステータス
	var sec_lbl = Label.new()
	sec_lbl.text = "─── 現在の解析変異スロット (MAX 3) ───"
	sec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_label_style(sec_lbl, 20, Color.WHITE, 6)
	vbox.add_child(sec_lbl)
	
	var player_node = get_node_or_null("../Player")
	var active_keys = player_node.active_traits if player_node and "active_traits" in player_node else []
	
	if active_keys.size() == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "※ 現在装備中の変異兵装はありません。\n（敵弾をジャストガード/パリィして解析ゲージを100%にすると自動装備されます）"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		setup_label_style(empty_lbl, 15, Color.GRAY, 3)
		vbox.add_child(empty_lbl)
	else:
		for k in active_keys:
			var card = create_pause_weapon_card(k, player_node.analysis_patterns.get(k, {}))
			vbox.add_child(card)
			
	# Action buttons
	var btns_vbox = VBoxContainer.new()
	btns_vbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btns_vbox)
	
	var resume_btn = Button.new()
	resume_btn.text = "作戦再開 (ESC / クリック)"
	resume_btn.custom_minimum_size = Vector2(300, 50)
	resume_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	style_game_over_button(resume_btn, Color.CYAN)
	btns_vbox.add_child(resume_btn)
	resume_btn.pressed.connect(func():
		get_tree().paused = false
		panel.queue_free()
	)
	
	var retry_btn = Button.new()
	retry_btn.text = "もう一度プレイ (再挑戦)"
	retry_btn.custom_minimum_size = Vector2(300, 50)
	retry_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	style_game_over_button(retry_btn, Color.GOLD)
	btns_vbox.add_child(retry_btn)
	retry_btn.pressed.connect(func():
		get_tree().paused = false
		var gm = get_node_or_null("../GameManager")
		if gm and gm.has_method("restart"):
			gm.restart()
		panel.queue_free()
	)
	
	var stage_btn = Button.new()
	stage_btn.text = "作戦エリア選択へ"
	stage_btn.custom_minimum_size = Vector2(300, 50)
	stage_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	style_game_over_button(stage_btn, Color(0.3, 0.75, 0.9))
	btns_vbox.add_child(stage_btn)
	stage_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://game/core/stage_selection.tscn")
	)
	
	var menu_btn = Button.new()
	menu_btn.text = "メインメニューへ"
	menu_btn.custom_minimum_size = Vector2(300, 50)
	menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	style_game_over_button(menu_btn, Color.GRAY)
	btns_vbox.add_child(menu_btn)
	menu_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://game/core/main_menu.tscn")
	)


func create_pause_weapon_card(pattern_key: String, p_data: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var cat_info = Global.analysis_catalog.get(pattern_key, {})
	var col = cat_info.get("color", p_data.get("color", Color.CYAN))
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = col
	card.add_theme_stylebox_override("panel", sb)
	
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_bottom", 10)
	card.add_child(m)
	
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	m.add_child(v)
	
	var title_lbl = Label.new()
	var lvl = p_data.get("level", 1)
	title_lbl.text = "%s 【%s】 Lv.%d  [解析元: %s敵 (%s)]" % [
		cat_info.get("icon", p_data.get("icon", "◈")),
		cat_info.get("name", p_data.get("name", pattern_key)),
		lvl,
		cat_info.get("enemy_color", "通常"),
		cat_info.get("enemy_type", "")
	]
	setup_label_style(title_lbl, 17, col, 4)
	v.add_child(title_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = "%s\n%s" % [cat_info.get("stats", ""), cat_info.get("description", "")]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup_label_style(desc_lbl, 14, Color(0.85, 0.9, 0.95), 3)
	v.add_child(desc_lbl)
	
	return card


func style_game_over_button(btn: Button, border_color: Color) -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.06, 0.07, 0.1, 0.95)
	style_normal.border_width_left = 3
	style_normal.border_width_top = 3
	style_normal.border_width_right = 3
	style_normal.border_width_bottom = 3
	style_normal.border_color = border_color
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = border_color
	
	if PIXEL_FONT:
		btn.add_theme_font_override("font", PIXEL_FONT)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
	btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func setup_label_style(label: Label, size: int, color: Color, outline: int = 4) -> void:
	var settings = LabelSettings.new()
	if PIXEL_FONT:
		settings.font = PIXEL_FONT
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = outline
	settings.outline_color = Color.BLACK
	label.label_settings = settings


func update_player_hp(current: int, max_hp_val: int) -> void:
	player_hp_bar.max_value = max_hp_val
	player_hp_bar.value = current
	player_hp_label.text = "自機 HP: %d / %d" % [current, max_hp_val]


func update_boss_hp(current: int, max_hp_val: int) -> void:
	hide_wave_phase_hud()
	boss_hp_bar.visible = true
	boss_hp_label.visible = true
	boss_hp_bar.max_value = max_hp_val
	boss_hp_bar.value = current
	boss_hp_label.text = "ボス HP: %d / %d" % [current, max_hp_val]


func hide_boss_hp() -> void:
	boss_hp_bar.visible = false
	boss_hp_label.visible = false


func update_parry_count(count: int) -> void:
	parry_count_label.text = "パリィ: %d 回" % count


func update_guard_status(_cooldown: float, _is_guarding: bool) -> void:
	pass


func update_guard_heat(heat: float, max_heat: float, is_overheated: bool, overheat_timer: float, is_guarding: bool) -> void:
	if is_instance_valid(shield_heat_bar):
		shield_heat_bar.max_value = max_heat
		shield_heat_bar.value = heat
		
		var fg_style = shield_heat_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fg_style:
			if is_overheated:
				var flash = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
				fg_style.bg_color = Color(1.0, 0.1, 0.1).lerp(Color(0.4, 0.0, 0.0), flash)
			elif is_guarding:
				fg_style.bg_color = Color(0.2, 1.0, 1.0)
			else:
				var pct = (heat / max_heat)
				if pct > 0.7:
					fg_style.bg_color = Color(1.0, 0.45, 0.1)
				elif pct > 0.35:
					fg_style.bg_color = Color(1.0, 0.85, 0.2)
				else:
					fg_style.bg_color = COLOR_SHIELD_HEAT_DEFAULT

	if is_overheated:
		guard_status_label.text = "⚠️ OVERHEAT! 装甲脆弱(被ダメ1.6倍) %.1fs" % overheat_timer
		guard_status_label.label_settings.font_color = Color.RED
	elif is_guarding:
		guard_status_label.text = "シールド: 展開中！"
		guard_status_label.label_settings.font_color = Color.CYAN
	else:
		guard_status_label.text = "シールドヒート [Space]"
		guard_status_label.label_settings.font_color = Color.LIGHT_GRAY





func trigger_flash(color: Color = Color(1.0, 1.0, 1.0, 0.5)) -> void:
	flash_overlay.color = color
	var tween = create_tween()
	tween.tween_property(flash_overlay, "color", Color(color.r, color.g, color.b, 0.0), 0.35)


func show_warning(title: String, subtitle: String) -> void:
	warning_title.text = title
	warning_subtitle.text = subtitle
	
	warning_title.show()
	warning_subtitle.show()
	
	var tween = create_tween().set_loops(4)
	tween.tween_property(warning_title, "modulate:a", 0.1, 0.4)
	tween.tween_property(warning_title, "modulate:a", 1.0, 0.4)
	
	get_tree().create_timer(3.8).timeout.connect(func():
		warning_title.hide()
		warning_subtitle.hide()
	)


func show_game_over(result: String) -> void:
	if has_node("GameOverPanel"):
		get_node("GameOverPanel").queue_free()
		
	var panel = ColorRect.new()
	panel.name = "GameOverPanel"
	panel.color = Color(0.05, 0.05, 0.08, 0.0)
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.process_mode = PROCESS_MODE_ALWAYS
	add_child(panel)
	
	var tween = create_tween()
	if tween.has_method("set_pause_mode"):
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "color", Color(0.05, 0.05, 0.08, 0.85), 0.6)
	
	var container = VBoxContainer.new()
	container.anchor_left = 0.0
	container.anchor_right = 1.0
	container.anchor_top = 0.0
	container.anchor_bottom = 1.0
	container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container.grow_vertical = Control.GROW_DIRECTION_BOTH
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 14)
	panel.add_child(container)
	
	var result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var settings = LabelSettings.new()
	if PIXEL_FONT:
		settings.font = PIXEL_FONT
	settings.font_size = 48
	settings.outline_size = 8
	settings.outline_color = Color.BLACK
	
	if result == "VICTORY":
		result_label.text = "作戦完了"
		settings.font_color = Color.CYAN
	else:
		result_label.text = "作戦失敗"
		settings.font_color = Color.ORANGE_RED
		
	result_label.label_settings = settings
	container.add_child(result_label)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	container.add_child(spacer)
	
	var stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stats_settings = LabelSettings.new()
	if PIXEL_FONT:
		stats_settings.font = PIXEL_FONT
	stats_settings.font_size = 24
	stats_settings.font_color = Color(0.8, 0.9, 1.0, 0.9)
	stats_settings.outline_size = 4
	stats_settings.outline_color = Color.BLACK
	stats_label.label_settings = stats_settings
	
	var parries = 0
	var score = 0
	var game_manager = get_node_or_null("../GameManager")
	if game_manager:
		parries = game_manager.parry_count
		if "total_damage_score" in game_manager:
			score = game_manager.total_damage_score
			
	stats_label.text = "総パリィ数: %d 回\n技術回収: 100%%" % parries
	container.add_child(stats_label)
	
	if result == "VICTORY":
		var spacer_score = Control.new()
		spacer_score.custom_minimum_size = Vector2(0, 15)
		container.add_child(spacer_score)
		
		var score_title_label = Label.new()
		score_title_label.text = "最終スコア"
		score_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var score_title_settings = LabelSettings.new()
		if PIXEL_FONT:
			score_title_settings.font = PIXEL_FONT
		score_title_settings.font_size = 22
		score_title_settings.font_color = Color.GOLD
		score_title_settings.outline_size = 4
		score_title_settings.outline_color = Color.BLACK
		score_title_label.label_settings = score_title_settings
		container.add_child(score_title_label)
		
		var score_val_label = Label.new()
		score_val_label.text = format_score(score)
		score_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var score_val_settings = LabelSettings.new()
		if PIXEL_FONT:
			score_val_settings.font = PIXEL_FONT
		score_val_settings.font_size = 52
		score_val_settings.font_color = Color(1.0, 0.85, 0.1)
		score_val_settings.outline_size = 10
		score_val_settings.outline_color = Color(0.1, 0.1, 0.3)
		score_val_label.label_settings = score_val_settings
		container.add_child(score_val_label)
		
		animate_score_count(score_val_label, score)
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	container.add_child(spacer2)
	
	var theme_color = Color.CYAN if result == "VICTORY" else Color.ORANGE_RED
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.06, 0.07, 0.1, 0.95)
	style_normal.border_width_left = 3
	style_normal.border_width_top = 3
	style_normal.border_width_right = 3
	style_normal.border_width_bottom = 3
	style_normal.border_color = theme_color
	style_normal.corner_radius_top_left = 0
	style_normal.corner_radius_top_right = 0
	style_normal.corner_radius_bottom_left = 0
	style_normal.corner_radius_bottom_right = 0
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = theme_color
	
	var current_stage_num = 1
	if game_manager and "current_stage_num" in game_manager:
		current_stage_num = game_manager.current_stage_num
		
	var next_stage_num = current_stage_num + 1
	var next_stage_path = "res://game/stages/stage_%d.tscn" % next_stage_num
	var has_next_stage = ResourceLoader.exists(next_stage_path)
	var is_next_unlocked = has_next_stage and Global.is_stage_unlocked(next_stage_num)
	
	# 1. 次ステージが開放済みの場合のみ「次のステージへ」ボタンを表示
	if result == "VICTORY" and is_next_unlocked:
		var next_btn = Button.new()
		next_btn.text = "次のステージへ (STAGE %d)" % next_stage_num
		next_btn.custom_minimum_size = Vector2(300, 52)
		next_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		next_btn.add_theme_font_size_override("font_size", 22)
		if PIXEL_FONT:
			next_btn.add_theme_font_override("font", PIXEL_FONT)
		
		next_btn.add_theme_color_override("font_color", Color.WHITE)
		next_btn.add_theme_color_override("font_hover_color", Color.BLACK)
		next_btn.add_theme_color_override("font_pressed_color", Color.BLACK)
		next_btn.add_theme_stylebox_override("normal", style_normal)
		next_btn.add_theme_stylebox_override("hover", style_hover)
		next_btn.add_theme_stylebox_override("pressed", style_hover)
		next_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		container.add_child(next_btn)
		
		next_btn.pressed.connect(func():
			get_tree().paused = false
			if game_manager and game_manager.has_method("load_next_stage"):
				game_manager.load_next_stage()
			panel.queue_free()
		)
		
		var spacer_btn = Control.new()
		spacer_btn.custom_minimum_size = Vector2(0, 8)
		container.add_child(spacer_btn)

	# 2. もう一度プレイ（同じステージを再挑戦）ボタン
	var retry_btn = Button.new()
	retry_btn.text = "もう一度プレイ (STAGE %d)" % current_stage_num if result == "VICTORY" else "再挑戦"
	retry_btn.custom_minimum_size = Vector2(300, 52)
	retry_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry_btn.add_theme_font_size_override("font_size", 22)
	if PIXEL_FONT:
		retry_btn.add_theme_font_override("font", PIXEL_FONT)
	
	var retry_style = style_normal.duplicate()
	if result == "VICTORY":
		retry_style.border_color = Color.GOLD
	var retry_hover = retry_style.duplicate()
	retry_hover.bg_color = Color.GOLD if result == "VICTORY" else theme_color
	
	retry_btn.add_theme_color_override("font_color", Color.WHITE)
	retry_btn.add_theme_color_override("font_hover_color", Color.BLACK)
	retry_btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	retry_btn.add_theme_stylebox_override("normal", retry_style)
	retry_btn.add_theme_stylebox_override("hover", retry_hover)
	retry_btn.add_theme_stylebox_override("pressed", retry_hover)
	retry_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	container.add_child(retry_btn)
	
	retry_btn.pressed.connect(func():
		get_tree().paused = false
		if game_manager and game_manager.has_method("restart"):
			game_manager.restart()
		panel.queue_free()
	)
	
	var spacer_retry = Control.new()
	spacer_retry.custom_minimum_size = Vector2(0, 8)
	container.add_child(spacer_retry)

	# 3. ステージ選択へ戻るボタン
	var stage_select_btn = Button.new()
	stage_select_btn.text = "作戦エリア選択へ"
	stage_select_btn.custom_minimum_size = Vector2(300, 52)
	stage_select_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stage_select_btn.add_theme_font_size_override("font_size", 22)
	if PIXEL_FONT:
		stage_select_btn.add_theme_font_override("font", PIXEL_FONT)
	
	var select_style = style_normal.duplicate()
	select_style.border_color = Color(0.3, 0.75, 0.9)
	var select_hover = select_style.duplicate()
	select_hover.bg_color = Color(0.3, 0.75, 0.9)
	
	stage_select_btn.add_theme_color_override("font_color", Color.WHITE)
	stage_select_btn.add_theme_color_override("font_hover_color", Color.BLACK)
	stage_select_btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	stage_select_btn.add_theme_stylebox_override("normal", select_style)
	stage_select_btn.add_theme_stylebox_override("hover", select_hover)
	stage_select_btn.add_theme_stylebox_override("pressed", select_hover)
	stage_select_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	container.add_child(stage_select_btn)
	
	stage_select_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://game/core/stage_selection.tscn")
	)
	
	var spacer_menu = Control.new()
	spacer_menu.custom_minimum_size = Vector2(0, 8)
	container.add_child(spacer_menu)

	# 4. メインメニューへ戻るボタン
	var menu_btn = Button.new()
	menu_btn.text = "メインメニューへ"
	menu_btn.custom_minimum_size = Vector2(300, 52)
	menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_btn.add_theme_font_size_override("font_size", 22)
	if PIXEL_FONT:
		menu_btn.add_theme_font_override("font", PIXEL_FONT)
	
	var menu_style = style_normal.duplicate()
	menu_style.border_color = Color(0.6, 0.6, 0.6)
	var menu_hover = menu_style.duplicate()
	menu_hover.bg_color = Color(0.7, 0.7, 0.7)
	
	menu_btn.add_theme_color_override("font_color", Color.WHITE)
	menu_btn.add_theme_color_override("font_hover_color", Color.BLACK)
	menu_btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	menu_btn.add_theme_stylebox_override("normal", menu_style)
	menu_btn.add_theme_stylebox_override("hover", menu_hover)
	menu_btn.add_theme_stylebox_override("pressed", menu_hover)
	menu_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	container.add_child(menu_btn)
	
	menu_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://game/core/main_menu.tscn")
	)
	
	get_tree().paused = true


func spawn_damage_popup(pos: Vector2, amount: int, is_finish: bool = false, is_critical: bool = false) -> void:
	var label = Label.new()
	label.text = str(amount) + ("!" if is_critical else "")
	
	var settings = LabelSettings.new()
	if PIXEL_FONT:
		settings.font = PIXEL_FONT
	if is_finish:
		settings.font_size = 22
		settings.font_color = Color(1.0, 0.6, 0.2)
		settings.outline_size = 3
		settings.outline_color = Color.BLACK
	elif is_critical:
		settings.font_size = 20
		settings.font_color = Color(1.0, 0.88, 0.15) # 鮮烈なクリティカルゴールド
		settings.outline_size = 4
		settings.outline_color = Color(0.35, 0.05, 0.0) # 深紅アウトライン
	else:
		settings.font_size = 15
		if amount > 15:
			settings.font_color = Color(1.0, 0.9, 0.3)
		else:
			settings.font_color = Color(0.9, 0.95, 1.0, 0.9)
		settings.outline_size = 2
		settings.outline_color = Color.BLACK
		
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.pivot_offset = Vector2(40, 15)
	
	label.global_position = pos + Vector2(randf_range(-15, 15), randf_range(-15, 5))
	add_child(label)
	
	var start_scale = Vector2(0.8, 0.8) if is_critical else Vector2(0.5, 0.5)
	var end_scale = Vector2(1.3, 1.3) if is_critical else Vector2(1.0, 1.0)
	label.scale = start_scale
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "scale", end_scale, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var target_pos = label.global_position + Vector2(randf_range(-15, 15), -45 if is_critical else -35)
	tween.tween_property(label, "global_position", target_pos, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var fade_tween = create_tween()
	fade_tween.tween_interval(0.18)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.20)
	
	tween.chain().tween_callback(label.queue_free)


func spawn_kill_popup(pos: Vector2, text: String = "撃破！") -> void:
	var label = Label.new()
	label.text = text
	
	var settings = LabelSettings.new()
	if PIXEL_FONT:
		settings.font = PIXEL_FONT
	settings.font_size = 24
	settings.font_color = Color(1.0, 0.85, 0.2)
	settings.outline_size = 3
	settings.outline_color = Color(0.1, 0.05, 0.0, 1.0)
	
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.pivot_offset = Vector2(60, 20)
	label.global_position = pos + Vector2(-60, -20)
	
	add_child(label)
	
	label.scale = Vector2(0.4, 0.4)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "global_position", pos + Vector2(-60, -50), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var fade = create_tween()
	fade.tween_interval(0.25)
	fade.tween_property(label, "modulate:a", 0.0, 0.2)
	
	tween.chain().tween_callback(label.queue_free)


func format_score(value: int) -> String:
	var s = str(value)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result


func animate_score_count(label: Label, target_score: int) -> void:
	if target_score <= 0:
		if is_instance_valid(label):
			label.text = "0"
		return
		
	label.scale = Vector2(0.8, 0.8)
	label.pivot_offset = Vector2(200, 25)
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	tween.tween_method(func(val):
		if is_instance_valid(label):
			var int_val = int(val)
			label.text = format_score(int_val)
			label.scale = Vector2(1.0, 1.0) + Vector2(randf_range(-0.04, 0.04), randf_range(-0.04, 0.04))
	, 0.0, float(target_score), 1.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func():
		if is_instance_valid(label):
			label.text = format_score(target_score)
			label.scale = Vector2(1.2, 1.2)
			var bounce_tween = create_tween()
			bounce_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			bounce_tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	)
