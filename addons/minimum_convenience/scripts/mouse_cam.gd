extends Node3D
class_name MouseCamera

@export var _yaw_limit_degrees: float = 90
@export var _pitch_limit_degrees: float = 80
@export var _easeback_duration: float = 0.5
@export var sensitivity: float = 0.3
@export var invert_y: bool

var _mouse_offset: Vector2 = Vector2.ZERO
var _total_yaw: float = 0
var _total_pitch: float = 0
var _easeback_tween: Tween
var _looking: bool

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        _mouse_offset = (event as InputEventMouseMotion).relative

    if event is InputEventMouseButton:
        var mouse_btn_event: InputEventMouseButton = event
        if event.button_index == MOUSE_BUTTON_RIGHT:
            if event.pressed:
                Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
                _looking = true
            elif event.is_released():
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
                _looking = false
                if _total_pitch != 0 || _total_yaw != 0:
                    _easeback()


func _easeback() -> void:
    if _easeback_tween != null && _easeback_tween.is_running():
        return

    _easeback_tween = create_tween()

    _easeback_tween.tween_method(
        _set_rotation,
        Vector2(_total_yaw, _total_pitch),
        Vector2.ZERO,
        _easeback_duration,
    )

func _process(delta: float) -> void:
    if !_looking:
        return

    _mouse_offset *= sensitivity

    _set_rotation(Vector2(
        _total_yaw + _mouse_offset.x,
        _total_pitch + _mouse_offset.y
    ))

    _mouse_offset = Vector2.ZERO

func _set_rotation(orientation: Vector2) -> void:
    _total_yaw = clampf(orientation.x, -_yaw_limit_degrees, _yaw_limit_degrees)
    _total_pitch = clampf(orientation.y, -_pitch_limit_degrees, _pitch_limit_degrees)

    basis = Basis()
    rotate_object_local(Vector3.UP, deg_to_rad(-_total_yaw))
    rotate_object_local(Vector3.LEFT, deg_to_rad(-_total_pitch if invert_y else _total_pitch))
