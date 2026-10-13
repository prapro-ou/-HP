extends Node
class_name CounterSystem

enum Phase { DISABLED, CHARGING, READY, ACTIVE, SPENT }
signal gauge_changed(value: float, ready: bool)
signal state_changed(phase: Phase)
signal counter_activated
signal counter_finished
@export_range(1.0, 100.0, 1.0) var gain_per_parry: float = 22.0
@export_range(1.0, 100.0, 1.0) var maximum: float = 100.0
var gauge: float = 0.0
var phase: Phase = Phase.DISABLED
var remaining: float = 0.0
var repeatable: bool = false

func reset_run() -> void:
	var was_active := phase == Phase.ACTIVE
	gauge = 0.0
	remaining = 0.0
	repeatable = false
	_set_phase(Phase.DISABLED)
	if was_active:
		counter_finished.emit()

func begin_battle(allow_repeat: bool = false) -> void:
	reset_run()
	repeatable = allow_repeat
	_set_phase(Phase.CHARGING)

func register_parry(streak: int = 1, gain_multiplier: float = 1.0) -> void:
	if phase != Phase.CHARGING:
		return
	var bonus := minf(maxi(streak - 1, 0) * 2.0, 8.0)
	gauge = minf(gauge + (gain_per_parry + bonus) * gain_multiplier, maximum)
	if gauge >= maximum:
		_set_phase(Phase.READY)
	else:
		gauge_changed.emit(gauge, false)

func is_ready() -> bool:
	return phase == Phase.READY

func try_activate(duration: float = 10.0) -> bool:
	if not is_ready() or duration <= 0.0:
		return false
	gauge = 0.0
	remaining = duration
	_set_phase(Phase.ACTIVE)
	counter_activated.emit()
	return true

func _process(delta: float) -> void:
	if phase != Phase.ACTIVE:
		return
	remaining = maxf(remaining - delta, 0.0)
	if remaining <= 0.0:
		_set_phase(Phase.CHARGING if repeatable else Phase.SPENT)
		counter_finished.emit()

func _set_phase(value: Phase) -> void:
	phase = value
	gauge_changed.emit(gauge, is_ready())
	state_changed.emit(phase)
