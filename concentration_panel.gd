## Reusable panel for displaying and editing concentrations
## Features: global unit selection, category lock, persistence, proportional element sizing
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
	var spinbox: ScientificSpinBox
	var slider: HSlider
	var lock_button: CheckBox
	var info_label: Label
	var id: String
	var display_name: String
	var current_unit: int = 0
	var base_value_mm: float = 0.0
	var item_type: String = "molecule"
	var is_updating: bool = false

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

func _ready() -> void:
	_create_header()
	_load_settings()

func _create_header() -> void:
	header_container = HBoxContainer.new()
	header_container.add_theme_constant_override("separation", 8)
	
	## Title
	title_label = Label.new()
	title_label.text = panel_title
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(title_label)
	
	## Global unit selector
	var unit_label = Label.new()
	unit_label.text = "Unit:"
	unit_label.add_theme_font_size_override("font_size", 11)
	header_container.add_child(unit_label)
	
	global_unit_option = OptionButton.new()
	global_unit_option.custom_minimum_size = Vector2(60, 0)
	global_unit_option.add_theme_font_size_override("font_size", 11)
	for i in range(UNIT_NAMES.size()):
		global_unit_option.add_item(UNIT_NAMES[i], i)
	global_unit_option.item_selected.connect(_on_global_unit_changed)
	header_container.add_child(global_unit_option)
	
	## Category lock
	category_lock_button = CheckBox.new()
	category_lock_button.text = "🔒 All"
	category_lock_button.add_theme_font_size_override("font_size", 11)
	category_lock_button.tooltip_text = "Lock all %ss from simulation changes" % default_item_type
	category_lock_button.toggled.connect(_on_category_lock_toggled)
	header_container.add_child(category_lock_button)
	
	add_child(header_container)

func _load_settings() -> void:
	var settings = SettingsManager.get_instance()
	
	## Load unit preference based on item type
	if default_item_type == "molecule":
		current_global_unit = settings.molecule_unit
		category_locked = settings.lock_molecules
	else:
		current_global_unit = settings.enzyme_unit
		category_locked = settings.lock_enzymes
	
	## Apply to UI
	global_unit_option.selected = current_global_unit
	category_lock_button.button_pressed = category_locked

#endregion

#region Public Interface

func set_panel_info(title: String, item_type: String, name: String = "") -> void:
	panel_title = title
	default_item_type = item_type
	panel_name = name if name != "" else item_type
	if title_label:
		title_label.text = title
	if category_lock_button:
		category_lock_button.tooltip_text = "Lock all %ss from simulation changes" % item_type

func update_values(items: Array, item_type: String = "") -> void:
	if item_type != "":
		default_item_type = item_type
	
	var seen_ids: Array[String] = []
	
	for item in items:
		var item_id = _get_item_id(item, default_item_type)
		var item_name = _get_item_name(item, default_item_type)
		var item_conc = _get_item_concentration(item)
		var is_locked = _get_item_locked(item, default_item_type)
		var extra_info = _get_item_info(item, default_item_type)
		
		seen_ids.append(item_id)
		
		if item_entries.has(item_id):
			## Update existing entry
			var entry = item_entries[item_id] as ItemEntry
			entry.base_value_mm = item_conc
			entry.lock_button.set_pressed_no_signal(is_locked)
			entry.info_label.text = extra_info
			_update_entry_display(entry)
		else:
			## Create new entry
			_create_item_entry(item_id, item_name, item_conc, is_locked, extra_info, default_item_type)
	
	## Remove entries no longer present
	var to_remove: Array[String] = []
	for existing_id in item_entries.keys():
		if existing_id not in seen_ids:
			to_remove.append(existing_id)
	
	for id_to_remove in to_remove:
		var entry = item_entries[id_to_remove]
		entry.container.queue_free()
		item_entries.erase(id_to_remove)

func clear() -> void:
	for entry in item_entries.values():
		entry.container.queue_free()
	item_entries.clear()

#endregion

#region Entry Creation

func _create_item_entry(item_id: String, item_name: String, item_conc: float, 
		is_locked: bool, extra_info: String, item_type: String) -> void:
	var entry = ItemEntry.new()
	entry.id = item_id
	entry.display_name = item_name
	entry.base_value_mm = item_conc
	entry.item_type = item_type
	entry.current_unit = current_global_unit
	
	var settings = SettingsManager.get_instance()
	
	## Container row - all children will expand proportionally
	entry.container = HBoxContainer.new()
	entry.container.add_theme_constant_override("separation", 6)
	
	## Lock checkbox (fixed size, no stretch)
	entry.lock_button = CheckBox.new()
	entry.lock_button.button_pressed = is_locked
	entry.lock_button.tooltip_text = "Lock from simulation changes"
	entry.lock_button.toggled.connect(_on_lock_toggled.bind(item_id))
	entry.lock_button.disabled = category_locked
	entry.lock_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	entry.container.add_child(entry.lock_button)
	
	## Name label - proportional stretch
	entry.name_label = Label.new()
	entry.name_label.text = item_name
	entry.name_label.custom_minimum_size = Vector2(settings.get_element_min_width("name"), 0)
	entry.name_label.add_theme_font_size_override("font_size", 12)
	entry.name_label.clip_text = true
	entry.name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.name_label.size_flags_stretch_ratio = settings.get_element_ratio("name", panel_name)
	entry.container.add_child(entry.name_label)
	
	## Slider - proportional stretch
	entry.slider = HSlider.new()
	entry.slider.custom_minimum_size = Vector2(settings.get_element_min_width("slider"), 0)
	entry.slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.slider.size_flags_stretch_ratio = settings.get_element_ratio("slider", panel_name)
	entry.slider.min_value = 0.0
	entry.slider.max_value = _get_slider_max_for_unit(item_type, entry.current_unit)
	entry.slider.step = 0.0001
	entry.slider.value = item_conc * UNIT_MULTIPLIERS[entry.current_unit]
	entry.slider.value_changed.connect(_on_slider_changed.bind(item_id))
	entry.container.add_child(entry.slider)
	
	## ScientificSpinBox - proportional stretch
	entry.spinbox = ScientificSpinBox.new()
	entry.spinbox.custom_minimum_size = Vector2(settings.get_element_min_width("spinbox"), 0)
	entry.spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.spinbox.size_flags_stretch_ratio = settings.get_element_ratio("spinbox", panel_name)
	entry.spinbox.min_value = 0.0
	entry.spinbox.max_value = _get_spinbox_max_for_unit(item_type, entry.current_unit)
	entry.spinbox.step = 0.0001
	entry.spinbox.value = item_conc * UNIT_MULTIPLIERS[entry.current_unit]
	entry.spinbox.allow_greater = true
	entry.spinbox.allow_lesser = false
	entry.spinbox.select_all_on_focus = true
	entry.spinbox.suffix = UNIT_NAMES[entry.current_unit]
	entry.spinbox.add_theme_font_size_override("font_size", 11)
	entry.spinbox.value_changed.connect(_on_spinbox_changed.bind(item_id))
	entry.container.add_child(entry.spinbox)
	
	## Info label - proportional stretch
	entry.info_label = Label.new()
	entry.info_label.text = extra_info
	entry.info_label.custom_minimum_size = Vector2(settings.get_element_min_width("info"), 0)
	entry.info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.info_label.size_flags_stretch_ratio = settings.get_element_ratio("info", panel_name)
	entry.info_label.add_theme_font_size_override("font_size", 10)
	entry.info_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	entry.info_label.clip_text = true
	entry.container.add_child(entry.info_label)
	
	add_child(entry.container)
	item_entries[item_id] = entry
	
	_update_lock_visual(entry)

#endregion

#region Display Updates

func _update_entry_display(entry: ItemEntry) -> void:
	if entry.is_updating:
		return
	entry.is_updating = true
	
	var display_value = entry.base_value_mm * UNIT_MULTIPLIERS[entry.current_unit]
	## Use value property directly - is_updating flag prevents callback loops
	entry.slider.value = display_value
	entry.spinbox.set_value_no_signal(display_value)
	
	entry.is_updating = false

func _update_all_units() -> void:
	for entry in item_entries.values():
		entry.current_unit = current_global_unit
		
		## Update slider range
		entry.slider.max_value = _get_slider_max_for_unit(entry.item_type, entry.current_unit)
		
		## Update spinbox range and suffix
		entry.spinbox.max_value = _get_spinbox_max_for_unit(entry.item_type, entry.current_unit)
		entry.spinbox.suffix = UNIT_NAMES[entry.current_unit]
		
		## Update displayed values
		_update_entry_display(entry)

func _update_lock_visual(entry: ItemEntry) -> void:
	var is_locked = entry.lock_button.button_pressed or category_locked
	var alpha = 0.6 if is_locked else 1.0
	entry.name_label.modulate.a = alpha
	entry.slider.editable = not category_locked
	entry.spinbox.editable = not category_locked

## Apply current settings to all entries (call after settings change)
func apply_element_sizing() -> void:
	var settings = SettingsManager.get_instance()
	
	for entry in item_entries.values():
		entry.name_label.custom_minimum_size.x = settings.get_element_min_width("name")
		entry.name_label.size_flags_stretch_ratio = settings.get_element_ratio("name", panel_name)
		
		entry.slider.custom_minimum_size.x = settings.get_element_min_width("slider")
		entry.slider.size_flags_stretch_ratio = settings.get_element_ratio("slider", panel_name)
		
		entry.spinbox.custom_minimum_size.x = settings.get_element_min_width("spinbox")
		entry.spinbox.size_flags_stretch_ratio = settings.get_element_ratio("spinbox", panel_name)
		
		entry.info_label.custom_minimum_size.x = settings.get_element_min_width("info")
		entry.info_label.size_flags_stretch_ratio = settings.get_element_ratio("info", panel_name)

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

func _on_slider_changed(value: float, item_id: String) -> void:
	if not item_entries.has(item_id):
		return
	
	var entry = item_entries[item_id] as ItemEntry
	if entry.is_updating:
		return
	
	entry.is_updating = true
	entry.base_value_mm = value / UNIT_MULTIPLIERS[entry.current_unit]
	entry.spinbox.value = value  ## Direct assignment, is_updating prevents loops
	entry.is_updating = false
	
	concentration_changed.emit(item_id, entry.base_value_mm)

func _on_spinbox_changed(value: float, item_id: String) -> void:
	if not item_entries.has(item_id):
		return
	
	var entry = item_entries[item_id] as ItemEntry
	if entry.is_updating:
		return
	
	entry.is_updating = true
	entry.base_value_mm = value / UNIT_MULTIPLIERS[entry.current_unit]
	entry.slider.value = value  ## Direct assignment, is_updating prevents loops
	entry.is_updating = false
	
	concentration_changed.emit(item_id, entry.base_value_mm)

#endregion

#region Helpers

func _get_slider_max_for_unit(item_type: String, unit: int) -> float:
	var base_max: float
	if item_type == "enzyme":
		base_max = 0.1
	else:
		base_max = 20.0
	return base_max * UNIT_MULTIPLIERS[unit]

func _get_spinbox_max_for_unit(item_type: String, unit: int) -> float:
	var base_max: float
	if item_type == "enzyme":
		base_max = 1.0
	else:
		base_max = 100.0
	return base_max * UNIT_MULTIPLIERS[unit]

func _get_item_id(item, item_type: String) -> String:
	if item_type == "enzyme":
		if item is EnzymeData:
			return item.enzyme_id
		return item.id if "id" in item else str(item)
	else:
		if item is MoleculeData:
			return item.molecule_name
		return item.name if "name" in item else str(item)

func _get_item_name(item, item_type: String) -> String:
	if item_type == "enzyme":
		if item is EnzymeData:
			return item.enzyme_name
		return item.name if "name" in item else str(item)
	else:
		if item is MoleculeData:
			return item.molecule_name
		return item.name if "name" in item else str(item)

func _get_item_concentration(item) -> float:
	return item.concentration if "concentration" in item else 0.0

func _get_item_locked(item, _item_type: String) -> bool:
	return item.is_locked if "is_locked" in item else false

func _get_item_info(item, item_type: String) -> String:
	if item_type == "enzyme":
		if item is EnzymeData:
			if item.is_degradable:
				return "(t½=%.0fs)" % item.half_life
			return "(stable)"
	else:
		if item is MoleculeData:
			return "(E=%.1f)" % item.potential_energy
	return ""

#endregion

#region External Updates

func update_concentration(item_id: String, new_value_mm: float) -> void:
	if not item_entries.has(item_id):
		return
	
	var entry = item_entries[item_id]
	entry.base_value_mm = new_value_mm
	_update_entry_display(entry)

func set_item_locked(item_id: String, locked: bool) -> void:
	if not item_entries.has(item_id):
		return
	
	var entry = item_entries[item_id]
	entry.lock_button.set_pressed_no_signal(locked)
	_update_lock_visual(entry)

func get_concentration(item_id: String) -> float:
	if item_entries.has(item_id):
		return item_entries[item_id].base_value_mm
	return 0.0

func is_item_locked(item_id: String) -> bool:
	if item_entries.has(item_id):
		return item_entries[item_id].lock_button.button_pressed or category_locked
	return false

#endregion
