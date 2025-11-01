extends Node
class_name LandingAreaManager

@export var pit_entry_node: GridNode
@export var pit_trapped_node: GridNode
@export var door_node: GridNode
@export var door_direction: CardinalDirections.CardinalDirection

@export var accept_pit_response: String
@export var refuse_pit_response: String
@export var surrender_to_pit_response: String

@export var trapped_poem: String
@export var trapped_response: String

@export var door_poem: String
@export var door_response: String


var played_entry: bool
var played_refuse: bool
var played_trapped: bool
var played_door: bool

var move_count: int

func _ready() -> void:
    if __SignalBus.on_change_node.connect(_handle_change_node) != OK:
        push_error("Failed to connect chnage node")

func _handle_change_node(feature: GridNodeFeature) -> void:
    if feature is not GridPlayerCore:
        return

    var player: GridPlayerCore = feature
    move_count += 1

    if !played_entry && pit_entry_node.coordinates == player.coordinates():
        played_entry = true
        if move_count <= 3:
            __AudioHub.play_dialogue(accept_pit_response)
        else:
            __AudioHub.play_dialogue(surrender_to_pit_response)

    elif !played_entry && !played_refuse && move_count > 4:
        played_refuse = true
        __AudioHub.play_dialogue(refuse_pit_response)

    elif !played_trapped && pit_trapped_node.coordinates == player.coordinates():
        played_trapped = true
        __AudioHub.play_dialogue(trapped_poem, _play_trapped_response)

    elif !played_door && door_node.coordinates == player.coordinates() && player.look_direction == door_direction:
        played_door = true
        __AudioHub.play_dialogue(door_poem, _play_door_response)

func _play_trapped_response() -> void:
    await get_tree().create_timer(0.3).timeout
    __AudioHub.play_dialogue(trapped_response)

func _play_door_response() -> void:
    await get_tree().create_timer(0.3).timeout
    __AudioHub.play_dialogue(door_response)
