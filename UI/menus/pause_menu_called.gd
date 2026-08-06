extends Node2D

var pause_menu_scene = preload("res://UI/menus/pause_menu.tscn")
var pause_menu = null

func _input(event):
	if event.is_action_pressed("esc"):
		if pause_menu == null:
			pause_menu = pause_menu_scene.instantiate()
			add_child(pause_menu)
#			get_tree().paused = true
