## Reusable panel for displaying and editing concentrations
## Used for both enzymes and molecules
class_name ConcentrationPanel
extends VBoxContainer

signal concentration_changed(id: String, value: float)
signal lock_changed(id: String, locked: bool)

var item_entries: Dictionary = {}  ## {id: ItemEntry}
var category_locked: bool = false  ## Whether the entire category is locked

class ItemEntry:
	var container: HBoxContainer
	var name_label: Label
	var value_label: Label
	var slider: HSlider
	var lock_button: CheckBox
	var info_label: Label
	var id: String

#region Setup

func clear() -> void:
	for child in get_children():
		child.queue_free()
	item_entries.clear()

func setup_items(items: Array, item_type: String) -> void:
	clear()
	
	if items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No %ss in simulation" % item_type
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		add_child(empty_label)
		return
	
	for item in items:
		_create_item_entry(item, item_type)

## Add a single item dynamically (for reactive updates)
func add_item(item, item_type: String) -> void:
	## Remove "no items" label if present
	if item_entries.is_empty() and get_child_count() > 0:
		var first_child = get_child(0)
		if first_child is Label:
			first_child.queue_free()
	
	_create_item_entry(item, item_type)

func _create_item_entry(item, item_type: String) -> void:
	var entry = ItemEntry.new()
	
	## Get item properties based on type
	var item_id: String
	var item_name: String
	var item_conc: float
	var item_locked: bool
	var extra_info: String = ""
	
	if item_type == "enzyme":
		item_id = item.id
		item_name = item.name
		item_conc = item.concentration
		item_locked = item.is_locked
		var degrade_str = "t½=%.0fs" % item.half_life if item.is_degradable else "stable"
		extra_info = "(%s, %d rxn)" % [degrade_str, item.reactions.size()]
	else:  ## molecule
		item_id = item.name
		item_name = item.name
		item_conc = item.concentration
		item_locked = item.is_locked
		extra_info = "(E=%.0f kJ/mol)" % item.potential_energy
	
	entry.id = item_id
	
	## Container
	entry.container = HBoxContainer.new()
	entry.container.add_theme_constant_override("separation", 8)
	
	## Lock checkbox
	entry.lock_button = CheckBox.new()
	entry.lock_button.button_pressed = item_locked
	entry.lock_button.tooltip_text = "Lock concentration"
	entry.lock_button.toggled.connect(_on_lock_toggled.bind(item_id))
	entry.container.add_child(entry.lock_button)
	
	## Name label
	entry.name_label = Label.new()
	entry.name_label.text = item_name
	entry.name_label.custom_minimum_size = Vector2(90, 0)
	entry.name_label.add_theme_font_size_override("font_size", 12)
	entry.container.add_child(entry.name_label)
	
	## Slider
	entry.slider = HSlider.new()
	entry.slider.custom_minimum_size = Vector2(100, 0)
	entry.slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.slider.min_value = 0.0
	entry.slider.max_value = _get_max_for_type(item_type)
	entry.slider.step = 0.001
	entry.slider.value = item_conc
	entry.slider.editable = not item_locked and not category_locked
	entry.slider.value_changed.connect(_on_slider_changed.bind(item_id))
	entry.container.add_child(entry.slider)
	
	## Value label
	entry.value_label = Label.new()
	entry.value_label.text = "%.4f" % item_conc
	entry.value_label.custom_minimum_size = Vector2(55, 0)
	entry.value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	entry.value_label.add_theme_font_size_override("font_size", 11)
	entry.container.add_child(entry.value_label)
	
	## Unit label
	var unit_label = Label.new()
	unit_label.text = "mM"
	unit_label.add_theme_font_size_override("font_size", 11)
	unit_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	entry.container.add_child(unit_label)
	
	## Info label
	entry.info_label = Label.new()
	entry.info_label.text = extra_info
	entry.info_label.add_theme_font_size_override("font_size", 10)
	entry.info_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	entry.container.add_child(entry.info_label)
	
	add_child(entry.container)
	item_entries[item_id] = entry

func _get_max_for_type(item_type: String) -> float:
	if item_type == "enzyme":
		return 0.1  ## Enzymes typically in µM-mM range
	else:
		return 20.0  ## Metabolites can be higher

#endregion

#region Updates

func update_values(items: Array, item_type: String) -> void:
	for item in items:
		var item_id: String
		var item_conc: float
		var item_locked: bool
		
		if item_type == "enzyme":
			item_id = item.id
			item_conc = item.concentration
			item_locked = item.is_locked
		else:
			item_id = item.name
			item_conc = item.concentration
			item_locked = item.is_locked
		
		if not item_entries.has(item_id):
			continue
		
		var entry: ItemEntry = item_entries[item_id]
		
		## Update value label
		entry.value_label.text = "%.4f" % item_conc
		
		## Update slider if not being dragged and not locked
		if not entry.slider.has_focus() and not item_locked:
			entry.slider.set_value_no_signal(item_conc)

## Set category-level lock state (affects all sliders)
func set_category_locked(locked: bool) -> void:
	category_locked = locked
	for item_id in item_entries:
		var entry: ItemEntry = item_entries[item_id]
		## Only allow editing if both category and individual item are unlocked
		entry.slider.editable = not locked and not entry.lock_button.button_pressed
		
		## Visual feedback for category lock
		if locked:
			entry.name_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
		else:
			entry.name_label.remove_theme_color_override("font_color")

#endregion

#region Callbacks

func _on_slider_changed(value: float, item_id: String) -> void:
	if item_entries.has(item_id):
		item_entries[item_id].value_label.text = "%.4f" % value
	concentration_changed.emit(item_id, value)

func _on_lock_toggled(pressed: bool, item_id: String) -> void:
	if item_entries.has(item_id):
		item_entries[item_id].slider.editable = not pressed and not category_locked
	lock_changed.emit(item_id, pressed)

#endregion
