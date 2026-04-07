## importers/gff_import_plugin.gd
## EditorImportPlugin for KotOR GFF-based files.
##
## Imports the following extensions as a GFFResource (Dictionary stored in a .tres):
##   .utc  Creature blueprint
##   .utd  Door blueprint
##   .ute  Encounter table
##   .uti  Item blueprint
##   .utp  Placeable blueprint
##   .uts  Sound blueprint
##   .utt  Trigger blueprint
##   .utw  Waypoint object
##   .utm  Merchant/store blueprint
##   .jrl  Journal file
##   .dlg  Dialogue tree
##   .git  Game Instance Table (area object layout)
##   .are  Area properties
##   .ifo  Module IFO
##   .gff  Generic GFF
@tool
extends EditorImportPlugin

const GFFParser := preload("../formats/gff_parser.gd")
const GFFResource := preload("../resources/gff_resource.gd")

func _get_importer_name() -> String:
	return "kotor.gff"

func _get_visible_name() -> String:
	return "KotOR GFF"

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray([
		"utc", "utd", "ute", "uti", "utp", "uts", "utt", "utw", "utm",
		"jrl", "dlg", "git", "are", "ifo", "gff",
	])

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

	var parsed := GFFParser.parse_bytes(data)
	if parsed.is_empty():
		return ERR_PARSE_ERROR

	var res := GFFResource.new()
	res.file_type = parsed.get("file_type", "")
	res.gff_data  = parsed.get("root", {})

	return ResourceSaver.save(res, "%s.%s" % [save_path, _get_save_extension()])
