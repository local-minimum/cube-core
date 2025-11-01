extends GridEntity
class_name Cat

@export var calling_sounds: Array[String]
@export var greeting_sounds: Array[String]
@export var petting_dialogue: Array[String]

@export var spawn_room: GridNode

var _zone: String
var _steps: int

func _ready() -> void:
    super._ready()

    if __SignalBus.on_cat_zone_entry.connect(_handle_zone_entry) != OK:
        push_error("Failed to connect to zone entry")

    if __SignalBus.on_cat_zone_exit.connect(_handle_zone_exit) != OK:
        push_error("Failed to connect to zone exit")

    if __SignalBus.on_move_start.connect(_handle_move_start) != OK:
        push_error("Failed to connect to move start")

    _hide_cat()

func _handle_zone_entry(zone: String) -> void:
    if _zone != zone:
        _steps = 0
        _zone = zone

func _handle_zone_exit(zone: String) -> void:
    if _zone == zone:
        _steps = 0
        _zone = ""

func _handle_move_start(entity: GridEntity, _from: Vector3i, _direction: CardinalDirections.CardinalDirection) -> void:
    if entity is not GridPlayer || _zone.is_empty():
        return

    _steps += 1
    print_debug("[Cat] Counted player steps %s" % _steps)

    if entity.coordinates() == coordinates():
        _pet()
        return

func _pet() -> void:
    __AudioHub.play_sfx(greeting_sounds.pick_random())
    await get_tree().create_timer(0.1).timeout
    __AudioHub.play_dialogue(petting_dialogue.pick_random(), _hide_cat, true)

func _hide_cat() -> void:
    set_grid_anchor(spawn_room.get_grid_anchor(CardinalDirections.CardinalDirection.DOWN))
    sync_position()
