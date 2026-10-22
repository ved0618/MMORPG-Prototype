# Map Generator 3D (2.5D / HD-2D)
# Generates all 26 3D arena map scenes into Scenes/maps_3d/ with environmental props
extends SceneTree

const MapDataScript := preload("res://Scripts/map_data.gd")
const MAP_3D_SCRIPT := preload("res://Scripts/map_3d.gd")
const SPAWNER_SCENE := preload("res://Scenes/spawner_3d.tscn")

const SLIME_1_SCENE := preload("res://Scenes/enemy_scenes/slime_1_3d.tscn")
const SLIME_2_SCENE := preload("res://Scenes/enemy_scenes/slime_2_3d.tscn")
const SLIME_3_SCENE := preload("res://Scenes/enemy_scenes/slime_3_3d.tscn")
const SLIME_4_SCENE := preload("res://Scenes/enemy_scenes/slime_4_3d.tscn")
const SLIME_5_SCENE := preload("res://Scenes/enemy_scenes/slime_5_3d.tscn")
const BOSS_SCENE    := preload("res://Scenes/enemy_scenes/boss_3d.tscn")

const PROP_TREE_SCENE  := preload("res://Scenes/environment/prop_tree.tscn")
const PROP_ROCK_SCENE  := preload("res://Scenes/environment/prop_rock.tscn")
const PROP_BUSH_SCENE  := preload("res://Scenes/environment/prop_bush.tscn")
const PROP_GRASS_SCENE := preload("res://Scenes/environment/prop_grass.tscn")

const OUT_DIR := "res://Scenes/maps_3d"

const BIOME_FLOOR_COLORS: Dictionary = {
	1: Color(0.22, 0.45, 0.20), # Grassland
	2: Color(0.48, 0.40, 0.18), # Golden Meadow
	3: Color(0.18, 0.35, 0.52), # Azure Cavern
	4: Color(0.32, 0.20, 0.42), # Cursed Grove
	5: Color(0.48, 0.22, 0.14), # Volcanic Ground
	6: Color(0.14, 0.12, 0.16), # Obsidian Arena (Boss)
	7: Color(0.25, 0.42, 0.24)  # Starter Camp
}

const BIOME_TORCH_COLORS: Dictionary = {
	1: Color(1.0, 0.85, 0.5),
	2: Color(1.0, 0.70, 0.3),
	3: Color(0.5, 0.85, 1.0),
	4: Color(0.85, 0.5, 1.0),
	5: Color(1.0, 0.4, 0.2),
	6: Color(1.0, 0.25, 0.25),
	7: Color(1.0, 0.85, 0.5)
}

const BIOME_PROP_CONFIG: Dictionary = {
	1: { # Grassland
		"trees": 14, "bushes": 16, "rocks": 6, "grass": 32,
		"tint": Color(1.0, 1.0, 1.0)
	},
	2: { # Golden Meadow
		"trees": 10, "bushes": 14, "rocks": 8, "grass": 38,
		"tint": Color(1.05, 0.95, 0.82)
	},
	3: { # Azure Cavern
		"trees": 0, "bushes": 8, "rocks": 24, "grass": 16,
		"tint": Color(0.72, 0.90, 1.18)
	},
	4: { # Cursed Grove
		"trees": 18, "bushes": 12, "rocks": 10, "grass": 22,
		"tint": Color(0.85, 0.72, 0.98)
	},
	5: { # Volcanic Ground
		"trees": 0, "bushes": 4, "rocks": 28, "grass": 12,
		"tint": Color(1.10, 0.70, 0.65)
	},
	6: { # Obsidian Arena (Boss)
		"trees": 0, "bushes": 2, "rocks": 18, "grass": 10,
		"tint": Color(0.70, 0.65, 0.78)
	},
	7: { # Starter Camp
		"trees": 12, "bushes": 14, "rocks": 6, "grass": 28,
		"tint": Color(1.0, 1.0, 1.0)
	}
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var count := 0
	for map_id: String in MapDataScript.MAPS.keys():
		_generate_3d_map(map_id, MapDataScript.MAPS[map_id])
		count += 1
	print("MapGenerator3D: successfully generated %d 3D map scenes to %s" % [count, OUT_DIR])
	quit(0)


func _generate_3d_map(map_id: String, data: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Map_" + map_id
	root.set_script(MAP_3D_SCRIPT)

	var biome: int = data.get("biome", 1)
	var floor_color: Color = BIOME_FLOOR_COLORS.get(biome, Color(0.25, 0.4, 0.2))
	var torch_color: Color = BIOME_TORCH_COLORS.get(biome, Color(1.0, 0.8, 0.5))

	var half_w: float = 21.0
	var half_h: float = 13.0
	var wall_height: float = 2.0
	var wall_thickness: float = 1.0

	# 1. Floor Mesh
	var floor_mesh_inst := MeshInstance3D.new()
	floor_mesh_inst.name = "FloorMesh"
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(half_w * 2.0, half_h * 2.0)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = floor_color
	floor_mat.roughness = 0.85
	plane_mesh.material = floor_mat
	floor_mesh_inst.mesh = plane_mesh
	root.add_child(floor_mesh_inst)

	# Floor StaticBody (so physics rays & floor collision work)
	var floor_body := StaticBody3D.new()
	floor_body.name = "FloorStaticBody"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 6
	var floor_col := CollisionShape3D.new()
	floor_col.name = "FloorCollision"
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(half_w * 2.0, 0.5, half_h * 2.0)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, -0.25, 0.0)
	floor_body.add_child(floor_col)
	root.add_child(floor_body)

	# 2. Visual Perimeter Wall Meshes
	var walls_node := Node3D.new()
	walls_node.name = "PerimeterWalls"
	root.add_child(walls_node)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.28, 0.28, 0.32)
	wall_mat.roughness = 0.9

	_add_wall_mesh(walls_node, "WallTop", Vector3(0.0, wall_height * 0.5, -half_h), Vector3(half_w * 2.0 + wall_thickness * 2.0, wall_height, wall_thickness), wall_mat)
	_add_wall_mesh(walls_node, "WallBottom", Vector3(0.0, wall_height * 0.5, half_h), Vector3(half_w * 2.0 + wall_thickness * 2.0, wall_height, wall_thickness), wall_mat)
	_add_wall_mesh(walls_node, "WallLeft", Vector3(-half_w, wall_height * 0.5, 0.0), Vector3(wall_thickness, wall_height, half_h * 2.0), wall_mat)
	_add_wall_mesh(walls_node, "WallRight", Vector3(half_w, wall_height * 0.5, 0.0), Vector3(wall_thickness, wall_height, half_h * 2.0), wall_mat)

	# 3. Corner Torches with dynamic OmniLight3D
	var torches_node := Node3D.new()
	torches_node.name = "Torches"
	root.add_child(torches_node)

	var corner_positions := [
		Vector3(-half_w + 2.0, 0.0, -half_h + 2.0),
		Vector3(half_w - 2.0, 0.0, -half_h + 2.0),
		Vector3(-half_w + 2.0, 0.0, half_h - 2.0),
		Vector3(half_w - 2.0, 0.0, half_h - 2.0)
	]
	for i in range(corner_positions.size()):
		_add_torch_pillar(torches_node, "Torch_%d" % i, corner_positions[i], torch_color)

	# 4. Spawn markers
	var spawns := Node3D.new()
	spawns.name = "SpawnPoints"
	root.add_child(spawns)

	_add_marker(spawns, "CenterSpawn", Vector3(0.0, 0.0, 0.0))
	_add_marker(spawns, "EnterTop",    Vector3(0.0, 0.0, -9.0))
	_add_marker(spawns, "EnterBottom", Vector3(0.0, 0.0, 9.0))
	_add_marker(spawns, "EnterLeft",   Vector3(-16.0, 0.0, 0.0))
	_add_marker(spawns, "EnterRight",  Vector3(16.0, 0.0, 0.0))

	# 5. Spawners
	var spawners := Node3D.new()
	spawners.name = "Spawners"
	root.add_child(spawners)

	# Select monster scene according to biome/map
	var monster_scene: PackedScene = SLIME_1_SCENE
	if map_id == "026" or biome == 6:
		monster_scene = BOSS_SCENE
	elif biome == 1 or biome == 7:
		monster_scene = SLIME_1_SCENE
	elif biome == 2:
		monster_scene = SLIME_2_SCENE
	elif biome == 3:
		monster_scene = SLIME_3_SCENE
	elif biome == 4:
		monster_scene = SLIME_4_SCENE
	elif biome == 5:
		monster_scene = SLIME_5_SCENE

	if map_id == "026":
		# Boss map: single central spawner
		var spawner = SPAWNER_SCENE.instantiate()
		spawner.name = "BossSpawner"
		spawner.position = Vector3(0.0, 0.0, 0.0)
		spawner.monster_scene = BOSS_SCENE
		spawner.max_alive = 1
		spawners.add_child(spawner)
	else:
		var positions := [
			Vector3(-11.0, 0.0, 4.0),
			Vector3(0.0, 0.0, -7.0),
			Vector3(11.0, 0.0, 4.0)
		]
		var names := ["SpawnerA", "SpawnerB", "SpawnerC"]
		for i in positions.size():
			var spawner = SPAWNER_SCENE.instantiate()
			spawner.name = names[i]
			spawner.position = positions[i]
			spawner.monster_scene = monster_scene
			spawner.max_alive = 2
			spawners.add_child(spawner)

	# 6. Environmental Props (Trees, Rocks, Bushes, Grass)
	var props_node := Node3D.new()
	props_node.name = "EnvironmentProps"
	root.add_child(props_node)
	_populate_environment_props(props_node, map_id, biome, half_w, half_h)

	# 7. Set owners and save PackedScene
	_set_owners(root, root)

	var packed := PackedScene.new()
	packed.pack(root)
	var path := "%s/map_%s.tscn" % [OUT_DIR, map_id]
	var err := ResourceSaver.save(packed, path)
	if err != OK:
		push_error("MapGenerator3D: failed to save %s (error %d)" % [path, err])
	root.free()


func _populate_environment_props(props_node: Node3D, map_id: String, biome: int, half_w: float, half_h: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(map_id) + 12345

	var config: Dictionary = BIOME_PROP_CONFIG.get(biome, BIOME_PROP_CONFIG[1])
	var base_tint: Color = config.get("tint", Color.WHITE)

	# Reserved zones (spawn points, spawners, torches)
	var reserved_points: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),    # CenterSpawn
		Vector3(0.0, 0.0, -9.0),   # EnterTop
		Vector3(0.0, 0.0, 9.0),    # EnterBottom
		Vector3(-16.0, 0.0, 0.0),  # EnterLeft
		Vector3(16.0, 0.0, 0.0),   # EnterRight
		Vector3(-half_w + 2.0, 0.0, -half_h + 2.0), # Torches
		Vector3(half_w - 2.0, 0.0, -half_h + 2.0),
		Vector3(-half_w + 2.0, 0.0, half_h - 2.0),
		Vector3(half_w - 2.0, 0.0, half_h - 2.0)
	]

	var is_boss_map: bool = (map_id == "026" or biome == 6)
	if not is_boss_map:
		reserved_points.append(Vector3(-11.0, 0.0, 4.0)) # SpawnerA
		reserved_points.append(Vector3(0.0, 0.0, -7.0))  # SpawnerB
		reserved_points.append(Vector3(11.0, 0.0, 4.0))  # SpawnerC

	var placed_solid_positions: Array[Vector3] = []

	var min_x := -half_w + 2.5
	var max_x := half_w - 2.5
	var min_z := -half_h + 2.2
	var max_z := half_h - 2.2

	var is_valid_solid_pos = func(pos: Vector3, min_dist: float) -> bool:
		for r in reserved_points:
			var req_dist: float = 6.5 if (is_boss_map and r == Vector3.ZERO) else 2.5
			if pos.distance_to(r) < req_dist:
				return false
		for p in placed_solid_positions:
			if pos.distance_to(p) < min_dist:
				return false
		return true

	# 1. Place Trees
	var tree_count: int = config.get("trees", 0)
	for i in range(tree_count):
		for attempt in range(50):
			var x: float
			var z: float
			# 60% bias towards perimeter
			if rng.randf() < 0.6:
				if rng.randf() < 0.5:
					x = rng.randf_range(min_x, max_x)
					z = rng.randf_range(max_z - 3.0, max_z) if rng.randf() < 0.5 else rng.randf_range(min_z, min_z + 3.0)
				else:
					x = rng.randf_range(max_x - 4.5, max_x) if rng.randf() < 0.5 else rng.randf_range(min_x, min_x + 4.5)
					z = rng.randf_range(min_z, max_z)
			else:
				x = rng.randf_range(min_x, max_x)
				z = rng.randf_range(min_z, max_z)

			var pos := Vector3(x, 0.0, z)
			if is_valid_solid_pos.call(pos, 2.2):
				var tree = PROP_TREE_SCENE.instantiate()
				tree.name = "Tree_%d" % i
				tree.position = pos
				var s: float = rng.randf_range(0.85, 1.2)
				tree.scale = Vector3(s, s, s)
				var spr: Sprite3D = tree.get_node_or_null("Sprite3D")
				if spr:
					spr.flip_h = rng.randf() > 0.5
					var tint_var := rng.randf_range(0.92, 1.08)
					spr.modulate = Color(base_tint.r * tint_var, base_tint.g * tint_var, base_tint.b * tint_var)
				props_node.add_child(tree)
				placed_solid_positions.append(pos)
				break

	# 2. Place Rocks
	var rock_count: int = config.get("rocks", 0)
	for i in range(rock_count):
		for attempt in range(50):
			var x := rng.randf_range(min_x, max_x)
			var z := rng.randf_range(min_z, max_z)
			var pos := Vector3(x, 0.0, z)
			if is_valid_solid_pos.call(pos, 1.8):
				var rock = PROP_ROCK_SCENE.instantiate()
				rock.name = "Rock_%d" % i
				rock.position = pos
				var s: float = rng.randf_range(0.70, 1.35)
				rock.scale = Vector3(s, s, s)
				var spr: Sprite3D = rock.get_node_or_null("Sprite3D")
				if spr:
					spr.flip_h = rng.randf() > 0.5
					var tint_var := rng.randf_range(0.90, 1.10)
					spr.modulate = Color(base_tint.r * tint_var, base_tint.g * tint_var, base_tint.b * tint_var)
				props_node.add_child(rock)
				placed_solid_positions.append(pos)
				break

	# 3. Place Bushes
	var bush_count: int = config.get("bushes", 0)
	for i in range(bush_count):
		for attempt in range(50):
			var x: float
			var z: float
			if placed_solid_positions.size() > 0 and rng.randf() < 0.4:
				var target_pos: Vector3 = placed_solid_positions[rng.randi() % placed_solid_positions.size()]
				var angle := rng.randf() * TAU
				var dist := rng.randf_range(1.5, 2.3)
				x = clampf(target_pos.x + cos(angle) * dist, min_x, max_x)
				z = clampf(target_pos.z + sin(angle) * dist, min_z, max_z)
			else:
				x = rng.randf_range(min_x, max_x)
				z = rng.randf_range(min_z, max_z)

			var pos := Vector3(x, 0.0, z)
			if is_valid_solid_pos.call(pos, 1.5):
				var bush = PROP_BUSH_SCENE.instantiate()
				bush.name = "Bush_%d" % i
				bush.position = pos
				var s: float = rng.randf_range(0.75, 1.25)
				bush.scale = Vector3(s, s, s)
				var spr: Sprite3D = bush.get_node_or_null("Sprite3D")
				if spr:
					spr.flip_h = rng.randf() > 0.5
					var tint_var := rng.randf_range(0.92, 1.08)
					spr.modulate = Color(base_tint.r * tint_var, base_tint.g * tint_var, base_tint.b * tint_var)
				props_node.add_child(bush)
				placed_solid_positions.append(pos)
				break

	# 4. Place Grass (No collision - decorative scatter)
	var grass_count: int = config.get("grass", 0)
	for i in range(grass_count):
		var x := rng.randf_range(-half_w + 1.5, half_w - 1.5)
		var z := rng.randf_range(-half_h + 1.5, half_h - 1.5)
		var pos := Vector3(x, 0.0, z)
		var grass = PROP_GRASS_SCENE.instantiate()
		grass.name = "Grass_%d" % i
		grass.position = pos
		var s: float = rng.randf_range(0.75, 1.30)
		grass.scale = Vector3(s, s, s)
		var spr: Sprite3D = grass.get_node_or_null("Sprite3D")
		if spr:
			spr.flip_h = rng.randf() > 0.5
			var tint_var := rng.randf_range(0.90, 1.10)
			spr.modulate = Color(base_tint.r * tint_var, base_tint.g * tint_var, base_tint.b * tint_var)
		props_node.add_child(grass)


func _add_wall_mesh(parent: Node, node_name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mi.mesh = box
	mi.position = pos
	parent.add_child(mi)


func _add_torch_pillar(parent: Node, node_name: String, pos: Vector3, light_color: Color) -> void:
	var pillar := Node3D.new()
	pillar.name = node_name
	pillar.position = pos
	parent.add_child(pillar)

	# Stone pillar
	var mi := MeshInstance3D.new()
	mi.name = "PillarMesh"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.45
	cyl.height = 1.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.25, 0.28)
	cyl.material = mat
	mi.mesh = cyl
	mi.position = Vector3(0.0, 0.8, 0.0)
	pillar.add_child(mi)

	# OmniLight
	var light := OmniLight3D.new()
	light.name = "TorchLight"
	light.light_color = light_color
	light.light_energy = 1.4
	light.omni_range = 10.0
	light.shadow_enabled = true
	light.position = Vector3(0.0, 1.8, 0.0)
	pillar.add_child(light)


func _add_marker(parent: Node, marker_name: String, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = marker_name
	m.position = pos
	parent.add_child(m)


func _set_owners(node: Node, root: Node) -> void:
	for c in node.get_children():
		c.owner = root
		_set_owners(c, root)
