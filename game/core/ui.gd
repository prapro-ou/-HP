extends CanvasLayer

const COMBAT_POPUP_SCENE: PackedScene = preload("res://game/ui/components/combat_popup.tscn")
const PAUSE_SETTINGS_SCENE: PackedScene = preload("res://game/ui/components/pause_settings_panel.tscn")
const PIXEL_FONT: Font = preload("res://game/assets/fonts/DotGothic16-Regular.ttf")
## UI 表示スクリプト（CanvasLayerを継承し、シーン ui.tscn のノードとバインド）
## - HP バー（Player・Boss）
## - ガード・パリィ・捕獲追撃表示
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
@onready var v3_counter_panel: PanelContainer = $V3CounterPanel
@onready var v3_counter_bar: ProgressBar = $V3CounterPanel/Margin/Stack/Gauge
@onready var v3_counter_label: Label = $V3CounterPanel/Margin/Stack/Label

# 警告・フラッシュ演出UI
@onready var warning_title: Label = $WarningTitle
@onready var warning_subtitle: Label = $WarningSubtitle
@onready var flash_overlay: ColorRect = $FlashOverlay

var shield_heat_bar: ProgressBar
var boost_label: Label
var counter_caption: Label
var top_cards: ColorRect


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
	style_hp_bar(player_hp_bar, COLOR_PLAYER_HP)
	style_hp_bar(boss_hp_bar, COLOR_BOSS_HP)
	
	# 左上プレイヤー情報配置 (大きめのフォント・バーで視認性向上)
	player_hp_label.position = Vector2(20, 10)
	player_hp_bar.position = Vector2(20, 32)
	player_hp_bar.custom_minimum_size = Vector2(240, 16)
	player_hp_bar.size = Vector2(240, 16)
	
	setup_label_style(player_hp_label, 22, Color.WHITE, 2)
	setup_label_style(boss_hp_label, 22, Color.GOLD, 2)
	setup_label_style(parry_count_label, 16, Color.CYAN, 4)
	setup_label_style(guard_status_label, 22, Color.GREEN, 2)
	setup_label_style(v3_counter_label, 22, Color(0.35, 0.9, 1.0), 2)
	setup_label_style(warning_title, FONT_SIZE_WARNING_TITLE, Color.RED, 10)
	setup_label_style(warning_subtitle, FONT_SIZE_WARNING_SUBTITLE, Color.GOLD, 6)
	
	parry_count_label.position = Vector2(20, 68)
	guard_status_label.position = Vector2(20, 88)
	
	# 主兵装HUD表示
	create_equipped_weapon_hud()
	
	# 中央〜右側ボス情報配置 (大迫力のロングHPゲージ)
	boss_hp_label.position = Vector2(260, 6)
	boss_hp_label.custom_minimum_size = Vector2(520, 22)
	boss_hp_label.size = Vector2(520, 22)
	boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_hp_bar.position = Vector2(260, 30)
	boss_hp_bar.custom_minimum_size = Vector2(520, 20)
	boss_hp_bar.size = Vector2(520, 20)
	
	boost_label = Label.new()
	boost_label.name = "BoostLabel"
	setup_label_style(boost_label, 18, Color.GOLD, 2)
	add_child(boost_label)
	create_shield_heat_bar()
	create_capture_ui()
	create_wave_phase_ui()
	create_top_warning_ui()
	counter_caption = Label.new()
	counter_caption.text = "COUNTER"
	setup_label_style(counter_caption, 18, Color.CYAN, 2)
	add_child(counter_caption)
	top_cards = ColorRect.new()
	top_cards.color = Color(0.02, 0.04, 0.07, 0.85)
	top_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_cards)
	move_child(top_cards, 1)
	get_viewport().size_changed.connect(layout_combat_hud)
	layout_combat_hud()


func layout_combat_hud() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var width := viewport_size.x
	var column := (width - 36.0) * 0.5
	top_cards.position = Vector2(6, 6)
	top_cards.size = Vector2(width - 12.0, 80)
	counter_caption.position = Vector2(width - 232.0, viewport_size.y - 108.0)
	player_hp_label.position = Vector2(12, 12)
	player_hp_bar.position = Vector2(12, 38)
	player_hp_bar.custom_minimum_size = Vector2(column, 8)
	player_hp_bar.size = Vector2(column, 8)
	guard_status_label.position = Vector2(12, 49)
	guard_status_label.size = Vector2(column - 105.0, 22)
	guard_status_label.clip_text = true
	shield_heat_bar.position = Vector2(12, 74)
	shield_heat_bar.custom_minimum_size = Vector2(column, 8)
	shield_heat_bar.size = Vector2(column, 8)
	boost_label.position = Vector2(12 + column - 101.0, 49)
	boss_hp_label.position = Vector2(width - column - 12.0, 12)
	boss_hp_bar.position = Vector2(width - column - 12.0, 52)
	for node in [boss_hp_bar, boss_hp_label]:
		node.custom_minimum_size.x = column
		node.size.x = column
	parry_count_label.hide()
	equipped_weapon_label.hide()
	wave_kills_label.hide()
	wave_timer_panel.position = Vector2(width - column - 12.0, 12)
	wave_timer_panel.custom_minimum_size = Vector2(column, 70)
	wave_timer_panel.size = Vector2(column, 70)
	v3_counter_panel.offset_left = width - 232.0
	v3_counter_panel.offset_right = width - 12.0
	v3_counter_panel.offset_top = -82.0
	v3_counter_panel.offset_bottom = -12.0
	v3_counter_bar.custom_minimum_size.y = 8.0
	var captures := get_node("CapturePanel") as PanelContainer
	captures.position = Vector2(12, viewport_size.y - 82.0)
	captures.custom_minimum_size = Vector2(260, 70)
	captures.size = Vector2(260, 70)
	top_warning_overlay.offset_left = 12.0
	top_warning_overlay.offset_right = -12.0
	top_warning_overlay.offset_top = 88.0
	top_warning_overlay.offset_bottom = 126.0
	top_warning_label.offset_top = 4.0
	top_warning_label.offset_bottom = 34.0

var equipped_weapon_label: Label

func create_equipped_weapon_hud() -> void:
	equipped_weapon_label = Label.new()
	equipped_weapon_label.name = "EquippedWeaponLabel"
	equipped_weapon_label.position = Vector2(20, 108)
	setup_label_style(equipped_weapon_label, 20, Color(1.0, 0.85, 0.3), 4)
	add_child(equipped_weapon_label)
	update_equipped_weapon_hud(Global.equipped_weapon)


func update_equipped_weapon_hud(weapon_id: String) -> void:
	if is_instance_valid(equipped_weapon_label):
		var w_name = weapon_id
		if Global.available_weapons.has(weapon_id):
			w_name = Global.available_weapons[weapon_id].get("name", weapon_id)
		equipped_weapon_label.text = "主兵装  %s" % w_name


func update_v3_counter_gauge(value: float, _ready: bool) -> void:
	var manager = get_node_or_null("/root/Main/GameManager")
	if manager:
		update_v3_counter_status(manager.counter_system.phase, value)

func update_v3_counter_status(phase: CounterSystem.Phase, value: float) -> void:
	v3_counter_panel.visible = phase != CounterSystem.Phase.DISABLED
	if is_instance_valid(counter_caption):
		counter_caption.visible = v3_counter_panel.visible
	v3_counter_bar.value = value
	match phase:
		CounterSystem.Phase.READY:
			v3_counter_label.text = "READY [%s]" % Global.get_combat_key_name(Global.key_counter_system)
		CounterSystem.Phase.ACTIVE:
			var manager = get_node_or_null("/root/Main/GameManager")
			v3_counter_label.text = "ACTIVE %.1fs" % (manager.counter_system.remaining if manager else 0.0)
		CounterSystem.Phase.SPENT:
			v3_counter_label.text = "使用済み"
		_:
			v3_counter_label.text = "充填  %d%%" % int(value)
	v3_counter_label.label_settings.font_color = Color.GOLD if phase == CounterSystem.Phase.READY else Color(0.35, 0.9, 1.0)

var top_warning_overlay: ColorRect
var top_warning_label: Label
var top_warning_tween: Tween
var top_warning_active: bool = false
var top_warning_generation: int = 0

func create_top_warning_ui() -> void:
	top_warning_overlay = ColorRect.new()
	top_warning_overlay.name = "TopWarningOverlay"
	top_warning_overlay.anchor_left = 0.0
	top_warning_overlay.anchor_right = 1.0
	top_warning_overlay.offset_top = 0.0
	top_warning_overlay.offset_bottom = 65.0
	top_warning_overlay.color = Color(1.0, 0.0, 0.08, 0.0)
	top_warning_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_warning_overlay)
	
	top_warning_label = Label.new()
	top_warning_label.name = "TopWarningLabel"
	top_warning_label.anchor_left = 0.0
	top_warning_label.anchor_right = 1.0
	top_warning_label.offset_top = 18.0
	top_warning_label.offset_bottom = 55.0
	top_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_warning_label.text = "ガード不可 — 回避！"
	var l_set = LabelSettings.new()
	if PIXEL_FONT:
		l_set.font = Global.get_readable_font()
	l_set.font_size = 22
	l_set.font_color = Color(1.0, 0.4, 0.4)
	l_set.outline_size = 2
	l_set.outline_color = Color(0.1, 0.0, 0.0)
	top_warning_label.label_settings = l_set
	top_warning_label.modulate.a = 0.0
	top_warning_overlay.add_child(top_warning_label)


var combat_notice_priority: int = -1

func show_combat_notice(message: String, color: Color = Color.GOLD, duration: float = 1.2, priority: int = 0) -> void:
	if top_warning_active or priority < combat_notice_priority:
		return
	combat_notice_priority = priority
	top_warning_generation += 1
	var generation := top_warning_generation
	if is_instance_valid(top_warning_tween):
		top_warning_tween.kill()
	top_warning_label.text = message
	top_warning_label.label_settings.font_color = color
	top_warning_label.modulate.a = 1.0
	top_warning_overlay.color = Color(0.02, 0.04, 0.07, 0.85)
	get_tree().create_timer(duration, false).timeout.connect(func():
		if generation == top_warning_generation:
			combat_notice_priority = -1
			top_warning_label.modulate.a = 0.0
			top_warning_overlay.color.a = 0.0
	)

func show_top_unparryable_warning(duration: float = 2.0, message: String = "") -> void:
	if not is_instance_valid(top_warning_overlay):
		return
	top_warning_active = true
	combat_notice_priority = 2
	top_warning_generation += 1
	var generation := top_warning_generation
	if is_instance_valid(top_warning_tween):
		top_warning_tween.kill()
	top_warning_label.text = "ガード不可 — 回避！"
	top_warning_label.tooltip_text = message
	top_warning_label.label_settings.font_color = Color(1.0, 0.4, 0.4)
	top_warning_label.modulate.a = 1.0
	top_warning_overlay.color = Color(0.8, 0.02, 0.04, 0.18)
	get_tree().create_timer(duration, false).timeout.connect(func():
		if generation == top_warning_generation:
			top_warning_active = false
			combat_notice_priority = -1
			top_warning_label.modulate.a = 0.0
			top_warning_overlay.color.a = 0.0
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
	wave_level_label.text = "WAVE 1"
	var w_set = LabelSettings.new()
	if PIXEL_FONT:
		w_set.font = Global.get_readable_font()
	w_set.font_size = 18
	w_set.font_color = Color.GOLD
	w_set.outline_size = 4
	w_set.outline_color = Color.BLACK
	wave_level_label.label_settings = w_set
	hdr.add_child(wave_level_label)
	
	wave_countdown_label = Label.new()
	wave_countdown_label.text = "上限 01:00"
	wave_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var c_set = LabelSettings.new()
	if PIXEL_FONT:
		c_set.font = Global.get_readable_font()
	c_set.font_size = 20
	c_set.font_color = Color.CYAN
	c_set.outline_size = 6
	c_set.outline_color = Color.BLACK
	wave_countdown_label.label_settings = c_set
	vbox.add_child(wave_countdown_label)
	
	wave_kills_label = Label.new()
	wave_kills_label.text = "撃破数: 0 体"
	wave_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var k_set = LabelSettings.new()
	if PIXEL_FONT:
		k_set.font = Global.get_readable_font()
	k_set.font_size = 18
	k_set.font_color = Color(0.9, 0.9, 0.9)
	k_set.outline_size = 4
	k_set.outline_color = Color.BLACK
	wave_kills_label.label_settings = k_set
	vbox.add_child(wave_kills_label)


func update_wave_phase_hud(wave_num: int, remaining_time: float, kills: int, remaining: int = -1, total_waves: int = 0, transitioning: bool = false) -> void:
	if is_instance_valid(wave_timer_panel):
		wave_timer_panel.visible = true
		wave_level_label.text = "WAVE %d/%d  %s" % [wave_num, total_waves, "次へ" if transitioning else "残%d" % remaining] if total_waves > 0 else "WAVE %d" % wave_num
		
		var total_sec = max(0, int(ceil(remaining_time)))
		var mins = total_sec / 60
		var secs = total_sec % 60
		wave_countdown_label.text = "上限 %02d:%02d" % [mins, secs]
		
		if remaining_time <= 10.0:
			var flash = int(remaining_time * 6.0) % 2 == 0
			wave_countdown_label.label_settings.font_color = Color.RED if flash else Color.YELLOW
		else:
			wave_countdown_label.label_settings.font_color = Color.CYAN
			
		wave_kills_label.text = "撃破数: %d 体" % kills


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


var capture_label: Label
var capture_detail: Label

func create_capture_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "CapturePanel"
	panel.position = Vector2(440, 58)
	panel.custom_minimum_size = Vector2(260, 58)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.09, 0.8)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.8, 1.0, 0.7)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	capture_label = Label.new()
	setup_label_style(capture_label, 22, Color.CYAN, 2)
	stack.add_child(capture_label)
	capture_detail = Label.new()
	capture_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup_label_style(capture_detail, 18, Color.WHITE, 2)
	stack.add_child(capture_detail)
	update_capture_hud([], 0.0)

func update_capture_hud(shots: Array, _power_remaining: float = 0.0) -> void:
	if not is_instance_valid(capture_label):
		return
	capture_label.text = "CAPTURE  %d / %d" % [shots.size(), CaptureVolley.CAPACITY]
	if Global.counter_only_mode_enabled:
		capture_label.text = "捕獲追撃 OFF"
	var precision_count := 0
	for shot in shots:
		if shot.get("precision", false):
			precision_count += 1
	capture_detail.visible = not shots.is_empty()
	capture_detail.text = "保持中" if precision_count == 0 else "保持中  精密 %d発" % precision_count

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
	
	var is_hard = Global.hard_mode_enabled if Global else false
	var accent_col = Color(1.0, 0.3, 0.3, 0.9) if is_hard else Color(0.3, 0.9, 1.0, 0.8)
	
	# Top & Bottom accent lines
	var line_top = ColorRect.new()
	line_top.color = accent_col
	line_top.anchor_right = 1.0
	line_top.offset_bottom = 2.0
	stage_intro_banner.add_child(line_top)
	
	var line_bottom = ColorRect.new()
	line_bottom.color = accent_col
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
	num_lbl.text = "── OPERATION STAGE %d%s ──" % [stage_num, " [HARD MODE]" if is_hard else ""]
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_label_style(num_lbl, 16, accent_col, 4)
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
		if not has_node("PracticeEnd") and not has_node("GameOverPanel") and not has_node("AnalysisUnlockModal") and not has_node("TutorialGuideModal"):
			toggle_pause_menu()


func show_tutorial_guide_modal(topic: String) -> void:
	if Global.practice_active:
		return
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
	var title_text = "【TUTORIAL 指南】"
	var sub_text = ""
	var border_col = Color.CYAN
	var items = []
	
	match topic:
		"controls":
			title_text = "【機体操作 ＆ 戦闘システム指南】"
			sub_text = "基本操作と必殺システムを把握し、激戦を制圧せよ！"
			border_col = Color(0.2, 0.8, 1.0)
			var move_k_str = "[WASD] / [方向キー]"
			if Global.control_move_preset == 1:
				move_k_str = "[WASDキー]"
			elif Global.control_move_preset == 2:
				move_k_str = "[方向キー (↑↓←→)]"
			elif Global.control_move_preset == 3:
				move_k_str = "[%s/%s/%s/%s]" % [
					Global.get_key_display_name(Global.key_up),
					Global.get_key_display_name(Global.key_left),
					Global.get_key_display_name(Global.key_down),
					Global.get_key_display_name(Global.key_right)
				]
			var shield_k_str = "[%sキー]" % Global.get_key_display_name(Global.key_shield)
			var cs_k_str = "[%sキー]" % Global.get_counter_system_key_name()
			items = [
				{
					"title": "機体移動",
					"color": Color.CYAN,
					"desc": "%s\n自機を自在に操り、敵の弾幕を掻い潜れ。（設定画面で変更可能）" % move_k_str
				},
				{
					"title": "主兵装射撃",
					"color": Color(0.4, 1.0, 0.5),
					"desc": "【出撃直後から自動射撃】\n予定の敵部隊を倒すと次のウェーブへ。全部隊を撃破すると早くボスへ進みます。道中の上限は60秒です。"
				},
				{
					"title": "ガード ＆ パリィ",
					"color": Color.GOLD,
					"desc": "%s / [右クリック]\nシールドを展開。着弾直前ならパリィとなり、敵弾を捕まえ、次の射撃で追撃します。成功5回で機体を修復します。" % shield_k_str
				},
				{
					"title": "COUNTER SYSTEM",
					"color": Color(1.0, 0.45, 0.9),
					"desc": "%s (設定画面で変更可能)\nボス戦のパリィで充填。READYになったら、装備中のカウンター兵装を手動発動します。通常はボス戦で1回だけ使用できます。" % cs_k_str
				}
			]
		"weapon_analysis":
			title_text = "【捕まえて、撃ち返す】"
			sub_text = "防いだ弾が、自分の追撃になる"
			items = [
				{"title": "パリィで捕獲", "color": Color.CYAN, "desc": "敵弾がリングに入る瞬間に防御ボタンを押します。捕まえた弾は機体の周りに並びます。"},
				{"title": "次の射撃で追撃", "color": Color.GOLD, "desc": "短く保持した後、次の自動射撃で放ちます。ミサイルは誘導、拡散弾は3方向、重弾は爆発の追撃になります。"}
			]
		"time_limit":
			title_text = "【道中突破 ＆ ボス接近】"
			sub_text = "迫る超巨大要塞ボスとの決戦に備えよ！"
			border_col = Color(1.0, 0.55, 0.2)
			items = [
				{
					"title": "道中の上限（60秒）",
					"color": Color(1.0, 0.6, 0.2),
					"desc": "道中全体の上限は60秒。ウェーブ間の待ちも含み、ポーズや操作説明中は止まります。"
				},
				{
					"title": "撃破で早く突破",
					"color": Color(0.3, 0.9, 1.0),
					"desc": "予定の出現が終わり、生きている敵を倒すと次へ。全ウェーブを突破すれば、60秒を待たずにボス警告へ進みます。"
				},
				{
					"title": "ボス戦移行",
					"color": Color(1.0, 0.3, 0.3),
					"desc": "上限60秒では残敵がいてもボス警告へ。未突破のウェーブの移行報酬は獲得できません。COUNTERはボス戦から充填します。"
				}
			]
		"boss_info":
			title_text = "【要塞ボス戦 ＆ サブ砲台の防壁】"
			sub_text = "サブ砲台を破壊し、要塞の装甲を突破せよ！"
			border_col = Color(1.0, 0.2, 0.2)
			items = [
				{
					"title": "サブ砲台の防壁",
					"color": Color(1.0, 0.35, 0.35),
					"desc": "左右のサブ砲台が生存中は、ボスの強固な防壁により【ボス本体への被ダメージが80%カット】されます！"
				},
				{
					"title": "攻略手順",
					"color": Color(0.3, 0.9, 1.0),
					"desc": "左右の砲台を先に破壊します。砲台の弾をパリィして、次の射撃の追撃にできます。"
				},
				{
					"title": "【ガード不可】真紅の警告",
					"color": Color(1.0, 0.1, 0.15),
					"desc": "画面上部が赤く点灯した際はガード不可・断絶レーザーの合図！シールドを貫通するため緊急回避してください！"
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
		it_desc.add_theme_constant_override("line_spacing", 4)
		var desc_set = LabelSettings.new()
		desc_set.font = Global.get_readable_font()
		desc_set.font_size = 17
		desc_set.font_color = Color(0.92, 0.96, 1.0)
		it_desc.label_settings = desc_set
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
	status_lbl.text = "装備主兵装: %s [出撃中固定] | シールド: %s" % [w_name, Global.equipped_shield]
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_label_style(status_lbl, 16, Color.GOLD, 4)
	vbox.add_child(status_lbl)
	
	var instructions := Label.new()
	instructions.text = "主兵装は自動射撃。パリィで敵弾を捕まえ、次の射撃でまとめて追撃。\nCOUNTERはボス戦のパリィで充填し、1戦に1回だけ手動発動。"
	if Global.counter_only_mode_enabled:
		instructions.text = "COUNTER ONLY: 主兵装と捕獲追撃は停止。\nボス戦のパリィでCOUNTERを再充填し、その都度手動発動。"
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup_label_style(instructions, 18, Color.WHITE, 4)
	vbox.add_child(instructions)

	var settings_title = Label.new()
	settings_title.text = "─── クイック設定 ───"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_label_style(settings_title, 20, Color.WHITE, 6)
	vbox.add_child(settings_title)

	var pause_settings = PAUSE_SETTINGS_SCENE.instantiate()
	vbox.add_child(pause_settings)

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
	stage_btn.text = "練習設定へ" if Global.practice_active else "作戦エリア選択へ"
	stage_btn.custom_minimum_size = Vector2(300, 50)
	stage_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	style_game_over_button(stage_btn, Color(0.3, 0.75, 0.9))
	btns_vbox.add_child(stage_btn)
	stage_btn.pressed.connect(func():
		get_tree().paused = false
		if Global.practice_active:
			get_node("../GameManager").exit_practice()
		else:
			leave_campaign_to_stage_selection()
	)
	
	var menu_btn = Button.new()
	menu_btn.text = "オプションへ戻る" if Global.practice_active else "メインメニューへ"
	menu_btn.custom_minimum_size = Vector2(300, 50)
	menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	style_game_over_button(menu_btn, Color.GRAY)
	btns_vbox.add_child(menu_btn)
	menu_btn.pressed.connect(func():
		get_tree().paused = false
		if Global.practice_active:
			get_node("../GameManager").exit_practice(true)
		else:
			leave_campaign_to_main_menu()
	)
	Global.apply_body_font(panel)


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
		settings.font = PIXEL_FONT if size >= 32 else Global.get_readable_font()
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = outline
	settings.outline_color = Color.BLACK
	label.label_settings = settings


func update_player_hp(current: int, max_hp_val: int) -> void:
	if not is_instance_valid(player_hp_bar) or not is_instance_valid(player_hp_label):
		return
	player_hp_bar.max_value = max_hp_val
	player_hp_bar.value = current
	player_hp_label.text = "HP ∞" if Global.practice_infinite_hp() or Global.debug_infinite_hp() else "HP %d / %d" % [current, max_hp_val]


func update_boss_hp(current: int, max_hp_val: int) -> void:
	hide_wave_phase_hud()
	if is_instance_valid(boss_hp_bar):
		boss_hp_bar.visible = true
		boss_hp_bar.max_value = max_hp_val
		boss_hp_bar.value = current
	if is_instance_valid(boss_hp_label):
		boss_hp_label.visible = true
		boss_hp_label.text = "BOSS HP ∞ / " + ("激化" if Global.practice_config.get("intense", false) else "通常") if Global.practice_active else "BOSS %d / %d" % [current, max_hp_val]


func update_parry_count(count: int) -> void:
	if is_instance_valid(parry_count_label):
		parry_count_label.text = "PARRY: %d" % count


func hide_boss_hp() -> void:
	if is_instance_valid(boss_hp_bar):
		boss_hp_bar.visible = false
	if is_instance_valid(boss_hp_label):
		boss_hp_label.visible = false


func update_guard_heat(heat: float, max_heat: float, is_overheated: bool, overheat_timer: float, is_guarding: bool, shield_type: String = "counter", gauge_timer: float = 0.0, max_gauge_ct: float = 3.0) -> void:
	if not is_instance_valid(shield_heat_bar) or not is_instance_valid(guard_status_label):
		return
	var shield_player := get_node_or_null("/root/Main/Player")
	var boost_remaining: float = shield_player.power_boost_remaining if is_instance_valid(shield_player) else 0.0
	boost_label.visible = boost_remaining > 0.0
	boost_label.text = "BOOST %.1fs" % boost_remaining
	if shield_type == "gauge":
		# 吸収マトリクス (3.0s クールダウン表示)
		shield_heat_bar.max_value = max_gauge_ct
		shield_heat_bar.value = gauge_timer
		
		var fg_style = shield_heat_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fg_style:
			if is_guarding:
				fg_style.bg_color = Color(0.2, 1.0, 0.6)
			elif gauge_timer > 0.0:
				var pct = (gauge_timer / max_gauge_ct)
				fg_style.bg_color = Color(1.0, 0.45, 0.1).lerp(Color(1.0, 0.85, 0.2), 1.0 - pct)
			else:
				var flash = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.015)
				fg_style.bg_color = Color(0.1, 0.9, 0.5, flash)
				
		if is_guarding:
			guard_status_label.text = "SHIELD 展開中"
			guard_status_label.label_settings.font_color = Color.CYAN
		elif gauge_timer > 0.0:
			guard_status_label.text = "再展開 %.1fs" % gauge_timer
			guard_status_label.label_settings.font_color = Color(1.0, 0.7, 0.3)
		else:
			guard_status_label.text = "READY [%s]" % Global.get_combat_key_name(Global.key_shield)
			guard_status_label.label_settings.font_color = Color(0.3, 1.0, 0.6)
	else:
		# 通常・カウンター・パワーシールド (ヒート制)
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
			guard_status_label.text = "OVERHEAT  %.1fs" % overheat_timer
			guard_status_label.label_settings.font_color = Color.RED
		elif is_guarding:
			guard_status_label.text = "SHIELD 展開中"
			guard_status_label.label_settings.font_color = Color.CYAN
		elif heat + (shield_player.heat_per_use if shield_player else 22.0) >= max_heat:
			guard_status_label.text = "放熱待ち"
			guard_status_label.label_settings.font_color = Color.ORANGE
		else:
			guard_status_label.text = "READY [%s]" % Global.get_combat_key_name(Global.key_shield)
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
			
	stats_label.text = "総パリィ数: %d回\n技術回収: 100%%" % parries
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
		leave_campaign_to_stage_selection()
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
		leave_campaign_to_main_menu()
	)
	
	get_tree().paused = true


func spawn_damage_popup(pos: Vector2, amount: int, is_finish: bool = false, is_critical: bool = false) -> void:
	var popup := COMBAT_POPUP_SCENE.instantiate() as CombatPopup
	popup.global_position = pos + Vector2(randf_range(-15, 15), randf_range(-15, 5))
	add_child(popup)
	popup.show_damage(amount, is_finish, is_critical)


func spawn_kill_popup(pos: Vector2, text: String = "撃破！") -> void:
	var popup := COMBAT_POPUP_SCENE.instantiate() as CombatPopup
	popup.global_position = pos + Vector2(-60, -20)
	add_child(popup)
	popup.show_kill(text)


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


# --- COUNTER SYSTEM 全画面プレイヤーカラーフィルター＆HUD ---
var counter_system_tint_rect: ColorRect = null
var counter_system_banner: PanelContainer = null
var counter_system_progress_bar: ProgressBar = null
var counter_system_timer_lbl: Label = null
var counter_system_active: bool = false
var counter_system_total_time: float = 10.0
var counter_system_remaining_time: float = 0.0

func _process(delta: float) -> void:
	if counter_system_active and not get_tree().paused:
		update_counter_system_ui(delta)

func activate_counter_system_tint(duration: float) -> void:
	counter_system_active = true
	counter_system_total_time = duration
	counter_system_remaining_time = duration
	
	# プレイヤーカラーの取得
	var p_col_key = Global.player_color
	var p_data = Global.available_player_colors.get(p_col_key, {})
	var p_accent: Color = p_data.get("accent_color", Color(0.2, 0.7, 1.0))
	
	# 1. 全画面カラーティント矩形の生成・初期化
	if not counter_system_tint_rect or not is_instance_valid(counter_system_tint_rect):
		counter_system_tint_rect = ColorRect.new()
		counter_system_tint_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		counter_system_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		counter_system_tint_rect.z_index = 5
		add_child(counter_system_tint_rect)
		
	counter_system_tint_rect.color = Color(p_accent.r, p_accent.g, p_accent.b, 0.0)
	counter_system_tint_rect.visible = true
	
	# ティントのフェードイン＆緩やかなパルス
	var tint_tween = create_tween()
	tint_tween.tween_property(counter_system_tint_rect, "color:a", 0.22, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# The lower-right COUNTER card also shows ACTIVE.
	update_v3_counter_status(CounterSystem.Phase.ACTIVE, 100.0)
	
	# 3. 画面フラッシュ
	trigger_flash(Color(p_accent.r, p_accent.g, p_accent.b, 0.45))

func create_counter_system_banner(p_accent: Color) -> void:
	counter_system_banner = PanelContainer.new()
	counter_system_banner.z_index = 50
	counter_system_banner.custom_minimum_size = Vector2(300, 48)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.12, 0.9)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = p_accent
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	counter_system_banner.add_theme_stylebox_override("panel", sb)
	
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	counter_system_banner.add_child(vb)
	
	var title_lbl = Label.new()
	title_lbl.text = "[COUNTER SYSTEM ONLINE]"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_label_style(title_lbl, 13, p_accent, 3)
	vb.add_child(title_lbl)
	
	counter_system_timer_lbl = Label.new()
	counter_system_timer_lbl.text = "支援砲台部隊 展開中: 10.0s"
	counter_system_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_label_style(counter_system_timer_lbl, 11, Color.WHITE, 2)
	vb.add_child(counter_system_timer_lbl)
	
	counter_system_progress_bar = ProgressBar.new()
	counter_system_progress_bar.custom_minimum_size = Vector2(280, 5)
	counter_system_progress_bar.show_percentage = false
	counter_system_progress_bar.max_value = 100.0
	counter_system_progress_bar.value = 100.0
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = p_accent
	counter_system_progress_bar.add_theme_stylebox_override("fill", bar_fill)
	vb.add_child(counter_system_progress_bar)
	
	add_child(counter_system_banner)

func update_counter_system_ui(_delta: float) -> void:
	if not counter_system_active:
		return
		
	var manager = get_node_or_null("/root/Main/GameManager")
	if not manager:
		return
	counter_system_remaining_time = manager.counter_system.remaining
	update_v3_counter_status(CounterSystem.Phase.ACTIVE, manager.counter_system.gauge)
	if counter_system_remaining_time <= 0.0:
		deactivate_counter_system_tint()
		return
		
	if is_instance_valid(counter_system_timer_lbl):
		counter_system_timer_lbl.text = "%s  %.1fs" % [WeaponCatalog.COUNTER[Global.equipped_counter_weapon]["name"], counter_system_remaining_time]
		
	if is_instance_valid(counter_system_progress_bar) and counter_system_total_time > 0.0:
		counter_system_progress_bar.value = (counter_system_remaining_time / counter_system_total_time) * 100.0
		
	# プレイヤーカラーティントの呼吸パルス
	if is_instance_valid(counter_system_tint_rect):
		var pulse = sin(Time.get_ticks_msec() * 0.006) * 0.04
		counter_system_tint_rect.color.a = clamp(0.20 + pulse, 0.12, 0.28)

func deactivate_counter_system_tint() -> void:
	counter_system_active = false
	if is_instance_valid(counter_system_tint_rect):
		var t = create_tween()
		t.tween_property(counter_system_tint_rect, "color:a", 0.0, 0.35)
		t.chain().tween_callback(func():
			if is_instance_valid(counter_system_tint_rect):
				counter_system_tint_rect.visible = false
		)
		
	if is_instance_valid(counter_system_banner):
		var bt = create_tween()
		bt.tween_property(counter_system_banner, "modulate:a", 0.0, 0.35)
		bt.chain().tween_callback(func():
			if is_instance_valid(counter_system_banner):
				counter_system_banner.visible = false
		)


func reset_counter_system_ui() -> void:
	counter_system_active = false
	counter_system_remaining_time = 0.0
	if is_instance_valid(counter_system_tint_rect):
		counter_system_tint_rect.visible = false
		counter_system_tint_rect.color.a = 0.0
	if is_instance_valid(counter_system_banner):
		counter_system_banner.visible = false
		counter_system_banner.modulate.a = 0.0

func update_practice_hud() -> void:
	wave_timer_panel.show()
	wave_level_label.text = "SIMULATOR"
	wave_countdown_label.text = "無限補充" if Global.practice_config.get("repeat", false) else "単発"
	wave_kills_label.hide()

func show_practice_hint(kind: String) -> void:
	var hints := {
		"straight": "早めに展開で通常捕獲。内側まで引きつけると精密捕獲。",
		"wave": "弾の中心側へ移動してまとめ取り。捕獲後は射手へ追撃。",
		"charge": "溜め中に倒すか、射線を外して強い弾を捕まえる。"
	}
	var label := Label.new()
	label.name = "PracticeHint"
	label.position = Vector2(18, 138)
	label.size = Vector2(get_viewport().get_visible_rect().size.x - 36.0, 68)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup_label_style(label, 18, Color.LIGHT_CYAN, 2)
	label.text = hints.get(kind, "練習中：進行・報酬・保存には反映されません。") + "\n捕獲後に射線を合わせる。ESCで再試行・退出。"
	add_child(label)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.tween_interval(5.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)

func show_practice_end() -> void:
	var panel := ColorRect.new()
	panel.name = "PracticeEnd"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.color = Color(0.025, 0.04, 0.07, 0.94)
	panel.process_mode = PROCESS_MODE_ALWAYS
	add_child(panel)
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 20)
	panel.add_child(stack)
	var title := Label.new()
	title.text = "練習終了"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_label_style(title, 32, Color.CYAN)
	stack.add_child(title)
	var manager := get_node("../GameManager")
	for action in ["同じ設定で再試行", "練習設定へ", "オプションへ戻る"]:
		var button := Button.new()
		button.text = action
		button.custom_minimum_size = Vector2(320, 56)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		style_game_over_button(button, Color.CYAN)
		stack.add_child(button)
		if action == "同じ設定で再試行":
			button.pressed.connect(manager.restart)
		elif action == "練習設定へ":
			button.pressed.connect(func(): manager.exit_practice())
		else:
			button.pressed.connect(func(): manager.exit_practice(true))
	Global.apply_body_font(panel)

func leave_campaign_to_stage_selection() -> void:
	get_node("../GameManager").clean_stage_entities()
	get_tree().change_scene_to_file("res://game/core/stage_selection.tscn")
func leave_campaign_to_main_menu() -> void:
	get_node("../GameManager").clean_stage_entities()
	get_tree().change_scene_to_file("res://game/core/main_menu.tscn")