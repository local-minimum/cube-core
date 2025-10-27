extends GridPlayerCore
class_name GridPlayer

@export var health: int = 100

var hurt_to_walk: bool = true:
    set(value):
        hurt_to_walk = value
        _previous_coords = coordinates()

func _ready() -> void:
    super._ready()

    if __SignalBus.on_move_end.connect(_handle_move_end) != OK:
        push_error("Failed to connect move end")

func is_alive() -> bool:
    return health > 0

func kill() -> void:
    pass

func hurt(amount: int = 1) -> void:
    amount = mini(health, amount)
    health -= amount
    __SignalBus.on_hurt_player.emit(self, amount)

func heal(amount: int) -> void:
    if amount <= 0:
        return

    health += amount
    __SignalBus.on_heal_player.emit(self, amount)

var _previous_coords: Vector3i

func _handle_move_end(entity: GridEntity) -> void:
    if entity != self || entity.coordinates() == _previous_coords:
        return

    hurt()
