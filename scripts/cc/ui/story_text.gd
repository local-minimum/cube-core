extends PanelContainer
class_name StoryText

@export var enforce_uppercase: bool = true
@export var _labels: Array[CensoringLabel]
@export var _label_containers: Array[Control]
@export var show_time: float = 30

func _ready() -> void:
    if __SignalBus.on_update_lost_letters.connect(_handle_load_letters) != OK:
        push_error("Failed to connect lost letter")

    if __SignalBus.on_reward_message.connect(_handle_text) != OK:
        push_error("Failed to connect reward message")

    if __SignalBus.on_move_start.connect(_handle_move_start) != OK:
        push_error("Failed to connect move")

    hide()

func _handle_move_start(entity: GridEntity, _from: Vector3i, _direction: CardinalDirections.CardinalDirection) -> void:
    if entity is GridPlayer && visible:
        hide()

func _handle_load_letters(letters: String) -> void:
    for label: CensoringLabel  in _labels:
        label.censored_letters = letters

func _wanted_wrap(message: String) -> int:
    if message.length() < 30:
        return 10
    elif message.length() < 40:
        return 12
    elif message.length() < 50:
        return 16
    elif message.length() < 60:
        return 20
    else:
        return 24

func _handle_text(message: String) -> void:
    if enforce_uppercase:
        message = message.to_upper()

    var lines: PackedStringArray = TextUtils.word_wrap(message, _wanted_wrap(message))
    if lines.size() > _labels.size():
        lines = TextUtils.word_wrap(message, 24)

    print_debug("[Story Text] message '%s' -> %s" % [message, lines])

    var idx: int = 0
    for label: CensoringLabel in _labels:
        if idx < lines.size():
            label.text = lines[idx]
            _label_containers[idx].show()
        else:
            label.text = ""
            _label_containers[idx].hide()

        idx += 1

    show()
    await get_tree().create_timer(show_time).timeout
    hide()
