extends Node

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ip_input: LineEdit = $"AnimatedSprite2D/VBoxContainer/Host IP"


# ============================================================
# MULTIPLAYER SETTINGS
# ============================================================

const PORT: int = 5000
const MAX_PLAYERS: int = 6

var peer: ENetMultiplayerPeer


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	animated_sprite.play("menu")

	# Multiplayer signals
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

	multiplayer.peer_connected.connect(_on_peer_connected)

	# Enter the host computer's LAN IPv4 address to join a game.
	ip_input.text = ""
	ip_input.placeholder_text = "Enter host IPv4 address"


# ============================================================
# HOST GAME
# ============================================================

func _on_start_game_pressed() -> void:

	print("================================")
	print("STARTING LAN SERVER")
	print("Port: ", PORT)
	print("Max Players: ", MAX_PLAYERS)
	print("================================")

	peer = ENetMultiplayerPeer.new()

	var error := peer.create_server(PORT, MAX_PLAYERS)

	if error == OK:

		multiplayer.multiplayer_peer = peer

		print("================================")
		print("SERVER STARTED SUCCESSFULLY")
		print("Port: ", PORT)
		print("Waiting for players...")
		print("================================")

		get_tree().change_scene_to_file(
			"res://Scenes/world_3d.tscn"
		)

	else:

		print("================================")
		print("FAILED TO START SERVER")
		print("Error: ", error)
		print("================================")


# ============================================================
# JOIN GAME
# ============================================================

func _on_join_multiplayer_pressed() -> void:

	var ip_address := ip_input.text.strip_edges()

	# --------------------------------------------------------
	# Check IP
	# --------------------------------------------------------

	if ip_address.is_empty():
		push_warning("Enter the host's LAN IPv4 address before joining.")
		return

	if not ip_address.is_valid_ip_address():
		push_warning("Invalid IP address: %s. Enter the host's LAN IPv4, e.g. 192.168.1.5." % ip_address)
		return


	print("================================")
	print("JOINING LAN SERVER")
	print("Host IP: ", ip_address)
	print("Port: ", PORT)
	print("================================")


	peer = ENetMultiplayerPeer.new()

	var error := peer.create_client(
		ip_address,
		PORT
	)

	if error == OK:

		multiplayer.multiplayer_peer = peer

		print("Attempting to connect to:")
		print(ip_address, ":", PORT)

	else:

		print("================================")
		print("FAILED TO START CLIENT")
		print("Error: ", error)
		print("================================")

		multiplayer.multiplayer_peer = null


# ============================================================
# CONNECTED TO SERVER
# ============================================================

func _on_connected_to_server() -> void:

	print("================================")
	print("CONNECTED TO SERVER!")
	print("My Peer ID: ", multiplayer.get_unique_id())
	print("================================")

	get_tree().change_scene_to_file(
		"res://Scenes/world_3d.tscn"
	)


# ============================================================
# CONNECTION FAILED
# ============================================================

func _on_connection_failed() -> void:

	print("================================")
	print("CONNECTION FAILED")
	print("Server may be offline, unreachable, or full.")
	print("================================")

	multiplayer.multiplayer_peer = null


# ============================================================
# PEER CONNECTED
# ============================================================

func _on_peer_connected(id: int) -> void:

	print("Peer connected: ", id)


# ============================================================
# EXIT
# ============================================================

func _on_exit_pressed() -> void:

	print("Pressed Exit")

	get_tree().quit()
