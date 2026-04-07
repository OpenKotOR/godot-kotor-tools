## formats/key_bif_parser.gd
## KEY / BIF resource database parser.
##
## KEY file (chitin.key / dialog.tlk companion index):
##   0x00 char[4]  FileType    ; "KEY "
##   0x04 char[4]  Version     ; "V1.0"
##   0x08 uint32   BIFCount
##   0x0C uint32   KeyCount
##   0x10 uint32   OffsetToFileTable
##   0x14 uint32   OffsetToKeyTable
##   0x18 uint32   BuildYear
##   0x1C uint32   BuildDay
##   0x20 byte[32] Reserved
##
## BIF entry (12 bytes):
##   uint32  FileSize
##   uint32  FilenameOffset   ; offset from start of filename section
##   uint16  FilenameSize     ; byte length including null
##   uint16  Drives           ; bitmask of drive types; 0x1 = HD
##
## Key entry (22 bytes):
##   char[16] ResRef
##   uint16   ResourceType
##   uint32   ResID           ; bits 31-20 = BIF index; bits 19-0 = fixed-res index in BIF
##
## BIF file (data*.bif):
##   0x00 char[4]  FileType   ; "BIFF"
##   0x04 char[4]  Version    ; "V1.0"
##   0x08 uint32   VarResCount
##   0x0C uint32   FixedResCount  ; always 0 in KotOR
##   0x10 uint32   VariableTableOffset
##
## VarRes entry (20 bytes):
##   uint32  ResID
##   uint32  Offset
##   uint32  FileSize
##   uint16  ResourceType
##   uint16  Unused
class_name KEYBIFParser

# --------------------------------------------------------------------------- #
# Data classes
# --------------------------------------------------------------------------- #

class BIFEntry:
	var filename:   String
	var file_size:  int
	var drives:     int

class KEYEntry:
	var resref:         String
	var resource_type:  int
	var res_id:         int
	## BIF index extracted from res_id bits 31-20
	var bif_index: int:
		get: return (res_id >> 20) & 0xFFF
	## Fixed-resource index within the BIF, bits 19-0
	var fixed_index: int:
		get: return res_id & 0xFFFFF

class BIFResEntry:
	var res_id:         int
	var offset:         int
	var file_size:      int
	var resource_type:  int

# --------------------------------------------------------------------------- #
# Public API — KEY
# --------------------------------------------------------------------------- #

## Parse a KEY file (chitin.key) from bytes.
## Returns:
##   "bif_entries" : Array[BIFEntry]
##   "key_entries" : Array[KEYEntry]
static func parse_key_bytes(data: PackedByteArray) -> Dictionary:
	if data.size() < 64:
		push_error("KEYBIFParser: KEY data too small")
		return {}

	var file_type := _read_text(data, 0, 4)
	if file_type != "KEY ":
		push_error("KEYBIFParser: bad KEY magic '%s'" % file_type)
		return {}

	var bif_count        := _u32(data, 0x08)
	var key_count        := _u32(data, 0x0C)
	var offset_filetable := _u32(data, 0x10)
	var offset_keytable  := _u32(data, 0x14)

	# --- Parse BIF entries ---
	var bif_entries: Array[BIFEntry] = []
	var fn_offsets: Array[int] = []
	var fn_sizes:   Array[int] = []
	for i in bif_count:
		var base := offset_filetable + i * 12
		var be         := BIFEntry.new()
		be.file_size   = _u32(data, base + 0)
		fn_offsets.append(_u32(data, base + 4))
		fn_sizes.append(_u16(data, base + 8))
		be.drives      = _u16(data, base + 10)
		bif_entries.append(be)

	# Filename strings follow immediately after the BIF entry table
	var fn_section_base := offset_filetable + bif_count * 12
	for i in bif_count:
		var off := fn_section_base + fn_offsets[i]
		bif_entries[i].filename = _read_text(data, off, fn_sizes[i])

	# --- Parse KEY entries ---
	var key_entries: Array[KEYEntry] = []
	for i in key_count:
		var base := offset_keytable + i * 22
		var ke             := KEYEntry.new()
		ke.resref          = _read_text(data, base, 16)
		ke.resource_type   = _u16(data, base + 16)
		ke.res_id          = _u32(data, base + 18)
		key_entries.append(ke)

	return {
		"bif_entries": bif_entries,
		"key_entries": key_entries,
	}


## Parse a KEY file from disk.
static func parse_key_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("KEYBIFParser: cannot open '%s'" % path)
		return {}
	var data := f.get_buffer(f.get_length())
	f.close()
	return parse_key_bytes(data)


# --------------------------------------------------------------------------- #
# Public API — BIF
# --------------------------------------------------------------------------- #

## Parse a BIF file from bytes.
## Returns:
##   "var_entries" : Array[BIFResEntry]
static func parse_bif_bytes(data: PackedByteArray) -> Dictionary:
	if data.size() < 20:
		push_error("KEYBIFParser: BIF data too small")
		return {}

	var file_type := _read_text(data, 0, 4)
	if file_type != "BIFF":
		push_error("KEYBIFParser: bad BIFF magic '%s'" % file_type)
		return {}

	var var_count  := _u32(data, 0x08)
	# var fixed_count := _u32(data, 0x0C)  # always 0 in KotOR
	var var_offset := _u32(data, 0x10)

	var entries: Array[BIFResEntry] = []
	for i in var_count:
		var base := var_offset + i * 16
		var e            := BIFResEntry.new()
		e.res_id         = _u32(data, base + 0)
		e.offset         = _u32(data, base + 4)
		e.file_size      = _u32(data, base + 8)
		e.resource_type  = _u16(data, base + 12)
		# Unused uint16 at base+14
		entries.append(e)

	return { "var_entries": entries }


## Parse a BIF file from disk.
static func parse_bif_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("KEYBIFParser: cannot open '%s'" % path)
		return {}
	var data := f.get_buffer(f.get_length())
	f.close()
	return parse_bif_bytes(data)


## Given a parsed KEY result and a resref+type, find the KEYEntry and return it.
static func find_key_entry(key_result: Dictionary, resref: String, res_type: int) -> KEYEntry:
	var lower := resref.to_lower()
	for e: KEYEntry in key_result.get("key_entries", []):
		if e.resref.to_lower() == lower and e.resource_type == res_type:
			return e
	return null


## Given KEY + BIF data, extract the raw bytes for a resource.
## key_result   = result of parse_key_bytes()
## bif_data     = Dictionary keyed by BIF index → PackedByteArray raw bif bytes
static func extract_resource(
	key_result: Dictionary,
	bif_data:   Dictionary,
	resref:     String,
	res_type:   int
) -> PackedByteArray:
	var ke := find_key_entry(key_result, resref, res_type)
	if ke == null:
		push_error("KEYBIFParser: resref '%s' (type %d) not found in KEY" % [resref, res_type])
		return PackedByteArray()

	var bi := ke.bif_index
	if not bif_data.has(bi):
		push_error("KEYBIFParser: BIF index %d not loaded" % bi)
		return PackedByteArray()

	var bif_result := parse_bif_bytes(bif_data[bi] as PackedByteArray)
	for e: BIFResEntry in bif_result.get("var_entries", []):
		if (e.res_id & 0xFFFFF) == ke.fixed_index:
			return (bif_data[bi] as PackedByteArray).slice(e.offset, e.offset + e.file_size)

	push_error("KEYBIFParser: fixed index %d not found in BIF %d" % [ke.fixed_index, bi])
	return PackedByteArray()


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
