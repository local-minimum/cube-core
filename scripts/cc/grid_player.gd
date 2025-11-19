extends GridPlayerCore
class_name GridPlayer

@export var only_hurt_if_not_on_trail: bool = true
@export var health: int = 100
@export var trail: EntityTrail

@export var footsteps_sfx: Array[String] = [
    "res://audio/sfx/footstep.ogg",
    "res://audio/sfx/footstep2.ogg",
    "res://audio/sfx/footstep3.ogg",
]
@export var min_foot_volume: float = 0.3
@export var max_foot_volume: float = 0.35
@export var exploration_music: String = "res://audio/music/Death Waltz - OPL Loop.ogg"
@export var no_health_sound: String = "res://audio/sfx/hit_10.ogg"
@export var crossfade_time: float = 0.5

static var playing_exploration_music = false
var _played_no_health: bool

var hurt_to_walk: bool = true:
    set(value):
        hurt_to_walk = value
        _previous_anchor = anchor

func _ready() -> void:
    super._ready()

    if __SignalBus.on_move_start.connect(_handle_move_from) != OK:
        push_error("Failed to connect move end")

    if __SignalBus.on_move_end.connect(_handle_move_end) != OK:
        push_error("Failed to connect move end")

    if __SignalBus.on_cinematic.connect(_handle_not_cinematic) != OK:
        push_error("Failed to connect not cinematic")

    if __SignalBus.on_play_exclude_word_game.connect(_handle_start_word_game) != OK:
        push_error("Failed to connect to word game start")

    if __SignalBus.on_end_exclude_word_game.connect(_handle_end_word_game) != OK:
        push_error("Failed to connect to end word game")

    if __SignalBus.on_start_sacrifice.connect(_handle_start_sacrifice) != OK:
        push_error("Failed to connect to start sacrifice")

    if __SignalBus.on_start_offer.connect(_handle_start_sacrifice) != OK:
        push_error("Failed to connect to start offer")

    if __SignalBus.on_complete_sacrifice.connect(_handle_end_sacrifice) != OK:
        push_error("Failed to connect ot complete sacrifice")

var _in_word_game: bool
var _in_sacrifice: bool

func _handle_start_word_game(_enemy: GridEnemy, _player: GridPlayer) -> void:
    _in_word_game = true

func _handle_end_word_game() -> void:
    _in_word_game = false
    print_debug("[Grid Player] end words Cine %s, Word %s, Sacri %s" % [cinematic, _in_word_game, _in_sacrifice])
    if cinematic && !_in_sacrifice:
        remove_cinematic_cause(self)

func _handle_start_sacrifice(_player: GridPlayer) -> void:
    _in_sacrifice = true

func _handle_end_sacrifice(_letter: String) -> void:
    _in_sacrifice = false
    print_debug("[Grid Player] end sacri Cine %s, Word %s, Sacri %s" % [cinematic, _in_word_game, _in_sacrifice])
    if cinematic && !_in_word_game:
        cause_cinematic(self)

func _handle_move_from(entity: GridEntity, _from: Vector3i, _direction: CardinalDirections.CardinalDirection) -> void:
    if entity != self || entity.cinematic || !entity.transportation_mode.has_any([TransportationMode.WALKING, TransportationMode.WALL_WALKING, TransportationMode.CEILING_WALKING]):
        return

    if !footsteps_sfx.is_empty():
        __AudioHub.play_sfx(footsteps_sfx.pick_random(), randf_range(min_foot_volume, max_foot_volume))

func _handle_not_cinematic(entity: GridEntity, is_cinamatic: bool) -> void:
    if entity != self:
        return

    if is_cinamatic:
        playing_exploration_music = false
    elif !playing_exploration_music:
        playing_exploration_music = true
        GridEnemy.battle_music_playing = false
        if !__AudioHub.playing_music().has(exploration_music):
            __AudioHub.play_music(exploration_music, crossfade_time)

func is_alive() -> bool:
    return health > 0

func kill() -> void:
    var amount = health
    health = 0
    __SignalBus.on_hurt_player.emit(self, amount)
    if health == 0:
        if !_played_no_health:
            __AudioHub.play_sfx(no_health_sound)
            _played_no_health = true
        __SignalBus.on_start_sacrifice.emit(self)

func hurt(amount: int = 1) -> void:
    amount = mini(health, amount)
    health -= amount
    __SignalBus.on_hurt_player.emit(self, amount)
    if health == 0:
        if !_played_no_health:
            __AudioHub.play_sfx(no_health_sound)
            _played_no_health = true
        __SignalBus.on_start_sacrifice.emit(self)

func heal(amount: int) -> void:
    if amount <= 0:
        return

    _played_no_health = false
    health += amount
    __SignalBus.on_heal_player.emit(self, amount)

var _previous_anchor: GridAnchor
var _on_trail_counter: int

func _handle_move_end(entity: GridEntity) -> void:
    if entity != self || anchor == _previous_anchor:
        return

    _previous_anchor = entity.anchor

    if only_hurt_if_not_on_trail && trail != null && trail.is_in_trail(_previous_anchor):
        _on_trail_counter += 1
        __SignalBus.on_track_back_on_trail.emit(self, _on_trail_counter)
        return

    _on_trail_counter = 0
    hurt()
    __SignalBus.on_hurt_by_walk.emit(self)
