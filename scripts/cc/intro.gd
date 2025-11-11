extends Node

@export var start_cinematic: bool = true
@export var intro_music: String = "res://audio/music/Death Waltz - OPL Loop.ogg"
@export var censor_noise: String = "res://audio/sfx/noise_03.ogg"
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

@export_category("Skipping")
@export var skip_action: String = "crawl_search"
@export var skip_activation_duration_msec: int = 1500
@export var skip_progress_ui: Control
@export var skip_label: CensoringLabel
@export var skip_countdown: TextureRect
@export var not_skipping_texture: Texture2D
@export var skip_countdown_textures: Array[Texture2D]

var player: GridPlayer:
    get():
        if player == null:
            var p: GridPlayerCore = GridLevelCore.active_level.player
            if p is GridPlayer:
                player = p

        return player

func _ready() -> void:
    skip_progress_ui.hide()
    if start_cinematic:
        orbiter.disabled = true
        player.cinematic = true
        ui_canvas.visible = false
        title_label.hide()
        press_to_start_label.hide()
        title_canvas.show()

        _start_orbit.call_deferred()
        FaderUI.fade_out(FaderUI.FadeTarget.EXPLORATION_VIEW, _show_title, 15)

    else:
        title_canvas.hide()
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
var _finalized: bool
var _skip_press_time: int
var _skipping: bool
var _skip_idx: int = 0

@export var _censor_interval: int = 1000

func _process(_delta: float) -> void:
    if _finalized:
        return

    if _skipping:
        if Time.get_ticks_msec() - _skip_press_time > skip_activation_duration_msec:
            _finalize_landing()
            return

        var progress: float = clampf((Time.get_ticks_msec() - _skip_press_time) / float(skip_activation_duration_msec), 0, 1)
        var step: int = roundi(lerp(0, skip_countdown_textures.size() - 1, progress))
        if step != _skip_idx:
            _skip_idx = step
            skip_countdown.texture = skip_countdown_textures[_skip_idx]

    if _oribing:
        if !orbiter.disabled:
            orbiter.target.global_transform = orbiter.target.global_transform.looking_at(player.global_position)

        if title_label.visible && Time.get_ticks_msec() > _next_censor:
            _next_censor = Time.get_ticks_msec() + _censor_interval + randi_range(0, 200)
            _alphabet.shuffle()
            var censor: String = "".join(_alphabet.slice(0, randi_range(1, 5)))
            __AudioHub.play_sfx(censor_noise, randf_range(0.1, 0.2))
            title_label.censored_letters = censor
            press_to_start_label.censored_letters = censor
            skip_label.censored_letters = censor

    if _awaiting_landing:
        var vec: Vector3 = (orbiter.target.global_position - player.global_position).normalized()
        var value: float =vec.dot(land_sequence_detector.normalized())
        # print_debug("[Intro] V %s -> %s" % [vec, value])
        if value > landing_start_threshold:
            _awaiting_landing = false
            _start_landing()

func _unhandled_input(event: InputEvent) -> void:
    if _finalized:
        return

    if _awaiting_start && event is InputEventKey && event.is_pressed():
        _start_intro()
        return

    elif event is InputEventKey:
        if !event.is_action(skip_action):
            if (event as InputEventKey).pressed:
                _show_skip_hint()
            elif !_skipping && (event as InputEventKey).is_released():
                _hide_skip_hint()

    if event.is_action_pressed(skip_action):
        _skip_press_time = Time.get_ticks_msec()
        _skipping = true
        _show_skip_hint()
    elif event.is_action_released(skip_action):
        _skipping = false
        _hide_skip_hint()

func _start_intro() -> void:
    _awaiting_start = false
    press_to_start_label.visible = false
    _start_poem()

    await get_tree().create_timer(8).timeout

    title_label.hide()
    press_to_start_label.hide()

func _show_skip_hint() -> void:
    if _skipping:
        skip_countdown.texture = skip_countdown_textures[0]
        _skip_idx = 0
    else:
        skip_countdown.texture = not_skipping_texture
    skip_progress_ui.show()

func _hide_skip_hint() -> void:
    skip_progress_ui.hide()

func _show_title() -> void:
    if _finalized:
        return
    _awaiting_start = false

    await get_tree().create_timer(1).timeout
    if _finalized:
        return

    _next_censor = Time.get_ticks_msec() + _censor_interval
    title_label.censored_letters = ""
    press_to_start_label.censored_letters = ""
    skip_label.censored_letters = ""
    press_to_start_label.hide()
    title_label.show()
    press_to_start_label.show()

    await get_tree().create_timer(2).timeout
    if _finalized:
        return

    press_to_start_label.show()

    _awaiting_start = true

func _start_poem() -> void:
    __AudioHub.play_dialogue(
        intro_poem,
        func () -> void:
            if _finalized:
                return
            __AudioHub.play_dialogue(intro_response, _wait_for_landing_trigger, false, false, response_delay),
    )

func _wait_for_landing_trigger() -> void:
    if _finalized:
        return

    _awaiting_landing = true

    await get_tree().create_timer(2).timeout
    if _finalized:
        return

    __AudioHub.play_dialogue(
        landing_poem,
        func () -> void:
            if _finalized:
                return

            __AudioHub.play_dialogue(
                landing_response,
                func () -> void:
                    if _finalized:
                        return
                    __AudioHub.play_dialogue(landing_coda, null, true, false, response_delay),
                false,
                false,
                response_delay,
            ),
    )

func _start_landing() -> void:
    orbiter.disabled = true

    await get_tree().create_timer(1).timeout
    if _finalized:
        return

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
    if _finalized:
        return

    if !orbiter.disabled:
        orbiter.disabled = true

    if title_canvas.visible:
        title_canvas.hide()

    _skipping = false
    _finalized = true
    player.camera.global_position = _cam_position
    player.camera.global_rotation = _cam_rotation
    player.cinematic = false
    ui_canvas.show()
    __GlobalGameState.lost_letters = ""
    _oribing = false
