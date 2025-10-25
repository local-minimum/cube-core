extends GridEntity
class_name GridEnemy

@export var move_on_turn: bool = false
@export var spawn_node: GridNode

func _enter_tree() -> void:
    if __SignalBus.on_move_end.connect(_handle_move_end) != OK:
        push_error("Failed to connect move end")
    if __SignalBus.on_move_start.connect(_handle_move_start) != OK:
        push_error("Failed to connect move start")
    if __SignalBus.on_change_node.connect(_handle_change_node) != OK:
        push_error("Failed to connect change node")

func _ready() -> void:
    if spawn_node != null:
        set_grid_node(spawn_node)

    super._ready()

var _may_move: bool

func _handle_change_node(feature: GridNodeFeature) -> void:
    if feature is not GridPlayerCore:
        return

    _may_move = true
    print_debug("[Grid Enemy] Detect player change node, may move self!")

func _handle_move_start(entity: GridEntity, _from: Vector3i, _direction: CardinalDirections.CardinalDirection) -> void:
    if entity is not GridPlayerCore:
        return

    # _may_move = move_on_turn
    print_debug("[Grid Enemy] Detect player move start, may move self %s" % _may_move)

func _get_wanted_direct(entity: GridEntity) -> CardinalDirections.CardinalDirection:
    var delta: Vector3i = entity.coordinates() - coordinates()

    print_debug("[Grid Enemy] Direction vector %s" % delta)
    if delta == Vector3i.ZERO:
        return CardinalDirections.CardinalDirection.NONE

    var direction: CardinalDirections.CardinalDirection = CardinalDirections.principal_direction(delta)
    var node: GridNode = get_grid_node()
    if !node.may_exit(self, direction, true, false):
        print_debug("[Grid Enemy] may not go %s checking secondary" % [CardinalDirections.name(direction)])

        var secondary: Array[CardinalDirections.CardinalDirection] = CardinalDirections.secondary_directions(delta)
        secondary.shuffle()
        for direction_2: CardinalDirections.CardinalDirection in secondary:
            if node.may_exit(self, direction_2, true, false):
                print_debug("[Grid Enemy] using seconday direction %s " % [CardinalDirections.name(direction_2)])
                return direction_2


        var fallback: Array[CardinalDirections.CardinalDirection] = CardinalDirections.ALL_DIRECTIONS.duplicate()
        fallback.shuffle()
        for direction_3: CardinalDirections.CardinalDirection in fallback:
            if node.may_exit(self, direction_3, true, false):
                print_debug("[Grid Enemy] using random direction %s " % [CardinalDirections.name(direction_3)])
                return direction_3

    print_debug("[Grid Enemy] using principal direction %s " % [CardinalDirections.name(direction)])
    return direction

func _handle_move_end(entity: GridEntity) -> void:
    if entity is not GridPlayerCore || !_may_move:
        return

    var direction: CardinalDirections.CardinalDirection = _get_wanted_direct(entity)

    if direction == CardinalDirections.CardinalDirection.NONE:
        return

    var movement: Movement.MovementType = Movement.from_directions(
        direction,
        look_direction,
        down,
    )

    print_debug("[Grid Enemy] Want to go direction %s from %s to %s which results in movement %s on mode %s" % [
        CardinalDirections.name(direction),
        coordinates(),
        entity.coordinates(),
        Movement.name(movement),
        transportation_mode.get_flag_names(),
    ])
    force_movement(movement)
    _may_move = false
