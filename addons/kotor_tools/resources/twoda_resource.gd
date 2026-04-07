## resources/twoda_resource.gd
## Resource produced by the 2DA importer.
@tool
extends Resource
class_name TwoDaResource

## Ordered column headers matching the 2DA file.
@export var columns: PackedStringArray = PackedStringArray()

## Row data — Array of Dictionary keyed by column name.
## null values indicate "****" (undefined/empty) cells.
@export var rows: Array[Dictionary] = []

## DEFAULT value declared at the top of the 2DA (or "" if absent).
@export var default_val: String = ""


## Get a cell by row index and column name.  Returns null for empty cells.
func get_cell(row: int, col: String) -> Variant:
	if row < 0 or row >= rows.size():
		return null
	return rows[row].get(col, null)


## Count of data rows.
func row_count() -> int:
	return rows.size()
