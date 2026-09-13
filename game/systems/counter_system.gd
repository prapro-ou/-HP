extends Node
class_name CounterSystem

signal gauge_changed(value: float, ready: bool)
signal counter_activated

@export_range(1.0, 100.0, 1.0) var gain_per_parry: float = 22.0
@export_range(1.0, 100.0, 1.0) var maximum: float = 100.0

var gauge: float = 0.0


func reset_run() -> void:
	gauge = 0.0
	gauge_changed.emit(gauge, false)


func register_parry(streak: int = 1) -> void:
	var rhythm_bonus := minf(maxi(streak - 1, 0) * 2.0, 8.0)
	gauge = minf(gauge + gain_per_parry + rhythm_bonus, maximum)
	gauge_changed.emit(gauge, is_ready())


func is_ready() -> bool:
	return gauge >= maximum


func try_activate() -> bool:
	if not is_ready():
		return false
	gauge = 0.0
	gauge_changed.emit(gauge, false)
	counter_activated.emit()
	return true
