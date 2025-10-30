extends InteractionUIViz
class_name InteractionUIVizTiles

@export var texture_size: int = 12
@export var grow_outline: int = 0

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
