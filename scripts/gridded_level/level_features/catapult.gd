extends GridEvent
class_name Catapult

enum Phase { NONE, CENTERING, ORIENTING, FLYING, CRASHING }

@export var _orient_entity: bool = false
@export var _prefer_orient_down_down: bool = true

# TODO: Crash forward seems problematic at times
# TODO: Crash relative down?
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
        return

    if _orient_entity:
        if entity is GridPlayerCore:
            var player: GridPlayerCore = entity
            player.stand_up()

    var crash_anchor: GridAnchor = _get_release_anchor(entity)
    if crash_anchor != null:
        print_debug("[Catapult %s] Attempting to anchor to %s" % [coordinates(), crash_anchor])
        # TODO: Animate this
        entity.set_grid_anchor(crash_anchor)
        entity.sync_position()
        if entity.look_direction == crash_anchor.direction:
            entity.look_direction = CardinalDirections.invert(entity.down)
        elif entity.look_direction == CardinalDirections.invert(crash_anchor.direction):
            entity.look_direction = entity.down
        entity.down = crash_anchor.direction

        GridEntity.orient(entity)
        entity.transportation_mode.adopt(crash_anchor.required_transportation_mode)
    elif entity.transportation_abilities.has_flag(TransportationMode.FALLING):
        entity.transportation_mode.mode = TransportationMode.FALLING
    else:
        entity.transportation_mode.mode = TransportationMode.NONE

    if immediate_uncinematic:
        _cleanup_entity(entity)
    else:
        print_debug("[Catapult %s] %s delayed cledanup" % [coordinates(), entity.name])
        _cleanup_entity.call_deferred(entity)

func _get_release_anchor(entity: GridEntity) -> GridAnchor:
    print_debug("[Catapult %s] %s getting release anchors" % [coordinates(), entity.name])
    var node: GridNode = entity.get_grid_node()
    if _crashes_forward:
        if node.may_exit(entity, entity.look_direction) && entity.transportation_abilities.has_flag(TransportationMode.FALLING):
            print_debug("[Catapult %s] %s may exit %s forward %s" % [coordinates(), entity.name, node.coordinates, CardinalDirections.name(entity.look_direction)])
            if !entity.force_movement(Movement.MovementType.FORWARD):
                push_warning("Failed to crash entity %s forward" % entity.name)
            else:
                return null

        elif node.has_side(entity.look_direction) == GridNode.NodeSideState.SOLID:
            var land_anchor: GridAnchor = node.get_grid_anchor(entity.look_direction)
            if land_anchor != null && land_anchor.can_anchor(entity):
                return land_anchor

    if _crashes_entity_down:
        if node.may_exit(entity, entity.down) && entity.transportation_abilities.has_flag(TransportationMode.FALLING):
            print_debug("[Catapult %s] %s may exit %s entity down %s" % [coordinates(), entity.name, node.coordinates, CardinalDirections.name(entity.down)])
            # TODO: Figure out movement down for entity...
            var movement: Movement.MovementType = Movement.from_directions(entity.down, entity.look_direction, entity.down)
            if !entity.force_movement(movement):
                push_warning("Failed to crash entity %s down" % entity.name)
            else:
                return null

        var land_anchor: GridAnchor = node.get_grid_anchor(entity.down)
        if land_anchor != null && land_anchor.can_anchor(entity):
            return land_anchor

    if _crash_direction != CardinalDirections.CardinalDirection.NONE:
        if node.may_exit(entity, _crash_direction) && entity.transportation_abilities.has_flag(TransportationMode.FALLING):
            print_debug("[Catapult %s] %s may exit %s default direction %s" % [coordinates(), entity.name, node.coordinates, CardinalDirections.name(_crash_direction)])
            # TODO: Figure out movement down for entity...
            var movement: Movement.MovementType = Movement.from_directions(_crash_direction, entity.look_direction, entity.down)
            if !entity.force_movement(movement):
                push_warning("Failed to crash entity %s down" % entity.name)
            else:
                return null

        var land_anchor: GridAnchor = node.get_grid_anchor(_crash_direction)
        if land_anchor != null && land_anchor.can_anchor(entity):
            return land_anchor

    return null

func _cleanup_entity(entity: GridEntity) -> void:
        entity.cinematic = false
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
            print_debug("[Catapult %s] %s nothing" % [coordinates(), entity.name])
            if entity.force_movement(Movement.MovementType.CENTER):
                _entity_phases[entity] = Phase.CENTERING
            _prev_coordinates[entity] = entity.coordinates()
        Phase.CENTERING:
            print_debug("[Catapult %s] %s centered" % [coordinates(), entity.name])
            if _orient_entity:
                if entity is GridPlayerCore:
                    var player: GridPlayerCore = entity
                    player.duck()

                var fly_direction: CardinalDirections.CardinalDirection = field_direction
                if !CardinalDirections.is_parallell(fly_direction, entity.look_direction):
                    var new_down: CardinalDirections.CardinalDirection = entity.look_direction
                    if _prefer_orient_down_down && !CardinalDirections.is_parallell(fly_direction, CardinalDirections.CardinalDirection.DOWN):
                        new_down = CardinalDirections.CardinalDirection.DOWN

                    print_debug("[Catapult %s] orienting look %s, down %s" % [coordinates(), CardinalDirections.name(fly_direction), CardinalDirections.name(new_down)])
                    var look_target: Quaternion = CardinalDirections.direction_to_rotation(CardinalDirections.invert(new_down), fly_direction)
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
                    entity.look_direction = fly_direction

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
            print_debug("[Catapult %s] %s flying from %s with look %s, %s down" % [coordinates(), entity.name, CardinalDirections.name(entity.get_grid_anchor_direction()), CardinalDirections.name(entity.look_direction), CardinalDirections.name(entity.down)])
            if !_fly(entity) || _prev_coordinates.get(entity, Vector3i.ZERO) == entity.coordinates():
                print_debug("[Catapult %s] %s hit something %s" % [coordinates(), entity.name, CardinalDirections.name(entity.look_direction)])
                _entity_phases[entity] = Phase.CRASHING
            else:
                _prev_coordinates[entity] = entity.coordinates()
        Phase.CRASHING:
            var fly_direction: CardinalDirections.CardinalDirection = field_direction

            print_debug("[Catapult %s] %s crashing (%s == %s && %s para down %s)" % [
                coordinates(),
                entity.name,
                CardinalDirections.name(fly_direction),
                CardinalDirections.name(entity.look_direction),
                CardinalDirections.name(fly_direction),
                CardinalDirections.is_parallell(fly_direction, CardinalDirections.CardinalDirection.DOWN),
            ])

            if fly_direction == entity.look_direction && CardinalDirections.is_parallell(fly_direction, CardinalDirections.CardinalDirection.DOWN):
                print_debug("[Catapult %s] %s adjusting down" % [coordinates(), entity.name])
                var new_down: CardinalDirections.CardinalDirection = CardinalDirections.CardinalDirection.DOWN
                var new_look: CardinalDirections.CardinalDirection = _entry_look_direction.get(entity, entity.look_direction)
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

    return entity.force_movement(movement)

func trigger(entity: GridEntity, _movement: Movement.MovementType) -> void:
    _triggered = true

    if !_should_be_managed(entity):
        return

    print_debug("[Catapult %s] Grabbing %s" % [coordinates(), entity.name])

    entity.cinematic = true

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

    return activates(entity)

func _tick() -> void:
    pass
