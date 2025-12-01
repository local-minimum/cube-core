extends Node
class_name MovementExecutor

@export var _entity: GridEntity
@export var _settings: MovementExecutorSettings
@export var _verbose: bool

var _active_plan_a: MovementPlannerBase.MovementPlan
var _active_plan_prio_a: int
var _tween_a: Tween

var _active_plan_b: MovementPlannerBase.MovementPlan
var _active_plan_prio_b: int
var _tween_b: Tween

var active_plan_prio: int:
    get():
        if _active_plan_b == null && _active_plan_a != null && _active_plan_a.running:
            return _active_plan_prio_a
        if _active_plan_a == null && _active_plan_b != null && _active_plan_b.running:
            return _active_plan_prio_b
        if _active_plan_a != null && _active_plan_b != null && _active_plan_a.running && _active_plan_b.running:
            return maxi(_active_plan_prio_a, _active_plan_prio_b)

        return -1

var has_concurrency_slot: bool:
    get():
        return (
            _active_plan_a == null ||
            _active_plan_b == null ||
            !_active_plan_a.running ||
            !_active_plan_b.running
        )

func execute_plan(plan: MovementPlannerBase.MovementPlan, priority: int, concurrent: bool) -> void:
    if !concurrent && priority < active_plan_prio || plan.equals(_active_plan_a) || plan.equals(_active_plan_b):
        if _verbose:
            print_debug("[Movement Executor %s] Discarding plan %s because of priority or currently running" % [name, plan.summarize()])
        return

    if concurrent && !has_concurrency_slot:
        if _verbose:
            print_debug("[Movement Executor %s] Discarding plan %s because no concurrent slot available" % [name, plan.summarize()])
        return

    elif concurrent:
        if _active_plan_a == null || !_active_plan_a.running:
            if _tween_a != null && _tween_a.is_running():
                _tween_a.kill()

            _tween_a = create_tween()
            _active_plan_a = plan
            _active_plan_prio_a = priority
            _start_plan(plan, _tween_a)
        else:
            if _tween_b != null && _tween_b.is_running():
                _tween_b.kill()

            _tween_b = create_tween()
            _active_plan_b = plan
            _active_plan_prio_b = priority
            _start_plan(plan, _tween_b)

    else:
        if _tween_a != null && _tween_a.is_running():
            _tween_a.kill()
        if _tween_b != null && _tween_b.is_running():
            _tween_b.kill()
        _active_plan_b = null
        _active_plan_prio_b = -1
        _tween_a = create_tween()
        _active_plan_a = plan
        _active_plan_prio_a = priority
        _start_plan(plan, _tween_a)

func _trigger_grid_events(plan: MovementPlannerBase.MovementPlan) -> void:
    var to: GridNode = _get_node(plan.to)
    var from: GridNode = _get_node(plan.from)
    if to == null:
        return

    var events: Array[GridEvent] = to.triggering_events(
            _entity,
            from,
            _entity.get_grid_anchor_direction(),
            plan.move_direction,
        )

    for event: GridEvent in events:
        event.trigger(_entity, plan.movement)

func _handle_ducking(plan: MovementPlannerBase.MovementPlan) -> void:
    if plan.to.mode == plan.from.mode:
        return

    if plan.to.mode == MovementPlannerBase.PositionMode.AIRBOURNE && _settings.ducking_in_the_air:
        _entity.duck()
    elif plan.from.mode == MovementPlanner.PositionMode.AIRBOURNE && _settings.ducking_in_the_air:
        _entity.stand_up()

func _start_plan(plan: MovementPlannerBase.MovementPlan, tween: Tween) -> void:
    if plan.mode == MovementPlannerBase.MovementMode.NONE:
        if _verbose:
            print_debug("[Movement Executor %s] Discarding plan %s of its mode" % [name, plan.summarize()])
        tween.kill()
        return

    _trigger_grid_events(plan)

    if plan.to.mode == MovementPlannerBase.PositionMode.EVENT_CONTROLLED:
        if _verbose:
            print_debug("[Movement Executor %s] Discarding plan %s of its mode" % [name, plan.summarize()])
        tween.kill()
        return

    if _verbose:
        print_debug("[Movement Executor %s] Executing plan %s" % [name, plan.summarize()])

    _handle_ducking(plan)

    match plan.mode:
        MovementPlannerBase.MovementMode.ROTATE:
            _create_rotation_tween(tween, plan)

        MovementPlannerBase.MovementMode.TRANSLATE_PLANAR:
            _create_translate_planar_tween(tween, plan)

        MovementPlannerBase.MovementMode.TRANSLATE_CENTER:
            _create_translate_center_tween(tween, plan)

        MovementPlannerBase.MovementMode.TRANSLATE_JUMP:
            _create_translate_jump_tween(tween, plan)

        MovementPlannerBase.MovementMode.TRANSLATE_LAND:
            _create_translate_land_tween(tween, plan)

        MovementPlannerBase.MovementMode.TRANSLATE_OUTER_CORNER:
            _create_translate_corner_tween(
                tween,
                plan,
                Tween.TRANS_CUBIC,
                Tween.TRANS_QUAD,
            )

        MovementPlannerBase.MovementMode.TRANSLATE_INNER_CORNER:
            _create_translate_corner_tween(
                tween,
                plan,
                Tween.TRANS_LINEAR,
                Tween.TRANS_QUAD,
            )

        MovementPlannerBase.MovementMode.TRANSLATE_FALL_LATERAL:
            _create_translate_fall_lateral_tween(tween, plan)

        MovementPlannerBase.MovementMode.TRANSLATE_REFUSE:
            _create_translate_refuse_tween(tween, plan)

        MovementPlannerBase.MovementMode.NONE:
            tween.kill()
            return

        _:
            push_error("[Movement Planner %s] got plan of unhandled movement type for %s" % [
                name,
                plan.summarize(),
                _entity,
            ])
            tween.kill()
            return

    __SignalBus.on_move_start.emit(_entity, plan.from.coordinates, plan.move_direction)

    if _updates_anchor(plan):
        var target: GridNode = _get_node(plan.to)
        if target != null:
            var anchor: GridAnchor = target.get_grid_anchor(plan.to.anchor)
            if _verbose:
                print_debug("[Movement Executor %s] Plan %s updates anchor of %s from <%s> to <%s>" % [
                    name,
                    plan.summarize(),
                    _entity,
                    GridAnchor.summarize(_entity.get_grid_anchor()),
                    GridAnchor.summarize(anchor),
                ])

            _entity.down = plan.to.down
            _entity.update_entity_anchorage(target, anchor, true)
        else:
            push_error("[Movement Executor %s] Plan %s target node cannot be found" % [name, plan.summarize()])
    else:
        if _verbose:
            print_debug("[Movement Executor %s] Plan %s maintains anchor" % [name, plan.summarize()])

    if _settings.instant_step:
        _fast_forward_tween(tween, plan)

func _fast_forward_tween(tween: Tween, plan: MovementPlannerBase.MovementPlan) -> void:
    var step: float = max((plan.end_time_msec - plan.start_time_msec) * 0.001, 1)
    while tween.custom_step(step):
        pass

func _updates_anchor(plan: MovementPlannerBase.MovementPlan) -> bool:
    var from: GridNode = _get_node(plan.from)
    var to: GridNode = _get_node(plan.to)

    return from == null || to == null || from != to || from.get_grid_anchor(plan.from.anchor) != to.get_grid_anchor(plan.to.anchor)

func _get_node(params: MovementPlannerBase.EntityParameters) -> GridNode:
    var level: GridLevelCore = _entity.get_level()
    if level == null:
        push_error("%s is not inside any level, cannot get node at %s" % [level, params.coordinates])
        return null

    return level.get_grid_node(params.coordinates)

func _get_position(params: MovementPlannerBase.EntityParameters) -> Vector3:
    var node: GridNode = _get_node(params)
    if node == null:
        return Vector3.ZERO

    var anchor: GridAnchor = node.get_grid_anchor(params.anchor)
    if anchor != null:
        return anchor.global_position

    return GridNode.get_center_pos(node, node.level)

func _make_rotation_tween(
    tween: Tween,
    plan: MovementPlannerBase.MovementPlan,
    tween_trans: Tween.TransitionType = Tween.TRANS_SINE,
    tween_ease: Tween.EaseType = Tween.EASE_IN
) -> Tween:
    var rotation_method: Callable = QuaternionUtils.create_tween_rotation_progress_method(
        _entity,
        plan.from.quaternion,
        plan.to.quaternion,
    )

    var method_tweener: MethodTweener = tween.tween_method(
        rotation_method,
        plan.progress,
        1.0,
        plan.remaining_seconds,
    )

    @warning_ignore_start("return_value_discarded")
    if !_settings.tank_movement:
         method_tweener.set_trans(tween_trans).set_ease(tween_ease)
    @warning_ignore_restore("return_value_discarded")

    return tween

func _create_rotation_tween(tween: Tween, plan: MovementPlannerBase.MovementPlan) -> void:
    tween = _make_rotation_tween(tween, plan, Tween.TRANS_LINEAR)

    # This should not be in finished since we update logical look and down immediately and just let animations play catch up!
    _entity.look_direction = plan.to.look_direction

    @warning_ignore_start("return_value_discarded")
    tween.finished.connect(
        func () -> void:
            GridEntity.orient(_entity)
            _entity.end_movement(plan.movement)
    )
    @warning_ignore_restore("return_value_discarded")

func _make_linear_translation_tween(
    tween: Tween,
    plan: MovementPlannerBase.MovementPlan,
    tween_trans: Tween.TransitionType = Tween.TRANS_SINE,
    tween_ease: Tween.EaseType = Tween.EASE_IN_OUT,
    force_tank_movement: bool = false,
) -> Tween:
    var from: Vector3 = _get_position(plan.from)
    var to: Vector3 = _get_position(plan.to)

    var translation_method: Callable = func (progress: float) -> void:
        _entity.global_position = from.lerp(to, progress)

    var method_tweener: MethodTweener = tween.tween_method(
        translation_method,
        plan.progress,
        1.0,
        plan.remaining_seconds,
    )

    if !_settings.tank_movement && !force_tank_movement:
        method_tweener.set_trans(tween_trans).set_ease(tween_ease)

    return tween

func _make_midpoint_translation_tween(
    tween: Tween,
    plan: MovementPlannerBase.MovementPlan,
    mid_point: Vector3,
    tween_trans: Tween.TransitionType = Tween.TRANS_SINE,
    tween_ease: Tween.EaseType = Tween.EASE_IN_OUT,
    force_tank_movement: bool = false,
    bounce_back: bool = false,
) -> Tween:
    var from: Vector3 = _get_position(plan.from)
    var to: Vector3 = _get_position(plan.to)

    var translation_method: Callable = func (progress: float) -> void:
        if progress < 0.5:
            _entity.global_position = from.lerp(mid_point, progress * 2)
        _entity.global_position = mid_point.lerp(to, (progress - 0.5) * 2.0)

    var duration: float = plan.remaining_seconds

    var method_tweener: MethodTweener = tween.tween_method(
        translation_method,
        plan.progress,
        1.0,
        duration if !bounce_back else duration * 0.5,
    )

    if !_settings.tank_movement && !force_tank_movement:
        method_tweener.set_trans(tween_trans).set_ease(tween_ease)

    if bounce_back:
        method_tweener = tween.tween_method(
            translation_method,
            1.0,
            0.0,
            duration * 0.5,
        )

    if !_settings.tank_movement && !force_tank_movement:
        method_tweener.set_trans(tween_trans).set_ease(tween_ease)

    return tween

func _create_translate_planar_tween(tween: Tween, plan: MovementPlannerBase.MovementPlan) -> void:
    tween = _make_linear_translation_tween(
        tween,
        plan,
        Tween.TRANS_SINE,
        Tween.EASE_IN_OUT,
        plan.from.mode == MovementPlannerBase.PositionMode.AIRBOURNE,
    )

    tween.finished.connect(
        func () -> void:
            _entity.sync_position()
            _entity.remove_concurrent_movement_block()
            _entity.end_movement(plan.movement)
    )

func _add_rotation_and_finalize_simple_translation_tween(tween: Tween, plan: MovementPlannerBase.MovementPlan) -> void:
    if plan.from.quaternion != plan.to.quaternion:
        _make_rotation_tween(tween.parallel(), plan)

        # This should not be in finished since we update to new down right as we start the animation
        _entity.look_direction = plan.to.look_direction

        @warning_ignore_start("return_value_discarded")
        tween.finished.connect(
            func () -> void:
                GridEntity.orient(_entity)
                _entity.sync_position()
                _entity.remove_concurrent_movement_block()
                _entity.end_movement(plan.movement)
        )
        return

    tween.finished.connect(
        func () -> void:
            _entity.sync_position()
            _entity.remove_concurrent_movement_block()
            _entity.end_movement(plan.movement)
    )
    @warning_ignore_restore("return_value_discarded")

func _create_translate_center_tween(tween: Tween, plan: MovementPlannerBase.MovementPlan) -> void:
    tween = _make_linear_translation_tween(tween, plan)
    _add_rotation_and_finalize_simple_translation_tween(tween, plan)

func _create_translate_jump_tween(tween: Tween, plan: MovementPlannerBase.MovementPlan) -> void:
    tween = _make_linear_translation_tween(tween, plan, Tween.TRANS_SINE, Tween.EASE_OUT)
    _add_rotation_and_finalize_simple_translation_tween(tween, plan)

func _create_translate_land_tween(tween: Tween, plan: MovementPlannerBase.MovementPlan) -> void:
    tween = _make_linear_translation_tween(tween, plan, Tween.TRANS_QUAD, Tween.EASE_OUT)
    _add_rotation_and_finalize_simple_translation_tween(tween, plan)

func _get_corner_midpoint(plan: MovementPlannerBase.MovementPlan) -> Vector3:
    var to_node: GridNode = _get_node(plan.to)
    var from_node: GridNode = _get_node(plan.from)
    if to_node == null || from_node == null:
        if to_node != null:
            return to_node.global_position
        if from_node != null:
            return from_node.global_position
        return Vector3.ZERO

    var to_anchor: GridAnchor = to_node.get_grid_anchor(plan.to.anchor)
    var from_anchor: GridAnchor = from_node.get_grid_anchor(plan.from.anchor)
    if to_anchor == null || from_anchor == null:
        return to_node.global_position.lerp(from_node.global_position, 0.5)

    match plan.mode:
        MovementPlannerBase.MovementMode.TRANSLATE_INNER_CORNER:
            var to_edge: Vector3 = to_anchor.global_position.lerp(to_anchor.get_edge_position(plan.from.anchor), _settings.inner_corner_translation_fraction)
            var from_edge: Vector3 = from_anchor.global_position.lerp(from_anchor.get_edge_position(plan.to.anchor), _settings.inner_corner_translation_fraction)
            return to_edge.lerp(from_edge, 0.5)

        MovementPlannerBase.MovementMode.TRANSLATE_OUTER_CORNER:
            var to_edge: Vector3 = to_anchor.get_edge_position(CardinalDirections.invert(plan.from.anchor))
            var from_edge: Vector3 = from_anchor.get_edge_position(CardinalDirections.invert(plan.to.anchor))
            return to_edge.lerp(from_edge, 0.5)

        _:
            return to_anchor.global_position.lerp(from_anchor.global_position, 0.5)

func _create_translate_corner_tween(tween: Tween, plan: MovementPlannerBase.MovementPlan, move_trans: Tween.TransitionType, rotation_trans: Tween.TransitionType) -> void:
    tween = _make_midpoint_translation_tween(
        tween,
        plan,
        _get_corner_midpoint(plan),
        move_trans,
        Tween.EASE_IN,
        true,
    )

    @warning_ignore_start("return_value_discarded")
    _make_rotation_tween(tween.parallel(), plan, rotation_trans, Tween.EASE_IN_OUT)

    # This should not be in finished since we update to new down right as we start the animation
    _entity.look_direction = plan.to.look_direction

    tween.finished.connect(
        func () -> void:
            GridEntity.orient(_entity)
            _entity.sync_position()
            _entity.remove_concurrent_movement_block()
            _entity.end_movement(plan.movement)
    )
    @warning_ignore_restore("return_value_discarded")

func _create_translate_fall_lateral_tween(tween: Tween, plan: MovementPlannerBase.MovementPlan) -> void:
    tween = _make_linear_translation_tween(
        tween,
        plan,
        Tween.TRANS_QUAD,
        Tween.EASE_OUT,
        plan.to.mode == MovementPlannerBase.PositionMode.AIRBOURNE,
    )
    _add_rotation_and_finalize_simple_translation_tween(tween, plan)

func _create_translate_refuse_tween(tween: Tween, plan: MovementPlannerBase.MovementPlan) -> void:
    var node: GridNode = _get_node(plan.from)
    if node == null:
        return

    var origin: Vector3 = GridNode.get_center_pos(node, node.level)
    var edge: Vector3 = node.global_position
    var anchor: GridAnchor = node.get_grid_anchor(plan.to.anchor)
    if anchor == null:
        edge = GridNode.get_center_pos(node, node.level) + CardinalDirections.direction_to_vector(plan.move_direction) * node.level.node_size
    else:
        origin = anchor.global_position
        edge = anchor.get_edge_position(plan.move_direction)

    var distance: float = _settings.refuse_distance_factor_lateral
    if plan.from.look_direction == plan.move_direction:
        distance = _settings.refuse_distance_factor_forward
    elif CardinalDirections.is_parallell(plan.from.look_direction, plan.move_direction):
        distance = _settings.refuse_distance_factor_reverse

    if plan.from.mode == MovementPlannerBase.PositionMode.AIRBOURNE:
        distance *= _settings.airbourne_refuse_distance_factor

    tween = _make_midpoint_translation_tween(
        tween,
        plan,
        origin.lerp(edge, distance),
        Tween.TRANS_SINE,
        Tween.EASE_IN,
        true,
        true,
    )
    _add_rotation_and_finalize_simple_translation_tween(tween, plan)
