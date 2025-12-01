extends GridEvent
class_name Catapult

enum Phase { NONE, CENTERING, ORIENTING, FLYING, CRASHING, RELEASE }

## Grabbing the entity will orient it. And usually that means looking in the direction we are flying
@export var _orient_entity: bool = false
## If we prefer to orient down with gravity, then we might not look where we are flying
@export var _prefer_orient_down_with_gravity: bool = true

## The direction we are looking at
@export var _crashes_forward: bool = false
@export var _crashes_entity_down: bool = false
@export var _crash_direction: CardinalDirections.CardinalDirection = CardinalDirections.CardinalDirection.NONE

enum CrashAnchorMode { DONT, GRAVITY, ENTITY_DOWN }
@export var _crash_anchor_direction: CrashAnchorMode = CrashAnchorMode.GRAVITY
@export var _manual_crash_duration: float = 0.3

@export var _activation_sound: String


static var _managed_entities: Dictionary[GridEntity, Catapult]
static var _entity_phases: Dictionary[GridEntity, Phase]
static var _prev_coordinates: Dictionary[GridEntity, Vector3i]
static var _entry_look_direction: Dictionary[GridEntity, CardinalDirections.CardinalDirection]

var field_direction: CardinalDirections.CardinalDirection:
    get():
        return CardinalDirections.invert(_trigger_sides[0])

func _ready() -> void:
    super._ready()

    if __SignalBus.on_move_start.connect(_handle_move_start) != OK:
        push_error("Failed to connect move start")

    if __SignalBus.on_move_end.connect(_handle_move_end) != OK:
        push_error("Failed to connect move end")

func _exit_tree() -> void:
    for entity: GridEntity in _managed_entities:
        if _managed_entities[entity] == self:
            _release_entity(entity, true)

static func release_from_catapult(entity: GridEntity, immidiate_remove_cinematic: bool = false, remove_cinematic: bool = true) -> Catapult:
    var catapult: Catapult = _managed_entities.get(entity)
    if catapult == null:
        return null

    catapult._release_entity(entity, immidiate_remove_cinematic, remove_cinematic)

    return catapult

func _animate_manual_crash(
    entity: GridEntity,
    crash_anchor: GridAnchor,
) -> void:
    print_debug("[Catapult %s] Manually crashing %s to anchor %s of %s" % [coordinates(), entity.name, CardinalDirections.name(crash_anchor.direction), crash_anchor.coordinates])
    var tween: Tween = create_tween()

    var gravity: CardinalDirections.CardinalDirection = get_level().gravity
    var new_down: CardinalDirections.CardinalDirection = crash_anchor.calculate_anchor_down(gravity, entity.down)
    var new_look: CardinalDirections.CardinalDirection = entity.look_direction if !CardinalDirections.is_parallell(new_down, entity.look_direction) else _entry_look_direction.get(entity, entity.look_direction)

    if CardinalDirections.is_parallell(new_down, new_look):
        print_debug("[Catapult %s] %s adjusting crash look direction because parallel to crash down" % [coordinates(), entity.name])
        new_look = CardinalDirections.orthogonals(new_down).pick_random()

    @warning_ignore_start("return_value_discarded")
    tween.tween_property(
        entity,
        "global_position",
        crash_anchor.global_position,
        _manual_crash_duration,
    )
    @warning_ignore_restore("return_value_discarded")

    if entity.down != new_down || entity.look_direction != new_look:
        var update_rotation: Callable = QuaternionUtils.create_tween_rotation_method(entity)
        var look_target: Quaternion = CardinalDirections.direction_to_rotation(CardinalDirections.invert(new_down), new_look)
        var look_from: Quaternion = CardinalDirections.direction_to_rotation(CardinalDirections.invert(entity.down), entity.look_direction)
        print_debug("[Catapult %s] %s adjusting rotations down %s -> %s and look %s -> %s" % [
            coordinates(),
            entity.name,
            CardinalDirections.name(entity.down),
            CardinalDirections.name(new_down),
            CardinalDirections.name(entity.look_direction),
            CardinalDirections.name(new_look),
        ])

        print_debug("[Catapult %s] Actual rotation %s vs assumed %s" % [
            coordinates(),
            entity.global_basis.get_rotation_quaternion().normalized(),
            look_from,
        ])

        @warning_ignore_start("return_value_discarded")
        tween.parallel().tween_method(
            update_rotation,
            look_from,
            look_target,
            _manual_crash_duration,
        )
        @warning_ignore_restore("return_value_discarded")

        entity.down = new_down
        entity.look_direction = new_look

    _entity_phases[entity] = Phase.RELEASE

    entity.transportation_mode.adopt(crash_anchor.required_transportation_mode)
    entity.set_grid_anchor(crash_anchor)
    entity.stand_up()

    tween.finished.connect(func () -> void:
        _release_entity(entity)
        entity.sync_position()
        GridEntity.orient(entity)
    )


func _crash_entity(entity: GridEntity) -> void:
    var out: Array = []
    match _force_crash_movement_or_get_crash_anchor(entity, out):
        CrashResult.MOVEMENT:
            # This is handled like a regular movement we release from cinematic at the end of that movement
            pass

        CrashResult.MANUAL:
            var crash_anchor: GridAnchor = out[0]
            _animate_manual_crash(entity, crash_anchor)

        CrashResult.FAIL:
            if entity.transportation_abilities.has_flag(TransportationMode.FLYING):
                print_debug("[Catapult %s] Crashing only sets mode flying to %s at %s" % [coordinates(), entity.name, entity.coordinates()])
                entity.transportation_mode.mode = TransportationMode.FLYING
            elif entity.transportation_abilities.has_flag(TransportationMode.FALLING):
                entity.stand_up()
                print_debug("[Catapult %s] Crashing only sets mode falling to %s at %s" % [coordinates(), entity.name, entity.coordinates()])
                entity.transportation_mode.mode = TransportationMode.FALLING
            else:
                push_error("[Catapult %s] Crashing only clears all transportation modes of %s at %s" % [coordinates(), entity.name, entity.coordinates()])
                entity.transportation_mode.mode = TransportationMode.NONE


func _release_entity(entity: GridEntity, immediate_remove_cinematic: bool = false, remove_cinematic: bool = true) -> void:
    if !_managed_entities.erase(entity):
        push_warning("Could not remove entity '%s' as held though it should have been there" % entity.name)

    if !_entity_phases.erase(entity):
        push_warning("Could not remove entity '%s' from phase tracking" % entity.name)

    if !_prev_coordinates.erase(entity):
        push_warning("Could not clear entity '%s' previous coordinates" % entity.name)

    if !_entry_look_direction.erase(entity):
        push_warning("Could not clear entity '%s' entry look direction" % entity.name)

    entity.transportation_ability_override = null

    if !remove_cinematic:
        print_debug("[Catapult %s] Keeping cinematic for %s" % [coordinates(), entity.name])
        return

    if immediate_remove_cinematic:
        _cleanup_entity(entity)
    else:
        print_debug("[Catapult %s] %s delayed clean up" % [coordinates(), entity.name])
        _cleanup_entity.call_deferred(entity)

func _get_neighbour_crash_anchor(
    entity: GridEntity,
    node: GridNode,
    neighbour_direction: CardinalDirections.CardinalDirection,
) -> GridAnchor:
    var neighbour: GridNode = node.neighbour(neighbour_direction)
    if neighbour != null:
        var anchor_direction: CardinalDirections.CardinalDirection = entity.down
        match _crash_anchor_direction:
            CrashAnchorMode.GRAVITY:
                anchor_direction = get_level().gravity

        var land_anchor: GridAnchor = neighbour.get_grid_anchor(anchor_direction)
        if land_anchor != null && land_anchor.can_anchor(entity):
            return land_anchor
    return null

enum CrashResult { MOVEMENT, MANUAL, FAIL }

func _handle_crash_move_or_return_anchor(
    entity: GridEntity,
    crash_direction: CardinalDirections.CardinalDirection,
    out: Array
) -> CrashResult:
    var node: GridNode = entity.get_grid_node()
    var can_be_in_the_air: bool = entity.transportation_abilities.can_be_in_the_air()
    out.clear()

    if node.may_exit(entity, crash_direction):
        var movement: Movement.MovementType = Movement.from_directions(crash_direction, entity.look_direction, entity.down)
        if can_be_in_the_air && _crash_anchor_direction == CrashAnchorMode.DONT:
            if entity.force_movement(movement):
                print_debug("[Catapult %s] %s may be in the air so crashes %s from %s with regular movement %s" % [
                    coordinates(),
                    entity.name,
                    CardinalDirections.name(crash_direction),
                    node.coordinates,
                    Movement.name(movement),
                ])
                return CrashResult.MOVEMENT
            else:
                push_error("[Catapult %s] %s failed to crash %s from %s, %s movement refused" % [
                    coordinates(),
                    entity.name,
                    CardinalDirections.name(crash_direction),
                    node.coordinates,
                    Movement.name(movement),
                ])
                return CrashResult.FAIL
        else:
            var crash_anchor: GridAnchor = _get_neighbour_crash_anchor(entity, node, crash_direction)
            if crash_anchor != null:
                out.append(crash_anchor)
                out.append(crash_direction)
                return CrashResult.MANUAL

            return CrashResult.FAIL


    if node.has_side(crash_direction) == GridNode.NodeSideState.SOLID:
        var land_anchor: GridAnchor = node.get_grid_anchor(crash_direction)
        if land_anchor != null && land_anchor.can_anchor(entity):
            print_debug("[Catapult %s] %s crashes into side %s from %s, crash anchor direction ignored" % [
                coordinates(),
                entity.name,
                CardinalDirections.name(crash_direction),
                node.coordinates,
            ])
            out.append(land_anchor)
            out.append(crash_direction)
            return CrashResult.MANUAL

    push_warning("[Catapult %s] %s cannot crash in direction %s from %s." % [
        coordinates(),
        entity.name,
        CardinalDirections.name(crash_direction),
        node.coordinates,
    ])

    return CrashResult.FAIL

## This either forces a movement
func _force_crash_movement_or_get_crash_anchor(entity: GridEntity, out: Array) -> CrashResult:
    # We need to clear our overrides here because else planner or we will get confused
    entity.transportation_ability_override = null

    print_debug("[Catapult %s] %s getting crash anchors" % [coordinates(), entity.name])

    if _crashes_forward:
        print_debug("[Catapult %s] Crashing forward" % coordinates())
        return _handle_crash_move_or_return_anchor(entity, entity.look_direction, out)

    if _crashes_entity_down:
        print_debug("[Catapult %s] Crashing entity down" % coordinates())
        return _handle_crash_move_or_return_anchor(entity, entity.down, out)

    if _crash_direction != CardinalDirections.CardinalDirection.NONE:
        print_debug("[Catapult %s] Crashing pre-defined direction" % coordinates())
        return _handle_crash_move_or_return_anchor(entity, _crash_direction, out)

    print_debug("[Catapult %s] No Crashing" % coordinates())
    out.clear()
    return CrashResult.FAIL

func _cleanup_entity(entity: GridEntity) -> void:
        entity.remove_cinematic_cause(self)
        entity.clear_queue()
        print_debug("[Catapult %s] Cleaned up %s, transportation %s, moving %s, cinematic %s" % [
            coordinates(),
            entity.name,
            entity.transportation_mode.get_flag_names(),
            entity.is_moving(),
            entity.cinematic,
        ])

func _is_same_coordinates(entity: GridEntity) -> bool:
    if _prev_coordinates.has(entity):
        return _prev_coordinates[entity] == entity.coordinates()
    return false

func _handle_move_start(entity: GridEntity, from: Vector3i, _direction: CardinalDirections.CardinalDirection) -> void:
    if _managed_entities.get(entity) == self:
        print_debug("[Catapult %s] %s planning new move from %s (%s), recording coordinates" % [
            coordinates(),
            entity.name,
            from,
            entity.coordinates(),
        ])
        _prev_coordinates[entity] = from

func _handle_move_end(entity: GridEntity) -> void:
    if _managed_entities.get(entity) != self:
        return

    match _entity_phases.get(entity, Phase.NONE):
        Phase.NONE:
            print_debug("[Catapult %s] %s initializing" % [coordinates(), entity.name])
            if entity.force_movement(Movement.MovementType.CENTER):
                _entity_phases[entity] = Phase.CENTERING

        Phase.CENTERING:
            print_debug("[Catapult %s] %s centered" % [coordinates(), entity.name])
            entity.duck()

            if _orient_entity:
                var fly_direction: CardinalDirections.CardinalDirection = field_direction
                var gravity: CardinalDirections.CardinalDirection = get_level().gravity
                var new_look: CardinalDirections.CardinalDirection = fly_direction
                var new_down: CardinalDirections.CardinalDirection = entity.look_direction if CardinalDirections.is_parallell(new_look, entity.look_direction) else entity.down

                if _prefer_orient_down_with_gravity:
                    new_down = gravity

                if CardinalDirections.is_parallell(new_down, new_look):
                    if !CardinalDirections.is_parallell(new_down, fly_direction):
                        new_look = fly_direction
                    elif !CardinalDirections.is_parallell(new_down, entity.look_direction):
                        new_look = entity.look_direction
                    else:
                        new_look = CardinalDirections.yaw_cw(entity.look_direction, entity.down)[0]

                if new_down != entity.down || new_look != entity.look_direction:

                    print_debug("[Catapult %s] orienting look %s and down %s" % [coordinates(), CardinalDirections.name(new_look), CardinalDirections.name(new_down)])
                    var look_target: Quaternion = CardinalDirections.direction_to_rotation(CardinalDirections.invert(new_down), new_look)
                    var tween: Tween = create_tween()
                    var update_rotation: Callable = QuaternionUtils.create_tween_rotation_method(entity)
                    @warning_ignore_start("return_value_discarded")
                    tween.tween_method(
                        update_rotation,
                        entity.global_transform.basis.get_rotation_quaternion(),
                        look_target,
                        0.2
                    )
                    @warning_ignore_restore("return_value_discarded")

                    entity.down = new_down
                    entity.look_direction = new_look

                    if tween.finished.connect(
                        func () -> void:
                            GridEntity.orient(entity)
                            print_debug("[Catapult %s] Oriented %s to look %s, %s down" % [
                                coordinates(),
                                entity.name,
                                CardinalDirections.name(entity.look_direction),
                                CardinalDirections.name(entity.down),
                            ])

                    ) != OK:
                        push_error("Failed to connect rotation done")

                    tween.play()

            if !_fly(entity):
                _entity_phases[entity] = Phase.CRASHING
            else:
                _entity_phases[entity] = Phase.FLYING

        Phase.FLYING:
            print_debug("[Catapult %s] %s flying from anchor %s with look %s and down %s; was at %s is %s" % [
                coordinates(),
                entity.name,
                CardinalDirections.name(entity.get_grid_anchor_direction()),
                CardinalDirections.name(entity.look_direction),
                CardinalDirections.name(entity.down),
                _prev_coordinates.get(entity, Vector3i.ZERO),
                entity.coordinates(),
            ])

            if _is_same_coordinates(entity):
                _crash_entity(entity)
                _entity_phases[entity] = Phase.RELEASE
            else:
                if !_fly(entity):
                    print_debug("[Catapult %s] %s hit something %s" % [coordinates(), entity.name, CardinalDirections.name(entity.look_direction)])
                    _crash_entity(entity)
                    _entity_phases[entity] = Phase.RELEASE

        Phase.CRASHING:
            _crash_entity(entity)
            _entity_phases[entity] = Phase.RELEASE

        Phase.RELEASE:
            _release_entity(entity)

func _fly(entity: GridEntity) -> bool:
    var direction: CardinalDirections.CardinalDirection = field_direction
    var movement: Movement.MovementType = Movement.from_directions(
        direction,
        entity.look_direction,
        entity.down,
    )

    if movement == Movement.MovementType.NONE:
        _release_entity(entity)
        _entity_phases[entity] = Phase.RELEASE
        return false

    print_debug("[Catapult %s] Fly %s looking %s with down %s - move %s" % [
        coordinates(),
        entity.name,
        CardinalDirections.name(entity.look_direction),
        CardinalDirections.name(entity.down),
        Movement.name(movement)
    ])
    return entity.force_movement(movement)

func trigger(entity: GridEntity, _movement: Movement.MovementType) -> void:
    _triggered = true

    if !_should_be_managed(entity):
        return

    print_debug("[Catapult %s] Grabbing %s" % [coordinates(), entity.name])

    entity.cause_cinematic(self)

    if !_managed_entities.has(entity):
        _claim_entity(entity)
        if !_activation_sound.is_empty():
            __AudioHub.play_sfx(_activation_sound)
    else:
        _claim_entity.call_deferred(entity)

func _claim_entity(entity: GridEntity) -> void:
    if _managed_entities.has(entity):
        entity.remove_cinematic_cause(_managed_entities[entity])

    entity.transportation_ability_override = TransportationMode.new([TransportationMode.FLYING])

    _managed_entities[entity] = self
    _entity_phases[entity] = Phase.NONE if !entity.transportation_mode.has_flag(TransportationMode.FLYING) else Phase.CENTERING
    _entry_look_direction[entity] = entity.look_direction

    entity.transportation_mode.mode = TransportationMode.FLYING

    print_debug("[Catapult %s] %s is now %s with abilities %s" % [
        coordinates(),
        entity.name,
        entity.transportation_mode.humanize(),
        entity.transportation_abilities.humanize(),
    ])

func _should_be_managed(entity: GridEntity) -> bool:
    if _managed_entities.get(entity) == self:
        return false

    return activates_for(entity)

func _tick() -> void:
    pass
