extends SceneTree
const OUTPUT := "res://rendered_responsive_ui"
var globals: Node
var debug: Node
var selection: Node
var render_enabled: bool
var image_count: int = 0

func _init() -> void:
	call_deferred("run")

func settle() -> void:
	for frame in 4: await process_frame

func set_size(width: int) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(width, 1200)
	root.size = Vector2i(width, 1200)
	await settle()

func show_scene(path: String, width: int) -> Node:
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	var scene = load(path).instantiate()
	root.add_child(scene)
	current_scene = scene
	await set_size(width)
	return scene

func screen_rect(control: Control) -> Rect2:
	return control.get_global_transform() * Rect2(Vector2.ZERO, control.size)

func inside(control: Control) -> void:
	var box := screen_rect(control)
	var viewport := Rect2(Vector2.ZERO, Vector2(root.content_scale_size)).grow(0.6)
	assert(viewport.encloses(box), "%s is outside the viewport: %s" % [control.name, box])

func inside_scroll(control: Control, scroll: ScrollContainer) -> void:
	assert(screen_rect(scroll).grow(0.6).encloses(screen_rect(control)), "Scrolled control is clipped: %s" % screen_rect(control))

func wheel_down(scroll: ScrollContainer) -> void:
	var before := scroll.scroll_vertical
	var point := screen_rect(scroll).get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()
	assert(scroll.scroll_vertical > before, "Mouse wheel must scroll the visible pane")

func capture(label: String, width: int) -> void:
	if not render_enabled: return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT + "/%s_%d.png" % [label, width]) == OK)
	image_count += 1

func click(control: Control) -> void:
	inside(control)
	var point := screen_rect(control).get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()

func check_selection() -> void:
	for control in [selection.detail_panel, selection.detail_title, selection.detail_codename, selection.detail_desc, selection.detail_diff, selection.menu_btn, selection.archive_btn, selection.tech_lab_btn, selection.select_btn, selection.prev_btn, selection.next_btn, selection.hard_mode_btn, selection.tips_btn]:
		inside(control)
	assert(selection.detail_panel.size.x <= root.content_scale_size.x * 0.92 + 1.0)
	assert(selection.detail_panel.get_global_rect().end.y <= 696.5)
	assert(selection.select_btn.get_theme_stylebox("focus").border_color == Color.WHITE)
	inside_scroll(selection.stage_cards[selection.current_index], selection.stage_container.get_parent().get_parent())
	print("RESPONSIVE_BOUNDS_CHECK width=", root.content_scale_size.x, " stage=", selection.current_index + 1, " hard=", globals.hard_mode_enabled, " panel=", selection.detail_panel.get_global_rect())

func run() -> void:
	globals = root.get_node("Global")
	debug = root.get_node("DebugTools")
	assert(globals.SAVE_PATH == "res://verification_save.cfg" and globals.SETTINGS_PATH == "res://verification_settings.cfg")
	render_enabled = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	assert(debug.begin_session() and debug.unlock_all())
	globals.cleared_stages = [1, 2, 3, 4, 5]
	globals.discovered_analysis_weapons.assign(globals.analysis_catalog.keys())
	globals.unlocked_tips.clear()
	for tip in globals.tips_catalog: globals.unlocked_tips.append(tip.id)
	globals.unread_tips.assign(globals.unlocked_tips)
	for width in [675, 800, 900]:
		selection = await show_scene("res://game/core/stage_selection.tscn", width)
		for hard in [false, true]:
			globals.hard_mode_enabled = hard
			for index in 5:
				selection.current_index = index
				selection.update_stage_selection(true)
				selection.select_btn.grab_focus()
				await settle()
				check_selection()
				assert(not selection.select_btn.disabled)
				await capture("stage%d_%s" % [index + 1, "hard" if hard else "normal"], width)
		await click(selection.prev_btn)
		await create_timer(0.3, false).timeout
		assert(selection.current_index == 3)
		check_selection()
		await click(selection.next_btn)
		await create_timer(0.3, false).timeout
		assert(selection.current_index == 4)
		check_selection()
		globals.unlocked_stages = [1]
		globals.cleared_stages = []
		selection.current_index = 4
		selection.update_stage_selection(true)
		await settle()
		check_selection()
		assert(selection.select_btn.disabled)
		await click(selection.select_btn)
		assert(current_scene == selection)
		await capture("locked", width)
		globals.unlocked_stages = [1, 2, 3, 4, 5]
		globals.cleared_stages = [1, 2, 3, 4, 5]
		selection.update_stage_selection(true)
		await click(selection.archive_btn)
		await create_timer(0.23, false).timeout
		inside(selection.archive_panel)
		var archive_close = selection.archive_panel.find_children("*", "Button", true, false)[0]
		inside(archive_close)
		await capture("archive", width)
		var archive_scroll = selection.archive_cards_container.get_parent()
		await wheel_down(archive_scroll)
		archive_scroll.scroll_vertical = int(archive_scroll.get_v_scroll_bar().max_value)
		await settle()
		inside_scroll(selection.archive_cards_container.get_children().back(), archive_scroll)
		await capture("archive_end", width)
		await click(archive_close)
		await create_timer(0.2, false).timeout
		assert(not selection.archive_panel.visible)
		await click(selection.tips_btn)
		await create_timer(0.23, false).timeout
		inside(selection.tips_panel)
		var tips_close = selection.tips_panel.find_children("*", "Button", true, false).filter(func(button): return button.text == "TIPSを閉じる")[0]
		inside(tips_close)
		for category in globals.tips_categories:
			var button = selection.tips_category_buttons[category]
			var cat_scroll = button.get_parent().get_parent()
			cat_scroll.ensure_control_visible(button)
			await settle()
			await click(button)
			assert(selection.tips_filter_category == category)
			inside(selection.tips_detail_panel)
			inside(selection.tips_left_scroll)
			inside(tips_close)
		# Empty category stays wrapped; then actual list-card input switches the detail.
		globals.unlocked_tips = ["tip_move"]
		selection.tips_filter_category = "boss"
		selection.update_tips_ui()
		await settle()
		inside(selection.tips_panel)
		await capture("tips_empty", width)
		globals.unlocked_tips.clear()
		var longest: Dictionary = {}
		for tip in globals.tips_catalog:
			globals.unlocked_tips.append(tip.id)
			if longest.is_empty() or tip.desc.length() > longest.desc.length(): longest = tip
		selection.tips_filter_category = "all"
		selection.selected_tip_id = "tip_move"
		selection.update_tips_ui()
		await settle()
		var card = selection.tips_list_container.get_child(2)
		selection.tips_left_scroll.ensure_control_visible(card)
		await settle()
		await click(card)
		assert(selection.selected_tip_id == "tip_wave_route")
		await capture("tips_route", width)
		selection.selected_tip_id = longest.id
		selection.update_tips_ui()
		await settle()
		inside(selection.tips_panel)
		inside(tips_close)
		await capture("tips_longest", width)
		selection.tips_detail_scroll.scroll_vertical = int(selection.tips_detail_scroll.get_v_scroll_bar().max_value)
		await settle()
		await capture("tips_longest_end", width)
		# Test overflow with a fixture; the production catalog remains unchanged.
		var stress_tip := longest.duplicate(true)
		stress_tip.desc = (longest.desc + "\n").repeat(18)
		stress_tip.hint = "長文末尾の操作説明もスクロールで確認できます。"
		selection.render_tip_detail(stress_tip)
		await settle()
		var detail_bar = selection.tips_detail_scroll.get_v_scroll_bar()
		assert(detail_bar.max_value > detail_bar.page)
		await wheel_down(selection.tips_detail_scroll)
		await capture("tips_scroll_stress", width)
		selection.tips_detail_scroll.scroll_vertical = int(detail_bar.max_value)
		await settle()
		var detail_box = selection.tips_detail_scroll.get_child(0).get_child(0)
		inside_scroll(detail_box.get_children().back(), selection.tips_detail_scroll)
		await capture("tips_scroll_stress_end", width)
		# Resizing the same open panel must recalculate the two columns, not require reopening.
		for changed_width in [900, 675, 800, width]:
			await set_size(changed_width)
			inside(selection.tips_panel)
			inside(selection.tips_left_scroll)
			inside(selection.tips_detail_panel)
			inside(tips_close)
			check_selection()
		await click(tips_close)
		await create_timer(0.2, false).timeout
		assert(not selection.tips_panel.visible)
		# Test real screen input for all navigation destinations.
		for destination in ["menu", "lab", "loadout"]:
			selection = await show_scene("res://game/core/stage_selection.tscn", width)
			var button = selection.menu_btn if destination == "menu" else selection.tech_lab_btn if destination == "lab" else selection.select_btn
			await click(button)
			await create_timer(0.4, false).timeout
			assert(current_scene.has_method("sync_settings_to_ui") if destination == "menu" else current_scene.has_method("update_lab_hud") if destination == "lab" else current_scene.has_method("show_details"))
		print("RESPONSIVE_ACTIONS_CHECK width=", width, " arrows/archive/categories/cards/wheel/close/resize/back/lab/deploy")
	debug.end_session()
	await settle()
	# Actual reset confirmation and locked-file failure, outside debug, at all three widths.
	for width in [675, 800, 900]:
		globals.tech_points = 123
		globals.save_game(3, 456)
		var menu = await show_scene("res://game/core/main_menu.tscn", width)
		menu._on_settings_pressed()
		menu._on_reset_btn_pressed()
		await create_timer(0.3, false).timeout
		inside(menu.confirm_dialog)
		for button in menu.confirm_dialog.find_children("*", "Button", true, false): inside(button)
		await capture("reset_confirm", width)
		var held_save = FileAccess.open(globals.SAVE_PATH, FileAccess.READ)
		var delete_button = menu.confirm_dialog.find_children("*", "Button", true, false)[0]
		await click(delete_button)
		await settle()
		assert(menu.reset_notice.visible and globals.tech_points == 123)
		inside(menu.reset_notice)
		inside(menu.confirm_dialog)
		await capture("reset_failure", width)
		held_save.close()
		await click(delete_button)
		assert(not globals.has_save and not menu.confirm_dialog.visible)
		var settings_back = menu.settings_container.find_children("*", "Button", true, false).filter(func(button): return button.text == "保存して戻る")[0]
		await click(settings_back)
		await create_timer(0.3, false).timeout
		assert(menu.play_start_btn.is_visible_in_tree())
		await click(menu.play_start_btn)
		await create_timer(0.3, false).timeout
		inside(menu.tutorial_dialog)
		for button in menu.tutorial_dialog.find_children("*", "Button", true, false): inside(button)
		await capture("first_launch", width)
	print("RESPONSIVE_UI_TEST_OK: viewport bounds and actual input, five stages NORMAL/HARD/locked, all categories, card selection, independent scroll, open-panel resizing, routes, reset confirmation/failure; images=", image_count)
	quit(0)
