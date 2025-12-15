## Update this method in simulator.gd to support the new pathway names

func load_builtin_pathway(pathway_name: String) -> void:
	var preset: PathwayPreset
	
	match pathway_name.to_lower():
		"default", "linear", "linear_pathway":
			preset = PathwayPreset.create_default()
		"glycolysis":
			preset = PathwayPreset.create_glycolysis()
		"krebs", "krebs_cycle", "tca", "citric_acid":
			preset = PathwayPreset.create_krebs_cycle()
		"ppp", "pentose_phosphate", "pentose":
			preset = PathwayPreset.create_pentose_phosphate()
		"beta_oxidation", "fatty_acid":
			preset = PathwayPreset.create_beta_oxidation()
		"urea", "urea_cycle":
			preset = PathwayPreset.create_urea_cycle()
		_:
			push_error("Unknown builtin pathway: %s" % pathway_name)
			return
	
	load_pathway(preset)
