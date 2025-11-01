extends GridEvent
class_name CatHelpSubZone

@export var subzone: String

func trigger(entity: GridEntity, movement: Movement.MovementType) -> void:
    super.trigger(entity, movement)

    __SignalBus.on_cat_subzone_entry.emit(subzone)
