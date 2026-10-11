extends Control

var pause_toggle = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var customize_button := Button.new()
	customize_button.name = "CustomizeControls"
	customize_button.text = "Customize Controls"
	customize_button.position = Vector2(get_viewport_rect().size.x * 0.5 - 110.0, get_viewport_rect().size.y * 0.5 + 115.0)
	customize_button.size = Vector2(220.0, 56.0)
	customize_button.pressed.connect(_on_customize_controls_pressed)
	add_child(customize_button)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		print("esc")
		pass


func _on_resume_pressed():
	get_tree().paused = false
	var pause_controller := get_tree().get_first_node_in_group("pause_controller")
	if pause_controller:
		pause_controller.pause_menu = null
	queue_free()

func _on_exit_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/menus/main_menu.tscn")

func _on_customize_controls_pressed() -> void:
	var controls := get_tree().get_first_node_in_group("mobile_controls")
	if controls:
		var pause_controller := get_tree().get_first_node_in_group("pause_controller")
		if pause_controller:
			pause_controller.pause_menu = null
		controls.begin_customize()
		queue_free()
