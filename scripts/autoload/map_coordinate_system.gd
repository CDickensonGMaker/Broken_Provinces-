## map_coordinate_system.gd - Handles grid to pixel coordinate conversion for painted world map
## Simple direct mapping: 20x20 grid on 1080x1080 image = 54 pixels per cell
extends Node

## Map dimensions (matches painted map)
var image_size: Vector2i = Vector2i(1080, 1080)
var grid_size: Vector2i = Vector2i(20, 20)

## Pixels per grid cell (calculated from image/grid size)
var cell_size: float = 54.0  # 1080 / 20 = 54

## Whether system is ready
var is_initialized: bool = false


func _ready() -> void:
	_initialize()


## Initialize with direct grid math
func _initialize() -> void:
	cell_size = float(image_size.x) / float(grid_size.x)
	is_initialized = true
	print("[MapCoordinateSystem] Initialized: %dx%d grid, %.1f pixels per cell" % [
		grid_size.x, grid_size.y, cell_size
	])


## Convert grid coordinates (col, row) to pixel position on map image
## Returns center of the cell
func grid_to_pixel(col: int, row: int) -> Vector2:
	var pixel_x: float = float(col) * cell_size + cell_size / 2.0
	var pixel_y: float = float(row) * cell_size + cell_size / 2.0
	return Vector2(pixel_x, pixel_y)


## Convert grid coordinates as Vector2i to pixel position
func grid_to_pixel_v(grid: Vector2i) -> Vector2:
	return grid_to_pixel(grid.x, grid.y)


## Alias for compatibility - same as grid_to_pixel_v
func hex_to_pixel_v(coords: Vector2i) -> Vector2:
	return grid_to_pixel_v(coords)


## Convert pixel position on map image to grid coordinates
func pixel_to_grid(pixel: Vector2) -> Vector2i:
	var col: int = int(pixel.x / cell_size)
	var row: int = int(pixel.y / cell_size)
	# Clamp to valid grid range
	col = clampi(col, 0, grid_size.x - 1)
	row = clampi(row, 0, grid_size.y - 1)
	return Vector2i(col, row)


## Alias for compatibility
func pixel_to_hex(pixel: Vector2) -> Vector2i:
	return pixel_to_grid(pixel)


## Check if a pixel position is within the map image bounds
func is_pixel_in_bounds(pixel: Vector2) -> bool:
	return pixel.x >= 0 and pixel.x < image_size.x and pixel.y >= 0 and pixel.y < image_size.y


## Check if grid coordinates are within bounds
func is_grid_in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < grid_size.x and row >= 0 and row < grid_size.y


## Check if grid coordinates as Vector2i are within bounds
func is_grid_in_bounds_v(grid: Vector2i) -> bool:
	return is_grid_in_bounds(grid.x, grid.y)


## Get the image size
func get_image_size() -> Vector2i:
	return image_size


## Get the grid size
func get_grid_size() -> Vector2i:
	return grid_size


## Get the cell size in pixels
func get_scale() -> Vector2:
	return Vector2(cell_size, cell_size)


## Get distance in pixels for a given grid distance
func grid_distance_to_pixels(grid_distance: float) -> float:
	return grid_distance * cell_size


## Alias for compatibility
func hex_distance_to_pixels(distance: float) -> float:
	return grid_distance_to_pixels(distance)
