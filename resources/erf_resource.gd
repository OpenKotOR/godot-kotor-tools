## resources/erf_resource.gd
## Resource produced by the ERF importer; describes the manifest of an ERF/RIM.
@tool
extends Resource
class_name ErfResource

## FileType tag: "ERF ", "RIM ", "MOD ", "SAV ".
@export var file_type: String = ""

## Absolute path to the original .erf/.rim file on disk (needed for read_entry).
@export var source_path: String = ""

## Flat entry manifest: Array of { resref, ext, offset, size }
@export var entries: Array[Dictionary] = []


func add_entry(resref: String, ext: String, offset: int, size: int) -> void:
	entries.append({ "resref": resref, "ext": ext, "offset": offset, "size": size })


## Read raw bytes for an entry by resref name (case-insensitive).
## Returns an empty PackedByteArray if not found or file unreadable.
func get_entry_data(resref: String) -> PackedByteArray:
	var lower := resref.to_lower()
	for e: Dictionary in entries:
		if (e["resref"] as String).to_lower() == lower:
			var f := FileAccess.open(source_path, FileAccess.READ)
			if f == null:
				return PackedByteArray()
			f.seek(e["offset"])
			var data := f.get_buffer(e["size"])
			f.close()
			return data
	return PackedByteArray()
