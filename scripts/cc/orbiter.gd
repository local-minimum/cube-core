extends Node3D
class_name Orbiter

@export var target: Node3D:
    get():
        if target == null:
            return self
        return target

@export var managed: bool
@export var _rotation_speed_variation: float = 0
@export var _rotation_axis_max_speed: float = 0.1
@export var center: Vector3

## Radius of the orbit
var _radius: float
var _orbit_vector: Vector3
## The local rotation around the parent position of the orbited object
var _orbiter_rotation: Quaternion
## How the object orbits around the parent
var _rotation: Quaternion

func _ready() -> void:
    if !managed:
        _orbit_vector = target.position
        _radius = target.position.length()
        _orbiter_rotation = Transform3D.IDENTITY.looking_at(target.position).basis.get_rotation_quaternion()
        var eulers: Vector3 = Vector3(
            randf_range(-_rotation_axis_max_speed, _rotation_axis_max_speed),
            randf_range(-_rotation_axis_max_speed, _rotation_axis_max_speed),
            randf_range(-_rotation_axis_max_speed, _rotation_axis_max_speed),
        )
        _rotation = Quaternion.from_euler(eulers.normalized() * _rotation_axis_max_speed)

func start_orbit(start_point: Vector3, orbit_rotation_eulers: Vector3, speed: float) -> void:
    _radius = start_point.length()
    _orbit_vector = start_point
    _orbiter_rotation = Transform3D.IDENTITY.looking_at(start_point).basis.get_rotation_quaternion()
    _rotation = Quaternion.from_euler(orbit_rotation_eulers * speed)

func _process(delta: float) -> void:
    var rot: Quaternion = delta * (1 - _rotation_speed_variation + randf() * _rotation_speed_variation) * _rotation
    _orbiter_rotation *= rot
    _orbiter_rotation = _orbiter_rotation.normalized()
    # target.position = _radius * Vector3.UP * _orbiter_rotation
    target.position = center + _orbit_vector * _orbiter_rotation
