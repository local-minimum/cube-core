extends GridEvent
class_name HealthNPC

@export var animation: Array[Texture]
@export var animation_speed_msec: int = 1000
@export var animation_target: MeshInstance3D
@export var disable_root: Node
@export var activation_sounds: Array[String] = [
    "res://audio/sfx/slide_dodge.ogg",
]

var _next_anim_msec: int
var _anim_idx: int

func _process(_delta: float) -> void:
    if available() && Time.get_ticks_msec() > _next_anim_msec:
        _next_anim_msec += animation_speed_msec

        var mat: Material = animation_target.get_active_material(0)

        if mat is StandardMaterial3D:
            var std_mat: StandardMaterial3D = mat
            std_mat.albedo_texture = animation[_anim_idx]
        elif mat is ShaderMaterial:
            var s_mat: ShaderMaterial = mat
            s_mat.set_shader_parameter("main_tex", animation[_anim_idx])


        _anim_idx = posmod(_anim_idx + 1, animation.size())

func trigger(entity: GridEntity, movement: Movement.MovementType) -> void:
    if entity is GridPlayer:
        super.trigger(entity, movement)

        if !activation_sounds.is_empty():
            __AudioHub.play_sfx(activation_sounds.pick_random())

        __SignalBus.on_start_offer.emit(entity)

        if !__SignalBus.on_complete_sacrifice.is_connected(_handle_complete_sacrifice):
            if __SignalBus.on_complete_sacrifice.connect(_handle_complete_sacrifice) != OK:
                push_error("Failed to connect on complete sacrifice")


func _handle_complete_sacrifice(_letter: String) -> void:
    disable_root.queue_free()

    if __SignalBus.on_complete_sacrifice.is_connected(_handle_complete_sacrifice):
        __SignalBus.on_complete_sacrifice.disconnect(_handle_complete_sacrifice)
