extends GridEntity
class_name Cat

@export var anim_player: AnimationPlayer

@export var calling_sounds: Array[String]
@export var greeting_sounds: Array[String]
@export var petting_dialogue: Array[String]
@export var player: AudioStreamPlayer3D

@export var spawn_room: GridNode
@export var hide_cooldown: int = 10
@export var subzone_entry_cooldown: int = 10

@export var call_interim: int = 3
@export var greenery_subzone_locations: Dictionary[String, GridNode]
@export var room_location: GridNode
@export var room_platform_location: GridNode

@export var room_crusher_node: GridNode

@export var trigger_greenery_threshold: int = 100
@export var trigger_room_threshold: int = 20

var _zone: String
var _subzone: String
var _spawned_subzone: String
var _next_call: int
var _steps: int
var _next_show_step: int
var _hiding: bool
var _room_crusher_extended: bool

func _ready() -> void:
    super._ready()

    anim_player.play("Idle")

    if __SignalBus.on_cat_zone_entry.connect(_handle_zone_entry) != OK:
        push_error("Failed to connect to zone entry")

    if __SignalBus.on_cat_zone_exit.connect(_handle_zone_exit) != OK:
        push_error("Failed to connect to zone exit")

    if __SignalBus.on_move_start.connect(_handle_move_start) != OK:
        push_error("Failed to connect to move start")

    if __SignalBus.on_cat_subzone_entry.connect(_handle_subzone_entry) != OK:
        push_error("Failed to connect to entry subzone")

    if __SignalBus.on_change_crusher_phase.connect(_handle_crusher_change) != OK:
        push_error("Failed to connect to crusher change")

    _hide_cat()

func _handle_crusher_change(crusher: Crusher, phase: Crusher.Phase) -> void:
    if crusher.coordinates() != room_crusher_node.coordinates:
        return

    _room_crusher_extended = phase == Crusher.Phase.CRUSHED
    if _zone == "room":
        _subzone = "platform" if _room_crusher_extended else "floor"
    print_debug("[Cat] Crusher toggle zone %s and spawned in %s wanted subzone %s" % [_zone, _spawned_subzone, _subzone])
    if !_hiding:
        _place_cat_in_room()


func _handle_subzone_entry(subzone: String) -> void:
    if _subzone == subzone:
        _subzone = ""
    else:
        _subzone = subzone
        _next_show_step = _steps + subzone_entry_cooldown

func _handle_zone_entry(zone: String) -> void:
    if _zone != zone:
        _steps = 0
        _zone = zone

func _handle_zone_exit(zone: String) -> void:
    if _zone == zone:
        _steps = 0
        _zone = ""
        if !_hiding:
            _hide_cat()

func _handle_move_start(entity: GridEntity, _from: Vector3i, _direction: CardinalDirections.CardinalDirection) -> void:
    if entity is not GridPlayer || _zone.is_empty():
        return

    _steps += 1
    print_debug("[Cat] Counted player steps %s" % _steps)

    if entity.coordinates() == coordinates():
        print_debug("[Cat] Petting time!")
        _pet()
        return

    if !_spawned_subzone.is_empty() && _spawned_subzone == _subzone:
        print_debug("[Cat] Spawned zone %s and wanted subzone %s" % [_spawned_subzone, _subzone])
        if !_hiding && _steps > _next_call:
            _call()
        return

    if _zone == "greenery":
        if _steps > trigger_greenery_threshold:
            var node: GridNode = greenery_subzone_locations.get(_subzone)
            print_debug("[Cat] Attempting to spawn greenery '%s' -> %s" % [_subzone, node])
            if node != null:
                set_grid_anchor(node.get_grid_anchor(CardinalDirections.CardinalDirection.DOWN))
                sync_position()
                _call()
                _spawned_subzone = _subzone
                _hiding = false
    elif _zone == "room":
        if _steps > trigger_room_threshold:
            print_debug("[Cat] Attempting to spawn in room")
            _place_cat_in_room()

func _place_cat_in_room() -> void:
    if _room_crusher_extended:
        if room_platform_location != null:
            print_debug("[Cat] spawn in room platform location %s" % room_platform_location)
            set_grid_anchor(room_platform_location.get_grid_anchor(CardinalDirections.CardinalDirection.DOWN))
            sync_position()
            _call()
            _spawned_subzone = ""
            # _subzone = _zone
            _hiding = false
            _steps = 0
    else:
        if room_location != null:
            print_debug("[Cat] spawn in room floor location %s" % room_location)
            set_grid_anchor(room_location.get_grid_anchor(CardinalDirections.CardinalDirection.DOWN))
            sync_position()
            _call()
            _spawned_subzone = ""
            # _subzone = _zone
            _hiding = false
            _steps = 0
    _zone = "room"

func _pet() -> void:
    if !greeting_sounds.is_empty():
        __AudioHub.play_sfx(greeting_sounds.pick_random())
    await get_tree().create_timer(0.1).timeout
    if !petting_dialogue.is_empty():
        if __AudioHub.dialogue_busy:
            _hide_cat()
        else:
            __AudioHub.play_dialogue(petting_dialogue.pick_random(), _hide_cat)
    else:
        _hide_cat()

func _hide_cat() -> void:
    print_debug("[Cat] Hiding")
    set_grid_anchor(spawn_room.get_grid_anchor(CardinalDirections.CardinalDirection.DOWN))
    sync_position()
    _next_show_step = _steps + hide_cooldown
    _hiding = true

func _call() -> void:
    print_debug("[Cat] Calling")
    _next_call = _steps + call_interim
    player.stream = load(calling_sounds.pick_random())
    player.play()
