class_name BattleGrid
extends RefCounted
## Uniform bucket grid over the field, rebuilt every tick in O(n) by a counting sort, so
## neighbour queries only look at nearby cells. Points outside the field use the edge cells.

var cell_size: float
var cols: int
var rows: int
## Items of cell i are items[cell_start[i] .. cell_start[i + 1] - 1].
var cell_start: PackedInt32Array = []
var items: PackedInt32Array = []

var _cell_of: PackedInt32Array = []
var _cursor: PackedInt32Array = []


func _init(field_size: Vector2, size: float) -> void:
	cell_size = size
	cols = maxi(1, ceili(field_size.x / size))
	rows = maxi(1, ceili(field_size.y / size))
	cell_start.resize(cols * rows + 1)


func cell_x(x: float) -> int:
	return clampi(floori(x / cell_size), 0, cols - 1)


func cell_y(y: float) -> int:
	return clampi(floori(y / cell_size), 0, rows - 1)


## Indexes every point whose include flag is non-zero.
func rebuild(points: PackedVector2Array, include: PackedByteArray) -> void:
	var count := points.size()
	_cell_of.resize(count)
	cell_start.fill(0)
	for i: int in count:
		if include[i] == 0:
			_cell_of[i] = -1
			continue
		var cell := cell_y(points[i].y) * cols + cell_x(points[i].x)
		_cell_of[i] = cell
		cell_start[cell + 1] += 1
	for cell: int in cols * rows:
		cell_start[cell + 1] += cell_start[cell]
	items.resize(cell_start[cols * rows])
	_cursor = cell_start.duplicate()
	for i: int in count:
		var cell := _cell_of[i]
		if cell >= 0:
			items[_cursor[cell]] = i
			_cursor[cell] += 1


## Indexed points in all cells touching the square around center; not distance-filtered.
func query(center: Vector2, reach: float) -> PackedInt32Array:
	var result := PackedInt32Array()
	for gy: int in range(cell_y(center.y - reach), cell_y(center.y + reach) + 1):
		for gx: int in range(cell_x(center.x - reach), cell_x(center.x + reach) + 1):
			var cell := gy * cols + gx
			for k: int in range(cell_start[cell], cell_start[cell + 1]):
				result.append(items[k])
	return result
