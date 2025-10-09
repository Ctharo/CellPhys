# Aerobic Respiration Simulator UI - Godot 4.5
# Visual representation with dynamic metabolic arrows

extends Control

class_name AerobicRespirationSimulatorUI

# ============= MOLECULE CONCENTRATIONS (mM) =============
var glucose: float = 5.0
var pyruvate: float = 0.1
var acetyl_coa: float = 0.05
var citrate: float = 0.1
var isocitrate: float = 0.05
var alpha_ketoglutarate: float = 0.08
var succinate: float = 0.1
var malate: float = 0.1
var oxaloacetate: float = 0.15
var nadh: float = 0.5
var nad: float = 5.0
var atp: float = 2.0
var adp: float = 3.0
var oxygen: float = 1.0
var co2: float = 0.1

# ============= ENZYME PARAMETERS =============
var vmax_pfk: float = 25.0
var km_pfk: float = 1.0
var vmax_pdh: float = 8.0
var km_pdh: float = 0.2
var vmax_cs: float = 12.0
var km_cs_acetyl: float = 0.01
var km_cs_oaa: float = 0.01
var vmax_icdh: float = 10.0
var km_icdh: float = 0.05
var vmax_akgdh: float = 8.0
var km_akgdh: float = 0.08
var vmax_sdh: float = 6.0
var km_sdh: float = 0.2
var vmax_mdh: float = 15.0
var km_mdh: float = 0.1
var vmax_etc: float = 20.0
var km_nadh: float = 0.1

# ============= REACTION RATES =============
var r_pfk: float = 0.0
var r_pdh: float = 0.0
var r_cs: float = 0.0
var r_icdh: float = 0.0
var r_akgdh: float = 0.0
var r_sdh: float = 0.0
var r_mdh: float = 0.0
var r_etc: float = 0.0

var timestep: float = 0.05
var total_time: float = 0.0
var is_paused: bool = false

# ============= MOLECULE DISPLAY INFO =============
var molecules_data: Dictionary = {}

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	# Add background color rect
	var bg = ColorRect.new()
	bg.color = Color.from_string("#0a0e27", Color.BLACK)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	move_child(bg, 0)
	
	initialize_molecule_data()
	print("🧬 Aerobic Respiration Simulator UI Ready!")
	print("Controls:")
	print("  [SPACE] - Add 5 mM glucose")
	print("  [ENTER] - Add 10 mM glucose")
	print("  [O] - Trigger hypoxia")
	print("  [R] - Reset")
	print("  [P] - Pause/Resume")
	print("  [+] Speed up, [-] Slow down")

func initialize_molecule_data() -> void:
	"""Initialize molecule tracking data"""
	molecules_data = {
		"Glucose": {"value": glucose, "pos": Vector2(100, 100), "color": Color.YELLOW, "max": 10.0},
		"Pyruvate": {"value": pyruvate, "pos": Vector2(300, 100), "color": Color.ORANGE, "max": 2.0},
		"Acetyl-CoA": {"value": acetyl_coa, "pos": Vector2(500, 100), "color": Color.RED, "max": 1.0},
		"Citrate": {"value": citrate, "pos": Vector2(100, 300), "color": Color.CYAN, "max": 1.0},
		"Isocitrate": {"value": isocitrate, "pos": Vector2(300, 300), "color": Color.LIGHT_BLUE, "max": 1.0},
		"α-KG": {"value": alpha_ketoglutarate, "pos": Vector2(500, 300), "color": Color.SKY_BLUE, "max": 1.0},
		"Succinate": {"value": succinate, "pos": Vector2(700, 300), "color": Color.MEDIUM_AQUAMARINE, "max": 1.0},
		"Malate": {"value": malate, "pos": Vector2(900, 300), "color": Color.TEAL, "max": 1.0},
		"OAA": {"value": oxaloacetate, "pos": Vector2(700, 100), "color": Color.MAGENTA, "max": 1.0},
		"NADH": {"value": nadh, "pos": Vector2(100, 500), "color": Color.GREEN, "max": 2.0},
		"NAD+": {"value": nad, "pos": Vector2(300, 500), "color": Color.DARK_GREEN, "max": 10.0},
		"ATP": {"value": atp, "pos": Vector2(500, 500), "color": Color.GOLD, "max": 5.0},
		"ADP": {"value": adp, "pos": Vector2(700, 500), "color": Color.DARK_GOLDENROD, "max": 10.0},
		"O2": {"value": oxygen, "pos": Vector2(900, 500), "color": Color.WHITE, "max": 2.0},
		"CO2": {"value": co2, "pos": Vector2(100, 700), "color": Color.GRAY, "max": 2.0},
	}

func _process(delta: float) -> void:
	if is_paused:
		return
	
	total_time += delta
	
	# Run simulation at fixed timestep
	if fmod(total_time, timestep) < delta:
		calculate_reaction_rates()
		simulate_step()
		update_concentrations()
	
	# Handle input
	handle_input()
	
	# Redraw
	queue_redraw()

func handle_input() -> void:
	"""Handle user input"""
	if Input.is_key_pressed(KEY_SPACE):
		add_glucose(5.0)
	
	if Input.is_key_pressed(KEY_ENTER):
		add_glucose(10.0)
	
	if Input.is_key_pressed(KEY_O):
		oxygen = 0.01
	
	if Input.is_key_pressed(KEY_R):
		reset_simulation()
	
	if Input.is_key_pressed(KEY_P):
		is_paused = !is_paused
		print("⏸️  Paused!" if is_paused else "▶️  Running!")
	
	if Input.is_key_pressed(KEY_PLUS) or Input.is_key_pressed(KEY_EQUAL):
		timestep = max(timestep - 0.001, 0.01)
	
	if Input.is_key_pressed(KEY_MINUS):
		timestep = min(timestep + 0.001, 0.5)

func calculate_reaction_rates() -> void:
	"""Calculate all reaction rates using Michaelis-Menten"""
	
	# Calculate inhibition factor from energy state
	var inhibition = calculate_inhibition()
	
	r_pfk = mm(vmax_pfk, km_pfk, glucose) * inhibition
	r_pdh = mm(vmax_pdh, km_pdh, pyruvate)
	r_cs = mm_2s(vmax_cs, km_cs_acetyl, acetyl_coa, km_cs_oaa, oxaloacetate)
	r_icdh = mm(vmax_icdh, km_icdh, isocitrate)
	r_akgdh = mm(vmax_akgdh, km_akgdh, alpha_ketoglutarate)
	r_sdh = mm(vmax_sdh, km_sdh, succinate)
	r_mdh = mm(vmax_mdh, km_mdh, malate)
	r_etc = calculate_etc_rate()

func calculate_inhibition() -> float:
	"""Calculate metabolic inhibition from energy state"""
	var atp_adp_ratio = atp / max(adp, 0.1)
	var nadh_nad_ratio = nadh / max(nad, 0.1)
	var inhibition = (1.0 - clamp(atp_adp_ratio * 0.2, 0.0, 0.7)) * (1.0 - clamp(nadh_nad_ratio * 0.3, 0.0, 0.5))
	return clamp(inhibition, 0.1, 1.0)

func calculate_etc_rate() -> float:
	"""ETC rate depends on NADH and O2"""
	var nadh_term = mm(1.0, km_nadh, nadh)
	var atp_adp_ratio = atp / max(adp, 0.1)
	var resp_control = 1.0 / (1.0 + atp_adp_ratio * 0.5)
	return vmax_etc * nadh_term * resp_control

func mm(vmax: float, km: float, s: float) -> float:
	"""Michaelis-Menten"""
	return (vmax * s) / (km + s)

func mm_2s(vmax: float, km1: float, s1: float, km2: float, s2: float) -> float:
	"""Two-substrate Michaelis-Menten"""
	return (vmax * s1 * s2) / ((km1 + s1) * (km2 + s2))

func simulate_step() -> void:
	"""Apply stoichiometric changes"""
	glucose -= r_pfk * timestep
	pyruvate += 2.0 * r_pfk * timestep - r_pdh * timestep
	
	acetyl_coa += r_pdh * timestep - r_cs * timestep
	co2 += r_pdh * timestep
	
	oxaloacetate -= r_cs * timestep
	citrate += r_cs * timestep - r_icdh * timestep
	
	isocitrate += r_icdh * timestep - r_akgdh * timestep
	nadh += r_icdh * timestep
	nad -= r_icdh * timestep
	co2 += r_icdh * timestep
	
	alpha_ketoglutarate += r_akgdh * timestep - r_sdh * timestep
	nadh += r_akgdh * timestep
	nad -= r_akgdh * timestep
	co2 += r_akgdh * timestep
	
	succinate += r_sdh * timestep - r_mdh * timestep
	
	malate += r_mdh * timestep - r_mdh * timestep
	
	oxaloacetate += r_mdh * timestep
	nadh += r_mdh * timestep
	nad -= r_mdh * timestep
	
	# Electron Transport Chain
	nadh -= r_etc * timestep
	nad += r_etc * timestep
	oxygen -= r_etc * 0.5 * timestep
	atp += r_etc * 2.5 * timestep
	adp -= r_etc * 2.5 * timestep
	
	clamp_concentrations()

func update_concentrations() -> void:
	"""Update molecule data with current values"""
	molecules_data["Glucose"]["value"] = glucose
	molecules_data["Pyruvate"]["value"] = pyruvate
	molecules_data["Acetyl-CoA"]["value"] = acetyl_coa
	molecules_data["Citrate"]["value"] = citrate
	molecules_data["Isocitrate"]["value"] = isocitrate
	molecules_data["α-KG"]["value"] = alpha_ketoglutarate
	molecules_data["Succinate"]["value"] = succinate
	molecules_data["Malate"]["value"] = malate
	molecules_data["OAA"]["value"] = oxaloacetate
	molecules_data["NADH"]["value"] = nadh
	molecules_data["NAD+"]["value"] = nad
	molecules_data["ATP"]["value"] = atp
	molecules_data["ADP"]["value"] = adp
	molecules_data["O2"]["value"] = oxygen
	molecules_data["CO2"]["value"] = co2

func clamp_concentrations() -> void:
	"""Prevent negative concentrations"""
	glucose = max(glucose, 0.0)
	pyruvate = max(pyruvate, 0.0)
	acetyl_coa = max(acetyl_coa, 0.0)
	citrate = max(citrate, 0.0)
	isocitrate = max(isocitrate, 0.0)
	alpha_ketoglutarate = max(alpha_ketoglutarate, 0.0)
	succinate = max(succinate, 0.0)
	malate = max(malate, 0.0)
	oxaloacetate = max(oxaloacetate, 0.0)
	nadh = max(nadh, 0.0)
	nad = max(nad, 0.0)
	atp = max(atp, 0.0)
	adp = max(adp, 0.0)
	oxygen = max(oxygen, 0.0)
	co2 = max(co2, 0.0)

func _draw() -> void:
	"""Render all visual elements"""
	# Draw title
	draw_string(ThemeDB.fallback_font, Vector2(get_rect().size.x / 2 - 200, 30), "🧬 AEROBIC RESPIRATION DYNAMICS", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	
	# Draw molecule boxes
	for mol_name in molecules_data:
		var data = molecules_data[mol_name]
		draw_molecule_box(data["pos"], mol_name, data["value"], data["max"], data["color"])
	
	# Draw reaction arrows with flux visualization
	draw_metabolic_arrows()

func draw_molecule_box(pos: Vector2, name: String, value: float, max_val: float, color: Color) -> void:
	"""Draw a molecule concentration box"""
	var size = Vector2(80, 80)
	var normalized = clamp(value / max_val, 0.0, 1.0)
	
	# Background
	draw_rect(Rect2(pos, size), Color.from_string("#1a1f3a", Color.BLACK), true)
	
	# Border
	draw_rect(Rect2(pos, size), color.lerp(Color.BLACK, 0.3), false, 2.0)
	
	# Fill indicator
	var fill_height = size.y * normalized
	var fill_rect = Rect2(pos + Vector2(0, size.y - fill_height), Vector2(size.x, fill_height))
	draw_rect(fill_rect, color.lerp(Color.WHITE, 0.3), true)
	
	# Text
	var font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(5, 20), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_string(font, pos + Vector2(5, 50), "%.3f" % value, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)

func draw_metabolic_arrows() -> void:
	"""Draw dynamic arrows representing metabolic flux"""
	var arrows = [
		{"from": "Glucose", "to": "Pyruvate", "rate": r_pfk, "label": "PFK"},
		{"from": "Pyruvate", "to": "Acetyl-CoA", "rate": r_pdh, "label": "PDH"},
		{"from": "Acetyl-CoA", "to": "Citrate", "rate": r_cs, "label": "CS"},
		{"from": "Citrate", "to": "Isocitrate", "rate": r_icdh, "label": "ICDH"},
		{"from": "Isocitrate", "to": "α-KG", "rate": r_akgdh, "label": "αKGDH"},
		{"from": "α-KG", "to": "Succinate", "rate": r_sdh, "label": "SDH"},
		{"from": "Succinate", "to": "Malate", "rate": r_sdh, "label": "SDH"},
		{"from": "Malate", "to": "OAA", "rate": r_mdh, "label": "MDH"},
		{"from": "NADH", "to": "ATP", "rate": r_etc, "label": "ETC"},
	]
	
	for arrow_data in arrows:
		draw_arrow(arrow_data["from"], arrow_data["to"], arrow_data["rate"], arrow_data["label"])

func draw_arrow(from_name: String, to_name: String, rate: float, label: String) -> void:
	"""Draw a single arrow with thickness and color based on flux"""
	if not molecules_data.has(from_name) or not molecules_data.has(to_name):
		return
	
	var from_pos = molecules_data[from_name]["pos"] + Vector2(40, 40)
	var to_pos = molecules_data[to_name]["pos"] + Vector2(40, 40)
	
	# Normalize rate to visual range (0-1)
	var max_rate = 25.0
	var normalized_rate = clamp(rate / max_rate, 0.0, 1.0)
	
	# Thickness based on rate
	var thickness = lerp(0.5, 4.0, normalized_rate)
	
	# Color based on rate intensity (blue -> yellow -> red)
	var arrow_color: Color
	if normalized_rate < 0.33:
		arrow_color = Color.BLUE.lerp(Color.YELLOW, normalized_rate * 3.0)
	else:
		arrow_color = Color.YELLOW.lerp(Color.RED, (normalized_rate - 0.33) * 1.5)
	
	# Add glow effect
	arrow_color = arrow_color.lerp(Color.WHITE, 0.3)
	
	# Draw arrow line
	draw_line(from_pos, to_pos, arrow_color, thickness)
	
	# Draw arrowhead
	var direction = (to_pos - from_pos).normalized()
	var perpendicular = Vector2(-direction.y, direction.x)
	var arrowhead_size = thickness * 3.0
	
	var tip = to_pos
	var base_left = to_pos - direction * arrowhead_size + perpendicular * arrowhead_size * 0.5
	var base_right = to_pos - direction * arrowhead_size - perpendicular * arrowhead_size * 0.5
	
	var points = PackedVector2Array([tip, base_left, base_right])
	draw_colored_polygon(points, arrow_color)
	
	# Draw enzyme label at midpoint
	var mid = (from_pos + to_pos) / 2.0
	draw_string(ThemeDB.fallback_font, mid, label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)
	
	# Draw rate text with color
	var rate_text = "%.2f" % rate
	draw_string(ThemeDB.fallback_font, mid + Vector2(0, 15), rate_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, arrow_color)

func add_glucose(amount: float) -> void:
	"""Add glucose to the system"""
	glucose += amount
	print("➕ Added %.2f mM glucose (total: %.2f mM)" % [amount, glucose])

func reset_simulation() -> void:
	"""Reset to initial state"""
	glucose = 5.0
	pyruvate = 0.1
	acetyl_coa = 0.05
	citrate = 0.1
	isocitrate = 0.05
	alpha_ketoglutarate = 0.08
	succinate = 0.1
	malate = 0.1
	oxaloacetate = 0.15
	nadh = 0.5
	nad = 5.0
	atp = 2.0
	adp = 3.0
	oxygen = 1.0
	co2 = 0.1
	total_time = 0.0
	print("🔄 Simulation reset!")
