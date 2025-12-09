## Dialog for adjusting UI element sizing ratios at runtime
## Changes persist between program instances via SettingsManager
class_name LayoutSettingsDialog
extends Window

signal settings_changed

#region UI Elements

var main_vbox: VBoxContainer
var ratios_grid: GridContainer
var min_widths_grid: GridContainer
var ratio_sliders: Dictionary = {}  ## {element_name: HSlider}
var width_spinboxes: Dictionary = {}  ## {element_name: SpinBox}

#endregion

#region Setup

func _init() -> void:
	title = "Layout Settings"
	size = Vector2(400, 450)
	exclusive = false
	transient = true
	unresizable = false
	close_requested.connect(_on_close_requested)

func _ready() -> void:
	_create_ui()
	_load_current_settings()

func _create_ui() -> void:
	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	add_child(main_vbox)
	
	## Title
	var title_label = Label.new()
	title_label.text = "Element Size Proportions"
	title_label.add_theme_font_size_override("font_size", 15)
	main_vbox.add_child(title_label)
	
	## Description
	var desc_label = Label.new()
	desc_label.text = "Adjust how UI elements share space when panels resize.\nHigher ratio = more space allocated."
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	main_vbox.add_child(desc_label)
	
	## Separator
	main_vbox.add_child(HSeparator.new())
	
	## Stretch Ratios Section
	var ratios_label = Label.new()
	ratios_label.text = "Stretch Ratios"
	ratios_label.add_theme_font_size_override("font_size", 13)
	main_vbox.add_child(ratios_label)
	
	ratios_grid = GridContainer.new()
	ratios_grid.columns = 3
	ratios_grid.add_theme_constant_override("h_separation", 12)
	ratios_grid.add_theme_constant_override("v_separation", 8)
	main_vbox.add_child(ratios_grid)
	
	_add_ratio_row("name", "Name Label")
	_add_ratio_row("slider", "Slider")
	_add_ratio_row("spinbox", "Value Input")
	_add_ratio_row("info", "Info Label")
	
	## Separator
	main_vbox.add_child(HSeparator.new())
	
	## Minimum Widths Section
	var widths_label = Label.new()
	widths_label.text = "Minimum Widths (pixels)"
	widths_label.add_theme_font_size_override("font_size", 13)
	main_vbox.add_child(widths_label)
	
	min_widths_grid = GridContainer.new()
	min_widths_grid.columns = 3
	min_widths_grid.add_theme_constant_override("h_separation", 12)
	min_widths_grid.add_theme_constant_override("v_separation", 8)
	main_vbox.add_child(min_widths_grid)
	
	_add_width_row("name", "Name Label")
	_add_width_row("slider", "Slider")
	_add_width_row("spinbox", "Value Input")
	_add_width_row("info", "Info Label")
	
	## Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer)
	
	## Button row
	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	main_vbox.add_child(button_row)
	
	var reset_btn = Button.new()
	reset_btn.text = "Reset to Defaults"
	reset_btn.pressed.connect(_on_reset_pressed)
	button_row.add_child(reset_btn)
	
	var btn_spacer = Control.new()
	btn_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(btn_spacer)
	
	var apply_btn = Button.new()
	apply_btn.text = "Apply"
	apply_btn.pressed.connect(_on_apply_pressed)
	button_row.add_child(apply_btn)
	
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_close_requested)
	button_row.add_child(close_btn)

func _add_ratio_row(element_name: String, display_name: String) -> void:
	var label = Label.new()
	label.text = display_name
	label.custom_minimum_size = Vector2(80, 0)
	ratios_grid.add_child(label)
	
	var slider = HSlider.new()
	slider.min_value = 0.1
	slider.max_value = 5.0
	slider.step = 0.1
	slider.custom_minimum_size = Vector2(150, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_ratio_changed.bind(element_name))
	ratios_grid.add_child(slider)
	ratio_sliders[element_name] = slider
	
	var value_label = Label.new()
	value_label.text = "1.0"
	value_label.custom_minimum_size = Vector2(40, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ratios_grid.add_child(value_label)

func _add_width_row(element_name: String, display_name: String) -> void:
	var label = Label.new()
	label.text = display_name
	label.custom_minimum_size = Vector2(80, 0)
	min_widths_grid.add_child(label)
	
	var spinbox = SpinBox.new()
	spinbox.min_value = 20
	spinbox.max_value = 200
	spinbox.step = 5
	spinbox.suffix = "px"
	spinbox.custom_minimum_size = Vector2(100, 0)
	spinbox.value_changed.connect(_on_width_changed.bind(element_name))
	min_widths_grid.add_child(spinbox)
	width_spinboxes[element_name] = spinbox
	
	## Placeholder for alignment
	var placeholder = Control.new()
	min_widths_grid.add_child(placeholder)

#endregion

#region Settings Management

func _load_current_settings() -> void:
	var settings = SettingsManager.get_instance()
	var ratios = settings.get_all_element_ratios()
	var widths = settings.get_all_element_min_widths()
	
	for element_name in ratio_sliders:
		if ratios.has(element_name):
			ratio_sliders[element_name].value = ratios[element_name]
			_update_ratio_label(element_name, ratios[element_name])
	
	for element_name in width_spinboxes:
		if widths.has(element_name):
			width_spinboxes[element_name].value = widths[element_name]

func _update_ratio_label(element_name: String, value: float) -> void:
	## Find the value label (third child after this slider's row)
	var slider = ratio_sliders[element_name]
	var idx = slider.get_index()
	if idx + 1 < ratios_grid.get_child_count():
		var value_label = ratios_grid.get_child(idx + 1)
		if value_label is Label:
			value_label.text = "%.1f" % value

#endregion

#region Callbacks

func _on_ratio_changed(value: float, element_name: String) -> void:
	_update_ratio_label(element_name, value)

func _on_width_changed(_value: float, _element_name: String) -> void:
	pass  ## Just for tracking, apply on button press

func _on_reset_pressed() -> void:
	var settings = SettingsManager.get_instance()
	settings.reset_element_sizing()
	_load_current_settings()
	settings_changed.emit()

func _on_apply_pressed() -> void:
	var settings = SettingsManager.get_instance()
	
	## Apply ratios
	for element_name in ratio_sliders:
		settings.set_element_ratio(element_name, ratio_sliders[element_name].value)
	
	## Apply minimum widths
	for element_name in width_spinboxes:
		settings.set_element_min_width(element_name, width_spinboxes[element_name].value)
	
	settings_changed.emit()

func _on_close_requested() -> void:
	hide()

#endregion

#region Public API

func show_dialog() -> void:
	_load_current_settings()
	popup_centered()

#endregion
