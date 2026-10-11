# Minimap — draws all 26 maps as colored diamonds in the top-right corner,
# highlights the current map, and shows the player's position as a dot.
# Only visible for the local (authority) player.
extends Control

const MapDataScript := preload("res://Scripts/map_data.gd")

## Half-width of each diamond cell (edge-to-edge).
const CELL_HALF: float = 5.0
## Spacing between diamond centers.
const CELL_SPACING: float = 12.0

## Border margin around the minimap.
const MARGIN: float = 8.0

## Biome colors (index 1-7; index 0 unused).
const BIOME_COLORS: Array[Color] = [
	Color.MAGENTA,          # 0 (unused placeholder)
	Color(0.4, 0.8, 0.3),  # 1 — green
	Color(0.8, 0.6, 0.2),  # 2 — gold
	Color(0.2, 0.6, 0.9),  # 3 — blue
	Color(0.7, 0.4, 0.8),  # 4 — purple
	Color(0.9, 0.5, 0.2),  # 5 — orange
	Color(0.3, 0.7, 0.7),  # 6 — teal
	Color(0.85, 0.35, 0.35) # 7 — center (red)
]

const BG_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const CURRENT_BORDER_COLOR := Color.WHITE
const CURRENT_FILL_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const PLAYER_DOT_COLOR := Color(1.0, 1.0, 0.2)
const PLAYER_DOT_RADIUS := 2.5

## Resolved references (filled in _ready).
var _map_manager: Node = null
var _player: Node = null

## Cached world-space bounds of the entire map cluster.
var _world_center: Vector2 = Vector2.ZERO
var _world_half: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Only draw for the local player.
	var canvas_layer = get_parent()
	var player_root = canvas_layer.get_parent() if canvas_layer else null
	if player_root and not player_root.is_multiplayer_authority():
		visible = false
		return

	# Walk up from the minimap to find the actual Player node
	# (minimap is Control > CanvasLayer > Player)
	_player = player_root

	_map_manager = _find_map_manager()

	# Compute world bounds from all map grid_pos.
	_calc_world_bounds()

	# Anchor to top-right.
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -_total_width() - MARGIN
	offset_top = MARGIN
	offset_right = -MARGIN
	offset_bottom = _total_height() + MARGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	# Background rect.
	var total_w := _total_width()
	var total_h := _total_height()
	draw_rect(Rect2(Vector2.ZERO, Vector2(total_w, total_h)), BG_COLOR)

	var current_id := _current_map_id()

	for map_id: String in MapDataScript.MAPS.keys():
		var data: Dictionary = MapDataScript.MAPS[map_id]
		var grid_pos: Vector2 = data.get("grid_pos", Vector2.ZERO)

		# Center of this diamond on the minimap.
		var center := _grid_to_screen(grid_pos)

		# Biome color.
		var biome: int = data.get("biome", 0)
		var color: Color = BIOME_COLORS[biome] if biome >= 0 and biome < BIOME_COLORS.size() else Color.GRAY

		# Diamond vertices (rotated square).
		var diamond := _diamond_poly(center, CELL_HALF)

		# Draw filled diamond.
		draw_colored_polygon(diamond, color)

		# Highlight current map.
		if map_id == current_id:
			var border_diamond := _diamond_poly(center, CELL_HALF + 1.5)
			draw_polyline(border_diamond + PackedVector2Array([border_diamond[0]]), CURRENT_BORDER_COLOR, 1.5)
			draw_colored_polygon(diamond, CURRENT_FILL_COLOR)

	# Draw player dot.
	if _player and _map_manager:
		var current_map = _map_manager.get_current_map()
		if current_map:
			var local_pos: Vector2 = _player.global_position - current_map.global_position
			var map_grid: Vector2 = MapDataScript.MAPS[current_id].get("grid_pos", Vector2.ZERO)
			var origin := _grid_to_screen(map_grid)

			# Map the player's local position within the map to the cell.
			var px: float = origin.x + (local_pos.x + MapDataScript.MAP_WIDTH * 0.5) / MapDataScript.MAP_WIDTH * CELL_HALF * 2.0
			var py: float = origin.y + (local_pos.y + MapDataScript.MAP_HEIGHT * 0.5) / MapDataScript.MAP_HEIGHT * CELL_HALF * 2.0
			draw_circle(Vector2(px, py), PLAYER_DOT_RADIUS, PLAYER_DOT_COLOR)


## ── Helpers ──────────────────────────────────────────────────────────

func _diamond_poly(center: Vector2, half: float) -> PackedVector2Array:
	"""Return 4 vertices of a diamond (rotated square) centered on `center`."""
	return PackedVector2Array([
		center + Vector2(0, -half),   # top
		center + Vector2(half, 0),    # right
		center + Vector2(0, half),    # bottom
		center + Vector2(-half, 0),   # left
	])


func _find_map_manager() -> Node:
	"""Locate the MapManager ('Maps') node."""
	var scene_root := get_tree().current_scene
	if scene_root:
		var maps := scene_root.get_node_or_null("Maps")
		if maps:
			return maps
		# Fallback: search all children recursively for Maps node
		for child in scene_root.get_children():
			if child.name == "Maps":
				return child
	return null


func _current_map_id() -> String:
	if _map_manager:
		return _map_manager.current_map_id
	return "001"


func _calc_world_bounds() -> void:
	var min_g := Vector2(INF, INF)
	var max_g := Vector2(-INF, -INF)
	for map_id: String in MapDataScript.MAPS.keys():
		var gp: Vector2 = MapDataScript.MAPS[map_id].get("grid_pos", Vector2.ZERO)
		min_g = Vector2(minf(min_g.x, gp.x), minf(min_g.y, gp.y))
		max_g = Vector2(maxf(max_g.x, gp.x), maxf(max_g.y, gp.y))
	_world_center = Vector2.ZERO  # Circular layout is centered at origin
	_world_half = Vector2(maxf(abs(min_g.x), abs(max_g.x)), maxf(abs(min_g.y), abs(max_g.y)))


func _grid_to_screen(grid_pos: Vector2) -> Vector2:
	"""Convert a map grid_pos to the center pixel position on the minimap."""
	# Offset by world half to center the circular layout
	var offset = grid_pos + _world_half
	return Vector2(offset.x * CELL_SPACING, offset.y * CELL_SPACING)


func _total_width() -> float:
	return (_world_half.x * 2.0 + 1.0) * CELL_SPACING - (CELL_SPACING - CELL_HALF * 2.0)


func _total_height() -> float:
	return (_world_half.y * 2.0 + 1.0) * CELL_SPACING - (CELL_SPACING - CELL_HALF * 2.0)
