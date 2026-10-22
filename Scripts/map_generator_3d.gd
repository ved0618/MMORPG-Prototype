# Map Generator 3D (2.5D / HD-2D)
# Generates all 26 3D arena map scenes into Scenes/maps_3d/
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

	# 6. Set owners and save PackedScene
	_set_owners(root, root)

	var packed := PackedScene.new()
	packed.pack(root)
	var path := "%s/map_%s.tscn" % [OUT_DIR, map_id]
	var err := ResourceSaver.save(packed, path)
	if err != OK:
		push_error("MapGenerator3D: failed to save %s (error %d)" % [path, err])


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
