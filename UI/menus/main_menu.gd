extends Node

@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D

const IP_ADDRESS: String = "localhost"
const PORT = 5000
const MAX_PLAYERS = 6

var peer: ENetMultiplayerPeer 

func _ready():
	animated_sprite.play("menu")
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(func(id):
		print("Peer connected: ", id)
	)

func _on_start_game_pressed() -> void:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_PLAYERS)

	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Server hosted on port ", PORT)
		print("Changing to world...")
		get_tree().change_scene_to_file("res://Scenes/world.tscn")
	else:
		print("Failed to host server. Error: ", error)

func _on_join_multiplayer_pressed() -> void:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(IP_ADDRESS, PORT)

	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Attempting to connect...")
	else:
		print("Failed to start client. Error: ", error)

func _on_connected_to_server():
	print("Connected to server")
	get_tree().change_scene_to_file("res://Scenes/world.tscn")  # only now, once confirmed

func _on_connection_failed():
	print("Connection failed — server may be full or offline")
	multiplayer.multiplayer_peer = null  # reset so the button can be pressed again

func _on_exit_pressed() -> void:
	print("Pressed Exit")
	get_tree().quit()
