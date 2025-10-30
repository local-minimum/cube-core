extends GridPlayerCore
class_name GridPlayer

@export var only_hurt_if_not_on_trail: bool = true
@export var health: int = 100
@export var trail: EntityTrail

var hurt_to_walk: bool = true:
    set(value):
        hurt_to_walk = value
        _previous_anchor = get_grid_anchor()

func _ready() -> void:
    super._ready()

    if __SignalBus.on_move_end.connect(_handle_move_end) != OK:
        push_error("Failed to connect move end")

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
