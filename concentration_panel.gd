## Reusable panel for displaying and editing concentrations
## Features: global unit selection, category lock, persistence, scientific notation
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
	for unit_name in UNIT_NAMES:
		global_unit_option.add_item(unit_name)
	global_unit_option.selected = current_global_unit
	global_unit_option.item_selected.connect(_on_global_unit_changed)
	header_container.add_child(global_unit_option)
	
	## Category lock
	category_lock_button = CheckBox.new()
	category_lock_button.text = "Lock All"
	category_lock_button.add_theme_font_size_override("font_size", 11)
	category_lock_button.toggled.connect(_on_category_lock_toggled)
	header_container.add_child(category_lock_button)
	
	add_child(header_container)
	
	## Separator line
	var line = HSeparator.new()
	add_child(line)

func _load_settings() -> void:
	var settings = SettingsManager.get_instance()
	if default_item_type == "molecule":
		current_global_unit = settings.molecule_unit
		category_locked = settings.lock_molecules
	else:
		current_global_unit = settings.enzyme_unit
		category_locked = settings.lock_enzymes
	
	global_unit_option.selected = current_global_unit
	category_lock_button.button_pressed = category_locked

#endregion

#region Item Management

func clear_items() -> void:
	## Remove all children except header and separator
	var children_to_remove: Array[Node] = []
	for child in get_children():
		if child != header_container and child is not HSeparator:
			children_to_remove.append(child)
	for child in children_to_remove:
		child.queue_free()
	item_entries.clear()

func setup_items(items: Array, item_type: String) -> void:
	## Clear existing entries
	clear_items()
	default_item_type = item_type
	_load_settings()  ## Reload settings for this item type
	
	if items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No %ss in simulation" % item_type
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		add_child(empty_label)
		return
	
	## Add all items
	for item in items:
		add_item(item, item_type)

func add_item(item, item_type: String = "") -> void:
	if item_type.is_empty():
		item_type = default_item_type
	
	var entry = ItemEntry.new()
	entry.item_type = item_type
	entry.current_unit = current_global_unit
	
	var item_id: String
	var item_name: String
	var item_conc: float
	var item_locked: bool = false
	var extra_info: String = ""
	
	## Handle different item types
	if item_type == "enzyme":
		if item is EnzymeData:
			item_id = item.enzyme_id
			item_name = item.enzyme_name
			item_conc = item.concentration
			item_locked = item.is_locked
			var degrade_str = "t½=%.0fs" % item.half_life if item.is_degradable else "stable"
			extra_info = "(%s)" % degrade_str
		else:  ## Legacy Enzyme class
			item_id = item.id if "id" in item else item.enzyme_id
			item_name = item.name if "name" in item else item.enzyme_name
			item_conc = item.concentration
			item_locked = item.is_locked
			var degrade_str = "t½=%.0fs" % item.half_life if item.is_degradable else "stable"
			extra_info = "(%s)" % degrade_str
	else:  ## molecule
		if item is MoleculeData:
			item_id = item.molecule_name
			item_name = item.molecule_name
			item_conc = item.concentration
			item_locked = item.is_locked
			extra_info = "(E=%.0f kJ/mol)" % item.potential_energy
		else:  ## Legacy Molecule class
			item_id = item.name
			item_name = item.name
			item_conc = item.concentration
			item_locked = item.is_locked
			extra_info = "(E=%.0f kJ/mol)" % item.potential_energy
	
	entry.id = item_id
	entry.display_name = item_name
	entry.base_value_mm = item_conc
	
	## Main container
	entry.container = HBoxContainer.new()
	entry.container.add_theme_constant_override("separation", 6)
	
	## Lock checkbox
	entry.lock_button = CheckBox.new()
	entry.lock_button.button_pressed = item_locked
	entry.lock_button.tooltip_text = "Lock from simulation changes"
	entry.lock_button.toggled.connect(_on_lock_toggled.bind(item_id))
	entry.lock_button.disabled = category_locked
	entry.container.add_child(entry.lock_button)
	
	## Name label
	entry.name_label = Label.new()
	entry.name_label.text = item_name
	entry.name_label.custom_minimum_size = Vector2(80, 0)
	entry.name_label.add_theme_font_size_override("font_size", 12)
	entry.name_label.clip_text = true
	entry.container.add_child(entry.name_label)
	
	## Slider
	entry.slider = HSlider.new()
	entry.slider.custom_minimum_size = Vector2(80, 0)
	entry.slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.slider.min_value = 0.0
	entry.slider.max_value = _get_slider_max_for_unit(item_type, entry.current_unit)
	entry.slider.step = 0.0001
	entry.slider.value = item_conc * UNIT_MULTIPLIERS[entry.current_unit]
	entry.slider.value_changed.connect(_on_slider_changed.bind(item_id))
	entry.container.add_child(entry.slider)
	
	## ScientificSpinBox (replaces standard SpinBox)
	entry.spinbox = ScientificSpinBox.new()
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
	
	## Info label
	entry.info_label = Label.new()
	entry.info_label.text = extra_info
	entry.info_label.add_theme_font_size_override("font_size", 10)
	entry.info_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
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
	entry.slider.value = display_value
	entry.spinbox.value = display_value
	
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

#endregion

#region Callbacks

func _on_global_unit_changed(index: int) -> void:
	current_global_unit = index
	_update_all_units()
	
	## Save setting
	var settings = SettingsManager.get_instance()
	if default_item_type == "molecule":
		settings.set_molecule_unit(index)
	else:
		settings.set_enzyme_unit(index)
	
	global_unit_changed.emit(index)

func _on_category_lock_toggled(pressed: bool) -> void:
	category_locked = pressed
	
	## Save setting
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
	
	## Convert from display unit to mM
	entry.base_value_mm = value / UNIT_MULTIPLIERS[entry.current_unit]
	entry.spinbox.value = value
	
	entry.is_updating = false
	
	concentration_changed.emit(item_id, entry.base_value_mm)

func _on_spinbox_changed(value: float, item_id: String) -> void:
	if not item_entries.has(item_id):
		return
	
	var entry = item_entries[item_id] as ItemEntry
	if entry.is_updating:
		return
	
	entry.is_updating = true
	
	## Convert from display unit to mM
	entry.base_value_mm = value / UNIT_MULTIPLIERS[entry.current_unit]
	entry.slider.value = value
	
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
		return item.id if "id" in item else ""
	else:
		if item is MoleculeData:
			return item.molecule_name
		return item.name if "name" in item else ""

func _get_item_concentration(item) -> float:
	return item.concentration

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
	entry.lock_button.button_pressed = locked
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
