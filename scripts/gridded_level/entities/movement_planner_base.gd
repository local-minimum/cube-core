@abstract
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
            if CardinalDirections.is_parallell(look_direction, down):
                push_error("[Entity Parameters] Colinear look direction and down are invalid %s" % [summarize()])

                return Transform3D.IDENTITY.looking_at(
                    Vector3(CardinalDirections.direction_to_vectori(CardinalDirections.orthogonals(down)[0])),
                    Vector3(CardinalDirections.direction_to_vectori(CardinalDirections.invert(down))),
                ).basis.get_rotation_quaternion()

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

    func summarize() -> String:
        return "[%s Look %s / Down %s / Anchor %s %s]" % [
            coordinates,
            CardinalDirections.name(look_direction),
            CardinalDirections.name(down),
            CardinalDirections.name(anchor),
            PositionMode.find_key(mode),
        ]

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
    var movement: Movement.MovementType
    var start_time_msec: int
    var end_time_msec: int
    var mode: MovementMode
    var from: EntityParameters
    var to: EntityParameters
    var move_direction: CardinalDirections.CardinalDirection

    @warning_ignore_start("shadowed_variable")
    func _init(
        movement: Movement.MovementType,
        mode: MovementMode,
        duration: float,
        direction: CardinalDirections.CardinalDirection,
    ) -> void:
        @warning_ignore_restore("shadowed_variable")
        self.movement = movement
        self.mode = mode
        start_time_msec = Time.get_ticks_msec()
        end_time_msec = start_time_msec + roundi(duration * 1000)
        move_direction = direction

    func equals(other: MovementPlan) -> bool:
        if other == null:
            return false

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

    func summarize() -> String:
        return "%s - %s / %s / %s -> %s (%s - %s)" % [
            from.summarize(),
            MovementMode.find_key(mode),
            Movement.name(movement),
            CardinalDirections.name(move_direction),
            to.summarize(),
            start_time_msec,
            end_time_msec,
        ]

@abstract func plans_for(entity: GridEntity) -> bool
@abstract func create_plan(entity: GridEntity, movement: Movement.MovementType) -> MovementPlan

## Requested movement isn't allowed even to be attempted
## Imagine as example rotating on a ladder or trying to jump up into the air to fly but not being able to
func create_no_movement(entity: GridEntity, movement: Movement.MovementType) -> MovementPlan:
    var plan: MovementPlan = MovementPlan.new(
        movement,
        MovementMode.NONE,
        0.0,
        CardinalDirections.CardinalDirection.NONE,
    )
    plan.from = EntityParameters.from_entity(entity)
    plan.to = EntityParameters.from_entity(entity)
    return plan
