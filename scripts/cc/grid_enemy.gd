extends GridEntity
class_name GridEnemy

@export var spawn_node: GridNode

func _enter_tree() -> void:
    if __SignalBus.on_move_end.connect(_handle_move_end) != OK:
        push_error("Failed to connect move end")

func _ready() -> void:
    if spawn_node != null:
        set_grid_node(spawn_node)

    super._ready()

func _handle_move_end(entity: GridEntity) -> void:
    if entity is not GridPlayerCore:
        return

    var direction: Vector3i = VectorUtils.primary_direction(entity.coordinates() - coordinates())

    var movement: Movement.MovementType = Movement.from_directions(
        CardinalDirections.vector_to_direction(direction),
        look_direction,
        down,
    )

    print_debug("[Grid Enemy] Want to go direction %s from %s to %s which results in movement %s on mode %s" % [
        CardinalDirections.name(CardinalDirections.vector_to_direction(direction)),
        coordinates(),
        entity.coordinates(),
        Movement.name(movement),
        transportation_mode.get_flag_names(),
    ])
    force_movement(movement)
