# Map Registry — shared by MapManager (runtime), MapGenerator (build tool),
# and Map.gd (spawn API). Edit connections / grid layout here once;
# run map_generator.gd after changing map count or connections.
class_name MapData

const MAP_WIDTH: float = 1280.0
const MAP_HEIGHT: float = 720.0
const TILE_SIZE: int = 16
const GRID_W: int = 80   # tiles per map width  (1280 / 16)
const GRID_H: int = 45   # tiles per map height (720 / 16)

## Playable radius (circular area within each map)
const PLAYABLE_RADIUS: float = 400.0

## Base grass tile in world_tile_set.tres atlas (source 0).
const GRASS_TILE: Vector2i = Vector2i(3, 3)

## Wall tile used at map edges
const WALL_TILE: Vector2i = Vector2i(0, 0)

## Rectangular grid layout (5x6 = 30, but using 26 maps).
## Maps are arranged in a simple row-column grid.
## (0,0) is top-left, (4,4) is bottom-right
## Grid indices map directly to cardinal directions:
## - Moving right increases X
## - Moving down increases Y
const MAPS: Dictionary = {
	# Row 0 (top)
	"001": {"biome": 7, "connections": ["002", "006"], "grid_pos": Vector2(0, 0)},
	"002": {"biome": 1, "connections": ["001", "003", "007"], "grid_pos": Vector2(1, 0)},
	"003": {"biome": 1, "connections": ["002", "004", "008"], "grid_pos": Vector2(2, 0)},
	"004": {"biome": 1, "connections": ["003", "005", "009"], "grid_pos": Vector2(3, 0)},
	"005": {"biome": 1, "connections": ["004", "010"], "grid_pos": Vector2(4, 0)},

	# Row 1
	"006": {"biome": 2, "connections": ["001", "007", "011"], "grid_pos": Vector2(0, 1)},
	"007": {"biome": 2, "connections": ["002", "006", "008", "012"], "grid_pos": Vector2(1, 1)},
	"008": {"biome": 2, "connections": ["003", "007", "009", "013"], "grid_pos": Vector2(2, 1)},
	"009": {"biome": 2, "connections": ["004", "008", "010", "014"], "grid_pos": Vector2(3, 1)},
	"010": {"biome": 2, "connections": ["005", "009", "015"], "grid_pos": Vector2(4, 1)},

	# Row 2
	"011": {"biome": 3, "connections": ["006", "012", "016"], "grid_pos": Vector2(0, 2)},
	"012": {"biome": 3, "connections": ["007", "011", "013", "017"], "grid_pos": Vector2(1, 2)},
	"013": {"biome": 3, "connections": ["008", "012", "014", "018"], "grid_pos": Vector2(2, 2)},
	"014": {"biome": 3, "connections": ["009", "013", "015", "019"], "grid_pos": Vector2(3, 2)},
	"015": {"biome": 3, "connections": ["010", "014", "020"], "grid_pos": Vector2(4, 2)},

	# Row 3
	"016": {"biome": 4, "connections": ["011", "017", "021"], "grid_pos": Vector2(0, 3)},
	"017": {"biome": 4, "connections": ["012", "016", "018", "022"], "grid_pos": Vector2(1, 3)},
	"018": {"biome": 4, "connections": ["013", "017", "019", "023"], "grid_pos": Vector2(2, 3)},
	"019": {"biome": 4, "connections": ["014", "018", "020", "024"], "grid_pos": Vector2(3, 3)},
	"020": {"biome": 4, "connections": ["015", "019", "025"], "grid_pos": Vector2(4, 3)},

	# Row 4
	"021": {"biome": 5, "connections": ["016", "022"], "grid_pos": Vector2(0, 4)},
	"022": {"biome": 5, "connections": ["017", "021", "023"], "grid_pos": Vector2(1, 4)},
	"023": {"biome": 5, "connections": ["018", "022", "024"], "grid_pos": Vector2(2, 4)},
	"024": {"biome": 5, "connections": ["019", "023", "025"], "grid_pos": Vector2(3, 4)},
	"025": {"biome": 5, "connections": ["020", "024", "026"], "grid_pos": Vector2(4, 4)},

	# Row 5 (extra corner map)
	"026": {"biome": 6, "connections": ["025"], "grid_pos": Vector2(5, 4)},
}
