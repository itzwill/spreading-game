extends MultiMeshInstance3D

@export var radius := 100.0

func _ready():
	randomize()

	for i in multimesh.instance_count:
		var angle = randf() * TAU
		var distance = randf_range(30.0, radius)

		var position = Vector3(
			cos(angle) * distance,
			0.0,
			sin(angle) * distance
		)

		var rotation = Basis.from_euler(
			Vector3(0, randf() * TAU, 0)
		)

		var transform = Transform3D(rotation, position)

		multimesh.set_instance_transform(i, transform)
