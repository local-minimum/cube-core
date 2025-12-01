extends GridNodeFeature
class_name GridEntity


const _LOOK_DIRECTION_KEY: String = "look_direction"
const _DOWN_KEY: String = "down"
const _ANCHOR_KEY: String = "anchor"
const _COORDINATES_KEY: String = "coordinates"

var _old_look_direction: CardinalDirections.CardinalDirection
var _old_down: CardinalDirections.CardinalDirection
var _emit_orientation: bool

## If cinematic, AI or player shouldn't be allowed to do inputs
var _cinematics: Array[Node]
var cinematic: bool:
    get():
        return !_cinematics.is_empty()

    set (value):
        if true:
            cause_cinematic(self)
        else:
            remove_cinematic_cause(self)
        push_warning("%s is cinematic %s due to unspecific cause" % [name, cinematic])

func cause_cinematic(cause: Node) -> void:
    if cause == null || _cinematics.has(cause):
        return
    _cinematics.append(cause)
    if _cinematics.size() == 1:
        __SignalBus.on_cinematic.emit(self, true)
        clear_queue()

func remove_cinematic_cause(cause: Node) -> void:
    if _cinematics.is_empty():
        return

    _cinematics.erase(cause)
    if _cinematics.is_empty():
        __SignalBus.on_cinematic.emit(self, false)


@export var look_direction: CardinalDirections.CardinalDirection = CardinalDirections.CardinalDirection.NORTH:
    set(value):
        _old_look_direction = look_direction
        _emit_orientation = true
        look_direction = value
        await get_tree().physics_frame
        delay_emit()

@export var down: CardinalDirections.CardinalDirection = CardinalDirections.CardinalDirection.DOWN:
    set(value):
        _old_down = down
        _emit_orientation = true
        down = value
        await get_tree().physics_frame
        delay_emit()

@export var transportation_mode: TransportationMode
var transportation_ability_override: TransportationMode
@export var transportation_abilities: TransportationMode:
    get():
        if transportation_ability_override != null:
            return transportation_ability_override
        return transportation_abilities

@export var can_jump_off_floor: bool:
    get():
        return can_jump_off_floor || can_jump_off_all

@export var can_jump_off_all: bool
@export var orient_with_gravity_in_air: bool = true

@export var executor: MovementExecutor

@export var concurrent_turns: bool

@export var queue_moves: bool = true

@export var _spawn_node: GridNode
@export var _spawn_anchor_direction: CardinalDirections.CardinalDirection = CardinalDirections.CardinalDirection.NONE

var _active_movement: Movement.MovementType = Movement.MovementType.NONE
var _concurrent_movement: Movement.MovementType = Movement.MovementType.NONE
var _next_movement: Movement.MovementType = Movement.MovementType.NONE
var _next_next_movement: Movement.MovementType = Movement.MovementType.NONE

func _ready() -> void:
    sync_spawn()
    get_level().grid_entities.append(self)

func sync_spawn() -> void:
    if _spawn_node != null:
        var spawn_anchor: GridAnchor = _spawn_node.get_grid_anchor(_spawn_anchor_direction)
        update_entity_anchorage(_spawn_node, spawn_anchor)
        sync_position()

    orient(self)

func load_look_direction_and_down(load_look: CardinalDirections.CardinalDirection, load_down: CardinalDirections.CardinalDirection) -> void:
    look_direction = load_look
    _old_look_direction = CardinalDirections.CardinalDirection.NONE

    down = load_down
    _old_down = CardinalDirections.CardinalDirection.NONE

func delay_emit() -> void:
    if CardinalDirections.is_parallell(down, look_direction):
        push_error("[Entity %s] Has colinear look (%s) and down (%s)" % [
            name,
            CardinalDirections.name(look_direction),
            CardinalDirections.name(down),
        ])

    if _emit_orientation:
        _emit_orientation = false
        __SignalBus.on_update_orientation.emit(self, _old_down, down, _old_look_direction, look_direction)
        _old_down = down
        _old_look_direction = look_direction

func is_moving() -> bool:
    return _active_movement != Movement.MovementType.NONE || _concurrent_movement != Movement.MovementType.NONE

var _block_concurrent: bool

func block_concurrent_movement() -> void:
    _block_concurrent = true

func remove_concurrent_movement_block() -> void:
    _block_concurrent = false

func execute_plan(plan: MovementPlannerBase.MovementPlan, priority: int, concurrent: bool) -> void:
    executor.execute_plan(plan, priority, concurrent)

func force_movement(movement: Movement.MovementType) -> bool:
    if _start_movement(movement, true):
        return attempt_movement(movement, false, true)
    return false

func _start_movement(movement: Movement.MovementType, force: bool) -> bool:
    if Movement.MovementType.NONE == movement || falling() && !force:
        push_warning("[Grid Entity %s] Movement refused: not accepting movements" % name)
        return false

    if _active_movement == Movement.MovementType.NONE || force:
        _active_movement = movement
        # print_debug("Movement %s accepted as primary" % [Movement.name(movement)])
    elif concurrent_turns && !_block_concurrent && Movement.is_turn(movement) && !Movement.is_turn(_active_movement):
        # print_debug("Movement %s accepted as concurrent" % [Movement.name(movement)])
        _concurrent_movement = movement
    else:
        # print_debug("Movement refused: busy")
        return false

    return true

func end_movement(movement: Movement.MovementType, start_next_from_queue: bool = true, force_emit: bool = false) -> void:
    if _active_movement == movement:
        _active_movement = _concurrent_movement
        _concurrent_movement = Movement.MovementType.NONE
    elif _concurrent_movement == movement:
        _concurrent_movement = Movement.MovementType.NONE
    else:
        if force_emit:
            __SignalBus.on_move_end.emit(self)
        elif !cinematic:
            push_warning("[Grid Entity %s] %s was not an active movement (%s / %s)" % [
                name,
                Movement.name(movement),
                Movement.name(_active_movement),
                Movement.name(_concurrent_movement),
            ])
        return

    print_debug("[Grid Entity %s] %s ended, active are %s / %s" % [
        name,
        Movement.name(movement),
        Movement.name(_active_movement),
        Movement.name(_concurrent_movement),
    ])

    if movement != Movement.MovementType.NONE || force_emit:
        # print_debug("[Grid Entity %s] Emitting end move" % name)
        __SignalBus.on_move_end.emit(self)

    if start_next_from_queue:
        _attempt_movement_from_queue()

func _attempt_movement_from_queue() -> void:
    if !queue_moves:
        return

    if _next_movement != Movement.MovementType.NONE:
        if attempt_movement(_next_movement, false):
            _next_movement = _next_next_movement
            _next_next_movement = Movement.MovementType.NONE
        else:
            clear_queue()
            print_debug("Queued movement refused")

        # print_debug("Consumed queue, now %s / %s" % [
            # Movement.name(_active_movement),
            # Movement.name(_concurrent_movement),
        # ])

func falling() -> bool:
    return transportation_mode.mode == TransportationMode.FALLING

func duck() -> void:
    pass

func stand_up() -> void:
    pass

func attempt_movement(
    movement: Movement.MovementType,
    enqueue_if_occupied: bool = true,
    force: bool = false,
) -> bool:
    if get_level().paused:
        return false

    if movement == Movement.MovementType.NONE:
        push_error("A none movement cannot be performed")
        print_stack()
        return false

    print_debug("[Grid Entity %s] Attempt movement %s from %s" % [name, Movement.name(movement), coordinates()])

    if !_start_movement(movement, force):
        if enqueue_if_occupied && queue_moves:
            _enqeue_movement(movement)
            return true

        # print_debug("%s & %s are active" % [Movement.name(_active_movement), Movement.name(_concurrent_movement)])
        return false

    if force:
        clear_queue()

    __SignalBus.on_move_plan.emit(self, movement)
    return true

func _enqeue_movement(movement: Movement.MovementType) -> void:
    if _next_movement != Movement.MovementType.NONE:
        _next_next_movement = movement
        # print_debug("%s enqued as next next movement (%s next)" % [
            # Movement.name(movement),
            # Movement.name(_next_movement),
        # ])
        return

    _next_movement = movement
    # print_debug("%s enqued as next movement" % [
        # Movement.name(_next_movement),
    # ])

## Empties queued up moves
func clear_queue() -> void:
    _next_movement = Movement.MovementType.NONE
    _next_next_movement = Movement.MovementType.NONE

func update_entity_anchorage(new_node: GridNode, new_anchor: GridAnchor, deferred: bool = false) -> void:
    if new_anchor != null:
        set_grid_anchor(new_anchor, deferred)
        if transportation_abilities != null:
            transportation_mode.mode = transportation_abilities.intersection(new_anchor.required_transportation_mode)
    else:
        set_grid_node(new_node, deferred)
        if transportation_abilities != null:
            if cinematic || transportation_abilities.has_flag(TransportationMode.FLYING):
                transportation_mode.mode = TransportationMode.FLYING
            else:
                transportation_mode.mode = TransportationMode.FALLING

    print_debug("[Grid Entity %s] Now %s @ %s %s" % [name, transportation_mode.humanize() if transportation_mode != null else "static", new_node.name, CardinalDirections.name(new_anchor.direction) if new_anchor else "airbourne"])

func sync_position() -> void:
    if anchor != null:
        global_position = anchor.global_position
        return

    var node: GridNode = get_grid_node()
    if node != null:
        global_position = GridNode.get_center_pos(node, node.level)
        return

    push_error("%s doesn't have either a node or anchor set" % name)
    print_stack()


static func orient(entity: GridEntity) -> void:
    if entity.look_direction == CardinalDirections.CardinalDirection.NONE || entity.down == CardinalDirections.CardinalDirection.NONE:
        push_warning("Cannot orient %s looking %s and down %s" % [
            entity.name,
            CardinalDirections.name(entity.look_direction),
            CardinalDirections.name(entity.down)
        ])
        return

    entity.look_at(
        entity.global_position + Vector3(CardinalDirections.direction_to_vectori(entity.look_direction)),
        CardinalDirections.direction_to_vectori(CardinalDirections.invert(entity.down)),
    )

static func sync_entity_position(entity: GridEntity) -> void:
    if entity.anchor != null:
        entity.global_position = entity.anchor.global_position
        return

    var node: GridNode = entity.get_grid_node()
    if node != null:
        entity.global_position = GridNode.get_center_pos(node, node.level)
        return

    push_error("%s doesn't have either a node or anchor set" % entity.name)
    print_stack()

static func find_entity_parent(current: Node, inclusive: bool = true) ->  GridEntity:
    if inclusive && current is GridEntity:
        return current as GridEntity

    var parent: Node = current.get_parent()

    if parent == null:
        return null

    if parent is GridEntity:
        return parent as GridEntity

    return find_entity_parent(parent, false)
