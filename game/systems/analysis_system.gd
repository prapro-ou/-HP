extends Node
class_name AnalysisSystem

signal progress_changed(weapon_id: StringName, progress: float)
signal analysis_completed(weapon: AnalysisWeapon)

@export var weapons: Array[AnalysisWeapon] = [
	preload("res://game/data/analysis/rapid.tres"),
	preload("res://game/data/analysis/spread.tres"),
	preload("res://game/data/analysis/pierce.tres"),
]
@export_range(1.0, 100.0, 1.0) var base_gain: float = 24.0

var progress: Dictionary = {}
var completed: Array[StringName] = []


func _ready() -> void:
	reset_run()


func reset_run() -> void:
	progress.clear()
	completed.clear()
	for weapon in weapons:
		progress[weapon.id] = 0.0


func register_parry(bullet_type: String, streak: int = 1) -> void:
	var weapon := get_weapon_for_bullet(bullet_type)
	if weapon == null or completed.has(weapon.id):
		return
	# Consecutive precision is rewarded, but four ordinary parries still complete an analysis.
	var streak_bonus := minf(maxi(streak - 1, 0) * 2.0, 8.0)
	var next_value := minf(float(progress.get(weapon.id, 0.0)) + base_gain + streak_bonus, 100.0)
	progress[weapon.id] = next_value
	progress_changed.emit(weapon.id, next_value)
	if next_value >= 100.0:
		completed.append(weapon.id)
		analysis_completed.emit(weapon)


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
	# The prototype must always reach the loadout decision. Near-complete scans are
	# decoded at the gate instead of turning one weak wave into a dead run.
	while completed.size() < mini(count, weapons.size()):
		var best: AnalysisWeapon = null
		var best_progress := -1.0
		for weapon in weapons:
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
