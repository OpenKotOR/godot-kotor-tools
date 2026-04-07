## formats/tpc_reader.gd
## TPC (BioWare Texture) reader → produces an ImageTexture for Godot.
##
## TPC file layout:
##   0x00 uint32  DataSize     ; total size of pixel data in bytes
##   0x04 float   AlphaTest   ; alpha-cutoff threshold (usually 0.0)
##   0x08 uint16  Width
##   0x0A uint16  Height
##   0x0C uint8   Encoding
##            0x01 = Greyscale (8-bit L)
##            0x02 = RGB  (24-bit)
##            0x04 = RGBA (32-bit)
##            0x09 = DXT1 (BC1)
##            0x0A = DXT3 (BC2)
##            0x0B = DXT5 (BC3)
##   0x0D uint8   NumMips
##   0x0E byte[0x74] Reserved   ; 116 bytes padding → header total = 0x80 (128 bytes)
##   0x80 ...     Pixel data for mip 0, then mip 1, ...
##
## Note: Godot 4 does NOT support BC1/2/3 decompression in GDScript natively.
## For DXT-encoded TPC files this reader performs a CPU fallback decode.
class_name TPCReader

const HEADER_SIZE := 128  # 0x80

# Encoding constants
const ENC_GREY := 0x01
const ENC_RGB  := 0x02
const ENC_RGBA := 0x04
const ENC_DXT1 := 0x09
const ENC_DXT3 := 0x0A
const ENC_DXT5 := 0x0B

# --------------------------------------------------------------------------- #
# Public API
# --------------------------------------------------------------------------- #

## Read a TPC file from bytes and return an ImageTexture, or null on failure.
## Only mip level 0 is imported.
static func read_bytes(data: PackedByteArray) -> ImageTexture:
	if data.size() < HEADER_SIZE:
		push_error("TPCReader: data too small (%d bytes)" % data.size())
		return null

	var width    := _u16(data, 0x08)
	var height   := _u16(data, 0x0A)
	var encoding := data[0x0C]
	# var num_mips := data[0x0D]

	if width == 0 or height == 0:
		push_error("TPCReader: zero-size texture")
		return null

	var img: Image = null

	match encoding:
		ENC_GREY:
			img = _decode_grey(data, width, height)
		ENC_RGB:
			img = _decode_rgb(data, width, height)
		ENC_RGBA:
			img = _decode_rgba(data, width, height)
		ENC_DXT1:
			img = _decode_dxt1(data, width, height)
		ENC_DXT3:
			img = _decode_dxt3(data, width, height)
		ENC_DXT5:
			img = _decode_dxt5(data, width, height)
		_:
			push_error("TPCReader: unsupported encoding 0x%02X" % encoding)
			return null

	if img == null:
		return null

	return ImageTexture.create_from_image(img)


## Read a TPC file from disk and return an ImageTexture, or null on failure.
static func read_file(path: String) -> ImageTexture:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("TPCReader: cannot open '%s'" % path)
		return null
	var data := f.get_buffer(f.get_length())
	f.close()
	return read_bytes(data)


# --------------------------------------------------------------------------- #
# Uncompressed decoders
# --------------------------------------------------------------------------- #

static func _decode_grey(data: PackedByteArray, w: int, h: int) -> Image:
	var px_count := w * h
	var rgba := PackedByteArray()
	rgba.resize(px_count * 4)
	var src := HEADER_SIZE
	for i in px_count:
		var g := data[src + i]
		var base := i * 4
		rgba[base + 0] = g
		rgba[base + 1] = g
		rgba[base + 2] = g
		rgba[base + 3] = 255
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba)


static func _decode_rgb(data: PackedByteArray, w: int, h: int) -> Image:
	var px_count := w * h
	var rgba := PackedByteArray()
	rgba.resize(px_count * 4)
	var src := HEADER_SIZE
	for i in px_count:
		var base := i * 4
		rgba[base + 0] = data[src + i * 3 + 0]
		rgba[base + 1] = data[src + i * 3 + 1]
		rgba[base + 2] = data[src + i * 3 + 2]
		rgba[base + 3] = 255
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba)


static func _decode_rgba(data: PackedByteArray, w: int, h: int) -> Image:
	var size := w * h * 4
	var slice := data.slice(HEADER_SIZE, HEADER_SIZE + size)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, slice)


# --------------------------------------------------------------------------- #
# DXT / BCn decoders — CPU fallback
# --------------------------------------------------------------------------- #

## DXT1 (BC1): 4x4 blocks, 8 bytes each, up to 1-bit alpha.
static func _decode_dxt1(data: PackedByteArray, w: int, h: int) -> Image:
	var bw := maxi(1, (w + 3) / 4)
	var bh := maxi(1, (h + 3) / 4)
	var out := PackedByteArray()
	out.resize(w * h * 4)
	var src := HEADER_SIZE
	for by in bh:
		for bx in bw:
			var c0 := _u16(data, src);  var c1 := _u16(data, src + 2)
			var bits := _u32(data, src + 4)
			src += 8
			var colors := _dxt_color_table(c0, c1, true)
			_write_block(out, bx, by, w, h, bits, colors)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)


## DXT3 (BC2): explicit 4-bit alpha per pixel, then DXT1 color block.
static func _decode_dxt3(data: PackedByteArray, w: int, h: int) -> Image:
	var bw := maxi(1, (w + 3) / 4)
	var bh := maxi(1, (h + 3) / 4)
	var out := PackedByteArray()
	out.resize(w * h * 4)
	var src := HEADER_SIZE
	for by in bh:
		for bx in bw:
			# 8 bytes explicit alpha table (4 bits per pixel)
			var alpha_bits: Array[int] = []
			for ai in 8:
				var ab := data[src + ai]
				alpha_bits.append((ab & 0x0F) * 17)
				alpha_bits.append(((ab >> 4) & 0x0F) * 17)
			src += 8
			var c0 := _u16(data, src);  var c1 := _u16(data, src + 2)
			var bits := _u32(data, src + 4)
			src += 8
			var colors := _dxt_color_table(c0, c1, false)
			_write_block_with_alpha(out, bx, by, w, h, bits, colors, alpha_bits)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)


## DXT5 (BC3): interpolated 8-bit alpha, then DXT1 color block.
static func _decode_dxt5(data: PackedByteArray, w: int, h: int) -> Image:
	var bw := maxi(1, (w + 3) / 4)
	var bh := maxi(1, (h + 3) / 4)
	var out := PackedByteArray()
	out.resize(w * h * 4)
	var src := HEADER_SIZE
	for by in bh:
		for bx in bw:
			var a0 := data[src] & 0xFF
			var a1 := data[src + 1] & 0xFF
			# Build alpha interpolation table from a0 / a1
			var atable: Array[int] = [a0, a1]
			if a0 > a1:
				for k in range(1, 7):
					atable.append((a0 * (7 - k) + a1 * k) / 7)
			else:
				for k in range(1, 5):
					atable.append((a0 * (5 - k) + a1 * k) / 5)
				atable.append(0)
				atable.append(255)
			# Pack 48 alpha bits from 6 bytes
			var alpha_idx_raw: int = 0
			for ai in 6:
				alpha_idx_raw |= (data[src + 2 + ai] << (ai * 8))
			src += 8
			var alpha_bits: Array[int] = []
			for pi in 16:
				var idx := (alpha_idx_raw >> (pi * 3)) & 0x7
				alpha_bits.append(atable[idx] if idx < atable.size() else 0)
			var c0 := _u16(data, src);  var c1 := _u16(data, src + 2)
			var bits := _u32(data, src + 4)
			src += 8
			var colors := _dxt_color_table(c0, c1, false)
			_write_block_with_alpha(out, bx, by, w, h, bits, colors, alpha_bits)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)


## Expand two RGB565 endpoints into a 4-entry colour table.
## use_dxt1_alpha: if true and c0 <= c1, index 3 → transparent black (DXT1 rule).
static func _dxt_color_table(c0: int, c1: int, use_dxt1_alpha: bool) -> Array[Color]:
	var r0 := ((c0 >> 11) & 0x1F) * 8
	var g0 := ((c0 >> 5)  & 0x3F) * 4
	var b0 :=  (c0        & 0x1F) * 8
	var r1 := ((c1 >> 11) & 0x1F) * 8
	var g1 := ((c1 >> 5)  & 0x3F) * 4
	var b1 :=  (c1        & 0x1F) * 8

	var table: Array[Color] = [
		Color8(r0, g0, b0, 255),
		Color8(r1, g1, b1, 255),
	]
	if (not use_dxt1_alpha) or c0 > c1:
		table.append(Color8((r0 * 2 + r1) / 3, (g0 * 2 + g1) / 3, (b0 * 2 + b1) / 3, 255))
		table.append(Color8((r0 + r1 * 2) / 3, (g0 + g1 * 2) / 3, (b0 + b1 * 2) / 3, 255))
	else:
		table.append(Color8((r0 + r1) / 2, (g0 + g1) / 2, (b0 + b1) / 2, 255))
		table.append(Color8(0, 0, 0, 0))  # transparent
	return table


static func _write_block(
		out: PackedByteArray, bx: int, by: int, w: int, h: int,
		bits: int, colors: Array[Color]
) -> void:
	for ry in 4:
		for rx in 4:
			var px := bx * 4 + rx
			var py := by * 4 + ry
			if px >= w or py >= h:
				continue
			var idx := (bits >> ((ry * 4 + rx) * 2)) & 0x3
			var c   := colors[idx]
			var off := (py * w + px) * 4
			out[off + 0] = int(c.r * 255)
			out[off + 1] = int(c.g * 255)
			out[off + 2] = int(c.b * 255)
			out[off + 3] = int(c.a * 255)


static func _write_block_with_alpha(
		out: PackedByteArray, bx: int, by: int, w: int, h: int,
		bits: int, colors: Array[Color], alpha_bits: Array[int]
) -> void:
	for ry in 4:
		for rx in 4:
			var px := bx * 4 + rx
			var py := by * 4 + ry
			if px >= w or py >= h:
				continue
			var pi  := ry * 4 + rx
			var idx := (bits >> (pi * 2)) & 0x3
			var c   := colors[idx]
			var off := (py * w + px) * 4
			out[off + 0] = int(c.r * 255)
			out[off + 1] = int(c.g * 255)
			out[off + 2] = int(c.b * 255)
			out[off + 3] = alpha_bits[pi] if pi < alpha_bits.size() else 255


# --------------------------------------------------------------------------- #
# Binary helpers
# --------------------------------------------------------------------------- #

static func _u16(data: PackedByteArray, offset: int) -> int:
	if offset + 2 > data.size():
		return 0
	return (data[offset] | (data[offset + 1] << 8)) & 0xFFFF


static func _u32(data: PackedByteArray, offset: int) -> int:
	if offset + 4 > data.size():
		return 0
	return (data[offset]
		| (data[offset + 1] << 8)
		| (data[offset + 2] << 16)
		| (data[offset + 3] << 24)) & 0xFFFFFFFF
