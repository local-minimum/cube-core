extends Node

@export var enemy_poem: String
@export var enemy_response: String

@export var word_game_poem: String
@export var word_game_response: String

@export var hurt_walk_poem: String
@export var hurt_walk_response: String
@export var player_hurt_poem_threshold: int = 30

@export var nohurt_walk_poem: String
@export var nohurt_walk_response: String
@export var nohurt_walk_threshold: int = 5

var played_enemy: bool
var played_word_game: bool
var played_hurt_walk: bool
var played_nohurt_walk: bool

func _ready() -> void:
    if __SignalBus.on_change_node.connect(_handle_change_node) != OK:
        push_error("Failed to connect chnage node")

    if __SignalBus.on_play_exclude_word_game.connect(_handle_play_word_game) != OK:
        push_error("Failed to connect play word game")

    if __SignalBus.on_hurt_by_walk.connect(_handle_hurt_by_walk) != OK:
        push_error("Failed to connect hurt by walk")

    if __SignalBus.on_track_back_on_trail.connect(_hande_nohurt_walk) != OK:
        push_error("Failed to connect no hurt walk")

func _hande_nohurt_walk(_nohurt_player: GridPlayer, steps: int) -> void:
    if played_nohurt_walk || steps < nohurt_walk_threshold:
        return

    played_nohurt_walk = true
    __SignalBus.on_track_back_on_trail.disconnect(_hande_nohurt_walk)
    __AudioHub.play_dialogue(nohurt_walk_poem, _play_nohurt_walk_response, true)

func _play_nohurt_walk_response() -> void:
    await get_tree().create_timer(0.3).timeout
    __AudioHub.play_dialogue(nohurt_walk_response)


func _handle_hurt_by_walk(hurt_player: GridPlayer) -> void:
    if played_hurt_walk || hurt_player.health > player_hurt_poem_threshold:
        return

    __SignalBus.on_hurt_by_walk.disconnect(_handle_hurt_by_walk)
    played_hurt_walk = true
    __AudioHub.play_dialogue(hurt_walk_poem, _play_hurt_walk_response, true)

func _play_hurt_walk_response() -> void:
    await get_tree().create_timer(0.3).timeout
    __AudioHub.play_dialogue(hurt_walk_response)

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
