extends GridEvent
class_name GridTeleporter

@export var exit: GridTeleporter

@export_group("Exit behavior")
## If set entity look direction will be yawed if possible as the relative rotation between entry and exit portal
@export var infer_look_direction: bool
@export var inherent_forward_direction: CardinalDirections.CardinalDirection
## This only is relevant a static fallback if inferred look direction is set
@export var look_direction: CardinalDirections.CardinalDirection
## If set overrides specific anchor direction and uses entity down in relation to inherent forward (if applies) or entity down else
@export var infer_anchor_from_down: bool
## This only matters if not infer from down is set
@export var anchor_direction: CardinalDirections.CardinalDirection

@export_group("Teleportation abilities")
@export var instant: bool
@export var fade_color: Color = Color.ALICE_BLUE
@export var inactive_scale: float = 0.3
@export var effect: Node3D
@export var rotation_speed: float = 1

@export var mid_time_delay_uncinematic: float = 0.1

var can_teleport: bool:
    get():
        return !_triggered || _repeatable || exit != null

func _ready() -> void:
    super._ready()

    if __SignalBus.on_move_end.connect(_handle_teleport) != OK:
        push_error("Failed to connect on move end")

    if effect != null:
        if exit == null:
            effect.visible = false
        else:
            effect.scale = Vector3.ONE * inactive_scale

func needs_saving() -> bool:
    return _triggered && !_repeatable

func save_key() -> String:
    return "tp-%s" % coordinates()

const _TRIGGERED_KEY: String = "triggered"
func collect_save_data() -> Dictionary:
    return {
        _TRIGGERED_KEY: _triggered
    }

func load_save_data(data: Dictionary) -> void:
    var triggered: bool = DictionaryUtils.safe_getb(data, _TRIGGERED_KEY, false, false)
    _triggered = triggered

func active_for_side(side: CardinalDirections.CardinalDirection) -> bool:
    if _trigger_entire_node:
        return true

    return anchor_direction == side || _trigger_sides.has(side)

func should_trigger(
    feature: GridNodeFeature,
    _from: GridNode,
    _from_side: CardinalDirections.CardinalDirection,
    _to_side: CardinalDirections.CardinalDirection,
) -> bool:
    if exit == null || !available() || !activates_for(feature):
        return false

    return true

## If event blocks entry translation
func blocks_entry_translation(
    _entity: GridEntity,
    _from: GridNode,
    _move_direction: CardinalDirections.CardinalDirection,
    _to_side: CardinalDirections.CardinalDirection,
    _silent: bool = false,
) -> bool:
    return false

## If event blocks entry translation
func blocks_exit_translation(
    _exit_direction: CardinalDirections.CardinalDirection,
) -> bool:
    return false

var _teleporting: Array[GridEntity] = []

func trigger(entity: GridEntity, movement: Movement.MovementType) -> void:
    if _teleporting.has(entity):
        return

    print_debug("%s grabbed %s for teleporting" % [coordinates(), entity])
    _teleporting.append(entity)

    super.trigger(entity, movement)

    if instant:
        return

    _show_effect(entity)

    entity.cause_cinematic(self)

func _show_effect(entity: GridEntity) -> void:
    if effect == null || exit == null:
        return

    var rot: Quaternion = CardinalDirections.direction_to_rotation(
        CardinalDirections.invert(entity.down),
        CardinalDirections.invert(entity.look_direction),
    )

    effect.global_rotation = rot.get_euler()
    effect.scale = Vector3.ONE * inactive_scale
    effect.visible = true

    var tween: Tween = create_tween()

    @warning_ignore_start("return_value_discarded")
    tween.tween_property(effect, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_CUBIC)
    @warning_ignore_restore("return_value_discarded")

    if tween.connect(
        "finished",
        func () -> void:
            effect.scale = Vector3.ONE * inactive_scale
    ) != OK:
        push_warning("Could not disable teleportation effect after done")


func _handle_teleport(entity: GridEntity) -> void:
    if !_teleporting.has(entity):
        return

    __SignalBus.on_teleporter_activate.emit(self, entity, exit)

    if instant:
        _arrive_entity(entity)
        _teleporting.erase(entity)
        __SignalBus.on_teleporter_arrive_entity.emit(exit, entity)
        return

    await get_tree().create_timer(0.1).timeout

    FaderUI.fade_in_out(
        FaderUI.FadeTarget.EXPLORATION_VIEW,
        func() -> void:
            _arrive_entity(entity)
            entity.clear_queue()
            await get_tree().create_timer(mid_time_delay_uncinematic).timeout
            entity.remove_cinematic_cause(self)
            ,
        func () -> void:
            _teleporting.erase(entity)
            __SignalBus.on_teleporter_arrive_entity.emit(exit, entity)
            ,
        fade_color,
    )

    print_debug("Handle teleport of %s from %s to %s" % [entity, coordinates(), "%s" % exit.coordinates() if exit != null else "Nowhere"])

func _arrive_entity(entity: GridEntity) -> void:
    var entry_down: CardinalDirections.CardinalDirection = entity.down
    print_debug("[Grid Teleporter] Exiting entity %s, has look %s and down %s before we start fixing things" % [
        entity,
        CardinalDirections.name(entity.look_direction),
        CardinalDirections.name(entity.down),
    ])

    var exit_node: GridNode = exit.get_grid_node()
    if exit_node == null:
        entity.remove_cinematic_cause(self)
        push_error("Failed to teleport because there was no exit")
        return

    var wanted_anchor_direction: CardinalDirections.CardinalDirection = calculate_exit_anchor_direction(entity)
    var exit_anchor: GridAnchor = exit_node.get_grid_anchor(wanted_anchor_direction)
    if exit_anchor != null:
        print_debug("[Grid Teleporter] Exiting attached to %s (%s), asked for direction %s" % [
            exit_anchor,
            CardinalDirections.name(exit_anchor.direction),
            CardinalDirections.name(wanted_anchor_direction),
            ])
        entity.down = exit_anchor.direction
        entity.set_grid_anchor(exit_anchor)
    else:
        print_debug("[Grid Teleporter] Exiting in the air, asked for direction %s" % [CardinalDirections.name(wanted_anchor_direction)])
        entity.set_grid_node(exit_node)

    if infer_exit_look_direction(entity, entity.look_direction, entry_down, entity.down):
        pass
    elif exit.look_direction != CardinalDirections.CardinalDirection.NONE:
        print_debug("[Grid Teleporter] Using exit look fallback direction")
        entity.look_direction = exit.look_direction
    else:
        print_debug("[Grid Teleporter] Will maintain entity look forward")

    if entity.look_direction == CardinalDirections.CardinalDirection.NONE || CardinalDirections.is_parallell(entity.look_direction, entity.down):
        push_warning("Teleporter exit %s needs to resque look direction of entity %s %s with down %s" % [
            exit,
            entity,
            CardinalDirections.name(entity.look_direction),
            CardinalDirections.name(entity.down),
        ])

        var orthos: Array[CardinalDirections.CardinalDirection] = CardinalDirections.orthogonals(entity.down)
        orthos.shuffle()
        entity.look_direction = orthos[0]

    print_debug("[Grid Teleporter] exit %s has entity %s at %s looking %s with down %s with anchor direction %s" % [
        exit,
        entity,
        entity.coordinates(),
        CardinalDirections.name(entity.look_direction),
        CardinalDirections.name(entity.down),
        CardinalDirections.name(entity.get_grid_anchor_direction()),
    ])
    GridEntity.orient(entity)
    entity.sync_position()

func calculate_exit_anchor_direction(
    entity: GridEntity,
) -> CardinalDirections.CardinalDirection:
    var fallback: CardinalDirections.CardinalDirection = entity.down if exit.infer_anchor_from_down else exit.anchor_direction

    if exit.infer_look_direction:
        if inherent_forward_direction == CardinalDirections.CardinalDirection.NONE || exit.inherent_forward_direction == CardinalDirections.CardinalDirection.NONE:
            push_warning("Teleporter %s's exit %s is configured to infer look direction but active teleporter (%s) and active teleporter (%s) don't both have an inherent forward" % [
                self,
                exit,
                CardinalDirections.name(exit.inherent_forward_direction),
                CardinalDirections.name(inherent_forward_direction),
            ])

            return fallback

        if CardinalDirections.is_parallell(entity.down, inherent_forward_direction):
            push_warning("Teleporter %s must have orthogonal foward to entity down: Teleporter forward %s, entity down %s" % [
                self,
                exit,
                CardinalDirections.name(exit.inherent_forward_direction),
                CardinalDirections.name(entity.down),
                CardinalDirections.name(inherent_forward_direction),
            ])
            return fallback

        var ortho: CardinalDirections.CardinalDirection = CardinalDirections.orthogonal_axis(entity.down, inherent_forward_direction)
        if CardinalDirections.is_parallell(ortho, exit.inherent_forward_direction):
            return fallback

        if CardinalDirections.yaw_cw(inherent_forward_direction, ortho)[0] == entity.down:
            return CardinalDirections.yaw_cw(exit.inherent_forward_direction, ortho)[0]

        return CardinalDirections.yaw_ccw(exit.inherent_forward_direction, ortho)[0]

    return fallback

func infer_exit_look_direction(
    entity: GridEntity,
    entry_look: CardinalDirections.CardinalDirection,
    entry_down: CardinalDirections.CardinalDirection,
    exit_down: CardinalDirections.CardinalDirection,
) -> bool:
    if !exit.infer_look_direction:
        return false

    if inherent_forward_direction == CardinalDirections.CardinalDirection.NONE || exit.inherent_forward_direction == CardinalDirections.CardinalDirection.NONE:
        push_warning("Teleporter %s's exit %s is configured to infer look direction but active teleporter (%s) and active teleporter (%s) don't both have an inherent forward" % [
            self,
            exit,
            CardinalDirections.name(exit.inherent_forward_direction),
            CardinalDirections.name(inherent_forward_direction),
        ])
        return false

    if CardinalDirections.is_parallell(entry_down, inherent_forward_direction) || CardinalDirections.is_parallell(exit_down, exit.inherent_forward_direction):
        push_warning("Teleporter %s and its exit %s must both have orthogonal foward to down: Teleporter forward %s, down %s. Exit forward %s, down %s" % [
            self,
            exit,
            CardinalDirections.name(exit.inherent_forward_direction),
            CardinalDirections.name(exit_down),
            CardinalDirections.name(inherent_forward_direction),
            CardinalDirections.name(entry_down),
        ])
        return false

    print_debug("[Grid Teleporter] Set relative look of %s Entry look %s vs %s" % [
        entity,
        CardinalDirections.name(entry_look),
        CardinalDirections.name(entry_down),
    ])

    if entry_look == inherent_forward_direction:
        print_debug("[Grid Teleporter] We looked in same direction as the teleporter forward so seting exit look direction from exit forward")
        entity.look_direction = exit.inherent_forward_direction
    elif entry_look == CardinalDirections.invert(inherent_forward_direction):
        print_debug("[Grid Teleporter] We looked in opposite direction as the teleporter forward so seting exit opposite look direction from exit forward")
        entity.look_direction = CardinalDirections.invert(exit.inherent_forward_direction)
    elif CardinalDirections.yaw_cw(entry_look, entry_down)[0] == inherent_forward_direction:
        print_debug("[Grid Teleporter] We looked in to the left entering the teleporter relative to its forward so seting exit left look relative to its forward direction")
        entity.look_direction = CardinalDirections.yaw_ccw(exit.inherent_forward_direction, exit_down)[0]
    else:
        print_debug("[Grid Teleporter] We looked in to the right entering the teleporter relative to its forward so seting exit right look relative to its forward direction")
        entity.look_direction = CardinalDirections.yaw_cw(exit.inherent_forward_direction, exit_down)[0]

    return true

func _process(delta: float) -> void:
    if effect == null || !effect.visible || !_teleporting.is_empty():
        return

    effect.global_rotation += CardinalDirections.direction_to_vector(anchor_direction) * delta * rotation_speed
