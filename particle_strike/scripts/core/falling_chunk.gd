class_name FallingChunk
extends RigidBody3D
## Оторвавшийся кусок постройки. Падает как твёрдое тело,
## при ударе о землю рассыпается на частицы и бьёт по всему рядом (каскадные разрушения).

var points := PackedVector3Array()
var cols := PackedColorArray()
var vsize := 0.5
var value := 0.0
var explosive := false
var age := 0.0
var shattered := false


func setup(world_points: PackedVector3Array, colors: PackedColorArray, voxel_size: float, total_value: float, has_explosive: bool) -> void:
	vsize = voxel_size
	value = total_value
	explosive = has_explosive
	var center := Vector3.ZERO
	for p in world_points:
		center += p
	center /= float(maxi(world_points.size(), 1))
	position = center
	points.resize(world_points.size())
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for k in world_points.size():
		var lp := world_points[k] - center
		points[k] = lp
		lo = lo.min(lp)
		hi = hi.max(lp)
	cols = colors

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = VoxelObject.cube_mesh()
	mm.instance_count = points.size()
	var buf := PackedFloat32Array()
	buf.resize(points.size() * 16)
	buf.fill(0.0)
	var s := vsize * 0.9
	for k in points.size():
		var o := k * 16
		var p := points[k]
		var c := cols[k]
		buf[o] = s
		buf[o + 3] = p.x
		buf[o + 5] = s
		buf[o + 7] = p.y
		buf[o + 10] = s
		buf[o + 11] = p.z
		buf[o + 12] = c.r
		buf[o + 13] = c.g
		buf[o + 14] = c.b
		buf[o + 15] = c.a
	mm.buffer = buf
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = ((hi - lo) + Vector3.ONE * vsize).max(Vector3.ONE * 0.6) * 0.85
	shape.shape = box
	shape.position = (hi + lo) * 0.5
	add_child(shape)

	collision_layer = GameWorld.L_CHUNK
	collision_mask = GameWorld.L_WORLD
	mass = clampf(points.size() * 0.05, 1.0, 400.0)
	contact_monitor = true
	max_contacts_reported = 2
	continuous_cd = true
	body_entered.connect(_on_body_entered)


func start(gravity_scale_value: float) -> void:
	gravity_scale = gravity_scale_value
	var tip := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	angular_velocity = tip.cross(Vector3.UP) * randf_range(0.4, 1.4)
	linear_velocity = Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5), randf_range(-1.0, 1.0))


func _physics_process(delta: float) -> void:
	age += delta
	if age > 7.0 or global_position.y < -30.0:
		shatter()
	elif age > 2.5 and linear_velocity.length() < 0.6:
		shatter()


func _on_body_entered(_b: Node) -> void:
	if age > 0.08 and not shattered:
		call_deferred("shatter")


func shatter() -> void:
	if shattered:
		return
	shattered = true
	var gw := GameWorld.current
	if gw == null:
		queue_free()
		return
	var n := points.size()
	var budget := int(Perf.get_value("per_event")) * 2
	var stride := maxi(1, ceili(float(n) / float(maxi(budget, 1))))
	var size_boost := minf(1.0 + 0.12 * float(stride - 1), 2.0)
	var xf := global_transform
	var base_vel := linear_velocity * 0.35
	var center := global_position
	for k in range(0, n, stride):
		var wp := xf * points[k]
		var out := (wp - center)
		var ol := out.length()
		out = out / ol if ol > 0.01 else Vector3.UP
		var vel := base_vel + out * randf_range(2.0, 7.0) + Vector3(0, randf_range(2.0, 7.0), 0)
		gw.debris.spawn(wp, vel, cols[k], vsize * 0.85 * size_boost, k % 4 == 0)
	gw.on_voxels_destroyed(n, value, center, false)
	gw.on_chunk_impact(center, n, explosive)
	queue_free()
