extends Node
class_name AudioHub

const BUS_SFX: String = "SFX"
const BUS_DIALOGUE: String = "Dialogue"
const BUS_MUSIC: String = "Music"

@export var sfx_players: int = 4
var _sfx_available: Array[AudioStreamPlayer]

@export var dialogue_players: int = 2
var _dialogue_available: Array[AudioStreamPlayer]
var _dialogue_running: Array[AudioStreamPlayer]
var _dialogue_playing: bool:
    get():
        return !_dialogue_running.is_empty()

var dialogue_busy: bool:
    get():
        return !_queue.get(BUS_DIALOGUE, []).is_empty() || !_dialogue_running.is_empty()

@export var music_players: int = 2
var _music_available: Array[AudioStreamPlayer]
var _music_running: Array[AudioStreamPlayer]

func _ready() -> void:
    for _i: int in range(sfx_players):
        _create_player(BUS_SFX, _sfx_available)

    for _i: int in range(dialogue_players):
        _create_player(BUS_DIALOGUE, _dialogue_available, _dialogue_running, true, "_dialogue_playing")

    for _i: int in range(music_players):
        _create_player(BUS_MUSIC, _music_available, _music_running)

func _create_player(
    bus: String,
    available_players: Array[AudioStreamPlayer],
    runnig_players: Variant = null,
    append: bool = true,
    busy_property: String = ""
) -> AudioStreamPlayer:
    var player: AudioStreamPlayer = AudioStreamPlayer.new()
    player.name = "Player %s on %s" % [available_players.size(), bus]

    add_child(player)
    player.bus = bus

    if player.finished.connect(_handle_player_finished.bind(player, available_players, runnig_players, busy_property)) != OK:
        push_error("Failed to connect to finished reads available for new player on bus '%s'" % bus)

    if append:
        available_players.append(player)

    return player

func _handle_player_finished(player: AudioStreamPlayer, available: Array[AudioStreamPlayer], running: Variant, busy_property: String) -> void:
    print_debug("[Audio HUB]%s done" % player)

    if running is Array[AudioStreamPlayer]:
        (running as Array[AudioStreamPlayer]).erase(player)

    available.append(player)

    _check_oneshot_callbacks(player, busy_property)

func play_sfx(sound_resource_path: String, volume: float = 1) -> void:
    if sound_resource_path.is_empty():
        return

    var player: AudioStreamPlayer = _sfx_available.pop_back()
    if player == null:
        player = _create_player(BUS_SFX, _sfx_available, null, false)
        sfx_players += 1
        push_warning("Extending '%s' with a %sth player because all busy" % [BUS_SFX, sfx_players])

    player.stream = load(sound_resource_path)
    player.volume_linear = volume
    player.play()


func play_dialogue(
    sound_resource_path: String,
    on_finish: Variant = null,
    enqueue: bool = true,
    silence_others: bool = false,
    delay_start: float = -1,
) -> void:
    if sound_resource_path.is_empty():
        return

    if silence_others:
        _end_dialogue_players()

    if enqueue && dialogue_busy:
        _enqueue_stream(
            BUS_DIALOGUE,
            sound_resource_path,
            on_finish,
            delay_start,
        )
        return

    var player: AudioStreamPlayer = _dialogue_available.pop_back()
    if player == null:
        player = _create_player(BUS_DIALOGUE, _dialogue_available, _dialogue_running, false, "_dialogue_playing")
        dialogue_players += 1
        push_warning("Extending '%s' with a %sth player because all busy" % [BUS_DIALOGUE, dialogue_players])

    if on_finish != null && on_finish is Callable:
        if _oneshots.has(player):
            _oneshots[player].append(on_finish)
        else:
            _oneshots[player] = [on_finish]

    player.stream = load(sound_resource_path)
    _dialogue_running.append(player)
    _delay_play(player, delay_start)

## Do not await this function to ensure it puts the relevant busy state even if not yet playing!
func _delay_play(player: AudioStreamPlayer, delay_start: float) -> void:
    if delay_start:
        await get_tree().create_timer(delay_start).timeout

    player.play()

func _end_dialogue_players():
    for player: AudioStreamPlayer in _dialogue_running:
        player.stop()

        if !_dialogue_available.has(player):
            _dialogue_available.append(player)

    _dialogue_available.clear()

var pause_dialogues: bool:
    set(value):
        pause_dialogues = value

        for player: AudioStreamPlayer in _dialogue_running:
            player.stream_paused = pause_dialogues

## Returns all music resources currently playing
func playing_music() -> PackedStringArray:
    return PackedStringArray(
        _music_running.map(
            func (player: AudioStreamPlayer) -> String:
                return player.stream.resource_path
                ,
        )
    )

func clear_all_dialogues() -> void:
    _clear_bus_queue(BUS_DIALOGUE)
    for player: AudioStreamPlayer in _dialogue_running:
        _clear_callbacks(player)
        player.stop()

func play_music(
    sound_resource_path: String,
    crossfade_time: float = -1,
) -> void:
    if sound_resource_path.is_empty():
        return

    var player: AudioStreamPlayer = _music_available.pop_back()
    if player == null:
        player = _create_player(BUS_MUSIC, _music_available, _music_running, false)
        music_players += 1
        push_warning("Extending '%s' with a %sth player because all busy" % [BUS_MUSIC, music_players])

    player.stream = load(sound_resource_path)
    player.play()

    if crossfade_time == 0:
        _end_music_players()
        player.volume_linear = 1.0
    elif crossfade_time > 0:
        _fade_player(player, 0, 1, crossfade_time)
        for other: AudioStreamPlayer in _music_running:
            _fade_player(
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

static func _fade_player(
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
var _queue: Dictionary[String, Array]

func _enqueue_stream(bus: String, sound_resource_path: String, on_finish: Variant, delay_start: float) -> void:
    var queued = func () -> void:
        play_dialogue(sound_resource_path, on_finish, false, false, delay_start)

    if _queue.has(bus):
        _queue[bus].append(queued)
    else:
        _queue[bus] = [queued]

    print_debug("[Audio Hub] Enqueued dialog '%s' for bus %s" % [sound_resource_path, bus])

func _check_oneshot_callbacks(player: AudioStreamPlayer, busy_property: String) -> void:
    var callbacks: Array = _oneshots.get(player, [])
    _oneshots[player] = []

    for callback: Callable in callbacks:
        callback.call()

    print_debug("[Audio Hub] Player %s checks for queued in %s if '%s' is false (%s)" % [player.bus, _queue, busy_property, get(busy_property)])
    if (busy_property.is_empty() || !bool(get(busy_property))) && _queue.has(player.bus):
        var queued: Variant = _queue[player.bus].pop_front()
        print_debug("[Audio Hub] Playes queued stream %s for bus %s" % [queued, player.bus])
        if queued is Callable:
            (queued as Callable).call()

func _clear_bus_queue(bus: String) -> void:
    if _queue.has(bus):
        _queue[bus].clear()

func _clear_callbacks(player: AudioStreamPlayer) -> void:
    _oneshots.erase(player)
