## formats/gff_parser.gd
## GFF V3.2 binary parser.
##
## Mirrors the CResGFF in-memory layout from K1_GOG_swkotor:
##   CResGFF ctor          @ 0x00410630
##   ReadFieldBYTE         @ 0x00411a60
##   ReadFieldCHAR         @ 0x00411ad0
##   ReadFieldWORD         @ 0x00411b40
##   ReadFieldSHORT        @ 0x00411bb0
##   ReadFieldDWORD        @ 0x00411c20
##   ReadFieldINT          @ 0x00411c90
##   ReadFieldFLOAT        @ 0x00411d00
##   ReadFieldDWORD64      @ 0x00411d70
##   ReadFieldCResRef      @ 0x00411e10
##   ReadFieldCExoString   @ 0x00411ec0
##   ReadFieldCExoLocString@ 0x00411fd0
##   ReadFieldQuaternion   @ 0x004121b0
##   ReadFieldVector       @ 0x004122a0
##   ReadFieldVOID         @ 0x00412380
##
## File layout (V3.2):
##   Offset 0x00 : char[4]  FileType    (e.g. "UTC ", "UTD ", "GFF ")
##   Offset 0x04 : char[4]  FileVersion ("V3.2")
##   Offset 0x08 : uint32   StructOffset
##   Offset 0x0C : uint32   StructCount
##   Offset 0x10 : uint32   FieldOffset
##   Offset 0x14 : uint32   FieldCount
##   Offset 0x18 : uint32   LabelOffset
##   Offset 0x1C : uint32   LabelCount
##   Offset 0x20 : uint32   FieldDataOffset
##   Offset 0x24 : uint32   FieldDataCount  (byte length)
##   Offset 0x28 : uint32   FieldIndicesOffset
##   Offset 0x2C : uint32   FieldIndicesCount (byte length)
##   Offset 0x30 : uint32   ListIndicesOffset
##   Offset 0x34 : uint32   ListIndicesCount  (byte length)
##
## Struct entry (12 bytes):
##   uint32  Type        ; 0xFFFFFFFF = top-level struct
##   uint32  DataOrOffset; if FieldCount==1: direct field index;
##             else: byte offset into FieldIndicesData
##   uint32  FieldCount
##
## Field entry (12 bytes):
##   uint32  Type
##   uint32  LabelIndex
##   uint32  DataOrOffset ; simple types stored inline; complex types = byte offset into FieldData
##
## Label entry (16 bytes):
##   char[16] null-terminated name
##
## GFF field types:
##   0x00 = BYTE       0x01 = CHAR       0x02 = WORD       0x03 = SHORT
##   0x04 = DWORD      0x05 = INT        0x06 = DWORD64    0x07 = INT64
##   0x08 = FLOAT      0x09 = DOUBLE     0x0A = CExoString 0x0B = CResRef
##   0x0C = CExoLocString  0x0D = VOID   0x0E = Struct     0x0F = List
##   0x10 = Orientation (Quaternion)     0x11 = Vector
class_name GFFParser

# --------------------------------------------------------------------------- #
# Constants
# --------------------------------------------------------------------------- #
const FIELD_BYTE        := 0x00
const FIELD_CHAR        := 0x01
const FIELD_WORD        := 0x02
const FIELD_SHORT       := 0x03
const FIELD_DWORD       := 0x04
const FIELD_INT         := 0x05
const FIELD_DWORD64     := 0x06
const FIELD_INT64       := 0x07
const FIELD_FLOAT       := 0x08
const FIELD_DOUBLE      := 0x09
const FIELD_CEXOSTRING  := 0x0A
const FIELD_CRESREF     := 0x0B
const FIELD_CEXOLOCSTR  := 0x0C
const FIELD_VOID        := 0x0D
const FIELD_STRUCT      := 0x0E
const FIELD_LIST        := 0x0F
const FIELD_QUATERNION  := 0x10
const FIELD_VECTOR      := 0x11

# Internally-stored (inline in DataOrOffset dword) types — all <= 4 bytes
const _SIMPLE_TYPES := [
	FIELD_BYTE, FIELD_CHAR, FIELD_WORD, FIELD_SHORT,
	FIELD_DWORD, FIELD_INT, FIELD_FLOAT,
]

# --------------------------------------------------------------------------- #
# Public API
# --------------------------------------------------------------------------- #

## Parse GFF from raw bytes.
## Returns a Dictionary with keys:
##   "file_type" : String  (4-char tag, e.g. "UTC ")
##   "version"   : String  ("V3.2")
##   "root"      : Dictionary  (recursive struct tree)
## Returns {} on failure.
static func parse_bytes(data: PackedByteArray) -> Dictionary:
	if data.size() < 56:
		push_error("GFFParser: data too small (%d bytes)" % data.size())
		return {}

	var file_type := _read_text(data, 0, 4)
	var version   := _read_text(data, 4, 4)
	if version != "V3.2":
		push_error("GFFParser: unsupported version %s" % version)
		return {}

	var struct_off   := _u32(data, 0x08)
	var struct_count := _u32(data, 0x0C)
	var field_off    := _u32(data, 0x10)
	var field_count  := _u32(data, 0x14)
	var label_off    := _u32(data, 0x18)
	var label_count  := _u32(data, 0x1C)
	var fdata_off    := _u32(data, 0x20)
	# var fdata_count  := _u32(data, 0x24)  # byte length, not used directly
	var findices_off := _u32(data, 0x28)
	# var findices_count := _u32(data, 0x2C)
	var lindices_off := _u32(data, 0x30)
	# var lindices_count := _u32(data, 0x34)

	if struct_count == 0:
		push_error("GFFParser: no structs in file")
		return {}

	# Build label lookup array
	var labels: Array[String] = []
	for i in label_count:
		labels.append(_read_text(data, label_off + i * 16, 16))

	# Parse the top-level struct (struct 0)
	var root := _parse_struct(
		data, 0,
		struct_off, field_off, fdata_off, findices_off, lindices_off,
		labels
	)

	return {
		"file_type": file_type.strip_edges(),
		"version": version,
		"root": root,
	}


## Parse GFF from a file path on disk.
static func parse_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("GFFParser: cannot open '%s'" % path)
		return {}
	var data := f.get_buffer(f.get_length())
	f.close()
	return parse_bytes(data)


# --------------------------------------------------------------------------- #
# Internal struct/field parsers
# --------------------------------------------------------------------------- #

static func _parse_struct(
		data: PackedByteArray,
		struct_idx: int,
		struct_off: int, field_off: int, fdata_off: int,
		findices_off: int, lindices_off: int,
		labels: Array[String]
) -> Dictionary:
	var base  := struct_off + struct_idx * 12
	# var stype := _u32(data, base + 0)  # type tag; 0xFFFFFFFF = top-level
	var data_or_off := _u32(data, base + 4)
	var field_count := _u32(data, base + 8)

	var result := {}

	if field_count == 0:
		return result

	var field_indices: Array[int] = []
	if field_count == 1:
		field_indices = [data_or_off]
	else:
		# data_or_off is byte offset into FieldIndicesData
		for k in field_count:
			field_indices.append(_u32(data, findices_off + data_or_off + k * 4))

	for fi in field_indices:
		var fbase      := field_off + fi * 12
		var ftype      := _u32(data, fbase + 0)
		var label_idx  := _u32(data, fbase + 4)
		var f_data_val := _u32(data, fbase + 8)   # raw dword — meaning depends on ftype
		var label      := labels[label_idx] if label_idx < labels.size() else ("field_%d" % fi)

		var value = _decode_field(
			data, ftype, f_data_val, fdata_off, findices_off, lindices_off,
			struct_off, field_off, labels
		)
		result[label] = value

	return result


static func _decode_field(
		data: PackedByteArray,
		ftype: int,
		raw_val: int,
		fdata_off: int,
		findices_off: int,
		lindices_off: int,
		struct_off: int,
		field_off: int,
		labels: Array[String]
) -> Variant:
	match ftype:
		FIELD_BYTE:
			return raw_val & 0xFF
		FIELD_CHAR:
			var v := raw_val & 0xFF
			return v if v < 128 else v - 256
		FIELD_WORD:
			return raw_val & 0xFFFF
		FIELD_SHORT:
			var v := raw_val & 0xFFFF
			return v if v < 32768 else v - 65536
		FIELD_DWORD:
			return raw_val
		FIELD_INT:
			# Reinterpret unsigned as signed 32-bit
			return _u32_to_i32(raw_val)
		FIELD_FLOAT:
			return _u32_to_f32(raw_val)

		FIELD_DWORD64:
			# 8 bytes in FieldData at offset raw_val
			return _u64(data, fdata_off + raw_val)
		FIELD_INT64:
			return _i64(data, fdata_off + raw_val)
		FIELD_DOUBLE:
			# 8 bytes IEEE 754 double — Godot uses float, best we can do
			return _f64(data, fdata_off + raw_val)

		FIELD_CEXOSTRING:
			# uint32 length + utf-8 chars ( ReadFieldCExoString @ 0x00411ec0 )
			var off := fdata_off + raw_val
			var slen := _u32(data, off)
			return data.slice(off + 4, off + 4 + slen).get_string_from_utf8()

		FIELD_CRESREF:
			# uint8 length + chars, max 16 ( ReadFieldCResRef @ 0x00411e10 )
			var off := fdata_off + raw_val
			var slen := data[off] & 0xFF
			return data.slice(off + 1, off + 1 + slen).get_string_from_ascii()

		FIELD_CEXOLOCSTR:
			# ( ReadFieldCExoLocString @ 0x00411fd0 )
			# uint32 total_size, uint32 strref, uint32 string_count, then entries:
			#   { int32 language_id, int32 count, char[count] string }
			var off := fdata_off + raw_val
			# var total_size := _u32(data, off)
			var strref := _u32(data, off + 4)
			var str_count := _u32(data, off + 8)
			var strings := {}
			var pos := off + 12
			for str_idx in str_count:
				var lang_id := _u32_to_i32(_u32(data, pos))
				var ch_count := _u32(data, pos + 4)
				var txt := data.slice(pos + 8, pos + 8 + ch_count).get_string_from_utf8()
				strings[lang_id] = txt
				pos += 8 + ch_count
			return { "strref": strref, "strings": strings }

		FIELD_VOID:
			# raw data blob ( ReadFieldVOID @ 0x00412380 )
			var off := fdata_off + raw_val
			var blen := _u32(data, off)
			return data.slice(off + 4, off + 4 + blen)

		FIELD_QUATERNION:
			# 4 floats: w, x, y, z ( ReadFieldQuaternion @ 0x004121b0 )
			var off := fdata_off + raw_val
			var qw := _u32_to_f32(_u32(data, off + 0))
			var qx := _u32_to_f32(_u32(data, off + 4))
			var qy := _u32_to_f32(_u32(data, off + 8))
			var qz := _u32_to_f32(_u32(data, off + 12))
			return Quaternion(qx, qy, qz, qw)

		FIELD_VECTOR:
			# 3 floats: x, y, z ( ReadFieldVector @ 0x004122a0 )
			var off := fdata_off + raw_val
			var vx := _u32_to_f32(_u32(data, off + 0))
			var vy := _u32_to_f32(_u32(data, off + 4))
			var vz := _u32_to_f32(_u32(data, off + 8))
			return Vector3(vx, vy, vz)

		FIELD_STRUCT:
			# raw_val is a struct index
			return _parse_struct(
				data, raw_val,
				struct_off, field_off, fdata_off, findices_off, lindices_off,
				labels
			)

		FIELD_LIST:
			# raw_val is byte offset into ListIndicesData
			# ListIndicesData block: uint32 count, uint32[count] struct indices
			var off := lindices_off + raw_val
			var lcount := _u32(data, off)
			var list: Array[Dictionary] = []
			for li in lcount:
				var si := _u32(data, off + 4 + li * 4)
				list.append(_parse_struct(
					data, si,
					struct_off, field_off, fdata_off, findices_off, lindices_off,
					labels
				))
			return list

		_:
			push_warning("GFFParser: unknown field type 0x%02X" % ftype)
			return null


# --------------------------------------------------------------------------- #
# Binary helpers — all little-endian
# --------------------------------------------------------------------------- #

static func _u32(data: PackedByteArray, offset: int) -> int:
	if offset + 4 > data.size():
		return 0
	return (data[offset]
		| (data[offset + 1] << 8)
		| (data[offset + 2] << 16)
		| (data[offset + 3] << 24)) & 0xFFFFFFFF


static func _u64(data: PackedByteArray, offset: int) -> int:
	if offset + 8 > data.size():
		return 0
	var lo := _u32(data, offset)
	var hi := _u32(data, offset + 4)
	return lo | (hi << 32)


static func _i64(data: PackedByteArray, offset: int) -> int:
	var v := _u64(data, offset)
	if v >= (1 << 63):
		v -= (1 << 64)
	return v


static func _f64(data: PackedByteArray, offset: int) -> float:
	# Re-pack 8 bytes as a PackedByteArray and decode via StreamPeerBuffer
	if offset + 8 > data.size():
		return 0.0
	var buf := StreamPeerBuffer.new()
	buf.data_array = data.slice(offset, offset + 8)
	buf.big_endian = false
	return buf.get_double()


static func _u32_to_i32(v: int) -> int:
	if v >= 0x80000000:
		return v - 0x100000000
	return v


static func _u32_to_f32(v: int) -> float:
	# Reinterpret bit pattern as IEEE 754 single
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.put_32(v)
	buf.seek(0)
	return buf.get_float()


static func _read_text(data: PackedByteArray, offset: int, length: int) -> String:
	var slice := data.slice(offset, offset + length)
	# Strip nulls
	var txt := ""
	for b in slice:
		if b == 0:
			break
		txt += char(b)
	return txt
