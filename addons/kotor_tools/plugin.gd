## plugin.gd
## KotOR Tools — EditorPlugin entry point.
##
## Registers all EditorImportPlugins for KotOR file formats and adds the KotOR
## Tools dock to the editor bottom panel.
##
## Aurora Engine file-format reference addresses (K1_GOG_swkotor):
##   CResGFF ctor          @ 0x00410630
##   CERFFile ctor         @ 0x005dd9c0
##   ExportFilesFromERF    @ 0x005dd710
##   C2DA::Load2DArray     @ 0x004143b0
##   CTlkTable             (class, no single ctor addr resolved)
@tool
extends EditorPlugin

const GffImportPlugin  := preload("importers/gff_import_plugin.gd")
const ErfImportPlugin  := preload("importers/erf_import_plugin.gd")
const TwodaImportPlugin := preload("importers/twoda_import_plugin.gd")
const TpcImportPlugin  := preload("importers/tpc_import_plugin.gd")
const KotorDock        := preload("ui/kotor_dock.gd")
const TLK_IMPORT_PLUGIN_PATH := "res://addons/kotor_tools/importers/tlk_import_plugin.gd"

var _gff_importer:   EditorImportPlugin
var _erf_importer:   EditorImportPlugin
var _twoda_importer: EditorImportPlugin
var _tlk_importer:   EditorImportPlugin
var _tpc_importer:   EditorImportPlugin
var _dock:           Control


func _enter_tree() -> void:
	_gff_importer   = GffImportPlugin.new()
	_erf_importer   = ErfImportPlugin.new()
	_twoda_importer = TwodaImportPlugin.new()
	_tpc_importer   = TpcImportPlugin.new()
	var tlk_importer_script := load(TLK_IMPORT_PLUGIN_PATH)
	if tlk_importer_script == null:
		push_error("KotOR Tools: failed to load TLK importer at %s" % TLK_IMPORT_PLUGIN_PATH)
		return
	_tlk_importer   = tlk_importer_script.new()

	add_import_plugin(_gff_importer)
	add_import_plugin(_erf_importer)
	add_import_plugin(_twoda_importer)
	add_import_plugin(_tlk_importer)
	add_import_plugin(_tpc_importer)

	_dock = KotorDock.new()
	add_control_to_bottom_panel(_dock, "KotOR")


func _exit_tree() -> void:
	if _gff_importer:
		remove_import_plugin(_gff_importer)
	if _erf_importer:
		remove_import_plugin(_erf_importer)
	if _twoda_importer:
		remove_import_plugin(_twoda_importer)
	if _tlk_importer:
		remove_import_plugin(_tlk_importer)
	if _tpc_importer:
		remove_import_plugin(_tpc_importer)

	if _dock:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()
