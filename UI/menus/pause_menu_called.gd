extends Camera2D

const MapDataScript := preload("res://Scripts/map_data.gd")

var pause_menu_scene = preload("res://UI/menus/pause_menu.tscn")
var pause_menu = null


func _ready() -> void:
	limit_smoothed = true


func _process(_delta: float) -> void:
	_update_limits()


func _update_limits() -> void:
	"""Keep the camera locked to the current map's bounds."""
	var map_manager = get_tree().current_scene.get_node_or_null("Maps")
	if not map_manager:
		return

	var map_node = map_manager.get_current_map()
	if not map_node:
		return

	var center: Vector2 = map_node.global_position
	var half_w := MapDataScript.MAP_WIDTH / 2.0
	var half_h := MapDataScript.MAP_HEIGHT / 2.0

	limit_left   = int(center.x - half_w)
	limit_top    = int(center.y - half_h)
	limit_right  = int(center.x + half_w)
	limit_bottom = int(center.y + half_h)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		if pause_menu == null:
			pause_menu = pause_menu_scene.instantiate()
			add_child(pause_menu)
