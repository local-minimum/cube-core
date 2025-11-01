extends Node

@export var start_cinematic: bool = true
@export var intro_music: String = "res://audio/music/Death Waltz - OPL Loop.ogg"
@export var music_fade_duration: float = 3
@export var intro_poem: String = ""
@export var response_delay: float = 0.5
@export var intro_response: String = ""
@export var landing_poem: String = ""
@export var landing_response: String = ""
@export var landing_coda: String = ""
@export var center: Vector3
@export var orbiter: Orbiter
@export var orbit_start: Vector3 = Vector3.LEFT * 2.5 * 50
@export var orbit: Vector3 = Vector3.LEFT
@export var orbit_speed: float = 1
@export var land_sequence_detector = Vector3.RIGHT
@export var landing_start_threshold: float = 0.8
@export var landing_time: float = 5.0
@export var ui_canvas: CanvasLayer
@export var title_canvas: CanvasLayer
@export var title_label: CensoringLabel
@export var press_to_start_label: CensoringLabel

var player: GridPlayer:
    get():
        if player == null:
            var p: GridPlayerCore = GridLevelCore.active_level.player
            if p is GridPlayer:
                player = p

        return player

func _ready() -> void:
    title_canvas.hide()
    if start_cinematic:
        orbiter.disabled = true
        player.cinematic = true
        ui_canvas.visible = false
        _start_orbit.call_deferred()
        FaderUI.fade_out(FaderUI.FadeTarget.EXPLORATION_VIEW, _show_title, 15)

    __AudioHub.play_music(intro_music, music_fade_duration)
    GridPlayer.playing_exploration_music = true


var _cam_position: Vector3
var _cam_rotation: Vector3
var _oribing: bool

func _start_orbit() -> void:
    _cam_position = player.camera.global_position
    _cam_rotation = player.camera.global_rotation

    title_label.censored_letters = ""
    press_to_start_label.censored_letters = ""

    orbiter.target = player.camera
    orbiter.center = center
    orbiter.start_orbit(
        orbit_start,
        orbit.normalized(),
        orbit_speed,
    )
    _oribing = true
    orbiter.disabled = false


var _next_censor: int = 0
var _alphabet: Array[String] = ["C","U","B","E","O","R","P","S","A","N","Y","K", "T"]
var _awaiting_start: bool
var _awaiting_landing: bool

@export var _censor_interval: int = 1000

func _process(_delta: float) -> void:
    if _oribing:
        if !orbiter.disabled:
            orbiter.target.global_transform = orbiter.target.global_transform.looking_at(player.global_position)

        if title_canvas.visible && Time.get_ticks_msec() > _next_censor:
            _next_censor = Time.get_ticks_msec() + _censor_interval
            _alphabet.shuffle()
            var censor: String = "".join(_alphabet.slice(0, randi_range(1, 5)))
            title_label.censored_letters = censor
            press_to_start_label.censored_letters = censor

    if _awaiting_landing:
        var vec: Vector3 = (orbiter.target.global_position - player.global_position).normalized()
        if vec.dot(land_sequence_detector.normalized()) > landing_start_threshold:
            _awaiting_landing = false
            _start_landing()

func _unhandled_input(event: InputEvent) -> void:
    if _awaiting_start && event is InputEventKey && event.is_pressed():
        _awaiting_start = false
        press_to_start_label.visible = false
        _start_poem()

        await get_tree().create_timer(8).timeout

        title_canvas.visible = false

func _show_title() -> void:
    _awaiting_start = false
    await get_tree().create_timer(1).timeout

    _next_censor = Time.get_ticks_msec() + _censor_interval
    title_label.censored_letters = ""
    press_to_start_label.censored_letters = ""
    press_to_start_label.hide()
    title_canvas.show()

    await get_tree().create_timer(2).timeout
    press_to_start_label.show()

    _awaiting_start = true

func _start_poem() -> void:
    __AudioHub.play_dialogue(intro_poem, _handle_poem_done)

func _handle_poem_done() -> void:

    await get_tree().create_timer(response_delay).timeout

    __AudioHub.play_dialogue(intro_response, _wait_for_landing_trigger)

func _wait_for_landing_trigger() -> void:
    _awaiting_landing = true

    await get_tree().create_timer(0.5).timeout

    __AudioHub.play_dialogue(landing_poem, _landing_response)

func _start_landing() -> void:
    orbiter.disabled = true

    await get_tree().create_timer(4).timeout

    var tween: Tween = create_tween()

    @warning_ignore_start("return_value_discarded")
    tween.tween_property(
        orbiter.target,
        "global_position",
        _cam_position,
        landing_time,
    ).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)

    tween.parallel().tween_method(
        QuaternionUtils.create_tween_rotation_method(orbiter.target, true),
        orbiter.target.global_transform.basis.get_rotation_quaternion(),
        Quaternion.from_euler(_cam_rotation),
        landing_time
    ).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
    @warning_ignore_restore("return_value_discarded")

    if tween.finished.connect(_finalize_landing) != OK:
        push_error("Failed to connect finished landing")

func _finalize_landing() -> void:
    player.camera.global_position = _cam_position
    player.camera.global_rotation = _cam_rotation
    player.cinematic = false
    __GlobalGameState.lost_letters = ""
    _oribing = false


func _landing_response() -> void:

    await get_tree().create_timer(response_delay).timeout

    __AudioHub.play_dialogue(landing_response, _intro_complete)

func _intro_complete() -> void:

    await get_tree().create_timer(response_delay).timeout

    __AudioHub.play_dialogue(landing_coda)
