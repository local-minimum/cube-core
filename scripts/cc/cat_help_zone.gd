extends GridEvent
class_name CatHelpZone

@export var entered: bool
@export var zone: String

func trigger(entity: GridEntity, movement: Movement.MovementType) -> void:
    super.trigger(entity, movement)

    if entered:
        __SignalBus.on_cat_zone_entry.emit(zone)
    else:
        __SignalBus.on_cat_zone_exit.emit(zone)
