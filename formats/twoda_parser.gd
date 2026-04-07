## formats/twoda_parser.gd
## 2DA V2.0 text-table parser.
##
## Mirrors C2DA::Load2DArray from K1_GOG_swkotor @ 0x004143b0.
##
## File layout (plain ASCII text):
##   Line 1:  "2DA V2.0\r\n" or "2DA V2.0\n"
##   Line 2:  blank OR "DEFAULT: <value>"
##   Line 3:  column headers separated by whitespace (NOT padded — just tokens)
##   Line 4+: <row_index> <col0_val> <col1_val> ... (row_index is ignored)
##
## Values of "****" are treated as "empty" / undefined (Aurora convention).
## Quoted values ("some string") are supported.
##
## The parser returns a Dictionary:
##   "columns"  : PackedStringArray   ordered column headers
##   "rows"     : Array[Dictionary]   each dict is { col_name: value }
##   "default"  : String              default value (or "" if not specified)
class_name TwoDaParser

const EMPTY_VALUE := "****"

# --------------------------------------------------------------------------- #
# Public API
# --------------------------------------------------------------------------- #

## Parse 2DA text from a raw string.
## Returns: { "columns": [...], "rows": [...], "default": "..." }
static func parse_string(text: String) -> Dictionary:
	# Normalise line endings
	var lines := text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	if lines.is_empty():
		return _empty()

	# Line 0: version header
	if not lines[0].strip_edges().begins_with("2DA"):
		push_error("TwoDaParser: missing 2DA header")
		return _empty()

	var default_val := ""
	var col_line_idx := 2

	# Line 1: blank or DEFAULT
	if lines.size() > 1:
		var l1 := lines[1].strip_edges()
		if l1.begins_with("DEFAULT:"):
			default_val = l1.substr(8).strip_edges()
			col_line_idx = 2
		elif l1.begins_with("DEFAULT"):
			# Some files separate DEFAULT and the value with whitespace
			var toks := _tokenize(l1)
			if toks.size() >= 2:
				default_val = toks[1]
			col_line_idx = 2

	# Line col_line_idx: column headers
	if lines.size() <= col_line_idx:
		return _empty()

	var columns := PackedStringArray(_tokenize(lines[col_line_idx]))

	# Remaining lines: data rows
	var rows: Array[Dictionary] = []
	for i in range(col_line_idx + 1, lines.size()):
		var tokens := _tokenize(lines[i])
		if tokens.is_empty():
			continue
		# First token is the row index — skip it
		var row: Dictionary = {}
		for ci in columns.size():
			var tok := tokens[ci + 1] if ci + 1 < tokens.size() else EMPTY_VALUE
			row[columns[ci]] = tok if tok != EMPTY_VALUE else null
		rows.append(row)

	return {
		"columns": columns,
		"rows":    rows,
		"default": default_val,
	}


## Parse a 2DA file from disk.
static func parse_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("TwoDaParser: cannot open '%s'" % path)
		return _empty()
	var text := f.get_as_text()
	f.close()
	return parse_string(text)


## Parse 2DA from raw bytes (ASCII).
static func parse_bytes(data: PackedByteArray) -> Dictionary:
	return parse_string(data.get_string_from_ascii())


## Look up a cell by row index and column name.
## Returns null if the row/column doesn't exist or value is undefined.
static func get_cell(result: Dictionary, row: int, col: String) -> Variant:
	var rows: Array = result.get("rows", [])
	if row < 0 or row >= rows.size():
		return null
	return rows[row].get(col, null)


## Look up the first row where column has a specific value.
## Returns the row Dictionary, or {} if not found.
static func find_row(result: Dictionary, col: String, value: String) -> Dictionary:
	for row: Dictionary in result.get("rows", []):
		if str(row.get(col, "")) == value:
			return row
	return {}


# --------------------------------------------------------------------------- #
# Token parser matching GetNextToken() from C2DA::Load2DArray
# Handles:
#   - Whitespace-separated tokens
#   - Quoted strings: "hello world"
# --------------------------------------------------------------------------- #
static func _tokenize(line: String) -> Array[String]:
	var tokens: Array[String] = []
	var i := 0
	var n := line.length()
	while i < n:
		var c := line[i]
		if c == " " or c == "\t":
			i += 1
			continue
		if c == "\"":
			# Quoted token — read until closing quote
			i += 1
			var start := i
			while i < n and line[i] != "\"":
				i += 1
			tokens.append(line.substr(start, i - start))
			i += 1  # consume closing quote
		else:
			var start := i
			while i < n and line[i] != " " and line[i] != "\t":
				i += 1
			tokens.append(line.substr(start, i - start))
	return tokens


static func _empty() -> Dictionary:
	return { "columns": PackedStringArray(), "rows": [], "default": "" }
