extends Interactable
class_name GridDoorInteraction

enum Mode { FULL, UNLOCK_ONLY }
enum TextureMode { SWAPPING, ONLY_VISIBLE_LOCKED }

@export var door: GridDoorCore

@export var mode: Mode = Mode.FULL

@export var is_negative_side: bool

@export var mesh: MeshInstance3D

@export var texture_mode: TextureMode = TextureMode.SWAPPING

@export var display_material_idx: int = 2

@export var automatic_door_tex: Texture

@export var walk_into_door_tex: Texture

@export var no_entry_door_tex: Texture

@export var click_to_open_tex: Texture

@export var locked_door_tex_model1: Texture

@export var locked_door_tex_model2: Texture

@export var locked_door_tex_model3: Texture

@export var open_door_tex: Texture

@export var emission_intensity: float = 3

@export var max_click_distance: float = 1

@export var camera_puller: CameraPuller

func _ready() -> void:
    is_interactable = false
    if __SignalBus.on_door_state_chaged.connect(_handle_door_state_chage) != OK:
        print_debug("%s could not connect to door state changes" % self)

    if __SignalBus.on_level_loaded.connect(_sync_reader_display) != OK:
        push_error("Could not connect level loaded")

    _sync_reader_display.call_deferred()

func _get_locked_texture() -> Texture:
    var key: String = door.key_id
    match KeyMasterCore.instance.get_key_model_id(key):
        1: return locked_door_tex_model1
        2: return locked_door_tex_model2
        3: return locked_door_tex_model3
        _:
            push_warning("Key %s has model id %s which we don't know how to draw" % [key, KeyMasterCore.instance.get_key_model_id(key)])
            return locked_door_tex_model1

func _set_interaction() -> void:
    match door.get_opening_automation(self):
        GridDoorCore.OpenAutomation.NONE:
            is_interactable = false
        GridDoorCore.OpenAutomation.WALK_INTO:
            is_interactable = true
        GridDoorCore.OpenAutomation.PROXIMITY:
            match door.get_lock_state(self):
                GridDoorCore.LockState.LOCKED:
                    is_interactable = true
                _:
                    is_interactable = false
        GridDoorCore.OpenAutomation.INTERACT:
            is_interactable = true


func _get_needed_texture() -> Texture:
    if texture_mode != TextureMode.SWAPPING:
        return null

    match door.get_opening_automation(self):
        GridDoorCore.OpenAutomation.NONE:
            match door.get_lock_state(self):
                GridDoorCore.LockState.OPEN:
                    return open_door_tex
                _:
                    return no_entry_door_tex
        GridDoorCore.OpenAutomation.WALK_INTO:
            match door.get_lock_state(self):
                GridDoorCore.LockState.LOCKED:
                    return _get_locked_texture()
                _:
                    return walk_into_door_tex
        GridDoorCore.OpenAutomation.PROXIMITY:
            match door.get_lock_state(self):
                GridDoorCore.LockState.LOCKED:
                    return _get_locked_texture()
                _:
                    return automatic_door_tex
        GridDoorCore.OpenAutomation.INTERACT:
            match door.get_lock_state(self):
                GridDoorCore.LockState.LOCKED:
                    return _get_locked_texture()
                _:
                    return click_to_open_tex


    return no_entry_door_tex

func _handle_door_state_chage(grid_door: GridDoorCore, _from: GridDoorCore.LockState, _to: GridDoorCore.LockState) -> void:
    if grid_door == door:
        _sync_reader_display()

func _sync_reader_display(_level: GridLevelCore = null) -> void:
    _set_interaction()

    if mesh == null:
        return

    if texture_mode == TextureMode.ONLY_VISIBLE_LOCKED:
        mesh.visible = door.get_lock_state(self) == GridDoorCore.LockState.LOCKED
        return

    var mat: Material = mesh.get_surface_override_material(display_material_idx)
    if mat == null:
        var default_mat: Material = mesh.get_active_material(display_material_idx)
        if default_mat == null || default_mat is StandardMaterial3D:
            mat = StandardMaterial3D.new()
        elif default_mat is ShaderMaterial:
            mat = ShaderMaterial.new()
            mat.shader = (default_mat as ShaderMaterial).shader.duplicate(true)

    var tex: Texture = _get_needed_texture()
    if mat is StandardMaterial3D:
        mat.albedo_texture = tex

        if emission_intensity > 0:
            mat.emission_texture = tex
            mat.emission_enabled = true
            mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
            mat.emission_intensity = emission_intensity
    elif mat is ShaderMaterial:
        #TODO: This is bugged, doesn't really set the texture at all
        mat.set_shader_parameter("main_tex", tex)
        print_debug("[Grid Door Interaction] Updated shader to use %s" % tex)

    mesh.set_surface_override_material(display_material_idx, mat)

func _in_range(event_position: Vector3) -> bool:
    if mode == Mode.UNLOCK_ONLY && door.get_lock_state(self) != GridDoorCore.LockState.LOCKED:
        return false

    var level: GridLevelCore = door.get_level()
    var player: GridPlayerCore = level.player

    if player.cinematic:
        return false

    var player_coords: Vector3i = player.coordinates()
    var door_coords: Vector3i = door.coordinates()
    var door_side: CardinalDirections.CardinalDirection = door.get_side()
    var negative_coords: Vector3i = CardinalDirections.translate(door_coords, door_side)

    # print_debug("[Door Reader] Player %s Door %s (%s) Negative %s" % [player_coords, door_coords, CardinalDirections.name(door_side), negative_coords])

    if is_negative_side:
        if VectorUtils.manhattan_distance(negative_coords, player_coords) > VectorUtils.manhattan_distance(door_coords, player_coords):
            return false
    else:
        if VectorUtils.manhattan_distance(negative_coords, player_coords) < VectorUtils.manhattan_distance(door_coords, player_coords):
            return false

    var direction: Vector3 = event_position - player.global_position
    var look_direction: Vector3 = CardinalDirections.direction_to_vector(player.look_direction)

    var dot: float = direction.normalized().dot(look_direction)
    return dot > 0.1 && VectorUtils.all_dimensions_smaller(
        direction.abs(),
        level.node_size,
    )

func execute_interation() -> void:
    if door.get_lock_state(self) == GridDoorCore.LockState.LOCKED:
        @warning_ignore_start("return_value_discarded")
        door.attempt_door_unlock(self, camera_puller)
        @warning_ignore_restore("return_value_discarded")
        _sync_reader_display()
    else:
        door.toggle_door()
