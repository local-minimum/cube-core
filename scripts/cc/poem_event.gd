extends GridEvent
class_name PoemEvent

static var _played_poems: Array[String]

@export var poem: String
@export var poem_response: String
@export var enqueue_if_busy: bool = true
@export var silence_others: bool = false
@export var response_delay: float = 0.3


func trigger(entity: GridEntity, movement: Movement.MovementType) -> void:
    if !available() || _played_poems.has(poem):
        return

    super.trigger(entity, movement)
    _played_poems.append(poem)
    __AudioHub.play_dialogue(
        poem,
        func() -> void: __AudioHub.play_dialogue(poem_response, false, false, response_delay),
        enqueue_if_busy,
        silence_others,
    )
