extends Node

@export var start_cinematic: bool = true
@export var intro_music: String = "res://audio/music/Death Waltz - OPL Loop.ogg"
@export var music_fade_duration: float = 3

var player: GridPlayer:
    get():
        if player == null:
            var p: GridPlayerCore = GridLevelCore.active_level.player
            if p is GridPlayer:
                player = p

        return player

func _ready() -> void:
    if start_cinematic:
        player.cinematic = true

    __AudioHub.play_music(intro_music, music_fade_duration)
    GridPlayer.playing_exploration_music = true
