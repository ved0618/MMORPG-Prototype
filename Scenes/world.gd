extends Node2D

const PLAYER_SCENE := preload("res://Scenes/player.tscn")
const BASE_PLAYER_HP := 100

@onready var players: Node = $Players
@onready var player_spawner: MultiplayerSpawner = $Players/MultiplayerSpawner
@onready var map_manager: Node2D = $Maps

# Persists max HP across death/respawn. Level transitions increase this value
# for every connected player by 20%.
var player_max_health: Dictionary = {}


func _ready() -> void:
	player_spawner.spawn_function = _spawn_custom_player

	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)

	if map_manager.has_signal("map_transitioned"):
		map_manager.map_transitioned.connect(_on_map_transitioned)

	if multiplayer.is_server():
		_spawn_player(multiplayer.get_unique_id())
		_show_host_ip_for_ten_seconds()

	print("World ready complete, is_server: ", multiplayer.is_server())


func _peer_connected(peer_id: int) -> void:
	print("Peer connected: ", peer_id)
	if multiplayer.is_server():
		# A late joiner must enter the level the party is currently playing.
		if map_manager.has_method("_rpc_load_map"):
			map_manager._rpc_load_map.rpc_id(peer_id, map_manager.current_map_id)
		_spawn_player(peer_id)


func _peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected: ", peer_id)
	if players.has_node(str(peer_id)):
		players.get_node(str(peer_id)).queue_free()
	player_max_health.erase(peer_id)


func _spawn_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if players.has_node(str(peer_id)):
		return

	if not player_max_health.has(peer_id):
		player_max_health[peer_id] = BASE_PLAYER_HP

	var current_level: String = map_manager.current_map_id
	var spawn_pos: Vector2 = map_manager.get_spawn_position(current_level)
	var spawn_data := {
		"peer_id": peer_id,
		"position": spawn_pos,
		"max_health": player_max_health[peer_id]
	}
	player_spawner.spawn(spawn_data)


func _spawn_custom_player(data: Dictionary) -> Node:
	var peer_id: int = int(data["peer_id"])
	var spawn_position: Vector2 = data["position"]
	var max_hp: int = int(data.get("max_health", BASE_PLAYER_HP))

	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.global_position = spawn_position
	player.set_multiplayer_authority(peer_id)

	var health = player.get_node("Health(Node)")
	health.max_health = max_hp
	health.current_health = max_hp

	health.died.connect(_on_player_died.bind(peer_id))

	return player


func _on_player_died(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var player := players.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

	get_tree().create_timer(3.0).timeout.connect(_respawn_player.bind(peer_id))


func _respawn_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if peer_id != multiplayer.get_unique_id() and not multiplayer.get_peers().has(peer_id):
		return

	_spawn_player(peer_id)


func _on_map_transitioned(from_map: String, to_map: String) -> void:
	if not multiplayer.is_server():
		return

	# Every completed level grants every connected player +20% max HP.
	for peer_id in player_max_health.keys():
		player_max_health[peer_id] = maxi(
			1,
			int(round(float(player_max_health[peer_id]) * 1.20))
		)

	for player in players.get_children():
		var health = player.get_node_or_null("Health(Node)")
		if health:
			health.max_health = player_max_health.get(
				int(player.name), health.max_health
			)
			health.current_health = health.max_health
			health.health_changed.emit(health.current_health, health.max_health)

	print(
		"Level complete: ", from_map, " -> ", to_map,
		" | player max HP increased by 20%"
	)


# Shows the host's LAN IPv4 address so players on the same network can join.
func _show_host_ip_for_ten_seconds() -> void:
	var host_ip := _get_lan_ipv4_address()
	var layer := CanvasLayer.new()
	layer.name = "HostAddressOverlay"
	add_child(layer)

	var panel := PanelContainer.new()
	panel.name = "HostAddressPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -330.0
	panel.offset_top = 18.0
	panel.offset_right = 330.0
	panel.offset_bottom = 112.0
	layer.add_child(panel)

	var label := Label.new()
	label.name = "HostAddressLabel"
	label.text = "HOST SERVER — SHARE THIS IP\n%s\nClients: enter this IP in Join Multiplayer (Port %d)" % [host_ip, 5000]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	panel.add_child(label)

	print("Host LAN IPv4: ", host_ip, " (shown for 10 seconds)")
	await get_tree().create_timer(10.0).timeout
	if is_instance_valid(layer):
		layer.queue_free()


func _get_lan_ipv4_address() -> String:
	var addresses: PackedStringArray = IP.get_local_addresses()
	# Prefer private LAN addresses; skip loopback and link-local addresses.
	for address in addresses:
		if address.contains(":") or not address.is_valid_ip_address():
			continue
		if address.begins_with("127.") or address.begins_with("169.254."):
			continue
		if address.begins_with("10.") or address.begins_with("192.168."):
			return address
		var parts := address.split(".")
		if parts.size() == 4 and parts[0] == "172":
			var second_octet := int(parts[1])
			if second_octet >= 16 and second_octet <= 31:
				return address
	for address in addresses:
		if address.contains(":") or not address.is_valid_ip_address():
			continue
		if not address.begins_with("127.") and not address.begins_with("169.254."):
			return address
	return "127.0.0.1"
