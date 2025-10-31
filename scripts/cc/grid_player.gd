extends GridPlayerCore
class_name GridPlayer

@export var only_hurt_if_not_on_trail: bool = true
@export var health: int = 100
@export var trail: EntityTrail

@export var exploration_music: String = "res://audio/music/Death Waltz - OPL Loop.ogg"
@export var crossfade_time: float = 0.5

static var playing_exploration_music = false

var hurt_to_walk: bool = true:
    set(value):
        hurt_to_walk = value
        _previous_anchor = get_grid_anchor()

func _ready() -> void:
    super._ready()

    if __SignalBus.on_move_end.connect(_handle_move_end) != OK:
        push_error("Failed to connect move end")

    if __SignalBus.on_cinematic.connect(_handle_not_cinematic) != OK:
        push_error("Failed to connect not cinematic")

func _handle_not_cinematic(entity: GridEntity, is_cinamatic: bool) -> void:
    if entity != self:
        return

    if is_cinamatic:
        playing_exploration_music = false
    elif !playing_exploration_music:
        playing_exploration_music = true
        GridEnemy.battle_music_playing = false
        __AudioHub.play_music(exploration_music, crossfade_time)

func is_alive() -> bool:
    return health > 0

func kill() -> void:
    var amount = health
    health = 0
    __SignalBus.on_hurt_player.emit(self, amount)
    if health == 0:
        __SignalBus.on_start_sacrifice.emit(self)

func hurt(amount: int = 1) -> void:
    amount = mini(health, amount)
    health -= amount
    __SignalBus.on_hurt_player.emit(self, amount)
    if health == 0:
        __SignalBus.on_start_sacrifice.emit(self)

func heal(amount: int) -> void:
    if amount <= 0:
        return

    health += amount
    __SignalBus.on_heal_player.emit(self, amount)

var _previous_anchor: GridAnchor


func _handle_move_end(entity: GridEntity) -> void:
    if entity != self || entity.get_grid_anchor() == _previous_anchor:
        return

    _previous_anchor = entity.get_grid_anchor()

    if only_hurt_if_not_on_trail && trail != null && trail.is_in_trail(_previous_anchor):
        return

    hurt()
