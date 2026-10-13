extends PanelContainer
class_name PauseSettingsPanel

@onready var display_mode: OptionButton = %DisplayMode
@onready var window_scale: OptionButton = %WindowScale
@onready var aspect_ratio: OptionButton = %AspectRatio
@onready var vsync_toggle: CheckButton = %VSyncToggle
@onready var shake_toggle: CheckButton = %ShakeToggle
@onready var move_preset: OptionButton = %MovePreset
@onready var master_slider: HSlider = %MasterSlider
@onready var master_value: Label = %MasterValue
@onready var bgm_slider: HSlider = %BgmSlider
@onready var bgm_value: Label = %BgmValue
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_value: Label = %SfxValue

const SCALE_VALUES: Array[float] = [0.5, 0.75, 1.0, 1.25]
var scale_choices: Array[float] = []
var syncing: bool = false
var settings: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings = get_node("/root/Global")
	_populate_options()
	_connect_controls()
	sync_from_global()
	settings.apply_body_font(self)


func _populate_options() -> void:
	display_mode.clear()
	display_mode.add_item("ウィンドウ")
	display_mode.add_item("フルスクリーン")
	display_mode.add_item("ボーダーレス")
	_populate_scales()
	aspect_ratio.clear()
	aspect_ratio.add_item("2:3")
	aspect_ratio.add_item("3:4")
	aspect_ratio.add_item("9:16")
	move_preset.clear()
	move_preset.add_item("WASD + 矢印")
	move_preset.add_item("WASD")
	move_preset.add_item("矢印キー")
	move_preset.add_item("カスタム")


func _connect_controls() -> void:
	display_mode.item_selected.connect(_on_display_mode_selected)
	window_scale.item_selected.connect(_on_window_scale_selected)
	aspect_ratio.item_selected.connect(_on_aspect_ratio_selected)
	vsync_toggle.toggled.connect(_on_vsync_toggled)
	shake_toggle.toggled.connect(_on_shake_toggled)
	move_preset.item_selected.connect(_on_move_preset_selected)
	master_slider.value_changed.connect(_on_master_changed)
	bgm_slider.value_changed.connect(_on_bgm_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)


func sync_from_global() -> void:
	syncing = true
	display_mode.select(clampi(settings.window_mode, 0, 2))
	_populate_scales()
	window_scale.disabled = settings.window_mode == 1
	aspect_ratio.select(clampi(settings.aspect_ratio, 0, 2))
	aspect_ratio.disabled = settings.window_mode == 1
	vsync_toggle.button_pressed = settings.vsync
	shake_toggle.button_pressed = settings.screen_shake
	move_preset.select(clampi(settings.control_move_preset, 0, 3))
	master_slider.value = settings.master_volume
	bgm_slider.value = settings.bgm_volume
	sfx_slider.value = settings.sfx_volume
	_update_volume_labels()
	syncing = false


func _on_display_mode_selected(index: int) -> void:
	if syncing:
		return
	settings.window_mode = index
	window_scale.disabled = index == 1
	aspect_ratio.disabled = index == 1
	_apply_display_and_save()


func _on_window_scale_selected(index: int) -> void:
	if syncing:
		return
	settings.window_scale = scale_choices[clampi(index, 0, scale_choices.size() - 1)]
	_apply_display_and_save()


func _on_aspect_ratio_selected(index: int) -> void:
	if syncing:
		return
	settings.aspect_ratio = index
	_apply_display_and_save()


func _on_vsync_toggled(enabled: bool) -> void:
	if syncing:
		return
	settings.vsync = enabled
	_apply_display_and_save()


func _on_shake_toggled(enabled: bool) -> void:
	if syncing:
		return
	settings.screen_shake = enabled
	settings.save_settings()


func _on_move_preset_selected(index: int) -> void:
	if syncing:
		return
	settings.control_move_preset = index
	settings.save_settings()


func _on_master_changed(value: float) -> void:
	if syncing:
		return
	settings.master_volume = value
	_apply_audio_and_save()


func _on_bgm_changed(value: float) -> void:
	if syncing:
		return
	settings.bgm_volume = value
	_apply_audio_and_save()


func _on_sfx_changed(value: float) -> void:
	if syncing:
		return
	settings.sfx_volume = value
	_apply_audio_and_save()


func _apply_display_and_save() -> void:
	settings.apply_display()
	settings.save_settings()


func _apply_audio_and_save() -> void:
	_update_volume_labels()
	settings.apply_audio()
	settings.save_settings()


func _update_volume_labels() -> void:
	master_value.text = "%d%%" % int(master_slider.value)
	bgm_value.text = "%d%%" % int(bgm_slider.value)
	sfx_value.text = "%d%%" % int(sfx_slider.value)

func _populate_scales() -> void:
	scale_choices = settings.get_window_scale_choices()
	window_scale.clear()
	for i in scale_choices.size():
		window_scale.add_item("%d%%" % roundi(scale_choices[i] * 100.0))
		if is_equal_approx(scale_choices[i], settings.window_scale): window_scale.select(i)
