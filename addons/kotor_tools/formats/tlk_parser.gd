## formats/tlk_parser.gd
## TLK V3.0 talk-table parser.
##
## Mirrors CTlkTable from K1_GOG_swkotor (class symbol @ 0x0073ecb0 = "TLK ").
##
## File layout (V3.0):
##   0x00 char[4]  FileType         ; "TLK "
##   0x04 char[4]  Version          ; "V3.0"
##   0x08 uint32   LanguageID       ; 0=English, 1=French, 2=German, etc.
##   0x0C uint32   StringCount
##   0x10 uint32   StringEntriesOffset  ; byte offset to string data section
##
## StringDataElement (40 bytes each, starting at offset 0x14):
##   0x00 uint32  Flags
##   0x04 char[16] SoundResRef       ; VO resref, null-padded
##   0x14 uint32  VolumeVariance    ; unused in KotOR
##   0x18 uint32  PitchVariance     ; unused in KotOR
##   0x1C uint32  OffsetToString    ; byte offset from StringEntriesOffset
##   0x20 uint32  StringSize        ; byte length
##   0x24 float   SoundLength       ; VO clip duration in seconds
##
## String data: raw bytes at (StringEntriesOffset + element.OffsetToString),
##              length = element.StringSize, encoding = Windows-1252 / Latin-1.
##
## StrRef 0xFFFFFFFF means "invalid / not set".
class_name TLKParser

const INVALID_STRREF := 0xFFFFFFFF
const ELEMENT_SIZE   := 40

## Flags masks for StringDataElement.Flags
const FLAG_TEXT_PRESENT  := 0x1
const FLAG_SOUND_PRESENT := 0x2
const FLAG_SOUND_LENGTH  := 0x4

# --------------------------------------------------------------------------- #
# Data class for a single TLK entry
# --------------------------------------------------------------------------- #
class TLKEntry:
	var strref:         int
	var flags:          int
	var sound_resref:   String
	var offset:         int
	var size:           int
	var sound_length:   float
	var text:           String   # populated on load

# --------------------------------------------------------------------------- #
# Public API
# --------------------------------------------------------------------------- #

## Parse a TLK file from raw bytes.
## Returns a Dictionary:
##   "version"     : String
##   "language_id" : int
##   "entries"     : Array[TLKEntry]  (indexed by StrRef)
## Returns {} on failure.
static func parse_bytes(data: PackedByteArray) -> Dictionary:
	if data.size() < 20:
		push_error("TLKParser: data too small (%d bytes)" % data.size())
		return {}

	var file_type := _read_text(data, 0, 4)
	if file_type != "TLK ":
		push_error("TLKParser: bad magic '%s'" % file_type)
		return {}

	var version        := _read_text(data, 4, 4)
	var language_id    := _u32(data, 0x08)
	var string_count   := _u32(data, 0x0C)
	var strings_offset := _u32(data, 0x10)

	var entries: Array[TLKEntry] = []
	var element_base := 0x14  # header is 20 bytes (0x14)

	for i in string_count:
		var e        := TLKEntry.new()
		var ebase    := element_base + i * ELEMENT_SIZE
		e.strref        = i
		e.flags         = _u32(data, ebase + 0x00)
		e.sound_resref  = _read_text(data, ebase + 0x04, 16)
		# 0x14 VolumeVariance, 0x18 PitchVariance — not stored, unused
		e.offset        = _u32(data, ebase + 0x1C)
		e.size          = _u32(data, ebase + 0x20)
		e.sound_length  = _u32_to_f32(_u32(data, ebase + 0x24))

		# Decode string text inline
		if e.size > 0 and (e.flags & FLAG_TEXT_PRESENT) != 0:
			var abs_off := strings_offset + e.offset
			if abs_off + e.size <= data.size():
				# Windows-1252 is ASCII-compatible for printable range
				e.text = data.slice(abs_off, abs_off + e.size).get_string_from_ascii()
		entries.append(e)

	return {
		"version":     version,
		"language_id": language_id,
		"entries":     entries,
	}


## Parse a TLK file from disk.
static func parse_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("TLKParser: cannot open '%s'" % path)
		return {}
	var data := f.get_buffer(f.get_length())
	f.close()
	return parse_bytes(data)


## Get text for a StrRef.  Returns "" for invalid or out-of-range refs.
static func get_string(result: Dictionary, strref: int) -> String:
	if strref == INVALID_STRREF or result.is_empty():
		return ""
	var entries: Array = result.get("entries", [])
	if strref < 0 or strref >= entries.size():
		return ""
	return (entries[strref] as TLKEntry).text


## Build a flat StringName→String lookup dict for quick access.
## Key is the integer StrRef formatted as a string.
static func build_lookup(result: Dictionary) -> Dictionary:
	var lookup := {}
	for e: TLKEntry in result.get("entries", []):
		if not e.text.is_empty():
			lookup[str(e.strref)] = e.text
	return lookup


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


static func _u32_to_f32(v: int) -> float:
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.put_32(v)
	buf.seek(0)
	return buf.get_float()


static func _read_text(data: PackedByteArray, offset: int, length: int) -> String:
	var txt := ""
	var end := mini(offset + length, data.size())
	for i in range(offset, end):
		if data[i] == 0:
			break
		txt += char(data[i])
	return txt
