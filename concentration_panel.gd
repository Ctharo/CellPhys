## Reusable panel for displaying and editing concentrations
## Works with MoleculeData and EnzymeData Resources
## Features: editable spinbox, unit conversion, lock only affects simulation
class_name ConcentrationPanel
extends VBoxContainer

signal concentration_changed(id: String, value: float)
signal lock_changed(id: String, locked: bool)

#region Unit Conversion Constants

enum Unit { MILLIMOLAR, MICROMOLAR, NANOMOLAR, PICOMOLAR }

const UNIT_NAMES: Array[String] = ["mM", "µM", "nM", "pM"]
const UNIT_MULTIPLIERS: Array[float] = [1.0, 1000.0, 1000000.0, 1000000000.0]

#endregion

var item_entries: Dictionary = {}  ## {id: ItemEntry}
var category_locked: bool = false
var default_item_type: String = "molecule"

class ItemEntry:
	var container: HBoxContainer
	var name_label: Label
	var spinbox: SpinBox
	var slider: HSlider
	var unit_option: OptionButton
	var lock_button: CheckBox
	var info_label: Label
	var id: String
	var display_name: String
	var current_unit: int = 0
	var base_value_mm: float = 0.0
	var item_type: String = "molecule"
	var is_updating: bool = false

#region Setup

func clear() -> void:
	for child in get_children():
		child.queue_free()
	item_entries.clear()

func setup_items(items: Array, item_type: String) -> void:
	clear()
	default_item_type = item_type
	
	if items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No %ss in simulation" % item_type
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		add_child(empty_label)
		return
	
	for item in items:
		_create_item_entry(item, item_type)

func add_item(item, item_type: String) -> void:
	if item_entries.is_empty() and get_child_count() > 0:
		var first_child = get_child(0)
		if first_child is Label:
			first_child.queue_free()
	
	_create_item_entry(item, item_type)

func _create_item_entry(item, item_type: String) -> void:
	var entry = ItemEntry.new()
	entry.item_type = item_type
	
	var item_id: String
	var item_name: String
	var item_conc: float
	var item_locked: bool
	var extra_info: String = ""
	
	## Handle both old classes and new Resource classes
	if item_type == "enzyme":
		if item is EnzymeData:
			item_id = item.enzyme_id
			item_name = item.enzyme_name
			item_conc = item.concentration
			item_locked = item.is_locked
			var degrade_str = "t½=%.0fs" % item.half_life if item.is_degradable else "stable"
			extra_info = "(%s, %d rxn)" % [degrade_str, item.reactions.size()]
		else:  ## Legacy Enzyme class
			item_id = item.id
			item_name = item.name
			item_conc = item.concentration
			item_locked = item.is_locked
			var degrade_str = "t½=%.0fs" % item.half_life if item.is_degradable else "stable"
			extra_info = "(%s, %d rxn)" % [degrade_str, item.reactions.size()]
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
	entry.lock_button.tooltip_text = "Lock from simulation changes (still manually editable)"
	entry.lock_button.toggled.connect(_on_lock_toggled.bind(item_id))
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
	entry.slider.max_value = _get_slider_max_for_unit(item_type, Unit.MILLIMOLAR)
	entry.slider.step = 0.0001
	entry.slider.value = item_conc
	entry.slider.value_changed.connect(_on_slider_changed.bind(item_id))
	entry.container.add_child(entry.slider)
	
	## SpinBox
	entry.spinbox = SpinBox.new()
	entry.spinbox.custom_minimum_size = Vector2(90, 0)
	entry.spinbox.min_value = 0.0
	entry.spinbox.max_value = _get_spinbox_max_for_unit(item_type, Unit.MILLIMOLAR)
	entry.spinbox.step = 0.0001
	entry.spinbox.value = item_conc
	entry.spinbox.allow_greater = true
	entry.spinbox.allow_lesser = false
	entry.spinbox.select_all_on_focus = true
	entry.spinbox.add_theme_font_size_override("font_size", 11)
	entry.spinbox.value_changed.connect(_on_spinbox_changed.bind(item_id))
	entry.container.add_child(entry.spinbox)
	
	## Unit selector
	entry.unit_option = OptionButton.new()
	entry.unit_option.custom_minimum_size = Vector2(55, 0)
	entry.unit_option.add_theme_font_size_override("font_size", 11)
	for i in range(UNIT_NAMES.size()):
		entry.unit_option.add_item(UNIT_NAMES[i], i)
	entry.unit_option.selected = Unit.MILLIMOLAR
	entry.unit_option.item_selected.connect(_on_unit_changed.bind(item_id))
	entry.container.add_child(entry.unit_option)
	
	## Info label
	entry.info_label = Label.new()
	entry.info_label.text = extra_info
	entry.info_label.add_theme_font_size_override("font_size", 10)
	entry.info_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	entry.container.add_child(entry.info_label)
	
	add_child(entry.container)
	item_entries[item_id] = entry
	
	_update_lock_visual(entry, item_locked)

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

#endregion

#region Unit Conversion

func _mm_to_unit(value_mm: float, unit: int) -> float:
	return value_mm * UNIT_MULTIPLIERS[unit]

func _unit_to_mm(value: float, unit: int) -> float:
	return value / UNIT_MULTIPLIERS[unit]

func _get_step_for_unit(unit: int) -> float:
	match unit:
		Unit.MILLIMOLAR:
			return 0.0001
		Unit.MICROMOLAR:
			return 0.1
		Unit.NANOMOLAR:
			return 100.0
		Unit.PICOMOLAR:
			return 100000.0
		_:
			return 0.0001

#endregion

#region Updates

func update_values(items: Array, item_type: String) -> void:
	for item in items:
		var item_id: String
		var item_conc: float
		var item_locked: bool
		
		if item_type == "enzyme":
			if item is EnzymeData:
				item_id = item.enzyme_id
				item_conc = item.concentration
				item_locked = item.is_locked
			else:
				item_id = item.id
				item_conc = item.concentration
				item_locked = item.is_locked
		else:
			if item is MoleculeData:
				item_id = item.molecule_name
				item_conc = item.concentration
				item_locked = item.is_locked
			else:
				item_id = item.name
				item_conc = item.concentration
				item_locked = item.is_locked
		
		if not item_entries.has(item_id):
			continue
		
		var entry: ItemEntry = item_entries[item_id]
		
		if not item_locked and not entry.spinbox.has_focus() and not entry.slider.has_focus():
			entry.is_updating = true
			entry.base_value_mm = item_conc
			var display_value = _mm_to_unit(item_conc, entry.current_unit)
			entry.slider.set_value_no_signal(display_value)
			entry.spinbox.set_value_no_signal(display_value)
			entry.is_updating = false

func set_category_locked(locked: bool) -> void:
	category_locked = locked
	for item_id in item_entries:
		var entry: ItemEntry = item_entries[item_id]
		_update_category_lock_visual(entry, locked)

func _update_lock_visual(entry: ItemEntry, is_locked: bool) -> void:
	if is_locked:
		entry.name_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
	else:
		entry.name_label.remove_theme_color_override("font_color")

func _update_category_lock_visual(entry: ItemEntry, p_category_locked: bool) -> void:
	if p_category_locked and not entry.lock_button.button_pressed:
		entry.container.modulate = Color(0.9, 0.8, 0.8)
	else:
		entry.container.modulate = Color.WHITE

#endregion

#region Callbacks

func _on_slider_changed(value: float, item_id: String) -> void:
	if not item_entries.has(item_id):
		return
	
	var entry: ItemEntry = item_entries[item_id]
	if entry.is_updating:
		return
	
	entry.is_updating = true
	entry.spinbox.set_value_no_signal(value)
	entry.base_value_mm = _unit_to_mm(value, entry.current_unit)
	concentration_changed.emit(item_id, entry.base_value_mm)
	entry.is_updating = false

func _on_spinbox_changed(value: float, item_id: String) -> void:
	if not item_entries.has(item_id):
		return
	
	var entry: ItemEntry = item_entries[item_id]
	if entry.is_updating:
		return
	
	entry.is_updating = true
	entry.slider.set_value_no_signal(clampf(value, entry.slider.min_value, entry.slider.max_value))
	entry.base_value_mm = _unit_to_mm(value, entry.current_unit)
	concentration_changed.emit(item_id, entry.base_value_mm)
	entry.is_updating = false

func _on_unit_changed(unit_index: int, item_id: String) -> void:
	if not item_entries.has(item_id):
		return
	
	var entry: ItemEntry = item_entries[item_id]
	entry.is_updating = true
	entry.current_unit = unit_index
	var new_display_value = _mm_to_unit(entry.base_value_mm, unit_index)
	
	entry.slider.max_value = _get_slider_max_for_unit(entry.item_type, unit_index)
	entry.slider.step = _get_step_for_unit(unit_index)
	entry.slider.set_value_no_signal(clampf(new_display_value, 0.0, entry.slider.max_value))
	
	entry.spinbox.max_value = _get_spinbox_max_for_unit(entry.item_type, unit_index)
	entry.spinbox.step = _get_step_for_unit(unit_index)
	entry.spinbox.set_value_no_signal(new_display_value)
	entry.is_updating = false

func _on_lock_toggled(pressed: bool, item_id: String) -> void:
	if not item_entries.has(item_id):
		return
	
	var entry: ItemEntry = item_entries[item_id]
	_update_lock_visual(entry, pressed)
	lock_changed.emit(item_id, pressed)

#endregion
