## SimulationConfig - Resource storing all simulation generation parameters
## Saveable/loadable profiles for different simulation setups
class_name SimulationConfig
extends Resource

#region Profile Metadata

@export var profile_name: String = "Default"
@export_multiline var description: String = ""
@export var author: String = ""
@export var created_date: String = ""
@export var tags: Array[String] = []
@export var is_builtin: bool = false  ## Built-in profiles can't be deleted

#endregion

#region Generation Counts

@export_group("Generation Counts")
@export_range(2, 20) var molecule_count: int = 5
@export_range(1, 15) var enzyme_count: int = 4
@export_range(0, 10) var source_count: int = 1
@export_range(0, 10) var sink_count: int = 1

#endregion

#region Molecule Parameters

@export_group("Molecule Defaults")
@export_range(0.01, 100.0) var default_molecule_concentration: float = 5.0
@export_range(0.001, 50.0) var molecule_concentration_variance: float = 3.0
@export_range(-50.0, 50.0) var default_potential_energy: float = 0.0
@export_range(0.0, 30.0) var potential_energy_variance: float = 15.0
@export_range(1, 10) var structural_code_length: int = 4

#endregion

#region Enzyme Parameters

@export_group("Enzyme Defaults")
@export_range(0.0001, 1.0) var default_enzyme_concentration: float = 0.01
@export_range(0.0001, 0.5) var enzyme_concentration_variance: float = 0.005
@export_range(0.1, 100.0) var default_vmax: float = 10.0
@export_range(0.1, 50.0) var vmax_variance: float = 5.0
@export_range(0.01, 10.0) var default_km: float = 1.0
@export_range(0.01, 5.0) var km_variance: float = 0.5
@export_range(10.0, 600.0) var default_half_life: float = 120.0
@export_range(0.0, 1.0) var degradable_fraction: float = 0.7

#endregion

#region Reaction Parameters

@export_group("Reaction Defaults")
@export_range(-30.0, 0.0) var default_delta_g: float = -5.0
@export_range(0.0, 15.0) var delta_g_variance: float = 5.0
@export_range(0.1, 1.0) var default_efficiency: float = 0.7
@export_range(0.0, 0.3) var efficiency_variance: float = 0.2
@export_range(0.0, 1.0) var irreversible_fraction: float = 0.2

#endregion

#region Gene Expression Parameters

@export_group("Gene Expression")
@export var create_genes_for_enzymes: bool = true
@export_range(0.00001, 0.01) var default_basal_rate: float = 0.0001
@export_range(0.0, 0.005) var basal_rate_variance: float = 0.00005
@export_range(0.0, 1.0) var regulation_probability: float = 0.5
@export_range(0.0, 1.0) var activator_vs_repressor: float = 0.5

#endregion

#region Regulation Parameters

@export_group("Regulation Defaults")
@export_range(0.1, 20.0) var default_kd: float = 2.0
@export_range(0.1, 10.0) var kd_variance: float = 1.5
@export_range(1.0, 50.0) var default_max_fold: float = 10.0
@export_range(0.0, 20.0) var max_fold_variance: float = 5.0
@export_range(0.5, 4.0) var default_hill_coefficient: float = 1.5
@export_range(0.0, 1.5) var hill_variance: float = 0.5

#endregion

#region Pathway Type

@export_group("Pathway Structure")
@export_enum("Random", "Linear", "Branched", "Cyclic", "Feedback") var pathway_type: int = 0
@export_range(0.0, 1.0) var branching_probability: float = 0.3
@export var include_feedback_loops: bool = true
@export_range(0, 5) var feedback_loop_count: int = 1

#endregion

#region Mutation Settings

@export_group("Mutation System")
@export var enable_mutations: bool = false
@export_range(0.0, 0.1) var enzyme_mutation_rate: float = 0.01
@export_range(0.0, 0.05) var duplication_rate: float = 0.005
@export_range(0.0, 0.02) var novel_enzyme_rate: float = 0.002
@export_range(0.0, 0.05) var gene_mutation_rate: float = 0.008

#endregion

#region Evolution Settings

@export_group("Evolution System")
@export var enable_evolution: bool = false
@export_range(1.0, 60.0) var selection_interval: float = 10.0
@export_range(0.0, 0.5) var elimination_threshold: float = 0.1
@export_range(0.5, 2.0) var fitness_boost_factor: float = 1.2

#endregion

#region Simulation Settings

@export_group("Simulation")
@export_range(0.1, 10.0) var default_time_scale: float = 1.0
@export var start_paused: bool = true
@export_range(100, 2000) var history_length: int = 500

#endregion

#region Factory Methods

static func create_default() -> SimulationConfig:
	var config = SimulationConfig.new()
	config.profile_name = "Default"
	config.description = "Standard balanced simulation settings"
	config.is_builtin = true
	config.created_date = Time.get_datetime_string_from_system()
	return config

static func create_simple() -> SimulationConfig:
	var config = SimulationConfig.new()
	config.profile_name = "Simple"
	config.description = "Minimal setup for learning basics"
	config.is_builtin = true
	config.molecule_count = 3
	config.enzyme_count = 2
	config.source_count = 1
	config.sink_count = 1
	config.pathway_type = 1
	config.regulation_probability = 0.0
	config.enable_mutations = false
	config.enable_evolution = false
	config.tags = ["beginner", "educational"]
	config.created_date = Time.get_datetime_string_from_system()
	return config

static func create_complex() -> SimulationConfig:
	var config = SimulationConfig.new()
	config.profile_name = "Complex"
	config.description = "Rich system with many interactions"
	config.is_builtin = true
	config.molecule_count = 10
	config.enzyme_count = 8
	config.source_count = 2
	config.sink_count = 2
	config.pathway_type = 2
	config.branching_probability = 0.5
	config.include_feedback_loops = true
	config.feedback_loop_count = 3
	config.regulation_probability = 0.8
	config.enable_mutations = true
	config.enable_evolution = true
	config.tags = ["advanced", "dynamic"]
	config.created_date = Time.get_datetime_string_from_system()
	return config

static func create_oscillator_config() -> SimulationConfig:
	var config = SimulationConfig.new()
	config.profile_name = "Oscillator"
	config.description = "Settings tuned for oscillating behavior"
	config.is_builtin = true
	config.molecule_count = 4
	config.enzyme_count = 4
	config.source_count = 1
	config.sink_count = 1
	config.pathway_type = 3
	config.include_feedback_loops = true
	config.feedback_loop_count = 2
	config.regulation_probability = 1.0
	config.activator_vs_repressor = 0.3
	config.default_half_life = 60.0
	config.degradable_fraction = 1.0
	config.enable_mutations = false
	config.tags = ["oscillator", "dynamics"]
	config.created_date = Time.get_datetime_string_from_system()
	return config

static func create_evolution_sandbox() -> SimulationConfig:
	var config = SimulationConfig.new()
	config.profile_name = "Evolution Sandbox"
	config.description = "High mutation and selection pressure"
	config.is_builtin = true
	config.molecule_count = 6
	config.enzyme_count = 5
	config.pathway_type = 0
	config.enable_mutations = true
	config.enzyme_mutation_rate = 0.05
	config.duplication_rate = 0.02
	config.novel_enzyme_rate = 0.01
	config.enable_evolution = true
	config.selection_interval = 5.0
	config.elimination_threshold = 0.15
	config.tags = ["evolution", "mutation", "experimental"]
	config.created_date = Time.get_datetime_string_from_system()
	return config

#endregion

#region Save/Load

const PROFILES_DIR: String = "user://profiles/"

func save_to_file(path: String = "") -> Error:
	if path == "":
		path = PROFILES_DIR + profile_name.to_snake_case() + ".tres"
	
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("profiles"):
		dir.make_dir("profiles")
	
	created_date = Time.get_datetime_string_from_system()
	return ResourceSaver.save(self, path)

static func load_from_file(path: String) -> SimulationConfig:
	if not ResourceLoader.exists(path):
		push_error("Config file not found: %s" % path)
		return null
	
	var resource = ResourceLoader.load(path)
	if resource is SimulationConfig:
		return resource
	
	push_error("Invalid config file: %s" % path)
	return null

static func get_builtin_profiles() -> Array[SimulationConfig]:
	var profiles: Array[SimulationConfig] = []
	profiles.append(create_default())
	profiles.append(create_simple())
	profiles.append(create_complex())
	profiles.append(create_oscillator_config())
	profiles.append(create_evolution_sandbox())
	return profiles

static func get_user_profiles() -> Array[SimulationConfig]:
	var profiles: Array[SimulationConfig] = []
	
	var dir = DirAccess.open(PROFILES_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var config = load_from_file(PROFILES_DIR + file_name)
				if config:
					profiles.append(config)
			file_name = dir.get_next()
	
	return profiles

static func get_all_profiles() -> Array[SimulationConfig]:
	var all: Array[SimulationConfig] = []
	all.append_array(get_builtin_profiles())
	all.append_array(get_user_profiles())
	return all

static func delete_profile(path: String) -> Error:
	if not path.begins_with(PROFILES_DIR):
		return ERR_INVALID_PARAMETER
	
	var dir = DirAccess.open(PROFILES_DIR)
	if dir:
		return dir.remove(path.get_file())
	return ERR_FILE_NOT_FOUND

#endregion

#region Utility

func duplicate_config() -> SimulationConfig:
	var copy = duplicate(true) as SimulationConfig
	copy.profile_name = profile_name + " (Copy)"
	copy.is_builtin = false
	copy.created_date = Time.get_datetime_string_from_system()
	return copy

func get_summary() -> String:
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % profile_name)
	if description != "":
		lines.append(description)
	lines.append("")
	lines.append("Molecules: %d  |  Enzymes: %d" % [molecule_count, enzyme_count])
	lines.append("Pathway: %s" % ["Random", "Linear", "Branched", "Cyclic", "Feedback"][pathway_type])
	if enable_mutations:
		lines.append("Mutations: ON (rate %.1f%%)" % [enzyme_mutation_rate * 100])
	if enable_evolution:
		lines.append("Evolution: ON")
	if not tags.is_empty():
		lines.append("Tags: %s" % ", ".join(tags))
	return "\n".join(lines)

func _to_string() -> String:
	return "SimulationConfig(%s)" % profile_name

#endregion
