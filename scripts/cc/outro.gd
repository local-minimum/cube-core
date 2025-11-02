extends GridEvent
class_name Outro

@export var initial_speed: float = 2.5
@export var duration: float = 10
@export var decay: float = 2.0
@export var censor_noise: String = "res://audio/sfx/noise_03.ogg"

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

    await get_tree().create_timer(24).timeout
    FaderUI.fade_in(FaderUI.FadeTarget.EXPLORATION_VIEW, null, 5)
    await get_tree().create_timer(1.9).timeout
    __SignalBus.on_roll_credits.emit()
    await get_tree().create_timer(4.0).timeout
    var alphabet: Array[String] = []
    alphabet.append_array(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ".split()))

    for letter: String in alphabet:
        if __GlobalGameState.lost_letters.contains(letter):
            alphabet.erase(letter)

    alphabet.shuffle()

    while !alphabet.is_empty():
        var letter: String = alphabet.pop_back()
        __GlobalGameState.lost_letters += letter
        if !censor_noise.is_empty():
            __AudioHub.play_sfx(censor_noise, randf_range(0.3, 0.5))
        await get_tree().create_timer(randf_range(2, 4)).timeout



func _process(delta: float) -> void:
    if _entity == null:
        return

    _animation_time += delta
    var progress: float = pow(max(lerpf(1, 0, _animation_time / duration), 0), decay)
    _entity.global_position += velocity * progress * delta
