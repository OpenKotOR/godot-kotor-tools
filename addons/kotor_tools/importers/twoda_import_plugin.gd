## importers/twoda_import_plugin.gd
## EditorImportPlugin for KotOR 2DA files.
##
## Imports .2da as a TwoDaResource (column headers + row data).
@tool
extends EditorImportPlugin

const TwoDaParser   := preload("../formats/twoda_parser.gd")
const TwoDaResource := preload("../resources/twoda_resource.gd")

func _get_importer_name() -> String:
	return "kotor.2da"

func _get_visible_name() -> String:
	return "KotOR 2DA Table"

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["2da"])

func _get_save_extension() -> String:
	return "tres"

func _get_resource_type() -> String:
	return "Resource"

func _get_preset_count() -> int:
	return 1

func _get_preset_name(_preset_index: int) -> String:
	return "Default"

func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return []

func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary) -> bool:
	return true

func _get_import_order() -> int:
	return 0

func _get_priority() -> float:
	return 1.0

func _import(
		source_file: String,
		save_path:   String,
		_options:    Dictionary,
		_platform_variants: Array[String],
		_gen_files:         Array[String]
) -> Error:
	var f := FileAccess.open(source_file, FileAccess.READ)
	if f == null:
		return ERR_FILE_CANT_READ
	var text := f.get_as_text()
	f.close()

	var parsed := TwoDaParser.parse_string(text)
	if parsed.is_empty():
		return ERR_PARSE_ERROR

	var res          := TwoDaResource.new()
	res.columns      = parsed.get("columns", PackedStringArray())
	res.rows         = parsed.get("rows", [])
	res.default_val  = parsed.get("default", "")

	return ResourceSaver.save(res, "%s.%s" % [save_path, _get_save_extension()])
