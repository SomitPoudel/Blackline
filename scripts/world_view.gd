class_name TacticalWorld
extends Node3D

var op: Operation
var camera: Camera3D
var actors = {}
var fixtures = []
var door_nodes = {}
var evidence_nodes = []
var dynamic_root: Node3D
var fog_image: Image
var fog_texture: ImageTexture
var fog_material: ShaderMaterial
var fog_clock = 0.0
var mats = {}
var selected_ring: MeshInstance3D
var route_nodes = []
var audio_pool = []
var audio_cursor = 0
var sound_enabled = true
var sound_streams = {}
var camera_target = Vector3(16, 0, 12)
var camera_zoom = 29.0
var floor_material: ShaderMaterial
var environment: Environment


func material(color: Color, metallic: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var key = str(color) + str(metallic) + str(glow)
	if mats.has(key):
		return mats[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = 0.63
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	mats[key] = m
	return m


func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


func cylinder(
	parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material
) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


func build(operation: Operation) -> void:
	op = operation
	var env = WorldEnvironment.new()
	var atmosphere = Environment.new()
	atmosphere.background_mode = Environment.BG_COLOR
	atmosphere.background_color = Color("080d14")
	atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.ambient_light_color = Color("738496")
	atmosphere.ambient_light_energy = 0.30
	atmosphere.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = atmosphere
	environment=atmosphere
	add_child(env)
	var sun = DirectionalLight3D.new()
	sun.light_color = Color("a8c6e0")
	sun.light_energy = 0.35
	sun.rotation_degrees = Vector3(-65, -25, 0)
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_zoom
	camera.far = 100
	camera.current = true
	add_child(camera)
	position_camera()
	var listening = AudioListener3D.new()
	camera.add_child(listening)
	listening.make_current()
	build_floor_material()
	box(self, Vector3(16, -0.25, 12), Vector3(34, 0.4, 26), material(Color("111c24")))
	for r in op.rooms:
		box(
			self,
			Vector3(r.get_center().x, -0.015, r.get_center().y),
			Vector3(r.size.x, 0.1, r.size.y),
			floor_material
		)
	box(self, Vector3(16, -0.01, 12), Vector3(26, 0.1, 3.0), floor_material)
	build_walls()
	for i in range(op.rooms.size()):
		var r = op.rooms[i]
		var room_label = Label3D.new()
		room_label.text = [
			"ADMINISTRATION", "OPERATIONS", "RECORDS", "STAFF ROOM", "STORAGE", "SERVICE"
		][i]
		room_label.font_size = 42
		room_label.outline_size=0
		room_label.pixel_size = 0.006
		room_label.modulate = Color(0.69, 0.75, 0.69, 0.50)
		room_label.position = Vector3(r.get_center().x, 0.07, r.end.y - 0.8)
		room_label.rotation_degrees.x = -90
		room_label.no_depth_test = false
		add_child(room_label)
	for prop in op.props:
		build_prop(prop)
	for l in op.lights:
		var holder = Node3D.new()
		holder.position = Vector3(l.pos.x, 1.65, l.pos.y)
		add_child(holder)
		box(holder, Vector3.ZERO, Vector3(1.0, 0.08, 0.25), material(Color("bac1ba"), 0.5))
		var bulb = box(
			holder,
			Vector3(0, -0.07, 0),
			Vector3(0.82, 0.05, 0.14),
			material(Color("ffe0a1"), 0, 1.5)
		)
		var light = OmniLight3D.new()
		light.position = Vector3(0, -0.18, 0)
		light.light_color = Color("ffe3b2")
		light.light_energy = 1.9
		light.omni_range = 7.0
		light.omni_attenuation = 1.25
		light.shadow_enabled = true
		light.shadow_bias = 0.06
		holder.add_child(light)
		fixtures.append({"holder": holder, "bulb": bulb, "light": light})
	for x in [5, 15, 25]:
		var l = OmniLight3D.new()
		l.position = Vector3(x, 1.8, 12)
		l.omni_range = 5
		l.light_color = Color("7eafc6")
		l.light_energy = 0.6
		add_child(l)
	for u in op.units:
		actors[u.id] = build_actor(u)
	for ev in op.evidence:
		var n = Node3D.new()
		n.position = Vector3(ev.pos.x, 0.12, ev.pos.y)
		add_child(n)
		box(n, Vector3.ZERO, Vector3(0.50, 0.19, 0.35), material(Color("d6ae6d"), 0.25))
		box(n, Vector3(0, 0.11, 0), Vector3(0.28, 0.03, 0.08), material(Color("fff2cf"), 0, 1))
		evidence_nodes.append(n)
	selected_ring = ring_mesh(0.48, material(Color("7ef8d5"), 0, 1.0))
	add_child(selected_ring)
	build_fog()
	dynamic_root = Node3D.new()
	add_child(dynamic_root)
	# Audio uses overlapping positional voices, with separate tails in each original sample.
	for i in range(12):
		var player = AudioStreamPlayer3D.new()
		player.unit_size = 16
		player.max_distance = 60
		add_child(player)
		audio_pool.append(player)
	for id in ["pistol", "smg", "carbine", "shotgun", "suppressed", "glass", "reload"]:
		sound_streams[id] = load("res://assets/audio/" + id + ".wav")


func position_camera() -> void:
	camera.position = camera_target + Vector3(0, 30, 18)
	camera.look_at(camera_target, Vector3.UP)
	camera.size = camera_zoom


func build_floor_material() -> void:
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.27,0.30,0.29,1.0);
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 cell=fract(world_pos.xz*1.25);
 float seam=step(0.035,cell.x)*step(0.035,cell.y);
 float n=fract(sin(dot(floor(world_pos.xz*50.0),vec2(12.9898,78.233)))*43758.5453);
 ALBEDO=base_color.rgb*(0.82+0.18*n)*(0.54+0.46*seam);
 ROUGHNESS=0.79;
}
"""
	floor_material = ShaderMaterial.new()
	floor_material.shader = shader


func build_walls() -> void:
	var transforms = []
	for y in range(2, 22):
		for x in range(2, 30):
			var t = op.tile(Vector2i(x, y))
			if t == 1:
				transforms.append(Transform3D(Basis.IDENTITY, Vector3(x + 0.5, 0.62, y + 0.5)))
			elif t == 3:
				var n = box(
					self,
					Vector3(x + 0.5, 0.55, y + 0.5),
					Vector3(0.9, 1.1, 0.15) if y in [10, 13] else Vector3(0.15, 1.1, 0.9),
					material(Color("6d675a"), 0.15)
				)
				door_nodes[str(y * Operation.W + x)] = n
	var mm = MultiMesh.new()
	var wall = BoxMesh.new()
	wall.size = Vector3(1, 1.25, 1)
	mm.mesh = wall
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var instance = MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = material(Color("68716e"))
	add_child(instance)
	# Lighter cut surfaces make the architectural silhouette readable.
	var cap_mm = MultiMesh.new()
	var cap = BoxMesh.new()
	cap.size = Vector3(1.02, 0.06, 1.02)
	cap_mm.mesh = cap
	cap_mm.transform_format = MultiMesh.TRANSFORM_3D
	cap_mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		var tr = transforms[i]
		tr.origin.y = 1.27
		cap_mm.set_instance_transform(i, tr)
	var caps = MultiMeshInstance3D.new()
	caps.multimesh = cap_mm
	caps.material_override = material(Color("afb6aa"))
	add_child(caps)


func build_prop(p: Dictionary) -> void:
	var n = Node3D.new()
	n.position = Vector3(p.pos.x, 0, p.pos.y)
	add_child(n)
	var steel = material(Color("3e4a4b"), 0.5)
	var wood = material(Color("75624b"))
	var cloth = material(Color("344b4e"))
	match int(p.kind):
		0:
			box(n, Vector3(0, 0.57, 0), Vector3(0.9, 0.09, 0.8), wood)
			for x in [-0.35, 0.35]:
				for z in [-0.28, 0.28]:
					box(n, Vector3(x, 0.28, z), Vector3(0.06, 0.56, 0.06), steel)
			box(n, Vector3(0, 0.77, -0.15), Vector3(0.47, 0.29, 0.06), material(Color("182329")))
			box(
				n,
				Vector3(0, 0.77, -0.11),
				Vector3(0.4, 0.22, 0.015),
				material(Color("579794"), 0, 0.45)
			)
			box(n, Vector3(0, 0.64, 0.16), Vector3(0.34, 0.03, 0.13), steel)
			box(n, Vector3(0.30, 0.63, 0.12), Vector3(0.16, 0.02, 0.23), material(Color("ddd4b8")))
		1:
			box(n, Vector3(0, 0.25, 0), Vector3(0.85, 0.5, 0.8), cloth)
			box(n, Vector3(0, 0.56, -0.30), Vector3(0.85, 0.42, 0.17), cloth)
			for x in [-0.36, 0.36]:
				box(n, Vector3(x, 0.45, 0), Vector3(0.15, 0.34, 0.78), cloth)
			box(n, Vector3(0, 0.52, 0.06), Vector3(0.57, 0.06, 0.49), material(Color("577072")))
		2:
			box(n, Vector3(0, 0.5, 0), Vector3(0.83, 1, 0.75), steel)
			for y in [0.2, 0.5, 0.8]:
				box(
					n,
					Vector3(0, y, 0.385),
					Vector3(0.70, 0.25, 0.025),
					material(Color("66716e"), 0.25)
				)
				box(
					n,
					Vector3(0, y, 0.41),
					Vector3(0.22, 0.04, 0.03),
					material(Color("bdc3b3"), 0.6)
				)
		3:
			box(n, Vector3(0, 0.37, 0), Vector3(0.85, 0.74, 0.85), wood)
			for y in [0.10, 0.55]:
				box(n, Vector3(0, y, 0.435), Vector3(0.91, 0.08, 0.03), steel)
			box(n, Vector3(0, 0.76, 0), Vector3(0.30, 0.02, 0.40), material(Color("c7bb8c")))


func ring_mesh(radius: float, mat: Material) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = TorusMesh.new()
	mesh.inner_radius = radius - 0.025
	mesh.outer_radius = radius + 0.025
	mesh.rings = 24
	mesh.ring_segments = 6
	n.mesh = mesh
	n.material_override = mat
	return n


func build_actor(u: Dictionary) -> Node3D:
	var n = Node3D.new()
	add_child(n)
	var body = material(
		(
			Color("263c4b")
			if u.team == "officer"
			else Color("75544b") if u.team == "suspect" else Color("b5b49e")
		)
	)
	var dark = material(Color("131e23"))
	var skin = material(Color("b9967b"))
	for x in [-0.10, 0.10]:
		box(n, Vector3(x, 0.21, 0), Vector3(0.13, 0.42, 0.16), body)
		box(n, Vector3(x, 0.045, 0.08), Vector3(0.16, 0.09, 0.28), dark)
	box(n, Vector3(0, 0.64, 0), Vector3(0.38, 0.44, 0.25), body)
	cylinder(n, Vector3(0, 0.99, 0), 0.14, 0.23, skin)
	if u.team == "officer":
		cylinder(n, Vector3(0, 1.09, 0), 0.175, 0.15, dark)
		box(n, Vector3(0, 1.01, 0.14), Vector3(0.26, 0.08, 0.03), material(Color("566e70"), 0.65))
		box(n, Vector3(0, 0.67, 0.155), Vector3(0.35, 0.34, 0.10), dark)
		box(n, Vector3(0, 0.77, -0.16), Vector3(0.29, 0.10, 0.02), material(Color("acbda9")))
		for x in [-0.11, 0.0, 0.11]:
			box(n, Vector3(x, 0.57, 0.23), Vector3(0.08, 0.14, 0.07), material(Color("465346")))
		var torch = SpotLight3D.new()
		torch.name = "Torch"
		torch.position = Vector3(0.20, 0.83, 0.28)
		torch.rotation.y = PI
		torch.spot_range = 8.0
		torch.spot_angle = 32
		torch.light_color = Color("d8eaf1")
		torch.light_energy = 1.4
		torch.shadow_enabled = true
		n.add_child(torch)
	if u.team != "civilian":
		box(n, Vector3(-0.23, 0.65, 0.13), Vector3(0.14, 0.14, 0.40), body)
		box(n, Vector3(0.23, 0.65, 0.13), Vector3(0.14, 0.14, 0.40), body)
		var gun = Node3D.new()
		gun.name = "Weapon"
		n.add_child(gun)
		var length = 0.25 if u.weapon == "pistol" else 0.68 if u.weapon == "shotgun" else 0.53
		box(gun, Vector3(0.18, 0.66, 0.30 + length / 3), Vector3(0.08, 0.11, length), dark)
		box(gun, Vector3(0.18, 0.74, 0.31), Vector3(0.065, 0.06, 0.13), dark)
	else:
		for x in [-0.25, 0.25]:
			box(n, Vector3(x, 0.56, 0), Vector3(0.12, 0.44, 0.12), body)
	var heat=cylinder(n,Vector3(0,0.59,0),0.22,0.95,material(Color("ff8954"),0,1.5))
	heat.name="HeatSignature"
	heat.visible=false
	return n


func build_fog() -> void:
	fog_image = Image.create(Operation.W, Operation.H, false, Image.FORMAT_RGBA8)
	fog_image.fill(Color(0, 0, 0, 1))
	fog_texture = ImageTexture.create_from_image(fog_image)
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D mask_tex : filter_nearest;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 st=wp.xz/vec2(32.0,24.0);
 vec4 info=texture(mask_tex,st);
 ALBEDO=info.b>0.5 && info.g<0.5 ? vec3(0.055,0.08,0.10) : vec3(0.012,0.020,0.028);
 ALPHA=info.r>0.5?0.0:(info.g>0.5?0.72:0.995);
}
"""
	fog_material = ShaderMaterial.new()
	fog_material.shader = shader
	fog_material.set_shader_parameter("mask_tex", fog_texture)
	var plane = MeshInstance3D.new()
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(32, 24)
	plane.mesh = mesh
	plane.position = Vector3(16, 2.1, 12)
	plane.material_override = fog_material
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)


func sync(dt: float) -> void:
	var viewing=op.units[op.selected]
	var thermal="thermal" in viewing.gear
	var nightvision="nvg" in viewing.gear and not thermal
	environment.ambient_light_color=Color("729b79") if nightvision else Color("738496")
	environment.ambient_light_energy=0.58 if nightvision else 0.30
	for u in op.units:
		var actor = actors[u.id]
		actor.position = Vector3(u.pos.x, 0, u.pos.y)
		actor.rotation.y = u.angle
		actor.get_node("HeatSignature").visible=thermal and u.hp>0
		actor.visible = u.team == "officer" or op.is_visible(u.pos)
		if actor.has_node("Weapon"):
			actor.get_node("Weapon").visible = not u.surrender and u.hp > 0
		if u.state == "evacuated":
			actor.visible = false
		if u.hp <= 0:
			actor.rotation.z = PI / 2
			actor.position.y = 0.15
		elif u.moving and not op.paused:
			actor.position.y = sin(op.time * 14 + u.id) * 0.025
		if u.team == "officer":
			var torch = actor.get_node("Torch")
			torch.visible = u.hp > 0 and "nvg" not in u.gear and "thermal" not in u.gear
	for i in range(fixtures.size()):
		var active = op.lights[i].on and not op.lights[i].broken
		fixtures[i].light.visible = active
		fixtures[i].bulb.material_override = material(
			Color("ffe0a1") if active else Color("353b3b"), 0, 1.5 if active else 0
		)
	for key in door_nodes:
		door_nodes[key].visible = not op.doors.get(key, false)
	for i in range(evidence_nodes.size()):
		evidence_nodes[i].visible = not op.evidence[i].taken and op.is_visible(op.evidence[i].pos)
	var selected = op.units[op.selected]
	selected_ring.position = Vector3(selected.pos.x, 0.05, selected.pos.y)
	selected_ring.visible = selected.hp > 0
	fog_clock -= dt
	if fog_clock <= 0:
		fog_clock = 0.12
		for y in range(Operation.H):
			for x in range(Operation.W):
				var index = y * Operation.W + x
				fog_image.set_pixel(
					x, y, Color(1 if op.visible[index] else 0, 1 if op.explored[index] else 0, 1 if op.grid[index]==1 else 0, 1)
				)
		fog_texture.update(fog_image)
		update_routes()
	while not op.sounds.is_empty():
		var s = op.sounds.pop_front()
		if sound_enabled and sound_streams.has(s.kind):
			var player = audio_pool[audio_cursor % audio_pool.size()]
			audio_cursor += 1
			player.position = Vector3(s.pos.x, 0.6, s.pos.y)
			player.stream = sound_streams[s.kind]
			player.pitch_scale = randf_range(0.95, 1.05)
			player.volume_db = -9 if s.kind == "suppressed" else -3
			player.play()
	queue_effects()


func line3d(
	a: Vector2, b: Vector2, height: float, width: float, mat: Material, parent: Node3D
) -> void:
	var distance = a.distance_to(b)
	if distance < 0.01:
		return
	var n = box(
		parent,
		Vector3((a.x + b.x) / 2, height, (a.y + b.y) / 2),
		Vector3(width, width, distance),
		mat
	)
	n.rotation.y = atan2(b.x - a.x, b.y - a.y)


func update_routes() -> void:
	for n in route_nodes:
		n.queue_free()
	route_nodes.clear()
	var root = Node3D.new()
	add_child(root)
	route_nodes.append(root)
	var u = op.units[op.selected]
	var last = u.pos
	for p in u.path:
		line3d(last, p, 2.15, 0.035, material(Color("5bd9b8"), 0, 1), root)
		last = p
	# Deployment strip and readable markers are deliberately visible above the fog.
	for x in range(3, 7):
		line3d(
			Vector2(x, 10.8), Vector2(x, 13.1), 2.14, 0.05, material(Color("47bba0"), 0, 0.4), root
		)
	if u.jammer:
		var ring = ring_mesh(6, material(Color("e4b066"), 0, 0.8))
		root.add_child(ring)
		ring.position = Vector3(u.pos.x, 2.2, u.pos.y)
	for key in op.last_known:
		var info = op.last_known[key]
		if not op.is_visible(info.pos) and op.time - info.time < 20:
			var ring = ring_mesh(0.23, material(Color("b88b5b"), 0, 0.25))
			root.add_child(ring)
			ring.position = Vector3(info.pos.x, 2.18, info.pos.y)


func queue_effects() -> void:
	for child in dynamic_root.get_children():
		child.queue_free()
	for e in op.effects:
		if not op.is_visible(e.a):
			continue
		if e.type == "shot":
			line3d(e.a, e.b, 0.75, 0.025, material(Color("ffe6ae"), 0, 3), dynamic_root)
			cylinder(
				dynamic_root,
				Vector3(e.a.x, 0.75, e.a.y),
				0.14,
				0.12,
				material(Color("ffd08a"), 0, 4)
			)
		elif e.type == "sparks":
			for i in range(5):
				var n = box(
					dynamic_root,
					Vector3(e.a.x + sin(i * 2.4) * 0.3, 0.9 + e.life, e.a.y + cos(i * 2.4) * 0.3),
					Vector3(0.04, 0.04, 0.04),
					material(Color("ffd095"), 0, 3)
				)
		elif e.type == "noise" and op.paused:
			var n = ring_mesh(0.7, material(Color("ddd0ad"), 0, 0.4))
			dynamic_root.add_child(n)
			n.position = Vector3(e.a.x, 0.03, e.a.y)


func ground_point(screen_pos: Vector2) -> Vector2:
	var origin = camera.project_ray_origin(screen_pos)
	var direction = camera.project_ray_normal(screen_pos)
	var hit = Plane(Vector3.UP, 0).intersects_ray(origin, direction)
	if hit == null:
		return Vector2(-1, -1)
	return Vector2(hit.x, hit.z)


func zoom(amount: float) -> void:
	camera_zoom = clampf(camera_zoom + amount, 12, 38)
	position_camera()


func pan(delta: Vector2) -> void:
	camera_target.x = clampf(camera_target.x + delta.x, 5, 27)
	camera_target.z = clampf(camera_target.z + delta.y, 4, 20)
	position_camera()
