extends Node
class_name MovementExecutor

@export var _entity: GridEntity

@export var tank_movement: bool

var _active_plan: MovementPlannerBase.MovementPlan
var _active_plan_prio: int
var _tween: Tween

# TODO: Calling end movement is that needed? Probably?
# TODO: Check concurrent movement block codes
# TODO: Handle ducking and such

func execute_plan(plan: MovementPlannerBase.MovementPlan, priority: int) -> void:
    if _active_plan != null && _active_plan_prio > priority || plan == null || plan.equals(_active_plan):
        return

    if _active_plan.running:
        _transition_plans(plan, priority)
    else:
        _start_plan(plan, priority)

func _transition_plans(plan: MovementPlannerBase.MovementPlan, priority: int) -> void:
    # In the future we could ease between in some way maybe
    _start_plan(plan, priority)


func _start_plan(plan: MovementPlannerBase.MovementPlan, priority: int) -> void:
    _active_plan = plan
    _active_plan_prio = priority
    if _tween != null && _tween.is_running():
        _tween.kill()

    if plan.to.mode == MovementPlannerBase.PositionMode.EVENT_CONTROLLED || plan.mode == MovementPlannerBase.MovementMode.NONE:
        return

    _tween = create_tween()

    match plan.mode:
        MovementPlannerBase.MovementMode.ROTATE:
            _create_rotation_tween(_tween, plan)

        MovementPlannerBase.MovementMode.TRANSLATE_PLANAR:
            _create_translate_planar_tween(_tween, plan)

        MovementPlannerBase.MovementMode.TRANSLATE_CENTER:
            _create_translate_center_tween(_tween, plan)

        MovementPlannerBase.MovementMode.TRANSLATE_JUMP:
            _create_translate_jump(_tween, plan)

        MovementPlannerBase.MovementMode.TRANSLATE_LAND:
            _create_translate_land(_tween, plan)

        MovementPlannerBase.MovementMode.NONE:
            return

    if _updates_anchor(plan):
        var target: GridNode = _get_node(plan.to)
        if target != null:
            _entity.update_entity_anchorage(target, target.get_grid_anchor(plan.to.anchor))

func _updates_anchor(plan: MovementPlannerBase.MovementPlan) -> bool:
    var from: GridNode = _get_node(plan.from)
    var to: GridNode = _get_node(plan.to)

    return from == null || to == null || from.get_grid_anchor(plan.from.anchor) != to.get_grid_anchor(plan.to.anchor)

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

func _make_rotation_tween(tween: Tween, plan: MovementPlannerBase.MovementPlan) -> Tween:
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
    if !tank_movement:
         method_tweener.set_trans(Tween.TRANS_SINE)
    @warning_ignore_restore("return_value_discarded")

    return tween

func _create_rotation_tween(tween: Tween, plan: MovementPlannerBase.MovementPlan) -> void:
    tween = _make_rotation_tween(tween, plan)

    @warning_ignore_start("return_value_discarded")
    tween.finished.connect(
        func () -> void:
            _entity.look_direction = plan.to.look_direction
            GridEntity.orient(_entity)
            # _entity.end_movement(movement)
    )
    @warning_ignore_restore("return_value_discarded")

func _make_linear_translation_tween(
    tween: Tween,
    plan: MovementPlannerBase.MovementPlan,
    trans: Tween.TransitionType = Tween.TRANS_SINE,
    ease: Tween.EaseType = Tween.EASE_IN_OUT
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

    if !tank_movement && plan.from.mode != MovementPlannerBase.PositionMode.AIRBOURNE:
        method_tweener.set_trans(trans).set_ease(ease)

    return tween

func _create_translate_planar_tween(tween: Tween, plan: MovementPlannerBase.MovementPlan) -> void:
    tween = _make_linear_translation_tween(tween, plan)

    tween.finished.connect(
        func () -> void:
            _entity.sync_position()
            _entity.remove_concurrent_movement_block()
            #_entity.end_movement(movement)
    )

func _add_rotation_and_finalize_simple_translation_tween(tween: Tween, plan: MovementPlannerBase.MovementPlan) -> void:
    if plan.from.quaternion != plan.to.quaternion:
        _make_rotation_tween(tween.parallel(), plan)

        @warning_ignore_start("return_value_discarded")
        tween.finished.connect(
            func () -> void:
                _entity.look_direction = plan.to.look_direction
                GridEntity.orient(_entity)
                _entity.sync_position()
                _entity.remove_concurrent_movement_block()
                # _entity.end_movement(movement)
        )
        return

    tween.finished.connect(
        func () -> void:
            _entity.sync_position()
            _entity.remove_concurrent_movement_block()
            #_entity.end_movement(movement)
    )
    @warning_ignore_restore("return_value_discarded")

func _create_translate_center_tween(tween: Tween, plan: MovementPlannerBase.MovementPlan) -> void:
    tween = _make_linear_translation_tween(tween, plan)
    _add_rotation_and_finalize_simple_translation_tween(tween, plan)

func _create_translate_jump(tween: Tween, plan: MovementPlannerBase.MovementPlan) -> void:
    tween = _make_linear_translation_tween(tween, plan, Tween.TRANS_SINE, Tween.EASE_OUT)
    _add_rotation_and_finalize_simple_translation_tween(tween, plan)

func _create_translate_land(tween: Tween, plan: MovementPlannerBase.MovementPlan) -> void:
    tween = _make_linear_translation_tween(tween, plan, Tween.TRANS_QUAD, Tween.EASE_OUT)
    _add_rotation_and_finalize_simple_translation_tween(tween, plan)
