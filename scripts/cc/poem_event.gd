extends GridEvent
class_name PoemEvent

static var _played_poems: Array[String]

@export var poem: String
@export var poem_response: String
@export var enqueue_if_busy: bool = true
@export var silence_others: bool = false


func trigger(entity: GridEntity, movement: Movement.MovementType) -> void:
    if !available() || _played_poems.has(poem):
        return

    super.trigger(entity, movement)
    _played_poems.append(poem)
    __AudioHub.play_dialogue(poem, _play_response, enqueue_if_busy, silence_others)

func _play_response() -> void:
    if !poem_response.is_empty():
        await get_tree().create_timer(0.3).timeout
        __AudioHub.play_dialogue(poem_response)
