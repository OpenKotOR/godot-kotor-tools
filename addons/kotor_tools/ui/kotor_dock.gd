## ui/kotor_dock.gd
## KotOR Tools bottom-panel dock.
##
## Provides:
##   • Game Path picker — point at a KotOR/TSL installation directory
##   • TAB: ERF Browser — browse any loaded ERF/RIM; double-click to preview
##   • TAB: GFF Inspector — drag any .utc/.dlg/etc. and inspect the field tree
##   • TAB: 2DA Viewer — load & browse any .2da as a spreadsheet
##   • TAB: TLK Search — load dialog.tlk and full-text search strings
@tool
extends Control

const GFFParser    := preload("../formats/gff_parser.gd")
const ERFParser    := preload("../formats/erf_parser.gd")
const TwoDaParser  := preload("../formats/twoda_parser.gd")
const TLKParser    := preload("../formats/tlk_parser.gd")
const TPCReader    := preload("../formats/tpc_reader.gd")

# Persisted game-path preference key
const PREF_KEY := "kotor_tools/game_path"
const GAME_TLK_NAME := "dialog.tlk"

var _game_path: String = ""
var _tabs: TabContainer
var _path_status_label: Label

# ERF tab
var _erf_path_label: Label
var _erf_tree: Tree
var _erf_data: Dictionary = {}
var _erf_preview: TextureRect

# GFF tab
var _gff_path_label: Label
var _gff_tree: Tree

# 2DA tab
var _twoda_path_label: Label
var _twoda_tree: Tree

# TLK tab
var _tlk_path_label: Label
var _tlk_search_field: LineEdit
var _tlk_tree: Tree
var _tlk_data: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(0, 220)


func _ready() -> void:
	_game_path = EditorInterface.get_editor_settings().get_setting(PREF_KEY) \
		if EditorInterface.get_editor_settings().has_setting(PREF_KEY) else ""
	_build_ui()


# --------------------------------------------------------------------------- #
# UI Construction
# --------------------------------------------------------------------------- #

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# ── Game-path row ──────────────────────────────────────────────────────
	var path_row := HBoxContainer.new()
	root.add_child(path_row)

	var path_lbl := Label.new()
	path_lbl.text = "Game Path:"
	path_row.add_child(path_lbl)

	var path_edit := LineEdit.new()
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_edit.placeholder_text = "Select KotOR / TSL install folder…"
	path_edit.text = _game_path
	path_edit.text_submitted.connect(_on_game_path_changed)
	path_row.add_child(path_edit)

	var browse_btn := Button.new()
	browse_btn.text = "Browse…"
	browse_btn.pressed.connect(_browse_game_path.bind(path_edit))
	path_row.add_child(browse_btn)

	_path_status_label = Label.new()
	_path_status_label.clip_text = true
	path_row.add_child(_path_status_label)
	_refresh_game_path_status()

	# ── Tabs ───────────────────────────────────────────────────────────────
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)

	_build_erf_tab()
	_build_gff_tab()
	_build_2da_tab()
	_build_tlk_tab()


# ── ERF Browser ─────────────────────────────────────────────────────────────

func _build_erf_tab() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "ERF Browser"
	_tabs.add_child(vbox)

	var toolbar := HBoxContainer.new()
	vbox.add_child(toolbar)

	var open_btn := Button.new()
	open_btn.text = "Open ERF/RIM…"
	open_btn.pressed.connect(_open_erf)
	toolbar.add_child(open_btn)

	var open_game_btn := Button.new()
	open_game_btn.text = "Game Archive…"
	open_game_btn.pressed.connect(_open_game_erf)
	toolbar.add_child(open_game_btn)

	var extract_btn := Button.new()
	extract_btn.text = "Extract All…"
	extract_btn.pressed.connect(_extract_erf_all)
	toolbar.add_child(extract_btn)

	_erf_path_label = Label.new()
	_erf_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_erf_path_label.clip_text = true
	toolbar.add_child(_erf_path_label)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(split)

	_erf_tree = Tree.new()
	_erf_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_erf_tree.columns = 3
	_erf_tree.set_column_title(0, "ResRef")
	_erf_tree.set_column_title(1, "Type")
	_erf_tree.set_column_title(2, "Size")
	_erf_tree.column_titles_visible = true
	_erf_tree.item_activated.connect(_on_erf_item_activated)
	split.add_child(_erf_tree)

	_erf_preview = TextureRect.new()
	_erf_preview.custom_minimum_size = Vector2(180, 180)
	_erf_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_erf_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	split.add_child(_erf_preview)


# ── GFF Inspector ────────────────────────────────────────────────────────────

func _build_gff_tab() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "GFF Inspector"
	_tabs.add_child(vbox)

	var toolbar := HBoxContainer.new()
	vbox.add_child(toolbar)

	var open_btn := Button.new()
	open_btn.text = "Open GFF…"
	open_btn.pressed.connect(_open_gff)
	toolbar.add_child(open_btn)

	_gff_path_label = Label.new()
	_gff_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gff_path_label.clip_text = true
	toolbar.add_child(_gff_path_label)

	_gff_tree = Tree.new()
	_gff_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_gff_tree.columns = 2
	_gff_tree.set_column_title(0, "Field")
	_gff_tree.set_column_title(1, "Value")
	_gff_tree.column_titles_visible = true
	vbox.add_child(_gff_tree)


# ── 2DA Viewer ───────────────────────────────────────────────────────────────

func _build_2da_tab() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "2DA Viewer"
	_tabs.add_child(vbox)

	var toolbar := HBoxContainer.new()
	vbox.add_child(toolbar)

	var open_btn := Button.new()
	open_btn.text = "Open 2DA…"
	open_btn.pressed.connect(_open_2da)
	toolbar.add_child(open_btn)

	_twoda_path_label = Label.new()
	_twoda_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_twoda_path_label.clip_text = true
	toolbar.add_child(_twoda_path_label)

	_twoda_tree = Tree.new()
	_twoda_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_twoda_tree)


# ── TLK Search ───────────────────────────────────────────────────────────────

func _build_tlk_tab() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "TLK Search"
	_tabs.add_child(vbox)

	var toolbar := HBoxContainer.new()
	vbox.add_child(toolbar)

	var open_btn := Button.new()
	open_btn.text = "Load dialog.tlk…"
	open_btn.pressed.connect(_open_tlk)
	toolbar.add_child(open_btn)

	var open_game_btn := Button.new()
	open_game_btn.text = "Load Game TLK"
	open_game_btn.pressed.connect(_load_game_tlk)
	toolbar.add_child(open_game_btn)

	_tlk_path_label = Label.new()
	_tlk_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tlk_path_label.clip_text = true
	toolbar.add_child(_tlk_path_label)

	var search_row := HBoxContainer.new()
	vbox.add_child(search_row)

	var search_lbl := Label.new()
	search_lbl.text = "Search:"
	search_row.add_child(search_lbl)

	_tlk_search_field = LineEdit.new()
	_tlk_search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tlk_search_field.placeholder_text = "Enter StrRef number or text fragment…"
	_tlk_search_field.text_submitted.connect(_on_tlk_search)
	search_row.add_child(_tlk_search_field)

	var search_btn := Button.new()
	search_btn.text = "Search"
	search_btn.pressed.connect(func(): _on_tlk_search(_tlk_search_field.text))
	search_row.add_child(search_btn)

	_tlk_tree = Tree.new()
	_tlk_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tlk_tree.columns = 2
	_tlk_tree.set_column_title(0, "StrRef")
	_tlk_tree.set_column_title(1, "Text")
	_tlk_tree.column_titles_visible = true
	vbox.add_child(_tlk_tree)


# --------------------------------------------------------------------------- #
# Event handlers — game path
# --------------------------------------------------------------------------- #

func _on_game_path_changed(new_path: String) -> void:
	_game_path = new_path
	EditorInterface.get_editor_settings().set_setting(PREF_KEY, _game_path)
	_refresh_game_path_status()


func _browse_game_path(target_edit: LineEdit) -> void:
	var dialog := _make_dialog(
		EditorFileDialog.FILE_MODE_OPEN_DIR,
		PackedStringArray(),
		"Select KotOR / TSL Install Folder"
	)
	dialog.title = "Select KotOR / TSL Install Folder"
	dialog.dir_selected.connect(func(dir: String) -> void:
		target_edit.text = dir
		_on_game_path_changed(dir)
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered_ratio(0.6)


# --------------------------------------------------------------------------- #
# Event handlers — ERF tab
# --------------------------------------------------------------------------- #

func _open_erf() -> void:
	var dialog := _make_dialog(
		EditorFileDialog.FILE_MODE_OPEN_FILE,
		PackedStringArray(["*.erf,*.rim,*.mod,*.sav ; KotOR ERF/RIM"]),
		"Open KotOR ERF/RIM"
	)
	dialog.file_selected.connect(func(path: String) -> void:
		_load_erf(path)
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)


func _open_game_erf() -> void:
	if not _has_valid_game_path():
		push_warning("KotOR Tools: configure a valid game path before opening game archives")
		_refresh_game_path_status("Set a valid game path first")
		return
	var archive_dir := _find_first_existing_dir([
		_game_path.path_join("modules"),
		_game_path.path_join("lips"),
		_game_path.path_join("rims"),
		_game_path,
	])
	var dialog := _make_dialog(
		EditorFileDialog.FILE_MODE_OPEN_FILE,
		PackedStringArray(["*.erf,*.rim,*.mod,*.sav ; KotOR ERF/RIM"]),
		"Open Game Archive",
		archive_dir
	)
	dialog.file_selected.connect(func(path: String) -> void:
		_load_erf(path)
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)


func _load_erf(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var data := f.get_buffer(f.get_length())
	f.close()

	_erf_data = ERFParser.parse_bytes(data)
	_erf_path_label.text = path.get_file()
	_erf_preview.texture = null

	_erf_tree.clear()
	var root_item := _erf_tree.create_item()
	for e: ERFParser.ERFEntry in _erf_data.get("entries", []):
		var item := _erf_tree.create_item(root_item)
		item.set_text(0, e.resref)
		item.set_text(1, e.extension)
		item.set_text(2, "%d B" % e.size)
		item.set_metadata(0, e)


func _extract_erf_all() -> void:
	if _erf_data.is_empty():
		return
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	dialog.title = "Extract To…"
	dialog.dir_selected.connect(func(dir: String) -> void:
		ERFParser.extract_all(_erf_data, dir)
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered_ratio(0.6)


func _on_erf_item_activated() -> void:
	var item := _erf_tree.get_selected()
	if item == null:
		return
	var e: ERFParser.ERFEntry = item.get_metadata(0)
	if e == null:
		return
	# Preview TPC textures inline
	if e.extension == "tpc":
		var tex := TPCReader.read_bytes(e.read_data())
		_erf_preview.texture = tex
	else:
		_erf_preview.texture = null


# --------------------------------------------------------------------------- #
# Event handlers — GFF tab
# --------------------------------------------------------------------------- #

func _open_gff() -> void:
	var gff_exts := "*.utc,*.utd,*.ute,*.uti,*.utp,*.uts,*.utt,*.utw,*.utm,"
	gff_exts += "*.jrl,*.dlg,*.git,*.are,*.ifo,*.gff ; KotOR GFF"
	var dialog := _make_dialog(
		EditorFileDialog.FILE_MODE_OPEN_FILE,
		PackedStringArray([gff_exts]),
		"Open KotOR GFF"
	)
	dialog.file_selected.connect(func(path: String) -> void:
		_load_gff(path)
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)


func _load_gff(path: String) -> void:
	var parsed := GFFParser.parse_file(path)
	_gff_path_label.text = "[%s] %s" % [parsed.get("file_type", "?"), path.get_file()]
	_gff_tree.clear()
	var root_item := _gff_tree.create_item()
	root_item.set_text(0, parsed.get("file_type", "?"))
	_populate_gff_tree(root_item, parsed.get("root", {}))


func _populate_gff_tree(parent: TreeItem, data: Dictionary) -> void:
	for key: String in data:
		var val = data[key]
		var item := _gff_tree.create_item(parent)
		item.set_text(0, key)
		match typeof(val):
			TYPE_DICTIONARY:
				item.set_text(1, "<struct>")
				item.collapsed = true
				_populate_gff_tree(item, val)
			TYPE_ARRAY:
				item.set_text(1, "<list[%d]>" % (val as Array).size())
				item.collapsed = true
				for i in (val as Array).size():
					var li := _gff_tree.create_item(item)
					li.set_text(0, "[%d]" % i)
					li.set_text(1, "<struct>")
					li.collapsed = true
					_populate_gff_tree(li, val[i])
			_:
				item.set_text(1, str(val))


# --------------------------------------------------------------------------- #
# Event handlers — 2DA tab
# --------------------------------------------------------------------------- #

func _open_2da() -> void:
	var dialog := _make_dialog(
		EditorFileDialog.FILE_MODE_OPEN_FILE,
		PackedStringArray(["*.2da ; KotOR 2DA Table"]),
		"Open KotOR 2DA"
	)
	dialog.file_selected.connect(func(path: String) -> void:
		_load_2da(path)
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)


func _load_2da(path: String) -> void:
	var parsed := TwoDaParser.parse_file(path)
	_twoda_path_label.text = path.get_file()

	var columns: PackedStringArray = parsed.get("columns", PackedStringArray())
	var rows: Array              = parsed.get("rows", [])

	_twoda_tree.clear()
	_twoda_tree.columns = columns.size() + 1  # +1 for row index

	_twoda_tree.set_column_title(0, "#")
	for ci in columns.size():
		_twoda_tree.set_column_title(ci + 1, columns[ci])
	_twoda_tree.column_titles_visible = true

	var root_item := _twoda_tree.create_item()
	for ri in rows.size():
		var item := _twoda_tree.create_item(root_item)
		item.set_text(0, str(ri))
		for ci in columns.size():
			var v = rows[ri].get(columns[ci], null)
			item.set_text(ci + 1, str(v) if v != null else "")


# --------------------------------------------------------------------------- #
# Event handlers — TLK tab
# --------------------------------------------------------------------------- #

func _open_tlk() -> void:
	var tlk_path := _find_dialog_tlk()
	var dialog := _make_dialog(
		EditorFileDialog.FILE_MODE_OPEN_FILE,
		PackedStringArray(["*.tlk ; KotOR TLK Talk Table"]),
		"Open KotOR TLK",
		tlk_path.get_base_dir() if not tlk_path.is_empty() else ""
	)
	dialog.file_selected.connect(func(path: String) -> void:
		_load_tlk(path)
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)


func _load_game_tlk() -> void:
	var tlk_path := _find_dialog_tlk()
	if tlk_path.is_empty():
		push_warning("KotOR Tools: dialog.tlk was not found under the configured game path")
		_refresh_game_path_status("dialog.tlk not found")
		return
	_load_tlk(tlk_path)
	_refresh_game_path_status("Loaded %s" % GAME_TLK_NAME)


func _load_tlk(path: String) -> void:
	_tlk_data = TLKParser.parse_file(path)
	if _tlk_data.is_empty():
		_tlk_path_label.text = "Failed to load %s" % path.get_file()
		return
	var count: int = (_tlk_data.get("entries", []) as Array).size()
	_tlk_path_label.text = "%s  [%d strings]" % [path.get_file(), count]
	_tlk_tree.clear()


func _on_tlk_search(query: String) -> void:
	if _tlk_data.is_empty():
		return
	query = query.strip_edges()
	if query.is_empty():
		return

	_tlk_tree.clear()
	var root_item := _tlk_tree.create_item()

	var entries: Array = _tlk_data.get("entries", [])

	# Numeric lookup — exact StrRef
	if query.is_valid_int():
		var idx := query.to_int()
		if idx >= 0 and idx < entries.size():
			var e: TLKParser.TLKEntry = entries[idx]
			var item := _tlk_tree.create_item(root_item)
			item.set_text(0, str(e.strref))
			item.set_text(1, e.text)
		return

	# Text fragment search (case-insensitive, limit 200 results)
	var lower_q := query.to_lower()
	var shown   := 0
	for e: TLKParser.TLKEntry in entries:
		if e.text.to_lower().contains(lower_q):
			var item := _tlk_tree.create_item(root_item)
			item.set_text(0, str(e.strref))
			item.set_text(1, e.text)
			shown += 1
			if shown >= 200:
				var more := _tlk_tree.create_item(root_item)
				more.set_text(0, "…")
				more.set_text(1, "(more results — refine search)")
				break


func _refresh_game_path_status(override_text: String = "") -> void:
	if _path_status_label == null:
		return
	if not override_text.is_empty():
		_path_status_label.text = override_text
		return
	if _game_path.is_empty():
		_path_status_label.text = "No game path configured"
		return
	if not DirAccess.dir_exists_absolute(_game_path):
		_path_status_label.text = "Invalid path"
		return
	var tlk_path := _find_dialog_tlk()
	if tlk_path.is_empty():
		_path_status_label.text = "Game path set; dialog.tlk not found"
		return
	_path_status_label.text = "Ready: %s" % tlk_path.get_file()


func _has_valid_game_path() -> bool:
	return not _game_path.is_empty() and DirAccess.dir_exists_absolute(_game_path)


func _find_dialog_tlk() -> String:
	if not _has_valid_game_path():
		return ""
	var candidates := [
		_game_path.path_join(GAME_TLK_NAME),
		_game_path.path_join("dialog").path_join(GAME_TLK_NAME),
	]
	for candidate: String in candidates:
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


func _find_first_existing_dir(candidates: Array[String]) -> String:
	for candidate: String in candidates:
		if DirAccess.dir_exists_absolute(candidate):
			return candidate
	return _game_path


func _make_dialog(
		file_mode: EditorFileDialog.FileMode,
		filters: PackedStringArray,
		title: String,
		start_dir: String = ""
) -> EditorFileDialog:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = file_mode
	dialog.title = title
	dialog.filters = filters
	var initial_dir := start_dir
	if initial_dir.is_empty() and _has_valid_game_path():
		initial_dir = _game_path
	if not initial_dir.is_empty() and DirAccess.dir_exists_absolute(initial_dir):
		dialog.current_dir = initial_dir
	return dialog
