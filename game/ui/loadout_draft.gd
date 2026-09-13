extends CanvasLayer
class_name LoadoutDraft

signal loadout_confirmed(selected_ids: Array[StringName])

@onready var cards: Array[Button] = [%RapidCard, %SpreadCard, %PierceCard]
@onready var confirm_button: Button = %ConfirmButton
@onready var selection_label: Label = %SelectionLabel

var available: Dictionary = {}
var selected: Array[StringName] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for card in cards:
		card.toggled.connect(_on_card_toggled.bind(card))
	confirm_button.pressed.connect(_on_confirm_pressed)
	hide_draft()


func show_draft(weapons: Array[AnalysisWeapon]) -> void:
	available.clear()
	selected.clear()
	for weapon in weapons:
		available[weapon.id] = weapon
	for card in cards:
		var weapon_id := StringName(card.get_meta("weapon_id"))
		card.disabled = not available.has(weapon_id)
		card.button_pressed = false
		card.modulate.a = 1.0 if available.has(weapon_id) else 0.32
	visible = true
	_update_status()


func hide_draft() -> void:
	visible = false


func _on_card_toggled(pressed: bool, card: Button) -> void:
	var weapon_id := StringName(card.get_meta("weapon_id"))
	if pressed:
		if selected.size() >= 2:
			card.set_pressed_no_signal(false)
			return
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
