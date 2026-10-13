extends Node
class_name AnalysisSystem

signal progress_changed(weapon_id: StringName, progress: float)
signal analysis_completed(weapon: AnalysisWeapon)
signal level_changed(weapon_id: StringName, level: int)

@export var weapons: Array[AnalysisWeapon] = WeaponCatalog.analysis_weapons()
@export_range(1.0, 100.0, 1.0) var base_gain: float = 24.0
const MAX_LEVEL: int = 5
var progress: Dictionary = {}
var levels: Dictionary = {}
var completed: Array[StringName] = []
var selected: Array[StringName] = []
var available_ids: Array[StringName] = []

func _ready() -> void:
	reset_run()

func reset_run() -> void:
	progress.clear()
	levels.clear()
	completed.clear()
	selected.clear()
	available_ids.clear()
	for weapon in weapons:
		progress[weapon.id] = 0.0
		levels[weapon.id] = 0

func configure_bullets(bullet_types: Array[String]) -> void:
	available_ids.clear()
	for weapon in weapons:
		for bullet_type in bullet_types:
			if weapon.matches_bullet(bullet_type):
				available_ids.append(weapon.id)
				break

func register_parry(bullet_type: String, streak: int = 1, gain_multiplier: float = 1.0) -> void:
	var weapon := get_weapon_for_bullet(bullet_type)
	var bonus := minf(maxi(streak - 1, 0) * 2.0, 8.0)
	if not selected.is_empty():
		# Boss parries strengthen only the two locked mutations.
		for weapon_id in selected:
			var matching := weapon != null and weapon.id == weapon_id
			_gain_level_progress(weapon_id, (12.0 + bonus) * gain_multiplier * (1.0 if matching else 0.35))
		return
	if weapon == null or completed.has(weapon.id):
		return
	if not available_ids.is_empty() and not available_ids.has(weapon.id):
		return
	var value := minf(float(progress.get(weapon.id, 0.0)) + (base_gain + bonus) * gain_multiplier, 100.0)
	progress[weapon.id] = value
	if value >= 100.0:
		completed.append(weapon.id)
	progress_changed.emit(weapon.id, value)
	if value >= 100.0:
		analysis_completed.emit(weapon)

func _gain_level_progress(weapon_id: StringName, amount: float) -> void:
	if int(levels.get(weapon_id, 0)) >= MAX_LEVEL:
		return
	var value := float(progress.get(weapon_id, 0.0)) + amount
	if value >= 100.0:
		levels[weapon_id] = int(levels[weapon_id]) + 1
		value = 0.0
		level_changed.emit(weapon_id, int(levels[weapon_id]))
	progress[weapon_id] = value
	progress_changed.emit(weapon_id, value)

func get_weapon_for_bullet(bullet_type: String) -> AnalysisWeapon:
	for weapon in weapons:
		if weapon.matches_bullet(bullet_type):
			return weapon
	return null

func get_completed_weapons() -> Array[AnalysisWeapon]:
	var result: Array[AnalysisWeapon] = []
	for weapon in weapons:
		if completed.has(weapon.id):
			result.append(weapon)
	return result

func ensure_minimum_choices(count: int) -> Array[AnalysisWeapon]:
	var candidates: Array[AnalysisWeapon] = []
	for weapon in weapons:
		if available_ids.is_empty() or available_ids.has(weapon.id):
			candidates.append(weapon)
	while completed.size() < mini(count, candidates.size()):
		var best: AnalysisWeapon = null
		var best_progress := -1.0
		for weapon in candidates:
			if not completed.has(weapon.id) and float(progress.get(weapon.id, 0.0)) > best_progress:
				best = weapon
				best_progress = float(progress.get(weapon.id, 0.0))
		if best == null:
			break
		progress[best.id] = 100.0
		completed.append(best.id)
		progress_changed.emit(best.id, 100.0)
		analysis_completed.emit(best)
	return get_completed_weapons()

func lock_loadout(ids: Array[StringName]) -> bool:
	if not selected.is_empty() or ids.size() != 2 or ids[0] == ids[1]:
		return false
	for weapon_id in ids:
		if not completed.has(weapon_id):
			return false
	selected.assign(ids)
	for weapon_id in selected:
		levels[weapon_id] = 1
		progress[weapon_id] = 0.0
		level_changed.emit(weapon_id, 1)
		progress_changed.emit(weapon_id, 0.0)
	return true
