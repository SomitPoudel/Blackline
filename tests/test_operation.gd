extends SceneTree

var checks = 0
var failures = []


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _initialize() -> void:
	var missions = JSON.parse_string(FileAccess.get_file_as_string("res://data/missions.json"))
	var loadouts = []
	for i in range(4):
		loadouts.append({"weapon": "pistol", "gear": []})
	check(missions.size() == 50, "Exactly 50 missions")
	for m in missions:
		var sim = Operation.new()
		sim.new_mission(m, loadouts)
		check(
			sim.units.size() == 4 + int(m.enemies) + int(m.civilians),
			"Correct population %d" % m.id
		)
		for ev in sim.evidence:
			check(
				not sim.find_path(sim.units[0].pos, ev.pos).is_empty(),
				"Evidence reachable %d" % m.id
			)
		for u in sim.units:
			if u.team != "officer":
				check(
					not sim.find_path(sim.units[0].pos, u.pos).is_empty(),
					"Character reachable %d" % m.id
				)
	var sim = Operation.new()
	sim.new_mission(missions[9], loadouts)
	var a = sim.units[0]
	var b = sim.units[4]
	check(not sim.los(Vector2(4.5, 9.5), Vector2(4.5, 11.5)), "Wall blocks sight")
	var door_key = sim.doors.keys()[0]
	var door_index = int(door_key)
	var door = Vector2(door_index % Operation.W + 0.5, door_index / Operation.W + 0.5)
	check(not sim.los(door - Vector2(0, 1), door + Vector2(0, 1)), "Closed door blocks sight")
	sim.doors[door_key] = true
	check(sim.los(door - Vector2(0, 1), door + Vector2(0, 1)), "Open door passes sight")
	sim.alert_enemy(b, Vector2(5.5, 11.5), 3)
	b.seen_time = -100
	a.pos = Vector2(3.5, 11.5)
	b.pos = Vector2(25.5, 18.5)
	b.state = "searching"
	sim.paused = false
	for i in range(30):
		sim.step(0.05)
	check(b.alert >= 3, "Alert memory persists after losing contact")
	a.gear = ["jammer"]
	a.jammer = true
	check(sim.jammed(a.pos), "Jammer affects its source position")
	check(not sim.jammed(a.pos + Vector2(8, 0)), "Jammer has bounded range")
	a.jammer = false
	a.hp = 50
	a.gear = ["medkit"]
	a.med = 1
	sim.selected = 0
	sim.heal()
	check(a.hp == 85 and a.med == 0, "Treatment consumes one charge")
	var before = a.ammo
	sim.fire(a, a.pos + Vector2(0, 1))
	check(a.ammo == before - 1, "Firing consumes ammunition")
	var inventory = sim.units.size()
	sim.paused = true
	sim.interact(door)
	check(sim.pending_actions.size() == 1, "Paused commands queue")
	var encoded = sim.encode(sim.units)
	var decoded = sim.decode(JSON.parse_string(JSON.stringify(encoded)))
	check(decoded.size() == inventory, "Snapshot preserves all actors")
	check(decoded[0].pos is Vector2, "Snapshot restores vector positions")
	check(decoded[4].alert >= 3, "Snapshot preserves persistent alert")
	var old_broken = sim.lights[0].broken
	sim.lights[0].broken = true
	sim.lights[0].on = false
	check(sim.encode(sim.lights)[0].broken, "Broken fixtures survive serialisation")
	sim.lights[0].broken = old_broken
	check(not sim.extract(), "Cannot extract without objectives")
	sim.collected = int(sim.mission.evidence)
	sim.rescued = int(sim.mission.civilians)
	for i in range(4):
		sim.units[i].pos = Vector2(3.5 + i * .4, 11.5)
	check(sim.extract(), "Extraction succeeds with objectives and squad present")
	if failures.is_empty():
		print("PASS: %d engine checks" % checks)
		quit(0)
	else:
		print("FAIL: %d / %d" % [failures.size(), checks])
		quit(1)
