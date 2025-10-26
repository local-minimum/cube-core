extends SignalBusCore
class_name SignalBus

@warning_ignore_start("unused_signal")
signal on_play_exclude_word_game(enemy: GridEnemy, player: GridPlayerCore)

signal on_award_key(coordinates: Vector3)

signal on_update_lost_letters(lost_letters: String)
@warning_ignore_restore("unused_signal")
