## importers/erf_import_plugin.gd
## EditorImportPlugin for KotOR ERF/RIM/MOD/SAV container files.
##
## Imports .erf / .rim / .mod / .sav as an ErfResource that carries a manifest
## of contained entries.  The raw bytes of each entry are accessible via
## ErfResource.get_entry_data(resref, extension).
@tool
extends EditorImportPlugin

const ERFParser   := preload("../formats/erf_parser.gd")
const ErfResource := preload("../resources/erf_resource.gd")

func _get_importer_name() -> String:
	return "kotor.erf"

func _get_visible_name() -> String:
	return "KotOR ERF/RIM Container"

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["erf", "rim", "mod", "sav"])

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
	var data := f.get_buffer(f.get_length())
	f.close()

	var parsed := ERFParser.parse_bytes(data)
	if parsed.is_empty():
		return ERR_PARSE_ERROR

	var res          := ErfResource.new()
	res.file_type    = parsed.get("file_type", "")
	res.source_path  = source_file
	var entries: Array = parsed.get("entries", [])
	for e: ERFParser.ERFEntry in entries:
		res.add_entry(e.resref, e.extension, e.offset, e.size)

	return ResourceSaver.save(res, "%s.%s" % [save_path, _get_save_extension()])
