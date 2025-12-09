## Manages persistent UI settings across program runs
## Handles unit preferences, category locks, and panel layout
class_name SettingsManager
extends RefCounted

const SETTINGS_PATH: String = "user://ui_settings.cfg"

#region Default Values

const DEFAULT_MOLECULE_UNIT: int = 0  ## MILLIMOLAR
const DEFAULT_ENZYME_UNIT: int = 0    ## MILLIMOLAR
const DEFAULT_LOCK_MOLECULES: bool = false
const DEFAULT_LOCK_ENZYMES: bool = false
const DEFAULT_LOCK_GENES: bool = false
const DEFAULT_LOCK_REACTIONS: bool = false
const DEFAULT_LOCK_MUTATIONS: bool = false
const DEFAULT_LAYOUT_MODE: int = 0  ## ALL_PANELS

#endregion

#region Singleton Access

static var _instance: SettingsManager = null

static func get_instance() -> SettingsManager:
	if _instance == null:
		_instance = SettingsManager.new()
		_instance._load_settings()
	return _instance

#endregion

#region Properties

var molecule_unit: int = DEFAULT_MOLECULE_UNIT
var enzyme_unit: int = DEFAULT_ENZYME_UNIT

var lock_molecules: bool = DEFAULT_LOCK_MOLECULES
var lock_enzymes: bool = DEFAULT_LOCK_ENZYMES
var lock_genes: bool = DEFAULT_LOCK_GENES
var lock_reactions: bool = DEFAULT_LOCK_REACTIONS
var lock_mutations: bool = DEFAULT_LOCK_MUTATIONS

var layout_mode: int = DEFAULT_LAYOUT_MODE

## Panel positions: stores which column each panel is in and its order
## Format: {panel_name: {column: int, order: int}}
var panel_positions: Dictionary = {}

#endregion

#region Save/Load

func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	
	if err != OK:
		## File doesn't exist yet, use defaults
		return
	
	## Load unit preferences
	molecule_unit = config.get_value("units", "molecule_unit", DEFAULT_MOLECULE_UNIT)
	enzyme_unit = config.get_value("units", "enzyme_unit", DEFAULT_ENZYME_UNIT)
	
	## Load category locks
	lock_molecules = config.get_value("locks", "molecules", DEFAULT_LOCK_MOLECULES)
	lock_enzymes = config.get_value("locks", "enzymes", DEFAULT_LOCK_ENZYMES)
	lock_genes = config.get_value("locks", "genes", DEFAULT_LOCK_GENES)
	lock_reactions = config.get_value("locks", "reactions", DEFAULT_LOCK_REACTIONS)
	lock_mutations = config.get_value("locks", "mutations", DEFAULT_LOCK_MUTATIONS)
	
	## Load layout
	layout_mode = config.get_value("layout", "mode", DEFAULT_LAYOUT_MODE)
	panel_positions = config.get_value("layout", "panel_positions", {})

func save_settings() -> void:
	var config = ConfigFile.new()
	
	## Save unit preferences
	config.set_value("units", "molecule_unit", molecule_unit)
	config.set_value("units", "enzyme_unit", enzyme_unit)
	
	## Save category locks
	config.set_value("locks", "molecules", lock_molecules)
	config.set_value("locks", "enzymes", lock_enzymes)
	config.set_value("locks", "genes", lock_genes)
	config.set_value("locks", "reactions", lock_reactions)
	config.set_value("locks", "mutations", lock_mutations)
	
	## Save layout
	config.set_value("layout", "mode", layout_mode)
	config.set_value("layout", "panel_positions", panel_positions)
	
	var err = config.save(SETTINGS_PATH)
	if err != OK:
		push_error("Failed to save UI settings: %s" % error_string(err))

#endregion

#region Convenience Setters

func set_molecule_unit(unit: int) -> void:
	molecule_unit = unit
	save_settings()

func set_enzyme_unit(unit: int) -> void:
	enzyme_unit = unit
	save_settings()

func set_lock_molecules(locked: bool) -> void:
	lock_molecules = locked
	save_settings()

func set_lock_enzymes(locked: bool) -> void:
	lock_enzymes = locked
	save_settings()

func set_lock_genes(locked: bool) -> void:
	lock_genes = locked
	save_settings()

func set_lock_reactions(locked: bool) -> void:
	lock_reactions = locked
	save_settings()

func set_lock_mutations(locked: bool) -> void:
	lock_mutations = locked
	save_settings()

func set_layout_mode(mode: int) -> void:
	layout_mode = mode
	save_settings()

func set_panel_position(panel_name: String, column_index: int, order: int) -> void:
	panel_positions[panel_name] = {"column": column_index, "order": order}
	save_settings()

func get_panel_position(panel_name: String) -> Dictionary:
	return panel_positions.get(panel_name, {})

func clear_panel_positions() -> void:
	panel_positions.clear()
	save_settings()

#endregion
