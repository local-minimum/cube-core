extends Node
class_name FaderUI

enum FadeTarget { EXPLORATION_VIEW }

@export var target: FadeTarget = FadeTarget.EXPLORATION_VIEW

static func name_target(fade_target: FadeTarget) -> String:
    match fade_target:
        FadeTarget.EXPLORATION_VIEW: return "Exploration View"
        _:
            push_warning("Unknown target %s" % name_target)
            return "Unknown Target"

@export var ease_duration: float = 0.4

@export var faded_duration: float = 0.1

@export var color_rect: ColorRect

@export var solid_color: Color
@export var transparent_color: Color

static var _faders: Dictionary[FadeTarget, FaderUI] = {}

## Starts inactive and ends so too
static func fade_in_out(
    fade_target: FadeTarget = FadeTarget.EXPLORATION_VIEW,
    on_midways: Variant = null,
    on_complete: Variant = null,
    color: Variant = null,
    duration_factor: float = 1.0,
) -> void:
    var fader: FaderUI = _faders.get(fade_target)
    if fader == null:
        push_warning("Lacking fader %s" % name_target(fade_target))
    else:
        fader._fade(on_midways, on_complete, color, true, true, duration_factor)

## Starts active and goes away
static func fade_out(
    fade_target: FadeTarget = FadeTarget.EXPLORATION_VIEW,
    on_complete: Variant = null,
    duration_factor: float = 1.0
) -> void:
    var fader: FaderUI = _faders.get(fade_target)
    if fader == null:
        push_warning("Lacking fader %s" % name_target(fade_target))
    else:
        fader._fade(null, on_complete, fader.solid_color, false, true, duration_factor)

static func fade_in(
    fade_target: FadeTarget = FadeTarget.EXPLORATION_VIEW,
    on_complete: Variant = null,
    duration_factor: float = 1.0
) -> void:
    var fader: FaderUI = _faders.get(fade_target)
    if fader == null:
        push_warning("Lacking fader %s" % name_target(fade_target))
    else:
        fader._fade(null, on_complete, null, true, false, duration_factor)

var tween: Tween

func _enter_tree() -> void:
    _faders[target] = self
    if color_rect != null:
        _disable_target(color_rect)

func _disable_target(control: Control) -> void:
    control.visible = false
    control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _activate_target(control: Control) -> void:
    control.mouse_filter = Control.MOUSE_FILTER_STOP
    control.visible = true

func _fade(
    on_midways: Variant = null,
    on_complete: Variant = null,
    override_color: Variant = null,
    do_fade_in: bool = true,
    do_fade_out: bool = true,
    duration_factor: float = 1.0,
) -> void:
    if tween != null:
        tween.kill()

    if color_rect != null:
        color_rect.color = transparent_color
        _activate_target(color_rect)

    var color: Color = solid_color
    if override_color is Color:
        color = override_color

    if !do_fade_in:
        color_rect.color = color

    tween = create_tween()

    @warning_ignore_start("return_value_discarded")
    if do_fade_in:
        tween.tween_property(
            color_rect,
            "color",
            color,
            ease_duration * duration_factor
        ).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

    tween.tween_property(
        color_rect,
        "color",
        color,
        faded_duration * duration_factor,
    )

    if on_midways != null && on_midways is Callable:
        var hack: Dictionary[int, bool] = { 0: false }

        tween.parallel().tween_method(
            func (_value: float) -> void:
                if hack[0]:
                    return

                hack[0] = true

                @warning_ignore_start("unsafe_cast")
                (on_midways as Callable).call()
                @warning_ignore_restore("unsafe_cast")
                ,
            0.0,
            1.0,
            faded_duration,
        )

    if do_fade_out:
        tween.tween_property(
            color_rect,
            "color",
            transparent_color,
            ease_duration * duration_factor,
        ).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
        @warning_ignore_restore("return_value_discarded")

    if tween.connect("finished", func () -> void:
        if do_fade_out:
            color_rect.visible = false
            color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

        if on_complete != null && on_complete is Callable:
            @warning_ignore_start("unsafe_cast")
            (on_complete as Callable).call()
            @warning_ignore_restore("unsafe_cast")
    ) != OK:
        push_error("Failed to connect fade_in_out finished will panic and not tween")

        tween.kill()

        if do_fade_out:
            color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
            color_rect.visible = false

        if on_complete != null && on_complete is Callable:
            @warning_ignore_start("unsafe_cast")
            (on_complete as Callable).call()
            @warning_ignore_restore("unsafe_cast")
