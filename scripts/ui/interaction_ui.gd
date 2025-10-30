extends Control
class_name InteractionUI

@export var _auto_end: bool = true
@export_range(1, 10) var _max_interactables: int = 5
@export var _viz: InteractionUIViz

var _interactables: Array[Interactable]
var _interacting: bool
var _requested: bool
var _moving: bool
var _active: Dictionary[String, Interactable]
var _cinematic: bool
var _mode: BindingHints.InputMode = BindingHints.InputMode.KEYBOARD_AND_MOUSE

func _enter_tree() -> void:
    if __SignalBus.on_allow_interactions.connect(_handle_allow_interaction) != OK:
        push_error("Failed to connect allow interactions")

    if __SignalBus.on_disallow_interactions.connect(_handle_disallow_interaction) != OK:
        push_error("Failed to connect disallow interactions")

    if __SignalBus.on_move_start.connect(_handle_move_start) != OK:
        push_error("Failed to connect move start")

    if __SignalBus.on_move_end.connect(_handle_move_end) != OK:
        push_error("Failed to connect move end")

    if __SignalBus.on_cinematic.connect(_handle_cinematic) != OK:
        push_error("Failed to connect cinematic")

    if __SignalBus.on_update_input_mode.connect(_handle_update_input_mode) != OK:
        push_error("Failed to connect update input mode")

func _ready() -> void:
    _mode = (__BindingHints as BindingHints).mode

func _handle_update_input_mode(mode: BindingHints.InputMode) -> void:
    _mode = mode
    queue_redraw()

func _handle_cinematic(entity: GridEntity, cinematic: bool) -> void:
    if entity is not GridPlayerCore:
        return

    _cinematic = cinematic
    if _interacting:
        _interacting = false
        queue_redraw()


func _handle_allow_interaction(interactable: Interactable) -> void:
    if !_interactables.has(interactable):
        _interactables.append(interactable)

        if _interacting:
            queue_redraw()

func _handle_disallow_interaction(interactable: Interactable) -> void:
    _interactables.erase(interactable)

    if _interacting:
        queue_redraw()

func _handle_move_start(entity: GridEntity, _from: Vector3i, _translation_direction: CardinalDirections.CardinalDirection) -> void:
    if entity is not GridPlayerCore:
        return

    var was_interacting: bool = _interacting
    _moving = true
    _interacting = false
    _requested = false

    if was_interacting:
        queue_redraw()

func _handle_move_end(entity: GridEntity) -> void:
    if entity is not GridPlayerCore:
        return

    _moving = false
    _interacting = _requested
    _requested = false

    if _interacting:
        queue_redraw()

func _draw() -> void:
    _active.clear()

    if !_interacting:
        return

    var idx: int = 1
    for interactable: Interactable in _calculate_within_reach():
        if idx > _max_interactables:
            push_warning("Cannot show interactable %s because exceeding limit of %s at a time" % [interactable, _max_interactables])
            continue

        var id_key: String = _get_key_id(idx)
        _active[id_key] = interactable

        _viz.draw_interactable_ui(self, id_key, interactable)

        idx += 1

func _get_key_id(idx: int) -> String: return "hot_key_%s" % idx

func _calculate_within_reach() -> Array[Interactable]:
    return _interactables.filter(
        func (interactable: Interactable) -> bool:
            return  interactable.is_interactable && interactable.player_is_in_range()
    )

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("crawl_search"):
        if _moving:
            _requested = true
            print_debug("[Interaction UI] Requested %s" % _requested)
        else:
            _interacting = !_interacting
            print_debug("[Interaction UI] Interaction %s" % _interacting)
            queue_redraw()

    elif _interacting:
        for idx: int in range(1, _max_interactables + 1):
            var key: String = _get_key_id(idx)
            if event.is_action_pressed(key):
                _activate_hotkey_interaction(idx)
                break

func _activate_hotkey_interaction(idx: int) -> void:
    var interactable: Interactable = _active.get(_get_key_id(idx), null)
    if interactable != null:
        if interactable.check_allow_interact():
            interactable.execute_interation()

            if _auto_end:
                _interacting = false
                queue_redraw()
