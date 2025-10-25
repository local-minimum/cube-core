extends Node3D

@export var _rotation_speed_variation: float = 0
@export var _rotation_axis_max_speed: float = 0.1

var _radius: float
var _orbit_direction: Quaternion
var _rotation: Quaternion

func _ready() -> void:
    _radius = position.length()
    _orbit_direction = Transform3D.IDENTITY.looking_at(position).basis.get_rotation_quaternion()
    var eulers: Vector3 = Vector3(
        randf_range(-_rotation_axis_max_speed, _rotation_axis_max_speed),
        randf_range(-_rotation_axis_max_speed, _rotation_axis_max_speed),
        randf_range(-_rotation_axis_max_speed, _rotation_axis_max_speed),
    )
    _rotation = Quaternion.from_euler(eulers.normalized() * _rotation_axis_max_speed)

func _process(delta: float) -> void:
    var rot: Quaternion = delta * (1 - _rotation_speed_variation + randf() * _rotation_speed_variation) * _rotation
    _orbit_direction *= rot
    _orbit_direction = _orbit_direction.normalized()
    position = _radius * Vector3.UP * _orbit_direction
