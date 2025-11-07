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

@export_group("Audio")
@export var offer_bad_sfx: String = "res://audio/sfx/roar_01.ogg"
@export var offer_sfx: String = "res://audio/sfx/swoosh_01.ogg"
@export var sacrifice_music: String = "res://audio/music/Music Box Sad 1 - OPL Loop.ogg"
@export var crossfade_time: float = 0.5
@export var regain_e_poem: String = "res://audio/voice/narration/regain_e.ogg"
@export var regain_e_poem_response: String = "res://audio/voice/narration/regain_e_response.ogg"

@export_group("Gains")
@export var gain_npc: int = 120
@export var gain_low: int = 20
@export var gain_default: int = 50
@export var gain_high: int = 100

@export_group("Hints")
@export var hint_sacrifice: String = "Sacrifice Letter"
@export var hint_not_letter: String = "Not a Letter"
@export var hint_npc: String = "All give {health} health"
@export var hint_value_letter: String = "Gain {health} health"

var sacrifice_letter: CensoringLabel

enum Mode { SACRIFICE, NPC_OFFER }

var mode: Mode = Mode.SACRIFICE

var _sacrificial_letter: String
var _player: GridPlayer
var _entered_cinematic: bool
var _allow_input_time: int
var _exhausted_all_letters: bool

func _enter_tree() -> void:
    if __SignalBus.on_start_sacrifice.connect(_handle_no_health) != OK:
        push_error("Failed to connect start sacrifice")

    if __SignalBus.on_start_offer.connect(_handle_start_offer) != OK:
        push_error("Failed to connect start offer")

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

func _handle_start_offer(player: GridPlayer) -> void:
    _player = player
    show_offer()

func _handle_no_health(player: GridPlayer) -> void:
    _player = player
    show_sacrifice()

func _handle_lost_letters(letters: String) -> void:
    hint.censored_letters = letters
    sacrifice_letter.censored_letters = letters
    alphabet.censored_letters = letters

func show_sacrifice() -> void:
    if visible:
        # We are already showing, presumably because the show_offer has been called
        return

    if _exhausted_all_letters:
        __SignalBus.on_complete_sacrifice.emit("")
        return

    if alphabet.text.length() <= __GlobalGameState.lost_letters.length():
        _exhausted_all_letters = true
        var all_lost: Array[String] = []
        all_lost.append_array(Array(__GlobalGameState.lost_letters.split()))
        all_lost.erase("E")
        __GlobalGameState.lost_letters = "".join(all_lost)
        if !regain_e_poem.is_empty():
            __AudioHub.play_dialogue(
                regain_e_poem,
                func() -> void: __AudioHub.play_dialogue(regain_e_poem_response, false, false, 0.3),
            )
        __SignalBus.on_complete_sacrifice.emit("")
        return

    mode = Mode.SACRIFICE
    hint.text = hint_sacrifice
    _ready_ui()

func show_offer() -> void:
    mode = Mode.NPC_OFFER

    if visible:
        # If show_sacrifice has been called we shouldn't make a new guess but we should
        # change the offer mode to npc so that we get the better rate!
        return

    if alphabet.text.length() <= __GlobalGameState.lost_letters.length():
        __SignalBus.on_reward_message.emit("No more value")
        __SignalBus.on_complete_sacrifice.emit("")
        return

    hint.text = hint_npc.format({"health": gain_npc})
    _ready_ui()

func _ready_ui() -> void:
    __AudioHub.play_music(sacrifice_music, crossfade_time)

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
    _allow_input_time = Time.get_ticks_msec() + 500
    show()

func _unhandled_input(event: InputEvent) -> void:
    if !visible || Time.get_ticks_msec() < _allow_input_time:
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
    var letter: String = _sacrificial_letter
    __GlobalGameState.lost_letters = "".join([__GlobalGameState.lost_letters, _sacrificial_letter])
    _player.heal(_get_sacrifice_value(_sacrificial_letter))
    hide()

    __AudioHub.play_sfx(offer_sfx)
    _sacrificial_letter = ""
    _player.cinematic = _entered_cinematic

    __SignalBus.on_complete_sacrifice.emit(letter)

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

    if upper_case:
        hint.text = hint.text.to_upper()

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

    __AudioHub.play_sfx(offer_bad_sfx)
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
