extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var settings := root.get_node_or_null("Global")
	if settings == null:
		settings = load("res://game/core/global.gd").new()
		settings.name = "Global"
		root.add_child(settings)
	var original_mode: int = settings.window_mode
	var original_scale: float = settings.window_scale
	var original_aspect: int = settings.aspect_ratio
	var original_vsync: bool = settings.vsync
	var original_shake: bool = settings.screen_shake
	var original_preset: int = settings.control_move_preset
	var original_master: float = settings.master_volume
	var original_bgm: float = settings.bgm_volume
	var original_sfx: float = settings.sfx_volume

	settings.window_mode = 0
	settings.window_scale = 0.75
	settings.aspect_ratio = 2
	settings.vsync = false
	settings.screen_shake = false
	settings.control_move_preset = 2
	settings.master_volume = 61.0
	settings.bgm_volume = 52.0
	settings.sfx_volume = 43.0

	var scene := load("res://game/ui/components/pause_settings_panel.tscn") as PackedScene
	assert(scene != null, "Pause settings scene must load")
	var panel := scene.instantiate() as PauseSettingsPanel
	root.add_child(panel)
	await process_frame
	assert(panel.display_mode.item_count == 3)
	assert(panel.window_scale.item_count == 4)
	assert(panel.aspect_ratio.item_count == 3)
	assert(panel.move_preset.item_count == 4)
	assert(panel.window_scale.selected == 1)
	assert(panel.aspect_ratio.selected == 2)
	assert(panel.move_preset.selected == 2)
	assert(panel.master_value.text == "61%")
	assert(panel.bgm_value.text == "52%")
	assert(panel.sfx_value.text == "43%")
	assert(panel.process_mode == Node.PROCESS_MODE_ALWAYS)

	settings.window_mode = original_mode
	settings.window_scale = original_scale
	settings.aspect_ratio = original_aspect
	settings.vsync = original_vsync
	settings.screen_shake = original_shake
	settings.control_move_preset = original_preset
	settings.master_volume = original_master
	settings.bgm_volume = original_bgm
	settings.sfx_volume = original_sfx
	print("PAUSE_SETTINGS_TEST_OK")
	quit(0)
