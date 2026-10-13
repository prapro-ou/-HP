extends CanvasLayer
class_name LoadoutDraft

signal loadout_confirmed(selected_ids: Array[StringName])
@onready var card_container: GridContainer = %Cards
@onready var confirm_button: Button = %ConfirmButton
@onready var selection_label: Label = %SelectionLabel
var cards: Array[Button] = []
var available: Dictionary = {}
var selected: Array[StringName] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	confirm_button.pressed.connect(_on_confirm_pressed)
	hide_draft()

func show_draft(weapons: Array[AnalysisWeapon]) -> void:
	available.clear()
	selected.clear()
	cards.clear()
	for child in card_container.get_children():
		card_container.remove_child(child)
		child.queue_free()
	for weapon in weapons:
		available[weapon.id] = weapon
		var card := Button.new()
		card.toggle_mode = true
		card.custom_minimum_size = Vector2(0, 105)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.text = weapon.display_name + "\n" + weapon.description
		card.set_meta("weapon_id", weapon.id)
		card.add_theme_color_override("font_color", weapon.color)
		card.toggled.connect(_on_card_toggled.bind(card))
		card_container.add_child(card)
		cards.append(card)
	visible = true
	_update_status()
	if not cards.is_empty():
		cards[0].grab_focus()

func hide_draft() -> void:
	visible = false

func _on_card_toggled(pressed: bool, card: Button) -> void:
	var weapon_id := StringName(card.get_meta("weapon_id"))
	if pressed:
		if selected.size() >= 2 or not available.has(weapon_id):
			card.set_pressed_no_signal(false)
			return
		if not selected.has(weapon_id):
			selected.append(weapon_id)
	else:
		selected.erase(weapon_id)
	_update_status()

func _update_status() -> void:
	selection_label.text = "装着スロット  %d / 2" % selected.size()
	confirm_button.disabled = selected.size() != 2

func _on_confirm_pressed() -> void:
	if selected.size() != 2:
		return
	visible = false
	loadout_confirmed.emit(selected.duplicate())
