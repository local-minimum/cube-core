extends Node
class_name MovementPlanningCoordinator

@export var planners: Array[MovementPlannerBase]

func _enter_tree() -> void:
    if __SignalBus.on_move_plan.connect(_handle_move_plan) != OK:
        push_error("Cannot connect to move plan")

func _exit_tree() -> void:
    __SignalBus.on_move_plan.disconnect(_handle_move_plan)

func _get_planner(entity: GridEntity) -> MovementPlannerBase:
    for planner: MovementPlannerBase in planners:
        if planner.plans_for(entity):
            return planner

    return null

func _handle_move_plan(entity: GridEntity, movement: Movement.MovementType) -> void:
    var planner: MovementPlannerBase = _get_planner(entity)
    if planner == null:
        push_error("No planner exists to allow %s to move" % entity)
        return

    var plan: MovementPlannerBase.MovementPlan = planner.create_plan(entity, movement)
    if plan == null:
        plan = planner.create_no_movement(entity, movement)

    if plan != null:
        # TODO: Decide somehow if a plan is concurrent or no
        entity.execute_plan(plan, 1, false)
