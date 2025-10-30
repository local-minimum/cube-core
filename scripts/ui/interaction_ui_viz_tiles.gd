extends InteractionUIViz
class_name InteractionUIVizTiles

@export var texture_size: int = 12
@export var grow_outline: int = 6
@export var modulate: Color = Color.WHITE

@export_group("Hint")
@export var _font: Font
@export var _font_size: int = 22
@export var _font_color: Color = Color.AZURE
@export_range(-2, 2) var _hint_y_offset: float = 0.3
@export var _text_hint_x_offset: int = 5

@export_group("Textures")
@export var upper_left_corner: Texture
@export var upper_right_corner: Texture
@export var lower_left_corner: Texture
@export var lower_right_corner: Texture

@export var gap_texture: Texture

@export var upper_horizontal: Texture
@export var left_vertical: Texture
@export var right_vertical: Texture
@export var bottom_horizontal: Texture

func draw_interactable_ui(ui: InteractionUI, key: String, interactable: Interactable) -> void:
    var rect: Rect2 = get_viewport_rect_with_3d_camera(ui, interactable).grow(grow_outline)
    var hint: Variant = __BindingHints.get_hint(key)

    var gap_size: int = 1
    var hint_text: String = ""
    if hint is String:
        hint_text = hint
        gap_size = hint_text.length()

    var corners: PackedVector2Array = convert_rect_to_corners(ui, rect)
    var top_left: Vector2 = corners[0]
    var top_right: Vector2 = corners[1]
    var lower_left: Vector2 = corners[2]
    var lower_right: Vector2 = corners[3]

    var t_size: Vector2 = Vector2(texture_size, texture_size)
    var x: float = top_left.x
    var idx: int = 0

    while x < top_right.x - texture_size:
        if idx == 0:
            ui.draw_texture_rect(
                upper_left_corner,
                Rect2(top_left + Vector2.RIGHT * texture_size * idx, t_size),
                false,
                modulate
            )
        elif idx == 1 || idx > 1 + gap_size:
            ui.draw_texture_rect(
                upper_horizontal,
                Rect2(top_left + Vector2.RIGHT * texture_size * idx, t_size),
                false,
                modulate
            )
        else:
            var r: Rect2 = Rect2(top_left + Vector2.RIGHT * texture_size * idx, t_size)
            ui.draw_texture_rect(
                gap_texture,
                r,
                false,
                modulate,
            )

            if hint_text.is_empty() && hint is Texture2D:
                var tex: Texture2D = hint
                ui.draw_texture_rect(
                    tex,
                    r,
                    false,
                    modulate,
                )
            elif idx == 2:
                var text_start: Vector2 = r.position
                text_start.x += _text_hint_x_offset
                text_start.y += _hint_y_offset * texture_size

                ui.draw_string(
                    _font,
                    text_start,
                    hint_text if !hint_text.is_empty() else key,
                    HORIZONTAL_ALIGNMENT_LEFT,
                    -1,
                    _font_size,
                    _font_color,
                )
        x += texture_size
        idx += 1

    top_right = top_left + Vector2.RIGHT * texture_size * idx
    ui.draw_texture_rect(
        upper_right_corner,
        Rect2(top_right, t_size),
        false,
        modulate
    )

    var y: float = top_left.y - texture_size
    idx = 1
    while signf(y - (lower_left.y - texture_size * 3)) == signf(top_left.y - (lower_left.y - texture_size)):
        ui.draw_texture_rect(
            left_vertical,
            Rect2(top_left + Vector2.DOWN * texture_size * idx, t_size),
            false,
            modulate
        )

        ui.draw_texture_rect(
            right_vertical,
            Rect2(top_right + Vector2.DOWN * texture_size * idx, t_size),
            false,
            modulate
        )

        y += texture_size
        idx += 1

    lower_left = top_left + Vector2.DOWN * texture_size * idx
    x = lower_left.x
    idx = 0
    while x < lower_right.x - texture_size:
        if idx == 0:
            ui.draw_texture_rect(
                lower_left_corner,
                Rect2(lower_left + Vector2.RIGHT * texture_size * idx, t_size),
                false,
                modulate
            )
        else:
            ui.draw_texture_rect(
                bottom_horizontal,
                Rect2(lower_left + Vector2.RIGHT * texture_size * idx, t_size),
                false,
                modulate
            )
        x += texture_size
        idx += 1

    lower_right = lower_left + Vector2.RIGHT * texture_size * idx
    ui.draw_texture_rect(
        lower_right_corner,
        Rect2(lower_right, t_size),
        false,
        modulate
    )
