extends GridEvent
class_name Catapult

enum Phase { NONE, CENTERING, ORIENTING, FLYING, CRASHING }

## Grabbing the entity will orient it. And usually that means looking in the direction we are flying
@export var _orient_entity: bool = false
## If we prefer to orient down with gravity, then we might not look where we are flying
@export var _prefer_orient_down_with_gravity: bool = true

# TODO: Crash forward seems problematic at times
# TODO: Crash relative down?

## The direction we are looking at
@export var _crashes_forward: bool = false
@export var _crashes_entity_down: bool = false
@export var _crash_direction: CardinalDirections.CardinalDirection = CardinalDirections.CardinalDirection.NONE

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

    if __SignalBus.on_move_end.connect(_handle_move_end) != OK:
        push_error("Failed to connect move end")

func _exit_tree() -> void:
    for entity: GridEntity in _managed_entities:
        if _managed_entities[entity] == self:
            _release_entity(entity, true)

static func release_from_catapult(entity: GridEntity, remove_cinematic: bool = false, crash_player: bool = false) -> Catapult:
    var catapult: Catapult = _managed_entities.get(entity)
    if catapult == null:
        return null


    catapult._release_entity(entity, remove_cinematic, crash_player)

    return catapult

func _release_entity(entity: GridEntity, immediate_uncinematic: bool = false, crash_player: bool = true) -> void:
    if !_managed_entities.erase(entity):
        push_warning("Could not remove entity '%s' as held though it should have been there" % entity.name)

    if !_entity_phases.erase(entity):
        push_warning("Could not remove entity '%s' from phase tracking" % entity.name)

    if !_prev_coordinates.erase(entity):
        push_warning("Could not clear entity '%s' previous coordinates" % entity.name)

    if !_entry_look_direction.erase(entity):
        push_warning("Could not clear entity '%s' entry look direction" % entity.name)

    if !crash_player:
        print_debug("[Catapult %s] Not crashing" % [coordinates()])
        return

    var crash_anchor: GridAnchor = _get_release_anchor(entity)

    if crash_anchor != null:
        entity.stand_up()
        print_debug("[Catapult %s] Attempting to anchor to %s" % [coordinates(), crash_anchor])
        # TODO: Animate this
        entity.set_grid_anchor(crash_anchor)
        entity.sync_position()
        if CardinalDirections.is_parallell(entity.look_direction, crash_anchor.direction):
            var options: Array[CardinalDirections.CardinalDirection] = CardinalDirections.orthogonals(crash_anchor.direction)
            options.shuffle()
            entity.look_direction = options[0]
        entity.down = crash_anchor.direction

        GridEntity.orient(entity)
        entity.transportation_mode.adopt(crash_anchor.required_transportation_mode)
    elif entity.transportation_abilities.has_flag(TransportationMode.FLYING):
        print_debug("[Catapult %s] Crashing into a flying" % [coordinates()])
        entity.transportation_mode.mode = TransportationMode.FLYING
    elif entity.transportation_abilities.has_flag(TransportationMode.FALLING):
        entity.stand_up()
        print_debug("[Catapult %s] Crashing into a fall" % [coordinates()])
        entity.transportation_mode.mode = TransportationMode.FALLING
    else:
        push_error("[Catapult %s] Crashing into a helpless situation for %s" % [coordinates(), entity])
        entity.transportation_mode.mode = TransportationMode.NONE

    if immediate_uncinematic:
        _cleanup_entity(entity)
    else:
        print_debug("[Catapult %s] %s delayed clean up" % [coordinates(), entity.name])
        _cleanup_entity.call_deferred(entity)

func _get_release_anchor(entity: GridEntity) -> GridAnchor:
    print_debug("[Catapult %s] %s getting release anchors" % [coordinates(), entity.name])
    var can_be_in_the_air: bool = entity.transportation_abilities.can_be_in_the_air()

    var node: GridNode = entity.get_grid_node()
    if _crashes_forward:
        if node.may_exit(entity, entity.look_direction) && can_be_in_the_air:
            print_debug("[Catapult %s] %s may exit %s forward %s" % [coordinates(), entity.name, node.coordinates, CardinalDirections.name(entity.look_direction)])
            if !entity.force_movement(Movement.MovementType.FORWARD):
                push_warning("Failed to crash entity %s forward" % entity.name)
            else:
                return null

        elif node.has_side(entity.look_direction) == GridNode.NodeSideState.SOLID:
            var land_anchor: GridAnchor = node.get_grid_anchor(entity.look_direction)
            if land_anchor != null && land_anchor.can_anchor(entity):
                print_debug("[Catapult %s] %s will anchor on wall forward wall %s / %s" % [coordinates(), entity.name, node.coordinates, CardinalDirections.name(entity.look_direction)])
                return land_anchor

    if _crashes_entity_down:
        if node.may_exit(entity, entity.down) && can_be_in_the_air:
            print_debug("[Catapult %s] %s may exit %s entity down %s" % [coordinates(), entity.name, node.coordinates, CardinalDirections.name(entity.down)])
            var movement: Movement.MovementType = Movement.from_directions(entity.down, entity.look_direction, entity.down)
            if !entity.force_movement(movement):
                push_warning("Failed to crash entity %s down" % entity.name)
            else:
                return null

        else:
            var land_anchor: GridAnchor = node.get_grid_anchor(entity.down)
            if land_anchor != null && land_anchor.can_anchor(entity):
                return land_anchor

    if _crash_direction != CardinalDirections.CardinalDirection.NONE:
        if node.may_exit(entity, _crash_direction) && entity.transportation_abilities.has_flag(TransportationMode.FALLING):
            print_debug("[Catapult %s] %s may exit %s default direction %s" % [coordinates(), entity.name, node.coordinates, CardinalDirections.name(_crash_direction)])
            var movement: Movement.MovementType = Movement.from_directions(_crash_direction, entity.look_direction, entity.down)
            if !entity.force_movement(movement):
                push_warning("Failed to crash entity %s down" % entity.name)
            else:
                return null

        else:
            var land_anchor: GridAnchor = node.get_grid_anchor(_crash_direction)
            if land_anchor != null && land_anchor.can_anchor(entity):
                return land_anchor

    return null

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

func _handle_move_end(entity: GridEntity) -> void:
    if _managed_entities.get(entity) != self:
        return

    match _entity_phases.get(entity, Phase.NONE):
        Phase.NONE:
            print_debug("[Catapult %s] %s initializing" % [coordinates(), entity.name])
            if entity.force_movement(Movement.MovementType.CENTER):
                _entity_phases[entity] = Phase.CENTERING
            _prev_coordinates[entity] = entity.coordinates()

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

                    print_debug("[Catapult %s] orienting look %s, down %s" % [coordinates(), CardinalDirections.name(new_look), CardinalDirections.name(new_down)])
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
                            print_debug("[Catapult %s] Oriented %s to look %s, %s down" % [coordinates(), entity.name, CardinalDirections.name(entity.look_direction), CardinalDirections.name(entity.down)])

                    ) != OK:
                        push_error("Failed to connect rotation done")

                    tween.play()

            if !_fly(entity) || _prev_coordinates.get(entity, Vector3i.ZERO) == entity.coordinates():
                _entity_phases[entity] = Phase.CRASHING
            else:
                _entity_phases[entity] = Phase.FLYING

        Phase.FLYING:
            print_debug("[Catapult %s] %s flying from anchor %s with look %s, %s down" % [coordinates(), entity.name, CardinalDirections.name(entity.get_grid_anchor_direction()), CardinalDirections.name(entity.look_direction), CardinalDirections.name(entity.down)])
            if !_fly(entity) || _prev_coordinates.get(entity, Vector3i.ZERO) == entity.coordinates():
                print_debug("[Catapult %s] %s hit something %s" % [coordinates(), entity.name, CardinalDirections.name(entity.look_direction)])
                _entity_phases[entity] = Phase.CRASHING
            else:
                _prev_coordinates[entity] = entity.coordinates()

        Phase.CRASHING:
            # TODO: This is bugged. We need to split into a cleanup phase too and make sense of the crashing directions which seem to happen in the release function and not here...
            # TODO: We should here figure out where to go and when that movement is done we should do the release

            var fly_direction: CardinalDirections.CardinalDirection = field_direction
            var gravity: CardinalDirections.CardinalDirection = get_level().gravity

            print_debug("[Catapult %s] %s crashing (%s == %s && %s para down %s)" % [
                coordinates(),
                entity.name,
                CardinalDirections.name(fly_direction),
                CardinalDirections.name(entity.look_direction),
                CardinalDirections.name(fly_direction),
                CardinalDirections.is_parallell(fly_direction, gravity),
            ])

            if CardinalDirections.is_parallell(fly_direction, entity.look_direction) && CardinalDirections.is_parallell(fly_direction, gravity):
                print_debug("[Catapult %s] %s adjusting down" % [coordinates(), entity.name])
                var new_down: CardinalDirections.CardinalDirection = gravity
                var new_look: CardinalDirections.CardinalDirection = entity.look_direction if !CardinalDirections.is_parallell(new_down, entity.look_direction) else _entry_look_direction.get(entity, entity.look_direction)
                if CardinalDirections.is_parallell(new_down, new_look):
                    var options: Array[CardinalDirections.CardinalDirection] = CardinalDirections.orthogonals(new_down)
                    options.shuffle()
                    new_look = options[0]

                var look_target: Quaternion = CardinalDirections.direction_to_rotation(CardinalDirections.invert(new_down), new_look)

                var tween: Tween = create_tween()
                var update_rotation: Callable = QuaternionUtils.create_tween_rotation_method(entity)
                @warning_ignore_start("return_value_discarded")
                tween.tween_method(
                    update_rotation,
                    entity.global_transform.basis.get_rotation_quaternion(),
                    look_target,
                    0.3
                )
                @warning_ignore_restore("return_value_discarded")

                entity.down = new_down
                entity.look_direction = new_look
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
    _managed_entities[entity] = self
    _entity_phases[entity] = Phase.NONE if !entity.transportation_mode.has_flag(TransportationMode.FLYING) else Phase.CENTERING
    _entry_look_direction[entity] = entity.look_direction

    entity.transportation_mode.mode = TransportationMode.FLYING

func _should_be_managed(entity: GridEntity) -> bool:
    if _managed_entities.get(entity) == self:
        return false

    return activates_for(entity)

func _tick() -> void:
    pass
