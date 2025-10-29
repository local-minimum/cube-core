extends Control
class_name Sacrifice

@export var alphabet: CensoringLabel
@export var hint: CensoringLabel
@export var sacrifice: ContainerButton

@export var default_text_color: Color = Color.HOT_PINK
@export var disabled_text_color: Color = Color.DIM_GRAY

@export var upper_case: bool = true

@export var low_value_letters: String = "VKJXQZ"
@export var high_value_letters: String = "ETAOINSR"

@export_group("Gains")
@export var gain_npc: int = 120
@export var gain_low: int = 20
@export var gain_default: int = 50
@export var gain_high: int = 100

@export_group("Hints")
@export var hint_sacrifice: String = "Sacrifice Letter"
@export var hint_not_letter: String = "Not a Letter"
@export var hint_npc: String = "Offer any Letter for {health} health"
@export var hint_value_letter: String = "Gain {health} health"

var sacrifice_letter: CensoringLabel

enum Mode { SACRIFICE, NPC_OFFER }

var mode: Mode = Mode.SACRIFICE

var _sacrificial_letter: String
var _player: GridPlayer
var _entered_cinematic: bool

func _enter_tree() -> void:
    if __SignalBus.on_start_sacrifice.connect(_handle_no_health) != OK:
        push_error("Failed to connect start sacrifice")
    if __SignalBus.on_update_lost_letters.connect(_handle_lost_letters) != OK:
        push_error("Failed to connect update lost letters")

func _ready() -> void:
    for child: CensoringLabel in sacrifice.find_children("", "CensoringLabel"):
        sacrifice_letter = child
        sacrifice_letter.manage_label_width = false
        sacrifice_letter.custom_minimum_size.x = sacrifice_letter.font_size / float(sacrifice_letter.height_ratio)
        sacrifice_letter.update_minimum_size()
        break

    hide()

func _handle_no_health(player: GridPlayer) -> void:
    _player = player
    show_sacrifice()

func _handle_lost_letters(letters: String) -> void:
    hint.censored_letters = letters
    sacrifice_letter.censored_letters = letters
    alphabet.censored_letters = letters

func show_sacrifice() -> void:
    mode = Mode.SACRIFICE
    hint.text = hint_sacrifice
    _ready_ui()

func show_offer() -> void:
    mode = Mode.NPC_OFFER
    hint.text = hint_npc.format({"health": gain_npc})
    _ready_ui()

func _ready_ui() -> void:
    if upper_case:
        hint.text = hint.text.to_upper()
    hint.censored_letters = __GlobalGameState.lost_letters

    sacrifice.interactable = false
    sacrifice_letter.text = ""
    sacrifice_letter.censored_letters = __GlobalGameState.lost_letters

    sacrifice.interactable = false

    if upper_case:
        alphabet.text = alphabet.text.to_upper()
    alphabet.censored_letters = __GlobalGameState.lost_letters

    _sacrificial_letter = ""

    _entered_cinematic = _player.cinematic
    _player.cinematic = true
    show()

func _unhandled_input(event: InputEvent) -> void:
    if !visible:
        return

    if event is InputEventKey && event.is_pressed() && !event.is_echo():
        var key_evt: InputEventKey = event
        var keycode: int = key_evt.keycode
        if keycode >= KEY_A && keycode <= KEY_Z || keycode >= KEY_0 && keycode <= KEY_9:
            _offer_letter(OS.get_keycode_string(keycode).to_upper())
        elif keycode == KEY_BACKSPACE || keycode == KEY_DELETE:
            _offer_letter("")

        elif keycode == KEY_SPACE || keycode == KEY_ENTER:
            if !_sacrificial_letter.is_empty():
                _handle_sacrifice_letter()

func _handle_sacrifice_letter() -> void:
    __GlobalGameState.lost_letters = "".join([__GlobalGameState.lost_letters, _sacrificial_letter])
    _player.heal(_get_sacrifice_value(_sacrificial_letter))
    hide()

    _sacrificial_letter = ""
    _player.cinematic = _entered_cinematic

func _offer_letter(letter: String) -> void:
    if letter.length() == 1:
        sacrifice_letter.text = letter
        sacrifice.interactable = alphabet.text.contains(letter) && !__GlobalGameState.lost_letters.contains(letter)

        if !sacrifice.interactable:
            hint.text = hint_not_letter
            _sacrificial_letter = ""
        else:
            hint.text = _get_value_text(letter)
            _sacrificial_letter = letter

    else:
        sacrifice_letter.text = ""
        sacrifice.interactable = false
        hint.text = _get_nothing_entered_hint()
        _sacrificial_letter = ""

    sacrifice_letter.color = default_text_color if sacrifice.interactable else disabled_text_color

func _get_nothing_entered_hint() -> String:
    match mode:
        Mode.NPC_OFFER:
            return hint_npc.format({"health": gain_npc})
        Mode.SACRIFICE:
            return hint_sacrifice

    return hint_sacrifice

func _get_value_text(letter: String) -> String:
    match mode:
        Mode.NPC_OFFER:
            return hint_npc.format({"health": gain_npc})
        Mode.SACRIFICE:
            return hint_value_letter.format({"health": _get_sacrifice_value(letter)})

    return hint_not_letter

func _get_sacrifice_value(letter: String) -> int:
    match mode:
        Mode.NPC_OFFER:
            return gain_npc
        Mode.SACRIFICE:
            if high_value_letters.contains(letter):
                return gain_high
            elif low_value_letters.contains(letter):
                return gain_low

            return gain_default

    return gain_default
