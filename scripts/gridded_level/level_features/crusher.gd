extends GridEvent
class_name Crusher

enum LiveMode { TURN_BASED, FULL_LIVE, LIVE_ONE_SHOT, LIVE_HALF_SHOT }

enum Phase { RETRACTED, CRUSHING, CRUSHED, RETRACTING }
static func phase_from_int(phase_value: int) -> Phase:
    match phase_value:
        0: return Phase.RETRACTED
        1: return Phase.CRUSHING
        2: return Phase.CRUSHED
        3: return Phase.RETRACTING
        _: return Phase.RETRACTED

## Overridden by adding "managed" as meta to the grid node side
## If managed it will not trigger by walking
@export var _managed: bool
@export var _side: GridNodeSide
@export var _moving_part_root: Node3D

## Note: This has no effect when managed
@export var _rest_crushed_ticks: int = 2
## Note: This has no effect when managed
@export var _rest_retracted_ticks: int = 3
@export var _start_delay_ticks: int = 0

## When retracted should crusher side be blocked
@export var _always_block_crusher_side: bool = true

@export var _block_retracting_seconds: float = 0.3
## The side the crusher is anchored on. Note that if grid node side is set then it overrides this value
@export var _crusher_side: CardinalDirections.CardinalDirection = CardinalDirections.CardinalDirection.UP:
    get():
        if _side != null:
            return _side.direction
        return _crusher_side

@export var _crush_check_delay: float = 0.05
@export var _anim: AnimationPlayer

@export var _retracted_resting_anim: String = "Retracted"
@export var _crushed_resting_anim: String = "Crushed"
@export var _crush_anim: String = "Crush"
@export var _retract_anim: String = "Retract"

@export var _crushing_sound: String
@export var _crushed_sound: String

## In many cases you want this live, especially when managed
@export var _live: LiveMode = LiveMode.TURN_BASED
@export var _live_tick_duration_msec: int = 500
## Overriden by adding "add_anchors_when_extended" as meta to the grid node side
@export var _add_anchors_when_extended: bool = false
@export var _anchor_position_overshoot: float

var _phase: Phase = Phase.RETRACTED:
    set(value):
        var updated: bool = _phase != value
        _phase = value
        match _phase:
            Phase.RETRACTED:
                _sync_blocking_retracted()
                _phase_ticks = _rest_retracted_ticks

            Phase.CRUSHING:
                _triggered = true
                _sync_blocking_retracted()
                _phase_ticks = 1

            Phase.CRUSHED:
                _blocks_sides = CardinalDirections.ALL_DIRECTIONS.duplicate()
                _phase_ticks = _rest_crushed_ticks

            Phase.RETRACTING:
                _blocks_sides = CardinalDirections.ALL_DIRECTIONS.duplicate()
                _phase_ticks = 1
                await get_tree().create_timer(_block_retracting_seconds).timeout
                _sync_blocking_retracted()

            _:
                _sync_blocking_retracted()

        if updated:
            __SignalBus.on_change_crusher_phase.emit(self, value)

var _phase_ticks: int
var _exposed: Array[GridEntity]
var _last_tick: int
var _extended_anchors_active: bool
var _extended_anchors: Array[GridAnchor]

func register_receiver_contract(contract: BroadcastContract, broadcaster_type: Broadcaster.BroadcasterType) -> void:
    match broadcaster_type:
        Broadcaster.BroadcasterType.PRESSURE_PLATE:
            if contract.messages.size() == 2:
                contract.register_receiver(0, self, _handle_crush)
                contract.register_receiver(1, self, _handle_retract)
                print_debug("[Broadcast Receiver] Configured Crusher %s as managed to receive %s crush/retract messages'" % [
                    BroadcastContract.get_broadcaster_name(contract),
                    Broadcaster.name(broadcaster_type),
                ])
            elif contract.messages.size() == 1:
                contract.register_receiver(0, self, _handle_toggle)
                print_debug("[Broadcast Receiver] Configured Crusher %s as managed to receive %s toggle mode message'" % [
                    BroadcastContract.get_broadcaster_name(contract),
                    Broadcaster.name(broadcaster_type),
                ])


func _ready() -> void:
    super._ready()

    var side: GridNodeSide = GridNodeSide.find_node_side_parent(self, true)
    _add_anchors_when_extended = get_bool_override(side, "add_anchors_when_extended", _add_anchors_when_extended)
    _managed = get_bool_override(side, "managed", _managed)

    if __SignalBus.on_change_node.connect(_handle_change_node) != OK:
        push_error("Failed to connect change node")

    if __SignalBus.on_move_end.connect(_handle_move_end) != OK:
        push_error("Failed to connect move end")

    _phase = Phase.RETRACTED
    _phase_ticks = _start_delay_ticks

func _process(_delta: float) -> void:
    if !_managed && _live == LiveMode.FULL_LIVE || _live == LiveMode.LIVE_ONE_SHOT && _phase != Phase.RETRACTED || _live == LiveMode.LIVE_HALF_SHOT && _phase !=  Phase.CRUSHED && _phase != Phase.RETRACTED:
        if Time.get_ticks_msec() - _last_tick > _live_tick_duration_msec:
            _progress_phase_cycle()
            _last_tick = Time.get_ticks_msec()

func _handle_toggle() -> void:
    if !available():
        return

    if _live != LiveMode.LIVE_ONE_SHOT && (_phase == Phase.CRUSHING || _phase == Phase.CRUSHED):
        if _repeatable || !_triggered:
            _phase = Phase.RETRACTING
            if _extended_anchors_active:
                _disable_extended_anchors()
            _anim.play(get_animation())
            _last_tick = Time.get_ticks_msec()
    elif _phase == Phase.RETRACTED || _phase == Phase.RETRACTING:
        _phase = Phase.CRUSHING
        if !_crushing_sound.is_empty():
            __AudioHub.play_sfx(_crushing_sound)

        if _add_anchors_when_extended && !_extended_anchors_active:
            _add_extended_anchors()
        _anim.play(get_animation())
        _check_crushing()
        _last_tick = Time.get_ticks_msec()

func _handle_retract() -> void:
    if !available():
        return

    if _live != LiveMode.LIVE_ONE_SHOT && (_phase == Phase.CRUSHING || _phase == Phase.CRUSHED):
        if _repeatable || !_triggered:
            _phase = Phase.RETRACTING
            if _extended_anchors_active:
                _disable_extended_anchors()
            _anim.play(get_animation())
            _last_tick = Time.get_ticks_msec()

func _handle_crush() -> void:
    if !available():
        return

    if _phase == Phase.RETRACTED || _phase == Phase.RETRACTING:
        _phase = Phase.CRUSHING
        if _add_anchors_when_extended && !_extended_anchors_active:
            _add_extended_anchors()
        _anim.play(get_animation())
        _check_crushing()
        _last_tick = Time.get_ticks_msec()

func _handle_change_node(feature: GridNodeFeature) -> void:
    if feature is not GridEntity:
        return

    var entity: GridEntity = feature
    if entity.coordinates() == coordinates():
        if !_exposed.has(entity):
            _exposed.append(entity)
    elif _exposed.has(entity):
        _exposed.erase(entity)

func _handle_move_end(entity: GridEntity) -> void:
    if entity is not GridPlayerCore || _managed:
        return

    if _live == LiveMode.TURN_BASED && !_managed:
        _progress_phase_cycle()

func _progress_phase_cycle() -> void:
        _phase_ticks -= 1
        if _phase_ticks <= 0:
            _phase = get_next_phase()

            _anim.play(get_animation())
            if _phase == Phase.CRUSHING:
                _check_crushing()

func _check_crushing() -> void:
    await get_tree().create_timer(_crush_check_delay).timeout
    var crush_direction: CardinalDirections.CardinalDirection = CardinalDirections.invert(_crusher_side)
    var node: GridNode = get_grid_node()

    var neighbour: GridNode = null
    match node.has_side(crush_direction):
        GridNode.NodeSideState.ILLUSORY, GridNode.NodeSideState.NONE:
            neighbour = node.neighbour(crush_direction)
        GridNode.NodeSideState.DOOR:
            var door: GridDoorCore = node.get_door(crush_direction)
            if door != null && door.lock_state == GridDoorCore.LockState.OPEN:
                neighbour = node.neighbour(crush_direction)

    for exposed: GridEntity in _exposed:
        if exposed == null || !is_instance_valid(exposed) || !exposed.is_inside_tree():
            continue

        var moved: bool = false

        if (
            neighbour != null &&
            node.may_exit(exposed, crush_direction, false, true) &&
            neighbour.may_enter(exposed, node, crush_direction, exposed.get_grid_anchor_direction(), false, false, true)
        ):
            moved = exposed.force_movement(
                Movement.from_directions(crush_direction, exposed.look_direction, exposed.down)
            )

        if !moved:
            if exposed is GridPlayerCore:
                var player: GridPlayerCore = exposed
                player.kill()
            elif exposed is GridEncounterCore:
                var encounter: GridEncounterCore = exposed
                encounter.kill()

func _sync_blocking_retracted() -> void:
    if _always_block_crusher_side:
        _blocks_sides = [_crusher_side]
    else:
        _blocks_sides = []

func get_next_phase() -> Phase:
    match _phase:
        Phase.RETRACTED:
            if !available():
                return Phase.RETRACTED

            return Phase.CRUSHING
        Phase.CRUSHING:
            if !_crushing_sound.is_empty():
                __AudioHub.play_sfx(_crushing_sound)
            if _add_anchors_when_extended && !_extended_anchors_active:
                _add_extended_anchors()
            return Phase.CRUSHED
        Phase.CRUSHED:
            if !_crushed_sound.is_empty():
                __AudioHub.play_sfx(_crushed_sound)
            if _add_anchors_when_extended && !_extended_anchors_active:
                _add_extended_anchors()

            if !available():
                return Phase.CRUSHED
            return Phase.RETRACTING
        Phase.RETRACTING:
            if _extended_anchors_active:
                _disable_extended_anchors()
            return Phase.RETRACTED
        _:
            push_error("Unknown phase %s" % _phase)
            return Phase.RETRACTED

func get_animation() -> String:
    match _phase:
        Phase.RETRACTED:
            return _retracted_resting_anim
        Phase.CRUSHING:
            return _crush_anim
        Phase.CRUSHED:
            return _crushed_resting_anim
        Phase.RETRACTING:
            return _retract_anim
        _:
            push_error("Unknown phase %s" % _phase)
            return _retracted_resting_anim

func _disable_extended_anchors() -> void:
    _extended_anchors_active = false
    for extended_anchor: GridAnchor in _extended_anchors:
        extended_anchor.disabled = true

func _add_extended_anchors() -> void:
    _extended_anchors_active = true
    if !_extended_anchors.is_empty():
        for extenden_anchor: GridAnchor in _extended_anchors:
            extenden_anchor.disabled = false

        return

    var grid_node: GridNode = GridNode.find_node_parent(self, true)
    for direction: CardinalDirections.CardinalDirection in CardinalDirections.ALL_DIRECTIONS:
        var inv_direction: CardinalDirections.CardinalDirection = CardinalDirections.invert(direction)
        var neighbour: GridNode = grid_node.neighbour(direction)
        if neighbour == null:
            print_debug("[Crusher] Node %s has no neighbour in direction %s" % [grid_node, CardinalDirections.name(direction)])
            continue

        match neighbour.has_side(inv_direction):
            GridNode.NodeSideState.DOOR, GridNode.NodeSideState.SOLID:
                print_debug("[Crusher] Node %s will skip adding anchor to neighbour %s because has stuff on side %s" % [
                    grid_node,
                    neighbour,
                    CardinalDirections.name(inv_direction),
                ])
                continue

        print_debug("[Crusher] Node %s asks %s to add an anchor in direction %s because its side states is %s" % [
            grid_node,
            neighbour,
            CardinalDirections.name(inv_direction),
            neighbour.has_side(inv_direction)
        ])
        var new_anchor: GridAnchor = GridAnchor.new()
        new_anchor.name = "Anchor %s" % CardinalDirections.name(inv_direction)
        new_anchor.direction = inv_direction
        new_anchor.required_transportation_mode = TransportationMode.create_from_direction(inv_direction)
        if neighbour.add_anchor(new_anchor):
            new_anchor.global_position = (
                # We are placing them as if they were on ourselves because we are doing it before we extend
                GridNode.get_center_pos(grid_node, grid_node.level) +
                CardinalDirections.direction_to_vector(_crusher_side) * grid_node.get_level().node_size +
                _anchor_position_overshoot * CardinalDirections.direction_to_vector(direction) +
                CardinalDirections.direction_to_vector(direction) * grid_node.get_level().node_size * 0.5
            )
            if CardinalDirections.ALL_PLANAR_DIRECTIONS.has(inv_direction):
                new_anchor.global_rotation = Transform3D.IDENTITY.looking_at(CardinalDirections.direction_to_vector(inv_direction)).basis.get_euler()

            # We want to reparent the anchor to the moving part of the crusher to have it look reasonable in the world if it
            # will retract
            if _moving_part_root != null:
                var side: GridNodeSide = GridNodeSide.new()
                side.name = "Side %s of %s" % [CardinalDirections.name(inv_direction), neighbour.name]
                side.infer_direction_from_rotation = false
                side.direction = direction
                side.negative_anchor = new_anchor

                _moving_part_root.add_child(side)
                new_anchor.reparent(side)

                if inv_direction == _crusher_side:
                    var own_anchor: GridAnchor = grid_node.get_grid_anchor(inv_direction)
                    if own_anchor != null:
                        for child in own_anchor.get_children(true):
                            if child is Node3D:
                                var node3d: Node3D = child
                                var child_t: Transform3D = node3d.transform
                                print_debug("[Crusher] Reparenting %s to %s" % [child, new_anchor])
                                child.reparent(new_anchor, true)
                                child.transform = child_t

                    else:
                        print_debug("[Crusher] No anchor in crusher direction %s" % [CardinalDirections.name(_crusher_side)])

            _extended_anchors.append(new_anchor)
        else:
            push_error("Crusher failed to add anchor %s to %s for unknown reasons" % [new_anchor, neighbour])
            new_anchor.queue_free()

func trigger(_entity: GridEntity, _movement: Movement.MovementType) -> void:
    # We don't trigger this way
    pass

func needs_saving() -> bool:
    return true

func save_key() -> String:
    return "cr-%s-%s" % [coordinates(), CardinalDirections.name(_crusher_side)]

const _PHASE_KEY: String = "phase"
const _PHASE_TICK_KEY: String = "tick"
const _TRIGGERED_KEY: String = "triggered"
const _LIVE_TIME_KEY: String = "live_time"

func collect_save_data() -> Dictionary:
    return {
        _PHASE_KEY: _phase,
        _PHASE_TICK_KEY: _phase_ticks,
        _TRIGGERED_KEY: _triggered,
        _LIVE_TIME_KEY: Time.get_ticks_msec() - _last_tick
    }

func load_save_data(_data: Dictionary) -> void:
    _triggered = DictionaryUtils.safe_getb(_data, _TRIGGERED_KEY)

    var raw_phase: int = DictionaryUtils.safe_geti(_data, _PHASE_KEY)
    _phase = phase_from_int(raw_phase)
    _phase_ticks = DictionaryUtils.safe_geti(_data, _PHASE_TICK_KEY)
    _exposed.clear()

    var live_time: int = DictionaryUtils.safe_geti(_data, _LIVE_TIME_KEY, _live_tick_duration_msec)
    _last_tick = Time.get_ticks_msec() - live_time

    var level: GridLevelCore = get_level()
    var coords: Vector3i = coordinates()

    for entity: GridEntity in level.grid_entities:
        if entity.coordinates() == coords:
            _exposed.append(entity)
