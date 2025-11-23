extends Resource
class_name MovementPlannerSettings

@export var translation_duration: float = 0.4
var translation_duration_scaled: float:
    get():
        return translation_duration / animation_speed

@export var fall_duration: float = 0.25
var fall_duration_scaled: float:
    get():
        return fall_duration / animation_speed

@export var corner_translation_duration: float = 0.5
var corner_translation_duration_scaled:
    get():
        return corner_translation_duration / animation_speed

@export var turn_duration: float = 0.3
var turn_duration_scaled:
    get():
        return turn_duration / animation_speed

@export var animation_speed: float = 1.0
var animation_speed_scaled:
    get():
        return animation_speed / animation_speed
