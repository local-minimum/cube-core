extends MovementPlannerBase
class_name MovementPlanner

@export var _filter: EntityFilter
@export var _settings: MovementPlannerSettings
@export var _verbose: bool

func plans_for(entity: GridEntity) -> bool:
    return _filter.applies(entity)

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

    push_warning("[Movement Planner %s] Failed to create plan for %s %s" % [self.name, entity, Movement.name(movement)])
    return null


func _create_rotation_plan(
    entity: GridEntity,
    movement: Movement.MovementType,
) -> MovementPlan:
    var node: GridNode = entity.get_grid_node()
    if node == null:
        push_error("[Movement Planner %s] Player %s not inside dungeon" % [self.name, entity])
        return null

    var look_direction: CardinalDirections.CardinalDirection
    match movement:
        Movement.MovementType.TURN_CLOCKWISE:
            look_direction = CardinalDirections.yaw_cw(entity.look_direction, entity.down)[0]
        Movement.MovementType.TURN_COUNTER_CLOCKWISE:
            look_direction = CardinalDirections.yaw_ccw(entity.look_direction, entity.down)[0]
        _:
            push_error("[Movement Planner %s] Movement %s is not a rotation" % [self.name, Movement.name(movement)])
            return null

    var plan: MovementPlan = MovementPlan.new(
        movement,
        MovementMode.ROTATE,
        _settings.turn_duration_scaled,
        CardinalDirections.CardinalDirection.NONE,
    )
    plan.from = EntityParameters.from_entity(entity)
    if plan.from.mode == PositionMode.SIDE_FACING:
        if _verbose:
            print_debug("[Movement Planner %s] does no rotation of %s because it is side facing" % [self.name, entity])
        return null

    plan.to = EntityParameters.new(
        node.coordinates,
        look_direction,
        entity.down,
        entity.get_grid_anchor_direction(),
        PositionMode.SIDE_FACING if CardinalDirections.is_parallell(look_direction, entity.get_grid_anchor_direction()) else PositionMode.NORMAL,
    )

    if _verbose:
        print_debug("[Movement Planner %s] Rotates %s %s" % [
            self.name,
            entity,
            Movement.name(movement),
        ])

    return plan

func _create_translation_plan(
    entity: GridEntity,
    movement: Movement.MovementType,
    direction: CardinalDirections.CardinalDirection,
) -> MovementPlan:
    var plan: MovementPlan = null

    plan = _create_translate_center(entity, movement)
    if plan != null:
        if _verbose:
            print_debug("[Movement Planner %s] Translates %s to node center (%s / %s)" % [
                self.name,
                entity,
                Movement.name(movement),
                CardinalDirections.name(direction),
            ])
        return plan

    plan = _create_translate_land_simple(entity, movement, direction)
    if plan != null:
        if _verbose:
            print_debug("[Movement Planner %s] Translates %s lands simple (%s / %s)" % [
                self.name,
                entity,
                Movement.name(movement),
                CardinalDirections.name(direction),
            ])
        return plan

    plan = _create_translate_fall_diagonal(entity, movement, direction)
    if plan != null:
        if _verbose:
            print_debug("[Movement Planner %s] Translates %s fall diagonally (%s / %s)" % [
                self.name,
                entity,
                Movement.name(movement),
                CardinalDirections.name(direction),
            ])
        return plan

    plan = _create_translate_nodes(entity, movement, direction)
    if plan != null:
        if _verbose:
            print_debug("[Movement Planner %s] Translates %s to new node (%s / %s)" % [
                self.name,
                entity,
                Movement.name(movement),
                CardinalDirections.name(direction),
            ])
        return plan

    plan = _create_translate_inner_corner(entity, movement, direction)
    if plan != null:
        if _verbose:
            print_debug("[Movement Planner %s] Translates %s node internal corner (%s / %s)" % [
                self.name,
                entity,
                Movement.name(movement),
                CardinalDirections.name(direction),
            ])
        return plan

    if _verbose:
        print_debug("[Movement Planner %s] Refuses translation %s (%s / %s)" % [
            self.name,
            entity,
            Movement.name(movement),
            CardinalDirections.name(direction),
        ])
    return _create_translate_refused(entity, movement, direction)

## Attempted translation in one direction but move is refused so return to
## movement origin
func _create_translate_refused(
    entity: GridEntity,
    movement: Movement.MovementType,
    move_direction: CardinalDirections.CardinalDirection,
) -> MovementPlan:
    var plan: MovementPlan = MovementPlan.new(
        movement,
        MovementMode.TRANSLATE_REFUSE,
        _settings.translation_duration_scaled,
        move_direction,
    )
    plan.from = EntityParameters.from_entity(entity)
    plan.to = EntityParameters.from_entity(entity)
    return plan

## If entity can fly get into the center of the tile
## Cinematic entities should have their abilities overridden if they can fly temporarily
func _create_translate_center(
    entity: GridEntity,
    movement: Movement.MovementType,
) -> MovementPlan:
    if movement != Movement.MovementType.CENTER:
        return null

    if entity.get_grid_anchor_direction() == CardinalDirections.CardinalDirection.NONE:
        push_warning("[Movement Planner] Requested centering of %s but they already don't have any anchor!" % [
            entity.name
        ])
        return create_no_movement(entity, movement)

    var move_direction: CardinalDirections.CardinalDirection = CardinalDirections.invert(entity.get_grid_anchor_direction())
    var from: GridNode = entity.get_grid_node()

    if entity.anchor != null && entity.transportation_abilities.can_be_in_the_air():
        var events: Array[GridEvent] = from.triggering_events(
            entity,
            from,
            entity.get_grid_anchor_direction(),
            move_direction,
        )
        for event: GridEvent in events:
            if event.manages_triggering_translation():
                var evented_plan: MovementPlan = MovementPlan.new(
                    movement,
                    MovementMode.TRANSLATE_CENTER,
                    _settings.translation_duration_scaled * 0.5,
                    move_direction,
                )
                evented_plan.from = EntityParameters.from_entity(entity)
                evented_plan.to = EntityParameters.new(
                    from.coordinates,
                    entity.look_direction,
                    entity.down,
                    CardinalDirections.CardinalDirection.NONE,
                    PositionMode.EVENT_CONTROLLED,
                )
                return evented_plan

        var plan: MovementPlan = MovementPlan.new(
            movement,
            MovementMode.TRANSLATE_CENTER,
            # Because it is half the distance of a translation we use half duration
            _settings.translation_duration_scaled * 0.5,
            move_direction,
        )
        plan.from = EntityParameters.from_entity(entity)
        plan.to = EntityParameters.from_entity(entity)
        plan.to.anchor = CardinalDirections.CardinalDirection.NONE
        plan.to.mode = PositionMode.AIRBOURNE
        var gravity: CardinalDirections.CardinalDirection = entity.get_level().gravity
        if !entity.cinematic && entity.orient_with_gravity_in_air && CardinalDirections.ALL_DIRECTIONS.has(gravity):
            if gravity == plan.to.look_direction:
                var updated_directions: Array[CardinalDirections.CardinalDirection] = CardinalDirections.pitch_up(plan.to.look_direction, plan.to.down)
                plan.to.look_direction = updated_directions[0]
                plan.to.down = gravity
            elif gravity == CardinalDirections.invert(plan.to.look_direction):
                var updated_directions: Array[CardinalDirections.CardinalDirection] = CardinalDirections.pitch_down(plan.to.look_direction, plan.to.down)
                plan.to.look_direction = updated_directions[0]
                plan.to.down = gravity
            else:
                plan.to.down = gravity
        return plan

    return create_no_movement(entity, movement)

func _create_translate_land_simple(
    entity: GridEntity,
    movement: Movement.MovementType,
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
                    movement,
                    MovementMode.TRANSLATE_LAND,
                    _settings.fall_duration_scaled if entity.transportation_mode.has_flag(TransportationMode.FALLING) else _settings.translation_duration_scaled,
                    move_direction,
                )
                evented_plan.from = EntityParameters.from_entity(entity)
                evented_plan.to = EntityParameters.new(
                    node.coordinates,
                    entity.look_direction if !CardinalDirections.is_parallell(move_direction, entity.look_direction) else CardinalDirections.orthogonals(move_direction).pick_random(),
                    move_direction,
                    move_direction,
                    PositionMode.EVENT_CONTROLLED,
                )
                return evented_plan

        if land_anchor.can_anchor(entity):
            var plan: MovementPlan = MovementPlan.new(
                movement,
                MovementMode.TRANSLATE_LAND,
                _settings.fall_duration_scaled if entity.transportation_mode.has_flag(TransportationMode.FALLING) else _settings.translation_duration_scaled,
                move_direction,
            )

            var look_direction: CardinalDirections.CardinalDirection = entity.look_direction
            var standing: PositionMode = PositionMode.NORMAL
            var gravity: CardinalDirections.CardinalDirection = entity.get_level().gravity
            var down: CardinalDirections.CardinalDirection = land_anchor.calculate_anchor_down(gravity, entity.down)
            if !CardinalDirections.is_parallell(down, land_anchor.direction):
                standing = PositionMode.SIDE_FACING
                look_direction = land_anchor.direction

            plan.from = EntityParameters.from_entity(entity)
            if CardinalDirections.is_parallell(look_direction, down):
                look_direction = CardinalDirections.orthogonals(down).pick_random()

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
    movement: Movement.MovementType,
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
                            movement,
                            MovementMode.TRANSLATE_LAND,
                            _settings.fall_duration_scaled,
                            move_direction,
                        )
                        evented_plan.from = EntityParameters.from_entity(entity)
                        evented_plan.to = EntityParameters.new(
                            neighbour.coordinates,
                            entity.look_direction if !CardinalDirections.is_parallell(move_direction, entity.look_direction) else CardinalDirections.orthogonals(move_direction).pick_random(),
                            move_direction,
                            move_direction,
                            PositionMode.EVENT_CONTROLLED,
                        )
                        return evented_plan

                if anchor.can_anchor(entity):
                    var plan: MovementPlan = MovementPlan.new(
                        movement,
                        MovementMode.TRANSLATE_LAND,
                        _settings.fall_duration_scaled,
                        move_direction,
                    )
                    plan.from = EntityParameters.from_entity(entity)
                    var down: CardinalDirections.CardinalDirection = anchor.calculate_anchor_down(gravity, entity.down)
                    var look_direction: CardinalDirections.CardinalDirection = entity.look_direction
                    var mode: PositionMode = PositionMode.NORMAL

                    if anchor.direction != down:
                        if !CardinalDirections.is_parallell(down, anchor.direction):
                            look_direction = anchor.direction
                            mode = PositionMode.SIDE_FACING

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
                        movement,
                        MovementMode.TRANSLATE_FALL_LATERAL,
                        _settings.fall_duration_scaled,
                        move_direction,
                    )
                    evented_plan.from = EntityParameters.from_entity(entity)
                    evented_plan.to = EntityParameters.new(
                        target.coordinates,
                        entity.look_direction if !CardinalDirections.is_parallell(move_direction, entity.look_direction) else CardinalDirections.orthogonals(move_direction).pick_random(),
                        move_direction,
                        CardinalDirections.CardinalDirection.NONE,
                        PositionMode.EVENT_CONTROLLED,
                    )
                    return evented_plan

            # We can fall to the side here
            var plan: MovementPlan = MovementPlan.new(
                movement,
                MovementMode.TRANSLATE_FALL_LATERAL,
                _settings.fall_duration_scaled,
                move_direction,
            )
            plan.from = EntityParameters.from_entity(entity)
            plan.to = EntityParameters.new(
                target.coordinates,
                entity.look_direction,
                entity.down,
                CardinalDirections.CardinalDirection.NONE,
                PositionMode.AIRBOURNE,
            )
            return plan

    return null

func _create_translate_nodes(
    entity: GridEntity,
    movement: Movement.MovementType,
    move_direction: CardinalDirections.CardinalDirection
) -> MovementPlan:
    var from: GridNode = entity.get_grid_node()

    if from.may_exit(entity, move_direction, false, true):
        var target: GridNode = from.neighbour(move_direction)
        if target == null:
            return null

        var plan: MovementPlan = _create_translate_outer_corner(entity, movement, from, move_direction, target)
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
                        movement,
                        MovementMode.TRANSLATE_PLANAR,
                        _settings.translation_duration_scaled,
                        move_direction,
                    )
                    evented_plan.from = EntityParameters.from_entity(entity)
                    evented_plan.to = EntityParameters.new(
                        target.coordinates,
                        entity.look_direction,
                        entity.down,
                        entity.get_grid_anchor_direction(),
                        PositionMode.EVENT_CONTROLLED,
                    )
                    return evented_plan

            var neighbour_anchor: GridAnchor = null if is_flying else target.get_grid_anchor(entity.get_grid_anchor_direction())
            var gravity: CardinalDirections.CardinalDirection = entity.get_level().gravity

            if _verbose:
                print_debug("[Grid Entity %s] Neighbour Anchor %s / Can be in air %s / is flying  %s / can jump from floor %s / can jump from any %s" % [
                    name,
                    neighbour_anchor,
                    entity.transportation_abilities.has_any([TransportationMode.FALLING, TransportationMode.FLYING]),
                    is_flying,
                    entity.get_grid_anchor_direction() == gravity && entity.can_jump_off_floor,
                    entity.can_jump_off_all,
                ])

            if (
                neighbour_anchor == null &&
                entity.transportation_abilities.has_any([TransportationMode.FALLING, TransportationMode.FLYING]) &&
                (is_flying || entity.get_grid_anchor_direction() == gravity && entity.can_jump_off_floor || entity.can_jump_off_all)
            ):
                plan = MovementPlan.new(
                    movement,
                    MovementMode.TRANSLATE_JUMP,
                    _settings.translation_duration_scaled,
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
                    PositionMode.AIRBOURNE,
                )

                return plan

            elif neighbour_anchor == null:
                return _create_translate_refused(entity, movement, move_direction)

            plan = MovementPlan.new(
                movement,
                MovementMode.TRANSLATE_PLANAR,
                _settings.translation_duration_scaled,
                move_direction,
            )
            plan.from = EntityParameters.from_entity(entity)
            plan.to = EntityParameters.new(
                target.coordinates,
                entity.look_direction,
                entity.down,
                entity.get_grid_anchor_direction(),
                PositionMode.NORMAL,
            )

            return plan

    return null

func _create_translate_outer_corner(
    entity: GridEntity,
    movement: Movement.MovementType,
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
            return _create_translate_refused(entity, movement, move_direction)
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
                movement,
                MovementMode.TRANSLATE_OUTER_CORNER,
                _settings.corner_translation_duration_scaled,
                move_direction,
            )
            evented_plan.from = EntityParameters.from_entity(entity)
            evented_plan.to = EntityParameters.new(
                target.coordinates,
                updated_directions[0],
                updated_directions[1],
                updated_directions[1],
                PositionMode.EVENT_CONTROLLED,
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
        movement,
        MovementMode.TRANSLATE_OUTER_CORNER,
        _settings.corner_translation_duration_scaled,
        move_direction,
    )
    plan.from = EntityParameters.from_entity(entity)

    var target_down: CardinalDirections.CardinalDirection = target_anchor.calculate_anchor_down(gravity, updated_directions[1])
    if target_down != target_anchor.direction:
        var look_direction: CardinalDirections.CardinalDirection = target_anchor.direction if !CardinalDirections.is_parallell(target_down, target_anchor.direction) else CardinalDirections.orthogonals(target_down).pick_random()

        plan.to = EntityParameters.new(
            from.coordinates,
            look_direction,
            target_down,
            target_anchor.direction,
            PositionMode.SIDE_FACING,
        )
    else:
        plan.to = EntityParameters.new(
            target.coordinates,
            updated_directions[0],
            target_down,
            target_anchor.direction,
            PositionMode.NORMAL,
        )

    return plan

func _create_translate_inner_corner(
    entity: GridEntity,
    movement: Movement.MovementType,
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
                movement,
                MovementMode.TRANSLATE_INNER_CORNER,
                _settings.corner_translation_duration_scaled,
                move_direction,
            )
            evented_plan.from = EntityParameters.from_entity(entity)
            evented_plan.to = EntityParameters.new(
                from.coordinates,
                updated_directions[0],
                updated_directions[1],
                updated_directions[1],
                PositionMode.EVENT_CONTROLLED,
            )
            return evented_plan

    if !target_anchor.can_anchor(entity):
        return null

    var gravity: CardinalDirections.CardinalDirection = entity.get_level().gravity
    var plan: MovementPlan = MovementPlan.new(
        movement,
        MovementMode.TRANSLATE_INNER_CORNER,
        _settings.corner_translation_duration_scaled,
        move_direction,
    )
    plan.from = EntityParameters.from_entity(entity)

    var target_down: CardinalDirections.CardinalDirection = target_anchor.calculate_anchor_down(gravity, updated_directions[1])
    if target_down != target_anchor.direction:
        var look_direction: CardinalDirections.CardinalDirection = target_anchor.direction if !CardinalDirections.is_parallell(target_down, target_anchor.direction) else CardinalDirections.orthogonals(target_down).pick_random()

        plan.to = EntityParameters.new(
            from.coordinates,
            look_direction,
            target_down,
            target_anchor.direction,
            PositionMode.SIDE_FACING,
        )

    else:

        plan.to = EntityParameters.new(
            from.coordinates,
            updated_directions[0],
            target_down,
            target_anchor.direction,
            PositionMode.NORMAL
        )

    return plan
