extends Node

@export var enemy_poem: String
@export var enemy_response: String

@export var word_game_poem: String
@export var word_game_response: String

var played_enemy: bool
var played_word_game: bool


func _ready() -> void:
    if __SignalBus.on_change_node.connect(_handle_change_node) != OK:
        push_error("Failed to connect chnage node")

    if __SignalBus.on_play_exclude_word_game.connect(_handle_play_word_game) != OK:
        push_error("Failed to connect play word game")


func _handle_play_word_game(_enemy: GridEnemy, _player: GridPlayer) -> void:
    if played_word_game:
        return

    __AudioHub.play_dialogue(word_game_poem, _play_word_game_response, true)

    __SignalBus.on_play_exclude_word_game.disconnect(_handle_play_word_game)

func _play_word_game_response() -> void:
    await get_tree().create_timer(0.3).timeout
    __AudioHub.play_dialogue(word_game_response)

var player: GridPlayerCore
var enemies: Array[GridEnemy]

func _handle_change_node(feature: GridNodeFeature) -> void:
    if feature is GridPlayerCore:
        player = feature
        _check_play_poem()

    elif feature is GridEnemy:
        if !enemies.has(feature):
            enemies.append(feature as GridEnemy)

        _check_play_poem()

func _check_play_poem():
    if player == null || played_enemy:
        return

    for enemy: GridEnemy in enemies:
        var distance: int = VectorUtils.manhattan_distance(enemy.coordinates(), player.coordinates())
        if distance > 3:
            continue

        if VectorUtils.manhattan_distance(CardinalDirections.translate(player.coordinates(), player.look_direction), enemy.coordinates()) < distance:
            played_enemy = true
            __AudioHub.play_dialogue(enemy_poem, _play_enemy_response, true)
            __SignalBus.on_change_node.disconnect(_handle_change_node)
            return

func _play_enemy_response() -> void:
    await get_tree().create_timer(0.3).timeout
    __AudioHub.play_dialogue(enemy_response)
