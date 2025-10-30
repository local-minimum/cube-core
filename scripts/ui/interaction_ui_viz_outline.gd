extends InteractionUIViz
class_name InteractionUIVizOutline

@export var _color: Color = Color.AZURE
@export var _line_width: float = 2
@export var _font: Font
@export var _font_size: int = 22
@export var _gap_padding: int = 2
@export_range(-2, 2) var _hint_y_offset: float = 0.3
@export var _text_hint_x_offset: int = 5

func draw_interactable_ui(ui: InteractionUI, key: String, interactable: Interactable) -> void:
    var rect: Rect2 = get_viewport_rect_with_3d_camera(ui, interactable)
    var hint: Variant = __BindingHints.get_hint(key)

    var gap_size: int = 1
    var hint_text: String = ""
    if hint is String:
        hint_text = hint
        gap_size = hint_text.length()

    print_debug("[Interaction UI] %s -> %s rect %s" % [key, hint, rect])

    var corners: PackedVector2Array = convert_rect_to_corners(ui, rect)
    var top_left: Vector2 = corners[0]
    var top_right: Vector2 = corners[1]
    var lower_left: Vector2 = corners[2]
    var lower_right: Vector2 = corners[3]

    var top_gap_start: Vector2 = top_left + Vector2.RIGHT * _font_size * 0.5
    var top_gap_end: Vector2 = top_gap_start + Vector2.RIGHT * (_font_size * gap_size + 2 * _gap_padding)
    top_gap_end.x = minf(top_right.x, top_gap_end.x)


    ui.draw_polyline(
        [
            top_gap_end,
            top_right,
            lower_right,
            lower_left,
            top_left,
            top_gap_start,
        ],
        _color,
        _line_width,
    )

    var text_start: Vector2 = top_gap_start + Vector2.RIGHT * _gap_padding + Vector2.UP * _font_size * _hint_y_offset

    if hint_text.is_empty() && hint is Texture2D:
        var tex: Texture2D = hint
        var r: Rect2 = Rect2(text_start + _font_size * Vector2.UP, Vector2(_font_size, _font_size))
        ui.draw_texture_rect(
            tex,
            r,
            false,
            _color
        )
    else:
        text_start.x += _text_hint_x_offset
        ui.draw_string(
            _font,
            text_start,
            hint_text if !hint_text.is_empty() else key,
            HORIZONTAL_ALIGNMENT_CENTER,
            -1,
            _font_size,
            _color,
        )
