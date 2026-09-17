class_name Operation
extends RefCounted

const W = 32
const H = 24
const SAVE = "user://operation.json"
var mission = {}
var grid = []
var units = []
var lights = []
var props = []
var evidence = []
var doors = {}
var explored = []
var visible = []
var effects = []
var sounds = []
var messages = []
var logs = []
var last_known = {}
var rng = RandomNumberGenerator.new()
var time = 0.0
var paused = true
var finished = false
var victory = false
var selected = 0
var group = false
var casualties = 0
var rescued = 0
var collected = 0
var arrests = 0
var perception_clock = 0.0
var tick_id = 0
var last_alert = "NO CONFIRMED CONTACT"
var rooms = []
var nav_cache = {}
var pending_actions = []


func idx(p: Vector2i) -> int:
	return p.y * W + p.x


func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < W and p.y < H


func cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.y))


func center(p: Vector2i) -> Vector2:
	return Vector2(p) + Vector2(0.5, 0.5)


func tile(p: Vector2i) -> int:
	if not inside(p):
		return 1
	return grid[idx(p)]


func blocked(p: Vector2i, vision: bool = false) -> bool:
	var t = tile(p)
	if t == 1:
		return true
	if t == 2:
		if not vision:
			return true
		for prop in props:
			if cell(prop.pos) == p and int(prop.kind) == 2:
				return true
		return false
	if t == 3:
		return not doors.get(str(idx(p)), false)
	return false


func new_mission(data: Dictionary, loadouts: Array) -> void:
	mission = data.duplicate(true)
	rng.seed = int(data.seed)
	grid.resize(W * H)
	grid.fill(0)
	visible.resize(W * H)
	visible.fill(false)
	explored.resize(W * H)
	explored.fill(false)
	for y in range(H):
		for x in range(W):
			if x < 2 or x > 29 or y < 2 or y > 21:
				grid[y * W + x] = 1
	for x in range(2, 30):
		grid[2 * W + x] = 1
		grid[21 * W + x] = 1
		grid[10 * W + x] = 1
		grid[13 * W + x] = 1
	for y in range(2, 22):
		grid[y * W + 2] = 1
		grid[y * W + 29] = 1
		if y < 10 or y > 13:
			grid[y * W + 11] = 1
			grid[y * W + 21] = 1
	for row in range(2):
		for col in range(3):
			var left = [3, 12, 22][col]
			var right = [10, 20, 28][col]
			var top = 3 if row == 0 else 14
			var bottom = 9 if row == 0 else 20
			rooms.append(Rect2i(left, top, right - left + 1, bottom - top + 1))
			var dx = left + 2 + int(data.layout) % 3
			var door_y = 10 if row == 0 else 13
			grid[door_y * W + dx] = 3
			doors[str(door_y * W + dx)] = false
			var light_pos = Vector2((left + right) / 2.0 + 0.5, (top + bottom) / 2.0 + 0.5)
			lights.append(
				{
					"pos": light_pos,
					"on": rng.randf() > float(data.darkness),
					"broken": false,
					"noticed": []
				}
			)
			for j in range(3):
				var p = Vector2i(left + 1 + j * 2, top + 1 + ((int(data.layout) + j + row) % 4))
				if p.x < right and tile(p) == 0:
					grid[idx(p)] = 2
					props.append({"pos": center(p), "kind": (col + row + j + int(data.layout)) % 4})
	# Cross-room connections vary across ten layouts; main corridor always connects all rooms.
	for x in [11, 21]:
		for row in [0, 1]:
			var y = (5 + int(data.layout) % 3) if row == 0 else (16 + int(data.layout) % 3)
			grid[y * W + x] = 3
			doors[str(y * W + x)] = false
	for i in range(4):
		var u = make_unit(i, "officer", Vector2(3.5 + i * 0.75, 11.5 + (i % 2) * 0.6))
		u.weapon = loadouts[i].weapon
		u.gear = loadouts[i].gear.duplicate()
		u.experience=int(loadouts[i].get("experience",0))
		u.armour = 40.0 if "armour" in u.gear else 0.0
		u.ammo = Arsenal.WEAPONS[u.weapon].capacity
		units.append(u)
	var occupied = {}
	for i in range(int(data.enemies)):
		var p = random_room_point(i % 6, occupied)
		var u = make_unit(units.size(), "suspect", p)
		u.weapon = "pistol" if i % 3 else "smg"
		u.ammo = Arsenal.WEAPONS[u.weapon].capacity
		u.angle = rng.randf_range(-PI, PI)
		u.personality = rng.randf()
		u.home = p
		units.append(u)
	for i in range(int(data.civilians)):
		var u = make_unit(units.size(), "civilian", random_room_point((i + 2) % 6, occupied))
		units.append(u)
	for i in range(int(data.evidence)):
		evidence.append(
			{"pos": random_room_point((i + 4) % 6, occupied), "taken": false, "progress": 0.0}
		)
	log_event("Operation %02d • %s" % [data.id, data.name])
	log_event("Paused. Select officer → tap floor for route → GO.")
	update_visibility()


func make_unit(id: int, team: String, pos: Vector2) -> Dictionary:
	return {
		"id": id,
		"team": team,
		"pos": pos,
		"angle": 0.0,
		"hp": 100.0,
		"armour": 0.0,
		"weapon": "pistol",
		"gear": [],
		"ammo": 15,
		"reserve": 150,
		"reload": 0.0,
		"cooldown": 0.0,
		"path": [],
		"state": "routine",
		"alert": 0,
		"last": pos,
		"seen_time": -100.0,
		"search": 0.0,
		"suspicion": 0.0,
		"radio": 0.0,
		"reported": -100.0,
		"aim": 0.0,
		"moving": false,
		"hold": false,
		"jammer": false,
		"battery": 90.0,
		"med": 1,
		"escort": -1,
		"home": pos,
		"personality": 0.5,
		"contact": -1,
		"surrender": false,
		"noise_clock": 0.0,
		"searches": 0,
		"investigated": [],
		"door_timer": 0.0
	}


func random_room_point(room_id: int, occupied: Dictionary) -> Vector2:
	var r = rooms[room_id]
	for attempt in range(100):
		var p = Vector2i(
			rng.randi_range(r.position.x, r.end.x - 1), rng.randi_range(r.position.y, r.end.y - 1)
		)
		if tile(p) == 0 and not occupied.has(idx(p)):
			occupied[idx(p)] = true
			return center(p)
	return center(r.position)


func los(a: Vector2, b: Vector2) -> bool:
	var steps = maxi(1, ceili(a.distance_to(b) * 5))
	for i in range(1, steps):
		if blocked(cell(a.lerp(b, float(i) / steps)), true):
			return false
	return true


func light_level(pos: Vector2) -> float:
	var amount = 0.10
	# The corridor's emergency fixtures never go fully dark.
	if pos.y > 10 and pos.y < 14:
		amount = 0.32
	for l in lights:
		if l.on and not l.broken and pos.distance_to(l.pos) < 7 and los(pos, l.pos):
			amount = maxf(amount, 1.0 - pos.distance_to(l.pos) / 8.0)
	return amount


func sees(u: Dictionary, p: Vector2) -> bool:
	var distance = u.pos.distance_to(p)
	if distance < 0.8:
		return los(u.pos, p)
	var direction = Vector2(sin(u.angle), cos(u.angle))
	if direction.dot((p - u.pos).normalized()) < cos(deg_to_rad(65)):
		return false
	var reach = 10.0
	var light = light_level(p)
	if "nvg" in u.gear or "thermal" in u.gear:
		light = maxf(light, 0.8)
	if u.alert >= 2:
		reach += 2
	return distance < reach * (0.35 + light * 0.65) and los(u.pos, p)


func jammed(p: Vector2) -> bool:
	for u in units:
		if (
			u.team == "officer"
			and u.hp > 0
			and u.jammer
			and u.battery > 0
			and u.pos.distance_to(p) < 6
		):
			return true
	return false


func linked(u: Dictionary) -> bool:
	return u.id == selected or (not jammed(u.pos) and not jammed(units[selected].pos))


func update_visibility() -> void:
	visible.fill(false)
	for u in units:
		if u.team != "officer" or u.hp <= 0 or not linked(u):
			continue
		var cp = cell(u.pos)
		for y in range(maxi(0, cp.y - 13), mini(H, cp.y + 14)):
			for x in range(maxi(0, cp.x - 13), mini(W, cp.x + 14)):
				var p = Vector2i(x, y)
				if sees(u, center(p)):
					visible[idx(p)] = true
					explored[idx(p)] = true
	for e in units:
		if e.team == "suspect" and e.hp > 0 and is_visible(e.pos):
			last_known[str(e.id)] = {"pos": e.pos, "time": time}


func is_visible(p: Vector2) -> bool:
	var c = cell(p)
	return inside(c) and visible[idx(c)]


func find_path(a: Vector2, b: Vector2) -> Array:
	var start = cell(a)
	var goal = cell(b)
	if not inside(goal) or tile(goal) in [1, 2]:
		return []
	var key = str(idx(start)) + ":" + str(idx(goal))
	if nav_cache.has(key):
		return nav_cache[key].duplicate()
	var queue = [start]
	var from = {idx(start): -1}
	var cursor = 0
	while cursor < queue.size():
		var p = queue[cursor]
		cursor += 1
		if p == goal:
			break
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next = p + step
			if inside(next) and tile(next) not in [1, 2] and not from.has(idx(next)):
				from[idx(next)] = idx(p)
				queue.append(next)
	if not from.has(idx(goal)):
		return []
	var result = []
	var cur = idx(goal)
	while cur != idx(start):
		result.push_front(center(Vector2i(cur % W, cur / W)))
		cur = from[cur]
	if nav_cache.size() > 400:
		nav_cache.clear()
	nav_cache[key] = result.duplicate()
	return result


func order_move(pos: Vector2, append: bool = false) -> void:
	for u in units:
		if u.team != "officer" or u.hp <= 0 or (not group and u.id != selected):
			continue
		var dest = pos
		if group:
			var offset = Vector2((u.id % 2) * 0.65, floori(u.id / 2.0) * 0.65)
			if tile(cell(pos + offset)) == 0:
				dest += offset
		var origin = u.path.back() if append and not u.path.is_empty() else u.pos
		var route = find_path(origin, dest)
		if not route.is_empty() or cell(origin)==cell(dest):
			route.append(dest)
		if append:
			u.path.append_array(route)
		else:
			u.path = route
		u.state = "moving"
		if route.is_empty():
			log_event("Destination blocked or already reached.")


func face_selected(pos: Vector2) -> void:
	var u = units[selected]
	u.angle = atan2(pos.x - u.pos.x, pos.y - u.pos.y)
	u.path.clear()


func selected_gear(id: String) -> bool:
	return id in units[selected].gear


func toggle_jammer() -> void:
	var u = units[selected]
	if "jammer" not in u.gear:
		log_event("Equip a jammer in the armoury first.")
		return
	u.jammer = not u.jammer and u.battery > 0
	log_event("Jammer %s. Squad radio is also affected." % ("active" if u.jammer else "off"))


func heal() -> void:
	if paused:
		pending_actions.append({"kind": "heal", "officer": selected, "pos": Vector2.ZERO})
		log_event("Treatment queued. Press GO.")
		return
	var u = units[selected]
	if "medkit" in u.gear and u.med > 0 and u.hp > 0 and u.hp < 100:
		u.med -= 1
		u.hp = minf(100, u.hp + 35)
		log_event("Field treatment applied.")
	else:
		log_event("No treatment available or officer uninjured.")


func interact(p: Vector2) -> void:
	if paused:
		pending_actions.append({"kind": "interact", "officer": selected, "pos": p})
		log_event("Interaction queued. Press GO.")
		return
	var u = units[selected]
	if u.hp <= 0:
		return
	for l in lights:
		if l.pos.distance_to(p) < 1.1 and u.pos.distance_to(l.pos) < 2.8 and los(u.pos, l.pos):
			if l.broken:
				log_event("Fixture destroyed; switching cannot repair it.")
			else:
				l.on = not l.on
				emit_noise(l.pos, 3, "switch", u.id)
			return
	var cp = cell(p)
	if tile(cp) == 3 and u.pos.distance_to(center(cp)) < 2.6:
		doors[str(idx(cp))] = not doors[str(idx(cp))]
		emit_noise(center(cp), 4, "door", u.id)
		return
	for e in units:
		if e.team != "suspect" or e.hp <= 0 or e.state == "secured":
			continue
		if e.pos.distance_to(p) < 1.0 and u.pos.distance_to(e.pos) < 3 and sees(u, e.pos):
			emit_noise(u.pos, 9, "command", u.id)
			if e.surrender:
				if u.pos.distance_to(e.pos) < 1.7:
					e.state = "secured"
					arrests += 1
					log_event("Suspect secured.")
				else:
					log_event("Move closer to secure the surrendered suspect.")
			elif rng.randf() < 0.32 + e.personality * 0.25 + (1.0 - e.hp / 100) * 0.4:
				e.surrender = true
				e.state = "surrender"
				e.path.clear()
				log_event("Suspect surrendered. Move close and INTERACT to secure.")
			else:
				alert_enemy(e, u.pos, 3)
				log_event("Suspect refuses command.")
			return
	log_event("INTERACT near a door, fixture or visible suspect.")


func shoot_light(p: Vector2) -> void:
	var u = units[selected]
	if paused:
		pending_actions.append({"kind": "light", "officer": selected, "pos": p})
		log_event("Fixture shot queued. Press GO.")
		return
	for l in lights:
		if l.pos.distance_to(p) < 1.25 and not l.broken and sees(u, l.pos):
			if fire(u, l.pos, -1, true):
				l.on = false
				l.broken = true
				effects.append({"a": l.pos, "b": l.pos, "type": "sparks", "life": 0.6})
				emit_noise(l.pos, 8, "glass", u.id)
				sounds.append({"pos": l.pos, "kind": "glass"})
			return
	log_event("No intact fixture in this officer's sight.")


func reload_unit(u: Dictionary) -> void:
	var w = Arsenal.WEAPONS[u.weapon]
	if u.reload <= 0 and u.ammo < w.capacity and u.reserve > 0:
		u.reload = w.reload
		sounds.append({"pos": u.pos, "kind": "reload"})


func step(dt: float) -> void:
	if paused or finished:
		return
	var current = selected
	while not pending_actions.is_empty():
		var action = pending_actions.pop_front()
		selected = int(action.officer)
		if units[selected].hp > 0:
			if action.kind == "interact":
				interact(action.pos)
			elif action.kind == "light":
				shoot_light(action.pos)
			elif action.kind == "heal":
				heal()
	selected = current
	time += dt
	tick_id += 1
	for i in range(effects.size() - 1, -1, -1):
		effects[i].life -= dt
		if effects[i].life <= 0:
			effects.remove_at(i)
	for u in units:
		if u.hp <= 0 or u.state in ["secured", "evacuated"]:
			continue
		u.cooldown = maxf(0, u.cooldown - dt)
		if u.reload > 0:
			u.reload -= dt
			if u.reload <= 0:
				var w = Arsenal.WEAPONS[u.weapon]
				var amount = mini(
					1 if u.weapon == "shotgun" else int(w.capacity) - int(u.ammo), int(u.reserve)
				)
				u.ammo += amount
				u.reserve -= amount
				if u.weapon == "shotgun" and u.ammo < w.capacity and u.reserve > 0:
					u.reload = w.reload
		if u.jammer:
			u.battery = maxf(0, u.battery - dt)
			if u.battery <= 0:
				u.jammer = false
		if u.team == "officer":
			update_officer(u, dt)
		elif u.team == "suspect":
			update_enemy(u, dt)
		else:
			update_civilian(u, dt)
		move_unit(u, dt)
	for i in range(messages.size() - 1, -1, -1):
		var m = messages[i]
		if time >= m.deliver:
			var sender = units[m.sender]
			if sender.hp > 0 and not sender.surrender and sender.state != "secured":
				if not jammed(sender.pos):
					for e in units:
						if (
							e.team == "suspect"
							and e.hp > 0
							and not jammed(e.pos)
							and e.id != sender.id
						):
							alert_enemy(e, m.pos, 2)
					if is_visible(sender.pos):
						log_event("Enemy radio report transmitted.")
				else:
					if is_visible(sender.pos):
						log_event("Enemy radio blocked.")
					for e in units:
						if (
							e.team == "suspect"
							and e.id != sender.id
							and e.pos.distance_to(sender.pos) < 3
							and los(e.pos, sender.pos)
						):
							alert_enemy(e, m.pos, 2)
			messages.remove_at(i)
	for ev in evidence:
		if ev.taken:
			continue
		for u in units:
			if (
				u.team == "officer"
				and u.hp > 0
				and u.pos.distance_to(ev.pos) < 1.4
				and los(u.pos, ev.pos)
			):
				ev.progress += dt * (2 if "knife" in u.gear else 1)
				if ev.progress >= 2:
					ev.taken = true
					collected += 1
					log_event("Evidence secured.")
				break
	perception_clock -= dt
	if perception_clock <= 0:
		perception_clock = 0.15
		update_visibility()
	var alive = 0
	for u in units:
		if u.team == "officer" and u.hp > 0:
			alive += 1
	if alive == 0:
		finished = true
		victory = false
		paused = true


func update_officer(u: Dictionary, dt: float) -> void:
	if u.reload > 0 or u.hold:
		return
	var target = {}
	var distance = 1000.0
	for e in units:
		if (
			e.team == "suspect"
			and e.hp > 0
			and not e.surrender
			and e.state != "secured"
			and sees(u, e.pos)
		):
			if u.pos.distance_to(e.pos) < distance:
				distance = u.pos.distance_to(e.pos)
				target = e
	if not target.is_empty():
		u.aim += dt
		u.angle = atan2(target.pos.x - u.pos.x, target.pos.y - u.pos.y)
		if u.aim > maxf(0.20,0.35-float(u.get("experience",0))*0.0001):
			if not friendly_in_line(u, target.pos):
				fire(u, target.pos, target.id)
	else:
		u.aim = 0.0


func friendly_in_line(u: Dictionary, target: Vector2) -> bool:
	for other in units:
		if other.id == u.id or other.hp <= 0 or other.team == "suspect":
			continue
		var closest = Geometry2D.get_closest_point_to_segment(other.pos, u.pos, target)
		if other.pos.distance_to(closest) < 0.38 and other.pos.distance_to(u.pos) > 0.25:
			return true
	return false


func update_enemy(u: Dictionary, dt: float) -> void:
	if u.surrender:
		return
	var spotted = {}
	for o in units:
		if o.team == "officer" and o.hp > 0 and sees(u, o.pos):
			spotted = o
			break
	if not spotted.is_empty():
		u.suspicion += dt * (1.2 + light_level(spotted.pos))
		if u.suspicion > 0.3:
			alert_enemy(u, spotted.pos, 3)
			u.seen_time = time
			u.contact = spotted.id
			u.angle = atan2(spotted.pos.x - u.pos.x, spotted.pos.y - u.pos.y)
			u.path.clear()
			u.aim += dt
			if u.aim > maxf(0.4, 0.95 - float(mission.discipline) * 0.5):
				fire(u, spotted.pos, spotted.id)
			if time - u.reported > 12 and mission.radio:
				u.reported = time
				messages.append({"sender": u.id, "pos": spotted.pos, "deliver": time + 0.8})
			return
	u.suspicion = maxf(0, u.suspicion - dt * .4)
	u.aim = 0.0
	if u.state == "combat":
		u.state = "searching"
		u.path = find_path(u.pos, u.last)
		u.search = 3.0
	if tick_id % 12 == u.id % 12:
		for body in units:
			if body.team == "suspect" and body.hp <= 0 and sees(u, body.pos) and u.alert < 2:
				alert_enemy(u, body.pos, 2)
				if mission.radio:
					messages.append({"sender": u.id, "pos": body.pos, "deliver": time + 0.8})
				break
		for l in lights:
			if l.broken and u.id not in l.noticed and sees(u, l.pos):
				l.noticed.append(u.id)
				alert_enemy(u, l.pos, 2)
	if not u.path.is_empty():
		return
	u.search -= dt
	if u.search > 0:
		u.angle += dt * 0.7
		return
	if u.alert > 0:
		u.state = "searching" if u.alert >= 2 else "investigating"
		var base = cell(u.last)
		var candidate = base + Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
		if inside(candidate) and tile(candidate) == 0 and idx(candidate) not in u.investigated:
			u.path = find_path(u.pos, center(candidate))
			u.investigated.append(idx(candidate))
		u.search = rng.randf_range(2.0, 4.0)
	# Evidence memory stays; search movement stops instead of magically resetting patrol.
	elif mission.patrol:
		var candidate = cell(u.home) + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
		if tile(candidate) == 0:
			u.path = find_path(u.pos, center(candidate))
		u.search = rng.randf_range(3.0, 7.0)


func update_civilian(u: Dictionary, dt: float) -> void:
	if u.escort < 0:
		for o in units:
			if (
				o.team == "officer"
				and o.hp > 0
				and o.pos.distance_to(u.pos) < 2
				and los(o.pos, u.pos)
			):
				u.escort = o.id
				u.state = "following"
				log_event("Civilian following. Return to the green deployment zone.")
				break
	else:
		var o = units[u.escort]
		if o.hp <= 0:
			u.escort = -1
			return
		if cell(u.pos).x < 7 and u.pos.y > 10 and u.pos.y < 14:
			u.state = "evacuated"
			rescued += 1
			log_event("Civilian evacuated.")
			return
		if u.pos.distance_to(o.pos) > 1.4 and (u.path.is_empty() or tick_id % 30 == 0):
			u.path = find_path(u.pos, o.pos)
	u.search = maxf(0, u.search - dt)


func move_unit(u: Dictionary, dt: float) -> void:
	u.moving = false
	if u.path.is_empty() or u.surrender:
		return
	var next = u.path[0]
	var c = cell(next)
	if tile(c) == 3 and not doors.get(str(idx(c)), false):
		if u.pos.distance_to(next) < 1.3:
			u.door_timer += dt
			if u.door_timer > 0.7:
				doors[str(idx(c))] = true
				u.door_timer = 0.0
				emit_noise(next, 4, "door", u.id)
		else:
			advance_unit(u, next, dt)
		return
	advance_unit(u, next, dt)


func advance_unit(u: Dictionary, next: Vector2, dt: float) -> void:
	var speed = 1.8 if u.team == "officer" else 1.25
	if u.hp < 40:
		speed *= 0.7
	if "armour" in u.gear:
		speed *= 0.9
	if u.team == "officer":
		speed /= 1 + float(Arsenal.WEAPONS[u.weapon].weight) * 0.035
	var delta = next - u.pos
	if delta.length() < 0.08:
		u.path.pop_front()
		return
	u.angle = atan2(delta.x, delta.y)
	var p = u.pos.move_toward(next, speed * dt)
	if not blocked(cell(p)):
		u.pos = p
		u.moving = true
		u.noise_clock += dt
		if u.noise_clock > 0.8:
			u.noise_clock = 0.0
			if u.team == "officer":
				emit_noise(u.pos, 2.8, "steps", u.id)
	else:
		u.path.clear()


func alert_enemy(u: Dictionary, pos: Vector2, level: int) -> void:
	if u.hp <= 0 or u.surrender or u.state == "secured":
		return
	u.alert = maxi(int(u.alert), level)
	u.last = pos
	if level == 3:
		u.state = "combat"
	else:
		if time - u.seen_time < 3:
			return
		u.state = "investigating" if level == 1 else "searching"
		if u.path.is_empty():
			u.path = find_path(u.pos, pos)
		u.search = 3.0
	if is_visible(u.pos):
		last_alert = "CONTACT / HIGH ALERT" if u.alert >= 2 else "SUSPICIOUS ACTIVITY"


func emit_noise(pos: Vector2, power: float, kind: String, source: int) -> void:
	# Weighted flood: open routes carry sound, closed doors and walls attenuate it.
	var start = cell(pos)
	var costs = {idx(start): 0.0}
	var queue = [start]
	var at = 0
	while at < queue.size():
		var p = queue[at]
		at += 1
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n = p + direction
			if not inside(n):
				continue
			var attenuation = 1.0
			if tile(n) == 1:
				attenuation = 7.0
			elif tile(n) == 3 and blocked(n):
				attenuation = 3.0
			var cost = costs[idx(p)] + attenuation
			if cost < power and cost < float(costs.get(idx(n), 10000.0)):
				costs[idx(n)] = cost
				queue.append(n)
	for e in units:
		if e.id == source or e.hp <= 0:
			continue
		if costs.has(idx(cell(e.pos))):
			if e.team == "suspect":
				var area = pos + Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.7, 0.7))
				if blocked(cell(area)):
					area = pos
				var strong = kind in ["gunshot", "glass", "command"]
				alert_enemy(e, area, 2 if strong else 1)
				if strong and mission.radio and time-e.reported>12:
					e.reported=time
					messages.append({"sender":e.id,"pos":area,"deliver":time+0.8})
			elif e.team == "civilian" and e.escort < 0:
				e.state = "frightened"
				e.search = 5.0
	effects.append({"a": pos, "b": pos, "type": "noise", "life": 0.8})


func fire(u: Dictionary, target: Vector2, target_id: int = -1, fixture: bool = false) -> bool:
	var w = Arsenal.WEAPONS[u.weapon]
	if u.hp <= 0 or u.cooldown > 0 or u.reload > 0 or u.hold:
		return false
	if u.ammo <= 0:
		reload_unit(u)
		return false
	if u.pos.distance_to(target) > float(w.reach):
		return false
	u.ammo -= 1
	u.cooldown = w.interval
	var origin = u.pos
	u.angle = atan2(target.x - origin.x, target.y - origin.y)
	sounds.append({"pos": origin, "kind": "suppressed" if w.suppressed else u.weapon})
	emit_noise(origin, w.noise, "gunshot", u.id)
	var fixture_reached = false
	for pellet in range(int(w.pellets)):
		var spread = float(w.spread) * (2.0 if u.moving else 1.0) * (1.5 if u.hp < 40 else 1.0)
		var angle = u.angle + rng.randf_range(-spread, spread)
		var direction = Vector2(sin(angle), cos(angle))
		var end = origin + direction * float(w.reach)
		var fixture_distance = origin.distance_to(target) if fixture else 1000.0
		for s in range(1, ceili(float(w.reach) / 0.15)):
			var point = origin + direction * s * 0.15
			if blocked(cell(point), true):
				end = point
				break
			var hit = false
			for other in units:
				if (
					other.id != u.id
					and other.hp > 0
					and other.state != "evacuated"
					and other.pos.distance_to(point) < 0.25
				):
					damage(other, w.damage)
					end = point
					hit = true
					break
			if hit:
				end = point
				break
			if fixture and origin.distance_to(point) >= fixture_distance:
				fixture_reached = point.distance_to(target) < 0.35
				end = point
				break
		effects.append({"a": origin, "b": end, "type": "shot", "life": 0.09})
	return fixture_reached if fixture else true


func damage(u: Dictionary, amount: float) -> void:
	var absorbed = minf(u.armour, amount * 0.65)
	u.armour -= absorbed
	u.hp = maxf(0, u.hp - amount + absorbed)
	if u.hp <= 0:
		u.path.clear()
		u.state = "down"
		u.jammer = false
		if u.team == "civilian":
			casualties += 1
			log_event("Civilian casualty. Mission failed.")
			finished = true
			victory = false
			paused = true
		elif u.team == "officer":
			log_event("Officer down.")


func extract() -> bool:
	if collected < int(mission.evidence) or rescued < int(mission.civilians):
		log_event("Rescue all civilians and collect evidence before extraction.")
		return false
	for u in units:
		if u.team == "officer" and u.hp > 0 and (u.pos.x >= 7 or u.pos.y <= 10 or u.pos.y >= 14):
			log_event("All surviving officers must return to the green zone.")
			return false
	finished = true
	victory = true
	paused = true
	return true


func log_event(message: String) -> void:
	logs.push_front(message)
	if logs.size() > 20:
		logs.resize(20)


func encode(value):
	if value is int:
		return {"__integer":str(value)}
	if value is Vector2:
		return {"__v2": [value.x, value.y]}
	if value is Vector2i:
		return {"__v2i": [value.x, value.y]}
	if value is Rect2i:
		return {"__rect": [value.position.x, value.position.y, value.size.x, value.size.y]}
	if value is Array:
		var result = []
		for v in value:
			result.append(encode(v))
		return result
	if value is Dictionary:
		var result = {}
		for k in value:
			result[str(k)] = encode(value[k])
		return result
	return value


func decode(value):
	if value is Dictionary:
		if value.has("__integer"):
			return int(value.__integer)
		if value.has("__v2"):
			return Vector2(value.__v2[0], value.__v2[1])
		if value.has("__v2i"):
			return Vector2i(value.__v2i[0], value.__v2i[1])
		if value.has("__rect"):
			return Rect2i(value.__rect[0], value.__rect[1], value.__rect[2], value.__rect[3])
		var result = {}
		for k in value:
			result[k] = decode(value[k])
		return result
	if value is Array:
		var result = []
		for v in value:
			result.append(decode(v))
		return result
	return value


func save_run() -> void:
	if finished:
		if FileAccess.file_exists(SAVE):
			DirAccess.remove_absolute(SAVE)
		return
	var d = {}
	for key in [
		"mission",
		"grid",
		"units",
		"lights",
		"props",
		"evidence",
		"doors",
		"explored",
		"last_known",
		"messages",
		"logs",
		"time",
		"selected",
		"casualties",
		"rescued",
		"collected",
		"arrests",
		"rooms",
		"last_alert",
		"pending_actions"
	]:
		d[key] = encode(get(key))
	d["rng_state"] = str(rng.state)
	var f = FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func load_run() -> bool:
	if not FileAccess.file_exists(SAVE):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if not d is Dictionary or not d.has("mission"):
		return false
	for key in d:
		if key != "rng_state":
			set(key, decode(d[key]))
	rng.state = int(d.get("rng_state", "0"))
	visible.resize(W * H)
	visible.fill(false)
	paused = true
	update_visibility()
	return true
