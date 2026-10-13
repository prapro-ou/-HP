extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var debug = root.get_node("DebugTools")
	var expected: bool = "allowed" in OS.get_cmdline_user_args()
	if debug.is_allowed() != expected or debug.is_active():
		push_error("Unexpected debug build permission/default")
		quit(1)
		return
	var menu = load("res://game/core/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	if (menu.find_child("DevelopmentEntry", true, false) != null) != expected:
		push_error("Unexpected development menu entry")
		quit(1)
		return
	if not expected:
		debug.active = true # A state flag alone must never grant build permission.
		if debug.begin_session() or debug.open_panel() or debug.add_tp() or debug.unlock_all() or debug.set_infinite_hp(true) or debug.jump_to_boss() or debug.fill_counter() or debug.reset_temporary_data("tp") or debug.canvas != null:
			push_error("A forbidden debug operation succeeded")
			quit(1)
			return
		debug.active = false
	var lab = load("res://game/core/tech_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	var original_tp: int = root.get_node("Global").tech_points
	if not expected: debug.active = true
	lab._on_demo_pressed()
	if lab.demo_btn.visible or root.get_node("Global").tech_points != original_tp:
		push_error("Legacy test TP escaped the debug build/session guard")
		quit(1)
		return
	debug.active = false
	lab.queue_free()
	if expected:
		if not debug.open_panel() or not paused or not debug.begin_session() or not debug.add_tp():
			push_error("An allowed debug operation failed")
			quit(1)
			return
		debug.close_panel()
		debug.end_session()
		await process_frame
		await process_frame
	print("DEBUG_BUILD_GATE_TEST_OK ", JSON.stringify({"allowed": debug.is_allowed(), "debug": OS.has_feature("debug"), "editor": OS.has_feature("editor"), "counter_debug": OS.has_feature("counter_debug")}))
	quit(0)
