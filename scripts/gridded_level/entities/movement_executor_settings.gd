extends Resource
class_name MovementExecutorSettings

@export var tank_movement: bool
@export var instant_step: bool
@export var ducking_in_the_air: bool = true
@export var refuse_distance_factor_lateral: float = 0.45
@export var refuse_distance_factor_forward: float = 0.55
@export var refuse_distance_factor_reverse: float = 0.1
@export var inner_corner_translation_fraction: float = 0.6
@export var airbourne_refuse_distance_factor: float = 0.5
