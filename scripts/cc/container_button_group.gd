extends Control
class_name ContainerButtonGroup

@export var buttons: Array[ContainerButton]

var interactables: int:
    get():
        return buttons.filter(func (btn: ContainerButton) -> bool: return btn.interactable).size()

var _focus: ContainerButton

func _ready() -> void:
    for button: ContainerButton in buttons:
        if button.on_focus.connect(_handle_button_focus) != OK:
            push_error("Failed to connect button focus")
        if button.visibility_changed.connect(
            func() -> void:
                _handle_visibility_change(button)
        ) != OK:
            push_error("Failed to connect button visibility changed")

func _handle_visibility_change(button: ContainerButton) -> void:
    if visible:
        if button.focused || _focus == button:
            _focus = null
            _select_next(Vector2i.LEFT, null)

func _handle_button_focus(button: ContainerButton) -> void:
    for other: ContainerButton in buttons:
        if button == other:
            continue

        if other.focused:
            other.focused = false

    _focus = button

func _input(event: InputEvent) -> void:
    if !visible || event.is_echo():
        return

    if event.is_action_pressed("ui_up"):
        _select_next(Vector2.UP, event)
    elif event.is_action_pressed("ui_down"):
        _select_next(Vector2.DOWN, event)
    elif event.is_action_pressed("ui_left"):
        _select_next(Vector2.LEFT, event)
    elif event.is_action_pressed("ui_right"):
        _select_next(Vector2.RIGHT, event)

func select_next() -> void:
    _select_next(Vector2.RIGHT, null)

func _select_next(direction: Vector2, event: InputEvent) -> void:
    if _focus == null:
        for button: ContainerButton in buttons:
            if button.visible && button.interactable:
                button.focused = true

                if event != null:
                    get_viewport().set_input_as_handled()
                return
        return

    var sorted: Array[ContainerButton] = buttons.duplicate()
    sorted.sort_custom(
        func (a: ContainerButton, b: ContainerButton) -> bool:
            if a == _focus:
                return false
            if b == _focus:
                return true

            var delta_a = a.position - _focus.position
            var score_a = delta_a.dot(direction) / delta_a.length()
            var delta_b = b.position - _focus.position
            var score_b = delta_b.dot(direction) / delta_b.length()

            # TODO: This sorting isn't very good
            if score_a == 0:
                return false

            if score_b == 0:
                return true

            return score_a > score_b

    )

    if !sorted.is_empty():
        _focus = sorted[0]
        _focus.focused = true

        if event != null:
            get_viewport().set_input_as_handled()
