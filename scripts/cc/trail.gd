extends Node
class_name EntityTrail

@export var entity: GridEntity

@export var only_paint_anchor_once: bool = true

@export var textures: Array[Texture]
@export var material: Material
@export var decal_scale: Vector2 = Vector2.ONE
@export var decal_normal_offset: float = 0.05
@export var random_normal_rotation: bool
@export var snap_random_rotations: bool = true
@export var snap_step: float = 90

@export var max_trail_length: int = 5

var _trail: Array[MeshInstance3D]
var _anchor_trail: Array[GridAnchor]
var _last_idx: int

var _last_anchor: GridAnchor

func _enter_tree() -> void:
    if __SignalBus.on_move_start.connect(_handle_move_start) != OK:
        push_error("Failed to connect move start")

func is_in_trail(anchor: GridAnchor) -> bool:
    return _anchor_trail.has(anchor)

func _handle_move_start(mover: GridEntity, _from: Vector3i, _translation_direction: CardinalDirections.CardinalDirection) -> void:
    if mover != entity:
        print_debug("[Trail] Mover %s is not %s" % [mover, entity])
        return

    var anchor: GridAnchor = mover.get_grid_anchor()
    if _last_anchor == anchor:
        print_debug("[Trail] Mover %s is at same anchor as before %s" % [mover, anchor])
        return

    if _last_anchor != null:
        var mesh: MeshInstance3D = _get_meshinstance(_last_anchor)
        _set_decal_position(mesh, _last_anchor)
        _set_random_decal(mesh)
    else:
        print_debug("[Trail] Mover %s is in the air" % [mover])

    if !only_paint_anchor_once || !_anchor_trail.has(anchor):
        _last_anchor = anchor
    else:
        _last_anchor = null

func _get_meshinstance(anchor: GridAnchor) -> MeshInstance3D:
    var mesh: MeshInstance3D
    if _trail.size() >= max_trail_length:
        _last_idx = posmod(_last_idx + 1, _trail.size())
        mesh = _trail[_last_idx]
        _anchor_trail[_last_idx] = anchor

    else:
        _last_idx = _trail.size()

        mesh = MeshInstance3D.new()
        mesh.name = "Trail %s of %s" % [_last_idx, entity.name]

        var qmesh: QuadMesh = QuadMesh.new()
        var node_size: Vector3 = anchor.get_grid_node().get_level().node_size
        var min_side: float = min(min(node_size.x, node_size.y), node_size.z)
        qmesh.size = Vector2(min_side, min_side) * decal_scale
        mesh.mesh = qmesh

        qmesh.material = material.duplicate(true)

        _trail.append(mesh)
        _anchor_trail.append(anchor)

    return mesh

func _set_decal_position(mesh: MeshInstance3D, anchor: GridAnchor) -> void:
    print_debug("[Trail] Adding trail decal %s to anchor %s" % [mesh, anchor])
    var normal: Vector3 = CardinalDirections.direction_to_vector(CardinalDirections.invert(anchor.direction))
    if mesh.get_parent() == null:
        anchor.add_child(mesh)
    else:
        mesh.reparent(anchor)

    mesh.global_position = anchor.global_position + normal * decal_normal_offset
    var look: Vector3
    match anchor.direction:
        CardinalDirections.CardinalDirection.DOWN:
            look = Vector3.FORWARD
        CardinalDirections.CardinalDirection.UP:
            look = Vector3.BACK
        _:
            look = Vector3.UP

    if random_normal_rotation:
        var angle: float = randf_range(0, 360)
        if snap_random_rotations:
            angle = round(angle / snap_step) * snap_step

        look = look.rotated(normal, deg_to_rad(angle))

    mesh.global_rotation = Transform3D.IDENTITY.looking_at(normal * -1, look).basis.get_rotation_quaternion().get_euler()

func _set_random_decal(mesh: MeshInstance3D) -> void:
    var mat: Material = mesh.get_active_material(0)
    if mat is StandardMaterial3D:
        mat.albedo_texture = textures.pick_random()
    elif mat is ShaderMaterial:
        mat.set_shader_parameter("main_tex", textures.pick_random())
