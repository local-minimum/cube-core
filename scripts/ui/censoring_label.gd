@tool
extends Control
class_name CensoringLabel

@export var censoring_textures: Array[Texture2D]

@export var allow_transpose_of_censoring_texture: bool:
    set(value):
        allow_transpose_of_censoring_texture = value
        queue_redraw()

@export var text: String:
    set(value):
        text = value
        _last_censor.clear()
        _sync_width()
        queue_redraw()

@export var censored_letters: String:
    set(value):
        censored_letters = value.to_upper() if censor_both_cases else value
        _last_censor.clear()
        queue_redraw()

@export var censor_both_cases: bool = true:
    set(value):
        censor_both_cases = true
        queue_redraw()

@export var font_size: int = 12:
    set(value):
        font_size = value
        custom_minimum_size.y = value
        _sync_width()
        queue_redraw()

@export var letter_spacing: int = 0:
    set (value):
        letter_spacing = value
        _sync_width()
        queue_redraw()

@export var height_ratio: int = 1:
    set (value):
        height_ratio = maxi(value, 1)
        _sync_width()

@export var update_freq_msec: int = 200

@export var font: Font

@export var color: Color = Color.WHITE_SMOKE:
    set(value):
        color = value
        queue_redraw()

@export var baseline_height: int = 6

@export var live: bool = true

@export var y_alignment_offset: int = 0:
    set (value):
        y_alignment_offset = value
        queue_redraw()

@export var manage_label_width: bool:
    set (value):
        manage_label_width = value
        _sync_width()

@export var center_horisontally: bool:
    set (value):
        center_horisontally = value
        _sync_width()
        queue_redraw()

func _sync_width() -> void:
    if manage_label_width:
        # TODO: Use height ratio instead?
        var width: float = font_size * text.length() + letter_spacing * (text.length() - (1 if letter_spacing > 0 else 0))
        custom_minimum_size = Vector2(width, custom_minimum_size.y)
        size = Vector2.ZERO
        if is_inside_tree():
            _sync_horisontally(width)
        else:
            _sync_horisontally.call_deferred(width)

func _sync_horisontally(width: float) -> void:
    if !is_inside_tree():
        return

    if center_horisontally:
        var parent: Node = get_parent()
        var parent_width: float
        if parent is Control && is_instance_valid(parent):
            var c_parent: Control = parent
            parent_width = c_parent.get_rect().size.x
        else:
            parent_width = get_viewport_rect().size.x

        position.x = (parent_width - width) / 2.0

        # print_debug("[Censoring Label] Position %s because has width %s and parent width is %s" % [position.x, width, parent_width])

var _last_draw: int
var _last_censor: Dictionary[int, int]

func _get_minimum_size() -> Vector2:
    return Vector2(font_size * text.length() + letter_spacing * (text.length() - 1), font_size)

func _draw() -> void:
    var pos: Vector2 = Vector2.UP * y_alignment_offset
    if center_horisontally:
        var text_width: float = (font_size + letter_spacing) * text.length() - (letter_spacing if letter_spacing > 0 else 0)
        var container_width: float = get_rect().size.x
        pos.x += (container_width  - text_width) / 2.0

    # print_debug(get_rect().size)
    for idx: int in range(text.length()):
        var letter: String = text[idx]

        if censored_letters.contains(letter.to_upper() if censor_both_cases else letter):
            var censor_size: float = font_size / float(height_ratio)
            for part: int in range(height_ratio):
                var r: Rect2 = Rect2(pos + Vector2.UP * (censor_size * (part + 1) - baseline_height), Vector2(censor_size, censor_size))
                if !censoring_textures.is_empty():
                    var texture_idx: int = randi_range(0, censoring_textures.size() - 1)
                    if _last_censor.get(idx, -1) == texture_idx:
                        texture_idx += 1
                        texture_idx = posmod(texture_idx, censoring_textures.size())

                    draw_texture_rect(
                        censoring_textures[texture_idx],
                        r,
                        false,
                        color,
                        allow_transpose_of_censoring_texture,
                    )

                    _last_censor[idx] = texture_idx
        else:
            draw_char(
                font if font else ThemeDB.fallback_font,
                pos,
                letter,
                font_size,
                color,
            )

        pos.x += font_size + letter_spacing


    _last_draw = Time.get_ticks_msec()


func _process(_delta: float) -> void:
    if live && Time.get_ticks_msec() > _last_draw + update_freq_msec && !censored_letters.is_empty():
        queue_redraw()
