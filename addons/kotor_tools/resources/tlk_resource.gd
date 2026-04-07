## Resource produced by the TLK importer.
@tool
extends Resource
class_name TLKResource

## TLK file format version string, usually "V3.0".
@export var version: String = ""

## Aurora language ID stored in the TLK header.
@export var language_id: int = 0

## Flattened talk table entries keyed by StrRef metadata.
@export var entries: Array[Dictionary] = []


## Get a string by StrRef. Returns an empty string if missing.
func get_string(strref: int) -> String:
	if strref < 0 or strref >= entries.size():
		return ""
	return String(entries[strref].get("text", ""))


## Build a compact string lookup suitable for editor tooling.
func build_lookup() -> Dictionary:
	var lookup := {}
	for entry: Dictionary in entries:
		var text := String(entry.get("text", ""))
		if text.is_empty():
			continue
		lookup[str(entry.get("strref", 0))] = text
	return lookup