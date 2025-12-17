## Reusable panel for displaying and editing concentrations
## Features: global unit selection, category lock, persistence, wider spinbox controls
class_name ConcentrationPanel
extends VBoxContainer

signal concentration_changed(id: String, value: float)
signal lock_changed(id: String, locked: bool)
signal global_unit_changed(unit: int)

#region Unit Conversion Constants

enum Unit { MILLIMOLAR, MICROMOLAR, NANOMOLAR, PICOMOLAR }

const UNIT_NAMES: Array[String] = ["mM", "µM", "nM", "pM"]
const UNIT_MULTIPLIERS: Array[float] = [1.0, 1000.0, 1000000.0, 1000000000.0]

#endregion

#region State

var item_entries: Dictionary = {}  ## {id: ItemEntry}
var category_locked: bool = false
var current_global_unit: int = Unit.MILLIMOLAR
var default_item_type: String = "molecule"
var panel_title: String = "Concentrations"
var panel_name: String = ""  ## For panel-specific settings

class ItemEntry:
	var container: HBoxContainer
	var name_label: Label
	var spinbox: SpinBox
	var lock_button: CheckBox
	var info_label: Label
	var id: String
	var display_name: String
	var current_unit: int = 0
	var base_value_mm: float = 0.0
	var item_type: String = "molecule"
	var is_updating: bool = false

#endregion

#region Label Settings Cache

var _label_settings_title: LabelSettings
var _label_settings_normal: LabelSettings
var _label_settings_small: LabelSettings
var _label_settings_info: LabelSettings

func _create_label_settings() -> void:
	_label_settings_title = LabelSettings.new()
	_label_settings_title.font_size = 13
	
	_label_settings_normal = LabelSettings.new()
	_label_settings_normal.font_size = 12
	
	_label_settings_small = LabelSettings.new()
	_label_settings_small.font_size = 11
	
	_label_settings_info = LabelSettings.new()
	_label_settings_info.font_size = 10
	_label_settings_info.font_color = Color(0.4, 0.4, 0.4)

#endregion

#region Header UI

var header_container: HBoxContainer
var global_unit_option: OptionButton
var category_lock_button: CheckBox
var title_label: Label

#endregion

#region Setup

func _init() -> void:
	add_theme_constant_override("separation", 6)
	_create_label_settings()

func _ready() -> void:
	_create_header()
	_load_settings()

func _create_header() -> void:
	header_container = HBoxContainer.new()
	header_container.add_theme_constant_override("separation", 8)
	
	## Category lock checkbox
	category_lock_button = CheckBox.new()
	category_lock_button.button_pressed = category_locked
	category_lock_button.tooltip_text = "Lock all from simulation changes"
	category_lock_button.toggled.connect(_on_category_lock_toggled)
	header_container.add_child(category_lock_button)
	
	## Title
	title_label = Label.new()
	title_label.text = panel_title
	title_label.label_settings = _label_settings_title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(title_label)
	
	## Global unit selector
	global_unit_option = OptionButton.new()
	global_unit_option.custom_minimum_size = Vector2(70, 0)
	for unit_name in UNIT_NAMES:
		global_unit_option.add_item(unit_name)
	global_unit_option.selected = current_global_unit
	global_unit_option.item_selected.connect(_on_global_unit_changed)
	header_container.add_child(global_unit_option)
	
	add_child(header_container)
	
	## Separator
	var sep = HSeparator.new()
	add_child(sep)

func _load_settings() -> void:
	var settings = SettingsManager.get_instance()
	if default_item_type == "molecule":
		current_global_unit = settings.molecule_unit
		category_locked = settings.lock_molecules
	else:
		current_global_unit = settings.enzyme_unit
		category_locked = settings.lock_enzymes
	
	if global_unit_option:
		global_unit_option.selected = current_global_unit
	if category_lock_button:
		category_lock_button.button_pressed = category_locked

#endregion

#region Public API

func setup_items(items: Array, item_type: String = "molecule") -> void:
	default_item_type = item_type
	clear_items()
	
	for item in items:
		var item_id = _get_item_id(item)
		var item_name = _get_item_name(item)
		var item_conc = _get_item_concentration(item)
		var is_locked = _get_item_locked(item)
		_add_item_entry(item_id, item_name, item_conc, is_locked, item_type)

func clear_items() -> void:
	for entry in item_entries.values():
		if entry.container and is_instance_valid(entry.container):
			entry.container.queue_free()
	item_entries.clear()

func update_values(items: Array, item_type: String = "") -> void:
	for item in items:
		var item_id = _get_item_id(item)
		if item_entries.has(item_id):
			var entry = item_entries[item_id] as ItemEntry
			if entry.is_updating:
				continue
			
			var is_locked = entry.lock_button.button_pressed or category_locked
			if is_locked:
				continue
			
			entry.is_updating = true
			entry.base_value_mm = _get_item_concentration(item)
			var display_val = entry.base_value_mm * UNIT_MULTIPLIERS[entry.current_unit]
			entry.spinbox.set_value_no_signal(display_val)
			entry.is_updating = false

func is_item_locked(item_id: String) -> bool:
	if category_locked:
		return true
	if item_entries.has(item_id):
		return item_entries[item_id].lock_button.button_pressed
	return false

#endregion

#region Item Creation

func _add_item_entry(item_id: String, item_name: String, item_conc: float, is_locked: bool, item_type: String) -> void:
	var entry = ItemEntry.new()
	entry.id = item_id
	entry.display_name = item_name
	entry.base_value_mm = item_conc
	entry.item_type = item_type
	entry.current_unit = current_global_unit
	
	var settings = SettingsManager.get_instance()
	
	entry.container = HBoxContainer.new()
	entry.container.add_theme_constant_override("separation", 8)
	
	## Lock checkbox (fixed size, no stretch)
	entry.lock_button = CheckBox.new()
	entry.lock_button.button_pressed = is_locked
	entry.lock_button.tooltip_text = "Lock from simulation changes"
	entry.lock_button.toggled.connect(_on_lock_toggled.bind(item_id))
	entry.lock_button.disabled = category_locked
	entry.lock_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	entry.container.add_child(entry.lock_button)
	
	## Name label - fixed width
	entry.name_label = Label.new()
	entry.name_label.text = item_name
	entry.name_label.custom_minimum_size = Vector2(100, 0)
	entry.name_label.label_settings = _label_settings_normal
	entry.name_label.clip_text = true
	entry.name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	entry.container.add_child(entry.name_label)
	
	## SpinBox - takes remaining space (wider now without slider)
	entry.spinbox = SpinBox.new()
	entry.spinbox.custom_minimum_size = Vector2(140, 0)
	entry.spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.spinbox.min_value = 0.0
	entry.spinbox.max_value = _get_spinbox_max_for_unit(item_type, entry.current_unit)
	entry.spinbox.step = 0.0001
	entry.spinbox.value = item_conc * UNIT_MULTIPLIERS[entry.current_unit]
	entry.spinbox.allow_greater = true
	entry.spinbox.allow_lesser = false
	entry.spinbox.select_all_on_focus = true
	entry.spinbox.suffix = " " + UNIT_NAMES[entry.current_unit]
	entry.spinbox.value_changed.connect(_on_spinbox_changed.bind(item_id))
	entry.container.add_child(entry.spinbox)
	
	## Info label (shows base mM value)
	entry.info_label = Label.new()
	entry.info_label.custom_minimum_size = Vector2(70, 0)
	entry.info_label.label_settings = _label_settings_info
	entry.info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	entry.info_label.text = "(%.4f mM)" % item_conc
	entry.container.add_child(entry.info_label)
	
	item_entries[item_id] = entry
	add_child(entry.container)
	
	_update_lock_visual(entry)

func _update_all_units() -> void:
	for entry in item_entries.values():
		entry.current_unit = current_global_unit
		
		## Update spinbox range and suffix
		entry.spinbox.max_value = _get_spinbox_max_for_unit(entry.item_type, entry.current_unit)
		entry.spinbox.suffix = " " + UNIT_NAMES[entry.current_unit]
		
		## Update displayed value
		entry.is_updating = true
		entry.spinbox.value = entry.base_value_mm * UNIT_MULTIPLIERS[entry.current_unit]
		entry.is_updating = false

func _update_lock_visual(entry: ItemEntry) -> void:
	var is_locked = entry.lock_button.button_pressed or category_locked
	var alpha = 0.6 if is_locked else 1.0
	entry.name_label.modulate.a = alpha
	entry.spinbox.editable = not category_locked

#endregion

#region Callbacks

func _on_global_unit_changed(index: int) -> void:
	current_global_unit = index
	_update_all_units()
	
	var settings = SettingsManager.get_instance()
	if default_item_type == "molecule":
		settings.set_molecule_unit(index)
	else:
		settings.set_enzyme_unit(index)
	
	global_unit_changed.emit(index)

func _on_category_lock_toggled(pressed: bool) -> void:
	category_locked = pressed
	
	var settings = SettingsManager.get_instance()
	if default_item_type == "molecule":
		settings.set_lock_molecules(pressed)
	else:
		settings.set_lock_enzymes(pressed)
	
	for entry in item_entries.values():
		entry.lock_button.disabled = pressed
		_update_lock_visual(entry)

func _on_lock_toggled(pressed: bool, item_id: String) -> void:
	if item_entries.has(item_id):
		_update_lock_visual(item_entries[item_id])
	lock_changed.emit(item_id, pressed)

func _on_spinbox_changed(value: float, item_id: String) -> void:
	if not item_entries.has(item_id):
		return
	
	var entry = item_entries[item_id] as ItemEntry
	if entry.is_updating:
		return
	
	entry.is_updating = true
	entry.base_value_mm = value / UNIT_MULTIPLIERS[entry.current_unit]
	entry.info_label.text = "(%.4f mM)" % entry.base_value_mm
	entry.is_updating = false
	
	concentration_changed.emit(item_id, entry.base_value_mm)

#endregion

#region Helpers

func _get_spinbox_max_for_unit(item_type: String, unit: int) -> float:
	var base_max = 50.0 if item_type == "molecule" else 1.0
	return base_max * UNIT_MULTIPLIERS[unit]

func _get_item_id(item) -> String:
	if item.has_method("get_id"):
		return item.get_id()
	if "molecule_name" in item:
		return item.molecule_name
	if "enzyme_id" in item:
		return item.enzyme_id
	if "id" in item:
		return item.id
	return str(item.get_instance_id())

func _get_item_name(item) -> String:
	if item.has_method("get_display_name"):
		return item.get_display_name()
	if "molecule_name" in item:
		return item.molecule_name
	if "enzyme_name" in item:
		return item.enzyme_name
	if "display_name" in item:
		return item.display_name
	if "name" in item:
		return item.name
	return "Unknown"

func _get_item_concentration(item) -> float:
	if "concentration" in item:
		return item.concentration
	return 0.0

func _get_item_locked(item) -> bool:
	if "is_locked" in item:
		return item.is_locked
	return false

#endregion
