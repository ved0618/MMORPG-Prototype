# Map
# A single level. Portals are intentionally removed/disabled.
# A solid boundary is created around every map so players cannot leave the level.
extends Node2D

const MapDataScript := preload("res://Scripts/map_data.gd")
const SPAWNER_SCENE := preload("res://Scenes/spawner.tscn")

signal wave_cleared

@onready var spawn_points: Node2D = $SpawnPoints

var _wave_started := false
var _wave_finished := false


func _ready() -> void:
	# Existing generated scenes may still contain old portal nodes. Remove them
	# at runtime so they cannot be used or seen.
	var portals := get_node_or_null("Portals")
	if portals:
		portals.queue_free()

	_create_map_boundaries()
	_ensure_wave_spawners()


func _create_map_boundaries() -> void:
	var body := StaticBody2D.new()
	body.name = "MapBoundary"
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)

	var half_w := MapDataScript.MAP_WIDTH / 2.0
	var half_h := MapDataScript.MAP_HEIGHT / 2.0
	var thickness := 32.0

	_add_wall(body, "Top", Vector2(0, -half_h - thickness / 2.0),
		Vector2(MapDataScript.MAP_WIDTH + thickness * 2.0, thickness))
	_add_wall(body, "Bottom", Vector2(0, half_h + thickness / 2.0),
		Vector2(MapDataScript.MAP_WIDTH + thickness * 2.0, thickness))
	_add_wall(body, "Left", Vector2(-half_w - thickness / 2.0, 0),
		Vector2(thickness, MapDataScript.MAP_HEIGHT + thickness * 2.0))
	_add_wall(body, "Right", Vector2(half_w + thickness / 2.0, 0),
		Vector2(thickness, MapDataScript.MAP_HEIGHT + thickness * 2.0))


func _add_wall(parent: Node, wall_name: String, position: Vector2, size: Vector2) -> void:
	var shape := CollisionShape2D.new()
	shape.name = wall_name
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	shape.position = position
	parent.add_child(shape)


func _ensure_wave_spawners() -> void:
	# Most maps already have three spawners. Map 026 did not, so create the same
	# wave setup there at runtime.
	var spawners := get_node_or_null("Spawners")
	if spawners == null:
		spawners = Node2D.new()
		spawners.name = "Spawners"
		add_child(spawners)

	if spawners.get_child_count() == 0:
		var positions := [
			Vector2(-366, 124),
			Vector2(-39, -291),
			Vector2(407, 142)
		]
		var names := ["SpawnerA", "SpawnerB", "SpawnerC"]
		for i in positions.size():
			var spawner = SPAWNER_SCENE.instantiate()
			spawner.name = names[i]
			spawner.position = positions[i]
			spawners.add_child(spawner)


func start_wave() -> void:
	if _wave_started:
		return
	_wave_started = true

	var spawners := get_node_or_null("Spawners")
	if spawners == null or spawners.get_child_count() == 0:
		_finish_wave()
		return

	for spawner in spawners.get_children():
		if spawner.has_signal("wave_cleared"):
			spawner.wave_cleared.connect(_on_spawner_wave_cleared)
		if spawner.has_method("start_wave"):
			spawner.start_wave()

	_check_wave_complete()


func _on_spawner_wave_cleared() -> void:
	_check_wave_complete()


func _check_wave_complete() -> void:
	if _wave_finished or not _wave_started:
		return

	var spawners := get_node_or_null("Spawners")
	if spawners == null:
		_finish_wave()
		return

	for spawner in spawners.get_children():
		if spawner.has_method("is_wave_active") and spawner.is_wave_active():
			return

	_finish_wave()


func _finish_wave() -> void:
	if _wave_finished:
		return
	_wave_finished = true
	print(name, ": wave cleared")
	wave_cleared.emit()


func get_spawn_position(entry_direction: String) -> Vector2:
	var marker_name := "CenterSpawn"
	match entry_direction:
		"top": marker_name = "EnterTop"
		"bottom": marker_name = "EnterBottom"
		"left": marker_name = "EnterLeft"
		"right": marker_name = "EnterRight"

	var marker := spawn_points.get_node_or_null(marker_name) as Marker2D
	if marker:
		return marker.global_position
	return global_position
