## Real-time chart panel for plotting concentration histories
## Uses custom drawing for performance
class_name ChartPanel
extends Panel

#region Configuration

@export var background_color: Color = Color(0.1, 0.1, 0.12)
@export var grid_color: Color = Color(0.2, 0.2, 0.25)
@export var axis_color: Color = Color(0.4, 0.4, 0.45)
@export var margin: Vector2 = Vector2(50, 30)

#endregion

#region Chart State

var time_data: Array = []
var series_data: Dictionary = {}  ## {name: Array[float]}
var y_min: float = 0.0
var y_max: float = 10.0
var auto_scale: bool = true

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
	pass

func _draw() -> void:
	var rect = get_rect()
	var chart_rect = Rect2(
		margin.x, margin.y,
		rect.size.x - margin.x * 2,
		rect.size.y - margin.y * 2
	)
	
	## Background
	draw_rect(Rect2(Vector2.ZERO, rect.size), background_color)
	
	## Grid
	_draw_grid(chart_rect)
	
	## Axes
	_draw_axes(chart_rect)
	
	## Series
	_draw_series(chart_rect)
	
	## Legend
	_draw_legend(chart_rect)

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
		var value = y_min + (y_max - y_min) * float(i) / num_labels
		var y = chart_rect.position.y + chart_rect.size.y * (1.0 - float(i) / num_labels)
		var label = _format_value(value)
		draw_string(font, Vector2(5, y + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, axis_color)

func _draw_series(chart_rect: Rect2) -> void:
	if time_data.is_empty():
		return
	
	var y_range = y_max - y_min
	if y_range <= 0:
		y_range = 1.0
	
	for series_name in series_data:
		var data: Array = series_data[series_name]
		if data.size() < 2:
			continue
		
		var color = _get_series_color(series_name)
		var points: PackedVector2Array = []
		
		for i in range(data.size()):
			var x = chart_rect.position.x + chart_rect.size.x * float(i) / (data.size() - 1)
			var normalized_y = (data[i] - y_min) / y_range
			var y = chart_rect.position.y + chart_rect.size.y * (1.0 - normalized_y)
			y = clampf(y, chart_rect.position.y, chart_rect.position.y + chart_rect.size.y)
			points.append(Vector2(x, y))
		
		if points.size() >= 2:
			draw_polyline(points, color, 2.0, true)

func _draw_legend(chart_rect: Rect2) -> void:
	if series_data.is_empty():
		return
	
	var font = ThemeDB.fallback_font
	var font_size = 10
	var line_height = 14
	var legend_x = chart_rect.position.x + chart_rect.size.x - 100
	var legend_y = chart_rect.position.y + 10
	
	var idx = 0
	for series_name in series_data:
		var color = _get_series_color(series_name)
		var y = legend_y + idx * line_height
		
		## Color swatch
		draw_rect(Rect2(legend_x, y - 8, 12, 10), color)
		
		## Name (truncated)
		var display_name = series_name
		if display_name.length() > 10:
			display_name = display_name.substr(0, 8) + ".."
		draw_string(font, Vector2(legend_x + 16, y), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		
		idx += 1
		if idx >= 10:  ## Max 10 in legend
			break

func _get_series_color(series_name: String) -> Color:
	if not color_assignments.has(series_name):
		color_assignments[series_name] = color_assignments.size() % series_colors.size()
	return series_colors[color_assignments[series_name]]

func _format_value(value: float) -> String:
	if abs(value) < 0.001:
		return "%.0f" % value
	elif abs(value) < 1.0:
		return "%.3f" % value
	elif abs(value) < 100.0:
		return "%.1f" % value
	else:
		return "%.0f" % value

#endregion

#region Public Interface

func update_chart(data: Dictionary, use_auto_scale: bool = true) -> void:
	time_data = data.get("time", [])
	series_data = data.get("series", {})
	auto_scale = use_auto_scale
	
	if auto_scale:
		_calculate_auto_scale()
	
	queue_redraw()

func set_y_range(min_val: float, max_val: float) -> void:
	y_min = min_val
	y_max = max_val
	auto_scale = false
	queue_redraw()

func _calculate_auto_scale() -> void:
	var all_values: Array[float] = []
	
	for series_name in series_data:
		for val in series_data[series_name]:
			all_values.append(val)
	
	if all_values.is_empty():
		y_min = 0.0
		y_max = 10.0
		return
	
	var min_val = all_values.min()
	var max_val = all_values.max()
	
	## Add padding
	var range_val = max_val - min_val
	if range_val < 0.001:
		range_val = max_val * 0.2 if max_val > 0 else 1.0
	
	y_min = max(0.0, min_val - range_val * 0.1)
	y_max = max_val + range_val * 0.1
	
	## Ensure minimum range
	if y_max - y_min < 0.001:
		y_max = y_min + 1.0

func clear() -> void:
	time_data.clear()
	series_data.clear()
	color_assignments.clear()
	queue_redraw()

#endregion
