extends Control

var pause_toggle = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		print("esc")
		pass


func _on_resume_pressed():
	get_tree().paused = false
	queue_free()

func _on_exit_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/menus/main_menu.tscn")
