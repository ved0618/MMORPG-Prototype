# Map Generator (one-shot)
# Builds the 26 editable map scenes into Scenes/maps/.
# Each map has: rectangular terrain and spawn markers.
# Maps are individual levels; all map edges are closed at runtime.
# Run from a terminal:
#   godot --headless --script res://Scripts/map_generator.gd
extends SceneTree

const MapDataScript := preload("res://Scripts/map_data.gd")
const MAP_SCRIPT     := preload("res://Scripts/map.gd")
const TILE_SET       := preload("res://Resources/world_tile_set.tres")

const DIR := "res://Scenes/maps"
const PORTAL_THICKNESS := 40.0

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var count := 0
	for map_id: String in MapDataScript.MAPS.keys():
		_generate_map(map_id, MapDataScript.MAPS[map_id])
		count += 1
	print("MapGenerator: wrote %d map scenes to %s" % [count, DIR])
	quit(0)


# ── Map root ────────────────────────────────────────────────────────

func _generate_map(map_id: String, data: Dictionary) -> void:
	var root := Node2D.new()
	root.name = "Map_" + map_id
	root.set_script(MAP_SCRIPT)

	_add_tilemap(root, map_id)
	_add_spawn_points(root)
	_add_label(root, map_id)

	_set_owners(root, root)

	var packed := PackedScene.new()
	packed.pack(root)
	var path := "%s/map_%s.tscn" % [DIR, map_id]
	var err := ResourceSaver.save(packed, path)
	if err == OK:
		print("  ", path)
	else:
		push_error("MapGenerator: failed to save %s (error %d)" % [path, err])


# ── Tilemap (circular with walls) ────────────────────────────────────

func _add_tilemap(root: Node2D, map_id: String) -> void:
	var tml := TileMapLayer.new()
	tml.name = "TileMapLayer"
	tml.tile_set = TILE_SET

	var half_w := MapDataScript.GRID_W / 2
	var half_h := MapDataScript.GRID_H / 2

	var data: Dictionary = MapDataScript.MAPS.get(map_id, {})
	var connections: Array = data.get("connections", [])
	var my_grid_pos: Vector2 = data.get("grid_pos", Vector2.ZERO)

	# Determine which edges have connections
	var has_connection: Dictionary = {
		"top": false,
		"bottom": false,
		"left": false,
		"right": false,
	}

	for dest_id in connections:
		if not MapDataScript.MAPS.has(dest_id):
			continue
		var dest_grid_pos: Vector2 = MapDataScript.MAPS[dest_id].get("grid_pos", Vector2.ZERO)
		var delta := dest_grid_pos - my_grid_pos

		if abs(delta.x) > abs(delta.y):
			# Horizontal connection
			if delta.x > 0:
				has_connection["right"] = true
			else:
				has_connection["left"] = true
		else:
			# Vertical connection
			if delta.y > 0:
				has_connection["bottom"] = true
			else:
				has_connection["top"] = true

	# Fill map with grass, add walls on edges without connections
	for x in MapDataScript.GRID_W:
		for y in MapDataScript.GRID_H:
			var grid_x := x - half_w
			var grid_y := y - half_h

			var tile: Vector2i = MapDataScript.GRASS_TILE

			# Add walls on edges that don't have connections
			# Top edge
			if grid_y < -half_h + 2 and not has_connection["top"]:
				tile = MapDataScript.WALL_TILE
			# Bottom edge
			elif grid_y > half_h - 3 and not has_connection["bottom"]:
				tile = MapDataScript.WALL_TILE
			# Left edge
			elif grid_x < -half_w + 2 and not has_connection["left"]:
				tile = MapDataScript.WALL_TILE
			# Right edge
			elif grid_x > half_w - 3 and not has_connection["right"]:
				tile = MapDataScript.WALL_TILE

			tml.set_cell(Vector2i(grid_x, grid_y), 0, tile)

	root.add_child(tml)


# Portals intentionally removed: maps are sequential wave-based levels.
# Players are moved automatically by MapManager after a cleared wave.


# ── Spawn markers ───────────────────────────────────────────────────

func _add_spawn_points(root: Node2D) -> void:
	var spawns := Node2D.new()
	spawns.name = "SpawnPoints"
	root.add_child(spawns)

	var margin := 200.0
	var W := MapDataScript.MAP_WIDTH
	var H := MapDataScript.MAP_HEIGHT

	_marker(spawns, "CenterSpawn", Vector2.ZERO)
	_marker(spawns, "EnterTop",    Vector2(0, -H / 2.0 + margin))
	_marker(spawns, "EnterBottom", Vector2(0,  H / 2.0 - margin))
	_marker(spawns, "EnterLeft",   Vector2(-W / 2.0 + margin, 0))
	_marker(spawns, "EnterRight",  Vector2( W / 2.0 - margin, 0))


func _marker(parent: Node, marker_name: String, pos: Vector2) -> void:
	var m := Marker2D.new()
	m.name = marker_name
	m.position = pos
	parent.add_child(m)


# ── Label ───────────────────────────────────────────────────────────

func _add_label(root: Node2D, map_id: String) -> void:
	var label := Label.new()
	label.name = "MapLabel"
	label.text = "Map " + map_id
	label.position = Vector2(-MapDataScript.MAP_WIDTH / 2.0 + 8.0, -MapDataScript.MAP_HEIGHT / 2.0 + 8.0)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	root.add_child(label)


# ── Ownership ───────────────────────────────────────────────────────

func _set_owners(node: Node, root: Node) -> void:
	for c in node.get_children():
		c.owner = root
		_set_owners(c, root)
