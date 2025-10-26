extends GlobalGameStateCore
class_name GlobalGameState

var lost_letters: String:
    set(value):
        lost_letters = value
        __SignalBus.on_update_lost_letters.emit(value)
