# godot-kotor-tools

A **Godot 4.6** editor plugin for importing and browsing Star Wars: Knights of the Old Republic (K1/K2) and Jade Empire game archive formats.

Fully implemented static parsers for all major Aurora Engine binary formats. Plug-in and use — no C++ modules required.

---

## Features

| Format | Parser | Importer | Resource wrapper |
|---|---|---|---|
| GFF (`.utc` `.dlg` `.gff` `.utp` .utt …) | `GffParser` | ✅ | `GFFResource` |
| ERF / RIM / MOD archives | `ErfParser` | ✅ | `ErfResource` |
| 2DA spreadsheets | `TwoDaParser` | ✅ | `TwoDaResource` |
| TLK string tables | `TlkParser` | ✅ | `TLKResource` |
| TPC textures | `TpcReader` | ✅ | — (native `ImageTexture`) |
| KEY / BIF archives | `KeyBifParser` | — | — |

Editor dock: **KotOR Tools** panel with 5 tabs:
- Game path picker (points to K1/K2/JE install folder)
- ERF browser (list and extract archive contents)
- GFF inspector (tree view of any GFF file)
- 2DA viewer (spreadsheet grid)
- TLK search (string ID → text lookup)

---

## Installation

### Asset Library (recommended)
Search **KotOR Tools** in the Godot Asset Library and click Install.

### Manual
```
cd your_project/addons
git clone https://github.com/OpenKotOR/godot-kotor-tools.git kotor_tools
```
Then **Project → Project Settings → Plugins → KotOR Tools → Enable**.

---

## API Reference

### `GffParser` — `addons/kotor_tools/formats/gff_parser.gd`

Static parser for Aurora GFF (Generic File Format) binary files.

```gdscript
# Parse from raw bytes
var gff: Dictionary = GffParser.parse(raw_bytes: PackedByteArray) -> Dictionary

# Keys returned:
#   "type"    : String  — four-char GFF type tag ("UTC ", "DLG ", etc.)
#   "version" : String  — format version ("V3.2")
#   "fields"  : Dictionary — field_label → value (recursively parsed structs/lists)
```

### `ErfParser` — `addons/kotor_tools/formats/erf_parser.gd`

Static parser for ERF / RIM / MOD compound archive files.

```gdscript
# Parse archive header and resource list (does NOT load resource data)
var erf: Dictionary = ErfParser.parse_header(raw_bytes: PackedByteArray) -> Dictionary

# Extract a single resource by ResRef + type
var bytes: PackedByteArray = ErfParser.extract_resource(
    raw_bytes: PackedByteArray,
    res_ref: String,
    res_type: int          # Aurora resource type constant (e.g. 0x03ED = UTC)
) -> PackedByteArray
```

### `TwoDaParser` — `addons/kotor_tools/formats/twoda_parser.gd`

Static parser for `.2da` tab-separated spreadsheet files (ASCII format used by K1/K2).

```gdscript
# Parse full sheet
var sheet: Dictionary = TwoDaParser.parse(raw_bytes: PackedByteArray) -> Dictionary
# Keys: "columns" (Array[String]), "rows" (Array[Dictionary])

# Access convenience wrapper (use TwoDaResource instead at runtime)
```

### `TlkParser` — `addons/kotor_tools/formats/tlk_parser.gd`

Static parser for `.tlk` string table files (binary V3.0 format, K1/K2 PC).

```gdscript
# Parse all strings (indexed by StrRef ID)
var strings: Dictionary = TlkParser.parse(raw_bytes: PackedByteArray) -> Dictionary
# Keys: int StrRef → String text
```

### `KeyBifParser` — `addons/kotor_tools/formats/key_bif_parser.gd`

Static parser for `chitin.key` and associated `.bif` data files.

```gdscript
# Parse KEY index
var key: Dictionary = KeyBifParser.parse_key(raw_bytes: PackedByteArray) -> Dictionary

# Extract resource raw bytes from a BIF using the offset from KEY
var bytes: PackedByteArray = KeyBifParser.extract_from_bif(
    bif_bytes: PackedByteArray,
    variable_resource_index: int
) -> PackedByteArray
```

### `TpcReader` — `addons/kotor_tools/formats/tpc_reader.gd`

Converts Aurora `.tpc` texture files to Godot `Image` objects. Handles DXT1/DXT5/RGBA8/greyscale and cubemaps.

```gdscript
var image: Image = TpcReader.read(raw_bytes: PackedByteArray) -> Image
```

---

## Resource Wrappers

Importers produce these `Resource` subclasses, loadable via `load()` at runtime.

### `GFFResource`
```gdscript
var res: GFFResource = load("res://path/to/file.utc")
var value = res.get_field("Tag")        # → Variant
var struct = res.get_struct("Stats")    # → Dictionary
```

### `ErfResource`
```gdscript
var erf: ErfResource = load("res://path/to/file.erf")
var names: Array = erf.resource_names()              # → Array[String]
var bytes: PackedByteArray = erf.get_resource("k_ptar_inc", 0x03ED)
```

### `TLKResource`
```gdscript
var tlk: TLKResource = load("res://path/to/dialog.tlk")
var text: String = tlk.get_string(1234)   # StrRef → text
```

### `TwoDaResource`
```gdscript
var sheet: TwoDaResource = load("res://path/to/feat.2da")
var val: String = sheet.get_cell(row_index: int, column_name: String) -> String
var row: Dictionary = sheet.get_row(row_index: int) -> Dictionary
```

---

## Compatibility

| Godot | Status |
|---|---|
| 4.6 | ✅ Tested |
| 4.5 | Likely works |
| 4.x < 4.5 | Untested |
| 3.x | ❌ Not supported |

Targets K1 (GOG), K2 (GOG), and Jade Empire (GOG). Console/mobile formats are not supported.

---

## License

MIT — see [LICENSE](LICENSE).

No original game assets are included. You must own a legal copy of KotOR or Jade Empire to use this plugin with game data.
