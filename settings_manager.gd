## Manages persistent UI settings across program runs
## Handles unit preferences, category locks, panel layout, and element sizing
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

## Default element stretch ratios for concentration rows
const DEFAULT_NAME_RATIO: float = 1.0
const DEFAULT_SLIDER_RATIO: float = 2.0
const DEFAULT_SPINBOX_RATIO: float = 1.2
const DEFAULT_INFO_RATIO: float = 0.8

## Default minimum sizes
const DEFAULT_NAME_MIN_WIDTH: float = 60.0
const DEFAULT_SLIDER_MIN_WIDTH: float = 60.0
const DEFAULT_SPINBOX_MIN_WIDTH: float = 70.0
const DEFAULT_INFO_MIN_WIDTH: float = 40.0

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
var panel_positions: Dictionary = {}

## Element sizing ratios (proportional)
var element_ratios: Dictionary = {
	"name": DEFAULT_NAME_RATIO,
	"slider": DEFAULT_SLIDER_RATIO,
	"spinbox": DEFAULT_SPINBOX_RATIO,
	"info": DEFAULT_INFO_RATIO
}

## Element minimum widths
var element_min_widths: Dictionary = {
	"name": DEFAULT_NAME_MIN_WIDTH,
	"slider": DEFAULT_SLIDER_MIN_WIDTH,
	"spinbox": DEFAULT_SPINBOX_MIN_WIDTH,
	"info": DEFAULT_INFO_MIN_WIDTH
}

## Panel-specific overrides (optional)
var panel_element_ratios: Dictionary = {}  ## {panel_name: {element: ratio}}

#endregion

#region Save/Load

func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	
	if err != OK:
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
	
	## Load element sizing
	element_ratios = config.get_value("sizing", "element_ratios", element_ratios)
	element_min_widths = config.get_value("sizing", "element_min_widths", element_min_widths)
	panel_element_ratios = config.get_value("sizing", "panel_element_ratios", {})

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
	
	## Save element sizing
	config.set_value("sizing", "element_ratios", element_ratios)
	config.set_value("sizing", "element_min_widths", element_min_widths)
	config.set_value("sizing", "panel_element_ratios", panel_element_ratios)
	
	var err = config.save(SETTINGS_PATH)
	if err != OK:
		push_error("Failed to save UI settings: %s" % error_string(err))

#endregion

#region Unit Setters

func set_molecule_unit(unit: int) -> void:
	molecule_unit = unit
	save_settings()

func set_enzyme_unit(unit: int) -> void:
	enzyme_unit = unit
	save_settings()

#endregion

#region Lock Setters

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

#endregion

#region Layout Setters

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

#region Element Sizing

## Get stretch ratio for an element type
func get_element_ratio(element_name: String, panel_name: String = "") -> float:
	## Check panel-specific override first
	if panel_name != "" and panel_element_ratios.has(panel_name):
		var panel_ratios = panel_element_ratios[panel_name]
		if panel_ratios.has(element_name):
			return panel_ratios[element_name]
	
	## Fall back to global ratio
	return element_ratios.get(element_name, 1.0)

## Get minimum width for an element type
func get_element_min_width(element_name: String) -> float:
	return element_min_widths.get(element_name, 50.0)

## Set global element ratio
func set_element_ratio(element_name: String, ratio: float) -> void:
	element_ratios[element_name] = maxf(0.1, ratio)
	save_settings()

## Set panel-specific element ratio
func set_panel_element_ratio(panel_name: String, element_name: String, ratio: float) -> void:
	if not panel_element_ratios.has(panel_name):
		panel_element_ratios[panel_name] = {}
	panel_element_ratios[panel_name][element_name] = maxf(0.1, ratio)
	save_settings()

## Set minimum width for an element type
func set_element_min_width(element_name: String, width: float) -> void:
	element_min_widths[element_name] = maxf(20.0, width)
	save_settings()

## Reset all sizing to defaults
func reset_element_sizing() -> void:
	element_ratios = {
		"name": DEFAULT_NAME_RATIO,
		"slider": DEFAULT_SLIDER_RATIO,
		"spinbox": DEFAULT_SPINBOX_RATIO,
		"info": DEFAULT_INFO_RATIO
	}
	element_min_widths = {
		"name": DEFAULT_NAME_MIN_WIDTH,
		"slider": DEFAULT_SLIDER_MIN_WIDTH,
		"spinbox": DEFAULT_SPINBOX_MIN_WIDTH,
		"info": DEFAULT_INFO_MIN_WIDTH
	}
	panel_element_ratios.clear()
	save_settings()

## Get all ratios as dictionary (for UI display)
func get_all_element_ratios() -> Dictionary:
	return element_ratios.duplicate()

## Get all min widths as dictionary (for UI display)
func get_all_element_min_widths() -> Dictionary:
	return element_min_widths.duplicate()

#endregion
