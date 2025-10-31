extends Control
class_name ContainerButton

signal on_focus(button: ContainerButton)
signal on_unfocus(button: ContainerButton)
signal on_click(button: ContainerButton)
signal on_change_interactable(button: ContainerButton)

@export var _focus_sound: String
@export var _focus_sound_volume: float = 0.4
@export var _focus_target: CanvasItem
@export var _focus_color: Color = Color.HOT_PINK
@export var _default_color: Color = Color.WHITE
@export var _disabled_color: Color = Color.DARK_GRAY
@export var _reclick_delay_msec: int = 100
@export var _managed_unfocus: bool
@export var interactable: bool = true:
    set(value):
        if interactable && !value:
            if _focus_target != null:
                _focus_target.modulate = _disabled_color
            interactable = value
            on_change_interactable.emit(self)
        elif !interactable && value:
            interactable = value
            if _focus_target != null:
                if focused:
                    _focus_target.modulate = _focus_color
                else:
                    _focus_target.modulate = _default_color
            on_change_interactable.emit(self)

var focused: bool = false:
    set(value):
        if !interactable:
            if focused:
                Input.set_default_cursor_shape(Input.CURSOR_ARROW)
                if _focus_target != null:
                    _focus_target.modulate = _disabled_color
                on_unfocus.emit(self)
            focused = false
            return

        if focused:
            Input.set_default_cursor_shape(Input.CURSOR_ARROW)
            if !value:
                if _focus_target != null:
                    _focus_target.modulate = _default_color

                on_unfocus.emit(self)
        else:
            Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
            if value:
                if _focus_target != null:
                    _focus_target.modulate = _focus_color

                if !_focus_sound.is_empty():
                    __AudioHub.play_sfx(_focus_sound, _focus_sound_volume)
                on_focus.emit(self)

        focused = value
    get():
        if !interactable:
            return false
        return focused

func _ready() -> void:
    _click_time = -_reclick_delay_msec

    if _focus_target != null:
        if !interactable:
            _focus_target.modulate = _disabled_color
        elif focused:
            _focus_target.modulate = _focus_color
        else:
            _focus_target.modulate = _default_color

func _on_mouse_exited() -> void:
    if !_managed_unfocus:
        focused = false

func _on_mouse_entered() -> void:
    if interactable:
        focused = true

func _gui_input(event: InputEvent) -> void:
    if !visible || !focused || event.is_echo():
        return

    if event is InputEventMouseButton:
        var mouse_event: InputEventMouseButton = event

        if mouse_event.pressed && mouse_event.button_index == MOUSE_BUTTON_LEFT:
            _click()

    elif event.is_action_pressed("ui_accept"):
        _click()

var _click_time: int

func _click() -> void:
    if !interactable || Time.get_ticks_msec() < _click_time + _reclick_delay_msec:
        return

    _click_time = Time.get_ticks_msec()
    on_click.emit(self)
