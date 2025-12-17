## Real-time chart panel for plotting concentration histories
## Uses custom drawing for performance
class_name ChartPanel
extends Panel

#region Configuration

@export var background_color: Color = Color(0.1, 0.1, 0.12)
@export var grid_color: Color = Color(0.2, 0.2, 0.25)
@export var axis_color: Color = Color(0.4, 0.4, 0.45)
@export var margin: Vector2 = Vector2(50, 30)
@export var no_data_color: Color = Color(0.5, 0.5, 0.55)

#endregion

#region Chart State

var time_data: Array[float] = []
var series_data: Dictionary = {}  ## {name: Array[float]}
var y_min: float = 0.0
var y_max: float = 10.0
var auto_scale: bool = true
var _has_valid_data: bool = false

## Color palette for series
var series_colors: Array[Color] = [
	Color(0.2, 0.6, 1.0),   ## Blue
	Color(1.0, 0.4, 0.3),   ## Red
	Color(0.3, 0.9, 0.4),   ## Green
	Color(1.0, 0.8, 0.2),   ## Yellow
	Color(0.8, 0.4, 1.0),   ## Purple
	Color(1.0, 0.6, 0.2),   ## Orange
	Color(0.4, 0.9, 0.9),   ## Cyan
	Color(1.0, 0.5, 0.7),   ## Pink
	Color(0.6, 0.8, 0.4),   ## Lime
	Color(0.9, 0.5, 0.5),   ## Salmon
]

var color_assignments: Dictionary = {}  ## {series_name: color_index}

#endregion

#region Initialization

func _ready() -> void:
	## Ensure we redraw when resized
	resized.connect(_on_resized)
	## Initial redraw
	queue_redraw()

func _on_resized() -> void:
	queue_redraw()

func _draw() -> void:
	var rect = get_rect()
	
	## Ensure minimum chart size
	var chart_rect = Rect2(
		margin.x, margin.y,
		maxf(rect.size.x - margin.x * 2, 10),
		maxf(rect.size.y - margin.y * 2, 10)
	)
	
	## Background
	draw_rect(Rect2(Vector2.ZERO, rect.size), background_color)
	
	## Grid
	_draw_grid(chart_rect)
	
	## Axes
	_draw_axes(chart_rect)
	
	## Series or "no data" message
	if _has_valid_data:
		_draw_series(chart_rect)
		_draw_legend(chart_rect)
	else:
		_draw_no_data(chart_rect)

#endregion

#region Drawing

func _draw_grid(chart_rect: Rect2) -> void:
	var num_horizontal = 5
	var num_vertical = 8
	
	## Horizontal grid lines
	for i in range(num_horizontal + 1):
		var y = chart_rect.position.y + chart_rect.size.y * (1.0 - float(i) / num_horizontal)
		draw_line(
			Vector2(chart_rect.position.x, y),
			Vector2(chart_rect.position.x + chart_rect.size.x, y),
			grid_color, 1.0
		)
	
	## Vertical grid lines
	for i in range(num_vertical + 1):
		var x = chart_rect.position.x + chart_rect.size.x * float(i) / num_vertical
		draw_line(
			Vector2(x, chart_rect.position.y),
			Vector2(x, chart_rect.position.y + chart_rect.size.y),
			grid_color, 1.0
		)

func _draw_axes(chart_rect: Rect2) -> void:
	## Y-axis
	draw_line(
		chart_rect.position,
		Vector2(chart_rect.position.x, chart_rect.position.y + chart_rect.size.y),
		axis_color, 2.0
	)
	
	## X-axis
	draw_line(
		Vector2(chart_rect.position.x, chart_rect.position.y + chart_rect.size.y),
		Vector2(chart_rect.position.x + chart_rect.size.x, chart_rect.position.y + chart_rect.size.y),
		axis_color, 2.0
	)
	
	## Y-axis labels
	var num_labels = 5
	var font = ThemeDB.fallback_font
	var font_size = 10
	
	for i in range(num_labels + 1):
		var label_value = y_min + (y_max - y_min) * float(i) / num_labels
		var y = chart_rect.position.y + chart_rect.size.y * (1.0 - float(i) / num_labels)
		var label = _format_value(label_value)
		draw_string(font, Vector2(5, y + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, axis_color)

func _draw_no_data(chart_rect: Rect2) -> void:
	var font = ThemeDB.fallback_font
	var font_size = 14
	var text = "Start simulation to see data"
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos = Vector2(
		chart_rect.position.x + (chart_rect.size.x - text_size.x) / 2,
		chart_rect.position.y + (chart_rect.size.y + text_size.y) / 2
	)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, no_data_color)

func _draw_series(chart_rect: Rect2) -> void:
	var y_range = y_max - y_min
	if y_range <= 0.0:
		y_range = 1.0
	
	for series_name in series_data:
		var data: Array = series_data[series_name]
		if data.size() < 2:
			continue
		
		var color = _get_series_color(series_name)
		var points: PackedVector2Array = []
		
		var data_count = data.size()
		var divisor = maxf(float(data_count - 1), 1.0)
		
		for i in range(data_count):
			var x = chart_rect.position.x + chart_rect.size.x * float(i) / divisor
			var val = data[i]
			if not (val is float or val is int):
				val = 0.0
			var normalized_y = (float(val) - y_min) / y_range
			var y = chart_rect.position.y + chart_rect.size.y * (1.0 - normalized_y)
			y = clampf(y, chart_rect.position.y, chart_rect.position.y + chart_rect.size.y)
			points.append(Vector2(x, y))
		
		if points.size() >= 2:
			draw_polyline(points, color, 2.0, true)
			
			## Draw endpoint marker
			var last_point = points[points.size() - 1]
			draw_circle(last_point, 4.0, color)

func _draw_legend(chart_rect: Rect2) -> void:
	if series_data.is_empty():
		return
	
	var font = ThemeDB.fallback_font
	var font_size = 10
	var line_height = 14
	var legend_x = chart_rect.position.x + chart_rect.size.x - 120
	var legend_y = chart_rect.position.y + 10
	
	var idx = 0
	for series_name in series_data:
		var data: Array = series_data[series_name]
		if data.size() < 2:
			continue
		
		var color = _get_series_color(series_name)
		var y = legend_y + idx * line_height
		
		## Color swatch
		draw_rect(Rect2(legend_x, y - 8, 12, 10), color)
		
		## Name (truncated) and current value
		var display_name = series_name
		if display_name.length() > 8:
			display_name = display_name.substr(0, 6) + ".."
		
		var current_val = data[data.size() - 1] if data.size() > 0 else 0.0
		var label_text = "%s: %.3f" % [display_name, current_val]
		draw_string(font, Vector2(legend_x + 16, y), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		
		idx += 1
		if idx >= 10:
			break

func _get_series_color(series_name: String) -> Color:
	if not color_assignments.has(series_name):
		color_assignments[series_name] = color_assignments.size() % series_colors.size()
	return series_colors[color_assignments[series_name]]

func _format_value(val: float) -> String:
	var abs_val = absf(val)
	if abs_val < 0.001 and abs_val > 0.0:
		return "%.1e" % val
	elif abs_val < 1.0:
		return "%.3f" % val
	elif abs_val < 100.0:
		return "%.1f" % val
	else:
		return "%.0f" % val

#endregion

#region Public Interface

## Main update method - accepts dictionary with "time" and "series" keys
func update_chart(data: Dictionary, use_auto_scale: bool = true) -> void:
	## Extract time data
	var raw_time = data.get("time", [])
	time_data.clear()
	for t in raw_time:
		if t is float or t is int:
			time_data.append(float(t))
	
	## Extract series data
	var raw_series = data.get("series", {})
	series_data.clear()
	
	for series_name in raw_series:
		var raw_values = raw_series[series_name]
		var values: Array[float] = []
		for v in raw_values:
			if v is float or v is int:
				values.append(float(v))
			else:
				values.append(0.0)
		if values.size() > 0:
			series_data[series_name] = values
	
	auto_scale = use_auto_scale
	
	## Check if we have valid data to display
	_has_valid_data = _check_valid_data()
	
	if auto_scale and _has_valid_data:
		_calculate_auto_scale()
	
	queue_redraw()

## Alternative update method for direct data arrays
func update_data(time_array: Array, series_dict: Dictionary, _title: String = "") -> void:
	## Convert to internal format
	time_data.clear()
	for t in time_array:
		if t is float or t is int:
			time_data.append(float(t))
	
	series_data.clear()
	for series_name in series_dict:
		var raw_values = series_dict[series_name]
		var values: Array[float] = []
		for v in raw_values:
			if v is float or v is int:
				values.append(float(v))
			else:
				values.append(0.0)
		if values.size() > 0:
			series_data[series_name] = values
	
	_has_valid_data = _check_valid_data()
	
	if auto_scale and _has_valid_data:
		_calculate_auto_scale()
	
	queue_redraw()

func _check_valid_data() -> bool:
	## Need at least 2 time points
	if time_data.size() < 2:
		return false
	
	## Need at least one series with 2+ points
	for series_name in series_data:
		var data: Array = series_data[series_name]
		if data.size() >= 2:
			return true
	
	return false

func set_y_range(min_val: float, max_val: float) -> void:
	y_min = min_val
	y_max = max_val
	auto_scale = false
	queue_redraw()

func _calculate_auto_scale() -> void:
	var all_values: Array[float] = []
	
	for series_name in series_data:
		var data: Array = series_data[series_name]
		for val in data:
			if val is float or val is int:
				all_values.append(float(val))
	
	if all_values.is_empty():
		y_min = 0.0
		y_max = 10.0
		return
	
	var min_val: float = all_values[0]
	var max_val: float = all_values[0]
	
	for val in all_values:
		if val < min_val:
			min_val = val
		if val > max_val:
			max_val = val
	
	## Add padding
	var range_val = max_val - min_val
	if range_val < 0.001:
		range_val = maxf(max_val * 0.2, 1.0)
	
	y_min = maxf(0.0, min_val - range_val * 0.1)
	y_max = max_val + range_val * 0.1
	
	## Ensure minimum range
	if y_max - y_min < 0.001:
		y_max = y_min + 1.0

func clear() -> void:
	time_data.clear()
	series_data.clear()
	color_assignments.clear()
	_has_valid_data = false
	queue_redraw()

#endregion
