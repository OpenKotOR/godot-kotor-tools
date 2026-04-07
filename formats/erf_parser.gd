## formats/erf_parser.gd
## ERF / RIM / MOD / SAV container parser.
##
## Mirrors CERFFile from K1_GOG_swkotor:
##   CERFFile ctor        @ 0x005dd9c0
##   ExportFilesFromERF   @ 0x005dd710
##
## File layout (V1.0, 160-byte header):
##   0x00 char[4]  FileType       ; "ERF ", "MOD ", "SAV ", "RIM "
##   0x04 char[4]  Version        ; "V1.0"
##   0x08 uint32   LanguageCount
##   0x0C uint32   LocalizedStringSize
##   0x10 uint32   EntryCount
##   0x14 uint32   OffsetToLocalizedString
##   0x18 uint32   OffsetToKeyList
##   0x1C uint32   OffsetToResourceList
##   0x20 uint32   BuildYear
##   0x24 uint32   BuildDay
##   0x28 uint32   DescriptionStrRef
##   0x2C byte[116] Reserved  → total header = 160 bytes (0xA0)
##
## Key entry (24 bytes):
##   char[16] ResRef          ; resource name, null-padded
##   uint32   ResourceID      ; unique ID (arbitrary)
##   uint16   ResourceType
##   uint16   Unused
##
## Resource entry (8 bytes):
##   uint32   OffsetToResource
##   uint32   ResourceSize
##
## RIM format (V1.0, identical layout but FileType = "RIM ").
class_name ERFParser

# --------------------------------------------------------------------------- #
# Resource type → file extension table
# Sourced from K1 CResRef type constants (see also ResTypes enum in Aurora SDK)
# --------------------------------------------------------------------------- #
const RES_TYPES: Dictionary = {
	0x0001: "bmp",
	0x0003: "tga",
	0x0004: "wav",
	0x0005: "plt",
	0x0006: "ini",
	0x0007: "txt",
	0x000A: "mdl",
	0x000B: "nss",
	0x000C: "ncs",
	0x000D: "mod",
	0x000E: "are",
	0x000F: "set",
	0x0010: "ifo",
	0x0011: "bic",
	0x0012: "wok",
	0x0018: "2da",
	0x001A: "ssf",
	0x001C: "tlk",
	0x001F: "txi",
	0x0020: "utc",
	0x0022: "dlg",
	0x0023: "itp",
	0x0025: "utp",
	0x0026: "dft",
	0x0027: "git",
	0x0028: "uti",
	0x0029: "uta",
	0x002A: "jrl",
	0x002B: "uts",
	0x002C: "utt",
	0x002D: "utm",
	0x002E: "ute",
	0x002F: "utd",
	0x0030: "utw",
	0x0031: "uto",
	0x07E6: "lyt",
	0x07E7: "vis",
	0x07EA: "mp3",
	0x07EE: "tpc",
	0x07EF: "mdx",
	0x07F0: "wlk",
	0x07F1: "xml",
	0x07F2: "scc",
	0x07FA: "pth",
	0x07FB: "lip",
	0x07FE: "tga",
}

# --------------------------------------------------------------------------- #
# Data class for a single resource entry
# --------------------------------------------------------------------------- #
class ERFEntry:
	var resref:        String
	var resource_id:   int
	var resource_type: int
	var extension:     String
	var offset:        int
	var size:          int
	var data_ref: PackedByteArray  ## source file bytes; set by parse_bytes()

	## Read this entry's raw bytes from the source data.
	func read_data() -> PackedByteArray:
		if data_ref.is_empty() or offset < 0 or size <= 0:
			return PackedByteArray()
		return data_ref.slice(offset, offset + size)


# --------------------------------------------------------------------------- #
# Public API
# --------------------------------------------------------------------------- #

## Parse an ERF/RIM/MOD/SAV from raw bytes.
## Returns a Dictionary:
##   "file_type"   : String   ("ERF ", "RIM ", ...)
##   "version"     : String   ("V1.0")
##   "entries"     : Array[ERFEntry]
## Returns {} on failure.
static func parse_bytes(data: PackedByteArray) -> Dictionary:
	if data.size() < 160:
		push_error("ERFParser: data too small (%d bytes)" % data.size())
		return {}

	var file_type  := _read_text(data, 0, 4)
	var version    := _read_text(data, 4, 4)
	if version != "V1.0":
		push_error("ERFParser: unsupported version '%s'" % version)
		return {}

	var entry_count          := _u32(data, 0x10)
	var offset_to_keys       := _u32(data, 0x18)
	var offset_to_resources  := _u32(data, 0x1C)

	var entries: Array[ERFEntry] = []
	for i in entry_count:
		var e         := ERFEntry.new()
		var kbase     := offset_to_keys + i * 24
		var rbase     := offset_to_resources + i * 8

		e.resref        = _read_text(data, kbase,      16)
		e.resource_id   = _u32(data, kbase + 16)
		e.resource_type = _u16(data, kbase + 20)
		e.extension     = RES_TYPES.get(e.resource_type, "bin")
		e.offset        = _u32(data, rbase)
		e.size          = _u32(data, rbase + 4)
		e.data_ref      = data           # keep reference so read_data() works
		entries.append(e)

	return {
		"file_type": file_type,
		"version":   version,
		"entries":   entries,
	}


## Parse an ERF/RIM from a file path.
static func parse_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("ERFParser: cannot open '%s'" % path)
		return {}
	var data := f.get_buffer(f.get_length())
	f.close()
	return parse_bytes(data)


## Find an entry by resref name (case-insensitive).
static func find_entry(result: Dictionary, resref: String) -> ERFEntry:
	var lower := resref.to_lower()
	for e: ERFEntry in result.get("entries", []):
		if e.resref.to_lower() == lower:
			return e
	return null


## Extract all entries from an ERF/RIM into a directory on disk.
static func extract_all(result: Dictionary, dest_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dest_dir)
	for e: ERFEntry in result.get("entries", []):
		var bytes := e.read_data()
		var out_path := dest_dir.path_join("%s.%s" % [e.resref, e.extension])
		var fw := FileAccess.open(out_path, FileAccess.WRITE)
		if fw:
			fw.store_buffer(bytes)
			fw.close()
		else:
			push_error("ERFParser: could not write '%s'" % out_path)


# --------------------------------------------------------------------------- #
# Binary helpers — little-endian
# --------------------------------------------------------------------------- #

static func _u32(data: PackedByteArray, offset: int) -> int:
	if offset + 4 > data.size():
		return 0
	return (data[offset]
		| (data[offset + 1] << 8)
		| (data[offset + 2] << 16)
		| (data[offset + 3] << 24)) & 0xFFFFFFFF


static func _u16(data: PackedByteArray, offset: int) -> int:
	if offset + 2 > data.size():
		return 0
	return (data[offset] | (data[offset + 1] << 8)) & 0xFFFF


static func _read_text(data: PackedByteArray, offset: int, length: int) -> String:
	var txt := ""
	var end := mini(offset + length, data.size())
	for i in range(offset, end):
		if data[i] == 0:
			break
		txt += char(data[i])
	return txt
