extends Node

@export var start_cinematic: bool = true
@export var intro_music: String = "res://audio/music/Death Waltz - OPL Loop.ogg"
@export var music_fade_duration: float = 3
@export var center: Vector3
@export var orbiter: Orbiter
@export var orbit_start: Vector3 = Vector3.LEFT * 2.5 * 50
@export var orbit: Vector3 = Vector3.LEFT
@export var orbit_speed: float = 1
@export var ui_canvas: CanvasLayer

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
        ui_canvas.visible = false
        _start_orbit()


    __AudioHub.play_music(intro_music, music_fade_duration)
    GridPlayer.playing_exploration_music = true


var _cam_position: Vector3
var _cam_rotation: Vector3
var _oribing: bool

func _start_orbit() -> void:
    orbiter.target = player.camera
    orbiter.center = center
    _cam_position = player.camera.position
    _cam_rotation = player.camera.rotation
    orbiter.start_orbit(
        orbit_start,
        orbit.normalized(),
        orbit_speed,
    )
    _oribing = true


func _process(_delta: float) -> void:
    if _oribing:
        orbiter.target.global_transform = orbiter.target.global_transform.looking_at(player.global_position)
