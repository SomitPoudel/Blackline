extends Node3D

var career: Career
var missions = []
var op: Operation
var world: TacticalWorld
var ui: CanvasLayer
var root: Control
var mode = "home"
var command = "MOVE"
var selected_mission = 1
var chapter = 0
var armoury_officer = 0
var hud_labels = {}
var unit_buttons = []
var status_label: Label
var pause_button: Button
var mission_panel: PanelContainer
var hud_clock = 0.0
var save_clock = 0.0
var result_committed = false
var sound_enabled = true
var fixed_time = 0.0
var touch_positions = {}
var pinch_distance = 0.0
var gesture_until = 0
const GOLD = Color("d8b784")
const MINT = Color("79d8bd")
const WHITE = Color("e4ebe8")
const MUTED = Color("8d9d9f")


func _ready() -> void:
	career = Career.new()
	missions = JSON.parse_string(FileAccess.get_file_as_string("res://data/missions.json"))
	selected_mission = career.unlocked
	chapter = (selected_mission - 1) / 10
	ui = CanvasLayer.new()
	add_child(ui)
	create_backdrop()
	home()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if op and mode == "mission":
			op.paused = true
			op.save_run()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if op and mode == "mission":
			op.save_run()


func create_backdrop() -> void:
	if world:
		world.queue_free()
	op = Operation.new()
	op.new_mission(missions[0], career.loadouts)
	op.visible.fill(true)
	op.explored.fill(true)
	world = TacticalWorld.new()
	add_child(world)
	world.build(op)
	world.camera_target = Vector3(16, 0, 12)
	world.camera_zoom = 28
	world.position_camera()
	world.sync(0)
	for node in world.actors.values():
		node.visible = false


func clear_ui() -> void:
	if root:
		root.queue_free()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	hud_labels.clear()
	unit_buttons.clear()


func style(bg: Color, border: Color = Color("293a40"), radius: int = 10) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


func panel(parent: Node, rect: Rect2, color: Color = Color("101b23")) -> PanelContainer:
	var p = PanelContainer.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", style(color))
	parent.add_child(p)
	return p


func label(parent: Node, text: String, size: int = 18, color: Color = WHITE) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func button(parent: Node, text: String, callback: Callable, accent: bool = false) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color("101b23") if accent else WHITE)
	b.add_theme_color_override("font_hover_color", Color("101b23") if accent else WHITE)
	b.add_theme_stylebox_override("normal", style(GOLD if accent else Color("1b2b34")))
	b.add_theme_stylebox_override(
		"hover", style(Color("e8c895") if accent else Color("29434b"), MINT)
	)
	b.add_theme_stylebox_override("pressed", style(Color("9fbdab")))
	b.add_theme_stylebox_override("disabled", style(Color("142029")))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func vbox(parent: Node, separation: int = 12) -> VBoxContainer:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	parent.add_child(v)
	return v


func hbox(parent: Node, separation: int = 10) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	parent.add_child(h)
	return h


func full_shade(alpha: float) -> void:
	var shade = ColorRect.new()
	shade.color = Color(0.025, 0.04, 0.055, alpha)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)


func home() -> void:
	mode = "home"
	clear_ui()
	full_shade(0.55)
	var p = panel(root, Rect2(54, 60, 480, 748), Color(0.04, 0.07, 0.09, 0.96))
	var v = vbox(p, 15)
	label(v, "TACTICAL COMMAND  /  OFFLINE CAMPAIGN", 13, MINT)
	label(v, "BLACKLINE", 54, WHITE)
	label(v, "Every room holds a different truth.", 20, GOLD)
	var intro = label(
		v,
		"Read the light. Listen to the building.\nCommand four officers through a city\nthat remembers every disturbance.",
		18,
		MUTED
	)
	intro.custom_minimum_size.y = 94
	label(v, "50 OPERATIONS     •     5 CHAPTERS", 15, WHITE)
	button(v, "OPERATIONS  →", campaign, true)
	if FileAccess.file_exists(Operation.SAVE):
		button(v, "CONTINUE SAVED OPERATION", resume_run)
	button(v, "ARMOURY & LOADOUTS", armoury)
	button(v, "FIELD MANUAL", manual)
	button(
		v,
		"AUDIO: ON" if sound_enabled else "AUDIO: OFF",
		func():
			sound_enabled = not sound_enabled
			world.sound_enabled = sound_enabled
			home()
	)
	label(v, "%s credits  /  Reputation %s" % [career.credits, career.reputation], 16, GOLD)
	label(v, "FIRST PLAYABLE BUILD  ·  3D / ANDROID EXPORT", 11, MUTED)
	var stamp = label(root, "KNOW WHAT YOU CAN SEE.\nQUESTION WHAT YOU CANNOT.", 25, WHITE)
	stamp.position = Vector2(720, 715)


func campaign() -> void:
	mode = "campaign"
	clear_ui()
	full_shade(0.86)
	var p = panel(root, Rect2(42, 34, 1356, 814))
	var v = vbox(p, 14)
	var top = hbox(v)
	label(top, "OPERATIONS", 32)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	button(top, "ARMOURY", armoury)
	button(top, "BACK", home)
	label(v, "%s  /  CHAPTER %d OF 5" % [missions[chapter * 10].chapter, chapter + 1], 15, GOLD)
	var nav = hbox(v)
	for i in range(5):
		var c = i
		button(
			nav,
			"0%d" % (i + 1),
			func():
				chapter = c
				campaign(),
			i == chapter
		)
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	for i in range(chapter * 10, chapter * 10 + 10):
		var m = missions[i]
		var id = int(m.id)
		var unlocked = id <= career.unlocked
		var b = button(
			grid,
			"%02d  %s\n%s" % [id, m.name.to_upper(), "AVAILABLE" if unlocked else "LOCKED"],
			func():
				selected_mission = id
				campaign(),
			id == selected_mission
		)
		b.custom_minimum_size = Vector2(246, 104)
		b.add_theme_font_size_override("font_size", 14)
		b.disabled = not unlocked
	var m = missions[selected_mission - 1]
	label(v, "%02d / %s" % [m.id, m.name.to_upper()], 26, WHITE)
	var desc = label(v, m.briefing, 17, MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.y = 60
	label(
		v,
		(
			"BRIEFING: %d civilians  ·  %d evidence  ·  hostile count unconfirmed"
			% [m.civilians, m.evidence]
		),
		16,
		GOLD
	)
	label(
		v, "Equipment is permanent. Basic supplies are replenished for every operation.", 15, MUTED
	)
	button(v, "DEPLOY SQUAD  →", func(): start_mission(selected_mission), true)


func armoury() -> void:
	mode = "armoury"
	clear_ui()
	full_shade(0.88)
	var p = panel(root, Rect2(42, 34, 1356, 814))
	var v = vbox(p, 10)
	var top = hbox(v)
	label(top, "ARMOURY", 32)
	label(top, "   %d CREDITS   /   REP %d" % [career.credits, career.reputation], 18, GOLD)
	button(top, "BACK", home)
	var squad = hbox(v)
	for i in range(4):
		var id = i
		button(
			squad,
			Arsenal.NAMES[i],
			func():
				armoury_officer = id
				armoury(),
			i == armoury_officer
		)
	label(
		v,
		"%s / LEVEL %d  —  Select a weapon and three tools. Purchases unlock squad-wide access." % [Arsenal.NAMES[armoury_officer],1+int(career.loadouts[armoury_officer].get("experience",0))/180],
		15,
		MUTED
	)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1280, 565)
	v.add_child(scroll)
	var items = vbox(scroll, 9)
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var combined = Arsenal.WEAPONS.duplicate(true)
	combined.merge(Arsenal.GEAR)
	for id in combined:
		var item = combined[id]
		var row = hbox(items)
		var details = vbox(row, 4)
		details.custom_minimum_size.x = 820
		label(details, item.name, 18, WHITE)
		var text = item.get("description", "")
		if id in Arsenal.WEAPONS:
			text = (
				"Magazine %d • Reload %.1fs • Weight %.1f • Sound %s"
				% [
					item.capacity,
					item.reload,
					item.weight,
					"reduced" if item.suppressed else "full"
				]
			)
		label(details, text, 14, MUTED)
		var owned = id in career.owned
		var equipped = (
			career.loadouts[armoury_officer].weapon == id
			or id in career.loadouts[armoury_officer].gear
		)
		var action = (
			"EQUIPPED"
			if equipped
			else "EQUIP" if owned else "%d CR / REP %d" % [item.price, item.rep]
		)
		var item_id = id
		var b = button(
			row,
			action,
			func():
				if career.purchase(item_id):
					career.equip(item_id, armoury_officer)
				armoury(),
			equipped
		)
		b.custom_minimum_size.x = 350
		if not owned:
			b.disabled = career.credits < int(item.price) or career.reputation < int(item.rep)
	label(
		v,
		"Three tool slots per officer. Specialist equipment changes your options; it does not make you invulnerable.",
		14,
		GOLD
	)


func manual() -> void:
	mode = "manual"
	clear_ui()
	full_shade(0.9)
	var p = panel(root, Rect2(90, 45, 1260, 800))
	var v = vbox(p, 13)
	label(v, "FIELD MANUAL", 32)
	var text = "1  SELECT an officer using the cards or tap their model.\n2  MOVE: tap floor to plot a route. Queue adds waypoints. ALL commands the squad.\n3  Press GO to execute; PAUSE at any time. Space also toggles pause on desktop.\n4  FACE turns the selected officer. Vision depends on direction, light and walls.\n5  INTERACT: nearby doors, light switches or suspects. Doors also open along a route.\n6  HOLD FIRE stops automatic engagement. INTERACT requests surrender; repeat nearby to secure.\n7  SHOOT LIGHT targets a visible fixture while time is running. The shot can alert suspects.\n8  Civilians follow a nearby officer. Lead them to the green deployment zone.\n9  Stand near gold evidence cases to collect them. A utility knife halves collection time.\n10 EXTRACT when civilians and evidence are secured and living officers are in the green zone.\n\nUnexplored areas are black; old observations remain dim. Amber rings mark stale sightings.\nHigh-alert enemies never forget. A jammer blocks new radio messages, not old knowledge.\nEquipped goggles improve dark-room detection. Thermal cannot see through walls.\n\nMouse wheel / + − zoom. Right-drag or arrow buttons pan. Two-finger pinch works on touch.\nSAVE & HQ stores the entire operation; continue later. Backgrounding automatically pauses."
	var l = label(v, text, 18, MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button(v, "BACK TO HEADQUARTERS", home, true)


func start_mission(id: int) -> void:
	if world:
		world.queue_free()
	op = Operation.new()
	op.new_mission(missions[id - 1], career.loadouts)
	setup_operation()
	op.save_run()


func resume_run() -> void:
	var saved = Operation.new()
	if not saved.load_run():
		return
	if world:
		world.queue_free()
	op = saved
	setup_operation()


func setup_operation() -> void:
	mode = "mission"
	result_committed = false
	fixed_time = 0
	world = TacticalWorld.new()
	add_child(world)
	world.build(op)
	world.sound_enabled = sound_enabled
	command = "MOVE"
	build_hud()


func build_hud() -> void:
	clear_ui()
	var top = PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_right = -18
	top.offset_top = 14
	top.offset_bottom = 99
	top.add_theme_stylebox_override("panel", style(Color(0.04, 0.075, 0.10, 0.96)))
	root.add_child(top)
	var row = hbox(top, 20)
	var title = vbox(row, 4)
	label(title, "BLACKLINE  /  OPERATION %02d" % int(op.mission.id), 13, GOLD)
	label(title, op.mission.name.to_upper(), 23, WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var objective = vbox(row, 4)
	hud_labels.objective = label(objective, "", 16, MINT)
	hud_labels.alert = label(objective, "", 13, MUTED)
	pause_button = button(row, "GO", func(): op.paused = not op.paused, true)
	pause_button.custom_minimum_size.x = 110
	button(
		row,
		"SAVE & HQ",
		func():
			op.paused = true
			op.save_run()
			create_backdrop()
			home()
	)
	var bottom = PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 18
	bottom.offset_right = -18
	bottom.offset_top = -224
	bottom.offset_bottom = -14
	bottom.add_theme_stylebox_override("panel", style(Color(0.04, 0.075, 0.10, 0.96)))
	root.add_child(bottom)
	var col = vbox(bottom, 8)
	var squad = hbox(col, 10)
	for i in range(4):
		var id = i
		var b = button(
			squad,
			"",
			func():
				op.selected = id
				op.update_visibility()
		)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 66
		b.add_theme_font_size_override("font_size", 14)
		unit_buttons.append(b)
	var commands = hbox(col, 7)
	for name in ["MOVE", "FACE", "INTERACT", "SHOOT LIGHT"]:
		var cmd = name
		var b = button(commands, name, func(): command = cmd)
		b.custom_minimum_size.x = 117
		b.add_theme_font_size_override("font_size", 13)
	button(commands, "ALL", func(): op.group = not op.group)
	button(
		commands,
		"HOLD FIRE",
		func():
			var hold = not op.units[op.selected].hold
			for u in op.units:
				if u.team == "officer" and (op.group or u.id == op.selected):
					u.hold = hold
	)
	button(commands, "RELOAD", func(): op.reload_unit(op.units[op.selected]))
	button(commands, "JAMMER", func(): op.toggle_jammer())
	button(commands, "HEAL", func(): op.heal())
	button(commands, "EXTRACT", func(): op.extract(), true)
	status_label = label(col, "", 13, MUTED)
	var right = PanelContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -240
	right.offset_right = -20
	right.offset_top = 113
	right.offset_bottom = 340
	right.add_theme_stylebox_override("panel", style(Color(0.04, 0.075, 0.10, 0.90)))
	root.add_child(right)
	var tools = vbox(right, 7)
	label(tools, "COMMAND VIEW", 13, GOLD)
	var zoomrow = hbox(tools)
	button(zoomrow, "−", func(): world.zoom(3))
	button(zoomrow, "+", func(): world.zoom(-3))
	button(
		zoomrow,
		"RESET",
		func():
			world.camera_target = Vector3(16, 0, 12)
			world.camera_zoom = 29
			world.position_camera()
	)
	var arrows = hbox(tools, 3)
	for pair in [
		["←", Vector2(-3, 0)], ["↑", Vector2(0, -3)], ["↓", Vector2(0, 3)], ["→", Vector2(3, 0)]
	]:
		var movement = pair[1]
		button(arrows, pair[0], func(): world.pan(movement))
	var check = CheckButton.new()
	check.text = "Queue waypoints"
	check.toggled.connect(func(enabled): queue_waypoints = enabled)
	tools.add_child(check)
	hud_labels.info = label(tools, "", 12, MUTED)
	refresh_hud()


var queue_waypoints = false


func refresh_hud() -> void:
	if mode != "mission":
		return
	pause_button.text = "GO" if op.paused else "PAUSE"
	hud_labels.objective.text = (
		"CIVILIANS %d/%d   EVIDENCE %d/%d"
		% [op.rescued, op.mission.civilians, op.collected, op.mission.evidence]
	)
	hud_labels.alert.text = (
		op.last_alert + "  /  %02d:%02d" % [int(op.time) / 60, int(op.time) % 60]
	)
	for i in range(4):
		var u = op.units[i]
		var state = (
			"DOWN"
			if u.hp <= 0
			else "RELOADING" if u.reload > 0 else "HOLD FIRE" if u.hold else "READY"
		)
		unit_buttons[i].text = (
			"%s  %s\nHP %d  •  ARM %d  •  AMMO %d  /  %s"
			% ["▸" if i == op.selected else "", Arsenal.NAMES[i], u.hp, u.armour, u.ammo, state]
		)
		unit_buttons[i].modulate = MINT if i == op.selected else WHITE
	var u = op.units[op.selected]
	hud_labels.info.text = (
		"RADIO: %s\nJAM BATTERY: %ds"
		% ["LOCAL ONLY" if op.jammed(u.pos) else "CONNECTED", u.battery]
	)
	status_label.text = (
		"%s %s  |  %s"
		% [command, "[ALL]" if op.group else "[SINGLE]", op.logs[0] if op.logs.size() > 0 else ""]
	)


func result_screen() -> void:
	mode = "result"
	var alive = 0
	for u in op.units:
		if u.team == "officer" and u.hp > 0:
			alive += 1
	var reward = 0
	if not result_committed:
		result_committed = true
		if op.victory:
			reward = career.reward(
				int(op.mission.id),
				alive * 100 + op.rescued * 100 + op.arrests * 75,
				op.arrests,
				op.rescued,
				alive
			)
		op.save_run()
	clear_ui()
	full_shade(0.82)
	var p = panel(root, Rect2(390, 135, 660, 630))
	var v = vbox(p, 18)
	label(v, "AFTER-ACTION REPORT", 14, GOLD)
	label(v, "OPERATION COMPLETE" if op.victory else "OPERATION FAILED", 30, WHITE)
	label(v, op.mission.name, 22, MUTED)
	label(
		v,
		(
			"Officers returned: %d / 4\nCivilians rescued: %d\nSuspects arrested: %d\nEvidence recovered: %d"
			% [alive, op.rescued, op.arrests, op.collected]
		),
		22,
		WHITE
	)
	label(v, "+%d DEPARTMENT CREDITS" % reward, 26, MINT)
	label(v, "Equipment is retained. There is no fee to retry.", 16, MUTED)
	button(
		v,
		"HEADQUARTERS",
		func():
			create_backdrop()
			home(),
		true
	)
	button(v, "RETRY OPERATION", func(): start_mission(int(op.mission.id)))


func _process(dt: float) -> void:
	if mode != "mission" or not op:
		return
	fixed_time += minf(dt, 0.1)
	while fixed_time >= 0.05:
		op.step(0.05)
		fixed_time -= 0.05
	world.sync(dt)
	hud_clock -= dt
	save_clock += dt
	if hud_clock <= 0:
		hud_clock = 0.15
		refresh_hud()
	if save_clock >= 12:
		save_clock = 0
		op.save_run()
	if op.finished:
		result_screen()


func _input(event: InputEvent) -> void:
	if mode != "mission":
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_positions[event.index] = event.position
		else:
			touch_positions.erase(event.index)
		if touch_positions.size() < 2:
			pinch_distance = 0
	if event is InputEventScreenDrag:
		touch_positions[event.index] = event.position
		if touch_positions.size() == 2:
			var points = touch_positions.values()
			var d = points[0].distance_to(points[1])
			if pinch_distance > 0:
				world.zoom((pinch_distance - d) * 0.035)
			pinch_distance = d
			gesture_until = Time.get_ticks_msec() + 250


func _unhandled_input(event: InputEvent) -> void:
	if mode != "mission":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			op.paused = not op.paused
		if event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
			op.selected = event.keycode - KEY_1
		if event.keycode == KEY_ESCAPE:
			op.paused = true
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		world.pan(-event.relative * world.camera_zoom / 900.0)
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			world.zoom(-1.5)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			world.zoom(1.5)
		elif (
			not event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT
			and Time.get_ticks_msec() > gesture_until
		):
			var p = world.ground_point(event.position)
			for u in op.units:
				if u.team == "officer" and u.pos.distance_to(p) < 0.5:
					op.selected = u.id
					op.update_visibility()
					return
			if command == "MOVE":
				op.order_move(p, queue_waypoints or Input.is_key_pressed(KEY_SHIFT))
			elif command == "FACE":
				op.face_selected(p)
			elif command == "INTERACT":
				op.interact(p)
			elif command == "SHOOT LIGHT":
				op.shoot_light(p)
