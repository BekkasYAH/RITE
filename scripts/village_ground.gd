extends Node2D

# 48x36 tiles of 16px = 768x576 world
const MAP_WIDTH: int = 48
const MAP_HEIGHT: int = 36
const TILE_SIZE: int = 16

var tex_ground: Texture2D
var tex_road: Texture2D
var tex_cobble: Texture2D
var tex_water0: Texture2D
var tex_water1: Texture2D

var water_timer: float = 0.0
var water_frame: int = 0

# Map grid: 0=grass, 1=dirt_road, 2=cobble, 3=water
var grid: Array = []

func _ready() -> void:
	z_index = 0
	tex_ground = load("res://assets/environment/ground_base.png")
	tex_road = load("res://assets/environment/autotile_dirt_road.png")
	tex_cobble = load("res://assets/environment/autotile_cobble.png")
	tex_water0 = load("res://assets/environment/autotile_water_f0.png")
	tex_water1 = load("res://assets/environment/autotile_water_f1.png")

	_generate_map_grid()

func _generate_map_grid() -> void:
	grid.resize(MAP_WIDTH * MAP_HEIGHT)
	for i in range(grid.size()):
		grid[i] = 0

	# 1. Main Dirt Road: West to East across middle (y = 17..19)
	for x in range(0, MAP_WIDTH):
		for y in range(17, 20):
			_set_cell(x, y, 1)

	# 2. Branch Road North to Chapel (x = 32..34, y = 6..18)
	for x in range(32, 35):
		for y in range(6, 18):
			_set_cell(x, y, 1)

	# 3. Branch Road South to Graveyard (x = 28..30, y = 19..30)
	for x in range(28, 31):
		for y in range(19, 30):
			_set_cell(x, y, 1)

	# 4. Branch Road North-West to Abandoned Cottage (x = 10..12, y = 8..18)
	for x in range(10, 13):
		for y in range(8, 18):
			_set_cell(x, y, 1)

	# 5. Cobble Plaza around Central Well (x = 21..27, y = 15..21)
	for x in range(20, 28):
		for y in range(15, 22):
			var dist = Vector2(x - 23.5, y - 18.0).length()
			if dist <= 3.8:
				_set_cell(x, y, 2)

	# 6. Water stream on far West edge (x = 2..4, y = 0..35)
	for y in range(MAP_HEIGHT):
		var wx = 3 + int(sin(y * 0.3) * 1.2)
		_set_cell(wx, y, 3)
		_set_cell(wx + 1, y, 3)

	# Road bridge over water (x = 2..5, y = 17..19)
	for x in range(1, 6):
		for y in range(17, 20):
			_set_cell(x, y, 1)

func _set_cell(x: int, y: int, val: int) -> void:
	if x >= 0 and x < MAP_WIDTH and y >= 0 and y < MAP_HEIGHT:
		grid[y * MAP_WIDTH + x] = val

func _get_cell(x: int, y: int) -> int:
	if x >= 0 and x < MAP_WIDTH and y >= 0 and y < MAP_HEIGHT:
		return grid[y * MAP_WIDTH + x]
	return 0

func _process(delta: float) -> void:
	water_timer += delta
	if water_timer >= 0.5:
		water_timer = 0.0
		water_frame = (water_frame + 1) % 2
		queue_redraw()

func _draw() -> void:
	if not tex_ground:
		return

	# Draw base ground (grass_a, grass_b, grass_c)
	# ground_base cols: 0=grass_a, 1=grass_b, 2=grass_c, 3=dirt_a, 4=dirt_b, 5=cobble
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			var pos = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			var cell_type = _get_cell(x, y)
			
			# Deterministic grass variation
			var hash_val = (x * 73856093 ^ y * 19349663) & 0x7FFFFFFF
			var grass_col = hash_val % 3 # 0, 1, or 2
			
			# Draw base grass
			var base_src = Rect2(grass_col * 16, 0, 16, 16)
			draw_texture_rect_region(tex_ground, Rect2(pos.x, pos.y, 16, 16), base_src)

			# Overlay roads / cobbles / water
			if cell_type == 1: # Dirt road
				var dirt_col = 3 + (hash_val % 2) # dirt_a or dirt_b
				var dirt_src = Rect2(dirt_col * 16, 0, 16, 16)
				draw_texture_rect_region(tex_ground, Rect2(pos.x, pos.y, 16, 16), dirt_src)
			elif cell_type == 2: # Cobble
				var cobble_src = Rect2(5 * 16, 0, 16, 16)
				draw_texture_rect_region(tex_ground, Rect2(pos.x, pos.y, 16, 16), cobble_src)
			elif cell_type == 3: # Water
				var water_tex = tex_water0 if water_frame == 0 else tex_water1
				if water_tex:
					# Use index 15 (full water) or open water
					var water_src = Rect2(3 * 16, 3 * 16, 16, 16)
					draw_texture_rect_region(water_tex, Rect2(pos.x, pos.y, 16, 16), water_src)
