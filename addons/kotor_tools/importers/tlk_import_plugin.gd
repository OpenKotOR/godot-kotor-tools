## EditorImportPlugin for KotOR TLK talk tables.
##
## Imports .tlk as a TLKResource for editor browsing and tooling.
@tool
extends EditorImportPlugin

const TLKParser := preload("../formats/tlk_parser.gd")
const TLKResource := preload("../resources/tlk_resource.gd")


func _get_importer_name() -> String:
	return "kotor.tlk"


func _get_visible_name() -> String:
	return "KotOR TLK Talk Table"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["tlk"])


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
		save_path: String,
		_options: Dictionary,
		_platform_variants: Array[String],
		_gen_files: Array[String]
) -> Error:
	var parsed := TLKParser.parse_file(source_file)
	if parsed.is_empty():
		return ERR_PARSE_ERROR

	var res := TLKResource.new()
	res.version = parsed.get("version", "")
	res.language_id = parsed.get("language_id", 0)
	for entry: TLKParser.TLKEntry in parsed.get("entries", []):
		res.entries.append({
			"strref": entry.strref,
			"flags": entry.flags,
			"sound_resref": entry.sound_resref,
			"offset": entry.offset,
			"size": entry.size,
			"sound_length": entry.sound_length,
			"text": entry.text,
		})

	return ResourceSaver.save(res as Resource, "%s.%s" % [save_path, _get_save_extension()])