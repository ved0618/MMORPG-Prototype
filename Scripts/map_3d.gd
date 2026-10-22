# Map 3D (2.5D / HD-2D)
# A single 3D level arena.
# Solid boundaries surround the level, and wave spawners manage enemy waves.
extends Node3D

signal wave_cleared

const SPAWNER_SCENE := preload("res://Scenes/spawner_3d.tscn")

@onready var spawn_points: Node3D = $SpawnPoints

var _wave_started: bool = false
var _wave_finished: bool = false


func _ready() -> void:
	_create_boundaries()
	_ensure_wave_spawners()


func _create_boundaries() -> void:
	if has_node("MapBoundary"):
		return

	var body := StaticBody3D.new()
	body.name = "MapBoundary"
	body.collision_layer = 1
	body.collision_mask = 6 # Player and Enemies
	add_child(body)

	var half_w: float = 21.0
	var half_h: float = 13.0
	var thickness: float = 2.0
	var wall_height: float = 4.0

	# Top wall (-Z)
	_add_wall_collider(body, "Top", Vector3(0.0, wall_height * 0.5, -half_h - thickness * 0.5), Vector3(half_w * 2.0 + thickness * 2.0, wall_height, thickness))
	# Bottom wall (+Z)
	_add_wall_collider(body, "Bottom", Vector3(0.0, wall_height * 0.5, half_h + thickness * 0.5), Vector3(half_w * 2.0 + thickness * 2.0, wall_height, thickness))
	# Left wall (-X)
	_add_wall_collider(body, "Left", Vector3(-half_w - thickness * 0.5, wall_height * 0.5, 0.0), Vector3(thickness, wall_height, half_h * 2.0 + thickness * 2.0))
	# Right wall (+X)
	_add_wall_collider(body, "Right", Vector3(half_w + thickness * 0.5, wall_height * 0.5, 0.0), Vector3(thickness, wall_height, half_h * 2.0 + thickness * 2.0))


func _add_wall_collider(parent: Node, wall_name: String, pos: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.name = wall_name
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	parent.add_child(shape)


func _ensure_wave_spawners() -> void:
	var spawners := get_node_or_null("Spawners")
	if spawners == null:
		spawners = Node3D.new()
		spawners.name = "Spawners"
		add_child(spawners)

	if spawners.get_child_count() == 0:
		var positions := [
			Vector3(-12.0, 0.0, 4.0),
			Vector3(0.0, 0.0, -8.0),
			Vector3(12.0, 0.0, 4.0)
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
	print(name, ": wave cleared in 2.5D")
	wave_cleared.emit()


func get_spawn_position(entry_direction: String = "center") -> Vector3:
	var marker_name := "CenterSpawn"
	match entry_direction:
		"top": marker_name = "EnterTop"
		"bottom": marker_name = "EnterBottom"
		"left": marker_name = "EnterLeft"
		"right": marker_name = "EnterRight"

	if spawn_points:
		var marker := spawn_points.get_node_or_null(marker_name) as Marker3D
		if marker:
			return marker.global_position
	return global_position
