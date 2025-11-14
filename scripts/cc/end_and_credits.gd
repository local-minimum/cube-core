extends CanvasLayer

@export var labels: Array[CensoringLabel]
@export var roll_delay: float = 5
@export var roll_speed: float = 0.5
@export var roll_duration: float = 20

func _enter_tree() -> void:
    if __SignalBus.on_roll_credits.connect(_roll_credits) != OK:
        push_error("Failed to connect to roll credits")

    if __SignalBus.on_update_lost_letters.connect(_handle_censor) != OK:
        push_error("Failed to connect to lost letters")

func _exit_tree() -> void:
    __SignalBus.on_roll_credits.disconnect(_roll_credits)
    __SignalBus.on_update_lost_letters.disconnect(_handle_censor)

func _ready() -> void:
    hide()

var _rolling: bool

func _roll_credits() -> void:
    for label: CensoringLabel in labels:
        label.position.x = (get_viewport().get_visible_rect().size.x - label.size.x) / 2.0

    show()
    await get_tree().create_timer(roll_delay).timeout
    _rolling = true

    print_debug("[Credits] Rolling!")
    await get_tree().create_timer(roll_duration).timeout
    _rolling = false
    print_debug("[Credits] Over!")

    __AudioHub.clear_all_dialogues()
    PoemEvent.clear_played_poems()
    get_tree().reload_current_scene()

func _handle_censor(letters: String) -> void:
    for label: CensoringLabel in labels:
        label.censored_letters = letters


func _process(delta: float) -> void:
    if !_rolling:
        return

    for label: CensoringLabel in labels:
        label.global_position.y += roll_speed * delta
