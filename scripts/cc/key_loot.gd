extends GridEvent
class_name KeyLoot

@export var key_id: String = "key"

@export var anim: AnimationPlayer
@export var idle: String = "Idle"
@export var gain: String = "Gain"
@export var delay_gain: float = 1

func _ready() -> void:
    anim.play(idle)

func should_trigger(
    entity: GridEntity,
    from: GridNode,
    from_side: CardinalDirections.CardinalDirection,
    to_side: CardinalDirections.CardinalDirection,
) -> bool:
    return super.should_trigger(entity, from, from_side, to_side) && entity is GridPlayerCore

func trigger(entity: GridEntity, movement: Movement.MovementType) -> void:
    if !available():
        return

    super.trigger(entity, movement)

    print_debug("[Key Loot] Gaining key '%s'" % key_id)

    anim.play(gain)

    await get_tree().create_timer(delay_gain).timeout

    (entity as GridPlayerCore).key_ring.gain(key_id)
    visible = false
    print_debug("[Key Loot] Waited for %ss" % delay_gain)

func needs_saving() -> bool:
    return _triggered

func save_key() -> String:
    return "key-%s" % get_grid_node().coordinates

const _TRIGGERED_KEY: String = "triggered"

func collect_save_data() -> Dictionary:
    return {
        _TRIGGERED_KEY: _triggered,
    }

func load_save_data(data: Dictionary) -> void:
    _triggered = DictionaryUtils.safe_getb(data, _TRIGGERED_KEY, false, false)
