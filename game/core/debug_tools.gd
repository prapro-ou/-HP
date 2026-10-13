extends Node
## Development-only, temporary state. No command-line unlock or persisted flag.
const UPGRADE_RESET_SCOPE = "HP・パリィ・冷却・主兵装/捕獲威力・シールド固有範囲・フォーカス・COUNTER持続/威力"
var active: bool = false
var infinite_hp: bool = false
var stage_num: int = 1
var score: int = 0
var snapshot: Dictionary = {}
var canvas: CanvasLayer
var panel: ColorRect
var badge: Label
var enabled_toggle: CheckButton
var hp_toggle: CheckButton
var notice: Label
var buttons: Dictionary = {}

static func build_allowed(debug: bool, editor: bool, dedicated: bool) -> bool:
	return debug and (editor or dedicated)

func is_allowed() -> bool:
	return build_allowed(OS.has_feature("debug"), OS.has_feature("editor"), OS.has_feature("counter_debug"))

func is_active() -> bool:
	return is_allowed() and active

func has_infinite_hp() -> bool:
	return is_active() and infinite_hp

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_allowed():
		return
	canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	badge = Label.new()
	badge.text = "DEBUG  保存なし"
	badge.position = Vector2(12, 12)
	badge.add_theme_font_override("font", Global.get_readable_font())
	badge.add_theme_font_size_override("font_size", 22)
	badge.add_theme_color_override("font_color", Color.GOLD)
	badge.add_theme_color_override("font_outline_color", Color.BLACK)
	badge.add_theme_constant_override("outline_size", 2)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.hide()
	canvas.add_child(badge)

func _process(_delta: float) -> void:
	if is_instance_valid(badge):
		badge.visible = is_active() or (is_instance_valid(panel) and panel.visible)
		# Keep the practice hint and combat warnings clear.
		var size := get_viewport().get_visible_rect().size
		badge.position = Vector2(size.x - badge.size.x - 12, size.y - 144) if manager() != null else Vector2(12, 12)

func manager() -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("GameManager") if is_instance_valid(scene) else null

func can_open_panel() -> bool:
	if not is_allowed() or get_tree().paused:
		return false
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return false
	if scene.has_method("sync_settings_to_ui"):
		if scene.currently_rebinding_action != "":
			return false
		for dialog in [scene.confirm_dialog, scene.tutorial_dialog, scene.credits_dialog]:
			if is_instance_valid(dialog) and dialog.visible:
				return false
	for key in [Global.key_shield, Global.key_counter_system, Global.key_up, Global.key_down, Global.key_left, Global.key_right, Global.key_weapon_prev, Global.key_weapon_next]:
		if key == KEY_F10:
			return false
	var gm := manager()
	if gm != null and (gm.player.is_control_locked or gm.current_state in [gm.State.DEFEAT, gm.State.VICTORY, gm.State.VICTORY_TRANSITION]):
		return false
	return true

func _input(event: InputEvent) -> void:
	if not is_allowed() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if is_instance_valid(panel) and panel.visible:
		if event.keycode in [KEY_F10, KEY_ESCAPE]:
			close_panel()
			get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F10 and can_open_panel():
		open_panel()
		get_viewport().set_input_as_handled()

func begin_session() -> bool:
	if not is_allowed():
		return false
	if active:
		return true
	var data := Global.load_game_data(false)
	stage_num = int(data.get("stage_num", 1))
	score = int(data.get("score", 0))
	# Practice already owns the outer campaign snapshot. OFF always ends the run.
	if Global.practice_active:
		snapshot = Global._practice_snapshot.duplicate(true)
	else:
		for key in Global.PRACTICE_STATE_KEYS:
			var value = Global.get(key)
			snapshot[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	active = true
	infinite_hp = false
	refresh_scene()
	return true

func end_session() -> void:
	if not is_active():
		return
	close_panel()
	var gm := manager()
	if gm != null:
		gm.clean_stage_entities()
		gm.player.lock_controls()
	Global.end_practice()
	for key in snapshot:
		Global.set(key, snapshot[key])
	snapshot.clear()
	active = false
	infinite_hp = false
	Engine.time_scale = 1.0
	Global.apply_all_settings()
	get_tree().change_scene_to_file("res://game/core/main_menu.tscn")

func set_infinite_hp(enabled: bool) -> bool:
	if not is_active():
		return false
	infinite_hp = enabled
	return true

func add_tp() -> bool:
	if not is_active():
		return false
	Global.tech_points += 100
	refresh_scene()
	return true

func unlock_all() -> bool:
	if not is_active():
		return false
	Global.unlocked_weapons = WeaponCatalog.PRIMARY.keys()
	Global.unlocked_counter_weapons = WeaponCatalog.COUNTER.keys()
	Global.unlocked_shields = ["counter", "gauge", "power"]
	Global.unlocked_stages = [1, 2, 3, 4, 5]
	refresh_scene()
	return true

func fill_counter() -> bool:
	var gm := manager()
	if not is_active() or gm == null or gm.current_state != gm.State.BOSS:
		return false
	var counter: CounterSystem = gm.counter_system
	if counter.phase == CounterSystem.Phase.READY:
		return true
	if counter.phase != CounterSystem.Phase.CHARGING:
		return false
	for i in range(100):
		counter.register_parry(1)
		if counter.is_ready():
			return true
	return false

func jump_to_boss() -> bool:
	var gm := manager()
	if not is_active() or gm == null:
		return false
	close_panel()
	return gm.debug_jump_to_boss()

func reset_temporary_data(kind: String) -> bool:
	if not is_active() or manager() != null or Global.practice_active:
		return false
	match kind:
		"upgrades": Global.reset_upgrade_levels()
		"tp": Global.reset_tech_points()
		"progress": Global.reset_development_progress()
		_: return false
	refresh_scene()
	if is_instance_valid(notice):
		notice.text = "一時リセット完了：" + (UPGRADE_RESET_SCOPE if kind == "upgrades" else "TP" if kind == "tp" else "兵装・図鑑・ステージ解放")
	return true

func refresh_scene() -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	if scene.has_method("update_lab_hud"):
		scene.update_lab_hud()
	if scene.has_method("update_stage_selection"):
		scene.update_stage_selection(true)
	if scene.has_method("update_button_states"):
		scene.update_button_states()
	if scene.has_method("sync_settings_to_ui"):
		scene.reset_btn.disabled = is_active()

func add_text(stack: VBoxContainer, text: String, size: int = 20) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	stack.add_child(label)
	return label

func add_button(stack: VBoxContainer, id: String, text: String, action: Callable) -> void:
	var button := Button.new()
	button.name = id
	button.text = text
	button.custom_minimum_size.y = 50
	button.pressed.connect(func():
		if not is_active(): return
		action.call()
		refresh_panel()
	)
	stack.add_child(button)
	buttons[id] = button

func create_panel() -> void:
	panel = ColorRect.new()
	panel.name = "DevelopmentPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.color = Color(0.015, 0.025, 0.04, 0.97)
	var theme_body := Theme.new()
	theme_body.default_font = Global.get_readable_font()
	theme_body.default_font_size = 22
	panel.theme = theme_body
	canvas.add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 14)
	scroll.add_child(stack)
	add_text(stack, "DEBUG / 開発専用", 32)
	add_text(stack, "一時状態です。通常セーブには反映しません。\nOFFにすると出撃・練習を終了し、元の状態へ戻ります。")
	enabled_toggle = CheckButton.new()
	enabled_toggle.text = "一時デバッグを有効にする"
	stack.add_child(enabled_toggle)
	enabled_toggle.toggled.connect(func(enabled):
		if enabled: begin_session()
		else: end_session()
		refresh_panel()
	)
	hp_toggle = CheckButton.new()
	hp_toggle.text = "自機HP無限（被弾反応は維持）"
	stack.add_child(hp_toggle)
	hp_toggle.toggled.connect(set_infinite_hp)
	add_button(stack, "AddTP", "TP +100（一時）", add_tp)
	add_button(stack, "UnlockAll", "全装備・全ステージを一時解放", unlock_all)
	add_button(stack, "JumpBoss", "ボスへ直行（道中のみ）", jump_to_boss)
	add_button(stack, "FillCounter", "COUNTER即充填（使用済みは不可）", fill_counter)
	add_text(stack, "個別リセットも一時状態だけが対象。\n以下は出撃・練習の外で利用できます。")
	add_button(stack, "ResetUpgrades", "全強化・フォーカスを一時リセット", func(): reset_temporary_data("upgrades"))
	buttons.ResetUpgrades.tooltip_text = UPGRADE_RESET_SCOPE
	add_button(stack, "ResetTP", "TPを一時リセット", func(): reset_temporary_data("tp"))
	add_button(stack, "ResetProgress", "兵装・図鑑・ステージ解放を一時リセット", func(): reset_temporary_data("progress"))
	notice = add_text(stack, "F10 / ESCで閉じて続行。終了は上のOFF操作。", 18)
	var close := Button.new()
	close.text = "閉じて続行 [F10 / ESC]"
	close.custom_minimum_size.y = 52
	close.pressed.connect(close_panel)
	stack.add_child(close)

func refresh_panel() -> void:
	if not is_instance_valid(panel): return
	enabled_toggle.set_pressed_no_signal(is_active())
	hp_toggle.set_pressed_no_signal(has_infinite_hp())
	hp_toggle.disabled = not is_active()
	for button in buttons.values():
		button.disabled = not is_active()
	var gm := manager()
	buttons.JumpBoss.disabled = not is_active() or gm == null or not gm.current_state in [gm.State.WAVE, gm.State.WAVE_TRANSITION, gm.State.INTERLUDE]
	buttons.FillCounter.disabled = not is_active() or gm == null or gm.current_state != gm.State.BOSS or not gm.counter_system.phase in [CounterSystem.Phase.CHARGING, CounterSystem.Phase.READY]
	for id in ["ResetUpgrades", "ResetTP", "ResetProgress"]:
		buttons[id].disabled = not is_active() or gm != null or Global.practice_active

func open_panel() -> bool:
	if not can_open_panel(): return false
	if not is_instance_valid(panel): create_panel()
	refresh_panel()
	panel.show()
	get_tree().paused = true
	return true

func close_panel() -> void:
	if is_instance_valid(panel) and panel.visible:
		panel.hide()
		get_tree().paused = false
