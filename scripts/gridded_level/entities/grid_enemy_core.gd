@abstract
extends GridEntity
class_name GridEnemyCore

@abstract func hurt(amount: int = 1) -> void
@abstract func kill() -> void
@abstract func is_alive() -> bool
