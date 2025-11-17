extends Node
class_name MovementPlanner2

@export var translation_duration: float = 0.4
@export var fall_duration: float = 0.25
@export var exotic_translation_duration: float = 0.5
@export var turn_duration: float = 0.3
@export var animation_speed: float = 1.0

enum MovementMode {
    NONE,
    ROTATE,
    TRANSLATE_PLANAR,
    TRANSLATE_CENTER,
    TRANSLATE_JUMP,
    TRANSLATE_LAND,
    TRANSLATE_INNER_CORNER,
    TRANSLATE_OUTER_CORNER,
    TRANSLATE_FALL_LATERAL,
    TRANSLATE_REFUSE,
}

enum StandMode {
    NORMAL,
    AIRBOURNE,
    SIDE_FACING,
    EVENT_CONTROLLED,
}

class EntityParameters:
    var coordinates: Vector3i
    var down: CardinalDirections.CardinalDirection
    var look_direction: CardinalDirections.CardinalDirection
    var anchor: CardinalDirections.CardinalDirection
    var standing: StandMode

    @warning_ignore_start("shadowed_variable")
    func _init(
        coordinates: Vector3i,
        look_direction: CardinalDirections.CardinalDirection,
        down: CardinalDirections.CardinalDirection,
        anchor: CardinalDirections.CardinalDirection,
        standing: StandMode,
    ) -> void:
        @warning_ignore_restore("shadowed_variable")
        self.coordinates = coordinates
        self.look_direction = look_direction
        self.down = down
        self.anchor = anchor
        self.standing = standing

    static func from_entity(entity: GridEntity) -> EntityParameters:
        var mode: StandMode = StandMode.NORMAL
        var anchor_direction: CardinalDirections.CardinalDirection = entity.get_grid_anchor_direction()
        if anchor_direction == CardinalDirections.CardinalDirection.NONE:
            mode = StandMode.AIRBOURNE
        elif CardinalDirections.is_parallell(anchor_direction, entity.look_direction):
            mode = StandMode.SIDE_FACING

        return EntityParameters.new(
            entity.coordinates(),
            entity.look_direction,
            entity.down,
            anchor_direction,
            mode,
        )

class MovementPlan:
    var start_time_msec: int
    var end_time_msec: int
    var mode: MovementMode
    var from: EntityParameters
    var to: EntityParameters
    var move_direction: CardinalDirections.CardinalDirection

    @warning_ignore_start("shadowed_variable")
    func _init(
        mode: MovementMode,
        duration: float,
        direction: CardinalDirections.CardinalDirection,
    ) -> void:
        @warning_ignore_restore("shadowed_variable")
        self.mode = mode
        start_time_msec = Time.get_ticks_msec()
        end_time_msec = start_time_msec + roundi(duration * 1000)
        move_direction = direction

func create_plan(entity: GridEntity, movement: Movement.MovementType) -> MovementPlan:
    if Movement.is_translation(movement):
        var translation_direction: CardinalDirections.CardinalDirection = Movement.to_direction(
            movement,
            entity.look_direction,
            entity.down,
        )
        return _create_translation_plan(entity, movement, translation_direction)

    if Movement.is_turn(movement):
        return _create_rotation_plan(entity, movement)

    return null

func _create_rotation_plan(
    entity: GridEntity,
    movement: Movement.MovementType,
) -> MovementPlan:
    var node: GridNode = entity.get_grid_node()
    if node == null:
        push_error("Player %s not inside dungeon")
        return null

    var look_direction: CardinalDirections.CardinalDirection
    match movement:
        Movement.MovementType.TURN_CLOCKWISE:
            look_direction = CardinalDirections.yaw_cw(entity.look_direction, entity.down)[0]
        Movement.MovementType.TURN_COUNTER_CLOCKWISE:
            look_direction = CardinalDirections.yaw_ccw(entity.look_direction, entity.down)[0]
        _:
            push_error("Movement %s is not a rotation" % Movement.name(movement))
            return null

    var plan: MovementPlan = MovementPlan.new(
        MovementMode.ROTATE,
        turn_duration * animation_speed,
        CardinalDirections.CardinalDirection.NONE,
    )
    plan.from = EntityParameters.from_entity(entity)
    if plan.from.standing == StandMode.SIDE_FACING:
        return null

    plan.to = EntityParameters.new(
        node.coordinates,
        look_direction,
        entity.down,
        entity.get_grid_anchor_direction(),
        StandMode.SIDE_FACING if CardinalDirections.is_parallell(look_direction, entity.get_grid_anchor_direction()) else StandMode.NORMAL,
    )

    return null

func _create_translation_plan(
    entity: GridEntity,
    movement: Movement.MovementType,
    direction: CardinalDirections.CardinalDirection,
) -> MovementPlan:
    var plan: MovementPlan = null

    plan = _create_translate_center(entity, movement)
    if plan != null:
        return plan

    plan = _create_translate_land_simple(entity, direction)
    if plan != null:
        return plan

    plan = _create_translate_fall_diagonal(entity, direction)
    if plan != null:
        return plan

    plan = _create_translate_land_simple(entity, direction)
    if plan != null:
        return plan

    plan = _create_translate_nodes(entity, direction)
    if plan != null:
        return plan

    plan = _create_translate_inner_corner(entity, direction)
    if plan != null:
        return plan

    return _create_translate_refused(entity, direction)

## Attempted translation in one direction but move is refused so return to
## movement origin
func _create_translate_refused(
    entity: GridEntity,
    move_direction: CardinalDirections.CardinalDirection,
) -> MovementPlan:
    var plan: MovementPlan = MovementPlan.new(
        MovementMode.TRANSLATE_REFUSE,
        translation_duration * animation_speed,
        move_direction,
    )
    plan.from = EntityParameters.from_entity(entity)
    plan.to = EntityParameters.from_entity(entity)
    return plan

## Requested movement isn't allowed even to be attempted
## Imagine as example rotating on a ladder or trying to jump up into the air to fly but not being able to
func _create_no_movement(entity: GridEntity) -> MovementPlan:
    var plan: MovementPlan = MovementPlan.new(
        MovementMode.NONE,
        0.0,
        CardinalDirections.CardinalDirection.NONE,
    )
    plan.from = EntityParameters.from_entity(entity)
    plan.to = EntityParameters.from_entity(entity)
    return plan

## If entity is cinematic or can fly get into the center of the tile
func _create_translate_center(
    entity: GridEntity,
    movement: Movement.MovementType,
) -> MovementPlan:
    if movement != Movement.MovementType.CENTER:
        return null

    var move_direction: CardinalDirections.CardinalDirection = CardinalDirections.invert(entity.get_grid_anchor_direction())
    var from: GridNode = entity.get_grid_node()

    if entity.anchor != null && (entity.cinematic || entity.transportation_abilities.has_flag(TransportationMode.FLYING)):
        var events: Array[GridEvent] = from.triggering_events(
            entity,
            from,
            entity.get_grid_anchor_direction(),
            move_direction,
        )
        for event: GridEvent in events:
            if event.manages_triggering_translation():
                var evented_plan: MovementPlan = MovementPlan.new(
                    MovementMode.TRANSLATE_CENTER,
                    translation_duration * 0.5 * animation_speed,
                    move_direction,
                )
                evented_plan.from = EntityParameters.from_entity(entity)
                evented_plan.to = EntityParameters.new(
                    from.coordinates,
                    entity.look_direction,
                    entity.down,
                    CardinalDirections.CardinalDirection.NONE,
                    StandMode.EVENT_CONTROLLED,
                )
                return evented_plan

        var plan: MovementPlan = MovementPlan.new(
            MovementMode.TRANSLATE_CENTER,
            # Because it is half the distance of a translation we use half duration
            translation_duration * 0.5 * animation_speed,
            move_direction,
        )
        plan.from = EntityParameters.from_entity(entity)
        plan.to = EntityParameters.from_entity(entity)
        plan.to.anchor = CardinalDirections.CardinalDirection.NONE
        plan.to.standing = StandMode.AIRBOURNE
        var gravity: CardinalDirections.CardinalDirection = entity.get_level().gravity
        if entity.orient_with_gravity_in_air && CardinalDirections.ALL_DIRECTIONS.has(gravity):
            plan.to.down = gravity
        return plan

    return _create_no_movement(entity)

func _create_translate_land_simple(
    entity: GridEntity,
    move_direction: CardinalDirections.CardinalDirection,
) -> MovementPlan:
    if entity.anchor != null:
        return null

    var node: GridNode = entity.get_grid_node()
    if node == null:
        return null

    var land_anchor: GridAnchor = node.get_grid_anchor(move_direction)
    if land_anchor != null:
        var events: Array[GridEvent] = node.triggering_events(
            entity,
            node,
            entity.get_grid_anchor_direction(),
            move_direction,
        )
        for event: GridEvent in events:
            if event.manages_triggering_translation():
                var evented_plan: MovementPlan = MovementPlan.new(
                    MovementMode.TRANSLATE_LAND,
                    (fall_duration if entity.transportation_mode.has_flag(TransportationMode.FALLING) else translation_duration) * animation_speed,
                    move_direction,
                )
                evented_plan.from = EntityParameters.from_entity(entity)
                evented_plan.to = EntityParameters.new(
                    node.coordinates,
                    entity.look_direction if !CardinalDirections.is_parallell(move_direction, entity.look_direction) else CardinalDirections.orthogonals(move_direction).pick_random(),
                    move_direction,
                    move_direction,
                    StandMode.EVENT_CONTROLLED,
                )
                return evented_plan

        if land_anchor.can_anchor(entity):
            var plan: MovementPlan = MovementPlan.new(
                MovementMode.TRANSLATE_LAND,
                (fall_duration if entity.transportation_mode.has_flag(TransportationMode.FALLING) else translation_duration) * animation_speed,
                move_direction,
            )

            var look_direction: CardinalDirections.CardinalDirection = entity.look_direction
            var standing: StandMode = StandMode.NORMAL
            var down: CardinalDirections.CardinalDirection = land_anchor.direction
            var gravity: CardinalDirections.CardinalDirection = entity.get_level().gravity
            if land_anchor.inherrent_axis_down != CardinalDirections.CardinalDirection.NONE:
                standing = StandMode.SIDE_FACING
                if CardinalDirections.is_parallell(land_anchor.inherrent_axis_down, gravity):
                    down = gravity
                else:
                    down = land_anchor.inherrent_axis_down
                look_direction = land_anchor.direction

            plan.from = EntityParameters.from_entity(entity)
            if CardinalDirections.is_parallell(look_direction, land_anchor.direction):
                look_direction = CardinalDirections.orthogonals(land_anchor.direction).pick_random()

            plan.to = EntityParameters.new(
                node.coordinates,
                look_direction,
                down,
                land_anchor.direction,
                standing,
            )

            return plan

    return null

func _create_translate_fall_diagonal(
    entity: GridEntity,
    move_direction: CardinalDirections.CardinalDirection,
) -> MovementPlan:
    var from: GridNode = entity.get_grid_node()
    var gravity: CardinalDirections.CardinalDirection = entity.get_level().gravity

    if (
        entity.anchor != null ||
        !entity.transportation_mode.has_flag(TransportationMode.FALLING) ||
        from == null ||
        move_direction != gravity
    ):
        return null

    var options: Array[CardinalDirections.CardinalDirection] = CardinalDirections.orthogonals(move_direction)
    options.shuffle()
    for lateral: CardinalDirections.CardinalDirection in options:
        if !from.may_exit(entity, lateral, false, true):
            continue

        var neighbour: GridNode = from.neighbour(lateral)
        if neighbour == null:
            continue

        if neighbour.may_enter(entity, from, lateral, move_direction, false, false, true):
            var anchor: GridAnchor = neighbour.get_grid_anchor(move_direction)
            if anchor != null:
                # Landing on a lateral tile
                var events: Array[GridEvent] = neighbour.triggering_events(
                    entity,
                    from,
                    entity.get_grid_anchor_direction(),
                    move_direction,
                )
                for event: GridEvent in events:
                    if event.manages_triggering_translation():
                        var evented_plan: MovementPlan = MovementPlan.new(
                            MovementMode.TRANSLATE_LAND,
                            fall_duration * animation_speed,
                            move_direction,
                        )
                        evented_plan.from = EntityParameters.from_entity(entity)
                        evented_plan.to = EntityParameters.new(
                            neighbour.coordinates,
                            entity.look_direction if !CardinalDirections.is_parallell(move_direction, entity.look_direction) else CardinalDirections.orthogonals(move_direction).pick_random(),
                            move_direction,
                            move_direction,
                            StandMode.EVENT_CONTROLLED,
                        )
                        return evented_plan

                if anchor.can_anchor(entity):
                    var plan: MovementPlan = MovementPlan.new(
                        MovementMode.TRANSLATE_LAND,
                        fall_duration * animation_speed,
                        move_direction,
                    )
                    plan.from = EntityParameters.from_entity(entity)
                    var down: CardinalDirections.CardinalDirection = anchor.direction
                    var look_direction: CardinalDirections.CardinalDirection = entity.look_direction
                    var mode: StandMode = StandMode.NORMAL

                    if anchor.inherrent_axis_down != CardinalDirections.CardinalDirection.NONE:
                        down = anchor.inherrent_axis_down
                        look_direction = anchor.direction
                        mode = StandMode.SIDE_FACING

                    if CardinalDirections.is_parallell(look_direction, down):
                        # We got pushed away from our default landing spot, thus we
                        look_direction = lateral

                    plan.to = EntityParameters.new(
                        neighbour.coordinates,
                        look_direction,
                        down,
                        anchor.direction,
                        mode,
                    )

                    return plan
                else:
                    continue

        var target: GridNode = neighbour.neighbour(move_direction)
        if (
            target != null &&
            neighbour.may_transit(
                entity,
                from,
                lateral,
                move_direction,
                true,
            ) &&
            target.may_enter(
                entity,
                neighbour,
                move_direction,
                CardinalDirections.CardinalDirection.NONE,
                false,
                false,
                true,
            )
        ):
            var events: Array[GridEvent] = target.triggering_events(
                entity,
                from,
                entity.get_grid_anchor_direction(),
                CardinalDirections.CardinalDirection.NONE,
            )
            for event: GridEvent in events:
                if event.manages_triggering_translation():
                    var evented_plan: MovementPlan = MovementPlan.new(
                        MovementMode.TRANSLATE_FALL_LATERAL,
                        fall_duration * animation_speed,
                        move_direction,
                    )
                    evented_plan.from = EntityParameters.from_entity(entity)
                    evented_plan.to = EntityParameters.new(
                        target.coordinates,
                        entity.look_direction if !CardinalDirections.is_parallell(move_direction, entity.look_direction) else CardinalDirections.orthogonals(move_direction).pick_random(),
                        move_direction,
                        CardinalDirections.CardinalDirection.NONE,
                        StandMode.EVENT_CONTROLLED,
                    )
                    return evented_plan

            # We can fall to the side here
            var plan: MovementPlan = MovementPlan.new(
                MovementMode.TRANSLATE_FALL_LATERAL,
                fall_duration * animation_speed,
                move_direction,
            )
            plan.from = EntityParameters.from_entity(entity)
            plan.to = EntityParameters.new(
                target.coordinates,
                entity.look_direction,
                entity.down,
                CardinalDirections.CardinalDirection.NONE,
                StandMode.AIRBOURNE,
            )
            return plan

    return null

func _create_translate_nodes(
    entity: GridEntity,
    move_direction: CardinalDirections.CardinalDirection
) -> MovementPlan:
    var from: GridNode = entity.get_grid_node()

    if from.may_exit(entity, move_direction, false, true):
        var target: GridNode = from.neighbour(move_direction)
        if target == null:
            return null

        var plan: MovementPlan = _create_translate_outer_corner(entity, from, move_direction, target)
        if plan != null:
            return plan

        var is_flying: bool = entity.transportation_mode.has_flag(TransportationMode.FLYING)
        if target.may_enter(
            entity,
            from,
            move_direction,
            CardinalDirections.CardinalDirection.NONE if is_flying else entity.get_grid_anchor_direction(),
            false,
            false,
            true
        ):
            var events: Array[GridEvent] = target.triggering_events(
                entity,
                from,
                entity.get_grid_anchor_direction(),
                entity.get_grid_anchor_direction(),
            )
            for event: GridEvent in events:
                if event.manages_triggering_translation():
                    var evented_plan: MovementPlan = MovementPlan.new(
                        MovementMode.TRANSLATE_PLANAR,
                        translation_duration * animation_speed,
                        move_direction,
                    )
                    evented_plan.from = EntityParameters.from_entity(entity)
                    evented_plan.to = EntityParameters.new(
                        target.coordinates,
                        entity.look_direction,
                        entity.down,
                        entity.get_grid_anchor_direction(),
                        StandMode.EVENT_CONTROLLED,
                    )
                    return evented_plan

            var neighbour_anchor: GridAnchor = null if is_flying else target.get_grid_anchor(entity.get_grid_anchor_direction())
            var gravity: CardinalDirections.CardinalDirection = entity.get_level().gravity

            if (
                neighbour_anchor == null &&
                entity.transportation_abilities.has_any([TransportationMode.FALLING, TransportationMode.FLYING]) &&
                (entity.get_grid_anchor_direction() == gravity && entity.can_jump_off_floor || entity.can_jump_off_all)
            ):
                plan = MovementPlan.new(
                    MovementMode.TRANSLATE_JUMP,
                    translation_duration * animation_speed,
                    move_direction,
                )
                plan.from = EntityParameters.from_entity(entity)
                var down: CardinalDirections.CardinalDirection = entity.down
                if entity.orient_with_gravity_in_air:
                    down = gravity

                plan.to = EntityParameters.new(
                    target.coordinates,
                    entity.look_direction,
                    down,
                    CardinalDirections.CardinalDirection.NONE,
                    StandMode.AIRBOURNE,
                )

            plan = MovementPlan.new(
                MovementMode.TRANSLATE_PLANAR,
                translation_duration * animation_speed,
                move_direction,
            )
            plan.from = EntityParameters.from_entity(entity)
            plan.to = EntityParameters.new(
                target.coordinates,
                entity.look_direction,
                entity.down,
                entity.get_grid_anchor_direction(),
                StandMode.NORMAL,
            )

    return null

func _create_translate_outer_corner(
    entity: GridEntity,
    from: GridNode,
    move_direction: CardinalDirections.CardinalDirection,
    intermediate: GridNode
) -> MovementPlan:
    if (
        entity.anchor == null || entity.transportation_mode.has_flag(TransportationMode.FLYING) ||
        !intermediate.may_transit(
            entity,
            from,
            move_direction,
            entity.get_grid_anchor_direction(),
            true,
        )
    ):
        return null

    var target: GridNode = intermediate.neighbour(entity.get_grid_anchor_direction())
    if target == null:
        return null

    var updated_directions: Array[CardinalDirections.CardinalDirection] = CardinalDirections.calculate_outer_corner(
        move_direction, entity.look_direction, entity.get_grid_anchor_direction())

    if !target.may_enter(entity, intermediate, entity.get_grid_anchor_direction(), updated_directions[1], false, false, true):
        # print_debug("We may not enter %s from %s" % [target.name, entity.down])
        if target._entry_blocking_events(entity, from, move_direction, entity.get_grid_anchor_direction()):
            return _create_translate_refused(entity, move_direction)
        return null

    # In the case that any event manages the transition we no longer require more than entry
    var events: Array[GridEvent] = target.triggering_events(
        entity,
        from,
        entity.get_grid_anchor_direction(),
        updated_directions[1],
    )
    for event: GridEvent in events:
        if event.manages_triggering_translation():
            var evented_plan: MovementPlan = MovementPlan.new(
                MovementMode.TRANSLATE_OUTER_CORNER,
                translation_duration * animation_speed,
                move_direction,
            )
            evented_plan.from = EntityParameters.from_entity(entity)
            evented_plan.to = EntityParameters.new(
                target.coordinates,
                updated_directions[0],
                updated_directions[1],
                updated_directions[1],
                StandMode.EVENT_CONTROLLED,
            )
            return evented_plan

    var target_anchor: GridAnchor = target.get_grid_anchor(updated_directions[1])
    if target_anchor == null:
        # print_debug("%s doesn't have an anchor %s" % [target.name, updated_directions[1]])
        return null

    if !target_anchor.can_anchor(entity):
        # print_debug("%s of %s doesn't alow us to anchor" % [target_anchor.name, target.name])
        return null

    var gravity: CardinalDirections.CardinalDirection = entity.get_level().gravity
    var plan: MovementPlan = MovementPlan.new(
        MovementMode.TRANSLATE_OUTER_CORNER,
        translation_duration * animation_speed,
        move_direction,
    )
    plan.from = EntityParameters.from_entity(entity)
    if (
        target_anchor.inherrent_axis_down != CardinalDirections.CardinalDirection.NONE &&
        CardinalDirections.is_parallell(target_anchor.inherrent_axis_down, gravity)
    ):
        plan.to = EntityParameters.new(
            from.coordinates,
            target_anchor.direction,
            gravity,
            target_anchor.direction,
            StandMode.SIDE_FACING,
        )
    else:
        plan.to = EntityParameters.new(
            target.coordinates,
            updated_directions[0],
            updated_directions[1],
            target_anchor.direction,
            StandMode.NORMAL,
        )

    return plan

func _create_translate_inner_corner(
    entity: GridEntity,
    move_direction: CardinalDirections.CardinalDirection,
) -> MovementPlan:
    var from: GridNode = entity.get_grid_node()
    var target_anchor: GridAnchor = from.get_grid_anchor(move_direction)

    if entity.get_grid_anchor_direction() == CardinalDirections.CardinalDirection.NONE || target_anchor == null:
        return null

    var updated_directions: Array[CardinalDirections.CardinalDirection] = CardinalDirections.calculate_innner_corner(
        move_direction, entity.look_direction, entity.get_grid_anchor_direction())

    # In the case that any event manages the transition we no longer require more than existance of anchor
    var events: Array[GridEvent] = from.triggering_events(
        entity,
        from,
        entity.get_grid_anchor_direction(),
        move_direction,
    )
    for event: GridEvent in events:
        if event.manages_triggering_translation():
            var evented_plan: MovementPlan = MovementPlan.new(
                MovementMode.TRANSLATE_INNER_CORNER,
                translation_duration * animation_speed,
                move_direction,
            )
            evented_plan.from = EntityParameters.from_entity(entity)
            evented_plan.to = EntityParameters.new(
                from.coordinates,
                updated_directions[0],
                updated_directions[1],
                updated_directions[1],
                StandMode.EVENT_CONTROLLED,
            )
            return evented_plan

    if !target_anchor.can_anchor(entity):
        return null

    var gravity: CardinalDirections.CardinalDirection = entity.get_level().gravity
    var plan: MovementPlan = MovementPlan.new(
        MovementMode.TRANSLATE_INNER_CORNER,
        translation_duration * animation_speed,
        move_direction,
    )
    plan.from = EntityParameters.from_entity(entity)

    if (
        target_anchor.inherrent_axis_down != CardinalDirections.CardinalDirection.NONE &&
        CardinalDirections.is_parallell(target_anchor.inherrent_axis_down, gravity)
    ):
        plan.to = EntityParameters.new(
            from.coordinates,
            target_anchor.direction,
            gravity,
            target_anchor.direction,
            StandMode.SIDE_FACING,
        )

    else:

        plan.to = EntityParameters.new(
            from.coordinates,
            updated_directions[0],
            updated_directions[1],
            target_anchor.direction,
            StandMode.NORMAL
        )

    return null
