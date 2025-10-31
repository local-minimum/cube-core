extends GridEntity
class_name GridEnemy

@export var hunting_activation_id: String
@export var move_on_turn: bool = false
@export var spawn_node: GridNode
@export var _lives: int = 3
var lives: int:
    get():
        return _lives

@export var _mushrooms: Array[Node3D]
@export var particles: Array[GPUParticles3D]
@export var self_center: Node3D
@export var gives_key: bool
@export var hurt_on_fight_start: int = 3
@export var hurt_on_guess_wrong: int = 15

var hunting: bool

func _enter_tree() -> void:
    if __SignalBus.on_move_end.connect(_handle_move_end) != OK:
        push_error("Failed to connect move end")
    if __SignalBus.on_move_start.connect(_handle_move_start) != OK:
        push_error("Failed to connect move start")
    if __SignalBus.on_change_node.connect(_handle_change_node) != OK:
        push_error("Failed to connect change node")
    if __SignalBus.on_activate_player_hunt.connect(_handle_activate_hunting) != OK:
        push_error("Failed to connect activate player hunt")

func _ready() -> void:
    if spawn_node != null:
        set_grid_node(spawn_node)
        sync_position()

    super._ready()

var _may_move: bool

func _handle_activate_hunting(id: String) -> void:
    if id == hunting_activation_id:
        hunting = true

func _handle_change_node(feature: GridNodeFeature) -> void:
    if feature is not GridPlayerCore:
        return

    _may_move = true
    print_debug("[Grid Enemy] Detect player change node, may move self!")

func _handle_move_start(entity: GridEntity, _from: Vector3i, _direction: CardinalDirections.CardinalDirection) -> void:
    if entity is not GridPlayerCore:
        return

    # _may_move = move_on_turn
    # print_debug("[Grid Enemy] Detect player move start, may move self %s" % _may_move)

func _get_occupied_by_enemy_filter() -> Callable:
    return func (direction: CardinalDirections.CardinalDirection) -> bool:
        var target: Vector3i = CardinalDirections.translate(coordinates(), direction)

        return get_level().grid_entities.any(
            func (entity: GridEntity) -> bool:
                if entity is not GridEnemy:
                    return false

                return target == entity.coordinates()
        )

func _get_wanted_direct(entity: GridEntity) -> CardinalDirections.CardinalDirection:
    var delta: Vector3i = entity.coordinates() - coordinates()


    print_debug("[Grid Enemy] Direction vector %s" % delta)
    if delta == Vector3i.ZERO:
        return CardinalDirections.CardinalDirection.NONE

    var direction: CardinalDirections.CardinalDirection = CardinalDirections.principal_direction(delta)
    var node: GridNode = get_grid_node()
    var occupied: Callable = _get_occupied_by_enemy_filter()

    if !node.may_exit(self, direction, true, false) || occupied.call(direction):
        print_debug("[Grid Enemy] may not go %s checking secondary" % [CardinalDirections.name(direction)])

        var secondary: Array[CardinalDirections.CardinalDirection] = CardinalDirections.secondary_directions(delta)
        secondary.shuffle()
        for direction_2: CardinalDirections.CardinalDirection in secondary:
            if node.may_exit(self, direction_2, true, false) && !occupied.call(direction_2):
                print_debug("[Grid Enemy] using seconday direction %s " % [CardinalDirections.name(direction_2)])
                return direction_2


        var fallback: Array[CardinalDirections.CardinalDirection] = CardinalDirections.ALL_DIRECTIONS.duplicate()
        fallback.shuffle()
        for direction_3: CardinalDirections.CardinalDirection in fallback:
            if node.may_exit(self, direction_3, true, false) && occupied.call(direction):
                print_debug("[Grid Enemy] using random direction %s " % [CardinalDirections.name(direction_3)])
                return direction_3

        return CardinalDirections.CardinalDirection.NONE

    print_debug("[Grid Enemy] using principal direction %s " % [CardinalDirections.name(direction)])
    return direction

func _handle_move_end(entity: GridEntity) -> void:
    if _killed || get_grid_node() == null:
        return

    var player: GridPlayer
    if entity == self:
        player = get_level().player
        if entity.coordinates() == player.coordinates():
            print_debug("[Grid Enemy] play game!")
            player.hurt(hurt_on_fight_start)
            __SignalBus.on_play_exclude_word_game.emit(self, player)
        return

    if entity is not GridPlayer:
        return

    player = entity
    # print_debug("[Grid Enemy] %s vs %s" % [player.coordinates(), coordinates()])

    if player.coordinates() == coordinates():
        print_debug("[Grid Enemy] play game voluntarily!")
        player.hurt(hurt_on_fight_start)
        __SignalBus.on_play_exclude_word_game.emit(self, player)
        return

    # TODO: We should still move when not hunting probably... but that's for later
    if !_may_move || !hunting:
        return

    var direction: CardinalDirections.CardinalDirection = _get_wanted_direct(player)

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
        player.coordinates(),
        Movement.name(movement),
        transportation_mode.get_flag_names(),
    ])
    force_movement(movement)
    _may_move = false

func hurt() -> void:
    _lives -= 1
    for shroom: Node3D in _mushrooms.slice(_lives):
        shroom.visible = false

var _killed: bool = false
func kill() -> void:
    if _killed:
        return

    _killed = true
    _lives = 0
    for particle: GPUParticles3D in particles:
        particle.emitting = false

    if gives_key:
        __SignalBus.on_award_key.emit(self_center.global_position)

    await get_tree().create_timer(5).timeout

    get_level().grid_entities.erase(self)
    queue_free()

func is_alive() -> bool:
    return _lives > 0
