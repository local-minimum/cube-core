extends GridEvent
class_name Outro

@export var initial_speed: float = 2.5
@export var duration: float = 10
@export var decay: float = 2.0

var velocity: Vector3
var _entity: GridEntity
var _animation_time: float

func trigger(entity: GridEntity, movement: Movement.MovementType) -> void:
    super.trigger(entity, movement)

    _entity = entity
    var catapult: Catapult = Catapult.release_from_catapult(entity, false, false)
    if catapult == null:
        return

    velocity = CardinalDirections.direction_to_vector(catapult.field_direction) * initial_speed


func _process(delta: float) -> void:
    if _entity == null:
        return

    _animation_time += delta
    var progress: float = pow(max(lerpf(1, 0, _animation_time / duration), 0), decay)
    _entity.global_position += velocity * progress * delta
