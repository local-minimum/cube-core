extends Node
class_name MovementPlannerBase

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

enum PositionMode {
    NORMAL,
    AIRBOURNE,
    SIDE_FACING,
    EVENT_CONTROLLED,
}

class EntityParameters:
    var coordinates: Vector3i
    var look_direction: CardinalDirections.CardinalDirection
    var down: CardinalDirections.CardinalDirection
    var anchor: CardinalDirections.CardinalDirection
    var mode: PositionMode

    @warning_ignore_start("shadowed_variable")
    func _init(
        coordinates: Vector3i,
        look_direction: CardinalDirections.CardinalDirection,
        down: CardinalDirections.CardinalDirection,
        anchor: CardinalDirections.CardinalDirection,
        standing: PositionMode,
    ) -> void:
        @warning_ignore_restore("shadowed_variable")
        self.coordinates = coordinates
        self.look_direction = look_direction
        self.down = down
        self.anchor = anchor
        self.mode = standing

    var quaternion: Quaternion:
        get():
            return Transform3D.IDENTITY.looking_at(
                Vector3(CardinalDirections.direction_to_vectori(look_direction)),
                Vector3(CardinalDirections.direction_to_vectori(CardinalDirections.invert(down))),
                ).basis.get_rotation_quaternion()

    func equals(other: EntityParameters) -> bool:
        return (
            coordinates == other.coordinates &&
            look_direction == other.look_direction &&
            down == other.down &&
            anchor == other.anchor &&
            mode == other.mode
        )

    static func from_entity(entity: GridEntity) -> EntityParameters:
        var position_mode: PositionMode = PositionMode.NORMAL
        var anchor_direction: CardinalDirections.CardinalDirection = entity.get_grid_anchor_direction()
        if anchor_direction == CardinalDirections.CardinalDirection.NONE:
            position_mode = PositionMode.AIRBOURNE
        elif CardinalDirections.is_parallell(anchor_direction, entity.look_direction):
            position_mode = PositionMode.SIDE_FACING

        return EntityParameters.new(
            entity.coordinates(),
            entity.look_direction,
            entity.down,
            anchor_direction,
            position_mode,
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

    func equals(other: MovementPlan) -> bool:
        return (
            start_time_msec == other.start_time_msec &&
            end_time_msec == other.end_time_msec &&
            mode == mode &&
            from.equals(other.from) &&
            to.equals(other.to) &&
            move_direction == move_direction
        )

    var running: bool:
        get():
            return Time.get_ticks_msec() <= end_time_msec

    var progress: float:
        get():
            return clampf(float(Time.get_ticks_msec() - start_time_msec) / float(end_time_msec - start_time_msec), 0.0, 1.0)

    var remaining_seconds: float:
        get():
            return maxi(0, end_time_msec - Time.get_ticks_msec()) * 0.001

@export var priority: int = 0

func _enter_tree() -> void:
    if __SignalBus.on_move_plan.connect(_handle_move_plan) != OK:
        push_error("Cannot connect to move plan")

func _exit_tree() -> void:
    __SignalBus.on_move_plan.disconnect(_handle_move_plan)

func _handle_move_plan(entity: GridEntity, movement: Movement.MovementType) -> void:
    var plan: MovementPlan = create_plan(entity, movement)
    if plan == null:
        plan = _create_no_movement(entity)

    if plan != null:
        entity.execute_plan(plan, priority)

func create_plan(_entity: GridEntity, _movement: Movement.MovementType) -> MovementPlan:
    return null

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
