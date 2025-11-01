extends Node
class_name AudioHub

const BUS_SFX: String = "SFX"
const BUS_DIALOGUE: String = "Dialogue"
const BUS_MUSIC: String = "Music"

@export var sfx_players: int = 4
var _sfx_available: Array[AudioStreamPlayer]

@export var dialogue_players: int = 2
var _dialogue_available: Array[AudioStreamPlayer]

@export var music_players: int = 2
var _music_available: Array[AudioStreamPlayer]
var _music_running: Array[AudioStreamPlayer]

func _ready() -> void:
    for _i: int in range(sfx_players):
        _create_player(BUS_SFX, _sfx_available)

    for _i: int in range(dialogue_players):
        _create_player(BUS_DIALOGUE, _dialogue_available)

    for _i: int in range(music_players):
        _create_player(BUS_MUSIC, _music_available)

func _create_player(bus: String, available_players: Array[AudioStreamPlayer], append: bool = true) -> AudioStreamPlayer:
    var player: AudioStreamPlayer = AudioStreamPlayer.new()
    add_child(player)
    player.bus = bus

    if player.finished.connect(available_players.append.bind(player)) != OK:
        push_error("Failed to connect to finished for new player on bus '%s'" % bus)

    if player.finished.connect(_check_oneshot_callbacks.bind(player)) != OK:
        push_error("Failed to connect to oneshot callbacks")

    if append:
        available_players.append(player)

    return player

func play_sfx(sound_resource_path: String, volume: float = 1) -> void:
    var player: AudioStreamPlayer = _sfx_available.pop_back()
    if player == null:
        player = _create_player(BUS_SFX, _sfx_available, false)
        sfx_players += 1
        push_warning("Extending '%s' with a %sth player because all busy" % [BUS_SFX, sfx_players])

    player.stream = load(sound_resource_path)
    player.volume_linear = volume
    player.play()

## on_finish takes an optional callable that receives the player as argument and is responsible to remove itself from the signal
func play_dialogue(sound_resource_path: String, on_finish: Variant = null) -> void:
    var player: AudioStreamPlayer = _dialogue_available.pop_back()
    if player == null:
        player = _create_player(BUS_DIALOGUE, _dialogue_available, false)
        dialogue_players += 1
        push_warning("Extending '%s' with a %sth player because all busy" % [BUS_DIALOGUE, dialogue_players])

    if on_finish != null && on_finish is Callable:
        if _oneshots.has(player):
            _oneshots[player].append(on_finish)
        else:
            _oneshots[player] = [on_finish]

    player.stream = load(sound_resource_path)
    player.play()

func play_music(
    sound_resource_path: String,
    crossfade_time: float = -1,
) -> void:
    var player: AudioStreamPlayer = _music_available.pop_back()
    if player == null:
        player = _create_player(BUS_MUSIC, _music_available, false)
        music_players += 1
        push_warning("Extending '%s' with a %sth player because all busy" % [BUS_MUSIC, music_players])

    player.stream = load(sound_resource_path)
    player.play()

    if crossfade_time == 0:
        _end_music_players()
        player.volume_linear = 1.0
    elif crossfade_time > 0:
        fade_player(player, 0, 1, crossfade_time)
        for other: AudioStreamPlayer in _music_running:
            fade_player(
                other,
                1,
                0,
                crossfade_time,
                func () -> void:
                    other.stop()
                    if !_music_available.has(other):
                        _music_available.append(other)
                    _music_running.erase(other)
            )

    else:
        player.volume_linear = 1.0

    _music_running.append(player)

static func fade_player(
    player: AudioStreamPlayer,
    from_linear: float = 0.0,
    to_linear: float = 1.0,
    duration: float = 1.0,
    on_complete: Variant = null,
    resolution: float = 0.05,
) -> void:
    var steps: int = floori(duration / resolution)
    for step: int in range(steps):
        player.volume_linear = lerpf(from_linear, to_linear, float(step) / steps)
        await player.get_tree().create_timer(resolution).timeout

    player.volume_linear = to_linear
    if on_complete is Callable:
        (on_complete as Callable).call()

func _end_music_players():
    for player: AudioStreamPlayer in _music_running:
        player.stop()

        if !_music_available.has(player):
            _music_available.append(player)

    _music_running.clear()


var _oneshots: Dictionary[AudioStreamPlayer, Array]

func _check_oneshot_callbacks(player: AudioStreamPlayer) -> void:
    if !_oneshots.has(player):
        return

    for callback: Callable in _oneshots[player]:
        callback.call()

    _oneshots.erase(player)
