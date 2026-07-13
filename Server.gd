extends Node

const PORT = 5000
const MAX_PLAYERS = 5

func _ready():
	# Use the new ENetMultiplayerPeer class
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_PLAYERS)
	
	# Assign the peer to the multiplayer singleton
	multiplayer.multiplayer_peer = peer
	
	# Connect signals using the new Callable syntax
	multiplayer.peer_connected.connect(_client_connected)
	multiplayer.peer_disconnected.connect(_client_disconnected)

func _client_connected(id):
	print("Client " + str(id) + " connected to Server")
	# Spawn a representation of the client on the server
	var newClient = load("res://remote_client.tscn").instantiate()
	newClient.name = str(id) # Use .name property directly
	get_tree().get_root().add_child(newClient)

func _client_disconnected(id):
	print("Client " + str(id) + " disconnected")
	# Remove the client representation
	var client_node = get_tree().get_root().get_node_or_null(str(id))
	if client_node:
		client_node.queue_free()   
