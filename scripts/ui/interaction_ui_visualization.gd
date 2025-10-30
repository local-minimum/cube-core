extends Resource
class_name InteractionUIViz

func draw_interactable_ui(_ui: InteractionUI, _key: String, _interactable: Interactable) -> void:
    pass

static func get_viewport_rect_with_3d_camera(ui: InteractionUI, interactable: Interactable) -> Rect2:
    var camera3d: Camera3D = ui.get_viewport().get_camera_3d()

    var box: AABB = interactable.bounding_box()
    var min_pos: Vector2
    var max_pos: Vector2

    for idx: int in range(8):
        var corner_global: Vector3 = box.get_endpoint(idx)
        var pos: Vector2 = camera3d.unproject_position(corner_global)
        # print_debug("[Interaction UI] Corner %s -> %s" % [corner_global, pos])

        if idx == 0:
            min_pos = pos
            max_pos = pos
        else:
            min_pos.x = min(pos.x, min_pos.x)
            min_pos.y = min(pos.y, min_pos.y)
            max_pos.x = max(pos.x, max_pos.x)
            max_pos.y = max(pos.y, max_pos.y)

    var r_size: Vector2 = max_pos - min_pos
    return Rect2(min_pos, r_size)

static func convert_rect_to_corners(ui: InteractionUI, rect: Rect2) -> PackedVector2Array:
    var top_left: Vector2 = ui.get_global_transform().affine_inverse().basis_xform(rect.position)
    var lower_right: Vector2 = ui.get_global_transform().affine_inverse().basis_xform(rect.end)
    var top_right: Vector2 = Vector2(lower_right.x, top_left.y)
    var lower_left: Vector2 = Vector2(top_left.x, lower_right.y)
    return [top_left, top_right, lower_left, lower_right]
