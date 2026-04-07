## importers/tpc_import_plugin.gd
## EditorImportPlugin for KotOR TPC texture files.
##
## Imports .tpc as a CompressedTexture2D-compatible resource via ImageTexture.
@tool
extends EditorImportPlugin

const TPCReader := preload("../formats/tpc_reader.gd")

func _get_importer_name() -> String:
	return "kotor.tpc"

func _get_visible_name() -> String:
	return "KotOR TPC Texture"

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["tpc"])

func _get_save_extension() -> String:
	return "res"

func _get_resource_type() -> String:
	return "ImageTexture"

func _get_preset_count() -> int:
	return 1

func _get_preset_name(_preset_index: int) -> String:
	return "Default"

func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return [
		{
			"name": "generate_mipmaps",
			"default_value": true,
			"property_hint": PROPERTY_HINT_NONE,
			"hint_string": "",
			"usage": PROPERTY_USAGE_DEFAULT,
		},
		{
			"name": "srgb",
			"default_value": true,
			"property_hint": PROPERTY_HINT_NONE,
			"hint_string": "",
			"usage": PROPERTY_USAGE_DEFAULT,
		},
	]

func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary) -> bool:
	return true

func _get_import_order() -> int:
	return 0

func _get_priority() -> float:
	return 1.0

func _import(
		source_file: String,
		save_path:   String,
		options:     Dictionary,
		_platform_variants: Array[String],
		_gen_files:         Array[String]
) -> Error:
	var f := FileAccess.open(source_file, FileAccess.READ)
	if f == null:
		return ERR_FILE_CANT_READ
	var data := f.get_buffer(f.get_length())
	f.close()

	var tex := TPCReader.read_bytes(data)
	if tex == null:
		return ERR_PARSE_ERROR

	if options.get("generate_mipmaps", true):
		var img := tex.get_image()
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)

	return ResourceSaver.save(tex, "%s.%s" % [save_path, _get_save_extension()])
