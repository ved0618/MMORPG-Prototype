extends Control

const MOVE_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]
const BUTTON_ACTIONS := ["attack", "teleport", "sprint", "esc"]
const CONTROL_NAMES := ["joystick", "attack", "teleport", "sprint", "esc"]
const LAYOUT_PATH := "user://mobile_control_layout.cfg"

var joystick_pointer: int = -1
var joystick_origin := Vector2.ZERO
var joystick_vector := Vector2.ZERO
var button_pointers: Dictionary = {}
var active_buttons: Dictionary = {}
var custom_positions: Dictionary = {}
var customize_mode := false
var dragging_control := ""
var done_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("mobile_controls")
	_load_layout()
	done_button = Button.new()
	done_button.text = "Done"
	done_button.position = Vector2(16, 16)
	done_button.size = Vector2(140, 56)
	done_button.visible = false
	done_button.mouse_filter = Control.MOUSE_FILTER_STOP
	done_button.pressed.connect(end_customize)
	add_child(done_button)
	queue_redraw()


func _exit_tree() -> void:
	_release_movement()
	for action in active_buttons.keys():
		Input.action_release(action)
	active_buttons.clear()
	button_pointers.clear()


func begin_customize() -> void:
	customize_mode = true
	get_tree().paused = false
	done_button.visible = true
	queue_redraw()


func end_customize() -> void:
	customize_mode = false
	dragging_control = ""
	done_button.visible = false
	_save_layout()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if get_tree().paused:
				return
			_handle_touch_pressed(event.index, event.position)
		else:
			_handle_touch_released(event.index)
	elif event is InputEventScreenDrag:
		if customize_mode and event.index == joystick_pointer:
			_set_custom_position(dragging_control, event.position)
		elif event.index == joystick_pointer:
			_update_joystick(event.position)
		elif customize_mode and button_pointers.has(event.index):
			_set_custom_position(button_pointers[event.index], event.position)


func _handle_touch_pressed(pointer: int, position: Vector2) -> void:
	if customize_mode:
		if done_button.get_global_rect().has_point(position):
			return
		dragging_control = _control_at(position)
		if not dragging_control.is_empty():
			if dragging_control == "joystick":
				joystick_pointer = pointer
			else:
				button_pointers[pointer] = dragging_control
			_set_custom_position(dragging_control, position)
		return

	var layout := _layout()
	var button_name := _button_at(position, layout)
	if not button_name.is_empty():
		button_pointers[pointer] = button_name
		_set_button(button_name, true)
		queue_redraw()
		return

	# A floating joystick starts wherever the player first touches the left half.
	if joystick_pointer == -1 and position.x < get_viewport_rect().size.x * 0.55:
		joystick_pointer = pointer
		joystick_origin = position
		_update_joystick(position)
		queue_redraw()


func _handle_touch_released(pointer: int) -> void:
	if pointer == joystick_pointer:
		joystick_pointer = -1
		joystick_vector = Vector2.ZERO
		_release_movement()
	if button_pointers.has(pointer):
		var button_name: String = button_pointers[pointer]
		button_pointers.erase(pointer)
		if not customize_mode:
			_set_button(button_name, false)
		if dragging_control == button_name:
			dragging_control = ""
	queue_redraw()


func _update_joystick(position: Vector2) -> void:
	var radius: float = _layout().joystick_radius
	var offset: Vector2 = position - joystick_origin
	joystick_vector = offset.limit_length(radius) / radius
	if joystick_vector.length() < 0.28:
		joystick_vector = Vector2.ZERO
	else:
		joystick_vector = joystick_vector.normalized()
	_set_action("move_left", joystick_vector.x < -0.35)
	_set_action("move_right", joystick_vector.x > 0.35)
	_set_action("move_up", joystick_vector.y < -0.35)
	_set_action("move_down", joystick_vector.y > 0.35)
	queue_redraw()


func _release_movement() -> void:
	for action in MOVE_ACTIONS:
		Input.action_release(action)


func _set_action(action: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _set_button(button_name: String, pressed: bool) -> void:
	if pressed:
		active_buttons[button_name] = true
		Input.action_press(button_name)
		if button_name == "esc":
			var pause_controller := get_tree().get_first_node_in_group("pause_controller")
			if pause_controller:
				pause_controller.open_pause_menu()
	else:
		active_buttons.erase(button_name)
		Input.action_release(button_name)
	queue_redraw()


func _button_at(position: Vector2, layout: Dictionary) -> String:
	for button_name in BUTTON_ACTIONS:
		if position.distance_to(layout[button_name]) <= layout.button_radius:
			return button_name
	return ""


func _control_at(position: Vector2) -> String:
	var layout := _layout()
	for control_name in CONTROL_NAMES:
		var radius: float = layout.joystick_radius if control_name == "joystick" else layout.button_radius
		if position.distance_to(layout[control_name]) <= radius * 1.35:
			return control_name
	return ""


func _set_custom_position(control_name: String, position: Vector2) -> void:
	if control_name.is_empty():
		return
	var view_size := get_viewport_rect().size
	custom_positions[control_name] = Vector2(
		clampf(position.x / view_size.x, 0.05, 0.95),
		clampf(position.y / view_size.y, 0.08, 0.92)
	)
	queue_redraw()


func _layout() -> Dictionary:
	var view_size := get_viewport_rect().size
	var scale_factor := clampf(minf(view_size.x, view_size.y) / 720.0, 0.65, 1.15)
	var margin := 28.0 * scale_factor
	var button_radius := 46.0 * scale_factor
	var joystick := Vector2(margin + 78.0 * scale_factor, view_size.y - margin - 78.0 * scale_factor)
	var positions := {
		"joystick": joystick,
		"attack": Vector2(view_size.x - margin - 76.0 * scale_factor, view_size.y - margin - 78.0 * scale_factor),
		"teleport": Vector2(view_size.x - margin - 178.0 * scale_factor, view_size.y - margin - 42.0 * scale_factor),
		"sprint": Vector2(view_size.x - margin - 45.0 * scale_factor, view_size.y - margin - 190.0 * scale_factor),
		"esc": Vector2(margin + 44.0 * scale_factor, view_size.y * 0.5),
	}
	for name in custom_positions:
		positions[name] = Vector2(custom_positions[name]) * view_size
	return {
		"joystick": positions.joystick,
		"joystick_radius": 72.0 * scale_factor,
		"attack": positions.attack,
		"teleport": positions.teleport,
		"sprint": positions.sprint,
		"esc": positions.esc,
		"button_radius": button_radius,
	}


func _load_layout() -> void:
	var config := ConfigFile.new()
	if config.load(LAYOUT_PATH) != OK:
		return
	for control_name in CONTROL_NAMES:
		if config.has_section_key("controls", control_name):
			custom_positions[control_name] = config.get_value("controls", control_name)


func _save_layout() -> void:
	var config := ConfigFile.new()
	for control_name in custom_positions:
		config.set_value("controls", control_name, custom_positions[control_name])
	config.save(LAYOUT_PATH)


func _draw() -> void:
	var layout := _layout()
	var stick_center: Vector2 = joystick_origin if joystick_pointer != -1 and not customize_mode else layout.joystick
	var radius: float = layout.joystick_radius
	_draw_pad(stick_center, radius, "MOVE", joystick_pointer != -1)
	if joystick_pointer != -1 and not customize_mode:
		draw_circle(stick_center + joystick_vector * radius * 0.58, radius * 0.28, Color(1, 1, 1, 0.38))
	_draw_button(layout.attack, layout.button_radius, "ATTACK", active_buttons.has("attack"))
	_draw_button(layout.teleport, layout.button_radius, "BLINK", active_buttons.has("teleport"))
	_draw_button(layout.sprint, layout.button_radius, "RUN", active_buttons.has("sprint"))
	_draw_button(layout.esc, layout.button_radius, "MENU", active_buttons.has("esc"))
	if customize_mode:
		_draw_label(Vector2(get_viewport_rect().size.x * 0.5, 48), "DRAG BUTTONS TO MOVE THEM", 18)


func _draw_pad(center: Vector2, radius: float, label: String, active: bool) -> void:
	draw_circle(center, radius, Color(0.06, 0.08, 0.11, 0.48 if active else 0.34))
	draw_arc(center, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.68), 3.0)
	draw_circle(center, radius * 0.37, Color(1, 1, 1, 0.18))
	_draw_label(center, label, 17)


func _draw_button(center: Vector2, radius: float, label: String, active: bool) -> void:
	draw_circle(center, radius, Color(0.12, 0.15, 0.2, 0.76 if active else 0.52))
	draw_arc(center, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.82), 3.0)
	_draw_label(center, label, 15)


func _draw_label(center: Vector2, label: String, font_size: int) -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center - Vector2(text_size.x, -font_size * 0.35) / 2.0, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
