extends Control
## A local simulator setup. The same equipment, upgrades and controls are used.
const DRONES: Array[String] = ["straight", "wave", "charge", "irregular", "laser", "beam", "missile", "thunder", "vortex", "blade", "meteor"]
const NAMES: Array[String] = ["直進", "波状", "チャージ", "不規則", "レーザー", "ビーム", "ミサイル", "雷撃", "重力", "刃", "隕石"]
var target: OptionButton
var repeat: OptionButton
var hp: OptionButton
var phase: OptionButton
var remembered: Dictionary = {}

func _ready() -> void:
	remembered = Global.practice_config.duplicate(true)
	Global.end_practice()
	var theme_body := Theme.new()
	theme_body.default_font = Global.get_readable_font()
	theme_body.default_font_size = 22
	theme = theme_body
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.04, 0.065)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 24)
	scroll.add_child(stack)
	add_text(stack, "戦闘シミュレーター", 32)
	add_text(stack, "現在の装備・強化・難易度で練習。\nTP・スコア・解放・図鑑・セーブには反映されません。", 20)
	target = add_choice(stack, "練習対象")
	for i in DRONES.size():
		target.add_item("ドローン：" + NAMES[i])
		target.set_item_metadata(i, {"kind": "drone", "drone": DRONES[i], "stage": 1})
	for stage in range(1, 6):
		if Global.is_stage_cleared(stage):
			var index := target.item_count
			target.add_item("クリア済みボス：STAGE %d" % stage)
			target.set_item_metadata(index, {"kind": "boss", "stage": stage})
	repeat = add_choice(stack, "ドローンの出現")
	repeat.add_item("単発（1体）")
	repeat.add_item("無限補充（同時3体まで）")
	hp = add_choice(stack, "自機HP")
	hp.add_item("有限（被弾で練習終了）")
	hp.add_item("無限（被弾の反応は残す）")
	phase = add_choice(stack, "ボス攻撃段階 ／ ボスHPは無限")
	phase.add_item("通常")
	phase.add_item("激化（HP30%相当）")
	for i in target.item_count:
		var data: Dictionary = target.get_item_metadata(i)
		if data.get("kind") == remembered.get("kind") and data.get("drone", "") == remembered.get("drone", "") and data.get("stage") == remembered.get("stage"):
			target.select(i)
	repeat.select(1 if remembered.get("repeat", false) else 0)
	hp.select(1 if remembered.get("infinite_hp", false) else 0)
	phase.select(1 if remembered.get("intense", false) else 0)
	target.item_selected.connect(func(_index): update_choices())
	update_choices()
	add_text(stack, "移動・シールド・COUNTER・ポーズは本編と共通。\n内側のリングで捕獲すると精密追撃 ×1.25。\n砲台破壊とBREAKも練習できます。", 20)
	var start := Button.new()
	start.text = "練習開始"
	start.custom_minimum_size.y = 60
	stack.add_child(start)
	start.pressed.connect(start_practice)
	var back := Button.new()
	back.text = "オプションへ戻る"
	back.custom_minimum_size.y = 60
	stack.add_child(back)
	back.pressed.connect(func():
		Global.return_to_options = true
		get_tree().change_scene_to_file("res://game/core/main_menu.tscn")
	)

func add_text(stack: VBoxContainer, text: String, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	if font_size >= 32:
		label.add_theme_font_override("font", preload("res://game/assets/fonts/DotGothic16-Regular.ttf"))
	stack.add_child(label)

func add_choice(stack: VBoxContainer, text: String) -> OptionButton:
	add_text(stack, text, 22)
	var option := OptionButton.new()
	option.custom_minimum_size.y = 52
	stack.add_child(option)
	return option

func update_choices() -> void:
	var data: Dictionary = target.get_item_metadata(target.selected)
	repeat.disabled = data["kind"] == "boss"
	phase.disabled = data["kind"] != "boss"

func start_practice() -> void:
	var config: Dictionary = target.get_item_metadata(target.selected).duplicate(true)
	config.merge({"repeat": repeat.selected == 1, "infinite_hp": hp.selected == 1, "intense": phase.selected == 1})
	if Global.begin_practice(config):
		get_tree().change_scene_to_file("res://game/main.tscn")
