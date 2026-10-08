extends SceneTree


func _init() -> void:
	var seeds: Array[int] = [1, 7, 42, 99, 2026, 31337]
	var tunnels := 0
	var bridges := 0
	for s in seeds:
		var terrain := TerrainField.new()
		terrain.generate(s)
		var roads := RoadNetwork.new()
		roads.generate(terrain, s)
		tunnels += roads.tunnel_points
		bridges += roads.bridge_points
		print("SEED %d height %.1f..%.1f edges %d shortcuts %d tunnel_pts %d bridge_pts %d races %d" % [
			s, terrain.min_h, terrain.max_h, roads.edges.size(), roads.shortcut_edges,
			roads.tunnel_points, roads.bridge_points, roads.races.size(),
		])
		if roads.races.size() != 8:
			push_error("Expected 8 races")
			quit(1)
			return
		if roads.edges.size() < 12:
			push_error("Road network too small")
			quit(1)
			return
		var names := {}
		var circuits := 0
		for race in roads.races:
			print("  ", race.name, " ", race.type, " %.0fm cps %d laps %d" % [race.length, race.checkpoints.size(), race.laps])
			if float(race.length) < 300.0 or race.checkpoints.size() < 4:
				push_error("Race too short: " + str(race.name))
				quit(1)
				return
			names[str(race.name)] = true
			if str(race.type) == "circuit":
				circuits += 1
		if names.size() != 8 or circuits != 8:
			push_error("Race mix invalid")
			quit(1)
			return
		var edge: Dictionary = roads.edges[0]
		var pts: PackedVector3Array = edge.points
		var mid: Vector3 = pts[pts.size() / 2]
		var sample: Dictionary = roads.sample(mid.x, mid.z)
		if absf(float(sample.height) - mid.y) > 4.0:
			push_error("Road sample mismatch %.2f vs %.2f" % [sample.height, mid.y])
			quit(1)
			return
		if roads.tunnel_points < 1 or roads.bridge_points < 1:
			push_error("Seed %d missing tunnels or bridges" % s)
			quit(1)
			return
	print("ALL GOOD tunnels=%d bridges=%d" % [tunnels, bridges])
	quit()
