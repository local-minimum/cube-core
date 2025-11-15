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

@export var no_health_poem: String
@export var no_health_response: String

@export var sacrifice_poem: String
@export var sacrifice_poem_response: String

@export var sacrifice_e_poem: String
@export var sacrifice_e_poem_response: String

var played_enemy: bool
var played_word_game: bool
var played_hurt_walk: bool
var played_nohurt_walk: bool
var played_sacrifice: bool
var played_no_health: bool
var played_sacrifice_e: bool

func _ready() -> void:
    if __SignalBus.on_change_node.connect(_handle_change_node) != OK:
        push_error("Failed to connect chnage node")

    if __SignalBus.on_play_exclude_word_game.connect(_handle_play_word_game) != OK:
        push_error("Failed to connect play word game")

    if __SignalBus.on_hurt_by_walk.connect(_handle_hurt_by_walk) != OK:
        push_error("Failed to connect hurt by walk")

    if __SignalBus.on_track_back_on_trail.connect(_handle_nohurt_walk) != OK:
        push_error("Failed to connect no hurt walk")

    if __SignalBus.on_start_sacrifice.connect(_handle_sacrifice) != OK:
        push_error("Failed to connect to handle first sacrifice")

    if __SignalBus.on_complete_sacrifice.connect(_handle_complete_sacrifice) != OK:
        push_error("Failed to connect to complete sacrifice")

func _handle_complete_sacrifice(letter: String) -> void:
    if !played_sacrifice_e && letter.to_upper() == "E":
        played_sacrifice_e = true
        __AudioHub.play_dialogue(
            sacrifice_e_poem,
            func () -> void: __AudioHub.play_dialogue(sacrifice_e_poem_response, false, false, 0.3),
        )

func _handle_sacrifice(sac_player: GridPlayer) -> void:
    if sac_player.health == 0 && !played_no_health:
        played_no_health = true
        __AudioHub.play_dialogue(
            no_health_poem,
            func () -> void: __AudioHub.play_dialogue(no_health_response, false, false, 0.3),
        )
    elif !played_sacrifice:
        played_sacrifice = true
        __AudioHub.play_dialogue(
            sacrifice_poem,
            func () -> void: __AudioHub.play_dialogue(sacrifice_poem_response, false, false, 0.3),
        )

func _handle_nohurt_walk(_nohurt_player: GridPlayer, steps: int) -> void:
    if played_nohurt_walk || steps < nohurt_walk_threshold:
        return

    played_nohurt_walk = true
    __SignalBus.on_track_back_on_trail.disconnect(_handle_nohurt_walk)
    __AudioHub.play_dialogue(
        nohurt_walk_poem,
        func () -> void: __AudioHub.play_dialogue(nohurt_walk_response, false, false, 0.3),
    )

func _handle_hurt_by_walk(hurt_player: GridPlayer) -> void:
    if played_hurt_walk || hurt_player.health > player_hurt_poem_threshold:
        return

    __SignalBus.on_hurt_by_walk.disconnect(_handle_hurt_by_walk)
    played_hurt_walk = true
    __AudioHub.play_dialogue(
        hurt_walk_poem,
        func () -> void: __AudioHub.play_dialogue(hurt_walk_response, false, false, 0.3),
    )

func _handle_play_word_game(_enemy: GridEnemy, _player: GridPlayer) -> void:
    if played_word_game:
        return

    __AudioHub.play_dialogue(
        word_game_poem,
        func () -> void: __AudioHub.play_dialogue(word_game_response, false, false, 0.3),
    )

    __SignalBus.on_play_exclude_word_game.disconnect(_handle_play_word_game)

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
            __AudioHub.play_dialogue(
                enemy_poem,
                func () -> void: __AudioHub.play_dialogue(enemy_response, false, false, 0.3),
            )
            __SignalBus.on_change_node.disconnect(_handle_change_node)
            return
