extends Control
class_name MenuDialog

enum Mode {RETURN_LETTERS, HINT_WORDS, HINT_EXPLORATION, HINT_ROOM, HINT_CAT, WARN_RESTART, WARN_QUIT }

@export var _return_letters: Array[Control]
@export var _hint_words: Array[Control]
@export var _hint_exploration: Array[Control]
@export var _hint_room: Array[Control]
@export var _hint_cat: Array[Control]
@export var _warn_progress: Array[Control]

@export var _title: CensoringLabel
@export var _positive_button: ContainerButton
@export var _positive_label: CensoringLabel
@export var _negative_button: ContainerButton
@export var _negative_label: CensoringLabel


var _all_parts: Array[Control]:
    get():
        return _return_letters + _hint_words + _hint_exploration + _hint_room + _hint_cat

func _get_parts(mode: Mode) -> Array[Control]:
    match mode:
        Mode.RETURN_LETTERS:
            return _return_letters
        Mode.HINT_WORDS:
            return _hint_words
        Mode.HINT_EXPLORATION:
            return _hint_exploration
        Mode.HINT_ROOM:
            return _hint_room
        Mode.HINT_CAT:
            return _hint_cat
        Mode.WARN_QUIT, Mode.WARN_RESTART:
            return _warn_progress

        _:
            return []

func _get_title(mode: Mode) -> String:
    match mode:
        Mode.RETURN_LETTERS:
            return "Return letters"
        Mode.HINT_WORDS:
            return "Word game"
        Mode.HINT_EXPLORATION:
            return "Exploration"
        Mode.HINT_ROOM:
            return "Big room"
        Mode.HINT_CAT:
            return "Cat"
        Mode.WARN_RESTART:
            return "Restart Game"
        Mode.WARN_QUIT:
            return "Quit Game"
        _:
            return "???"

var _labels: Array[CensoringLabel]
var _letter_buttons: Dictionary[String, ContainerButton]

func _enter_tree() -> void:
    if __SignalBus.on_update_lost_letters.connect(_handle_lost_letters) != OK:
        push_error("Failed to connect to lost letters")

    if _positive_button.on_click.connect(_handle_click_positive) != OK:
        push_error("Failed to connect to click positive button")

    if _negative_button.on_click.connect(_handle_click_negative) != OK:
        push_error("Failed to connect to click negative button")

    for letters: Control in _return_letters:
        for btn: ContainerButton in letters.find_children("", "ContainerButton", true, false):
            var btn_label: CensoringLabel = btn.find_children("", "CensoringLabel")[0]
            if btn_label.text.length() != 1:
                continue

            _letter_buttons[btn_label.text] = btn

            if btn.on_click.connect(
                func (_btn: ContainerButton) -> void:
                    btn.interactable = false

                    if __GlobalGameState.lost_letters.contains(btn_label.text):
                        __GlobalGameState.lost_letters = __GlobalGameState.lost_letters.erase(
                            __GlobalGameState.lost_letters.find(btn_label.text)
                        )
            ) != OK:
                push_error("Failed to connect letter button '%s' click" % btn_label.text)

func _exit_tree() -> void:
    __SignalBus.on_update_lost_letters.disconnect(_handle_lost_letters)

func _ready() -> void:
    _labels.append_array(find_children("", "CensoringLabel", true, false))

    hide()

func _handle_lost_letters(letters: String) -> void:
    for label: CensoringLabel in _labels:
        label.censored_letters = letters

func show_dialog(
    mode: Mode,
    positive_action: String,
    positive_callback: Variant,
    negative_action: Variant = null,
    negative_callback: Variant = null,
) -> void:
    _title.text = _get_title(mode).to_upper()
    var visible_parts: Array[Control] = _get_parts(mode)

    if mode == Mode.RETURN_LETTERS:
        for letter: String in _letter_buttons:
            _letter_buttons[letter].interactable = __GlobalGameState.lost_letters.contains(letter)

    for part: Control in _all_parts:
        if visible_parts.has(part):
            part.show()
            continue
        part.hide()

    _positive_label.text = positive_action.to_upper()

    if negative_callback is Callable:
        if negative_action is String:
            _negative_label.text = negative_action.to_upper()
        else:
            _negative_label.text = "cancel".to_upper()
        _negative_button.show()
    else:
        _negative_button.hide()

    _positive_callback = positive_callback
    _negative_callback = negative_callback

    size = Vector2.ZERO
    show()

var _positive_callback: Variant
var _negative_callback: Variant

func _handle_click_positive(_btn: ContainerButton) -> void:
    hide()
    if _positive_callback is Callable:
        _positive_callback.call()

func _handle_click_negative(_btn: ContainerButton) -> void:
    hide()
    if _negative_callback is Callable:
        _negative_callback.call()
