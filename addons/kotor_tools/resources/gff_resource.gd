## resources/gff_resource.gd
## Resource container produced by the GFF importer.
@tool
extends Resource
class_name GFFResource

## Four-character GFF type tag (e.g. "UTC", "DLG", "GIT").
@export var file_type: String = ""

## Root struct as a recursive Dictionary — mirrors CResGFF::GetTopLevelStruct output.
@export var gff_data: Dictionary = {}
