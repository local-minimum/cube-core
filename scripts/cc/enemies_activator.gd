extends GridEvent
class_name EnemiesActivator

@export var _enemy_activation_id: String

func trigger(entity: GridEntity, movement: Movement.MovementType) -> void:
    super.trigger(entity, movement)

    print_debug("[Enemies Activator %s] at %s activated" % [
        _enemy_activation_id,
        coordinates(),
    ])
    __SignalBus.on_activate_player_hunt.emit(_enemy_activation_id)
