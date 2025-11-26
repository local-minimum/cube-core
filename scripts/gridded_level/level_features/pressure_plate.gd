extends GridEvent
class_name PressurePlate

const _ACTIVATE_OR_TOGGLE_PLATE: int = 0
const _DEACTIVATE_PLATE: int = 1

## Overrides the event trigger settings and base them on the node side
@export var infer_trigger_side: bool

@export var _activation_sound: String = "res://audio/sfx/hit_10.ogg"
@export var _activation_sound_volume: float = 0.7

@export_group("Texture swapping")
@export var _swapping_mesh: MeshInstance3D
@export var _swap_active_texture: Texture
@export var _swap_inactive_texture: Texture


@export_group("Animation")
@export var _anim: AnimationPlayer
@export var _anim_activate: String = "Activate"
@export var _anim_active: String = "Active"
@export var _anim_deactivate: String = "Deactivate"
@export var _anim_deactivated: String = "Deactivated"

var _contracts: Array[BroadcastContract]

var _triggering: Array[GridNodeFeature]

func _ready() -> void:
    super._ready()

    if __SignalBus.on_change_node.connect(_handle_feature_move) != OK:
        push_warning("Failed to connect change node")

    if __SignalBus.on_change_anchor.connect(_handle_feature_move) != OK:
        push_warning("Failed to connect change anchor")

    if infer_trigger_side:
        var side: GridNodeSide = GridNodeSide.find_node_side_parent(self, true)
        if side != null:
            _trigger_entire_node = false
            _trigger_sides = [side.direction]

    # Uniqify mesh and material
    if _swapping_mesh != null:
        _swapping_mesh.mesh = _swapping_mesh.mesh.duplicate()
        _swapping_mesh.mesh.surface_set_material(0, _swapping_mesh.mesh.surface_get_material(0).duplicate())

        _sync_swapping_material()

    if _anim != null:
        _anim.play(_anim_deactivated)

func register_broadcasts(contract: BroadcastContract) -> bool:
    var messages: int = contract.messages.size()
    if messages > 0 && messages <= 2:
        _contracts.append(contract)
        return true

    return false

func _handle_feature_move(feature: GridNodeFeature) -> void:
    if !available() || !activates_for(feature):
        return

    if !_triggering.has(feature) && coordinates() == feature.coordinates() &&  is_triggering_side(feature.get_grid_anchor_direction()):
        _triggered = true
        _triggering.append(feature)
        if _triggering.size() == 1:
            if _anim != null || _swapping_mesh != null:
                __AudioHub.play_sfx(_activation_sound, _activation_sound_volume)
            if _anim != null:
                _anim.play(_anim_activate)
            _sync_swapping_material()
            for contract: BroadcastContract in _contracts:
                contract.broadcast(_ACTIVATE_OR_TOGGLE_PLATE)

    elif _triggering.has(feature) && (coordinates() != feature.coordinates() || !is_triggering_side(feature.get_grid_anchor_direction())):
        _triggering.erase(feature)
        if _triggering.is_empty():
            if _anim != null:
                _anim.play(_anim_deactivate)
            _sync_swapping_material()
            for contract: BroadcastContract in _contracts:
                contract.broadcast(_DEACTIVATE_PLATE)

func _sync_swapping_material() -> void:
    if _swapping_mesh != null:
        var mat: Material = _swapping_mesh.get_active_material(0)
        if mat is StandardMaterial3D:
            var std_mat: StandardMaterial3D = mat
            if _triggering.is_empty():
                std_mat.albedo_texture = _swap_inactive_texture
            else:
                std_mat.albedo_texture = _swap_active_texture
        elif mat is ShaderMaterial:
            var s_mat: ShaderMaterial = mat
            if _triggering.is_empty():
                s_mat.set_shader_parameter("main_tex", _swap_inactive_texture)
            else:
                s_mat.set_shader_parameter("main_tex", _swap_active_texture)


func trigger(_entity: GridEntity, _movement: Movement.MovementType) -> void:
    # We don't trigger this way because it happens too early in that case
    pass

const _TRIGGERED_KEY: String = "triggered"

func needs_saving() -> bool:
    return _trigger_sides.size() > 0

func save_key() -> String:
    return "pp-%s-%s" % [coordinates(), CardinalDirections.name(_trigger_sides[0])]

func collect_save_data() -> Dictionary:
    return {
        _TRIGGERED_KEY: _triggered,
    }

func load_save_data(_data: Dictionary) -> void:
    _triggered = DictionaryUtils.safe_getb(_data, _TRIGGERED_KEY)

    _triggering.clear()

    var level: GridLevelCore = get_level()
    var coords: Vector3i = coordinates()

    for entity: GridEntity in level.grid_entities:
        if entity == null || !is_instance_valid(entity) || !entity.is_inside_tree():
            continue

        if entity.coordinates() == coords && _trigger_sides.has(entity.get_grid_anchor_direction()):
            _triggering.append(entity)

    _sync_swapping_material()

    if _anim != null:
        if _triggering.is_empty():
            _anim.play(_anim_deactivated)
        else:
            _anim.play(_anim_active)
