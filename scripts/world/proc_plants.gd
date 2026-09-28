class_name ProcPlants
extends RefCounted
## Procedural plants for biomes the model kit has nothing for: lavender bush, heather cushion.
## Vertex colors carry the look (surface "Proc" → foliage shader mode 3), crossed quads keep them light.

## Mesh for a model name like "Proc_Lavender" (null if unknown)
static func build(model: String) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(model)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match model:
		"Proc_Lavender":
			_lavender(st, rng)
		"Proc_Heather":
			_heather(st, rng)
		"Proc_Reeds":
			_reeds(st, rng)
		"Proc_LilyPad":
			_lily(st, rng, false)
		"Proc_Lily":
			_lily(st, rng, true)
		_:
			return null
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.resource_name = "Proc"
	mesh.surface_set_material(0, mat)
	return mesh


## Upright quad from a to b (width w, facing sideways dir), colors bottom/top; normals lean outwards and up
static func _blade(st: SurfaceTool, a: Vector3, b: Vector3, side: Vector3, w_bottom: float, w_top: float,
		c_bottom: Color, c_top: Color, out: Vector3) -> void:
	var n := (out * 0.8 + Vector3.UP * 1.2).normalized()
	var p := [a - side * w_bottom, a + side * w_bottom, b + side * w_top, b - side * w_top]
	var c := [c_bottom, c_bottom, c_top, c_top]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_color((c[i] as Color).srgb_to_linear())
		st.set_normal(n)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(p[i])


## Two crossed quads
static func _cross(st: SurfaceTool, a: Vector3, b: Vector3, w_bottom: float, w_top: float, c_bottom: Color, c_top: Color, rot: float) -> void:
	var out := Vector3(a.x, 0.0, a.z).normalized() if Vector2(a.x, a.z).length() > 0.01 else Vector3(cos(rot), 0, sin(rot))
	for k in 2:
		var ang := rot + k * PI * 0.5
		var side := Vector3(cos(ang), 0.0, sin(ang))
		_blade(st, a, b, side, w_bottom, w_top, c_bottom, c_top, out)


## Round bush of ~18 stalks, each with a purple flower spike (≈ 0.75 m)
static func _lavender(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var stem_dark := Color("4f6b3a")
	var stem := Color("7d9460")
	for i in 26:
		var a := rng.randf() * TAU
		var r0 := sqrt(rng.randf()) * 0.14
		var base := Vector3(cos(a) * r0, 0.0, sin(a) * r0)
		var lean := rng.randf_range(0.15, 0.5)
		var h := rng.randf_range(0.55, 0.8)
		var tip := base + Vector3(cos(a) * lean * h, h, sin(a) * lean * h)
		var mid := base.lerp(tip, 0.62)
		var purple := Color.from_hsv(rng.randf_range(0.72, 0.77), rng.randf_range(0.42, 0.55), rng.randf_range(0.62, 0.8))
		_cross(st, base, mid, 0.012, 0.01, stem_dark, stem, a)
		_cross(st, mid, tip, 0.036, 0.014, purple.darkened(0.25), purple.lightened(0.12), a + 0.4)
	# grey-green leaf tuft at the foot
	for i in 5:
		var a := rng.randf() * TAU
		var tip := Vector3(cos(a) * 0.22, 0.22, sin(a) * 0.22)
		_cross(st, Vector3.ZERO, tip, 0.05, 0.02, stem_dark, Color("93a37a"), a)


## Low cushion of heather: many fine twigs, dark at the foot, pink-purple blossom along the upper half (≈ 0.3 m)
static func _heather(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var dark := Color("3a4228")
	var mid := Color("5d6a3a")
	for i in 30:
		var a := rng.randf() * TAU
		var r0 := sqrt(rng.randf()) * 0.3
		var base := Vector3(cos(a) * r0, 0.0, sin(a) * r0)
		var h := rng.randf_range(0.16, 0.34) * (1.0 - r0 * 1.1)
		var lean := rng.randf_range(0.1, 0.35)
		var tip := base + Vector3(cos(a) * lean * h, h, sin(a) * lean * h)
		var mid_p := base.lerp(tip, 0.45)
		var pink := Color.from_hsv(rng.randf_range(0.82, 0.9), rng.randf_range(0.35, 0.55), rng.randf_range(0.62, 0.85))
		_cross(st, base, mid_p, 0.012, 0.012, dark, mid, a)
		_cross(st, mid_p, tip, 0.028, 0.012, pink.darkened(0.2), pink.lightened(0.1), a + 0.5)


## A clump of reeds (≈ 1.6 m), some stems with a brown cattail
static func _reeds(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var base_c := Color("3f5a26")
	for i in 16:
		var a := rng.randf() * TAU
		var r0 := sqrt(rng.randf()) * 0.22
		var base := Vector3(cos(a) * r0, 0.0, sin(a) * r0)
		var h := rng.randf_range(1.1, 1.75)
		var lean := rng.randf_range(0.05, 0.25)
		var tip := base + Vector3(cos(a) * lean * h, h, sin(a) * lean * h)
		var mid := base.lerp(tip, 0.55)
		var tip_c := Color.from_hsv(rng.randf_range(0.2, 0.26), rng.randf_range(0.45, 0.6), rng.randf_range(0.58, 0.75))
		# a blade: wide at the foot, pointed at the tip
		_cross(st, base, mid, 0.025, 0.018, base_c, tip_c.darkened(0.12), a)
		_cross(st, mid, tip, 0.018, 0.002, tip_c.darkened(0.12), tip_c, a + 0.3)
		if i % 4 == 0:
			# cattail: a thin stem with a velvety brown head
			var top := base + Vector3(0, h * 1.05, 0)
			var head_bottom := top - Vector3(0, 0.26, 0)
			_cross(st, base, head_bottom, 0.008, 0.008, base_c, tip_c, a + 1.0)
			_cross(st, head_bottom, top - Vector3(0, 0.02, 0), 0.034, 0.03, Color("6b4428"), Color("7d5230"), a + 0.8)
			_cross(st, top - Vector3(0, 0.02, 0), top + Vector3(0, 0.1, 0), 0.006, 0.002, tip_c, tip_c, a)


## A floating water lily pad (Ø ≈ 0.55 m, with the notch), optionally with a flower on it
static func _lily(st: SurfaceTool, rng: RandomNumberGenerator, bloom: bool) -> void:
	var green := Color.from_hsv(rng.randf_range(0.24, 0.29), 0.6, 0.66)
	var rim := green.darkened(0.18)
	var seg := 18
	var notch := 0.35
	for i in seg:
		var a0 := notch + (TAU - notch) * i / seg
		var a1 := notch + (TAU - notch) * (i + 1) / seg
		var r0 := 0.27 + sin(a0 * 5.0) * 0.008
		var r1 := 0.27 + sin(a1 * 5.0) * 0.008
		var pts := [Vector3(0, 0.005, 0), Vector3(cos(a1) * r1, 0.0, sin(a1) * r1), Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)]
		var cols := [green.lightened(0.12), rim, rim]
		for k in 3:
			st.set_color((cols[k] as Color).srgb_to_linear())
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(pts[k])
	if bloom:
		var petal := Color("fbf2f4") if rng.randf() < 0.6 else Color("f4b6cf")
		for ring in 2:
			var n := 8
			var len := 0.11 if ring == 0 else 0.075
			var up := 0.35 if ring == 0 else 0.9
			for i in n:
				var a := TAU * (i + ring * 0.5) / n
				var dir := Vector3(cos(a), 0, sin(a))
				var side := Vector3(-dir.z, 0, dir.x)
				var base := Vector3(0, 0.02, 0)
				var tip := base + (dir * cos(up) + Vector3.UP * sin(up)) * len
				var quad := [base - side * 0.018, base + side * 0.018, tip + side * 0.022, tip - side * 0.022]
				for k: int in [0, 1, 2, 0, 2, 3]:
					st.set_color((petal if k != 0 and k != 1 else petal.darkened(0.08)).srgb_to_linear())
					st.set_normal((Vector3.UP + dir * 0.4).normalized())
					st.set_uv(Vector2(0.5, 0.5))
					st.add_vertex(quad[k])
		# golden heart
		for i in 5:
			var a := TAU * i / 5.0
			var pts := [Vector3(0, 0.07, 0), Vector3(cos(a) * 0.025, 0.03, sin(a) * 0.025), Vector3(cos(a + TAU / 5.0) * 0.025, 0.03, sin(a + TAU / 5.0) * 0.025)]
			for k in 3:
				st.set_color(Color("f2c230").srgb_to_linear())
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(0.5, 0.5))
				st.add_vertex(pts[k])
